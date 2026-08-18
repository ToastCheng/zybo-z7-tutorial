`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// top_ps_hello.sv
// Phase 9: PS bring-up - hello message over UART on button press.
//
// Unlike Phases 0-8, this top contains no application logic.  All it does is
// instantiate the block-design wrapper (the Zynq PS7) and route the PL-side
// push-button BTN0 into the PS through a 1-bit EMIO GPIO.  The PS then polls
// the GPIO from a bare-metal C application and prints a hello message over
// UART1 (the PROG/UART micro-USB port) on every button press.
//
// The block design exposes the EMIO GPIO as a tri-state inout port.  The pin
// direction is controlled by the PS GPIO peripheral itself: the bare-metal
// application configures it as an input at startup.
//------------------------------------------------------------------------------

module top_ps_hello (
    inout  wire btn     // BTN0, active high when pressed (PS GPIO input)
);

    system_wrapper ps (
        .GPIO_0_0_tri_io (btn)
    );

endmodule
