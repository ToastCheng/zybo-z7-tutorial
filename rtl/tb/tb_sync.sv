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

    // Error counter.
    int error_count;

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

        error_count = 0;
        din = 0;

        // Wait for the initial state to propagate.
        @(negedge clk);
        @(negedge clk);
        if (dout !== 0) begin
            $error("Expected dout = 0 initially");
            error_count++;
        end

        // Change din and verify it appears at dout two cycles later.
        din = 1;
        @(negedge clk);
        if (dout !== 0) begin
            $error("dout should still be 0 after 1 cycle");
            error_count++;
        end
        @(negedge clk);
        if (dout !== 1) begin
            $error("dout should be 1 after 2 cycles");
            error_count++;
        end

        // Change din back to 0 and verify the delay.
        din = 0;
        @(negedge clk);
        if (dout !== 1) begin
            $error("dout should still be 1 after 1 cycle");
            error_count++;
        end
        @(negedge clk);
        if (dout !== 0) begin
            $error("dout should be 0 after 2 cycles");
            error_count++;
        end

        // Verify dout is always a clean digital value (not X or Z).
        if (dout === 1'bx || dout === 1'bz) begin
            $error("dout is not a clean digital value");
            error_count++;
        end

        if (error_count == 0) begin
            $display("sync testbench passed.");
        end else begin
            $display("sync testbench failed with %0d errors.", error_count);
        end
        $finish;
    end

endmodule : tb_sync
