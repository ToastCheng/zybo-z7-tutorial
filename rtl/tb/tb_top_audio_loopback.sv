`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_top_audio_loopback.sv
// Integration testbench for top_audio_loopback.
//
// - Provides a 125 MHz system clock and a simple I2C slave stub that ACKs
//   every byte written by the DUT.
// - Uses a second i2s_tx instance (driven from the DUT's MCLK) to generate a
//   known stereo I2S record stream for the DUT.
// - Uses an i2s_rx instance to capture the DUT's playback output and verifies
//   that the loopback path reproduces the transmitted pattern.
//------------------------------------------------------------------------------

module tb_top_audio_loopback;

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

    top_audio_loopback #(
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
        sw  = 4'b0000; // loopback mode
        uart_rx = 1'b1;
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
                slave_state <= S_ACK_HIGH;
            end
            S_ACK_HIGH: if (scl_q && !ac_scl) begin // falling edge of SCL
                slave_state <= S_RCV;
                bit_cnt     <= '0;
            end
            default: slave_state <= S_IDLE;
        endcase
    end

    // Known stereo pattern to loop back.
    localparam logic [15:0] TX_LEFT  = 16'hA5A5;
    localparam logic [15:0] TX_RIGHT = 16'h5A5A;

    // I2S record source, locked to the DUT's MCLK so it is naturally aligned.
    wire src_bclk;
    wire src_lrclk;

    i2s_tx i2s_src (
        .mclk       (dut.mclk),
        .rst        (dut.i2s_rst),
        .sample_l   (TX_LEFT),
        .sample_r   (TX_RIGHT),
        .sample_req (),
        .bclk       (src_bclk),
        .lrclk      (src_lrclk),
        .pbdat      (ac_recdat)
    );

    // I2S playback sink: capture what the DUT transmits.
    logic [15:0] captured_l;
    logic [15:0] captured_r;
    logic        pb_sample_req;

    i2s_rx i2s_sink (
        .mclk       (dut.mclk),
        .rst        (dut.i2s_rst),
        .lrclk      (ac_pblrc),
        .recdat     (ac_pbdat),
        .sample_req (pb_sample_req),
        .sample_l   (captured_l),
        .sample_r   (captured_r)
    );

    bit test_failed = 1'b0;

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
        $dumpfile("tb_top_audio_loopback.vcd");
        $dumpvars(0, tb_top_audio_loopback);
        $display("Starting tb_top_audio_loopback...");
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
            // for the I2S interfaces to start.
            while (dut.i2s_rst)
                @(posedge clk);

            // Skip the first few left-channel frames while the pipeline fills.
            repeat (4) @(posedge pb_sample_req);

            // Capture several left-channel loopback samples and verify the
            // constant test pattern.
            repeat (4) begin
                logic [15:0] s;
                @(posedge pb_sample_req);
                s = captured_l;
                $display("Loopback sample captured: %h", s);
                if (s !== TX_LEFT) begin
                    $error("ERROR: Captured loopback sample %h does not match TX_LEFT %h", s, TX_LEFT);
                    test_failed = 1'b1;
                end
            end
        end

        if (test_failed) begin
            $display("TEST FAILED");
        end else begin
            $display("TEST PASSED");
        end

        $finish;
    end

endmodule : tb_top_audio_loopback
