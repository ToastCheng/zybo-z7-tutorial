`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_button_led.sv
// Phase 1: Button-controlled LEDs.
//
// Each of the four PL push-buttons toggles one of the four single-color LEDs.
// The button signal is synchronized, debounced, and edge-detected before it
// changes the LED state.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_button_led (
    input  logic clk,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic [2:0] rgb_led
);

    import board_pkg::*;

    logic [3:0] btn_sync;
    logic [3:0] btn_deb;
    logic [3:0] btn_rising;

    // Generate one button-processing channel per button.
    // Each channel: synchronize -> debounce -> detect rising edge.
    genvar i;
    generate
        for (i = 0; i < NUM_BUTTONS; i++) begin : g_button_channel
            sync sync_inst (
                .clk  (clk),
                .din  (btn[i]),
                .dout (btn_sync[i])
            );

            debounce debounce_inst (
                .clk  (clk),
                .din  (btn_sync[i]),
                .dout (btn_deb[i])
            );

            edge_detect edge_detect_inst (
                .clk     (clk),
                .din     (btn_deb[i]),
                .rising  (btn_rising[i]),
                .falling ()
            );
        end
    endgenerate

    // Toggle register for the four LEDs.
    logic [NUM_LEDS-1:0] led_reg = '0;

    always_ff @(posedge clk) begin
        for (int j = 0; j < NUM_LEDS; j++) begin
            if (btn_rising[j]) begin
                led_reg[j] <= ~led_reg[j];
            end
        end
    end

    assign led = led_reg;

    // Keep the RGB LED off in this phase.
    assign rgb_led = '0;

endmodule : top_button_led
