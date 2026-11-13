`timescale 1ns/1ps
module surface_core_test #(
 parameter N=24, E=78, CASES=1,
 parameter GRAPH="qec/surface/graphs/d3_z_r3.mem", VECTORS="cases.mem"
);
 logic clk=0; always #5 clk=~clk;
 logic rst=1, in_valid=0, in_ready, out_valid, out_ready=0, prediction, error;
 logic [N-1:0] syndrome=0; logic [31:0] cycles;
 logic [N+1:0] cases[0:CASES-1]; integer i,ticks=0,accepted,waited;
 surface_decoder #(.DETECTORS(N),.EDGES(E),.GRAPH_FILE(GRAPH)) dut(
  .clk(clk),.rst(rst),.in_valid(in_valid),.in_ready(in_ready),.syndrome(syndrome),
  .out_valid(out_valid),.out_ready(out_ready),.prediction(prediction),
  .decode_error(error),.cycles(cycles));
 always @(negedge clk) ticks=ticks+1;
 initial begin
  $readmemh(VECTORS,cases); repeat(4) @(negedge clk); rst=0;
  for(i=0;i<CASES;i=i+1) begin
   while(!in_ready) @(negedge clk);
   syndrome=cases[i][N+1:2]; in_valid=1;
   @(posedge clk); accepted=ticks; #1;
   @(negedge clk); in_valid=0; waited=0;
   while(!out_valid && waited<500000) begin @(posedge clk); #1; waited=waited+1; end
   if(!out_valid) $fatal(1,"watchdog case %d",i);
   if({error,prediction}!==cases[i][1:0]) $fatal(1,"UF mismatch N=%d case=%d syndrome=%h got=%b expected=%b",N,i,syndrome,{error,prediction},cases[i][1:0]);
   if(cycles!==32'(ticks-accepted)) $fatal(1,"counter got=%d edges=%d",cycles,ticks-accepted);
   repeat(3) begin @(negedge clk); if(!out_valid || {error,prediction}!==cases[i][1:0]) $fatal(1,"backpressure"); end
   out_ready=1; @(negedge clk); out_ready=0;
  end
  // Abort a running dense shot and prove reacceptance after reset.
  syndrome='1; in_valid=1; @(negedge clk); in_valid=0;
  repeat(10) @(negedge clk); rst=1; @(negedge clk); rst=0; #1;
  if(!in_ready || out_valid) $fatal(1,"reset recovery");
  $display("PASS algorithmic surface N=%0d E=%0d cases=%0d independent cycle edges and backpressure/reset",N,E,CASES); $finish;
 end
 initial begin #1000000000; $fatal(1,"global watchdog"); end
endmodule
module tb_surface_d3;
 surface_core_test #(.N(24),.E(78),.CASES(1)) t();
endmodule
