`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_uart_tx.sv
// Testbench for the uart_tx module.
//
// Transmits a byte and verifies the serial frame on the tx line.
//------------------------------------------------------------------------------

module tb_uart_tx;

    localparam int CLK_FREQ_HZ = 1_000_000;
    localparam int BAUD_RATE   = 100_000;
    localparam int TICKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;  // 10

    logic clk;
    logic start;
    logic [7:0] data;
    logic tx;
    logic busy;

    int error_count;
    logic [9:0] captured_frame;

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) dut (
        .clk   (clk),
        .start (start),
        .data  (data),
        .tx    (tx),
        .busy  (busy)
    );

    // Fast clock for simulation.
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    initial begin
        $display("Starting uart_tx testbench...");

        error_count = 0;
        start = 0;
        data  = 8'h00;

        @(negedge clk);

        // Test byte 0xA5 = 8'b1010_0101.
        data = 8'hA5;
        start = 1;
        @(negedge clk);
        start = 0;

        // The start bit begins on the posedge following the start pulse.
        // Wait one bit time (start bit) plus half a bit time to reach the
        // center of the first data bit.
        wait_cycles(TICKS_PER_BIT + TICKS_PER_BIT / 2);

        // Capture the 8 data bits at their centers, LSB first.
        captured_frame = '0;
        for (int i = 0; i < 8; i++) begin
            captured_frame[i] = tx;
            wait_cycles(TICKS_PER_BIT);
        end

        // Capture stop bit at its center.
        captured_frame[8] = tx;

        if (captured_frame[8] !== 1'b1) begin
            $error("Expected stop bit = 1, got %b", captured_frame[8]);
            error_count++;
        end

        if (captured_frame[7:0] !== 8'hA5) begin
            $error("Expected data = 0xA5, got 0x%02x (LSB-first captured)", captured_frame[7:0]);
            error_count++;
        end

        // Wait for the transmitter to return to idle.
        wait (!busy);
        @(negedge clk);

        if (tx !== 1'b1) begin
            $error("Expected tx idle high after transmission");
            error_count++;
        end

        if (error_count == 0) begin
            $display("uart_tx testbench passed.");
        end else begin
            $display("uart_tx testbench failed with %0d errors.", error_count);
        end
        $finish;
    end

endmodule : tb_uart_tx
