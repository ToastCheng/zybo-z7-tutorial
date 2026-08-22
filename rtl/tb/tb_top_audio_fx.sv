`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_top_audio_fx.sv
// Integration testbench for top_audio_fx.
//
// Same structure as tb_top_audio_loopback: an I2C slave stub ACKs the codec
// configuration, a second i2s_tx feeds a known stereo pattern into the DUT's
// record input, and an i2s_rx captures the DUT's playback output.
//
// Verified effect settings (the echo depth/mix is covered by tb_audio_fx):
//   - bypass     : output equals the injected pattern
//   - bit-crusher: low bits are masked off
//   - distortion : large samples saturate to full scale
//------------------------------------------------------------------------------

module tb_top_audio_fx;

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

    top_audio_fx #(
        .DEBOUNCE_STABLE_US(0),
        .ECHO_DEPTH(64)
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
        sw  = 4'b0000; // bypass
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

    // Known stereo pattern to process.
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

    // Capture one left-channel sample after skipping a few frames.
    task automatic capture_left(output logic [15:0] s);
        repeat (4) @(posedge pb_sample_req);
        @(posedge pb_sample_req);
        s = captured_l;
    endtask

    task automatic check(string name, logic [15:0] got, logic [15:0] expected);
        if (got !== expected) begin
            $error("ERROR: %s: got %h, expected %h", name, got, expected);
            test_failed = 1'b1;
        end else begin
            $display("OK: %s = %h", name, got);
        end
    endtask

    initial begin
        $dumpfile("tb_top_audio_fx.vcd");
        $dumpvars(0, tb_top_audio_fx);
        $display("Starting tb_top_audio_fx...");
        reset_dut();
        wait_init();

        if (dut.init_err) begin
            $error("ERROR: I2C init failed (ACK error).");
            test_failed = 1'b1;
        end

        if (!test_failed) begin
            logic [15:0] s;

            while (dut.i2s_rst)
                @(posedge clk);

            //--- Bypass: loopback must be bit-identical ----------------------
            sw = 4'b0000;
            repeat (4) @(posedge pb_sample_req); // let switches sync over
            capture_left(s);
            check("bypass", s, TX_LEFT);

            //--- Bit-crusher, intensity 1 (keep 8 bits) ----------------------
            sw = 4'b0101;
            repeat (4) @(posedge pb_sample_req);
            capture_left(s);
            check("crusher keep8", s, TX_LEFT & 16'hFF00);

            //--- Distortion, intensity 3 (x16 -> both channels saturate) -----
            sw = 4'b1111;
            repeat (4) @(posedge pb_sample_req);
            capture_left(s);
            check("distortion clip- (left)", s, 16'h8000);

            //--- Back to bypass ----------------------------------------------
            sw = 4'b0000;
            repeat (4) @(posedge pb_sample_req);
            capture_left(s);
            check("bypass again", s, TX_LEFT);
        end

        if (test_failed) begin
            $display("TEST FAILED");
        end else begin
            $display("TEST PASSED");
        end

        $finish;
    end

endmodule : tb_top_audio_fx
