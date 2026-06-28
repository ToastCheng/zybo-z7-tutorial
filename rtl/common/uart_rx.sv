`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// uart_rx.sv
// Parameterized UART receiver (8 data bits, no parity, 1 stop bit).
//
// The module waits for a falling edge on rx (the start bit), samples the
// start bit at its center, then samples each data bit at its center. When a
// complete frame has been received correctly, `valid` pulses high for one
// cycle and `data` contains the byte.
//------------------------------------------------------------------------------

module uart_rx #(
    parameter int CLK_FREQ_HZ = 125_000_000,
    parameter int BAUD_RATE   = 115_200
)(
    input  logic clk,
    input  logic rx,           // serial receive line
    output logic [7:0] data,   // received byte
    output logic valid         // one-cycle pulse when a byte is received
);

    localparam int TICKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam int HALF_BIT      = TICKS_PER_BIT / 2;
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
    logic [7:0] shift_reg = '0;
    logic valid_reg = 1'b0;

    always_ff @(posedge clk) begin
        valid_reg <= 1'b0;

        case (state)
            IDLE: begin
                if (rx == 1'b0) begin
                    // Falling edge: wait half a bit period to sample the
                    // center of the start bit.
                    timer <= TIMER_WIDTH'(HALF_BIT);
                    state <= START;
                end
            end

            START: begin
                if (timer == '0) begin
                    // Center of the start bit. If it is still low, this is a
                    // real start bit; otherwise it was a glitch.
                    if (rx == 1'b0) begin
                        state      <= DATA;
                        bit_index  <= 3'd0;
                        timer      <= TIMER_WIDTH'(TICKS_PER_BIT - 1);
                    end else begin
                        state <= IDLE;
                    end
                end else begin
                    timer <= timer - 1'b1;
                end
            end

            DATA: begin
                if (timer == '0) begin
                    // Sample the current data bit at its center.
                    shift_reg[bit_index] <= rx;
                    timer <= TIMER_WIDTH'(TICKS_PER_BIT - 1);

                    if (bit_index == 3'd7) begin
                        state <= STOP;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    timer <= timer - 1'b1;
                end
            end

            STOP: begin
                if (timer == '0) begin
                    // A complete frame has been received.
                    state     <= IDLE;
                    valid_reg <= 1'b1;
                end else begin
                    timer <= timer - 1'b1;
                end
            end

            default: state <= IDLE;
        endcase
    end

    assign data  = shift_reg;
    assign valid = valid_reg;

endmodule : uart_rx
