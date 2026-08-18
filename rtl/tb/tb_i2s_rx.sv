`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_i2s_rx.sv
// Unit test for the I2S receiver.
//
// An i2s_tx instance generates a known stereo stream; its serial output is
// looped directly into the i2s_rx instance.  After the pipeline fills, the
// received left/right samples are compared against the transmitted samples.
//------------------------------------------------------------------------------

module tb_i2s_rx;

    localparam int MCLK_HALF_NS = 44; // ~11.36 MHz

    logic mclk = 1'b0;
    logic rst  = 1'b1;

    always #(MCLK_HALF_NS) mclk = ~mclk;

    logic [15:0] tx_l, tx_r;
    logic        tx_sample_req;

    wire        bclk;
    wire        lrclk;
    wire        pbdat;

    i2s_tx tx (
        .mclk       (mclk),
        .rst        (rst),
        .sample_l   (tx_l),
        .sample_r   (tx_r),
        .sample_req (tx_sample_req),
        .bclk       (bclk),
        .lrclk      (lrclk),
        .pbdat      (pbdat)
    );

    logic [15:0] rx_l, rx_r;
    logic        rx_sample_req;

    i2s_rx rx (
        .mclk       (mclk),
        .rst        (rst),
        .lrclk      (lrclk),
        .recdat     (pbdat),
        .sample_req (rx_sample_req),
        .sample_l   (rx_l),
        .sample_r   (rx_r)
    );

    // Update transmitted samples at the start of each frame.
    always_ff @(posedge mclk) begin
        if (rst) begin
            tx_l <= 16'hA5A5;
            tx_r <= 16'h5A5A;
        end else if (tx_sample_req) begin
            tx_l <= tx_l + 16'd1;
            tx_r <= tx_r - 16'd1;
        end
    end

    // Reference pipeline: remember the samples that were transmitted two
    // frames ago, because the receiver captures them one frame after tx loads
    // them and the testbench samples them on the following frame pulse.
    logic [15:0] expected_l, expected_r;
    logic [15:0] prev_tx_l, prev_tx_r;
    logic [15:0] prev2_tx_l, prev2_tx_r;

    always_ff @(posedge mclk) begin
        if (rst) begin
            prev_tx_l   <= 16'hA5A5;
            prev_tx_r   <= 16'h5A5A;
            prev2_tx_l  <= 16'hA5A5;
            prev2_tx_r  <= 16'h5A5A;
            expected_l  <= 16'hA5A5;
            expected_r  <= 16'h5A5A;
        end else if (tx_sample_req) begin
            prev_tx_l  <= tx_l;
            prev_tx_r  <= tx_r;
            prev2_tx_l <= prev_tx_l;
            prev2_tx_r <= prev_tx_r;
            // The receiver captured the sample that the transmitter just
            // finished sending, which is the current tx_l/tx_r value before
            // the sample_req update increments it.
            expected_l <= tx_l;
            expected_r <= tx_r;
        end
    end

    bit test_failed = 1'b0;

    initial begin
        $display("Starting tb_i2s_rx...");
        repeat (10) @(posedge mclk);
        rst <= 1'b0;

        // Timeout watchdog in case the receiver never pulses sample_req.
        fork
            begin
                repeat (10000) @(posedge mclk);
                $display("TIMEOUT waiting for rx_sample_req");
                $finish;
            end
            begin
                wait (rx_sample_req === 1'b1);
                $display("rx_sample_req first pulse at time %0t", $time);
            end
        join_any
        disable fork;

        // Wait for several complete frames.
        repeat (10) @(posedge rx_sample_req);

        if (rx_l !== expected_l || rx_r !== expected_r) begin
            $error("ERROR: I2S RX mismatch. expected_l=%h rx_l=%h expected_r=%h rx_r=%h",
                   expected_l, rx_l, expected_r, rx_r);
            test_failed = 1'b1;
        end else begin
            $display("I2S RX matched: rx_l=%h rx_r=%h", rx_l, rx_r);
        end

        // Run a few more frames and check again.
        repeat (4) @(posedge rx_sample_req);

        if (rx_l !== expected_l || rx_r !== expected_r) begin
            $error("ERROR: I2S RX mismatch on second check. expected_l=%h rx_l=%h expected_r=%h rx_r=%h",
                   expected_l, rx_l, expected_r, rx_r);
            test_failed = 1'b1;
        end else begin
            $display("I2S RX matched again: rx_l=%h rx_r=%h", rx_l, rx_r);
        end

        if (test_failed)
            $display("TEST FAILED");
        else
            $display("TEST PASSED");

        $finish;
    end

endmodule : tb_i2s_rx
