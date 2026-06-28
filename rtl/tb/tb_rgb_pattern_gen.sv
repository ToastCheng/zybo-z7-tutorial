`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_rgb_pattern_gen.sv
// Testbench for the rgb_pattern_gen module.
//
// Verifies static color modes and that animated modes advance when ticked.
//------------------------------------------------------------------------------

module tb_rgb_pattern_gen;

    localparam int INTENSITY_BITS = 3;

    logic clk;
    logic tick;
    logic [3:0] mode;
    logic [INTENSITY_BITS-1:0] r;
    logic [INTENSITY_BITS-1:0] g;
    logic [INTENSITY_BITS-1:0] b;

    int error_count;

    rgb_pattern_gen #(
        .INTENSITY_BITS(INTENSITY_BITS)
    ) dut (
        .clk  (clk),
        .tick (tick),
        .mode (mode),
        .r    (r),
        .g    (g),
        .b    (b)
    );

    // 125 MHz clock.
    initial begin
        clk = 0;
        forever #4 clk = ~clk;
    end

    // Advance the animation state by exactly one tick.
    task automatic pulse_tick();
        begin
            @(negedge clk);
            tick = 1;
            @(negedge clk);
            tick = 0;
        end
    endtask

    // Compare outputs against expected values.
    task automatic check_color(
        input logic [INTENSITY_BITS-1:0] exp_r,
        input logic [INTENSITY_BITS-1:0] exp_g,
        input logic [INTENSITY_BITS-1:0] exp_b
    );
        begin
            if (r !== exp_r || g !== exp_g || b !== exp_b) begin
                $error("mode=%0d: expected R=%0d G=%0d B=%0d, got R=%0d G=%0d B=%0d",
                       mode, exp_r, exp_g, exp_b, r, g, b);
                error_count++;
            end
        end
    endtask

    logic [INTENSITY_BITS-1:0] r_before, g_before, b_before;

    initial begin
        $display("Starting rgb_pattern_gen testbench...");

        error_count = 0;
        tick = 0;
        mode = 4'd0;

        // Wait for the DUT to come out of reset.
        @(negedge clk);
        @(negedge clk);

        // Static color modes.
        mode = 4'd0; @(negedge clk); check_color(0, 0, 0);  // off
        mode = 4'd1; @(negedge clk); check_color(7, 0, 0);  // red
        mode = 4'd2; @(negedge clk); check_color(0, 7, 0);  // green
        mode = 4'd3; @(negedge clk); check_color(0, 0, 7);  // blue
        mode = 4'd4; @(negedge clk); check_color(7, 7, 0);  // yellow
        mode = 4'd5; @(negedge clk); check_color(0, 7, 7);  // cyan
        mode = 4'd6; @(negedge clk); check_color(7, 0, 7);  // magenta
        mode = 4'd7; @(negedge clk); check_color(7, 7, 7);  // white

        // Slow rainbow: state starts at 0 and advances by one each tick.
        // g = state + 2, b = state + 3, all wrapped to 3 bits.
        mode = 4'd8;
        pulse_tick();  // state = 1
        check_color(1, 3, 4);
        pulse_tick();  // state = 2
        check_color(2, 4, 5);

        // Fast rainbow: g = state + 3, b = state + 5.
        mode = 4'd9;
        // Reset state to a known value by toggling to a static mode first
        // is not guaranteed, so just verify it advances from the current state.
        @(negedge clk);
        r_before = r;
        g_before = g;
        b_before = b;
        pulse_tick();
        if ({r, g, b} === {r_before, g_before, b_before}) begin
            $error("mode=9: outputs did not advance after tick");
            error_count++;
        end

        // White breathe: intensity should change after a tick.
        mode = 4'd10;
        @(negedge clk);
        r_before = r;
        g_before = g;
        b_before = b;
        pulse_tick();
        if ({r, g, b} === {r_before, g_before, b_before}) begin
            $error("mode=10: breathe output did not change after tick");
            error_count++;
        end

        if (error_count == 0) begin
            $display("rgb_pattern_gen testbench passed.");
        end else begin
            $display("rgb_pattern_gen testbench failed with %0d errors.", error_count);
        end
        $finish;
    end

endmodule : tb_rgb_pattern_gen
