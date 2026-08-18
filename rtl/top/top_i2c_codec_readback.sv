`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_i2c_codec_readback.sv
// Phase 6 follow-on: configure the on-board SSM2603 audio codec over I2C and
// read back register R0 (Left Line In).  The lower four bits of the read data
// are shown on LD0-LD3.
//
// The design powers up and automatically:
//   1. Writes the standard 11-register SSM2603 initialization table.
//   2. Issues a repeated-START read of register R0.
//   3. Displays the returned low byte on led[3:0].
//
// RGB LED status (active-high, dimmed with PWM):
//   red   = busy (a transaction is in progress)
//   green = done (write + read completed successfully)
//   blue  = error (a codec ACK was not received)
//   off   = idle (waiting for a re-trigger)
//
// Toggle SW0 to restart the sequence after done or error.
// Press BTN0 to hold the design in reset.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_i2c_codec_readback #(
    parameter int DEBOUNCE_STABLE_US = 10_000
)(
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
    localparam logic [7:0] I2C_DEVICE_ADDR_R = 8'h35;  // 0x1A << 1 | R

    // Reset and trigger handling.
    logic db_btn0;
    logic sw0_sync;
    logic sw0_rising;

    debounce #(
        .STABLE_US(DEBOUNCE_STABLE_US)
    ) db0 (
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

    // I2C master with read support.
    logic i2c_cmd_start, i2c_cmd_rep_start, i2c_cmd_stop;
    logic i2c_cmd_write, i2c_cmd_read;
    logic [7:0] i2c_tx_data;
    logic       i2c_ack_in;
    logic       i2c_busy, i2c_done, i2c_ack;
    logic [7:0] i2c_rx_data;
    logic       scl_oe, sda_oe;

    i2c_master #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(100_000)
    ) i2c (
        .clk          (clk),
        .rst          (db_btn0),
        .cmd_start    (i2c_cmd_start),
        .cmd_rep_start(i2c_cmd_rep_start),
        .cmd_stop     (i2c_cmd_stop),
        .cmd_write    (i2c_cmd_write),
        .cmd_read     (i2c_cmd_read),
        .tx_data      (i2c_tx_data),
        .ack_in       (i2c_ack_in),
        .busy         (i2c_busy),
        .done         (i2c_done),
        .ack          (i2c_ack),
        .rx_data      (i2c_rx_data),
        .scl_oe       (scl_oe),
        .sda_oe       (sda_oe),
        .sda_i        (ac_sda)
    );

    // Open-drain outputs for the I2C bus.
    assign ac_scl = scl_oe ? 1'b0 : 1'bz;
    assign ac_sda = sda_oe ? 1'b0 : 1'bz;

    // Unmute the codec analog outputs.
    assign ac_muten = 1'b1;

    // Configuration and read-back sequencer.
    typedef enum logic [4:0] {
        S_IDLE,
        S_W_START,        S_W_WAIT_START,
        S_W_ADDR,         S_W_WAIT_ADDR,
        S_W_REG_H,        S_W_WAIT_REG_H,
        S_W_REG_L,        S_W_WAIT_REG_L,
        S_W_STOP,         S_W_WAIT_STOP,
        S_R_START,        S_R_WAIT_START,
        S_R_ADDR_W,       S_R_WAIT_ADDR_W,
        S_R_REG,          S_R_WAIT_REG,
        S_R_REP_START,    S_R_WAIT_REP_START,
        S_R_ADDR_R,       S_R_WAIT_ADDR_R,
        S_R_BYTE,         S_R_WAIT_BYTE,
        S_R_STOP,         S_R_WAIT_STOP,
        S_DONE,
        S_ERROR
    } state_t;

    state_t state = S_IDLE;
    logic [3:0] step        = '0;
    logic       ack_ok      = 1'b1;
    logic       error_reg   = 1'b0;
    logic       done_all    = 1'b0;
    logic [7:0] read_data   = '0;

    always_ff @(posedge clk) begin
        if (db_btn0) begin
            state           <= S_IDLE;
            step            <= '0;
            ack_ok          <= 1'b1;
            error_reg       <= 1'b0;
            done_all        <= 1'b0;
            read_data       <= '0;
            i2c_cmd_start   <= 1'b0;
            i2c_cmd_rep_start<= 1'b0;
            i2c_cmd_stop    <= 1'b0;
            i2c_cmd_write   <= 1'b0;
            i2c_cmd_read    <= 1'b0;
            i2c_tx_data     <= '0;
            i2c_ack_in      <= 1'b0;
        end else begin
            // Default: no command.
            i2c_cmd_start    <= 1'b0;
            i2c_cmd_rep_start<= 1'b0;
            i2c_cmd_stop     <= 1'b0;
            i2c_cmd_write    <= 1'b0;
            i2c_cmd_read     <= 1'b0;

            case (state)
                S_IDLE: begin
                    ack_ok <= 1'b1;
                    if (!done_all && !error_reg) begin
                        state <= S_W_START;
                    end
                end

                S_W_START: begin
                    i2c_cmd_start <= 1'b1;
                    state         <= S_W_WAIT_START;
                end

                S_W_WAIT_START: if (i2c_done) begin
                    i2c_tx_data <= I2C_DEVICE_ADDR_W;
                    state       <= S_W_ADDR;
                end

                S_W_ADDR: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_W_WAIT_ADDR;
                end

                S_W_WAIT_ADDR: if (i2c_done) begin
                    ack_ok      <= ack_ok && i2c_ack;
                    i2c_tx_data <= lut[step][15:8];
                    state       <= S_W_REG_H;
                end

                S_W_REG_H: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_W_WAIT_REG_H;
                end

                S_W_WAIT_REG_H: if (i2c_done) begin
                    ack_ok      <= ack_ok && i2c_ack;
                    i2c_tx_data <= lut[step][7:0];
                    state       <= S_W_REG_L;
                end

                S_W_REG_L: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_W_WAIT_REG_L;
                end

                S_W_WAIT_REG_L: if (i2c_done) begin
                    ack_ok <= ack_ok && i2c_ack;
                    state  <= S_W_STOP;
                end

                S_W_STOP: begin
                    i2c_cmd_stop <= 1'b1;
                    state        <= S_W_WAIT_STOP;
                end

                S_W_WAIT_STOP: if (i2c_done) begin
                    if (ack_ok) begin
                        if (step < LUT_SIZE-1) begin
                            step  <= step + 1'b1;
                            state <= S_W_START;
                        end else begin
                            step  <= step + 1'b1;
                            state <= S_R_START;
                        end
                    end else begin
                        error_reg <= 1'b1;
                        state     <= S_ERROR;
                    end
                end

                // ---------- Read-back phase for register R0 ----------
                S_R_START: begin
                    i2c_cmd_start <= 1'b1;
                    state         <= S_R_WAIT_START;
                end

                S_R_WAIT_START: if (i2c_done) begin
                    i2c_tx_data <= I2C_DEVICE_ADDR_W;
                    state       <= S_R_ADDR_W;
                end

                S_R_ADDR_W: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_R_WAIT_ADDR_W;
                end

                S_R_WAIT_ADDR_W: if (i2c_done) begin
                    ack_ok      <= ack_ok && i2c_ack;
                    i2c_tx_data <= 8'h00;  // R0: Left Line In
                    state       <= S_R_REG;
                end

                S_R_REG: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_R_WAIT_REG;
                end

                S_R_WAIT_REG: if (i2c_done) begin
                    ack_ok <= ack_ok && i2c_ack;
                    state  <= S_R_REP_START;
                end

                S_R_REP_START: begin
                    i2c_cmd_rep_start <= 1'b1;
                    state             <= S_R_WAIT_REP_START;
                end

                S_R_WAIT_REP_START: if (i2c_done) begin
                    i2c_tx_data <= I2C_DEVICE_ADDR_R;
                    state       <= S_R_ADDR_R;
                end

                S_R_ADDR_R: begin
                    i2c_cmd_write <= 1'b1;
                    state         <= S_R_WAIT_ADDR_R;
                end

                S_R_WAIT_ADDR_R: if (i2c_done) begin
                    ack_ok <= ack_ok && i2c_ack;
                    state  <= S_R_BYTE;
                end

                S_R_BYTE: begin
                    i2c_ack_in <= 1'b0;   // NACK: read exactly one byte
                    i2c_cmd_read <= 1'b1;
                    state        <= S_R_WAIT_BYTE;
                end

                S_R_WAIT_BYTE: if (i2c_done) begin
                    read_data <= i2c_rx_data;
                    state     <= S_R_STOP;
                end

                S_R_STOP: begin
                    i2c_cmd_stop <= 1'b1;
                    state        <= S_R_WAIT_STOP;
                end

                S_R_WAIT_STOP: if (i2c_done) begin
                    if (ack_ok) begin
                        done_all <= 1'b1;
                        state    <= S_DONE;
                    end else begin
                        error_reg <= 1'b1;
                        state     <= S_ERROR;
                    end
                end

                S_DONE: begin
                    if (sw0_rising) begin
                        done_all  <= 1'b0;
                        error_reg <= 1'b0;
                        step      <= '0;
                        read_data <= '0;
                        ack_ok    <= 1'b1;
                        state     <= S_W_START;
                    end
                end

                S_ERROR: begin
                    if (sw0_rising) begin
                        done_all  <= 1'b0;
                        error_reg <= 1'b0;
                        step      <= '0;
                        read_data <= '0;
                        ack_ok    <= 1'b1;
                        state     <= S_W_START;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Visual feedback.
    assign led = error_reg  ? 4'b1111 :
                 done_all   ? read_data[3:0] :
                              step[3:0];

    logic busy;
    assign busy = (state != S_IDLE) && (state != S_DONE) && (state != S_ERROR);

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

endmodule : top_i2c_codec_readback
