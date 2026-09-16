`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_biquad.sv
// Second-order IIR ("biquad") filter effect.
//
// A biquad implements the recurrence
//
//   y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] + a1*y[n-1] + a2*y[n-2]
//
// NOTE: the a-coefficients are stored already negated, so all five terms
// simply add.  (In the textbook form they are subtracted.)
//
// Four preset filters are selected by `intensity`:
//
//   0 -> low-pass, 1 -> high-pass, 2 -> band-pass, 3 -> notch
//
// All presets have fc = 1 kHz and Q = 0.707 (Butterworth, maximally flat)
// at the 44.1 kHz sample rate used by the audio pipeline.
//
// Fixed-point format: coefficients are signed 18-bit Q2.16 (sign + 1 integer
// bit + 16 fractional bits), covering the -2..+2 range biquad coefficients
// need.  A 16x18-bit signed product fits one DSP48 multiplier, and the
// 48-bit accumulator matches the DSP48 accumulator width.
//
// The filter state advances only when `sample_req` pulses (once per audio
// frame), so the combinational multiply-accumulate has ~256 MCLK cycles to
// settle.  Output is registered on the strobe; one frame of latency.
//------------------------------------------------------------------------------

module audio_fx_biquad #(
    parameter int WIDTH = 16    // audio sample width
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    sample_req,   // 1-cycle strobe, frame rate
    input  logic signed [WIDTH-1:0] sample_in,
    input  logic [1:0]              intensity,    // 0 LP, 1 HP, 2 BP, 3 notch
    output logic signed [WIDTH-1:0] sample_out
);

    localparam int COEF_W = 18;             // Q2.16 coefficients
    localparam int FRAC   = COEF_W - 2;     // fractional bits
    localparam int PROD_W = WIDTH + COEF_W; // 16x18 -> 34 bits
    localparam int ACC_W  = 48;             // DSP48 accumulator width

    localparam logic signed [WIDTH-1:0] SAT_POS = {1'b0, {(WIDTH-1){1'b1}}};
    localparam logic signed [WIDTH-1:0] SAT_NEG = {1'b1, {(WIDTH-1){1'b0}}};

    //--------------------------------------------------------------------------
    // Coefficient LUT, Q2.16 recurrence form (a-coefficients pre-negated).
    // Computed with the RBJ audio-EQ cookbook at fs = 44.1 kHz, fc = 1 kHz,
    // Q = 1/sqrt(2).  See audio_fx_biquad.md for the formulas.
    //--------------------------------------------------------------------------
    logic signed [COEF_W-1:0] b0, b1, b2, a1, a2;

    always_comb begin
        case (intensity)
            2'd0: begin  // low-pass
                b0 =  18'sd302;    b1 =  18'sd603;    b2 =  18'sd302;
                a1 =  18'sd117906; a2 = -18'sd53576;
            end
            2'd1: begin  // high-pass
                b0 =  18'sd59255;  b1 = -18'sd118509; b2 =  18'sd59255;
                a1 =  18'sd117906; a2 = -18'sd53576;
            end
            2'd2: begin  // band-pass (constant 0 dB peak gain)
                b0 =  18'sd5980;   b1 =  18'sd0;      b2 = -18'sd5980;
                a1 =  18'sd117906; a2 = -18'sd53576;
            end
            default: begin  // notch
                b0 =  18'sd59556;  b1 = -18'sd117906; b2 =  18'sd59556;
                a1 =  18'sd117906; a2 = -18'sd53576;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Filter state: two-sample delay lines for x and y.
    //--------------------------------------------------------------------------
    logic signed [WIDTH-1:0] x1, x2, y1, y2;

    //--------------------------------------------------------------------------
    // Multiply-accumulate (combinational; latched on sample_req).
    //--------------------------------------------------------------------------
    logic signed [PROD_W-1:0] p_b0, p_b1, p_b2, p_a1, p_a2;

    assign p_b0 = sample_in * b0;
    assign p_b1 = x1        * b1;
    assign p_b2 = x2        * b2;
    assign p_a1 = y1        * a1;
    assign p_a2 = y2        * a2;

    logic signed [ACC_W-1:0] acc;
    assign acc = ACC_W'(p_b0) + ACC_W'(p_b1) + ACC_W'(p_b2)
               + ACC_W'(p_a1) + ACC_W'(p_a2);

    // Drop the 16 fractional bits to get back to an integer sample.
    logic signed [ACC_W-1:0] y_full;
    assign y_full = acc >>> FRAC;

    //--------------------------------------------------------------------------
    // State update and output saturation, once per audio frame.
    // The saturated value (not the raw accumulator) feeds back into y1, so
    // the filter recovers cleanly after an overload instead of latching up.
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            x1         <= '0;
            x2         <= '0;
            y1         <= '0;
            y2         <= '0;
            sample_out <= '0;
        end else if (sample_req) begin
            x1 <= sample_in;
            x2 <= x1;
            y2 <= y1;
            if (y_full > ACC_W'(SAT_POS)) begin
                y1         <= SAT_POS;
                sample_out <= SAT_POS;
            end else if (y_full < ACC_W'(SAT_NEG)) begin
                y1         <= SAT_NEG;
                sample_out <= SAT_NEG;
            end else begin
                y1         <= y_full[WIDTH-1:0];
                sample_out <= y_full[WIDTH-1:0];
            end
        end
    end

endmodule : audio_fx_biquad
