`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_chorus.sv
// Chorus / flanger / vibrato: a delay line whose tap is modulated by an LFO.
//
// Mixing a signal with a slightly delayed copy of itself creates moving
// comb-filter notches; sweeping the delay with a slow LFO makes them "swim".
// The same structure with different parameters gives three classic effects:
//
//   intensity 0: chorus      15 ms +- 6 ms, 0.5 Hz, dry + wet/2
//   intensity 1: flanger      3 ms +- 3 ms, 0.25 Hz, dry + wet/2
//   intensity 2: vibrato     10 ms +- 6 ms, 5 Hz,   wet only
//   intensity 3: slow chorus 15 ms +- 6 ms, 0.2 Hz, dry + wet/2
//
// Delay times are in frames at 44.1 kHz (1 ms ~ 44.1 frames).  The tap
// offset is the LFO output shifted right (power-of-two scaling, no
// multiplier): tri_wave >>> 7 gives +-256 frames (~+-5.8 ms).
//
// The tap moves in 1-frame steps (~23 us).  At these slow rates the steps
// are inaudible; true fractional interpolation is left as an exercise.
//------------------------------------------------------------------------------

module audio_fx_chorus #(
    parameter int WIDTH = 16,
    parameter int DEPTH = 2048        // frames (~46 ms); power of two
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

    localparam int AW = $clog2(DEPTH);

    //--------------------------------------------------------------------------
    // Presets: base delay, LFO depth (shift), LFO rate, dry/wet mode
    //--------------------------------------------------------------------------
    logic [AW-1:0] base;
    logic [3:0]     depth_shift;
    logic [23:0]    rate;
    logic           wet_only;

    always_comb begin
        case (intensity)
            2'd0: begin  // chorus
                base = 11'd662;  depth_shift = 4'd7;  rate = 24'd190;  wet_only = 1'b0;
            end
            2'd1: begin  // flanger
                base = 11'd132;  depth_shift = 4'd8;  rate = 24'd95;   wet_only = 1'b0;
            end
            2'd2: begin  // vibrato
                base = 11'd441;  depth_shift = 4'd7;  rate = 24'd1903; wet_only = 1'b1;
            end
            default: begin  // slow chorus
                base = 11'd662;  depth_shift = 4'd7;  rate = 24'd76;   wet_only = 1'b0;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // LFO -> modulated tap
    //--------------------------------------------------------------------------
    logic signed [15:0] tri_wave;

    lfo lfo_inst (
        .clk        (clk),
        .rst        (rst),
        .sample_req (sample_req),
        .rate       (rate),
        .out        (tri_wave)
    );

    // tap = base + (tri_wave >>> depth_shift).  Presets guarantee
    // 1 <= tap <= DEPTH-2, so the truncated slice is safe.
    logic signed [16:0] tap_full;
    logic [AW-1:0]      tap;

    assign tap_full = $signed({1'b0, base}) + ($signed(tri_wave) >>> depth_shift);
    assign tap      = tap_full[AW-1:0];

    //--------------------------------------------------------------------------
    // Delay line
    //--------------------------------------------------------------------------
    logic signed [WIDTH-1:0] del_l, del_r;

    audio_delay_line #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dline (
        .clk        (clk),
        .rst        (rst),
        .sample_req (sample_req),
        .in_l       (in_l),
        .in_r       (in_r),
        .tap        (tap),
        .out_l      (del_l),
        .out_r      (del_r)
    );

    //--------------------------------------------------------------------------
    // Dry/wet mix (wet at 1/2 via shift; saturating add like audio_fx_echo)
    //--------------------------------------------------------------------------
    function automatic logic signed [WIDTH-1:0] sat_add(
        input logic signed [WIDTH-1:0] a,
        input logic signed [WIDTH-1:0] b
    );
        logic signed [WIDTH:0] sum;
        sum = a + b;
        if (sum > $signed({1'b0, {(WIDTH-1){1'b1}}}))
            return {1'b0, {(WIDTH-1){1'b1}}};
        if (sum < $signed({1'b1, {(WIDTH-1){1'b0}}}))
            return {1'b1, {(WIDTH-1){1'b0}}};
        return sum[WIDTH-1:0];
    endfunction

    always_comb begin
        if (wet_only) begin
            out_l = del_l;
            out_r = del_r;
        end else begin
            out_l = sat_add(in_l, del_l >>> 1);
            out_r = sat_add(in_r, del_r >>> 1);
        end
    end

endmodule : audio_fx_chorus
