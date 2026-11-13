`timescale 1ns/1ps
// One outstanding request. Host must wait for the complete response.
module top_qec_uart #(
    parameter int CLK_FREQ_HZ=125_000_000,
    parameter int BAUD_RATE=115_200,
    parameter LUT_FILE="qec/lut.mem"
)(
    input logic clk,
    input logic [3:0] btn, sw,
    output logic [3:0] led,
    output logic [2:0] rgb_led,
    input logic uart_rx,
    output logic uart_tx
);
    logic rst;
    sync reset_sync(.clk(clk),.din(btn[0]),.dout(rst));
    logic [7:0] rx_data,tx_data;
    logic rx_valid,tx_busy;
    logic tx_start;
    uart_rx #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.BAUD_RATE(BAUD_RATE)) rx_inst(
        .clk(clk),.rx(uart_rx),.data(rx_data),.valid(rx_valid));
    uart_tx #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.BAUD_RATE(BAUD_RATE)) tx_inst(
        .clk(clk),.start(tx_start),.data(tx_data),.tx(uart_tx),.busy(tx_busy));
    typedef enum logic [3:0] {HEADER,SEQ,SYNDROME,CHECKSUM,ACCEPT,DECODE,SEND,WAIT_TX,DRAIN} state_t;
    state_t state=HEADER;
    logic [7:0] sequence_byte=0,syndrome_byte=0;
    logic prediction,in_ready,out_valid;
    logic [15:0] cycles;
    logic [7:0] response [0:5];
    logic [2:0] index=0;
    logic [7:0] completed=0;
    logic checksum_error=0;
    // Allow a complete next UART byte plus one byte of inter-byte idle.
    localparam int GAP_TICKS=20*(CLK_FREQ_HZ/BAUD_RATE);
    localparam int GAP_WIDTH=$clog2(GAP_TICKS+1);
    logic [GAP_WIDTH-1:0] gap_count=0;
    wire parsing = state==SEQ || state==SYNDROME || state==CHECKSUM;
    always_ff @(posedge clk) begin
        if(rst || !parsing || rx_valid) gap_count<=0;
        else if(gap_count<GAP_TICKS) gap_count<=gap_count+1'b1;
    end
    qec_decoder #(.LUT_FILE(LUT_FILE)) decoder(
        .clk(clk),.rst(rst),.in_valid(state==ACCEPT),.in_ready(in_ready),
        .syndrome(syndrome_byte),.out_valid(out_valid),.out_ready(state==DECODE),
        .prediction(prediction),.cycles(cycles));
    assign tx_data=response[index];
    assign tx_start=!rst && state==SEND && !tx_busy;
    assign led=completed[3:0];
    assign rgb_led={checksum_error,1'b0,(state!=HEADER)};
    always_ff @(posedge clk) begin
        if(rst) begin
            state<=HEADER; sequence_byte<=0; syndrome_byte<=0;
            index<=0; completed<=0; checksum_error<=0;
            for(int i=0;i<6;i++) response[i]<=0;
        end else if(parsing && !rx_valid && gap_count==GAP_TICKS) begin
            state<=HEADER;
        end else case(state)
            HEADER: if(rx_valid && rx_data==8'hA5) state<=SEQ;
            SEQ: if(rx_valid) begin sequence_byte<=rx_data; state<=SYNDROME; end
            SYNDROME: if(rx_valid) begin syndrome_byte<=rx_data; state<=CHECKSUM; end
            CHECKSUM: if(rx_valid) begin
                if(rx_data==(8'hA5 ^ sequence_byte ^ syndrome_byte)) begin
                    state<=ACCEPT; checksum_error<=0;
                end else begin
                    checksum_error<=1;
                    // A bad checksum that is itself a header can start a new frame.
                    state<=(rx_data==8'hA5) ? SEQ:HEADER;
                end
            end
            ACCEPT: if(in_ready) state<=DECODE;
            DECODE: if(out_valid) begin
                response[0]<=8'h5A; response[1]<=sequence_byte;
                response[2]<={7'b0,prediction}; response[3]<=cycles[7:0];
                response[4]<=cycles[15:8];
                response[5]<=8'h5A ^ sequence_byte ^ {7'b0,prediction} ^ cycles[7:0] ^ cycles[15:8];
                index<=0; state<=SEND;
            end
            SEND: if(!tx_busy) state<=WAIT_TX;
            WAIT_TX: if(tx_busy) state<=DRAIN;
            DRAIN: if(!tx_busy) begin
                if(index==5) begin state<=HEADER; completed<=completed+1'b1; end
                else begin index<=index+1'b1; state<=SEND; end
            end
            default: state<=HEADER;
        endcase
    end
endmodule
