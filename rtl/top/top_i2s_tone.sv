`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_i2s_tone.sv
// Phase 7: I2S audio tone generator.
//
// After reset the FPGA configures the SSM2603 codec over I2C for I2S 16-bit
// slave mode at 44.1 kHz, then drives a 1 kHz sine tone out of the headphone
// jack using the I2S interface.
//
// RGB LED status:
//   red   = busy (I2C configuration in progress)
//   green = done (tone is playing)
//   blue  = error (codec did not acknowledge a byte)
//   off   = idle (waiting, should not persist after reset)
//
// BTN0 resets the design.  SW0 is unused in this phase.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_i2s_tone #(
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
    output logic ac_mclk,
    output logic ac_bclk,
    output logic ac_pblrc,
    output logic ac_reclrc,
    output logic ac_pbdat,
    input  logic ac_recdat,
    output logic ac_muten
);

    import board_pkg::*;

    // SSM2603 configuration for I2S 16-bit playback at 44.1 kHz.
    localparam int LUT_SIZE = 11;
    logic [15:0] lut [0:LUT_SIZE-1] = '{
        16'h0C10,  // R6: power on everything except OUT
        16'h0017,  // R0: left line in, 0 dB
        16'h0217,  // R1: right line in, 0 dB
        16'h0479,  // R2: left headphone, 0 dB
        16'h0679,  // R3: right headphone, 0 dB
        16'h08D4,  // R4: analog audio path (DAC enabled)
        16'h0A04,  // R5: digital audio path
        16'h0E02,  // R7: digital audio interface, I2S 16-bit, codec slave
        16'h1020,  // R8: sampling rate, 44.1 kHz normal mode
        16'h0C00,  // R6: power on everything
        16'h1201   // R9: activate digital core
    };

    localparam logic [7:0] I2C_DEVICE_ADDR_W = 8'h34;

    // Reset and trigger handling.
    logic db_btn0;

    debounce #(
        .STABLE_US(DEBOUNCE_STABLE_US)
    ) db0 (
        .clk  (clk),
        .din  (btn[0]),
        .dout (db_btn0)
    );

    // Audio master clock generation (125 MHz -> ~11.2896 MHz).
    logic mclk;
    logic audio_locked;

    audio_clock_gen clk_gen (
        .clk    (clk),
        .rst    (db_btn0),
        .mclk   (mclk),
        .locked (audio_locked)
    );

    // I2C master for codec configuration.
    logic i2c_cmd_start, i2c_cmd_stop, i2c_cmd_write;
    logic [7:0] i2c_tx_data;
    logic i2c_busy, i2c_done, i2c_ack;
    logic scl_oe, sda_oe;

    i2c_master #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(100_000)
    ) i2c (
        .clk          (clk),
        .rst          (db_btn0),
        .cmd_start    (i2c_cmd_start),
        .cmd_rep_start(1'b0),
        .cmd_stop     (i2c_cmd_stop),
        .cmd_write    (i2c_cmd_write),
        .cmd_read     (1'b0),
        .tx_data      (i2c_tx_data),
        .ack_in       (1'b0),
        .busy         (i2c_busy),
        .done         (i2c_done),
        .ack          (i2c_ack),
        .rx_data      (),
        .scl_oe       (scl_oe),
        .sda_oe       (sda_oe),
        .sda_i        (ac_sda)
    );

    // Open-drain I2C outputs.
    assign ac_scl = scl_oe ? 1'b0 : 1'bz;
    assign ac_sda = sda_oe ? 1'b0 : 1'bz;

    // Codec configuration sequencer (runs on sysclk).
    typedef enum logic [3:0] {
        S_IDLE,
        S_START,        S_WAIT_START,
        S_ADDR,         S_WAIT_ADDR,
        S_DATA_H,       S_WAIT_DATA_H,
        S_DATA_L,       S_WAIT_DATA_L,
        S_STOP,         S_WAIT_STOP,
        S_DONE,
        S_ERROR
    } state_t;

    state_t state = S_IDLE;
    logic [3:0] step      = '0;
    logic       ack_ok    = 1'b1;
    logic       init_done = 1'b0;
    logic       init_err  = 1'b0;

    always_ff @(posedge clk) begin
        if (db_btn0) begin
            state         <= S_IDLE;
            step          <= '0;
            ack_ok        <= 1'b1;
            init_done     <= 1'b0;
            init_err      <= 1'b0;
            i2c_cmd_start <= 1'b0;
            i2c_cmd_stop  <= 1'b0;
            i2c_cmd_write <= 1'b0;
            i2c_tx_data   <= '0;
        end else begin
            i2c_cmd_start <= 1'b0;
            i2c_cmd_stop  <= 1'b0;
            i2c_cmd_write <= 1'b0;

            case (state)
                S_IDLE: begin
                    ack_ok <= 1'b1;
                    if (!init_done && !init_err)
                        state <= S_START;
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
                            state <= S_START;
                        end else begin
                            init_done <= 1'b1;
                            state     <= S_DONE;
                        end
                    end else begin
                        init_err <= 1'b1;
                        state    <= S_ERROR;
                    end
                end

                S_DONE, S_ERROR: ; // hold until reset

                default: state <= S_IDLE;
            endcase
        end
    end

    // Cross init_done into the MCLK domain.
    logic init_done_mclk;
    logic [1:0] init_done_sync;

    always_ff @(posedge mclk or posedge db_btn0) begin
        if (db_btn0)
            init_done_sync <= '0;
        else
            init_done_sync <= {init_done_sync[0], init_done};
    end

    assign init_done_mclk = init_done_sync[1];

    // I2S + tone generator (MCLK domain).
    logic i2s_rst;
    logic [15:0] tone_l, tone_r;
    logic        sample_req;

    assign i2s_rst = db_btn0 || !audio_locked || !init_done_mclk;

    tone_generator #(
        .SAMPLE_RATE_HZ(44_100),
        .FREQ_HZ       (1_000)
    ) tone (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_req (sample_req),
        .sample_l   (tone_l),
        .sample_r   (tone_r)
    );

    i2s_tx i2s (
        .mclk       (mclk),
        .rst        (i2s_rst),
        .sample_l   (tone_l),
        .sample_r   (tone_r),
        .sample_req (sample_req),
        .bclk       (ac_bclk),
        .lrclk      (ac_pblrc),
        .pbdat      (ac_pbdat)
    );

    // Tie record LRCLK to playback LRCLK (codec is slave).
    assign ac_reclrc = ac_pblrc;

    // MCLK output.
    assign ac_mclk = mclk;

    // Unmute after successful init.
    assign ac_muten = init_done;

    // Visual feedback on sysclk domain.
    logic busy;
    assign busy = (state != S_IDLE) && (state != S_DONE) && (state != S_ERROR);

    logic pwm_out;
    pwm #(.N(8)) pwm_dimmer (
        .clk     (clk),
        .duty    (8'd2),
        .pwm_out (pwm_out)
    );

    logic [2:0] rgb_raw;
    assign rgb_raw = init_err  ? 3'b001 :
                     init_done ? 3'b010 :
                     busy      ? 3'b100 :
                                 3'b000;
    assign rgb_led = rgb_raw & {3{pwm_out}};

    assign led     = 4'b0000;
    assign uart_tx = 1'b1;

endmodule : top_i2s_tone
