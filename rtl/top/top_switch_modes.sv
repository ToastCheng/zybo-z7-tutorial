`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_switch_modes.sv
// Phase 3: Switch-Controlled RGB LED Modes.
//
// The four slide switches select one of 16 RGB LED patterns.  Static modes
// produce a solid color; animated modes slowly fade or breathe.  The four
// single-color LEDs mirror the switch positions so you can see which switches
// are on.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_switch_modes (
    input  logic clk,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic [2:0] rgb_led,

    // UART pins on Pmod JE. Not used in this phase; kept for a shared
    // top-level port list across all phases.
    input  logic uart_rx,
    output logic uart_tx
);

    import board_pkg::*;

    localparam int PWM_W    = 8;
    localparam int FADE_DIV = 24;  // ~0.134 s per animation step at 125 MHz

    // Free-running counter.  A new animation step occurs every 2^FADE_DIV
    // clock cycles.
    logic [31:0] counter = '0;
    always_ff @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    wire logic tick = (counter[FADE_DIV-1:0] == '0);

    // 3-bit color intensities from the pattern generator.
    logic [2:0] r_duty;
    logic [2:0] g_duty;
    logic [2:0] b_duty;

    rgb_pattern_gen #(
        .INTENSITY_BITS(3)
    ) pattern (
        .clk  (clk),
        .tick (tick),
        .mode (sw[3:0]),
        .r    (r_duty),
        .g    (g_duty),
        .b    (b_duty)
    );

    // PWM generators for each RGB channel.  The 3-bit intensities are
    // zero-extended so the maximum on-time stays at 7/256.
    pwm #(.N(PWM_W)) pwm_r (
        .clk     (clk),
        .duty    ({5'b0, r_duty}),
        .pwm_out (rgb_led[RGB_R])
    );

    pwm #(.N(PWM_W)) pwm_g (
        .clk     (clk),
        .duty    ({5'b0, g_duty}),
        .pwm_out (rgb_led[RGB_G])
    );

    pwm #(.N(PWM_W)) pwm_b (
        .clk     (clk),
        .duty    ({5'b0, b_duty}),
        .pwm_out (rgb_led[RGB_B])
    );

    // Single-color LEDs show the switch state.
    assign led = sw;

    // Hold UART transmit line idle in this phase.
    assign uart_tx = 1'b1;

endmodule : top_switch_modes
