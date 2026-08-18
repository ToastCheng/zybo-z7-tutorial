`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// i2s_rx.sv
// I2S receive deserializer (Philips standard).
//
// Receives a stereo 16-bit I2S stream on RECDAT, synchronized to the supplied
// LRCLK.  The LRCLK input is sampled on internally generated BCLK rising edges
// so the receiver aligns to the transmitter even if the internal counter
// phases differ.
//
// Assumes a 64-BCLK frame (32 slots per channel).  Data is MSB-first, delayed
// by one BCLK after each LRCLK edge.
//------------------------------------------------------------------------------

module i2s_rx (
    input  logic        mclk,
    input  logic        rst,
    input  logic        lrclk,
    input  logic        recdat,
    output logic        sample_req, // pulse at the start of each left frame
    output logic [15:0] sample_l,
    output logic [15:0] sample_r
);

    // MCLK-to-BCLK divider: 4 MCLK cycles per BCLK period.
    logic [1:0] mclk_div;

    // LRCLK registered on BCLK rising edges for edge detection.
    logic lrclk_q;

    // Bit counter within the current half-frame.  After an LRCLK edge, slot 0
    // is the I2S leading 0 and slots 1..16 carry the data bits (MSB first).
    logic [4:0] bit_cnt;

    // Shift register for the currently received channel.
    logic [15:0] shift_reg;

    // BCLK rising-edge strobe.
    logic bclk_rise;
    assign bclk_rise = (mclk_div == 2'd0);

    always_ff @(posedge mclk) begin
        if (rst) begin
            mclk_div   <= '0;
            lrclk_q    <= 1'b1;
            bit_cnt    <= '0;
            shift_reg  <= '0;
            sample_l   <= '0;
            sample_r   <= '0;
            sample_req <= 1'b0;
        end else begin
            // Advance the BCLK divider.
            mclk_div <= mclk_div + 1'b1;
            sample_req <= 1'b0;

            if (bclk_rise) begin
                // Detect an LRCLK edge against the value captured on the
                // previous BCLK rising edge.
                if (lrclk != lrclk_q)
                    bit_cnt <= '0;
                else
                    bit_cnt <= bit_cnt + 1'b1;

                // Always shift in the current RECDAT bit.  The leading 0 after
                // an LRCLK edge is shifted into slot 0; the 16 data bits fill
                // slots 1..16.  After the LSB has been shifted (old bit_cnt==15)
                // the shift register holds the complete sample word.
                shift_reg <= {shift_reg[14:0], recdat};
                if (bit_cnt == 5'd15) begin
                    if (!lrclk)
                        sample_l <= {shift_reg[14:0], recdat};
                    else
                        sample_r <= {shift_reg[14:0], recdat};
                end

                // Update the registered LRCLK *after* the edge comparison.
                lrclk_q <= lrclk;

                // Pulse at the start of each new left frame.
                if (lrclk_q && !lrclk)
                    sample_req <= 1'b1;
            end
        end
    end

endmodule : i2s_rx
