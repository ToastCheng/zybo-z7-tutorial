//------------------------------------------------------------------------------
// top_hello.sv
// Phase 0: "Hello World" LED blinker.
//
// This is the simplest possible FPGA design: a free-running counter whose
// upper bits drive the on-board LEDs. The goal is to verify that the toolchain,
// constraints, and programming flow are all working.
//------------------------------------------------------------------------------

`include "rtl/pkg/board_pkg.sv"

module top_hello (
    // 125 MHz system clock from the Zybo Z7-10 oscillator.
    input  logic clk,

    // Active-high push-buttons. Not used in this phase but kept as part of the
    // standard top-level interface.
    input  logic [3:0] btn,

    // Slide switches. Not used in this phase.
    input  logic [3:0] sw,

    // Single-color LEDs LD0..LD3. Active high.
    output logic [3:0] led,

    // RGB LED LD6. Active high.
    //   rgb_led[2] = Red
    //   rgb_led[1] = Green
    //   rgb_led[0] = Blue
    output logic [2:0] rgb_led
);

    import board_pkg::*;

    // A 32-bit counter that increments on every rising clock edge.
    // At 125 MHz, the full counter wraps around every 2^32 / 125e6 ~ 34 seconds.
    logic [31:0] counter;

    always_ff @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Drive the single-color LEDs with different counter bits so each LED blinks
    // at a different rate. The higher the bit index, the slower the blink.
    // Approximate blink rates at 125 MHz:
    //   counter[23] -> 125e6 / 2^24 ~ 7.5 Hz
    //   counter[24] -> ~3.7 Hz
    //   counter[25] -> ~1.9 Hz
    //   counter[26] -> ~0.9 Hz
    assign led = counter[26:23];

    // Drive the RGB LED with even slower counter bits so it cycles through
    // colors over several seconds.
    assign rgb_led[RGB_R] = counter[28];
    assign rgb_led[RGB_G] = counter[27];
    assign rgb_led[RGB_B] = counter[26];

endmodule : top_hello
