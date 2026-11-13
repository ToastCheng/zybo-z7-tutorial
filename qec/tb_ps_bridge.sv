`timescale 1ns/1ps
module tb_ps_bridge;
 reg clk=0; always #5 clk=~clk;
 reg rst=1; reg [31:0] ctrl=0; wire [31:0] status;
 qec_ps_bridge dut(.clk(clk),.rst(rst),.ctrl(ctrl),.status(status));
 reg [0:0] lut[0:255]; integer s,n,t,accepted,available; reg toggle=0;
 always @(posedge clk) begin
   if(dut.in_valid && dut.in_ready) accepted=t;
   #1; if(dut.out_valid) available=t;
 end
 initial begin t=0; forever begin @(negedge clk); t=t+1; end end
 initial begin
   $readmemh("qec/lut.mem",lut);
   repeat(4) @(negedge clk); rst=0;
   for(s=0;s<256;s=s+1) begin
     toggle=~toggle; ctrl=(s | (toggle<<8)); n=0;
     while(status[0]!==toggle && n<30) begin @(negedge clk); n=n+1; end
     if(n==30) $fatal(1,"timeout %d",s);
     if(status[1]!==lut[s]) $fatal(1,"prediction %d",s);
     if(status[17:2]!==16'd2 || available-accepted!=2)
       $fatal(1,"counter/edges %d %d",status[17:2],available-accepted);
     repeat(5) @(negedge clk);
     if(status[0]!==toggle) $fatal(1,"duplicate completion");
   end
   ctrl=32'h200; repeat(4) @(negedge clk);
   if(status!==0) $fatal(1,"software reset failed");
   ctrl=32'h100; repeat(12) @(negedge clk);
   if(status[0]!==1 || status[1]!==lut[0]) $fatal(1,"reset recovery");
   $display("PASS PS bridge 256 predictions, counter edges, hold and reset"); $finish;
 end
 initial begin #200000; $fatal(1,"watchdog"); end
endmodule
