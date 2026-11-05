`timescale 1ns/1ps
module tb_qec_decoder;
    logic clk=0, rst=1, in_valid=0, in_ready, out_valid, out_ready=1;
    logic [7:0] syndrome=0;
    logic prediction;
    logic [15:0] cycles;
    logic expected [0:255];
    always #4 clk=~clk;
    qec_decoder dut(.*);
    initial begin
        $readmemh("qec/lut.mem", expected);
        repeat(20) @(negedge clk);
        rst=0; #1;
        for(int i=0;i<256;i++) begin
            if(!in_ready) $fatal(1,"not ready at input %0d",i);
            syndrome=8'(i); in_valid=1;
            @(negedge clk); in_valid=0;
            if(out_valid) $fatal(1,"early result");
            @(negedge clk);
            if(out_valid) $fatal(1,"one cycle rather than two");
            @(negedge clk);
            if(!out_valid || prediction !== expected[i] || cycles !== 16'd2)
                $fatal(1,"decode mismatch input=%0d result=%b expected=%b cycles=%0d",i,prediction,expected[i],cycles);
            @(negedge clk);
        end
        // Hold the result and attempt to overwrite it with another request.
        out_ready=0; syndrome=8'hA5; in_valid=1;
        @(negedge clk); in_valid=0;
        repeat(2) @(negedge clk);
        repeat(7) begin
            syndrome=8'h5A; in_valid=1;
            if(in_ready || !out_valid || prediction !== expected[8'hA5] || cycles!==2)
                $fatal(1,"backpressure changed result or accepted extra work");
            @(negedge clk);
        end
        in_valid=0; rst=1; #1;
        if(in_ready || out_valid) $fatal(1,"reset did not gate handshake");
        @(negedge clk); rst=0; #1;
        if(!in_ready || out_valid) $fatal(1,"reset did not clear held result");
        // Abort an accepted shot before completion.
        syndrome=8'hFF; in_valid=1;
        @(negedge clk); in_valid=0; rst=1;
        @(negedge clk); rst=0; out_ready=1;
        repeat(4) @(negedge clk);
        if(out_valid || !in_ready) $fatal(1,"aborted shot leaked after reset");
        $display("PASS exhaustive 256 LUT entries, exactly two cycles; backpressure and reset abort");
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
