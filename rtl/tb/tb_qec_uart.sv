`timescale 1ns/1ps
module tb_qec_uart;
    localparam int TICKS=32;
    logic clk=0;
    logic [3:0] btn=1,sw=0,led;
    logic [2:0] rgb_led;
    logic uart_rx=1,uart_tx;
    logic expected [0:255];
    byte replies [0:4095];
    integer received=0;
    always #4 clk=~clk;
    top_qec_uart #(.CLK_FREQ_HZ(3_200_000),.BAUD_RATE(100_000)) dut(.*);
    // Independent bit-level receiver, not the DUT UART receiver.
    initial forever begin
        @(negedge uart_tx);
        repeat(TICKS+TICKS/2) @(negedge clk);
        for(int b=0;b<8;b++) begin
            replies[received][b]=uart_tx;
            repeat(TICKS) @(negedge clk);
        end
        if(uart_tx!==1'b1) $fatal(1,"bad response stop bit");
        received++;
    end
    task automatic send_byte(input byte value);
        uart_rx=0; repeat(TICKS) @(negedge clk);
        for(int b=0;b<8;b++) begin
            uart_rx=value[b]; repeat(TICKS) @(negedge clk);
        end
        uart_rx=1; repeat(TICKS) @(negedge clk);
    endtask
    task automatic request(input byte seqno, input byte syn, input bit bad);
        send_byte('hA5); send_byte(seqno); send_byte(syn);
        send_byte('hA5 ^ seqno ^ syn ^ (bad ? 8'h01:8'h00));
    endtask
    task automatic check_reply(input int base, input byte seqno, input byte syn);
        wait(received>=base+6);
        if(replies[base]!==8'h5A || replies[base+1]!==seqno ||
           replies[base+2]!=={7'b0,expected[$unsigned(syn)]} ||
           replies[base+3]!==8'd2 || replies[base+4]!==8'd0 ||
           replies[base+5] !== (8'h5A ^ seqno ^ {7'b0,expected[$unsigned(syn)]} ^ 8'd2))
            $fatal(1,"response mismatch at base %0d seq %h",base,seqno);
        repeat(2*TICKS) @(negedge clk);
    endtask
    initial begin
        $readmemh("qec/lut.mem",expected);
        repeat(8*TICKS) @(negedge clk); btn=0;
        send_byte(8'h33); send_byte(8'h00);
        request(8'h11,8'hFE,1);
        repeat(65*TICKS) @(negedge clk);
        if(received!=0) $fatal(1,"reply to bad checksum");
        request(8'hA5,8'h5A,0); check_reply(0,8'hA5,8'h5A);
        request(8'hFF,8'hA5,0); check_reply(6,8'hFF,8'hA5);
        // Reset an incomplete packet, then recover with a complete shot.
        send_byte('hA5); send_byte('h44);
        btn=1; repeat(8*TICKS) @(negedge clk); btn=0;
        request(8'h00,8'hFF,0); check_reply(12,8'h00,8'hFF);
        // A truncated packet must time out without requiring board reset.
        send_byte('hA5); send_byte('h77);
        repeat(25*TICKS) @(negedge clk);
        request(8'h12,8'h80,0); check_reply(18,8'h12,8'h80);
        for(int s=0;s<256;s++) begin
            request(8'(s),8'(s),0);
            check_reply(24+6*s,8'(s),8'(s));
        end
        if(received!=1560) $fatal(1,"extra response");
        $display("PASS UART exhaustive 256 syndromes, framing/checksums/malformed recovery/reset/timeout: 260 replies");
        $finish;
    end
    initial begin #20000000; $fatal(1,"UART timeout received=%0d",received); end
endmodule
