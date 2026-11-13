`timescale 1ns/1ps
// Sequential unweighted half-edge union-find growth and spanning-forest peeling.
// Graph-size state only; no syndrome lookup table and no ARM decoding.
module surface_decoder #(
 parameter integer DETECTORS=24, EDGES=78,
 parameter GRAPH_FILE="qec/surface/graphs/d3_z_r3.mem",
 parameter integer VB=$clog2(DETECTORS+1)
)(input logic clk,rst,in_valid, output logic in_ready,
 input logic [DETECTORS-1:0] syndrome,
 output logic out_valid, input logic out_ready,
 output logic prediction,decode_error, output logic [31:0] cycles);
 localparam integer B=DETECTORS;
 typedef enum logic [3:0] {IDLE,INIT,CHECK,GROW,RELABEL,ADVANCE,LEAVES,FIND,VERIFY,HOLD} state_t;
 state_t state=IDLE;
 (* rom_style="distributed" *) logic [2*VB:0] graph[0:EDGES-1];
 initial $readmemh(GRAPH_FILE,graph);
 logic [VB-1:0] label[0:DETECTORS];
 logic parity[0:DETECTORS],work[0:DETECTORS];
 logic [VB:0] degree[0:DETECTORS];
 logic [1:0] growth[0:EDGES-1];
 logic forest[0:EDGES-1];
 logic [DETECTORS-1:0] input_shot;
 integer unsigned cursor=0,edge_index=0,sweeps=0,leaf=0;
 logic pending;
 logic [VB-1:0] winner,loser;
 wire [VB-1:0] a=graph[edge_index][VB-1:0];
 wire [VB-1:0] b=graph[edge_index][2*VB-1:VB];
 wire obs=graph[edge_index][2*VB];
 wire [VB-1:0] ra=label[a],rb=label[b];
 wire [1:0] active={1'b0,(ra!=B && parity[ra])}+{1'b0,(rb!=B && parity[rb])};
 wire [2:0] expanded={1'b0,growth[edge_index]}+{1'b0,active};
 wire [VB-1:0] win=(ra==B || rb==B)?VB'(B):((ra<rb)?ra:rb);
 wire [VB-1:0] lose=(win==ra)?rb:ra;
 wire [VB-1:0] other=(a==leaf)?b:a;
 assign in_ready=!rst && state==IDLE;
 assign out_valid=!rst && state==HOLD;
 always_ff @(posedge clk) begin
  if(rst) begin
   state<=IDLE; cycles<=0; prediction<=0; decode_error<=0;
   cursor<=0; edge_index<=0; sweeps<=0; pending<=0; input_shot<=0;
   winner<=0; loser<=0; leaf<=0;
  end else begin
   if(state!=IDLE && state!=HOLD) cycles<=cycles+1;
   case(state)
    IDLE: if(in_valid) begin
     input_shot<=syndrome; prediction<=0; decode_error<=0; cycles<=0;
     cursor<=0; edge_index<=0; sweeps<=0; pending<=0; state<=INIT;
    end
    INIT: begin
     if(cursor<=DETECTORS) begin
      label[cursor]<=VB'(cursor); degree[cursor]<=0;
      parity[cursor]<=(cursor<DETECTORS)?input_shot[cursor]:1'b0;
      work[cursor]<=(cursor<DETECTORS)?input_shot[cursor]:1'b0;
     end
     if(cursor<EDGES) begin growth[cursor]<=0; forest[cursor]<=0; end
     if(cursor+1>=EDGES && cursor>=DETECTORS) begin cursor<=0; state<=CHECK; pending<=0; end
     else cursor<=cursor+1;
    end
    CHECK: begin
     if(cursor<DETECTORS) begin pending<=pending||parity[cursor]; cursor<=cursor+1; end
     else begin
      cursor<=0; pending<=0;
      if(!pending) state<=LEAVES;
      else if(sweeps>=2*(DETECTORS+1)) begin decode_error<=1; state<=HOLD; end
      else begin sweeps<=sweeps+1; edge_index<=0; state<=GROW; end
     end
    end
    GROW: begin
     if(ra!=rb && active!=0) begin
      growth[edge_index]<=(expanded>=2)?2:expanded[1:0];
      if(expanded>=2) begin
       winner<=win; loser<=lose; parity[win]<=parity[ra]^parity[rb]; parity[lose]<=0;
       forest[edge_index]<=1; degree[a]<=degree[a]+1; degree[b]<=degree[b]+1;
       cursor<=0; state<=RELABEL;
      end else state<=ADVANCE;
     end else state<=ADVANCE;
    end
    RELABEL: begin
     if(label[cursor]==loser) label[cursor]<=winner;
     if(cursor==DETECTORS) state<=ADVANCE;
     else cursor<=cursor+1;
    end
    ADVANCE: begin
     if(edge_index==EDGES-1) begin cursor<=0; pending<=0; state<=CHECK; end
     else begin edge_index<=edge_index+1; state<=GROW; end
    end
    LEAVES: begin
     if(cursor==DETECTORS) begin cursor<=0; state<=VERIFY; end
     else if(degree[cursor]==1) begin leaf<=cursor; edge_index<=0; state<=FIND; end
     else cursor<=cursor+1;
    end
    FIND: begin
     if(forest[edge_index] && (a==leaf || b==leaf)) begin
      if(work[leaf]) begin work[other]<=work[other]^1'b1; prediction<=prediction^obs; end
      work[leaf]<=0; forest[edge_index]<=0; degree[a]<=degree[a]-1; degree[b]<=degree[b]-1;
      cursor<=0; state<=LEAVES;
     end else if(edge_index==EDGES-1) begin decode_error<=1; state<=HOLD; end
     else edge_index<=edge_index+1;
    end
    VERIFY: begin
     if(cursor==DETECTORS) state<=HOLD;
     else if(work[cursor]) begin decode_error<=1; state<=HOLD; end
     else cursor<=cursor+1;
    end
    HOLD: if(out_ready) state<=IDLE;
    default: begin decode_error<=1; state<=HOLD; end
   endcase
  end
 end
endmodule
