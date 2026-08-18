`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// tone_generator.sv
// Direct-digital-synthesis (DDS) sine-wave generator for audio playback.
//
// A phase accumulator indexes a 256-entry signed sine lookup table.  The
// same sample is presented on both left and right channels.
//------------------------------------------------------------------------------

module tone_generator #(
    parameter int SAMPLE_RATE_HZ = 44_100,
    parameter int FREQ_HZ        = 1_000,
    parameter int PHASE_BITS     = 16,
    parameter int TABLE_BITS     = 8
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             sample_req, // pulse: produce next sample
    output logic signed [15:0] sample_l,
    output logic signed [15:0] sample_r
);

    localparam int TABLE_SIZE = 1 << TABLE_BITS;

    // Phase increment = FREQ * 2^PHASE_BITS / SAMPLE_RATE.
    localparam int PHASE_INC = (FREQ_HZ * (1 << PHASE_BITS)) / SAMPLE_RATE_HZ;

    // 256-entry signed 16-bit sine lookup table.
    logic signed [15:0] sine_lut [0:TABLE_SIZE-1] = '{
        16'sh0000, 16'sh0324, 16'sh0648, 16'sh096A, 16'sh0C8C, 16'sh0FAB, 16'sh12C8, 16'sh15E2,
        16'sh18F9, 16'sh1C0B, 16'sh1F1A, 16'sh2223, 16'sh2528, 16'sh2826, 16'sh2B1F, 16'sh2E11,
        16'sh30FB, 16'sh33DF, 16'sh36BA, 16'sh398C, 16'sh3C56, 16'sh3F17, 16'sh41CE, 16'sh447A,
        16'sh471C, 16'sh49B4, 16'sh4C3F, 16'sh4EBF, 16'sh5133, 16'sh539B, 16'sh55F5, 16'sh5842,
        16'sh5A82, 16'sh5CB3, 16'sh5ED7, 16'sh60EB, 16'sh62F1, 16'sh64E8, 16'sh66CF, 16'sh68A6,
        16'sh6A6D, 16'sh6C23, 16'sh6DC9, 16'sh6F5E, 16'sh70E2, 16'sh7254, 16'sh73B5, 16'sh7504,
        16'sh7641, 16'sh776B, 16'sh7884, 16'sh7989, 16'sh7A7C, 16'sh7B5C, 16'sh7C29, 16'sh7CE3,
        16'sh7D89, 16'sh7E1D, 16'sh7E9C, 16'sh7F09, 16'sh7F61, 16'sh7FA6, 16'sh7FD8, 16'sh7FF5,
        16'sh7FFF, 16'sh7FF5, 16'sh7FD8, 16'sh7FA6, 16'sh7F61, 16'sh7F09, 16'sh7E9C, 16'sh7E1D,
        16'sh7D89, 16'sh7CE3, 16'sh7C29, 16'sh7B5C, 16'sh7A7C, 16'sh7989, 16'sh7884, 16'sh776B,
        16'sh7641, 16'sh7504, 16'sh73B5, 16'sh7254, 16'sh70E2, 16'sh6F5E, 16'sh6DC9, 16'sh6C23,
        16'sh6A6D, 16'sh68A6, 16'sh66CF, 16'sh64E8, 16'sh62F1, 16'sh60EB, 16'sh5ED7, 16'sh5CB3,
        16'sh5A82, 16'sh5842, 16'sh55F5, 16'sh539B, 16'sh5133, 16'sh4EBF, 16'sh4C3F, 16'sh49B4,
        16'sh471C, 16'sh447A, 16'sh41CE, 16'sh3F17, 16'sh3C56, 16'sh398C, 16'sh36BA, 16'sh33DF,
        16'sh30FB, 16'sh2E11, 16'sh2B1F, 16'sh2826, 16'sh2528, 16'sh2223, 16'sh1F1A, 16'sh1C0B,
        16'sh18F9, 16'sh15E2, 16'sh12C8, 16'sh0FAB, 16'sh0C8C, 16'sh096A, 16'sh0648, 16'sh0324,
        16'sh0000, 16'shFCDC, 16'shF9B8, 16'shF696, 16'shF374, 16'shF055, 16'shED38, 16'shEA1E,
        16'shE707, 16'shE3F5, 16'shE0E6, 16'shDDDD, 16'shDAD8, 16'shD7DA, 16'shD4E1, 16'shD1EF,
        16'shCF05, 16'shCC21, 16'shC946, 16'shC674, 16'shC3AA, 16'shC0E9, 16'shBE32, 16'shBB86,
        16'shB8E4, 16'shB64C, 16'shB3C1, 16'shB141, 16'shAECD, 16'shAC65, 16'shAA0B, 16'shA7BE,
        16'shA57E, 16'shA34D, 16'shA129, 16'sh9F15, 16'sh9D0F, 16'sh9B18, 16'sh9931, 16'sh975A,
        16'sh9593, 16'sh93DD, 16'sh9237, 16'sh90A2, 16'sh8F1E, 16'sh8DAC, 16'sh8C4B, 16'sh8AFC,
        16'sh89BF, 16'sh8895, 16'sh877C, 16'sh8677, 16'sh8584, 16'sh84A4, 16'sh83D7, 16'sh831D,
        16'sh8277, 16'sh81E3, 16'sh8164, 16'sh80F7, 16'sh809F, 16'sh805A, 16'sh8028, 16'sh800B,
        16'sh8001, 16'sh800B, 16'sh8028, 16'sh805A, 16'sh809F, 16'sh80F7, 16'sh8164, 16'sh81E3,
        16'sh8277, 16'sh831D, 16'sh83D7, 16'sh84A4, 16'sh8584, 16'sh8677, 16'sh877C, 16'sh8895,
        16'sh89BF, 16'sh8AFC, 16'sh8C4B, 16'sh8DAC, 16'sh8F1E, 16'sh90A2, 16'sh9237, 16'sh93DD,
        16'sh9593, 16'sh975A, 16'sh9931, 16'sh9B18, 16'sh9D0F, 16'sh9F15, 16'shA129, 16'shA34D,
        16'shA57E, 16'shA7BE, 16'shAA0B, 16'shAC65, 16'shAECD, 16'shB141, 16'shB3C1, 16'shB64C,
        16'shB8E4, 16'shBB86, 16'shBE32, 16'shC0E9, 16'shC3AA, 16'shC674, 16'shC946, 16'shCC21,
        16'shCF05, 16'shD1EF, 16'shD4E1, 16'shD7DA, 16'shDAD8, 16'shDDDD, 16'shE0E6, 16'shE3F5,
        16'shE707, 16'shEA1E, 16'shED38, 16'shF055, 16'shF374, 16'shF696, 16'shF9B8, 16'shFCDC
    };

    logic [PHASE_BITS-1:0] phase;
    logic [TABLE_BITS-1:0] lut_addr;

    assign lut_addr = phase[PHASE_BITS-1 -: TABLE_BITS];

    always_ff @(posedge clk) begin
        if (rst) begin
            phase    <= '0;
            sample_l <= '0;
            sample_r <= '0;
        end else if (sample_req) begin
            phase    <= phase + PHASE_BITS'(PHASE_INC);
            sample_l <= sine_lut[lut_addr];
            sample_r <= sine_lut[lut_addr];
        end
    end

endmodule : tone_generator
