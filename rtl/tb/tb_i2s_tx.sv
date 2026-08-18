`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_i2s_tx.sv
// Verify the I2S transmit serializer framing and bit order.
//------------------------------------------------------------------------------

module tb_i2s_tx;

    localparam real MCLK_MHZ = 11.2896;
    localparam real MCLK_PERIOD_NS = 1000.0 / MCLK_MHZ;

    logic        mclk;
    logic        rst;
    logic [15:0] sample_l;
    logic [15:0] sample_r;
    logic        sample_req;
    logic        bclk;
    logic        lrclk;
    logic        pbdat;

    i2s_tx dut (
        .mclk       (mclk),
        .rst        (rst),
        .sample_l   (sample_l),
        .sample_r   (sample_r),
        .sample_req (sample_req),
        .bclk       (bclk),
        .lrclk      (lrclk),
        .pbdat      (pbdat)
    );

    initial begin
        mclk = 1'b0;
        forever #(MCLK_PERIOD_NS / 2.0) mclk = ~mclk;
    end

    task automatic reset_dut();
        rst = 1'b1;
        sample_l = 16'hA55A;
        sample_r = 16'h1234;
        repeat (20) @(posedge mclk);
        rst = 1'b0;
        repeat (5) @(posedge mclk);
    endtask

    // Simple I2S receiver: capture left/right samples on BCLK rising edges.
    logic        lrclk_q;
    logic [4:0]  bit_cnt;
    logic [15:0] left_shift;
    logic [15:0] right_shift;
    logic [15:0] captured_l;
    logic [15:0] captured_r;
    logic        left_ready;
    logic        right_ready;

    always_ff @(posedge bclk or posedge rst) begin
        if (rst) begin
            lrclk_q     <= 1'b1;
            bit_cnt     <= '0;
            left_shift  <= '0;
            right_shift <= '0;
            captured_l  <= '0;
            captured_r  <= '0;
            left_ready  <= 1'b0;
            right_ready <= 1'b0;
        end else begin
            lrclk_q <= lrclk;
            left_ready  <= 1'b0;
            right_ready <= 1'b0;

            // LRCLK transitions reset the per-channel bit counter.
            if ((!lrclk && lrclk_q) || (lrclk && !lrclk_q)) begin
                bit_cnt <= '0;
            end else begin
                bit_cnt <= bit_cnt + 1'b1;
            end

            // Capture the 16 data bits after the one-BCLK delay.
            if (!lrclk) begin
                if (bit_cnt < 5'd16) begin
                    left_shift <= {left_shift[14:0], pbdat};
                    if (bit_cnt == 5'd15) begin
                        captured_l <= {left_shift[14:0], pbdat};
                        left_ready <= 1'b1;
                    end
                end
            end else begin
                if (bit_cnt < 5'd16) begin
                    right_shift <= {right_shift[14:0], pbdat};
                    if (bit_cnt == 5'd15) begin
                        captured_r <= {right_shift[14:0], pbdat};
                        right_ready <= 1'b1;
                    end
                end
            end
        end
    end

    bit test_failed = 1'b0;

    task automatic check_channels(input [15:0] exp_l, input [15:0] exp_r);
        logic [15:0] got_l, got_r;
        // Wait for a frame start so the new samples are loaded, then capture
        // each half-frame independently.
        wait(sample_req);
        @(posedge mclk);
        wait(left_ready);
        @(posedge mclk);
        got_l = captured_l;
        wait(right_ready);
        @(posedge mclk);
        got_r = captured_r;

        if (got_l !== exp_l) begin
            $error("Left sample mismatch: expected %h, got %h", exp_l, got_l);
            test_failed = 1'b1;
        end
        if (got_r !== exp_r) begin
            $error("Right sample mismatch: expected %h, got %h", exp_r, got_r);
            test_failed = 1'b1;
        end
    endtask

    initial begin
        $display("Starting tb_i2s_tx...");
        reset_dut();

        // Test pattern 1.
        sample_l = 16'hA55A;
        sample_r = 16'h1234;
        check_channels(sample_l, sample_r);

        // Test pattern 2.
        sample_l = 16'h7FFF;
        sample_r = 16'h8001;
        check_channels(sample_l, sample_r);

        // Test pattern 3.
        sample_l = 16'h0000;
        sample_r = 16'hFFFF;
        check_channels(sample_l, sample_r);

        if (test_failed) begin
            $display("TEST FAILED");
        end else begin
            $display("TEST PASSED");
        end
        $finish;
    end

endmodule : tb_i2s_tx
