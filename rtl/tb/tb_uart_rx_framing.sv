`timescale 1ns / 1ps

// Incoming framing-error rejection and recovery, without a reset or error port.
module tb_uart_rx_framing;
    localparam int TICKS_PER_BIT = 32;
    logic clk = 0;
    logic rx = 1;
    wire [7:0] data;
    wire valid;
    int received = 0;
    logic previous_valid = 0;
    logic [7:0] expected = 8'h3C;

    always #5 clk = ~clk;
    uart_rx #(.CLK_FREQ_HZ(3_200_000), .BAUD_RATE(100_000)) dut (
        .clk(clk), .rx(rx), .data(data), .valid(valid)
    );

    // Observe outputs after NBA updates; stimulus changes only on falling edges.
    always @(posedge clk) begin
        #1;
        if (valid) begin
            if (previous_valid) $fatal(1, "valid must be a one-cycle pulse");
            if (received != 0 || data !== expected)
                $fatal(1, "Unexpected received byte 0x%02x (count=%0d)", data, received);
            received++;
        end
        previous_valid = valid;
    end

    task automatic send_bit(input logic value);
        rx = value;
        repeat (TICKS_PER_BIT) @(negedge clk);
    endtask

    task automatic send_frame(input logic [7:0] value, input logic stop_bit);
        send_bit(0);
        for (int i = 0; i < 8; i++) send_bit(value[i]);
        send_bit(stop_bit);
    endtask

    initial begin
        repeat (2*TICKS_PER_BIT) @(negedge clk);
        // Reproduces review finding: valid data bits but a LOW stop bit.
        send_frame(8'hA5, 0);
        send_bit(1);
        send_bit(1);
        send_bit(1);
        if (received != 0) $fatal(1, "Bad stop bit must not produce valid");
        // No reset: the next well-formed frame after idle must be received.
        send_frame(expected, 1);
        send_bit(1);
        if (received != 1) $fatal(1, "Receiver did not recover after bad stop");
        $display("PASS tb_uart_rx_framing: bad stop rejected, next frame recovered");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Framing regression timeout");
    end
endmodule
