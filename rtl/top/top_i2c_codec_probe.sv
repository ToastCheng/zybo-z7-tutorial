`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_i2c_codec_probe.sv
// Phase 6: I2C master probe of the on-board SSM2603 audio codec.
//
// Toggling SW0 sends the next register-write from the configuration lookup
// table to the codec over I2C.  LD0-LD3 show the current step in the sequence.
// The RGB LED indicates status:
//   red   = busy (a transaction is in progress)
//   green = done (all registers have been configured successfully)
//   blue  = error (the codec did not acknowledge a byte)
//   off   = idle (waiting for SW0)
// BTN0 resets the sequencer.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_i2c_codec_probe (
    input  logic clk,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic [2:0] rgb_led,
    input  logic uart_rx,
    output logic uart_tx,
    inout  logic ac_scl,
    inout  logic ac_sda,
    output logic ac_muten
);

    import board_pkg::*;

    // SSM2603 configuration sequence.
    // Each entry is {7-bit register address, 9-bit register value}.
    localparam int LUT_SIZE = 11;
    logic [15:0] lut [0:LUT_SIZE-1] = '{
        16'h0C10,  // R6: power on everything except OUT
        16'h0017,  // R0: left line in, 0 dB
        16'h0217,  // R1: right line in, 0 dB
        16'h0479,  // R2: left headphone, 0 dB
        16'h0679,  // R3: right headphone, 0 dB
        16'h08D4,  // R4: analog audio path
        16'h0A04,  // R5: digital audio path
        16'h0E01,  // R7: digital audio interface, I2S 16-bit
        16'h1020,  // R8: sampling rate, 44.1 kHz normal mode
        16'h0C00,  // R6: power on everything
        16'h1201   // R9: activate digital core
    };

    localparam logic [7:0] I2C_DEVICE_ADDR_W = 8'h34;  // 0x1A << 1 | W

    // Reset and trigger handling.
    logic db_btn0;
    logic sw0_sync;
    logic sw0_rising;

    debounce db0 (
        .clk  (clk),
        .din  (btn[0]),
        .dout (db_btn0)
    );

    sync sync_sw0 (
        .clk  (clk),
        .din  (sw[0]),
        .dout (sw0_sync)
    );

    edge_detect ed_sw0 (
        .clk     (clk),
        .din     (sw0_sync),
        .rising  (sw0_rising),
        .falling ()
    );

    // I2C master.
    logic i2c_cmd_start, i2c_cmd_stop, i2c_cmd_write;
    logic [7:0] i2c_tx_data;
    logic i2c_busy, i2c_done, i2c_ack;
    logic scl_oe, sda_oe;

    i2c_master #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(100_000)
    ) i2c (
        .clk       (clk),
        .rst       (db_btn0),
        .cmd_start (i2c_cmd_start),
        .cmd_stop  (i2c_cmd_stop),
        .cmd_write (i2c_cmd_write),
        .tx_data   (i2c_tx_data),
        .busy      (i2c_busy),
        .done      (i2c_done),
        .ack       (i2c_ack),
        .scl_oe    (scl_oe),
        .sda_oe    (sda_oe),
        .sda_i     (ac_sda)
    );

    // Open-drain outputs for the I2C bus.
    assign ac_scl = scl_oe ? 1'b0 : 1'bz;
    assign ac_sda = sda_oe ? 1'b0 : 1'bz;

    // Unmute the codec analog outputs.
    assign ac_muten = 1'b1;

    // Configuration sequencer.
    typedef enum logic [3:0] {
        S_IDLE,
        S_START,
        S_WAIT_START,
        S_ADDR,
        S_WAIT_ADDR,
        S_DATA_H,
        S_WAIT_DATA_H,
        S_DATA_L,
        S_WAIT_DATA_L,
        S_STOP,
        S_WAIT_STOP,
        S_ERROR
    } state_t;

    state_t state = S_IDLE;
    logic [3:0] step = '0;
    logic       ack_ok;
    logic       error_reg = 1'b0;
    logic       done_all  = 1'b0;

    always_ff @(posedge clk) begin
        if (db_btn0) begin
            state         <= S_IDLE;
            step          <= '0;
            error_reg     <= 1'b0;
            done_all      <= 1'b0;
            ack_ok        <= 1'b1;
            i2c_cmd_start <= 1'b0;
            i2c_cmd_stop  <= 1'b0;
            i2c_cmd_write <= 1'b0;
        end else begin
            // Default: no command.
            i2c_cmd_start <= 1'b0;
            i2c_cmd_stop  <= 1'b0;
            i2c_cmd_write <= 1'b0;

            case (state)
                S_IDLE: begin
                    ack_ok <= 1'b1;
                    if (sw0_rising && !done_all && !error_reg) begin
                        state <= S_START;
                    end
                end

                S_START: begin
                    i2c_cmd_start <= 1'b1;
                    state         <= S_WAIT_START;
                end

                S_WAIT_START: if (i2c_done) begin
                    i2c_tx_data <= I2C_DEVICE_ADDR_W;
                    state       <= S_ADDR;
                end

                S_ADDR: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_WAIT_ADDR;
                end

                S_WAIT_ADDR: if (i2c_done) begin
                    ack_ok      <= ack_ok && i2c_ack;
                    i2c_tx_data <= lut[step][15:8];
                    state       <= S_DATA_H;
                end

                S_DATA_H: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_WAIT_DATA_H;
                end

                S_WAIT_DATA_H: if (i2c_done) begin
                    ack_ok      <= ack_ok && i2c_ack;
                    i2c_tx_data <= lut[step][7:0];
                    state       <= S_DATA_L;
                end

                S_DATA_L: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_WAIT_DATA_L;
                end

                S_WAIT_DATA_L: if (i2c_done) begin
                    ack_ok <= ack_ok && i2c_ack;
                    state  <= S_STOP;
                end

                S_STOP: begin
                    i2c_cmd_stop <= 1'b1;
                    state        <= S_WAIT_STOP;
                end

                S_WAIT_STOP: if (i2c_done) begin
                    if (ack_ok) begin
                        if (step < LUT_SIZE-1) begin
                            step  <= step + 1'b1;
                            state <= S_IDLE;
                        end else begin
                            step     <= step + 1'b1;
                            done_all <= 1'b1;
                            state    <= S_IDLE;
                        end
                    end else begin
                        error_reg <= 1'b1;
                        state     <= S_ERROR;
                    end
                end

                S_ERROR: begin
                    // Hold state until reset.
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Visual feedback.
    assign led = step[3:0];

    logic busy;
    assign busy = (state != S_IDLE) && (state != S_ERROR);

    logic pwm_out;
    pwm #(
        .N(8)
    ) pwm_dimmer (
        .clk     (clk),
        .duty    (8'd2),
        .pwm_out (pwm_out)
    );

    logic [2:0] rgb_raw;
    // rgb_led[2]=R, [1]=G, [0]=B
    assign rgb_raw = error_reg ? 3'b001 :
                     done_all  ? 3'b010 :
                     busy      ? 3'b100 :
                                 3'b000;
    assign rgb_led = rgb_raw & {3{pwm_out}};

    // Unused ports.
    assign uart_tx = 1'b1;

endmodule : top_i2c_codec_probe
