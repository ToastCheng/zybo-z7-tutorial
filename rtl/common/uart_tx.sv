`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// uart_tx.sv
// Parameterized UART transmitter (8 data bits, no parity, 1 stop bit).
//
// The module idles high. When `start` is asserted, it latches `data` and
// transmits one complete UART frame: start bit, LSB-first data bits, stop bit.
// `busy` is high from the first clock cycle of the start bit until the frame
// is complete.
//------------------------------------------------------------------------------

module uart_tx #(
    parameter int CLK_FREQ_HZ = 125_000_000,
    parameter int BAUD_RATE   = 115_200
)(
    input  logic clk,
    input  logic start,        // one-cycle pulse to begin transmission
    input  logic [7:0] data,   // byte to transmit
    output logic tx,           // serial transmit line
    output logic busy          // high while transmitting
);

    localparam int TICKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam int TIMER_WIDTH   = $clog2(TICKS_PER_BIT);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state = IDLE;

    logic [TIMER_WIDTH-1:0] timer = '0;
    logic [2:0] bit_index = '0;
    logic [7:0] data_reg = '0;

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start) begin
                    data_reg <= data;
                    state    <= START;
                end
            end

            START: begin
                if (timer == TIMER_WIDTH'(TICKS_PER_BIT - 1)) begin
                    timer <= '0;
                    state <= DATA;
                end else begin
                    timer <= timer + 1'b1;
                end
            end

            DATA: begin
                if (timer == TIMER_WIDTH'(TICKS_PER_BIT - 1)) begin
                    timer <= '0;
                    if (bit_index == 3'd7) begin
                        bit_index <= '0;
                        state     <= STOP;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    timer <= timer + 1'b1;
                end
            end

            STOP: begin
                if (timer == TIMER_WIDTH'(TICKS_PER_BIT - 1)) begin
                    timer <= '0;
                    state <= IDLE;
                end else begin
                    timer <= timer + 1'b1;
                end
            end

            default: state <= IDLE;
        endcase
    end

    always_comb begin
        case (state)
            IDLE:  tx = 1'b1;
            START: tx = 1'b0;
            DATA:  tx = data_reg[bit_index];
            STOP:  tx = 1'b1;
        endcase
    end

    assign busy = (state != IDLE);

endmodule : uart_tx
