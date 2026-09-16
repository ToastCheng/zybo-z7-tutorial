`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_audio_fx_soc.sv
// Phase 11: PS-controlled live sound effects (SoC version of Phase 10).
//
// Unlike Phase 10, there is no RTL I2C master and no switch-based control.
// The Zynq PS does all of the management:
//
//   - PS I2C1 (routed through EMIO to the PL pins) configures the SSM2603
//     codec from the bare-metal application.
//   - The PS writes a 32-bit control word over AXI GPIO (M_AXI_GP0):
//
//       ctrl[2:0]  effect select: 000 bypass, 001 bit-crusher, 010 echo,
//                                 011 distortion, 100 biquad filter
//       ctrl[4:3]  effect intensity (0..3; filter preset for the biquad)
//       ctrl[5]    codec_ready: releases the I2S datapath reset once the
//                  codec is configured (replaces the RTL init_done)
//       ctrl[6]    unmute (drives ac_muten)
//
// The PL keeps the real-time datapath: audio master clock (MMCM), I2S
// receive/transmit, and the effect chain - the parts that must run at
// hardware speed with zero CPU involvement.
//
// The four LEDs mirror ctrl[3:0] as a hardware-side debug view.
//------------------------------------------------------------------------------

module top_audio_fx_soc #(
    parameter int ECHO_DEPTH = 16384   // frames; ~0.37 s at 44.1 kHz
)(
    input  logic clk,
    output logic [3:0] led,
    inout  wire  ac_scl,
    inout  wire  ac_sda,
    output logic ac_mclk,
    output logic ac_bclk,
    output logic ac_pblrc,
    output logic ac_reclrc,
    output logic ac_pbdat,
    input  logic ac_recdat,
    output logic ac_muten
);

    //--------------------------------------------------------------------------
    // Zynq PS (block-design wrapper)
    //
    // The wrapper exposes the EMIO I2C1 as tri-state inout ports and the AXI
    // GPIO channel as a plain 32-bit output.  Pin direction on the I2C lines
    // is controlled by the PS peripheral itself.
    //--------------------------------------------------------------------------

    wire [31:0] ctrl;

    system_wrapper ps (
        .IIC_1_0_scl_io (ac_scl),
        .IIC_1_0_sda_io (ac_sda),
        .gpio_io_o_0    (ctrl)
    );

    // LED debug mirror of effect select + intensity.
    assign led = ctrl[3:0];

    //--------------------------------------------------------------------------
    // Audio master clock generation (125 MHz -> ~11.2896 MHz)
    //--------------------------------------------------------------------------

    logic mclk;
    logic audio_locked;

    audio_clock_gen clk_gen (
        .clk    (clk),
        .rst    (1'b0),
        .mclk   (mclk),
        .locked (audio_locked)
    );

    //--------------------------------------------------------------------------
    // Cross the PS-written control word into the MCLK domain
    //--------------------------------------------------------------------------

    logic [31:0] ctrl_sync_0 = '0, ctrl_sync_1 = '0;

    always_ff @(posedge mclk) begin
        ctrl_sync_0 <= ctrl;
        ctrl_sync_1 <= ctrl_sync_0;
    end

    logic [2:0] fx_sel_mclk;
    logic [1:0] intensity_mclk;
    logic       codec_ready_mclk;

    assign fx_sel_mclk    = ctrl_sync_1[2:0];
    assign intensity_mclk = ctrl_sync_1[4:3];
    assign codec_ready_mclk = ctrl_sync_1[5];

    //--------------------------------------------------------------------------
    // I2S receive/transmit (MCLK domain)
    //--------------------------------------------------------------------------

    logic        i2s_rst;
    logic        sample_req;
    logic [15:0] rx_l, rx_r;

    assign i2s_rst = !audio_locked || !codec_ready_mclk;

    i2s_rx i2s_in (
        .mclk     (mclk),
        .rst      (i2s_rst),
        .lrclk    (ac_pblrc),
        .recdat   (ac_recdat),
        .sample_l (rx_l),
        .sample_r (rx_r)
    );

    //--------------------------------------------------------------------------
    // Effect chain (identical to Phase 10, but controlled by the PS)
    //--------------------------------------------------------------------------

    logic signed [15:0] rx_ls, rx_rs;
    assign rx_ls = rx_l;
    assign rx_rs = rx_r;

    logic signed [15:0] crush_l, crush_r;
    logic signed [15:0] dist_l,  dist_r;
    logic signed [15:0] echo_l,  echo_r;
    logic signed [15:0] filt_l,  filt_r;

    audio_fx_bitcrusher crush_l_inst (
        .sample_in  (rx_ls),
        .intensity  (intensity_mclk),
        .sample_out (crush_l)
    );

    audio_fx_bitcrusher crush_r_inst (
        .sample_in  (rx_rs),
        .intensity  (intensity_mclk),
        .sample_out (crush_r)
    );

    audio_fx_distortion dist_l_inst (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_in  (rx_ls),
        .intensity  (intensity_mclk),
        .sample_out (dist_l)
    );

    audio_fx_distortion dist_r_inst (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_in  (rx_rs),
        .intensity  (intensity_mclk),
        .sample_out (dist_r)
    );

    audio_fx_echo #(.DEPTH(ECHO_DEPTH)) echo_inst (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_req (sample_req),
        .in_l       (rx_ls),
        .in_r       (rx_rs),
        .intensity  (intensity_mclk),
        .out_l      (echo_l),
        .out_r      (echo_r)
    );

    audio_fx_biquad filt_l_inst (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_req (sample_req),
        .sample_in  (rx_ls),
        .intensity  (intensity_mclk),
        .sample_out (filt_l)
    );

    audio_fx_biquad filt_r_inst (
        .clk        (mclk),
        .rst        (i2s_rst),
        .sample_req (sample_req),
        .sample_in  (rx_rs),
        .intensity  (intensity_mclk),
        .sample_out (filt_r)
    );

    // Effect select mux: 000 bypass, 001 crusher, 010 echo, 011 distortion,
    // 100 biquad filter.
    logic signed [15:0] tx_l, tx_r;

    always_comb begin
        case (fx_sel_mclk)
            3'b001:  {tx_l, tx_r} = {crush_l, crush_r};
            3'b010:  {tx_l, tx_r} = {echo_l,  echo_r};
            3'b011:  {tx_l, tx_r} = {dist_l,  dist_r};
            3'b100:  {tx_l, tx_r} = {filt_l,  filt_r};
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

    // Mute is controlled by the PS (ctrl[6]).
    assign ac_muten = ctrl_sync_1[6];

endmodule : top_audio_fx_soc
