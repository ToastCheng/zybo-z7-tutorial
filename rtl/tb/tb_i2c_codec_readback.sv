`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_i2c_codec_readback.sv
// Testbench for top_i2c_codec_readback.
//
// The DUT automatically writes the 11-register SSM2603 initialization table,
// then performs a repeated-START read of register R0.  A simple I2C slave stub
// acknowledges every written byte and returns 8'hB4 during the read phase.
//
// Pass criteria:
//   - No ACK errors are flagged by the DUT.
//   - The read byte captured by the DUT is 8'hB4.
//   - led[3:0] shows the lower nibble (4'h4) once the sequence is done.
//------------------------------------------------------------------------------

module tb_i2c_codec_readback;

    import board_pkg::*;

    localparam int CLK_PERIOD_NS = 1_000_000_000 / CLK_FREQ_HZ;  // 8 ns

    logic clk;
    logic [3:0] btn;
    logic [3:0] sw;
    logic [3:0] led;
    logic [2:0] rgb_led;
    logic uart_rx;
    logic uart_tx;
    wire  ac_scl;
    wire  ac_sda;
    logic ac_muten;

    // Pull-ups model the board resistors.
    pullup (ac_scl);
    pullup (ac_sda);

    // DUT with a short debounce time for fast simulation.
    top_i2c_codec_readback #(
        .DEBOUNCE_STABLE_US(0)
    ) dut (
        .clk     (clk),
        .btn     (btn),
        .sw      (sw),
        .led     (led),
        .rgb_led (rgb_led),
        .uart_rx (uart_rx),
        .uart_tx (uart_tx),
        .ac_scl  (ac_scl),
        .ac_sda  (ac_sda),
        .ac_muten(ac_muten)
    );

    // Clock generation.
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // Inputs default.
    initial begin
        btn = 4'b0000;
        sw  = 4'b0000;
        uart_rx = 1'b1;
    end

    // Reset sequence: hold BTN0 high, then release.
    task automatic reset_dut();
        btn[0] = 1'b1;
        repeat (20) @(posedge clk);
        btn[0] = 1'b0;
        repeat (5) @(posedge clk);
    endtask

    // Simple I2C slave model.
    // Acknowledges every byte and returns 8'hB4 when the master reads.
    typedef enum logic [2:0] {
        S_IDLE,
        S_RCV,
        S_ACK,
        S_ACK_HIGH,
        S_READ,
        S_READ_ACK
    } slave_state_t;

    slave_state_t slave_state = S_IDLE;
    logic [7:0] shift_reg = '0;
    logic [2:0] bit_cnt   = '0;
    logic       read_mode = 1'b0;
    logic       read_first_bit = 1'b0;
    logic       slave_sda_low  = 1'b0;
    logic [7:0] read_data = 8'hB4;

    logic scl_q, sda_q;
    logic scl_rising, scl_falling;
    logic start_det, stop_det;

    always_ff @(posedge clk) begin
        scl_q <= ac_scl;
        sda_q <= ac_sda;
    end

    assign scl_rising  =  ac_scl && !scl_q;
    assign scl_falling = !ac_scl &&  scl_q;
    assign start_det   =  ac_scl && sda_q && !ac_sda &&
                         (slave_state inside {S_IDLE, S_RCV});
    assign stop_det    =  ac_scl && !sda_q && ac_sda;

    // Slave SDA drive (open-drain).
    assign ac_sda = slave_sda_low ? 1'b0 : 1'bz;

    always_comb begin
        case (slave_state)
            S_ACK, S_ACK_HIGH: slave_sda_low = 1'b1;
            S_READ:            slave_sda_low = ~read_data[3'd7 - bit_cnt];
            default:           slave_sda_low = 1'b0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (start_det) begin
            slave_state <= S_RCV;
            bit_cnt     <= '0;
        end else if (stop_det) begin
            slave_state <= S_IDLE;
        end else case (slave_state)
            S_RCV: if (scl_rising) begin
                shift_reg <= {shift_reg[6:0], ac_sda};
                bit_cnt   <= bit_cnt + 1'b1;
                if (bit_cnt == 3'd7) begin
                    slave_state <= S_ACK;
                end
            end

            S_ACK: if (scl_rising) begin
                read_mode <= shift_reg[0];
                slave_state <= S_ACK_HIGH;
            end

            S_ACK_HIGH: if (scl_falling) begin
                bit_cnt <= '0;
                read_first_bit <= 1'b1;
                slave_state <= read_mode ? S_READ : S_RCV;
            end

            S_READ: if (scl_rising) begin
                read_first_bit <= 1'b0;
            end else if (scl_falling && !read_first_bit) begin
                if (bit_cnt == 3'd7) begin
                    slave_state <= S_READ_ACK;
                end else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end

            S_READ_ACK: if (scl_rising) begin
                if (ac_sda) begin
                    // Master NACK: end of burst.
                    slave_state <= S_IDLE;
                end else begin
                    bit_cnt <= '0;
                    slave_state <= S_READ;
                end
            end

            default: slave_state <= S_IDLE;
        endcase
    end

    // Test flow.
    bit test_failed = 1'b0;

    initial begin
        $display("Starting top_i2c_codec_readback testbench...");
        reset_dut();

        // Wait for the auto-init + read sequence to complete.
        // 10 ms is comfortably longer than the required ~5.5 ms at 125 MHz.
        repeat (1_250_000) @(posedge clk);

        if (dut.error_reg) begin
            $error("ERROR: DUT flagged an I2C ACK error.");
            test_failed = 1'b1;
        end

        if (!dut.done_all) begin
            $error("ERROR: DUT did not reach done state in time.");
            test_failed = 1'b1;
        end

        if (dut.read_data !== 8'hB4) begin
            $error("ERROR: Expected read_data = 8'hB4, got %h", dut.read_data);
            test_failed = 1'b1;
        end

        if (led !== 4'h4) begin
            $error("ERROR: Expected led = 4'h4, got %h", led);
            test_failed = 1'b1;
        end

        if (rgb_led !== {3{1'b0}}) begin
            // The RGB LED is PWM-dimmed; sample it here (it may be off due
            // to the low duty cycle).  We only check the raw decode signal.
            if (dut.rgb_raw !== 3'b010) begin
                $error("ERROR: Expected rgb_raw = green (done), got %b", dut.rgb_raw);
                test_failed = 1'b1;
            end
        end

        if (test_failed) begin
            $display("TEST FAILED");
        end else begin
            $display("TEST PASSED");
        end

        $finish;
    end

endmodule : tb_i2c_codec_readback
