`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tb_i2c_master.sv
// Testbench for the byte-stream I2C master.
//
// Instantiates a simple slave stub that acknowledges every byte and captures
// what was transmitted.  The test verifies a full START + 3 bytes + STOP
// transaction.
//------------------------------------------------------------------------------

module tb_i2c_master;

    localparam int CLK_PERIOD = 8;  // 125 MHz

    logic clk = 1'b0;
    logic rst;

    logic cmd_start;
    logic cmd_stop;
    logic cmd_write;
    logic [7:0] tx_data;
    logic busy;
    logic done;
    logic ack;
    logic scl_oe;
    logic sda_oe;
    logic sda_i;

    wire scl;
    wire sda;

    // Slave SDA drive signal, declared before use in the assign below.
    logic slave_sda_low = 1'b0;

    // Open-drain emulation: the bus idles high and is pulled low by either
    // the master or the slave stub.
    assign scl = scl_oe ? 1'b0 : 1'b1;
    assign sda = (sda_oe || slave_sda_low) ? 1'b0 : 1'b1;
    assign sda_i = sda;

    i2c_master #(
        .CLK_FREQ_HZ(125_000_000),
        .I2C_FREQ_HZ(100_000)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .cmd_start (cmd_start),
        .cmd_stop  (cmd_stop),
        .cmd_write (cmd_write),
        .tx_data   (tx_data),
        .busy      (busy),
        .done      (done),
        .ack       (ack),
        .scl_oe    (scl_oe),
        .sda_oe    (sda_oe),
        .sda_i     (sda_i)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Simple I2C slave stub that ACKs every byte and captures it.
    // Bus samples are taken on the posedge of the system clock.  Because the
    // master also updates on the posedge, the state machine waits a small time
    // (#1) after the clock edge so the open-drain combinational drivers have
    // settled before it evaluates edge conditions.
    logic       scl_q = 1'b1, sda_q = 1'b1;
    logic       scl_rising, scl_falling;
    logic       start_det;
    logic [2:0] bit_cnt = '0;
    logic [7:0] shift_reg = '0;
    logic [7:0] captured [0:2];
    logic [1:0] byte_idx = '0;

    always_ff @(posedge clk) begin
        scl_q <= scl;
        sda_q <= sda;
    end

    assign scl_rising  = scl && !scl_q;
    assign scl_falling = !scl && scl_q;
    assign start_det   = scl && sda_q && !sda;

    typedef enum logic [1:0] { S_IDLE, S_RCV, S_ACK, S_ACK_HIGH } slave_state_t;
    slave_state_t slave_state = S_IDLE;

    always @(posedge clk) begin
        #1;
        if (rst) begin
            slave_state   <= S_IDLE;
            bit_cnt       <= '0;
            shift_reg     <= '0;
            slave_sda_low <= 1'b0;
            byte_idx      <= '0;
        end else begin
            case (slave_state)
                S_IDLE: begin
                    slave_sda_low <= 1'b0;
                    if (start_det) begin
                        slave_state <= S_RCV;
                        bit_cnt     <= '0;
                    end
                end

                S_RCV: begin
                    slave_sda_low <= 1'b0;
                    if (scl_rising) begin
                        shift_reg <= {shift_reg[6:0], sda};
                        bit_cnt   <= bit_cnt + 1'b1;
                        if (bit_cnt == 3'd7) begin
                            slave_state        <= S_ACK;
                            captured[byte_idx] <= {shift_reg[6:0], sda};
                            byte_idx           <= byte_idx + 1'b1;
                        end
                    end
                end

                S_ACK: begin
                    slave_sda_low <= 1'b1;
                    if (scl_rising) begin
                        // ACK bit is now being sampled by the master.
                        slave_state <= S_ACK_HIGH;
                    end
                end

                S_ACK_HIGH: begin
                    slave_sda_low <= 1'b1;
                    if (scl_falling) begin
                        slave_sda_low <= 1'b0;
                        slave_state   <= S_RCV;
                        bit_cnt       <= '0;
                    end
                end

                default: slave_state <= S_IDLE;
            endcase
        end
    end

    // Helper task: wait for the I2C master to finish its current command.
    task automatic wait_done();
        begin
            @(posedge done);
        end
    endtask

    initial begin
        $dumpfile("tb_i2c_master.vcd");
        $dumpvars(0, tb_i2c_master);

        rst       <= 1'b1;
        cmd_start <= 1'b0;
        cmd_stop  <= 1'b0;
        cmd_write <= 1'b0;
        tx_data   <= '0;
        repeat (5) @(posedge clk);
        rst <= 1'b0;
        repeat (2) @(posedge clk);

        // Transaction: device address + W, then two payload bytes.
        // 16'h0C10 = write 0x010 to register 6 of the SSM2603.
        // Use single-cycle command strobes; the master latches and runs.
        cmd_start <= 1'b1;
        @(posedge clk);
        cmd_start <= 1'b0;
        wait_done();

        tx_data   <= 8'h34;
        cmd_write <= 1'b1;
        @(posedge clk);
        cmd_write <= 1'b0;
        wait_done();
        if (!ack) $error("Expected ACK for device address");

        tx_data   <= 8'h0C;
        cmd_write <= 1'b1;
        @(posedge clk);
        cmd_write <= 1'b0;
        wait_done();
        if (!ack) $error("Expected ACK for payload high byte");

        tx_data   <= 8'h10;
        cmd_write <= 1'b1;
        @(posedge clk);
        cmd_write <= 1'b0;
        wait_done();
        if (!ack) $error("Expected ACK for payload low byte");

        cmd_stop <= 1'b1;
        @(posedge clk);
        cmd_stop <= 1'b0;
        wait_done();

        // Allow the slave to settle and detect the stop.
        repeat (10) @(posedge clk);

        // Verify the slave captured the bytes correctly.
        if (captured[0] !== 8'h34) $error("Expected captured[0] = 0x34, got %h", captured[0]);
        if (captured[1] !== 8'h0C) $error("Expected captured[1] = 0x0C, got %h", captured[1]);
        if (captured[2] !== 8'h10) $error("Expected captured[2] = 0x10, got %h", captured[2]);

        $display("I2C master testbench passed.");
        $finish;
    end

endmodule
