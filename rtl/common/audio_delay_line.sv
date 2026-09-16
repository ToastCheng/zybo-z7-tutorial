`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_delay_line.sv
// Stereo BRAM delay line with a variable read tap.
//
// Both 16-bit channels are packed into one 32-bit word and written into a
// ring buffer once per audio frame (paced by `sample_req`).  The read
// address trails the write address by `tap` frames, so the value read out
// was written exactly `tap` frames ago:
//
//   delay = tap / sample_rate
//
// Unlike audio_fx_echo (fixed full-depth delay), `tap` is a port, so the
// delay can be modulated at run time - e.g. by an LFO for chorus/flanger.
// `tap` may change between frames; AW-bit address arithmetic wraps modulo
// DEPTH naturally.  tap = 0 reads the slot about to be overwritten, i.e.
// effectively DEPTH frames of delay - use tap >= 1.
//
// The read is synchronous (BRAM): the outputs update one clock after
// `sample_req`, adding one frame of latency.
//------------------------------------------------------------------------------

module audio_delay_line #(
    parameter int WIDTH = 16,
    parameter int DEPTH = 2048        // must be a power of two
)(
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      sample_req,
    input  logic signed [WIDTH-1:0]   in_l,
    input  logic signed [WIDTH-1:0]   in_r,
    input  logic [$clog2(DEPTH)-1:0]  tap,    // frames of delay, 1..DEPTH-1
    output logic signed [WIDTH-1:0]   out_l,
    output logic signed [WIDTH-1:0]   out_r
);

    localparam int AW = $clog2(DEPTH);

    // Ring buffer (infers block RAM).
    (* ram_style = "block" *)
    logic [2*WIDTH-1:0] mem [0:DEPTH-1];

    logic [AW-1:0]      wr_addr = '0;
    logic [AW-1:0]      rd_addr;
    logic [2*WIDTH-1:0] rd_data;

    // AW-bit subtraction wraps modulo DEPTH for free.
    assign rd_addr = wr_addr - tap;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_addr <= '0;
        end else if (sample_req) begin
            mem[wr_addr] <= {in_l, in_r};
            rd_data      <= mem[rd_addr];
            wr_addr      <= wr_addr + 1'b1;
        end
    end

    assign {out_l, out_r} = rd_data;

endmodule : audio_delay_line
