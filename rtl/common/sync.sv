`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// sync.sv
// Multi-stage input synchronizer.
//
// External signals (like push-buttons) are asynchronous to the system clock.
// Sampling them directly can cause metastability. This module chains flip-flops
// to reduce the chance of metastability propagating into the design.
//------------------------------------------------------------------------------

module sync #(
    parameter int STAGES = 2
)(
    input  logic clk,
    input  logic din,
    output logic dout
);

    logic [STAGES-1:0] shift_reg;

    always_ff @(posedge clk) begin
        // Shift the input through the register chain.
        // For STAGES=2: shift_reg[0] <= din; shift_reg[1] <= shift_reg[0];
        shift_reg <= {shift_reg[STAGES-2:0], din};
    end

    assign dout = shift_reg[STAGES-1];

endmodule : sync
