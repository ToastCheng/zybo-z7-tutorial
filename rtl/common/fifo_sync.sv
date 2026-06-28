`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// fifo_sync.sv
// Parameterized synchronous FIFO.
//
// A first-in, first-out buffer implemented with on-chip memory.  Data written
// on one clock cycle is available for reading on later cycles.  The FIFO uses
// show-ahead behavior: `dout` always shows the oldest unread entry.
//------------------------------------------------------------------------------

module fifo_sync #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16
)(
    input  logic clk,
    input  logic rst,                       // synchronous active-high reset/clear

    // Write interface
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] din,
    output logic                  full,

    // Read interface
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] dout,
    output logic                  empty
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);

    // Storage.  Inferred as distributed or block RAM by the synthesis tool.
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers.  An extra wrap bit distinguishes full from empty when the
    // addresses are equal.
    logic [DATA_WIDTH-1:0] dout_reg = '0;

    logic [ADDR_WIDTH-1:0] wr_addr = '0;
    logic [ADDR_WIDTH-1:0] rd_addr = '0;
    logic                  wr_wrap = 1'b0;
    logic                  rd_wrap = 1'b0;

    // Status flags.
    assign full  = (wr_addr == rd_addr) && (wr_wrap != rd_wrap);
    assign empty = (wr_addr == rd_addr) && (wr_wrap == rd_wrap);

    // Registered read data.  The oldest entry is latched into `dout` when a
    // read is requested, and the read pointer advances on the same cycle.
    assign dout = dout_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_addr  <= '0;
            rd_addr  <= '0;
            wr_wrap  <= 1'b0;
            rd_wrap  <= 1'b0;
            dout_reg <= '0;
        end else begin
            // Write: store data and advance the write pointer.
            if (wr_en && !full) begin
                mem[wr_addr] <= din;

                if (wr_addr == ADDR_WIDTH'(DEPTH - 1)) begin
                    wr_addr <= '0;
                    wr_wrap <= ~wr_wrap;
                end else begin
                    wr_addr <= wr_addr + 1'b1;
                end
            end

            // Read: latch the oldest entry, then advance the read pointer.
            if (rd_en && !empty) begin
                dout_reg <= mem[rd_addr];

                if (rd_addr == ADDR_WIDTH'(DEPTH - 1)) begin
                    rd_addr <= '0;
                    rd_wrap <= ~rd_wrap;
                end else begin
                    rd_addr <= rd_addr + 1'b1;
                end
            end
        end
    end

endmodule : fifo_sync
