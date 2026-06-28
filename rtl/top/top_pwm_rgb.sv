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
    output logic [2:0] rgb_led
);

    import board_pkg::*;

    // PWM duty cycles for each color channel.
    logic [7:0] duty_r;
    logic [7:0] duty_g;
    logic [7:0] duty_b;

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
            duty_r <= duty_r + 8'd1;
            duty_g <= duty_g + 8'd2;
            duty_b <= duty_b + 8'd3;
        end
    end

    // PWM generators for each RGB channel.
    pwm #(.N(8)) pwm_r (
        .clk     (clk),
        .duty    (duty_r),
        .pwm_out (rgb_led[RGB_R])
    );

    pwm #(.N(8)) pwm_g (
        .clk     (clk),
        .duty    (duty_g),
        .pwm_out (rgb_led[RGB_G])
    );

    pwm #(.N(8)) pwm_b (
        .clk     (clk),
        .duty    (duty_b),
        .pwm_out (rgb_led[RGB_B])
    );

    // Single-color LEDs are off in this phase.
    assign led = 4'b0000;

endmodule : top_pwm_rgb
