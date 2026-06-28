`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// pwm.sv
// Parameterized pulse-width modulation (PWM) generator.
//
// The output is high for `duty` cycles out of every 2^N cycles, where N is the
// resolution in bits. This allows smooth brightness control of LEDs and other
// simple analog-like outputs from a digital pin.
//------------------------------------------------------------------------------

module pwm #(
    parameter int N = 8  // PWM resolution in bits
)(
    input  logic clk,
    input  logic [N-1:0] duty,
    output logic pwm_out
);

    logic [N-1:0] counter;

    // Free-running counter that wraps around every 2^N cycles.
    always_ff @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Output is high while the counter is below the duty cycle value.
    assign pwm_out = (counter < duty);

endmodule : pwm
