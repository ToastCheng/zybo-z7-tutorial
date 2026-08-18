`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_top_i2s_tone.sv
// Integration testbench for top_i2s_tone.
//
// - Provides a 125 MHz system clock and a simple I2C slave stub that ACKs
//   every byte written by the DUT.
// - Receives the I2S playback stream and captures a few left-channel samples.
// - Verifies that the codec init completes without error and that the tone
//   generator produces a changing (non-DC) waveform.
//------------------------------------------------------------------------------

module tb_top_i2s_tone;

    import board_pkg::*;

    localparam int CLK_PERIOD_NS = 1_000_000_000 / CLK_FREQ_HZ;

    logic clk;
    logic [3:0] btn;
    logic [3:0] sw;
    logic [3:0] led;
    logic [2:0] rgb_led;
    logic uart_rx;
    logic uart_tx;
    wire  ac_scl;
    wire  ac_sda;
    wire  ac_mclk;
    wire  ac_bclk;
    wire  ac_pblrc;
    wire  ac_reclrc;
    wire  ac_pbdat;
    logic ac_recdat;
    wire  ac_muten;

    pullup (ac_scl);
    pullup (ac_sda);

    top_i2s_tone #(
        .DEBOUNCE_STABLE_US(0)
    ) dut (
        .clk      (clk),
        .btn      (btn),
        .sw       (sw),
        .led      (led),
        .rgb_led  (rgb_led),
        .uart_rx  (uart_rx),
        .uart_tx  (uart_tx),
        .ac_scl   (ac_scl),
        .ac_sda   (ac_sda),
        .ac_mclk  (ac_mclk),
        .ac_bclk  (ac_bclk),
        .ac_pblrc (ac_pblrc),
        .ac_reclrc(ac_reclrc),
        .ac_pbdat (ac_pbdat),
        .ac_recdat(ac_recdat),
        .ac_muten (ac_muten)
    );

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    initial begin
        btn = 4'b0000;
        sw  = 4'b0000;
        uart_rx = 1'b1;
        ac_recdat = 1'b0;
    end

    task automatic reset_dut();
        btn[0] = 1'b1;
        repeat (20) @(posedge clk);
        btn[0] = 1'b0;
        repeat (5) @(posedge clk);
    endtask

    // Simple I2C slave stub: ACK everything.
    typedef enum logic [2:0] { S_IDLE, S_RCV, S_ACK, S_ACK_HIGH } slave_state_t;
    slave_state_t slave_state = S_IDLE;
    logic [7:0] shift_reg = '0;
    logic [2:0] bit_cnt   = '0;
    logic       slave_sda_low = 1'b0;

    logic scl_q, sda_q;
    logic start_det, stop_det;

    always_ff @(posedge clk) begin
        scl_q <= ac_scl;
        sda_q <= ac_sda;
    end

    assign start_det = ac_scl && sda_q && !ac_sda &&
                       (slave_state inside {S_IDLE, S_RCV});
    assign stop_det  = ac_scl && !sda_q && ac_sda;
    assign ac_sda    = slave_sda_low ? 1'b0 : 1'bz;

    always_comb begin
        slave_sda_low = (slave_state inside {S_ACK, S_ACK_HIGH});
    end

    always_ff @(posedge clk) begin
        if (start_det) begin
            slave_state <= S_RCV;
            bit_cnt     <= '0;
        end else if (stop_det) begin
            slave_state <= S_IDLE;
        end else case (slave_state)
            S_RCV: if (!scl_q && ac_scl) begin // rising edge of SCL
                shift_reg <= {shift_reg[6:0], ac_sda};
                bit_cnt   <= bit_cnt + 1'b1;
                if (bit_cnt == 3'd7)
                    slave_state <= S_ACK;
            end
            S_ACK: if (!scl_q && ac_scl) begin
                // Drive ACK during the ACK high period.
                slave_state <= S_ACK_HIGH;
            end
            S_ACK_HIGH: if (scl_q && !ac_scl) begin // falling edge of SCL
                slave_state <= S_RCV;
                bit_cnt     <= '0;
            end
            default: slave_state <= S_IDLE;
        endcase
    end

    // I2S receiver: capture left-channel samples.
    logic        lrclk_q;
    logic [4:0]  bit_cnt_i2s;
    logic [15:0] left_shift;
    logic [15:0] captured_l;
    logic        left_ready;

    always_ff @(posedge ac_bclk) begin
        lrclk_q <= ac_pblrc;
        left_ready <= 1'b0;

        if (!ac_pblrc && lrclk_q) begin
            bit_cnt_i2s <= '0;
        end else begin
            bit_cnt_i2s <= bit_cnt_i2s + 1'b1;
        end

        // I2S data bits are valid during BCLK high periods 2..18 for the left
        // channel (period 1 is the leading 0).  Capture the full 16-bit sample
        // after the LSB has been shifted in.
        if (!ac_pblrc && bit_cnt_i2s >= 5'd2 && bit_cnt_i2s <= 5'd18) begin
            left_shift <= {left_shift[14:0], ac_pbdat};
            if (bit_cnt_i2s == 5'd18) begin
                captured_l  <= {left_shift[14:0], ac_pbdat};
                left_ready  <= 1'b1;
            end
        end
    end

    bit test_failed = 1'b0;
    int mclk_edge_cnt = 0;
    logic [15:0] s0, s1;

    always @(posedge dut.mclk)
        mclk_edge_cnt <= mclk_edge_cnt + 1;

    task automatic wait_init();
        int timeout = 8_000_000; // ~64 ms at 125 MHz
        while (!dut.init_done && !dut.init_err && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0) begin
            $error("ERROR: I2C init timed out.");
            test_failed = 1'b1;
        end
    endtask

    initial begin
        $dumpfile("tb_top_i2s_tone.vcd");
        $dumpvars(0, tb_top_i2s_tone);
        $display("Starting tb_top_i2s_tone...");
        reset_dut();
        wait_init();

        if (dut.init_err) begin
            $error("ERROR: I2C init failed (ACK error).");
            test_failed = 1'b1;
        end

        if (!dut.init_done) begin
            $error("ERROR: init_done not asserted.");
            test_failed = 1'b1;
        end

        $display("init_done=%b init_err=%b audio_locked=%b db_btn0=%b init_done_mclk=%b i2s_rst=%b",
                 dut.init_done, dut.init_err, dut.audio_locked, dut.db_btn0, dut.init_done_mclk, dut.i2s_rst);

        if (!test_failed) begin
            // Wait for the init indication to cross into the MCLK domain and
            // for the I2S transmitter to start.
            while (dut.i2s_rst)
                @(posedge clk);

            // The tone generator's first two left-channel samples are 0x0000
            // because the DDS phase starts at 0 and the first sample_req only
            // updates the sample for the following frame.  Skip them, then
            // capture the next two consecutive frames.
            repeat (2) @(posedge left_ready);

            @(posedge left_ready);
            @(posedge clk);
            s0 = captured_l;

            @(posedge left_ready);
            @(posedge clk);
            s1 = captured_l;

            // A 1 kHz sine at 44.1 kHz changes significantly between samples.
            if (s0 == s1) begin
                $error("ERROR: Tone samples are constant (%h), generator may be stuck.", s0);
                test_failed = 1'b1;
            end else begin
                $display("Tone samples: s0=%0d, s1=%0d", $signed(s0), $signed(s1));
            end
        end

        if (test_failed) begin
            $display("TEST FAILED");
        end else begin
            $display("TEST PASSED");
        end

        $finish;
    end

endmodule : tb_top_i2s_tone
