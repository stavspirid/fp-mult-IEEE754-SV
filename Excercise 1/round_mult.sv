`include "defs.svh"

module round_mult (
    input  logic [2:0] rnd,          // Rounding mode selector
    input  logic [23:0] mant,        // 24-bit mantissa (includes implicit leading 1)
    input  logic guard, sticky, sgn, // Guard, sticky bits, and sign
    output logic [24:0] result,      // Rounded result (25-bit to handle overflow)
    output logic inexact             // 1 if result is inexact
);

	/* 
	/ The result value can either be the same 
	/ 24-bit long Mantissa signal as the input
	/ or the 24-bit Mantissa increased by one bit
	*/

    // Inexact flag: 1 if guard or sticky bit is set
    assign inexact = guard || sticky;

    always_comb begin
        logic round_up;
        case (rounding_mode'(rnd))	// Cast logic to enum
            IEEE_near: begin  // Round to nearest, ties to even
				if (guard == 0) begin
					round_up = 0;
				end else begin
					if (sticky == 0) begin
						round_up = mant[0];	// LSB
					end else begin
						round_up = 1;
					end
				end		 
            end

            IEEE_zero: begin  // Truncate toward zero
				round_up = 1'b0; // Just truncate
            end

            IEEE_pinf: begin  // Round toward +infinity
                round_up = (!sgn && inexact); // If positive and inexact
            end

            IEEE_ninf: begin  // Round toward -infinity
                round_up = !(!sgn && inexact); // If negative and inexact
            end

            near_up: begin    // Round to nearest, ties to +infinity
                round_up = guard; // Guard alone can determine rounding
            end

            away_zero: begin  // Round away from zero
                round_up = 1'b1; // Always round up if inexact
            end

            default: round_up = 1'b0; // Handle undefined modes
        endcase

        // Perform addition with overflow protection
        result = {1'b0, mant} + round_up;
    end

endmodule