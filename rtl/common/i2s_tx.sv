`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// i2s_tx.sv
// I2S transmit serializer (Philips standard).
//
// Assumes a 64-BCLK frame (32 slots per channel) with 16-bit samples.
// Data is MSB-first, delayed by one BCLK period after each LRCLK edge.
// All logic runs on the MCLK domain; BCLK and LRCLK are generated as enables.
//
// PBDAT is registered on BCLK falling edges so the codec sees stable data on
// the subsequent BCLK rising edge.
//------------------------------------------------------------------------------

module i2s_tx (
    input  logic        mclk,
    input  logic        rst,
    input  logic [15:0] sample_l,
    input  logic [15:0] sample_r,
    output logic        sample_req, // pulse at the start of each frame
    output logic        bclk,
    output logic        lrclk,
    output logic        pbdat
);

    // MCLK-to-BCLK divider: 4 MCLK cycles per BCLK period.
    localparam int MCLK_PER_BCLK = 4;
    logic [1:0] mclk_div;

    // BCLK period counter: 64 BCLK periods per LRCLK frame.
    logic [5:0] bclk_cnt;

    // Shift register holds the currently transmitted channel sample.
    logic [15:0] shift_reg;

    // Registered output bit.
    logic pbdat_reg;

    // BCLK edges within the MCLK domain.
    logic bclk_rise;
    logic bclk_fall;

    assign bclk      = (mclk_div < 2);
    assign bclk_rise = (mclk_div == 2'd0);
    assign bclk_fall = (mclk_div == 2'd2);
    assign pbdat     = pbdat_reg;

    always_ff @(posedge mclk) begin
        if (rst) begin
            mclk_div    <= '0;
            bclk_cnt    <= '0;
            shift_reg   <= '0;
            lrclk       <= 1'b1;
            pbdat_reg   <= 1'b0;
            sample_req  <= 1'b0;
        end else begin
            // Divide MCLK down to BCLK.
            if (mclk_div == MCLK_PER_BCLK - 1)
                mclk_div <= '0;
            else
                mclk_div <= mclk_div + 1'b1;

            sample_req <= 1'b0;

            // BCLK rising edge: advance the frame counter and request a new
            // stereo sample at the start of each frame.
            if (bclk_rise) begin
                bclk_cnt <= bclk_cnt + 1'b1;
                if (bclk_cnt == 6'd63)
                    sample_req <= 1'b1;
            end

            // BCLK falling edge: update LRCLK, load/shift the data, and set
            // the output value for the next BCLK high period.  Output the MSB
            // *before* shifting so no bit is lost.
            if (bclk_fall) begin
                lrclk <= (bclk_cnt >= 6'd32);

                case (bclk_cnt)
                    6'd0:  begin shift_reg <= sample_l;      pbdat_reg <= 1'b0; end
                    6'd32: begin shift_reg <= sample_r;      pbdat_reg <= 1'b0; end
                    6'd16, 6'd48: begin                      pbdat_reg <= shift_reg[15]; end
                    default: begin
                        if ((bclk_cnt >= 6'd1  && bclk_cnt <= 6'd15) ||
                            (bclk_cnt >= 6'd33 && bclk_cnt <= 6'd47)) begin
                            pbdat_reg <= shift_reg[15];
                            shift_reg <= {shift_reg[14:0], 1'b0};
                        end else begin
                            pbdat_reg <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end

endmodule : i2s_tx
