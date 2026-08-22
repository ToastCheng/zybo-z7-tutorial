`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_fx_echo.sv
// Echo effect: BRAM delay line + dry/wet mixer.
//
// Both 16-bit channels are packed into one 32-bit word and written into a
// ring buffer once per audio frame (paced by `sample_req`).  The read
// pointer trails the write pointer by one slot, so the value read out was
// written exactly DEPTH frames ago:
//
//   delay = DEPTH / sample_rate   (16384 / 44100 Hz ~ 0.37 s)
//
// `intensity` selects the wet (echo) level:
//   0 -> 1/4,  1 -> 3/8,  2 -> 1/2,  3 -> 5/8
// The fractions are built from shifts and adds - no multiplier needed.
// The final dry + wet sum saturates to full scale.
//------------------------------------------------------------------------------

module audio_fx_echo #(
    parameter int WIDTH = 16,
    parameter int DEPTH = 16384       // must be a power of two
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

    // Ring buffer (infers block RAM).
    (* ram_style = "block" *)
    logic [2*WIDTH-1:0] mem [0:DEPTH-1];

    logic [AW-1:0]      wr_addr = '0;
    logic [2*WIDTH-1:0] rd_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_addr <= '0;
        end else if (sample_req) begin
            mem[wr_addr] <= {in_l, in_r};
            rd_data      <= mem[wr_addr + 1'b1]; // written DEPTH frames ago
            wr_addr      <= wr_addr + 1'b1;
        end
    end

    logic signed [WIDTH-1:0] del_l, del_r;
    assign {del_l, del_r} = rd_data;

    // Wet level from shifts and adds.
    logic signed [WIDTH-1:0] wet_l, wet_r;

    function automatic logic signed [WIDTH-1:0] wet_gain(
        input logic signed [WIDTH-1:0] s,
        input logic [1:0]              level
    );
        case (level)
            2'd0:    return s >>> 2;                    // 1/4
            2'd1:    return (s >>> 2) + (s >>> 3);      // 3/8
            2'd2:    return s >>> 1;                    // 1/2
            default: return (s >>> 1) + (s >>> 3);      // 5/8
        endcase
    endfunction

    assign wet_l = wet_gain(del_l, intensity);
    assign wet_r = wet_gain(del_r, intensity);

    // Saturating dry + wet mix.
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

    assign out_l = sat_add(in_l, wet_l);
    assign out_r = sat_add(in_r, wet_r);

endmodule : audio_fx_echo
