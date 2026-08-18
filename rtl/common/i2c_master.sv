`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// i2c_master.sv
// Byte-stream I2C master with read and write support.
//
// Generates START, repeated-START, byte writes, byte reads, and STOP from
// single-cycle command strobes.  The master drives the bus in open-drain
// fashion: it either pulls SCL/SDA low or tri-states them so the external
// pull-ups pull them high.
//
// Command interface:
//   cmd_start     - generate a START condition
//   cmd_rep_start - generate a repeated START condition
//   cmd_write     - transmit the byte on tx_data, capture slave ACK on `ack`
//   cmd_read      - receive one byte into rx_data
//   cmd_stop      - generate a STOP condition
//
// For multi-byte reads the caller drives `ack_in`:
//   ack_in = 1 -> master ACKs the byte and the slave sends the next one
//   ack_in = 0 -> master NACKs the byte (last byte)
//------------------------------------------------------------------------------

module i2c_master #(
    parameter int CLK_FREQ_HZ = 125_000_000,
    parameter int I2C_FREQ_HZ = 100_000
)(
    input  logic clk,
    input  logic rst,              // synchronous active-high reset

    // Command interface
    input  logic       cmd_start,     // generate a START condition
    input  logic       cmd_rep_start, // generate a repeated START condition
    input  logic       cmd_write,     // transmit tx_data
    input  logic       cmd_read,      // receive one byte into rx_data
    input  logic       cmd_stop,      // generate a STOP condition
    input  logic [7:0] tx_data,       // byte to transmit
    input  logic       ack_in,        // master ACK/NACK for received byte (1 = ACK)

    output logic       busy,          // high while a command is running
    output logic       done,          // one-cycle pulse when command finishes
    output logic       ack,           // slave ACK for last write (high = ACK)
    output logic [7:0] rx_data,       // byte received from slave

    // Open-drain I2C lines (0 = drive low, 1 = release / high-Z)
    output logic       scl_oe,        // active high -> drive SCL low
    output logic       sda_oe,        // active high -> drive SDA low
    input  logic       sda_i          // sampled SDA value
);

    localparam int HALF_PERIOD = CLK_FREQ_HZ / (2 * I2C_FREQ_HZ);
    localparam int TIMER_WIDTH = $clog2(HALF_PERIOD);

    typedef enum logic [4:0] {
        IDLE,
        START_SDA_LOW,
        START_SCL_LOW,
        REP_START_SDA_HIGH,
        REP_START_SCL_HIGH,
        REP_START_SDA_LOW,
        WRITE_SETUP,
        WRITE_SCL_HIGH,
        WRITE_SCL_LOW,
        ACK_SETUP,
        ACK_HIGH,
        ACK_SAMPLE,
        ACK_LOW,
        READ_SETUP,
        READ_SCL_HIGH,
        READ_SAMPLE,
        READ_SCL_LOW,
        MASTER_ACK_SETUP,
        MASTER_ACK_HIGH,
        MASTER_ACK_LOW,
        STOP_P1,
        STOP_P2,
        STOP_P3
    } state_t;

    state_t state = IDLE;

    logic [TIMER_WIDTH-1:0] timer = '0;
    logic                   half_tick;
    logic [2:0]             bit_cnt = '0;
    logic                   ack_reg = 1'b0;
    logic [7:0]             rx_reg  = '0;

    logic                   scl_val;
    logic                   sda_val;

    // Command latch: single-cycle strobes are captured and held until the
    // bit timer accepts them in IDLE.
    logic start_req     = 1'b0;
    logic rep_start_req = 1'b0;
    logic write_req     = 1'b0;
    logic read_req      = 1'b0;
    logic stop_req      = 1'b0;

    assign half_tick = (timer == TIMER_WIDTH'(HALF_PERIOD - 1));
    assign scl_oe    = ~scl_val;      // drive low when scl_val == 0
    assign sda_oe    = ~sda_val;      // drive low when sda_val == 0
    assign ack       = ack_reg;
    assign rx_data   = rx_reg;

    // Timer: one half-bit period per tick.
    always_ff @(posedge clk) begin
        if (rst) begin
            timer <= '0;
        end else if (half_tick) begin
            timer <= '0;
        end else begin
            timer <= timer + 1'b1;
        end
    end

    // Capture single-cycle command strobes.
    always_ff @(posedge clk) begin
        if (rst) begin
            start_req     <= 1'b0;
            rep_start_req <= 1'b0;
            write_req     <= 1'b0;
            read_req      <= 1'b0;
            stop_req      <= 1'b0;
        end else begin
            if (cmd_start     && !start_req)     start_req     <= 1'b1;
            if (cmd_rep_start && !rep_start_req) rep_start_req <= 1'b1;
            if (cmd_write     && !write_req)     write_req     <= 1'b1;
            if (cmd_read      && !read_req)      read_req      <= 1'b1;
            if (cmd_stop      && !stop_req)      stop_req      <= 1'b1;

            if (half_tick && state == IDLE) begin
                if (start_req)     start_req     <= 1'b0;
                if (rep_start_req) rep_start_req <= 1'b0;
                if (write_req)     write_req     <= 1'b0;
                if (read_req)      read_req      <= 1'b0;
                if (stop_req)      stop_req      <= 1'b0;
            end
        end
    end

    // Main FSM.
    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= IDLE;
            busy    <= 1'b0;
            done    <= 1'b0;
            ack_reg <= 1'b0;
            rx_reg  <= '0;
            bit_cnt <= '0;
            scl_val <= 1'b1;
            sda_val <= 1'b1;
        end else begin
            done <= 1'b0;

            if (half_tick) begin
                case (state)
                    IDLE: begin
                        busy    <= 1'b0;

                        if (start_req) begin
                            state <= START_SDA_LOW;
                            busy  <= 1'b1;
                        end else if (rep_start_req) begin
                            state <= REP_START_SDA_HIGH;
                            busy  <= 1'b1;
                        end else if (write_req) begin
                            state   <= WRITE_SETUP;
                            busy    <= 1'b1;
                            bit_cnt <= 3'd7;
                            ack_reg <= 1'b0;
                        end else if (read_req) begin
                            state   <= READ_SETUP;
                            busy    <= 1'b1;
                            bit_cnt <= 3'd7;
                            rx_reg  <= '0;
                        end else if (stop_req) begin
                            state <= STOP_P1;
                            busy  <= 1'b1;
                        end
                    end

                    START_SDA_LOW: begin
                        // SDA falls while SCL is high -> START.
                        sda_val <= 1'b0;
                        state   <= START_SCL_LOW;
                    end

                    START_SCL_LOW: begin
                        scl_val <= 1'b0;
                        state   <= IDLE;
                        done    <= 1'b1;
                    end

                    REP_START_SDA_HIGH: begin
                        // Release SDA while SCL is low, preparing for a
                        // repeated START.
                        scl_val <= 1'b0;
                        sda_val <= 1'b1;
                        state   <= REP_START_SCL_HIGH;
                    end

                    REP_START_SCL_HIGH: begin
                        scl_val <= 1'b1;
                        state   <= REP_START_SDA_LOW;
                    end

                    REP_START_SDA_LOW: begin
                        // SDA falls while SCL is high -> repeated START.
                        sda_val <= 1'b0;
                        state   <= IDLE;
                        done    <= 1'b1;
                    end

                    WRITE_SETUP: begin
                        scl_val <= 1'b0;
                        sda_val <= tx_data[bit_cnt];
                        state   <= WRITE_SCL_HIGH;
                    end

                    WRITE_SCL_HIGH: begin
                        scl_val <= 1'b1;
                        state   <= WRITE_SCL_LOW;
                    end

                    WRITE_SCL_LOW: begin
                        scl_val <= 1'b0;
                        if (bit_cnt == 3'd0) begin
                            state <= ACK_SETUP;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                            state   <= WRITE_SETUP;
                        end
                    end

                    ACK_SETUP: begin
                        // Release SDA so the slave can drive ACK.
                        sda_val <= 1'b1;
                        state   <= ACK_HIGH;
                    end

                    ACK_HIGH: begin
                        scl_val <= 1'b1;
                        state   <= ACK_SAMPLE;
                    end

                    ACK_SAMPLE: begin
                        ack_reg <= ~sda_i;   // low SDA from slave = ACK
                        state   <= ACK_LOW;
                    end

                    ACK_LOW: begin
                        scl_val <= 1'b0;
                        state   <= IDLE;
                        done    <= 1'b1;
                    end

                    READ_SETUP: begin
                        // Release SDA so the slave can drive the data bit.
                        scl_val <= 1'b0;
                        sda_val <= 1'b1;
                        state   <= READ_SCL_HIGH;
                    end

                    READ_SCL_HIGH: begin
                        scl_val <= 1'b1;
                        state   <= READ_SAMPLE;
                    end

                    READ_SAMPLE: begin
                        rx_reg <= {rx_reg[6:0], sda_i};
                        if (bit_cnt == 3'd0) begin
                            state <= MASTER_ACK_SETUP;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                            state   <= READ_SCL_LOW;
                        end
                    end

                    READ_SCL_LOW: begin
                        scl_val <= 1'b0;
                        state   <= READ_SETUP;
                    end

                    MASTER_ACK_SETUP: begin
                        // Lower SCL, then drive SDA low for ACK or release for
                        // NACK while SCL is low.
                        scl_val <= 1'b0;
                        sda_val <= ack_in ? 1'b0 : 1'b1;
                        state   <= MASTER_ACK_HIGH;
                    end

                    MASTER_ACK_HIGH: begin
                        scl_val <= 1'b1;
                        state   <= MASTER_ACK_LOW;
                    end

                    MASTER_ACK_LOW: begin
                        scl_val <= 1'b0;
                        state   <= IDLE;
                        done    <= 1'b1;
                    end

                    STOP_P1: begin
                        // SDA low while SCL low.
                        sda_val <= 1'b0;
                        state   <= STOP_P2;
                    end

                    STOP_P2: begin
                        scl_val <= 1'b1;
                        state   <= STOP_P3;
                    end

                    STOP_P3: begin
                        // SDA rises while SCL high -> STOP.
                        sda_val <= 1'b1;
                        state   <= IDLE;
                        done    <= 1'b1;
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end

endmodule : i2c_master
