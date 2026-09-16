`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_gate.sv
// Noise gate: silence below a threshold, pass above it.
//
// The envelope of the LEFT channel decides the gate for both channels
// (one shared gain keeps the stereo image intact).  Hysteresis prevents
// chattering at the threshold: the gate opens at `open_thr` but only
// closes again below `open_thr / 2`.
//
// The gain itself ramps instead of switching - fast up (~8 frame time
// constant), slow down (~64 frames) - so the gate never clicks:
//
//   gain -> 32768 (unity)  when open,  gain -> 0 when closed
//   out = (sample * gain) >>> 15
//
// Threshold presets (full scale = 32767):
//   intensity 0 -> 104  (-50 dB)   1 -> 328  (-40 dB)
//           2 -> 1036 (-30 dB)     3 -> 3277 (-20 dB)
//
// One 16x17 multiply per channel (one DSP48 each).  gain <= 32768 means
// |out| <= |in| - no overflow possible.
//------------------------------------------------------------------------------

module audio_fx_gate #(
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
    // Threshold presets
    //--------------------------------------------------------------------------
    logic [WIDTH-1:0] open_thr;
    always_comb begin
        case (intensity)
            2'd0:    open_thr = 16'd104;    // -50 dB
            2'd1:    open_thr = 16'd328;    // -40 dB
            2'd2:    open_thr = 16'd1036;   // -30 dB
            default: open_thr = 16'd3277;   // -20 dB
        endcase
    end
    logic [WIDTH-1:0] close_thr;
    assign close_thr = open_thr >> 1;       // hysteresis band

    //--------------------------------------------------------------------------
    // Envelope of the input (left channel decides for both)
    //--------------------------------------------------------------------------
    logic [WIDTH-1:0] env;

    audio_fx_envelope env_inst (
        .clk        (clk),
        .rst        (rst),
        .sample_req (sample_req),
        .sample_in  (in_l),
        .env        (env)
    );

    //--------------------------------------------------------------------------
    // Gate state (hysteresis) and gain ramp
    //--------------------------------------------------------------------------
    logic              gate_open = 1'b0;
    logic [WIDTH:0]    gain      = '0;      // 0..UNITY

    always_ff @(posedge clk) begin
        if (rst) begin
            gate_open <= 1'b0;
            gain      <= '0;
        end else if (sample_req) begin
            if (!gate_open && env > open_thr)       gate_open <= 1'b1;
            else if (gate_open && env < close_thr)  gate_open <= 1'b0;

            // Ramp toward the target; the +1 guarantees the ramp actually
            // reaches it instead of stalling on an asymptote.
            if (gate_open && gain < UNITY) begin
                gain <= gain + ((UNITY - gain) >> 3) + 1'b1;
            end else if (!gate_open && gain > 0) begin
                gain <= gain - (gain >> 6) - 1'b1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Gain application
    //--------------------------------------------------------------------------
    logic signed [WIDTH+17:0] p_l, p_r;
    logic signed [WIDTH+17:0] y_l, y_r;

    assign p_l = in_l * $signed({1'b0, gain});
    assign p_r = in_r * $signed({1'b0, gain});
    assign y_l = p_l >>> (WIDTH-1);
    assign y_r = p_r >>> (WIDTH-1);

    always_ff @(posedge clk) begin
        if (rst) begin
            out_l <= '0;
            out_r <= '0;
        end else if (sample_req) begin
            out_l <= y_l[WIDTH-1:0];
            out_r <= y_r[WIDTH-1:0];
        end
    end

endmodule : audio_fx_gate
