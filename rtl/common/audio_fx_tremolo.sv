`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_tremolo.sv
// Tremolo: amplitude modulation by a ~5 Hz triangle LFO.
//
// The LFO output (Q1.15, +-1) is scaled by a power-of-two shift and added
// to 0.5, giving a gain in Q1.16 format that oscillates around 0.5:
//
//   gain = 32768 + (tri_wave >>> depth_shift)     (Q1.16, 0 < gain < 1)
//   out  = (sample * gain) >>> 16
//
// `intensity` selects the modulation depth:
//   0 -> shift 3 (subtle: gain swings 0.44..0.56)
//   1 -> shift 2 (mild:   0.375..0.625)
//   2 -> shift 1 (deep:   0.25..0.75)
//   3 -> shift 0 (full:   0.0..1.0)
//
// One 16x18 multiply per channel (one DSP48 each).  Since gain < 1 the
// product can never overflow, so no saturation stage is needed.
// The output is registered on `sample_req`; one frame of latency.
//------------------------------------------------------------------------------

module audio_fx_tremolo #(
    parameter int WIDTH = 16
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    sample_req,
    input  logic signed [WIDTH-1:0] in_l,
    input  logic signed [WIDTH-1:0] in_r,
    input  logic [1:0]              intensity,
    output logic signed [WIDTH-1:0] out_l,
    output logic signed [WIDTH-1:0] out_r
);

    // ~5 Hz at 44.1 kHz frames: rate = 5 * 2^24 / 44100 = 1903.
    localparam logic [23:0] RATE_5HZ = 24'd1903;

    //--------------------------------------------------------------------------
    // LFO and depth scaling
    //--------------------------------------------------------------------------
    logic signed [15:0] tri_wave;

    lfo lfo_inst (
        .clk        (clk),
        .rst        (rst),
        .sample_req (sample_req),
        .rate       (RATE_5HZ),
        .out        (tri_wave)
    );

    logic [1:0] depth_shift;
    assign depth_shift = 2'd3 - intensity;  // 0->subtle ... 3->full

    // Q1.16 gain, range (0, 1).
    logic signed [17:0] gain;
    assign gain = 18'sd32768 + ($signed(tri_wave) >>> depth_shift);

    //--------------------------------------------------------------------------
    // Gain application: 16x18 multiply, drop 16 fractional bits.
    //--------------------------------------------------------------------------
    logic signed [WIDTH+17:0] p_l, p_r;
    logic signed [WIDTH+17:0] y_l, y_r;
    assign p_l = in_l * gain;
    assign p_r = in_r * gain;
    assign y_l = p_l >>> 16;
    assign y_r = p_r >>> 16;

    always_ff @(posedge clk) begin
        if (rst) begin
            out_l <= '0;
            out_r <= '0;
        end else if (sample_req) begin
            out_l <= y_l[WIDTH-1:0];
            out_r <= y_r[WIDTH-1:0];
        end
    end

endmodule : audio_fx_tremolo
