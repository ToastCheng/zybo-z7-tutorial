`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_audio_fx.sv
// Phase 10: switch-controlled live sound effects on the audio loopback.
//
// After reset the FPGA configures the SSM2603 codec over I2C (mic input,
// I2S 16-bit slave mode at 44.1 kHz), then loops mic-in back to the
// headphones through a selectable effect:
//
//   sw[1:0] = 00 : bypass (pure loopback)
//             01 : bit-crusher (lo-fi)
//             10 : echo (~0.37 s delay line in block RAM)
//             11 : distortion (gain + hard clip)
//
//   sw[3:2] select the effect intensity (see the effect modules).
//
// RGB LED shows the selected effect once the codec is configured:
//   off = bypass, red = bit-crusher, green = echo, blue = distortion
// (during I2C configuration the LED pulses red; blue pulse = I2C error).
//
// BTN0 resets the design.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_audio_fx #(
    parameter int DEBOUNCE_STABLE_US = 10_000,
    parameter int ECHO_DEPTH         = 16384   // frames; ~0.37 s at 44.1 kHz
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

    // SSM2603 configuration for I2S 16-bit playback/record at 44.1 kHz.
    localparam int LUT_SIZE = 11;
    logic [15:0] lut [0:LUT_SIZE-1] = '{
        16'h0C10,  // R6: power on everything except OUT
        16'h0017,  // R0: left line in, 0 dB
        16'h0217,  // R1: right line in, 0 dB
        16'h0479,  // R2: left headphone, 0 dB
        16'h0679,  // R3: right headphone, 0 dB
        16'h0815,  // R4: analog audio path (DAC on, mic input, +20 dB boost)
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

    // Cross init_done and the effect switches into the MCLK domain.
    logic init_done_mclk;
    logic [1:0] init_done_sync;
    logic [3:0] sw_mclk;
    logic [3:0] sw_sync_0, sw_sync_1;

    always_ff @(posedge mclk or posedge db_btn0) begin
        if (db_btn0) begin
            init_done_sync <= '0;
            sw_sync_0      <= '0;
            sw_sync_1      <= '0;
        end else begin
            init_done_sync <= {init_done_sync[0], init_done};
            sw_sync_0      <= sw;
            sw_sync_1      <= sw_sync_0;
        end
    end

    assign init_done_mclk = init_done_sync[1];
    assign sw_mclk        = sw_sync_1;

    // I2S receive/transmit (MCLK domain).
    logic        i2s_rst;
    logic        sample_req;
    logic [15:0] rx_l, rx_r;

    assign i2s_rst = db_btn0 || !audio_locked || !init_done_mclk;

    i2s_rx i2s_in (
        .mclk     (mclk),
        .rst      (i2s_rst),
        .lrclk    (ac_pblrc),
        .recdat   (ac_recdat),
        .sample_l (rx_l),
        .sample_r (rx_r)
    );

    //--------------------------------------------------------------------------
    // Effect chain
    //--------------------------------------------------------------------------

    logic signed [15:0] rx_ls, rx_rs;
    assign rx_ls = rx_l;
    assign rx_rs = rx_r;

    logic signed [15:0] crush_l, crush_r;
    logic signed [15:0] dist_l,  dist_r;
    logic signed [15:0] echo_l,  echo_r;

    audio_fx_bitcrusher crush_l_inst (
        .sample_in  (rx_ls),
        .intensity  (sw_mclk[3:2]),
        .sample_out (crush_l)
    );

    audio_fx_bitcrusher crush_r_inst (
        .sample_in  (rx_rs),
        .intensity  (sw_mclk[3:2]),
        .sample_out (crush_r)
    );

    audio_fx_distortion dist_l_inst (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_in  (rx_ls),
        .intensity  (sw_mclk[3:2]),
        .sample_out (dist_l)
    );

    audio_fx_distortion dist_r_inst (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_in  (rx_rs),
        .intensity  (sw_mclk[3:2]),
        .sample_out (dist_r)
    );

    audio_fx_echo #(.DEPTH(ECHO_DEPTH)) echo_inst (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_req (sample_req),
        .in_l       (rx_ls),
        .in_r       (rx_rs),
        .intensity  (sw_mclk[3:2]),
        .out_l      (echo_l),
        .out_r      (echo_r)
    );

    // Effect select mux: 00 bypass, 01 crusher, 10 echo, 11 distortion.
    logic signed [15:0] tx_l, tx_r;

    always_comb begin
        case (sw_mclk[1:0])
            2'b01:   {tx_l, tx_r} = {crush_l, crush_r};
            2'b10:   {tx_l, tx_r} = {echo_l,  echo_r};
            2'b11:   {tx_l, tx_r} = {dist_l,  dist_r};
            default: {tx_l, tx_r} = {rx_ls,   rx_rs};
        endcase
    end

    i2s_tx i2s_out (
        .mclk       (mclk),
        .rst        (i2s_rst),
        .sample_l   (tx_l),
        .sample_r   (tx_r),
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

    //--------------------------------------------------------------------------
    // Visual feedback (sysclk domain)
    //--------------------------------------------------------------------------

    logic busy;
    assign busy = (state != S_IDLE) && (state != S_DONE) && (state != S_ERROR);

    logic pwm_out;
    pwm #(.N(8)) pwm_dimmer (
        .clk     (clk),
        .duty    (8'd2),
        .pwm_out (pwm_out)
    );

    // After init: show the selected effect (off/red/green/blue).  While busy
    // or on error, keep the Phase 8 status colors.
    logic [2:0] fx_color;
    always_comb begin
        case (sw[1:0])
            2'b01:   fx_color = 3'b100; // crusher: red
            2'b10:   fx_color = 3'b010; // echo: green
            2'b11:   fx_color = 3'b001; // distortion: blue
            default: fx_color = 3'b000; // bypass: off
        endcase
    end

    logic [2:0] rgb_raw;
    assign rgb_raw = init_err  ? 3'b001 :
                     busy      ? 3'b100 :
                     init_done ? fx_color :
                                 3'b000;
    assign rgb_led = rgb_raw & {3{pwm_out}};

    assign led     = sw;
    assign uart_tx = 1'b1;

endmodule : top_audio_fx
