`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_comp.sv
// Compressor / limiter built as a feedback AGC.
//
// A textbook compressor computes gain = f(env) with a division; division
// in hardware is expensive.  This module sidesteps it with FEEDBACK: the
// envelope follower watches the *output*, and the gain walks up or down
// every frame until the output envelope sits at the target level:
//
//   env(out) > target : gain -= (env - target) >> 4   (attack, ~fast)
//   env(out) < target : gain += (UNITY - gain) >> 9   (release, ~slow)
//
// The loop settles where env(out) ~ target - loud inputs get attenuated,
// quiet ones pass at unity gain (a compressor with infinite:1 ratio above
// the target, i.e. a limiter, plus gentle upward recovery).
//
// The `+ 1` term in the attack guarantees progress even when the shift
// rounds to zero; the resulting +-1 LSB gain dither around the target is
// ~0.003% and inaudible.
//
// Target presets (full scale = 32767):
//   intensity 0 -> 16384 (-6 dB)   1 -> 8192 (-12 dB)
//           2 -> 4096  (-18 dB)    3 -> 2048 (-24 dB)
//
// One 16x17 multiply per channel (one DSP48 each).  gain <= UNITY means
// |out| <= |in| - no overflow possible.
//------------------------------------------------------------------------------

module audio_fx_comp #(
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

    localparam int UNITY = 1 << (WIDTH-1);   // 32768 = gain of 1.0

    //--------------------------------------------------------------------------
    // Target level presets
    //--------------------------------------------------------------------------
    logic [WIDTH-1:0] target;
    always_comb begin
        case (intensity)
            2'd0:    target = 16'd16384;    // -6 dB
            2'd1:    target = 16'd8192;     // -12 dB
            2'd2:    target = 16'd4096;     // -18 dB
            default: target = 16'd2048;     // -24 dB
        endcase
    end

    //--------------------------------------------------------------------------
    // Gain application (combinational from the current gain register)
    //--------------------------------------------------------------------------
    logic [WIDTH:0] gain;                    // 0..UNITY

    logic signed [WIDTH+17:0] p_l, p_r;
    logic signed [WIDTH+17:0] y_l, y_r;

    assign p_l = in_l * $signed({1'b0, gain});
    assign p_r = in_r * $signed({1'b0, gain});
    assign y_l = p_l >>> (WIDTH-1);
    assign y_r = p_r >>> (WIDTH-1);

    //--------------------------------------------------------------------------
    // Feedback: envelope of the OUTPUT drives the gain loop
    //--------------------------------------------------------------------------
    logic [WIDTH-1:0] env;
    logic [WIDTH:0]   step;

    audio_fx_envelope env_inst (
        .clk        (clk),
        .rst        (rst),
        .sample_req (sample_req),
        .sample_in  (y_l[WIDTH-1:0]),
        .env        (env)
    );

    always_comb begin
        step = (({1'b0, env} - {1'b0, target}) >> 4) + 1'b1;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            gain  <= {2'b01, {(WIDTH-1){1'b0}}};   // UNITY
            out_l <= '0;
            out_r <= '0;
        end else if (sample_req) begin
            out_l <= y_l[WIDTH-1:0];
            out_r <= y_r[WIDTH-1:0];

            if (env > target && gain > 0) begin
                // Attack: proportional step down, +1 guarantees progress.
                gain <= (gain > step) ? gain - step : '0;
            end else if (env < target && gain < UNITY) begin
                // Release: exponential return toward unity.  Deliberately
                // much finer than the attack step - a coarse release step
                // makes the loop ratchet far past the target (measured in
                // tb_audio_fx_dyn as a ~40% overshoot with >> 6).
                gain <= gain + ((UNITY - gain) >> 9) + 1'b1;
            end
        end
    end

endmodule : audio_fx_comp
