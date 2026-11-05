`timescale 1ns/1ps
// Full-shot d=3, rounds=3 decoder: one packed eight-detector shot per request.
module qec_decoder #(
    parameter LUT_FILE="qec/lut.mem"
)(
    input logic clk, rst,
    input logic in_valid,
    output logic in_ready,
    input logic [7:0] syndrome,
    output logic out_valid,
    input logic out_ready,
    output logic prediction,
    output logic [15:0] cycles
);
    (* rom_style="distributed" *) logic lut [0:255];
    initial $readmemh(LUT_FILE, lut);
    typedef enum logic [1:0] {IDLE, READ, RESULT, HOLD} state_t;
    state_t state=IDLE;
    logic [7:0] address;
    logic rom_value;
    assign in_ready = !rst && state==IDLE;
    assign out_valid = !rst && state==HOLD;
    always_ff @(posedge clk) begin
        if(rst) begin
            state<=IDLE; prediction<=0; cycles<=0;
            address<=0; rom_value<=0;
        end else case(state)
            IDLE: if(in_valid) begin address<=syndrome; state<=READ; end
            READ: begin rom_value<=lut[address]; state<=RESULT; end
            RESULT: begin prediction<=rom_value; cycles<=16'd2; state<=HOLD; end
            HOLD: if(out_ready) state<=IDLE;
            default: state<=IDLE;
        endcase
    end
endmodule
