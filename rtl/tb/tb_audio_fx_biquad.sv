`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_audio_fx_biquad.sv
// Unit tests for audio_fx_biquad.
//
// The biquad is checked by its *measurable behaviour* rather than by
// golden waveforms:
//
//   1. DC gain:  low-pass passes a constant input (~unity), high-pass
//                blocks it (~zero).
//   2. Sine sweep: synthesized sine waves at 100 Hz, 1 kHz, and 10 kHz
//                check the passband/stopband of the LP, HP, and notch
//                presets.
//
// Sample rate is simulated as-is: one sample per push_sample() call is one
// 44.1 kHz frame, so the sine frequencies below are the *real* audio
// frequencies the filter was designed for.
//------------------------------------------------------------------------------

module tb_audio_fx_biquad;

    localparam real FS  = 44100.0;   // sample rate (Hz)
    localparam real PI  = 3.14159265358979;
    localparam int  AMP = 10000;     // sine amplitude (~30% full scale)

    logic clk = 1'b0;
    always #5 clk = ~clk;            // 100 MHz sim clock (speed irrelevant)

    bit test_failed = 1'b0;

    logic                    rst;
    logic                    req = 1'b0;
    logic signed [15:0]      sample_in;
    logic [1:0]              mode;
    logic signed [15:0]      sample_out;

    audio_fx_biquad dut (
        .clk        (clk),
        .rst        (rst),
        .sample_req (req),
        .sample_in  (sample_in),
        .intensity  (mode),
        .sample_out (sample_out)
    );

    //--------------------------------------------------------------------------
    // Helpers
    //--------------------------------------------------------------------------
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

    // Push one audio frame (one 44.1 kHz sample period).
    task automatic push_sample(logic signed [15:0] s);
        @(negedge clk);
        sample_in = s;
        req = 1'b1;
        @(negedge clk);
        req = 1'b0;
    endtask

    // Reset the filter state between tests.
    task automatic reset_dut();
        rst = 1'b1;
        repeat (4) @(negedge clk);
        rst = 1'b0;
    endtask

    // Feed a constant value; return the settled output.
    task automatic run_dc(logic signed [15:0] value, output int settled);
        for (int n = 0; n < 300; n++) push_sample(value);
        settled = sample_out;
    endtask

    // Feed a sine wave at frequency f; return the peak |output| measured
    // after the filter has settled (second half of the run).
    task automatic run_sine(real f, output int peak);
        int a;
        peak = 0;
        for (int n = 0; n < 2000; n++) begin
            push_sample(16'($rtoi(AMP * $sin(2.0 * PI * f * n / FS))));
            if (n >= 1000) begin
                a = (sample_out < 0) ? -sample_out : sample_out;
                if (a > peak) peak = a;
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Tests
    //--------------------------------------------------------------------------
    int result;

    initial begin
        rst = 1'b1;
        sample_in = '0;
        mode = 2'd0;
        reset_dut();

        // 1. Low-pass passes DC (unity gain, tolerance for Q2.16 rounding).
        mode = 2'd0;
        run_dc(16'sd10000, result);
        check_window("LP DC gain", result, 9900, 10100);

        // 2. High-pass blocks DC.  Tolerance is looser: truncation in the
        // feedback path causes a tiny limit cycle (~0.5% of the input).
        reset_dut();
        mode = 2'd1;
        run_dc(16'sd10000, result);
        check_window("HP DC gain", result, -64, 64);

        // 3. Low-pass passes 100 Hz (gain ~1)...
        reset_dut();
        mode = 2'd0;
        run_sine(100.0, result);
        check_window("LP 100 Hz passband", result, 9500, 10600);

        // 4. ...and attenuates 10 kHz by >25 dB (Butterworth: gain ~0.01).
        reset_dut();
        run_sine(10000.0, result);
        check_window("LP 10 kHz stopband", result, 0, 500);

        // 5. Notch kills a 1 kHz tone at fc.
        reset_dut();
        mode = 2'd3;
        run_sine(1000.0, result);
        check_window("notch 1 kHz stopband", result, 0, 500);

        // 6. High-pass passes 10 kHz (gain ~1).
        reset_dut();
        mode = 2'd1;
        run_sine(10000.0, result);
        check_window("HP 10 kHz passband", result, 9500, 10600);

        if (test_failed) begin
            $display("tb_audio_fx_biquad: FAILED");
            $fatal(1);
        end else begin
            $display("tb_audio_fx_biquad: PASSED");
        end
        $finish;
    end

endmodule : tb_audio_fx_biquad
