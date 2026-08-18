`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// audio_clock_gen.sv
// Generate the audio master clock (MCLK) for the Zybo Z7 SSM2603 codec.
//
// The Zybo board has no dedicated audio crystal; the FPGA must drive the
// codec's MCLK input.  This module uses an MMCM to synthesize 11.2896 MHz
// (256 * 44.1 kHz) from the 125 MHz system clock.
//
// MMCM settings for 11.2896 MHz:
//   VCO = 125 MHz * 52 / 7 = 928.571 MHz
//   MCLK = VCO / 82.25 = 11.289622 MHz  (error < 2 ppm)
//
// For simulation the MMCM is bypassed with a simple divider so testbenches do
// not wait for PLL lock.
//------------------------------------------------------------------------------

module audio_clock_gen (
    input  logic clk,   // 125 MHz system clock
    input  logic rst,   // active-high reset
    output logic mclk,  // ~11.2896 MHz audio master clock
    output logic locked // MMCM locked indicator
);

`ifdef SYNTHESIS

    // Synthesis: real MMCM.
    logic mclk_unbuf;
    logic clkfb_unbuf;
    logic clkfb;

    MMCME2_ADV #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (52.0),
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD      (8.0),
        .CLKIN2_PERIOD      (0.0),
        .DIVCLK_DIVIDE      (7),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE"),
        .CLKOUT0_DIVIDE_F   (82.25),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0)
    ) mmcm_inst (
        .CLKIN1   (clk),
        .CLKIN2   (1'b0),
        .CLKINSEL (1'b1),
        .RST      (rst),
        .PWRDWN   (1'b0),
        .CLKFBIN  (clkfb),
        .CLKFBOUT (clkfb_unbuf),
        .CLKFBOUTB(),
        .CLKOUT0  (mclk_unbuf),
        .CLKOUT0B (),
        .CLKOUT1  (),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .LOCKED   (locked),
        .DADDR    (7'b0),
        .DCLK     (1'b0),
        .DEN      (1'b0),
        .DI       (16'b0),
        .DO       (),
        .DRDY     (),
        .PSCLK    (1'b0),
        .PSEN     (1'b0),
        .PSINCDEC (1'b0)
    );

    BUFG fb_bufg (.I(clkfb_unbuf), .O(clkfb));
    BUFG mclk_bufg (.I(mclk_unbuf), .O(mclk));

`else

    // Simulation: simple ~11.3 MHz divider from 125 MHz.
    // 125 MHz / 11 = 11.36 MHz, close enough for protocol verification.
    localparam int DIV = 11;
    localparam int HALF = DIV / 2;  // 5
    logic [$clog2(DIV)-1:0] cnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt   <= '0;
            mclk  <= 1'b0;
            locked<= 1'b0;
        end else begin
            if (cnt == DIV - 1) begin
                cnt <= '0;
                mclk <= ~mclk;
            end else begin
                cnt <= cnt + 1'b1;
            end
            locked <= 1'b1;
        end
    end

`endif

endmodule : audio_clock_gen
