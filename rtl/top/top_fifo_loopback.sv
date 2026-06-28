`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_fifo_loopback.sv
// Phase 5: FIFO loopback.
//
// Demonstrates the synchronous FIFO with push-buttons and LEDs.
//   - SW0-SW3 supply a 4-bit data value.
//   - BTN0 clears (resets) the FIFO.
//   - BTN1 pushes the switch value into the FIFO.
//   - BTN2 pops the oldest value from the FIFO onto the LEDs.
//   - RGB LED shows full (red), empty (green), or has data (blue).
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_fifo_loopback (
    input  logic clk,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic [2:0] rgb_led,
    input  logic uart_rx,
    output logic uart_tx
);

    import board_pkg::*;

    localparam int FIFO_WIDTH = 4;
    localparam int FIFO_DEPTH = 8;

    // Debounced button signals.
    logic db_btn0, db_btn1, db_btn2;

    // Single-cycle pulses from the push/release edges of BTN1/BTN2.
    logic write_pulse, read_pulse;

    // FIFO status.
    logic fifo_full, fifo_empty;
    logic [FIFO_WIDTH-1:0] fifo_dout;

    // BTN0 is the FIFO clear (active while pressed).
    debounce db_clear (
        .clk  (clk),
        .din  (btn[0]),
        .dout (db_btn0)
    );

    // BTN1 push.
    debounce db_push (
        .clk  (clk),
        .din  (btn[1]),
        .dout (db_btn1)
    );

    edge_detect ed_push (
        .clk     (clk),
        .din     (db_btn1),
        .rising  (write_pulse),
        .falling ()
    );

    // BTN2 pop.
    debounce db_pop (
        .clk  (clk),
        .din  (btn[2]),
        .dout (db_btn2)
    );

    edge_detect ed_pop (
        .clk     (clk),
        .din     (db_btn2),
        .rising  (read_pulse),
        .falling ()
    );

    fifo_sync #(
        .DATA_WIDTH(FIFO_WIDTH),
        .DEPTH     (FIFO_DEPTH)
    ) fifo_inst (
        .clk    (clk),
        .rst    (db_btn0),
        .wr_en  (write_pulse),
        .din    (sw[FIFO_WIDTH-1:0]),
        .full   (fifo_full),
        .rd_en  (read_pulse),
        .dout   (fifo_dout),
        .empty  (fifo_empty)
    );

    // PWM dimming for the RGB status LED: 1/256 duty cycle so the indicator
    // is visible but not uncomfortably bright.
    logic pwm_out;

    pwm #(
        .N(8)
    ) pwm_dimmer (
        .clk     (clk),
        .duty    (8'd1),
        .pwm_out (pwm_out)
    );

    // Visual feedback.
    assign led     = fifo_dout;
    assign rgb_led = {fifo_full, fifo_empty, ~(fifo_full || fifo_empty)} & {3{pwm_out}};
    assign uart_tx = 1'b1;  // idle for unused UART pin

endmodule : top_fifo_loopback
