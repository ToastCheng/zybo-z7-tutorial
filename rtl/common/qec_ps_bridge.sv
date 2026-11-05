`timescale 1ns/1ps
// AXI GPIO and decoder share FCLK_CLK0. One stable request per toggle.
module qec_ps_bridge(input logic clk,rst,input logic [31:0] ctrl,
                     output logic [31:0] status);
 logic in_valid,in_ready,out_valid,prediction;
 logic [15:0] schedule_cycles;
 logic busy=0, launched=0, request=0;
 logic [31:0] ticks=0, start_tick=0;
 wire reset = rst || ctrl[9];
 assign in_valid = !busy && (ctrl[8]!=status[0]) && !reset;
 qec_decoder core(.clk(clk),.rst(reset),.in_valid(in_valid),.in_ready(in_ready),
   .syndrome(ctrl[7:0]),.out_valid(out_valid),.out_ready(1'b1),
   .prediction(prediction),.cycles(schedule_cycles));
 always_ff @(posedge clk) begin
   ticks<=ticks+1;
   if(reset) begin status<=0; busy<=0; launched<=0; request<=0; start_tick<=0; end
   else begin
     if(in_valid && in_ready) begin
       start_tick<=ticks; request<=ctrl[8]; busy<=1; launched<=1;
     end
     if(busy && launched && out_valid) begin
       // out_valid became visible after the preceding rising edge. The
       // observation edge is one later: remove that single observer cycle.
       status <= {14'b0,16'(ticks-start_tick-1),prediction,request};
       busy<=0; launched<=0;
     end
   end
 end
endmodule
