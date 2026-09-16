`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_audio_fx_mod.sv
// Unit tests for the Phase 13 modulation-effect modules:
//   - lfo:              triangle period and amplitude
//   - audio_delay_line: variable tap reads back the right frame
//   - audio_fx_chorus:  DC mix level, flanger impulse copy
//   - audio_fx_tremolo: gain envelope swings with depth
//
// One push_*() call = one 44.1 kHz audio frame, so delay/tap counts below
// are real frames.
//------------------------------------------------------------------------------

module tb_audio_fx_mod;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    bit test_failed = 1'b0;

    task automatic check_window(string name, int got, int lo, int hi);
        if (got < lo || got > hi) begin
            $error("ERROR: %s: got %0d, expected within [%0d, %0d]",
                   name, got, lo, hi);
            test_failed = 1'b1;
        end else begin
            $display("OK: %s = %0d (expected within [%0d, %0d])",
                     name, got, lo, hi);
        end
    endtask

    task automatic check_eq(string name, int got, int expected);
        if (got !== expected) begin
            $error("ERROR: %s: got %0d, expected %0d", name, got, expected);
            test_failed = 1'b1;
        end else begin
            $display("OK: %s = %0d", name, got);
        end
    endtask

    //--------------------------------------------------------------------------
    // LFO (fast rate: period = 2^24 / rate = 4 frames)
    //--------------------------------------------------------------------------
    logic               lfo_rst;
    logic               lfo_req = 1'b0;
    logic signed [15:0] lfo_out;

    lfo lfo_dut (
        .clk        (clk),
        .rst        (lfo_rst),
        .sample_req (lfo_req),
        .rate       (24'h400000),
        .out        (lfo_out)
    );

    task automatic lfo_step();
        @(negedge clk);
        lfo_req = 1'b1;
        @(negedge clk);
        lfo_req = 1'b0;
    endtask

    //--------------------------------------------------------------------------
    // Delay line (small DEPTH for a fast test)
    //--------------------------------------------------------------------------
    localparam int DL_DEPTH = 64;

    logic               dl_rst;
    logic               dl_req = 1'b0;
    logic signed [15:0] dl_in_l, dl_in_r;
    logic [5:0]         dl_tap;
    logic signed [15:0] dl_out_l, dl_out_r;

    audio_delay_line #(.DEPTH(DL_DEPTH)) dl_dut (
        .clk        (clk),
        .rst        (dl_rst),
        .sample_req (dl_req),
        .in_l       (dl_in_l),
        .in_r       (dl_in_r),
        .tap        (dl_tap),
        .out_l      (dl_out_l),
        .out_r      (dl_out_r)
    );

    task automatic dl_push(logic signed [15:0] v);
        @(negedge clk);
        dl_in_l = v;
        dl_in_r = -v;
        dl_req  = 1'b1;
        @(negedge clk);
        dl_req  = 1'b0;
    endtask

    //--------------------------------------------------------------------------
    // Chorus (real DEPTH: taps are in real audio frames)
    //--------------------------------------------------------------------------
    logic               ch_rst;
    logic               ch_req = 1'b0;
    logic signed [15:0] ch_in_l, ch_in_r;
    logic [1:0]         ch_mode;
    logic signed [15:0] ch_out_l, ch_out_r;

    audio_fx_chorus ch_dut (
        .clk        (clk),
        .rst        (ch_rst),
        .sample_req (ch_req),
        .in_l       (ch_in_l),
        .in_r       (ch_in_r),
        .intensity  (ch_mode),
        .out_l      (ch_out_l),
        .out_r      (ch_out_r)
    );

    task automatic ch_push(logic signed [15:0] v);
        @(negedge clk);
        ch_in_l = v;
        ch_in_r = v;
        ch_req  = 1'b1;
        @(negedge clk);
        ch_req  = 1'b0;
    endtask

    //--------------------------------------------------------------------------
    // Tremolo
    //--------------------------------------------------------------------------
    logic               tr_rst;
    logic               tr_req = 1'b0;
    logic signed [15:0] tr_in_l, tr_in_r;
    logic [1:0]         tr_mode;
    logic signed [15:0] tr_out_l, tr_out_r;

    audio_fx_tremolo tr_dut (
        .clk        (clk),
        .rst        (tr_rst),
        .sample_req (tr_req),
        .in_l       (tr_in_l),
        .in_r       (tr_in_r),
        .intensity  (tr_mode),
        .out_l      (tr_out_l),
        .out_r      (tr_out_r)
    );

    task automatic tr_push(logic signed [15:0] v);
        @(negedge clk);
        tr_in_l = v;
        tr_in_r = v;
        tr_req  = 1'b1;
        @(negedge clk);
        tr_req  = 1'b0;
    endtask

    //--------------------------------------------------------------------------
    // Tests
    //--------------------------------------------------------------------------
    int peak, trough;
    logic signed [15:0] hist [0:63];
    logic signed [15:0] lfo_first;

    initial begin
        lfo_rst = 1'b1; dl_rst = 1'b1; ch_rst = 1'b1; tr_rst = 1'b1;
        dl_in_l = '0; dl_in_r = '0; ch_in_l = '0; ch_in_r = '0;
        tr_in_l = '0; tr_in_r = '0;
        dl_tap = '0; ch_mode = '0; tr_mode = '0;
        repeat (4) @(negedge clk);
        lfo_rst = 1'b0; dl_rst = 1'b0; ch_rst = 1'b0; tr_rst = 1'b0;

        //-- 1. LFO: period 4 frames, full-scale triangle --------------------
        lfo_step();
        lfo_first = lfo_out;
        lfo_step(); lfo_step(); lfo_step(); lfo_step();
        check_eq("LFO period-4 repeat", lfo_out, lfo_first);

        lfo_rst = 1'b1;
        repeat (2) @(negedge clk);
        lfo_rst = 1'b0;
        peak = -40000; trough = 40000;
        for (int n = 0; n < 8; n++) begin
            lfo_step();
            if (lfo_out > peak)   peak   = lfo_out;
            if (lfo_out < trough) trough = lfo_out;
        end
        check_window("LFO max", peak, 32000, 32767);
        check_window("LFO min", trough, -32768, -32000);

        //-- 2. Delay line: tap = 10 reads 10 frames back ---------------------
        dl_tap = 6'd10;
        for (int n = 0; n < 32; n++) begin
            hist[n] = 16'(n * 100);
            dl_push(16'(n * 100));
            if (n >= 10)
                check_eq($sformatf("delay_line tap10 frame %0d", n),
                         dl_out_l, hist[n-10]);
        end

        //-- 3. Chorus DC: dry + wet/2 of a constant = 1.5x ------------------
        ch_mode = 2'd0;  // chorus preset
        for (int n = 0; n < 2100; n++) ch_push(16'sd10000);
        check_window("chorus DC mix", ch_out_l, 14800, 15200);

        //-- 4. Flanger impulse: delayed copy appears within tap range -------
        ch_rst = 1'b1;
        repeat (2) @(negedge clk);
        ch_rst = 1'b0;
        ch_mode = 2'd1;  // flanger: tap 4..260 frames
        ch_push(16'sd20000);
        peak = 0;
        for (int n = 1; n < 270; n++) begin
            ch_push(16'sd0);
            if (n >= 3) begin
                automatic int a = (ch_out_l < 0) ? -ch_out_l : ch_out_l;
                if (a > peak) peak = a;
            end
        end
        check_window("flanger impulse copy", peak, 4000, 12000);

        //-- 5. Tremolo full depth: gain swings 0..1 on DC -------------------
        tr_mode = 2'd3;
        peak = 0; trough = 40000;
        for (int n = 0; n < 18000; n++) begin
            tr_push(16'sd10000);
            if (n >= 100) begin
                if (tr_out_l > peak)   peak   = tr_out_l;
                if (tr_out_l < trough) trough = tr_out_l;
            end
        end
        check_window("tremolo max", peak, 9000, 10100);
        check_window("tremolo min", trough, -100, 1500);

        if (test_failed) begin
            $display("tb_audio_fx_mod: FAILED");
            $fatal(1);
        end else begin
            $display("tb_audio_fx_mod: PASSED");
        end
        $finish;
    end

endmodule : tb_audio_fx_mod
