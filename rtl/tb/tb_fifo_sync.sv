`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_fifo_sync.sv
// Testbench for the synchronous FIFO.
//------------------------------------------------------------------------------

module tb_fifo_sync;

    localparam int DATA_WIDTH = 4;
    localparam int DEPTH      = 4;
    localparam int CLK_PERIOD = 8;

    logic clk = 1'b0;
    logic rst;
    logic wr_en;
    logic [DATA_WIDTH-1:0] din;
    logic full;
    logic rd_en;
    logic [DATA_WIDTH-1:0] dout;
    logic empty;

    // Read data captured by the testbench.
    logic [DATA_WIDTH-1:0] rdata;

    fifo_sync #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) dut (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (wr_en),
        .din    (din),
        .full   (full),
        .rd_en  (rd_en),
        .dout   (dout),
        .empty  (empty)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic write(input logic [DATA_WIDTH-1:0] data);
        begin
            din   = data;
            wr_en = 1'b1;
            @(posedge clk);
            wr_en = 1'b0;
        end
    endtask

    task automatic read(output logic [DATA_WIDTH-1:0] data);
        begin
            rd_en = 1'b1;
            @(posedge clk);
            rd_en = 1'b0;
            data = dout;
        end
    endtask

    initial begin
        $dumpfile("tb_fifo_sync.vcd");
        $dumpvars(0, tb_fifo_sync);

        rst   <= 1'b1;
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        din   <= '0;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        repeat (1) @(posedge clk);

        // Check reset state.
        if (!empty) $error("FIFO should be empty after reset");
        if (full)   $error("FIFO should not be full after reset");

        // Write a few values.
        write(4'h1);
        write(4'h2);
        write(4'h3);

        if (empty) $error("FIFO should not be empty after writes");

        // Read them back and verify order.
        read(rdata); if (rdata !== 4'h1) $error("Expected 1, got %h", rdata);
        read(rdata); if (rdata !== 4'h2) $error("Expected 2, got %h", rdata);
        read(rdata); if (rdata !== 4'h3) $error("Expected 3, got %h", rdata);

        if (!empty) $error("FIFO should be empty after reading all entries");

        // Fill to capacity and check full flag.
        write(4'hA);
        write(4'hB);
        write(4'hC);
        write(4'hD);
        if (!full) $error("FIFO should be full after DEPTH writes");

        // A write while full should be ignored.
        write(4'hE);
        if (!full) $error("FIFO should still be full after ignored write");

        // Read one, then write one to test wrap-around behavior.
        read(rdata); if (rdata !== 4'hA) $error("Expected A, got %h", rdata);
        write(4'hE);
        if (!full) $error("FIFO should be full again");

        read(rdata); if (rdata !== 4'hB) $error("Expected B, got %h", rdata);
        read(rdata); if (rdata !== 4'hC) $error("Expected C, got %h", rdata);
        read(rdata); if (rdata !== 4'hD) $error("Expected D, got %h", rdata);
        read(rdata); if (rdata !== 4'hE) $error("Expected E, got %h", rdata);

        if (!empty) $error("FIFO should be empty at end");

        $display("FIFO testbench passed.");
        $finish;
    end

endmodule
