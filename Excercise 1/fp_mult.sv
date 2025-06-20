`include "normalize_mult.sv"
`include "round_mult.sv"
`include "exception_mult.sv"

module fp_mult(
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  rnd,       	
    output logic [31:0] z,
    output logic [7:0]  status);

	localparam int EXPONENT_BIAS = 127;
	localparam int signed EXP_MIN = -126;	
    localparam int EXP_MAX = 254;	// 255 is reserved for infinity
	
    logic sign_a, sign_b, sign_z;
    logic [7:0]  exp_a, exp_b, exp_z;
    logic [22:0] frac_a, frac_b;
    logic [23:0] mant_a, mant_b;
    logic [47:0] mant_product;
	logic [9:0]  exp_sum;
    logic carry;
	logic sgn;
	
	// Splitting Input
    assign sign_a = a[31];
    assign sign_b = b[31];
    assign exp_a  = a[30:23];
    assign exp_b  = b[30:23];
    assign frac_a = a[22:0];
    assign frac_b = b[22:0];

    // Add implicit leading 1 to handle denormals
    assign mant_a = (exp_a != 0) ? {1'b1, frac_a} : {1'b0, frac_a};
    assign mant_b = (exp_b != 0) ? {1'b1, frac_b} : {1'b0, frac_b};

    // Output assignments
	assign mant_product = mant_a * mant_b;			// Multiply Mantissas
	assign exp_sum = exp_a + exp_b - EXPONENT_BIAS;	// Add Exponents
	assign sgn = (sign_a ^ sign_b);					// Calculate Sign

	// For initial normalization
	logic sticky, guard;
	logic [22:0] norm_mant;
	logic [9:0] norm_exp;

	mult_norm normalizer(
		.result_p	(mant_product),
		.exp_sum	(exp_sum),
		.sticky		(sticky),
		.guard		(guard),
		.norm_mant	(norm_mant),
		.norm_exp	(norm_exp)
	);

	// For Rounding
	logic [23:0] post_norm_mant;
	assign post_norm_mant = {1'b1, norm_mant};	// 1.mant = 24 bits
	logic inexact;
	logic [24:0] rounded_mant;	// 1 bit for overflow handling
	round_mult round(
		.rnd	(rnd),
		.mant	(post_norm_mant),
		.guard	(guard),
		.sticky	(sticky),
		.sgn	(sgn),
		.result	(rounded_mant),
		.inexact(inexact)
	);


	logic [23:0] post_rounding_mantissa;
    logic [9:0] post_rounding_exponent;
    always_comb begin : POST_ROUNDING
        post_rounding_exponent = rounded_mant[24] ? norm_exp + 1 : norm_exp;
        post_rounding_mantissa = rounded_mant[24] ? rounded_mant >> 1 : rounded_mant;
    end

	// z output before exception module
    logic [31:0] z_calc;
    always_comb begin
        z_calc = {sgn, post_rounding_exponent[7:0], post_rounding_mantissa[22:0]};
    end
    
    // Calculate overflow and underflow
	logic overflow, underflow;

	// Overflow and Underflow Handling
	always_comb begin
    	overflow = (post_rounding_exponent > 8'd254);
    	underflow = (post_rounding_exponent < 8'd1) && (post_rounding_mantissa != 0);
	end
    
    
    // Exception Handling  
    logic [31:0] z_out;
    logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;
    mult_except exception (
        .a(a),
        .b(b),
        .z_calc(z_calc),
        .rnd(rnd),
        .overflow(overflow),
        .underflow(underflow),
        .inexact(inexact),
        .zero_f(zero_f),
        .inf_f(inf_f),
        .nan_f(nan_f),
        .tiny_f(tiny_f),
        .huge_f(huge_f),
        .inexact_f(inexact_f),
        .z(z_out)
    );

	// Final output and status assembly
    always_comb begin
        z = z_out;
        status = {overflow, underflow, zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f};
    end

endmodule

