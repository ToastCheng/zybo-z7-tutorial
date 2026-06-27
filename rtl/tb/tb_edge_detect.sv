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

    // Synchronous reset for the pulse-capture flags.
    logic reset_flags;

    // Flags to record whether a pulse was seen.
    logic rising_seen;
    logic falling_seen;

    // Error counter.
    int error_count;

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

    // Capture pulses in registers. Because `rising` and `falling` are each
    // high for only one clock cycle, we latch them so we can check after
    // the cycle has passed.
    always_ff @(posedge clk) begin
        if (reset_flags) begin
            rising_seen  <= 0;
            falling_seen <= 0;
        end else begin
            if (rising)  rising_seen  <= 1;
            if (falling) falling_seen <= 1;
        end
    end

    // Test stimulus.
    initial begin
        $display("Starting edge_detect testbench...");

        error_count = 0;
        reset_flags = 1;
        din = 0;

        // Wait for a few clock cycles to ensure the DUT is stable.
        @(negedge clk);
        @(negedge clk);

        // Create a rising edge on din.
        reset_flags = 0;
        din = 1;

        // Wait for the pulse to occur and the flag to latch, then check in
        // the middle of the following cycle (negedge) to avoid race conditions.
        @(negedge clk);
        @(negedge clk);
        if (rising_seen !== 1) begin
            $error("Expected rising pulse after rising edge");
            error_count++;
        end
        if (falling_seen !== 0) begin
            $error("Unexpected falling pulse");
            error_count++;
        end

        // Hold din high for a few cycles. No new edges should appear.
        repeat (3) @(negedge clk);

        // Reset the flags and create a falling edge.
        reset_flags = 1;
        @(negedge clk);
        reset_flags = 0;
        din = 0;
        @(negedge clk);
        @(negedge clk);
        if (falling_seen !== 1) begin
            $error("Expected falling pulse after falling edge");
            error_count++;
        end
        if (rising_seen !== 0) begin
            $error("Unexpected rising pulse");
            error_count++;
        end

        if (error_count == 0) begin
            $display("edge_detect testbench passed.");
        end else begin
            $display("edge_detect testbench failed with %0d errors.", error_count);
        end
        $finish;
    end

endmodule : tb_edge_detect
