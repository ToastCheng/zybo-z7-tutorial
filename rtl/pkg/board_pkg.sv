`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// board_pkg.sv
// Shared constants and types for the Zybo Z7-10 board.
//------------------------------------------------------------------------------

`ifndef BOARD_PKG_SV
`define BOARD_PKG_SV

package board_pkg;

    // System clock frequency.
    // The Zybo Z7-10 has a 125 MHz single-ended oscillator connected to pin K17.
    localparam int CLK_FREQ_HZ = 125_000_000;

    // User I/O counts.
    localparam int NUM_LEDS     = 4;  // Single-color LEDs LD0..LD3
    localparam int NUM_RGB_LEDS = 1;  // Tri-color LED LD6 (LD5 is Z7-20 only)
    localparam int NUM_BUTTONS  = 4;  // PL-connected push-buttons BTN0..BTN3
    localparam int NUM_SWITCHES = 4;  // Slide switches SW0..SW3

    // RGB LED channel indices.
    // We use a 3-bit vector [2:0] where:
    //   [2] = Red
    //   [1] = Green
    //   [0] = Blue
    localparam int RGB_R = 2;
    localparam int RGB_G = 1;
    localparam int RGB_B = 0;

endpackage : board_pkg

`endif // BOARD_PKG_SV
