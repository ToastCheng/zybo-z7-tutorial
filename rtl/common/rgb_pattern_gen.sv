`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// rgb_pattern_gen.sv
// Pattern generator for a single RGB LED.
//
// Given a 4-bit mode select and a periodic tick, it produces three
// pulse-width-modulation duty values (one per color channel).  Static modes
// output a constant color; animated modes update their color on every tick.
//------------------------------------------------------------------------------

module rgb_pattern_gen #(
    parameter int INTENSITY_BITS = 3  // duty range is 0 .. (2^INTENSITY_BITS - 1)
)(
    input  logic clk,
    input  logic tick,               // one-cycle pulse that advances animations
    input  logic [3:0] mode,         // 16 possible patterns
    output logic [INTENSITY_BITS-1:0] r,
    output logic [INTENSITY_BITS-1:0] g,
    output logic [INTENSITY_BITS-1:0] b
);

    localparam [INTENSITY_BITS-1:0] MAX = '1;

    // Free-running animation state.  It increments on every tick, wrapping
    // naturally because it is the same width as the output intensity.
    logic [INTENSITY_BITS-1:0] state = '0;

    // Breathe animation state: a triangle wave 0 -> MAX -> 0.
    logic [INTENSITY_BITS-1:0] breathe = '0;
    logic breathe_dir = 1'b1;  // 1 = counting up, 0 = counting down

    always_ff @(posedge clk) begin
        if (tick) begin
            state <= state + 1'b1;

            if (breathe_dir) begin
                if (breathe == MAX) begin
                    breathe_dir <= 1'b0;
                    breathe     <= breathe - 1'b1;
                end else begin
                    breathe <= breathe + 1'b1;
                end
            end else begin
                if (breathe == '0) begin
                    breathe_dir <= 1'b1;
                    breathe     <= breathe + 1'b1;
                end else begin
                    breathe <= breathe - 1'b1;
                end
            end
        end
    end

    always_comb begin
        case (mode)
            // Static colors ---------------------------------------------------
            4'd0:  begin r = '0;   g = '0;   b = '0;   end  // off
            4'd1:  begin r = MAX;  g = '0;   b = '0;   end  // red
            4'd2:  begin r = '0;   g = MAX;  b = '0;   end  // green
            4'd3:  begin r = '0;   g = '0;   b = MAX;  end  // blue
            4'd4:  begin r = MAX;  g = MAX;  b = '0;   end  // yellow
            4'd5:  begin r = '0;   g = MAX;  b = MAX;  end  // cyan
            4'd6:  begin r = MAX;  g = '0;   b = MAX;  end  // magenta
            4'd7:  begin r = MAX;  g = MAX;  b = MAX;  end  // white

            // Animated patterns -----------------------------------------------
            4'd8:  begin  // slow rainbow fade
                r = state;
                g = state + INTENSITY_BITS'(2);
                b = state + INTENSITY_BITS'(3);
            end
            4'd9:  begin  // fast rainbow fade
                r = state;
                g = state + INTENSITY_BITS'(3);
                b = state + INTENSITY_BITS'(5);
            end
            4'd10: begin  // white breathe
                r = breathe;
                g = breathe;
                b = breathe;
            end

            // Unused / reserved modes -----------------------------------------
            default: begin r = '0; g = '0; b = '0; end
        endcase
    end

endmodule : rgb_pattern_gen
