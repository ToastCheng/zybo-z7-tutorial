`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_envelope.sv
// Peak envelope follower: tracks how loud the signal is, smoothed.
//
//   rect[n] = |x[n]|
//   env[n]  = rect[n]                          if rect > env   (attack)
//           = env[n-1] - (env[n-1] >> RELEASE) otherwise       (release)
//
// Instant attack, exponential release - the classic analog envelope
// follower behaviour.  The release is a shift, not a multiply: with
// RELEASE_SHIFT = 7 the envelope falls by 1/128 per frame, a time constant
// of ~128 frames ~ 2.9 ms at 44.1 kHz.
//
// The full-wave rectifier saturates: |−32768| would overflow 16 bits, so
// it clamps to 32767 (a 0.003% error on one sample value - inaudible).
//
// Used by audio_fx_gate (feedforward: envelope of the *input*) and
// audio_fx_comp (feedback: envelope of the *output*).
//------------------------------------------------------------------------------

module audio_fx_envelope #(
    parameter int WIDTH         = 16,
    parameter int RELEASE_SHIFT = 7    // time constant ~ 2^RELEASE frames
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    sample_req,
    input  logic signed [WIDTH-1:0] sample_in,
    output logic        [WIDTH-1:0] env    // unsigned magnitude estimate
);

    // Saturating absolute value.
    logic [WIDTH-1:0] rect;
    always_comb begin
        if (sample_in == {1'b1, {(WIDTH-1){1'b0}}})
            rect = {1'b0, {(WIDTH-1){1'b1}}};   // |−full| clamps to +full
        else
            rect = sample_in[WIDTH-1] ? ~sample_in + 1'b1 : sample_in;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            env <= '0;
        end else if (sample_req) begin
            if (rect > env) begin
                env <= rect;                              // instant attack
            end else begin
                env <= env - (env >> RELEASE_SHIFT);      // exp. release
            end
        end
    end

endmodule : audio_fx_envelope
