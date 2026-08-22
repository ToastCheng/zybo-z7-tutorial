`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_distortion.sv
// Distortion / fuzz effect: amplify, then hard-clip.
//
// Multiplies the sample by a power-of-two gain selected by `intensity`:
//   0 -> x2, 1 -> x4, 2 -> x8, 3 -> x16
// and saturates the result to the full-scale range.  The flat tops created
// by clipping add the harmonics that make the "fuzz" sound.
//
// The output is registered; one clock cycle of latency is irrelevant at
// audio sample rates.
//------------------------------------------------------------------------------

module audio_fx_distortion #(
    parameter int WIDTH = 16
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic signed [WIDTH-1:0] sample_in,
    input  logic [1:0]              intensity,
    output logic signed [WIDTH-1:0] sample_out
);

    localparam logic signed [WIDTH-1:0] SAT_POS = {1'b0, {(WIDTH-1){1'b1}}};
    localparam logic signed [WIDTH-1:0] SAT_NEG = {1'b1, {(WIDTH-1){1'b0}}};

    // Gain as a left shift: 1..4 -> x2, x4, x8, x16.
    logic [2:0] shift;
    assign shift = {1'b0, intensity} + 3'd1;

    // Widened intermediate so the amplified value cannot overflow.
    logic signed [WIDTH+4:0] scaled;
    assign scaled = sample_in <<< shift;

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_out <= '0;
        end else if (scaled > SAT_POS) begin
            sample_out <= SAT_POS;
        end else if (scaled < $signed(SAT_NEG)) begin
            sample_out <= SAT_NEG;
        end else begin
            sample_out <= scaled[WIDTH-1:0];
        end
    end

endmodule : audio_fx_distortion
