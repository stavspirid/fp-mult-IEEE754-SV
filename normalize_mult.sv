module mult_norm (
    input logic [47:0] result_p,
    input logic [9:0] exp_sum,
    output logic sticky, guard,
    output logic [22:0] norm_mant,
    output logic [9:0] norm_exp
);

    logic MSB;
	assign MSB = result_p[47];
    
    always_comb begin
		// Normalized Exponent
        if(MSB) begin
            norm_exp = exp_sum + 1'b1;
        end else begin
            norm_exp = exp_sum;
        end
    
    	// Normalized Mantissa
        if(MSB) begin
            norm_mant = result_p[46:24];
        end else begin
            norm_mant = result_p[45:23];
        end
    
    	// Guard Bit
        if(MSB) begin
            guard = result_p[23];
        end else begin
            guard = result_p[22];
        end

    	// Sticky Bit
        if(MSB) begin
            sticky = |result_p[22:0];
        end else begin
            sticky = |result_p[21:0];
        end

		// Denormals Handling
        if ($signed(norm_exp) < 0) begin
            norm_mant = result_p[47] ? result_p[47:25] : result_p[46:24];
            norm_mant = (norm_mant >> -(norm_exp));
            guard = !($signed(norm_exp) < (-23));
            norm_exp = 10'b0;
        end
	end

endmodule