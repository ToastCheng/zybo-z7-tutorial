`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_audio_fx_dyn.sv
// Unit tests for the Phase 14 dynamics modules:
//   - audio_fx_envelope: instant attack, exponential release
//   - audio_fx_gate:     quiet signal stays muted, loud signal passes
//   - audio_fx_comp:     loud sine is limited to the target level,
//                        quiet sine passes at unity gain
//
// One push_*() call = one 44.1 kHz audio frame.  Sine waves are
// synthesized with real math, so amplitudes below are in 16-bit LSBs.
//------------------------------------------------------------------------------

module tb_audio_fx_dyn;

    localparam real FS = 44100.0;
    localparam real PI = 3.14159265358979;

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

    //--------------------------------------------------------------------------
    // DUTs
    //--------------------------------------------------------------------------
    logic               rst;
    logic               req = 1'b0;

    logic signed [15:0] env_in;
    logic        [15:0] env_out;

    audio_fx_envelope env_dut (
        .clk (clk), .rst (rst), .sample_req (req),
        .sample_in (env_in), .env (env_out)
    );

    logic signed [15:0] g_in_l, g_out_l, g_out_r;
    logic [1:0]         g_mode;

    audio_fx_gate gate_dut (
        .clk (clk), .rst (rst), .sample_req (req),
        .in_l (g_in_l), .in_r (g_in_l),
        .intensity (g_mode), .out_l (g_out_l), .out_r (g_out_r)
    );

    logic signed [15:0] c_in_l, c_out_l, c_out_r;
    logic [1:0]         c_mode;

    audio_fx_comp comp_dut (
        .clk (clk), .rst (rst), .sample_req (req),
        .in_l (c_in_l), .in_r (c_in_l),
        .intensity (c_mode), .out_l (c_out_l), .out_r (c_out_r)
    );

    // One shared frame strobe for all DUTs.
    task automatic push(logic signed [15:0] ev, logic signed [15:0] s);
        @(negedge clk);
        env_in = ev;
        g_in_l = s;
        c_in_l = s;
        req = 1'b1;
        @(negedge clk);
        req = 1'b0;
    endtask

    task automatic reset_all();
        rst = 1'b1;
        repeat (4) @(negedge clk);
        rst = 1'b0;
    endtask

    function automatic logic signed [15:0] sine(int n, int amp);
        return 16'($rtoi(amp * $sin(2.0 * PI * 440.0 * n / FS)));
    endfunction

    //--------------------------------------------------------------------------
    // Tests
    //--------------------------------------------------------------------------
    int peak;

    initial begin
        rst = 1'b1;
        env_in = '0; g_in_l = '0; c_in_l = '0;
        g_mode = '0; c_mode = '0;
        reset_all();

        //-- 1. Envelope: attack on a constant --------------------------------
        // Note: steady-state env ripples one release step (env >> 7 = 39
        // at 5000) below the peak - attack fires only when rect > env.
        for (int n = 0; n < 10; n++) push(16'sd5000, 16'sd0);
        check_window("envelope attack", env_out, 4900, 5000);

        //-- 2. Envelope: exponential release ---------------------------------
        for (int n = 0; n < 600; n++) push(16'sd0, 16'sd0);
        check_window("envelope release", env_out, 0, 500);

        //-- 3. Gate: quiet sine (amp 200 < open_thr 328) stays muted ---------
        reset_all();
        g_mode = 2'd1;
        peak = 0;
        for (int n = 0; n < 2000; n++) begin
            push(16'sd0, sine(n, 200));
            if (n >= 1500) begin
                automatic int a = (g_out_l < 0) ? -g_out_l : g_out_l;
                if (a > peak) peak = a;
            end
        end
        check_window("gate quiet muted", peak, 0, 5);

        //-- 4. Gate: loud sine (amp 10000 > 328) opens and passes ------------
        reset_all();
        peak = 0;
        for (int n = 0; n < 2000; n++) begin
            push(16'sd0, sine(n, 10000));
            if (n >= 1500) begin
                automatic int a = (g_out_l < 0) ? -g_out_l : g_out_l;
                if (a > peak) peak = a;
            end
        end
        check_window("gate loud passes", peak, 9000, 10100);

        //-- 5. Comp: loud sine (amp 20000) limited to target 8192 ------------
        reset_all();
        c_mode = 2'd1;
        peak = 0;
        for (int n = 0; n < 3000; n++) begin
            push(16'sd0, sine(n, 20000));
            if (n >= 2000) begin
                automatic int a = (c_out_l < 0) ? -c_out_l : c_out_l;
                if (a > peak) peak = a;
            end
        end
        check_window("comp limits to target", peak, 7000, 9500);

        //-- 6. Comp: quiet sine (amp 2000 < target) passes at unity ----------
        reset_all();
        peak = 0;
        for (int n = 0; n < 2000; n++) begin
            push(16'sd0, sine(n, 2000));
            if (n >= 1500) begin
                automatic int a = (c_out_l < 0) ? -c_out_l : c_out_l;
                if (a > peak) peak = a;
            end
        end
        check_window("comp quiet unity", peak, 1800, 2100);

        if (test_failed) begin
            $display("tb_audio_fx_dyn: FAILED");
            $fatal(1);
        end else begin
            $display("tb_audio_fx_dyn: PASSED");
        end
        $finish;
    end

endmodule : tb_audio_fx_dyn
