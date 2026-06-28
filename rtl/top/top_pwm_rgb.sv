`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_pwm_rgb.sv
// Phase 2: PWM RGB LED.
//
// Smoothly fades the RGB LED through a range of colors by independently
// pulse-width modulating the Red, Green, and Blue channels.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_pwm_rgb (
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

    // PWM duty cycles for each color channel, limited to 3 bits (0..7).
    logic [2:0] duty_r;
    logic [2:0] duty_g;
    logic [2:0] duty_b;

    // Free-running counter used to pace the color changes.
    logic [31:0] counter;

    always_ff @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Update the duty cycles slowly. With a 125 MHz clock, counter[23:0]
    // wraps every 2^24 / 125e6 ≈ 0.134 seconds. Each update changes the
    // color slightly, producing a smooth fade.
    always_ff @(posedge clk) begin
        if (counter[23:0] == 0) begin
            duty_r <= duty_r + 3'd1;
            duty_g <= duty_g + 3'd2;
            duty_b <= duty_b + 3'd3;
        end
    end

    // PWM generators for each RGB channel.
    // The 3-bit duty values are
    // zero-extended to the 8-bit PWM resolution, so max brightness is 7/256.
    pwm #(.N(8)) pwm_r (
        .clk     (clk),
        .duty    ({5'b0, duty_r}),
        .pwm_out (rgb_led[RGB_R])
    );

    pwm #(.N(8)) pwm_g (
        .clk     (clk),
        .duty    ({5'b0, duty_g}),
        .pwm_out (rgb_led[RGB_G])
    );

    pwm #(.N(8)) pwm_b (
        .clk     (clk),
        .duty    ({5'b0, duty_b}),
        .pwm_out (rgb_led[RGB_B])
    );

    // Single-color LEDs are off in this phase.
    assign led = 4'b0000;

    // Hold UART transmit line idle in this phase.
    assign uart_tx = 1'b1;

endmodule : top_pwm_rgb
