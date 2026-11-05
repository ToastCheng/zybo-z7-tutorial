`timescale 1ns/1ps
module tb_surface_bridge;
 logic clk=0; always #5 clk=~clk;
 logic rst=1; logic [31:0] ctrl=0; wire [31:0] status;
 logic toggle=0; logic [25:0] cases[0:422]; integer i;
 surface_ps_bridge dut(.clk(clk),.rst(rst),.ctrl(ctrl),.status(status));
 task command(input [3:0] op,input [7:0] index,input [15:0] data);
  integer wait_cycles;
  begin
   @(negedge clk); toggle=~toggle; ctrl={toggle,3'b0,op,index,data}; wait_cycles=0;
   while(status[31]!==toggle && wait_cycles<500000) begin @(negedge clk);wait_cycles++;end
   if(wait_cycles==500000) $fatal(1,"command timeout %d",op);
  end
 endtask
 initial begin
  $readmemh("build/surface_sim_d3_z/cases.mem",cases);
  repeat(4) @(negedge clk);rst=0;
  for(i=0;i<40;i++) begin
   command(1,0,cases[i][17:2]); command(1,1,{8'b0,cases[i][25:18]});command(2,0,0);
   if(!status[30] || {status[29],status[28]}!==cases[i][1:0] || status[27:0]==0) $fatal(1,"bridge result %d %h",i,status);
  end
  command(3,0,0); if(status[30]) $fatal(1,"reset failed");
  command(1,0,0);command(1,1,0);command(2,0,0);
  if(status[29:28]!=0 || !status[30]) $fatal(1,"reset recovery failed");
  command(1,255,16'hffff);if(!status[29]) $fatal(1,"out of range word accepted");
  $display("PASS surface AXI GPIO bridge words/start/reset/bounds 40 syndromes");$finish;
 end
 initial begin #100000000; $fatal(1,"watchdog");end
endmodule
