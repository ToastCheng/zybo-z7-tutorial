`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_uart_loopback.sv
// Phase 4: UART Loopback.
//
// Receives bytes on uart_rx at 115200 baud and immediately re-transmits them
// on uart_tx.  The lower nibble of the most recently handled byte is shown
// on the four single-color LEDs.
//
// A self-test mode is provided for boards without a USB-UART adapter: when
// SW0 is high the FPGA periodically transmits an incrementing test byte.
// Shorting uart_tx to uart_rx feeds that byte back into the receiver.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_uart_loopback (
    input  logic clk,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic [2:0] rgb_led,
    input  logic uart_rx,
    output logic uart_tx
);

    import board_pkg::*;

    localparam int BAUD_RATE = 115_200;

    logic [7:0] rx_data;
    logic       rx_valid;

    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx_busy;

    // One-byte buffer. When a byte arrives it is stored here; as soon as the
    // transmitter is free, the buffered byte is sent.
    logic [7:0] pending_data = '0;
    logic       pending      = 1'b0;

    // Self-test generator.
    logic [31:0] test_counter = '0;
    logic [7:0]  test_byte    = '0;

    always_ff @(posedge clk) begin
        test_counter <= test_counter + 1'b1;
    end

    wire logic test_tick = (test_counter[25:0] == '0);

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) rx_inst (
        .clk   (clk),
        .rx    (uart_rx),
        .data  (rx_data),
        .valid (rx_valid)
    );

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) tx_inst (
        .clk   (clk),
        .start (tx_start),
        .data  (tx_data),
        .tx    (uart_tx),
        .busy  (tx_busy)
    );

    always_ff @(posedge clk) begin
        if (sw[0]) begin
            // Self-test mode: load an incrementing test byte on each tick.
            // External receive data is ignored so the test pattern is not
            // overwritten by the echo.
            if (!pending && !tx_busy && test_tick) begin
                pending_data <= test_byte;
                pending      <= 1'b1;
                test_byte    <= test_byte + 1'b1;
            end
        end else begin
            // Normal loopback: store the byte received from uart_rx.
            if (rx_valid && !pending) begin
                pending_data <= rx_data;
                pending      <= 1'b1;
            end
        end

        // Transmit the pending byte as soon as the transmitter is free.
        if (pending && !tx_busy) begin
            tx_data  <= pending_data;
            tx_start <= 1'b1;
            pending  <= 1'b0;
        end else begin
            tx_start <= 1'b0;
        end
    end

    // Visual feedback: lower nibble of the last handled byte.
    assign led     = pending_data[3:0];
    assign rgb_led = 3'b000;  // RGB LED is off in this phase

endmodule : top_uart_loopback
