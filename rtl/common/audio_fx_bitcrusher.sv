`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_bitcrusher.sv
// Lo-fi bit-crusher effect.
//
// Zeroes the least significant bits of each sample, reducing the effective
// resolution.  The number of discarded bits is selected by `intensity`:
//   0 -> keep 12 bits, 1 -> keep 8 bits, 2 -> keep 6 bits, 3 -> keep 4 bits
//
// Implemented with a signed arithmetic shift right followed by a logical
// shift left, so the sign bit is preserved.  Purely combinational.
//------------------------------------------------------------------------------

module audio_fx_bitcrusher #(
    parameter int WIDTH = 16
)(
    input  logic signed [WIDTH-1:0] sample_in,
    input  logic [1:0]              intensity,
    output logic signed [WIDTH-1:0] sample_out
);

    // Number of LSBs to discard.
    logic [3:0] shift;

    always_comb begin
        case (intensity)
            2'd0:    shift = 4'd4;    // keep 12 bits
            2'd1:    shift = 4'd8;    // keep 8 bits
            2'd2:    shift = 4'd10;   // keep 6 bits
            default: shift = 4'd12;   // keep 4 bits
        endcase
    end

    assign sample_out = (sample_in >>> shift) <<< shift;

endmodule : audio_fx_bitcrusher
