`timescale 1ns/1ps
// Host-provided wire packets traverse actual UART RX, decoder and UART TX RTL.
module tb_host_bridge;
    localparam int TICKS=32;
    logic clk=0;
    logic [3:0] btn=1,sw=0,led;
    logic [2:0] rgb_led;
    logic uart_rx=1,uart_tx;
    logic [7:0] requests [0:16383];
    logic [7:0] received_byte;
    integer received=0, shots, output_file;
    always #4 clk=~clk;
    top_qec_uart #(.CLK_FREQ_HZ(3_200_000),.BAUD_RATE(100_000)) dut(.*);
    initial forever begin
        @(negedge uart_tx);
        repeat(TICKS+TICKS/2) @(negedge clk);
        for(int b=0;b<8;b++) begin
            received_byte[b]=uart_tx;
            repeat(TICKS) @(negedge clk);
        end
        if(uart_tx!==1'b1) $fatal(1,"bad UART stop bit");
        $fdisplay(output_file,"%02x",received_byte);
        received++;
    end
    task automatic send_byte(input logic [7:0] value);
        uart_rx=0; repeat(TICKS) @(negedge clk);
        for(int b=0;b<8;b++) begin
            uart_rx=value[b]; repeat(TICKS) @(negedge clk);
        end
        uart_rx=1; repeat(TICKS) @(negedge clk);
    endtask
    initial begin
        if(!$value$plusargs("shots=%d",shots)) $fatal(1,"shots missing");
        if(shots<1 || shots>4096) $fatal(1,"shots outside 1..4096");
        $readmemh("requests.mem",requests,0,4*shots-1);
        output_file=$fopen("responses.mem","w");
        if(output_file==0) $fatal(1,"cannot open response file");
        repeat(8*TICKS) @(negedge clk); btn=0;
        for(int i=0;i<shots;i++) begin
            for(int b=0;b<4;b++) send_byte(requests[4*i+b]);
            wait(received>=6*(i+1));
            repeat(2*TICKS) @(negedge clk);
        end
        $fclose(output_file);
        $display("PASS host wire exchange %0d replies",received/6);
        $finish;
    end
    initial begin #300000000; $fatal(1,"host bridge timeout"); end
endmodule
