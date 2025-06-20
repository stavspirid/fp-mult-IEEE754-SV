`include "defs.svh"

typedef enum bit [2:0]{
    ZERO, INF, NORM, MIN_NORM, MAX_NORM
} interp_t;

// Numeric Interpretation treats denormals as ZERO
function interp_t num_interp (
    input logic [31:0] num
);
    logic [7:0] exp;
    logic [22:0] mant;
    exp = num[30:23];
    mant = num[22:0];

    if (exp == 8'b00000000) begin
        return ZERO;	// Includes both true zeros AND denormals
    end
    else if (exp == 8'b11111111) begin
        return INF;		// Includes both infinity and NaN
    end
    else if (exp == 8'b00000001 && mant == 23'b0) begin
        return MIN_NORM;	// Minimum normal number
    end
    else if (exp == 8'b11111110 && mant == 23'h7FFFFF) begin
        return MAX_NORM;	// Maximum normal number
    end
    else begin
        return NORM;	// Regular normal numbers
    end
endfunction

// Return value 32-bit based on local enum
function logic [31:0] z_num (
    interp_t value
);
    case (value) 
        ZERO: return 32'b0;
        INF: return {1'b0, 8'hFF, 23'b0};
        MIN_NORM: return {1'b0, 8'h01, 23'b0};
        MAX_NORM: return {1'b0, 8'hFE, 23'h7FFFFF};
        default: return 32'b0;
    endcase
endfunction


module mult_except(
    input logic [31:0] a, b, z_calc,
    input logic [2:0] rnd,
    input logic overflow, underflow, inexact,
    output logic [31:0] z,
    output logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f
);
    logic a_sgn, b_sgn;
    logic [7:0] a_exp, b_exp;
    logic [22:0] a_mant, b_mant;
    
    assign a_sgn  = a[31];
    assign b_sgn  = b[31];
    assign a_exp  = a[30:23];
    assign b_exp  = b[30:23];
    assign a_mant = a[22:0];
    assign b_mant = b[22:0];
    
    interp_t int_a, int_b;
    
    always_comb begin
        int_a = num_interp(a);
        int_b = num_interp(b);
        
        // Initialize all flags to 0
        zero_f = 1'b0;
        inf_f = 1'b0;
        nan_f = 1'b0;
        tiny_f = 1'b0;
        huge_f = 1'b0;
        inexact_f = 1'b0;

        // corner case: If one operand is INF/NaN and other is zero/denormal => positive infinity
        if ((a_exp == 8'hFF && b_exp == 8'h00) || (a_exp == 8'h00 && b_exp == 8'hFF)) begin
            z = {1'b0, 8'hFF, 23'b0};  // Always positive infinity
            inf_f = 1'b1;
        end
        // If either operand is INF (includes NaN), result is SIGNED INF
        else if (int_a == INF || int_b == INF) begin
            z = {(a_sgn ^ b_sgn), 8'hFF, 23'b0};	// Signed infinity
            inf_f = 1'b1;
        end
        // Any multiplication with ZERO results in SIGNED ZERO
        else if (int_a == ZERO || int_b == ZERO) begin
            z = {(a_sgn ^ b_sgn), 31'b0};		// Signed zero
            zero_f = 1'b1;
        end

        // Overflow Handling
        else if (overflow) begin
            huge_f = 1'b1;
            if (rnd == IEEE_zero) begin				// Round toward zero
                z = {z_calc[31], 8'hFE, 23'h7FFFFF};// Max normal
            end
            else if (rnd == IEEE_pinf) begin		// Round toward +infinity
                if (z_calc[31]) begin			// Negative
                    z = {1'b1, 8'hFE, 23'h7FFFFF};	// Max negative normal
                end else begin					// Positive
                    z = {1'b0, 8'hFF, 23'b0};		// +Infinity
                end
            end
            else if (rnd == IEEE_ninf) begin// Round toward -infinity
                if (z_calc[31]) begin			// Negative
                    z = {1'b1, 8'hFF, 23'b0};		// -Infinity
                end else begin					// Positive
                    z = {1'b0, 8'hFE, 23'h7FFFFF};	// Max positive normal
                end
            end
            else begin							// For: IEEE_near, near_up, away_zero
                z = {z_calc[31], 8'hFF, 23'b0};	// Default to infinity
            end
        end
        // Underflow Handling
        else if (underflow) begin
            tiny_f = 1'b1;
            if (rnd == near_up || rnd == IEEE_near || rnd == IEEE_zero) begin	// Round to nearest or toward zero
                z = {z_calc[31], 31'b0};		// Signed zero
            end
            else if (rnd == IEEE_pinf) begin	// Round toward +infinity
                if (z_calc[31]) begin
                    z = {1'b1, 31'b0};	// -0
                end else begin
                    z = {1'b0, 8'h01, 23'b0};	// Min positive normal
                end
            end
            else if (rnd == IEEE_ninf) begin	// Round toward -infinity
                if (z_calc[31]) begin
                    z = {1'b1, 8'h01, 23'b0};	// Min negative normal
                end else begin
                    z = {1'b0, 31'b0};	// +0
                end
            end
            else if (rnd == away_zero) begin	// Round away from zero
                z = {z_calc[31], 8'h01, 23'b0};	// Min normal
            end
            else begin
                z = {z_calc[31], 31'b0};	// Default to signed zero
            end
        end
        // Normal case - no overflow or underflow
        else begin
            z = z_calc;
            inexact_f = inexact;
        end
    end

endmodule