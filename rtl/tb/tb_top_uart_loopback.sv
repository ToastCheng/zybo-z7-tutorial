`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_top_uart_loopback.sv
// Quick sanity check: run the top-level in self-test mode with uart_tx tied
// back to uart_rx and watch the LEDs.
//------------------------------------------------------------------------------

module tb_top_uart_loopback;

    localparam int CLK_PERIOD_NS = 8;

    logic clk = 1'b0;
    logic [3:0] btn = '0;
    logic [3:0] sw = 4'b0001;      // self-test mode
    logic [3:0] led;
    logic [2:0] rgb_led;
    logic uart_rx;
    logic uart_tx;

    // Loopback: connect TX back to RX (as on the board).
    assign uart_rx = uart_tx;

    top_uart_loopback dut (
        .clk     (clk),
        .btn     (btn),
        .sw      (sw),
        .led     (led),
        .rgb_led (rgb_led),
        .uart_rx (uart_rx),
        .uart_tx (uart_tx)
    );

    always #(CLK_PERIOD_NS/2) clk = ~clk;

    initial begin
        $dumpfile("tb_top_uart_loopback.vcd");
        $dumpvars(0, tb_top_uart_loopback);
        $display("Starting top-level loopback simulation...");
        repeat (125_000_000) @(posedge clk); // 1 second real time-ish
        $display("LED = %b", led);
        repeat (125_000_000) @(posedge clk);
        $display("LED = %b", led);
        $finish;
    end

endmodule
