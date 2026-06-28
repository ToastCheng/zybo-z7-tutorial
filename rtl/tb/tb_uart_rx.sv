`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_uart_rx.sv
// Testbench for the uart_rx module.
//
// Generates UART frames from the testbench and verifies the received bytes.
//------------------------------------------------------------------------------

module tb_uart_rx;

    localparam int CLK_FREQ_HZ = 1_000_000;
    localparam int BAUD_RATE   = 100_000;
    localparam int TICKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;  // 10

    logic clk;
    logic rx;
    logic [7:0] data;
    logic valid;

    int error_count;

    // Record that a valid byte was received.
    logic first_valid;
    logic second_valid;

    always_ff @(posedge clk) begin
        if (valid && !first_valid) begin
            first_valid <= 1'b1;
        end else if (valid && first_valid && !second_valid) begin
            second_valid <= 1'b1;
        end
    end

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) dut (
        .clk   (clk),
        .rx    (rx),
        .data  (data),
        .valid (valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    task automatic send_byte(input logic [7:0] val);
        begin
            // Start bit.
            rx = 1'b0;
            repeat (TICKS_PER_BIT) @(posedge clk);

            // Data bits, LSB first.
            for (int i = 0; i < 8; i++) begin
                rx = val[i];
                repeat (TICKS_PER_BIT) @(posedge clk);
            end

            // Stop bit.
            rx = 1'b1;
            repeat (TICKS_PER_BIT) @(posedge clk);
        end
    endtask

    initial begin
        $display("Starting uart_rx testbench...");

        error_count = 0;
        rx = 1'b1;  // idle

        @(negedge clk);
        @(negedge clk);

        // Send byte 0xA5 = 8'b1010_0101.
        send_byte(8'hA5);
        @(negedge clk);

        if (!first_valid) begin
            $error("Expected valid pulse after receiving first byte");
            error_count++;
        end else if (data !== 8'hA5) begin
            $error("Expected first data = 0xA5, got 0x%02x", data);
            error_count++;
        end

        // Wait a bit, then send another byte to verify continuous reception.
        repeat (4) @(negedge clk);
        send_byte(8'h3C);
        @(negedge clk);

        if (!second_valid) begin
            $error("Expected valid pulse after receiving second byte");
            error_count++;
        end else if (data !== 8'h3C) begin
            $error("Expected second data = 0x3C, got 0x%02x", data);
            error_count++;
        end

        if (error_count == 0) begin
            $display("uart_rx testbench passed.");
        end else begin
            $display("uart_rx testbench failed with %0d errors.", error_count);
        end
        $finish;
    end

endmodule : tb_uart_rx
