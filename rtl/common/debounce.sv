`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// debounce.sv
// Push-button debouncer.
//
// Mechanical buttons do not make or break contact cleanly; they "bounce" for a
// few milliseconds. This module waits for the input to remain stable for a
// programmable amount of time before updating the output.
//------------------------------------------------------------------------------

module debounce #(
    parameter int CLK_FREQ_HZ = 125_000_000,
    parameter int STABLE_US   = 10_000        // 10 ms default
)(
    input  logic clk,
    input  logic din,
    output logic dout
);

    // Number of clock cycles the input must be stable before we accept it.
    localparam int THRESHOLD  = (CLK_FREQ_HZ / 1_000_000) * STABLE_US;
    localparam int CNT_WIDTH  = $clog2(THRESHOLD + 1);

    logic [CNT_WIDTH-1:0] counter = '0;
    logic                 dout_reg = 1'b0;

    always_ff @(posedge clk) begin
        if (din == dout_reg) begin
            // Input matches the current output: reset the stability counter.
            counter <= '0;
        end else begin
            // Input is different from the output: count how long it stays that way.
            if (counter < THRESHOLD) begin
                counter <= counter + 1'b1;
            end else begin
                // Input has been stable long enough: update the output.
                dout_reg <= din;
                counter  <= '0;
            end
        end
    end

    assign dout = dout_reg;

endmodule : debounce
