//------------------------------------------------------------------------------
// tb_edge_detect.sv
// Testbench for the edge_detect module.
//
// Verifies that a rising edge produces a one-cycle pulse on `rising`,
// and a falling edge produces a one-cycle pulse on `falling`.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_edge_detect;

    // Signals connected to the Device Under Test (DUT).
    logic clk;
    logic din;
    logic rising;
    logic falling;

    // Instantiate the DUT.
    edge_detect dut (
        .clk     (clk),
        .din     (din),
        .rising  (rising),
        .falling (falling)
    );

    // Generate a 125 MHz clock (8 ns period).
    initial begin
        clk = 0;
        forever #4 clk = ~clk;
    end

    // Test stimulus.
    initial begin
        $display("Starting edge_detect testbench...");

        din = 0;

        // Wait for a few clock cycles to ensure the DUT is stable.
        @(posedge clk);
        @(posedge clk);

        // Create a rising edge on din.
        din = 1;
        @(posedge clk);
        if (rising !== 1) $error("Expected rising pulse after rising edge");
        if (falling !== 0) $error("Unexpected falling pulse");

        // On the next cycle, rising should be low again.
        @(posedge clk);
        if (rising !== 0) $error("rising pulse should last only one cycle");
        if (falling !== 0) $error("Unexpected falling pulse");

        // Hold din high for a few cycles.
        repeat (3) @(posedge clk);

        // Create a falling edge on din.
        din = 0;
        @(posedge clk);
        if (falling !== 1) $error("Expected falling pulse after falling edge");
        if (rising !== 0) $error("Unexpected rising pulse");

        // On the next cycle, falling should be low again.
        @(posedge clk);
        if (falling !== 0) $error("falling pulse should last only one cycle");
        if (rising !== 0) $error("Unexpected rising pulse");

        $display("edge_detect testbench passed.");
        $finish;
    end

endmodule : tb_edge_detect
