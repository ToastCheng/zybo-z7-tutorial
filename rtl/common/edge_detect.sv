`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// edge_detect.sv
// Rising- and falling-edge detector.
//
// Produces a single-clock-cycle pulse when the input changes from low to high
// (rising edge) or from high to low (falling edge).
//------------------------------------------------------------------------------

module edge_detect (
    input  logic clk,
    input  logic din,
    output logic rising,
    output logic falling
);

    logic din_q;

    always_ff @(posedge clk) begin
        din_q <= din;
    end

    // Rising edge: input is high now, but was low last cycle.
    assign rising  = din && !din_q;

    // Falling edge: input is low now, but was high last cycle.
    assign falling = !din && din_q;

endmodule : edge_detect
