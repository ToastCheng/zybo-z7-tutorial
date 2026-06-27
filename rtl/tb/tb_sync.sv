//------------------------------------------------------------------------------
// tb_sync.sv
// Testbench for the sync module.
//
// Verifies that the output is a 2-cycle delayed version of the input,
// and that the output is always a clean 0 or 1.
//
// Note: metastability itself cannot be reliably simulated, because the
// simulator models flip-flops as ideal digital elements. This testbench
// demonstrates the latency and signal shape of the synchronizer.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_sync;

    logic clk;
    logic din;
    logic dout;

    // Instantiate the DUT with default 2 stages.
    sync dut (
        .clk  (clk),
        .din  (din),
        .dout (dout)
    );

    // Generate a 125 MHz clock.
    initial begin
        clk = 0;
        forever #4 clk = ~clk;
    end

    // Test stimulus.
    initial begin
        $display("Starting sync testbench...");

        din = 0;

        // Wait for the initial state to propagate.
        @(posedge clk);
        @(posedge clk);
        if (dout !== 0) $error("Expected dout = 0 initially");

        // Change din and verify it appears at dout two cycles later.
        din = 1;
        @(posedge clk);
        if (dout !== 0) $error("dout should still be 0 after 1 cycle");
        @(posedge clk);
        if (dout !== 1) $error("dout should be 1 after 2 cycles");

        // Change din back to 0 and verify the delay.
        din = 0;
        @(posedge clk);
        if (dout !== 1) $error("dout should still be 1 after 1 cycle");
        @(posedge clk);
        if (dout !== 0) $error("dout should be 0 after 2 cycles");

        // Verify dout is always a clean digital value (not X or Z).
        if (dout === 1'bx || dout === 1'bz) $error("dout is not a clean digital value");

        $display("sync testbench passed.");
        $finish;
    end

endmodule : tb_sync
