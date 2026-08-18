`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_i2c_master.sv
// Testbench for the read/write byte-stream I2C master.
//
// Emulates an open-drain pull-up bus and a simple slave stub that:
//   - ACKs every byte the master writes
//   - captures written bytes
//   - returns programmed read bytes after a read address is sent
//------------------------------------------------------------------------------

module tb_i2c_master;

    localparam int CLK_PERIOD = 8;  // 125 MHz

    logic clk = 1'b0;
    logic rst;

    logic       cmd_start;
    logic       cmd_rep_start;
    logic       cmd_stop;
    logic       cmd_write;
    logic       cmd_read;
    logic [7:0] tx_data;
    logic       ack_in;
    logic       busy;
    logic       done;
    logic       ack;
    logic [7:0] rx_data;
    logic       scl_oe;
    logic       sda_oe;
    logic       sda_i;

    wire scl;
    wire sda;

    // Slave SDA drive signal: active high means pull SDA low.
    logic slave_sda_low = 1'b0;

    // Open-drain emulation: bus idles high and is pulled low by either driver.
    assign scl   = scl_oe ? 1'b0 : 1'b1;
    assign sda   = (sda_oe || slave_sda_low) ? 1'b0 : 1'b1;
    assign sda_i = sda;

    i2c_master #(
        .CLK_FREQ_HZ(125_000_000),
        .I2C_FREQ_HZ(100_000)
    ) dut (
        .clk          (clk),
        .rst          (rst),
        .cmd_start    (cmd_start),
        .cmd_rep_start(cmd_rep_start),
        .cmd_stop     (cmd_stop),
        .cmd_write    (cmd_write),
        .cmd_read     (cmd_read),
        .tx_data      (tx_data),
        .ack_in       (ack_in),
        .busy         (busy),
        .done         (done),
        .ack          (ack),
        .rx_data      (rx_data),
        .scl_oe       (scl_oe),
        .sda_oe       (sda_oe),
        .sda_i        (sda_i)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Slave model: captures writes, ACKs, and drives read data.
    // Start/stop detection and write-data capture use the *master's* SDA
    // contribution so the slave does not trigger on its own ACK drive.
    logic        scl_q = 1'b1, sda_master_q = 1'b1;
    logic        sda_master;
    logic        scl_rising, scl_falling;
    logic        start_det, stop_det;

    assign sda_master = sda_oe ? 1'b0 : 1'b1;

    always_ff @(posedge clk) begin
        scl_q        <= scl;
        sda_master_q <= sda_master;
    end

    assign scl_rising  = scl && !scl_q;
    assign scl_falling = !scl && scl_q;

    typedef enum logic [2:0] {
        S_IDLE,
        S_RCV,
        S_ACK,
        S_ACK_HIGH,
        S_READ,
        S_READ_ACK
    } slave_state_t;
    slave_state_t slave_state = S_IDLE;

    logic [2:0]  bit_cnt = '0;
    logic [7:0]  shift_reg = '0;
    logic [7:0]  captured [0:3];
    logic [1:0]  byte_idx = '0;
    logic [1:0]  read_idx = '0;
    logic        read_mode = 1'b0;
    logic        read_first_bit = 1'b0;

    assign start_det = scl && sda_master_q && !sda_master &&
                       (slave_state inside {S_IDLE, S_RCV});
    assign stop_det  = scl && !sda_master_q && sda_master;

    // Data the slave returns during a read.
    logic [7:0]  read_data [0:1] = '{8'h00, 8'h17};

    // Combinational open-drain drive: low when ACKing or when the current
    // read bit is 0.  The sequential block below only updates state/bit counters.
    always_comb begin
        if (rst) begin
            slave_sda_low = 1'b0;
        end else begin
            case (slave_state)
                S_ACK, S_ACK_HIGH: slave_sda_low = 1'b1;
                S_READ:            slave_sda_low = ~read_data[read_idx][3'd7 - bit_cnt];
                default:           slave_sda_low = 1'b0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            slave_state <= S_IDLE;
            bit_cnt     <= '0;
            shift_reg   <= '0;
            byte_idx    <= '0;
            read_idx    <= '0;
            read_mode   <= 1'b0;
            read_first_bit <= 1'b0;
        end else begin
            if (start_det) begin
                slave_state <= S_RCV;
                bit_cnt     <= '0;
                read_idx    <= '0;
            end else if (stop_det) begin
                slave_state <= S_IDLE;
            end else begin
                case (slave_state)
                    S_IDLE: ;

                    S_RCV: begin
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda_master};
                            bit_cnt   <= bit_cnt + 1'b1;
                            if (bit_cnt == 3'd7) begin
                                captured[byte_idx] <= {shift_reg[6:0], sda_master};
                                byte_idx           <= byte_idx + 1'b1;
                                slave_state        <= S_ACK;
                            end
                        end
                    end

                    S_ACK: begin
                        if (scl_rising) begin
                            read_mode   <= shift_reg[0];
                            slave_state <= S_ACK_HIGH;
                        end
                    end

                    S_ACK_HIGH: begin
                        if (scl_falling) begin
                            bit_cnt        <= '0;
                            read_first_bit <= 1'b1;
                            slave_state    <= read_mode ? S_READ : S_RCV;
                        end
                    end

                    S_READ: begin
                        // Output is combinational above.  The first SCL falling
                        // edge after entering this state only sets up the first
                        // bit; after that we advance the bit counter on each
                        // falling edge.
                        if (scl_rising) begin
                            read_first_bit <= 1'b0;
                        end else if (scl_falling && !read_first_bit) begin
                            if (bit_cnt == 3'd7) begin
                                slave_state <= S_READ_ACK;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end

                    S_READ_ACK: begin
                        if (scl_rising) begin
                            if (sda_master) begin
                                // Master NACK: end of read burst.
                                slave_state <= S_IDLE;
                            end else begin
                                // Master ACK: send next byte.
                                read_idx       <= read_idx + 1'b1;
                                bit_cnt        <= '0;
                                read_first_bit <= 1'b1;
                                slave_state    <= S_READ;
                            end
                        end
                    end

                    default: slave_state <= S_IDLE;
                endcase
            end
        end
    end

    // Helper task: wait for the I2C master to finish its current command.
    task automatic wait_done();
        begin
            @(posedge done);
        end
    endtask

    initial begin
        bit test_failed = 1'b0;

        $dumpfile("tb_i2c_master.vcd");
        $dumpvars(0, tb_i2c_master);

        rst           <= 1'b1;
        cmd_start     <= 1'b0;
        cmd_rep_start <= 1'b0;
        cmd_stop      <= 1'b0;
        cmd_write     <= 1'b0;
        cmd_read      <= 1'b0;
        tx_data       <= '0;
        ack_in        <= 1'b0;
        repeat (5) @(posedge clk);
        rst <= 1'b0;
        repeat (2) @(posedge clk);

        //---------------------------------------------------------------------
        // Test 1: pure write transaction (START + 3 bytes + STOP)
        //---------------------------------------------------------------------
        cmd_start <= 1'b1; @(posedge clk); cmd_start <= 1'b0;
        wait_done();

        tx_data <= 8'h34;
        cmd_write <= 1'b1; @(posedge clk); cmd_write <= 1'b0;
        wait_done();
        if (!ack) begin test_failed = 1'b1; $error("Expected ACK for device address"); end

        tx_data <= 8'h0C;
        cmd_write <= 1'b1; @(posedge clk); cmd_write <= 1'b0;
        wait_done();
        if (!ack) begin test_failed = 1'b1; $error("Expected ACK for payload high byte"); end

        tx_data <= 8'h10;
        cmd_write <= 1'b1; @(posedge clk); cmd_write <= 1'b0;
        wait_done();
        if (!ack) begin test_failed = 1'b1; $error("Expected ACK for payload low byte"); end

        cmd_stop <= 1'b1; @(posedge clk); cmd_stop <= 1'b0;
        wait_done();

        if (captured[0] !== 8'h34) begin test_failed = 1'b1; $error("Expected captured[0] = 0x34, got %h", captured[0]); end
        if (captured[1] !== 8'h0C) begin test_failed = 1'b1; $error("Expected captured[1] = 0x0C, got %h", captured[1]); end
        if (captured[2] !== 8'h10) begin test_failed = 1'b1; $error("Expected captured[2] = 0x10, got %h", captured[2]); end

        //---------------------------------------------------------------------
        // Test 2: register read with repeated START
        // SSM2603 read sequence:
        //   START, dev addr W, reg addr, REP START, dev addr R,
        //   read byte (ACK), read byte (NACK), STOP
        //---------------------------------------------------------------------
        cmd_start <= 1'b1; @(posedge clk); cmd_start <= 1'b0;
        wait_done();

        tx_data <= 8'h34;   // device address, W
        cmd_write <= 1'b1; @(posedge clk); cmd_write <= 1'b0;
        wait_done();
        if (!ack) begin test_failed = 1'b1; $error("Expected ACK for device address W"); end

        tx_data <= 8'h00;   // register address (R0)
        cmd_write <= 1'b1; @(posedge clk); cmd_write <= 1'b0;
        wait_done();
        if (!ack) begin test_failed = 1'b1; $error("Expected ACK for register address"); end

        cmd_rep_start <= 1'b1; @(posedge clk); cmd_rep_start <= 1'b0;
        wait_done();

        tx_data <= 8'h35;   // device address, R
        cmd_write <= 1'b1; @(posedge clk); cmd_write <= 1'b0;
        wait_done();
        if (!ack) begin test_failed = 1'b1; $error("Expected ACK for device address R"); end

        ack_in <= 1'b1;     // expect more bytes
        cmd_read <= 1'b1; @(posedge clk); cmd_read <= 1'b0;
        wait_done();
        if (rx_data !== 8'h00) begin test_failed = 1'b1; $error("Expected rx_data[0] = 0x00, got %h", rx_data); end

        ack_in <= 1'b0;     // last byte
        cmd_read <= 1'b1; @(posedge clk); cmd_read <= 1'b0;
        wait_done();
        if (rx_data !== 8'h17) begin test_failed = 1'b1; $error("Expected rx_data[1] = 0x17, got %h", rx_data); end

        cmd_stop <= 1'b1; @(posedge clk); cmd_stop <= 1'b0;
        wait_done();

        repeat (10) @(posedge clk);

        if (test_failed) begin
            $display("I2C master read/write testbench FAILED.");
            $fatal(0, "Testbench failed due to previous errors");
        end else begin
            $display("I2C master read/write testbench passed.");
        end
        $finish;
    end

endmodule
