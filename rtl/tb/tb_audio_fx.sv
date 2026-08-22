`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_audio_fx.sv
// Unit tests for the Phase 10 audio effect modules:
//   - audio_fx_bitcrusher: LSB masking at each intensity
//   - audio_fx_distortion: gain and saturation
//   - audio_fx_echo:       ring-buffer delay depth and wet mix
//------------------------------------------------------------------------------

module tb_audio_fx;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    bit test_failed = 1'b0;

    task automatic check(string name, logic signed [15:0] got,
                         logic signed [15:0] expected);
        if (got !== expected) begin
            $error("ERROR: %s: got %h (%0d), expected %h (%0d)",
                   name, got, got, expected, expected);
            test_failed = 1'b1;
        end else begin
            $display("OK: %s = %h (%0d)", name, got, got);
        end
    endtask

    //--------------------------------------------------------------------------
    // Bit crusher
    //--------------------------------------------------------------------------
    logic signed [15:0] crush_in;
    logic [1:0]         crush_int;
    logic signed [15:0] crush_out;

    audio_fx_bitcrusher crush (
        .sample_in  (crush_in),
        .intensity  (crush_int),
        .sample_out (crush_out)
    );

    //--------------------------------------------------------------------------
    // Distortion
    //--------------------------------------------------------------------------
    logic signed [15:0] dist_in;
    logic [1:0]         dist_int;
    logic signed [15:0] dist_out;

    audio_fx_distortion distort (
        .clk        (clk),
        .rst        (1'b0),
        .sample_in  (dist_in),
        .intensity  (dist_int),
        .sample_out (dist_out)
    );

    //--------------------------------------------------------------------------
    // Echo (small DEPTH so the test runs fast)
    //--------------------------------------------------------------------------
    localparam int ECHO_DEPTH = 8;

    logic               echo_req = 1'b0;
    logic signed [15:0] echo_in_l, echo_in_r;
    logic [1:0]         echo_int;
    logic signed [15:0] echo_out_l, echo_out_r;

    audio_fx_echo #(.DEPTH(ECHO_DEPTH)) echo (
        .clk        (clk),
        .rst        (1'b0),
        .sample_req (echo_req),
        .in_l       (echo_in_l),
        .in_r       (echo_in_r),
        .intensity  (echo_int),
        .out_l      (echo_out_l),
        .out_r      (echo_out_r)
    );

    task automatic echo_push(logic signed [15:0] l, logic signed [15:0] r);
        echo_in_l = l;
        echo_in_r = r;
        @(posedge clk);
        echo_req = 1'b1;
        @(posedge clk);
        echo_req = 1'b0;
        #1; // let rd_data settle
    endtask

    initial begin
        $display("Starting tb_audio_fx...");

        //----------------------------------------------------------------------
        // Bit crusher
        //----------------------------------------------------------------------
        crush_in = 16'h7FFF; crush_int = 2'd0; #1;
        check("crush keep12 pos", crush_out, 16'h7FF0);
        crush_in = 16'h1234; crush_int = 2'd1; #1;
        check("crush keep8 pos", crush_out, 16'h1200);
        crush_in = 16'h1234; crush_int = 2'd2; #1;
        check("crush keep6 pos", crush_out, 16'h1000);
        crush_in = 16'h1234; crush_int = 2'd3; #1;
        check("crush keep4 pos", crush_out, 16'h1000);
        crush_in = 16'h8765; crush_int = 2'd1; #1; // negative sample
        check("crush keep8 neg", crush_out, 16'h8700);

        //----------------------------------------------------------------------
        // Distortion (registered output: sample one cycle after input)
        //----------------------------------------------------------------------
        dist_int = 2'd0;                    // gain x2
        dist_in = 16'sd1000;
        @(posedge clk); #1;
        check("dist x2 normal", dist_out, 16'sd2000);

        dist_in = 16'sd16384;               // 16384 * 2 = 32768 -> clip
        @(posedge clk); #1;
        check("dist x2 clip+", dist_out, 16'sd32767);

        dist_int = 2'd2;                    // gain x8
        dist_in = -16'sd10000;              // -80000 -> clip
        @(posedge clk); #1;
        check("dist x8 clip-", dist_out, -16'sd32768);

        dist_in = -16'sd100;                // -800, no clip
        @(posedge clk); #1;
        check("dist x8 normal", dist_out, -16'sd800);

        //----------------------------------------------------------------------
        // Echo: with DEPTH=8 the read pointer trails by one slot, so the
        // delayed value at push k is the sample from push k-7 (DEPTH-1 frames
        // ago).  Intensity 2 = 1/2 wet mix.
        //----------------------------------------------------------------------
        echo_int = 2'd2;
        for (int k = 0; k < ECHO_DEPTH; k++)
            echo_push(16'(k * 256), -16'(k * 256));

        // Push 8: delayed value is frame 1 (256), wet = 128.
        echo_push(16'sd4096, 16'sd4096);
        check("echo dry+wet(frame1) L", echo_out_l, 16'sd4096 + 16'sd128);
        check("echo dry+wet(frame1) R", echo_out_r, 16'sd4096 - 16'sd128);

        // Push 9: delayed value is frame 2 (512), wet = 256.
        echo_push(16'sd4096, 16'sd4096);
        check("echo dry+wet(frame2) L", echo_out_l, 16'sd4096 + 16'sd256);

        // Intensity 0 = 1/4 wet mix; frame 3 = 768 -> wet = 192.
        echo_int = 2'd0;
        echo_push(16'sd0, 16'sd0);
        check("echo 1/4 wet(frame3) L", echo_out_l, 16'sd192);

        if (test_failed)
            $display("TEST FAILED");
        else
            $display("TEST PASSED");

        $finish;
    end

endmodule : tb_audio_fx
