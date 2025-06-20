`timescale 1ns/10ps

`include "fp_mult_top.sv"

module test_status_bits(
	input logic clk,
	input logic rst,
    input logic [31:0] z,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [7:0] status
);

	logic overflow, underflow, zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;
    assign {overflow, underflow, zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f} = status;

	// Check status bit interference using Immediate Assertions
	// All cases of assertion are only checked when rst if set to 1
	always_comb begin
    	if (!$isunknown(rst) && rst) begin
        	// Assert that zero_f and inf_f cannot both be true 
        	assert_zero_inf: assert (!(zero_f && inf_f)) 
            	else $error("ASSERTION FAILED: zero_f and inf_f both asserted simultaneously"); 
        	// Assert that zero_f and nan_f cannot both be true   
        	assert_zero_nan: assert (!(zero_f && nan_f)) 
            	else $error("ASSERTION FAILED: zero_f and nan_f both asserted simultaneously"); 
        	// Assert that inf_f and nan_f cannot both be true 
        	assert_inf_nan: assert (!(inf_f && nan_f)) 
            	else $error("ASSERTION FAILED: inf_f and nan_f both asserted simultaneously"); 
        	// Assert that huge_f and tiny_f cannot both be true 
        	assert_huge_tiny: assert (!(huge_f && tiny_f)) 
            	else $error("ASSERTION FAILED: huge_f and tiny_f both asserted simultaneously"); 
    	end
	end

endmodule

module test_status_z_combinations(
    input logic clk,
	input logic rst,
    input logic [31:0] z,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [7:0] status);

	logic overflow, underflow, zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;
    assign {overflow, underflow, zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f} = status;

	logic exp3;
	assign exp3 = ((a[30:23]==8'b0 && b[30:23]==8'hFF)||(b[30:23]==8'b0 && a[30:23]==8'hFF));
	
	property pr1;
		@(posedge clk) zero_f |-> (z[30:23] == 8'b0);
	endproperty

	property pr2;
		@(posedge clk) inf_f |-> (z[30:23] == 8'hFF);
	endproperty

	property pr3;
    	@(posedge clk) nan_f |-> $past(exp3, 3);
	endproperty

	property pr4;
		@(posedge clk) huge_f |-> (z[30:23]==8'hFF || (z[30:23]==8'hFE && z[22:0]==23'h7FFFFF));
	endproperty

	property pr5;
		@(posedge clk) tiny_f |-> (z[30:23]==8'b0 || (z[30:23]==8'b1 && z[22:0]==23'b0));
	endproperty

	// Assert status properties
	assert property (pr1)
		else $error("zero_f asserted but exponent of z is not all zeros");
	assert property (pr2)
		else $error("inf_f asserted but exponent of z is not all ones");
	assert property (pr3)
		else $error("nan_f asserted but a and b are not as expected 3 cycles before");
	assert property( pr4)
		else $error("huge_f asserted but exponent of z is not all ones or maxNormal");
	assert property (pr5)
		else $error("tiny_f asserted but exponent of z is not all zeros or minNormal");

endmodule
