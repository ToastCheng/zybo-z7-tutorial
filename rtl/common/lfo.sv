`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// lfo.sv
// Low-frequency oscillator for modulation effects (chorus, tremolo, ...).
//
// A 24-bit phase accumulator advances by `rate` once per audio frame
// (paced by `sample_req`):
//
//   frequency = rate * sample_rate / 2^24
//
// At 44.1 kHz: rate = 190 -> 0.5 Hz (chorus), rate = 1903 -> 5 Hz
// (tremolo/vibrato).
//
// The waveform is a triangle derived from the phase bits: the MSB selects
// rising/falling, the next 16 bits are the slope.  Offset binary is
// converted to two's complement by flipping the sign bit, giving a signed
// Q1.15 output in [-1, +1).  No lookup table and no multipliers.
//
// A triangle sounds nearly identical to a sine for slow modulation; the
// difference is the slightly constant-rate sweep at the peaks.  Swapping
// in a sine LUT is left as an exercise (see lfo.md).
//------------------------------------------------------------------------------

module lfo (
    input  logic             clk,
    input  logic             rst,
    input  logic             sample_req,   // 1-cycle strobe, frame rate
    input  logic [23:0]      rate,         // phase increment per frame
    output logic signed [15:0] out         // triangle, Q1.15
);

    logic [23:0] phase = '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            phase <= '0;
        end else if (sample_req) begin
            phase <= phase + rate;
        end
    end

    // Triangle: rising ramp while phase MSB is 0, falling while 1.
    logic [15:0] tri_wave;
    assign tri_wave = phase[23] ? ~phase[22:7] : phase[22:7];

    // Offset binary -> two's complement.
    assign out = $signed(tri_wave ^ 16'h8000);

endmodule : lfo
