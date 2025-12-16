`timescale 1ns/10ps

`include "multiplication.sv"
`include "fp_mult_top.sv"
`include "assertions.sv"
`include "defs.svh"

module test_fp_mult;
    logic [31:0] a;
    logic [31:0] b;
    rounding_mode rnd;
    logic [31:0] z;
    logic [7:0] status;
    logic clk;
    logic rst;
    logic [31:0] correct_result;
	string enumRND;
	logic random_flag, corner_flag;

    rounding_mode rounding_modes[6] = '{IEEE_near, IEEE_zero, IEEE_pinf, IEEE_ninf, near_up, away_zero};
    corner_case_t corner_cases[12] = '{
        NEG_SNAN, POS_SNAN,
        NEG_NAN, POS_NAN,
        NEG_INF, POS_INF,
        NEG_NORMAL, POS_NORMAL,
        NEG_DENORMAL, POS_DENORMAL,
        NEG_ZERO, POS_ZERO
    };

    fp_mult_top uut (
        .clk(clk),
        .rst(rst),
        .rnd(rnd),
        .a(a),
        .b(b),
        .z(z),
        .status(status)
    );

	// Bind both assertion modules to the design
    bind fp_mult_top test_status_bits status_bits_checker (
        .clk(clk),
        .rst(rst),
        .z(z),
        .a(a),
        .b(b),
        .status(status)
    );

    bind fp_mult_top test_status_z_combinations status_z_checker (
        .clk(clk),
        .rst(rst),
        .z(z),
        .a(a),
        .b(b),
        .status(status)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset generation
    initial begin
        rst = 0;        // Reset
        #20 rst = 1;    // Deassert reset after two clock edges
        #10;            // Align with clock
    end

    // Test sequence
    initial begin
		random_flag = 1'b0;
		corner_flag = 1'b0;
        // Wait for reset to complete
        wait(rst === 1);
        @(posedge clk);
        
        // Random checks for all rounding modes
        for (int i = 0; i < 4000; i++) begin
            // Apply inputs
            a = $urandom();
            b = $urandom();
            rnd = rounding_modes[i%6];

    		case (rnd)
        		IEEE_near:   enumRND = "IEEE_near";
    	    	IEEE_zero:   enumRND = "IEEE_zero";
    	    	IEEE_pinf:   enumRND = "IEEE_pinf";
   	  	   		IEEE_ninf:   enumRND = "IEEE_ninf";
    	    	near_up:     enumRND = "near_up";
    	    	away_zero:   enumRND = "away_zero";
    		endcase
            
            // Wait 3 cycles for pipeline (1 for input reg, 1 for comb logic, 1 for output reg)
            @(posedge clk);  // Cycle 1: Input sampled
            @(posedge clk);  // Cycle 2: Combinational logic
			correct_result = multiplication(enumRND, a, b);		// Result from multiplicatio function
			@(posedge clk);  // Cycle 3: Output available
			
			if (z == correct_result) begin
                $display("[%0t] SUCCESS: a=%h b=%h rnd=%s got=%h expected=%h",
                       $time, a, b, rnd.name(), z, correct_result);
            end            
            if (z !== correct_result) begin
                $error("[%0t] FAIL: a=%h b=%h rnd=%s got=%h expected=%h",
                       $time, a, b, rnd.name(), z, correct_result);
				random_flag = 1'b1;
            end
        end

		// Display random cases result
        if(random_flag) begin
			$display("Random value tests FAILED.");
		end else begin
			$display("Random value tests completed successfully.");
    	end 

        
        // Corner cases checks
        for (int i = 0; i < 12; i++) begin
            for (int j = 0; j < 12; j++) begin
                // Apply inputs
                a = corner_cases[j];
                b = corner_cases[i];
                rnd = rounding_modes[i%6];
                
                // Wait 3 cycles for pipeline
                @(posedge clk);
                @(posedge clk);
				correct_result = multiplication(string'(rnd), a, b);
                @(posedge clk);

				// Check result
                if (z == correct_result) begin
					$display("[%0t] Corner SUCCESS: a=%h b=%h rnd=%s got=%h expected=%h",
                           $time, a, b, rnd.name(), z, correct_result);
				end
                if (z !== correct_result) begin
                    $error("[%0t] Corner FAIL: a=%h b=%h rnd=%s got=%h expected=%h",
                           $time, a, b, rnd.name(), z, correct_result);
					corner_flag = 1'b1;
                end
            end    
        end
        
		// Display corner cases result
        if(corner_flag) begin
			$display("FAIL: Corner cases tests FAILED.");
		end else begin
			$display("PASS: Corner cases tests completed successfully.");
    	end    
		
		// Display random cases result
        if(random_flag) begin
			$display("FAIL: Random value tests FAILED.");
		end else begin
			$display("PASS: Random value tests completed successfully.");
    	end

		// ================= //
		// ASSERTION TESTING //
		// ================= //
/*
        $display("Testing assertion violations...");
        
        // Force conflicting status bits to test assertions
        force uut.status = 8'b00110000; // zero_f and inf_f both true
        @(posedge clk);
        
        force uut.status = 8'b00101000; // zero_f and nan_f both true  
        @(posedge clk);
        
        force uut.status = 8'b00011000; // inf_f and nan_f both true
        @(posedge clk);
        
        force uut.status = 8'b00000110; // huge_f and tiny_f both true
        @(posedge clk);
        
        // Release forces
        release uut.status;
        @(posedge clk);


		// Test pr1: zero_f should imply z[30:23] == 8'b0
        $display("Testing pr1 violation: zero_f=1 but z exponent != 0");
        a = 32'h00000000;  // zero
        b = 32'h3F800000;  // 1.0
        rnd = IEEE_near;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        // At this point z should be 0, but let's force a non-zero exponent
        force uut.z = 32'h3F800000;  // Force z to have non-zero exponent
        @(posedge clk);
        release uut.z;
        
        // Test pr2: inf_f should imply z[30:23] == 8'hFF
        $display("Testing pr2 violation: inf_f=1 but z exponent != 0xFF");
        a = 32'h7F800000;  // +infinity
        b = 32'h3F800000;  // 1.0
        rnd = IEEE_near;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        // At this point z should be infinity, but let's force a different exponent
        force uut.z = 32'h3F800000;  // Force z to have different exponent
        @(posedge clk);
        release uut.z;

		// Test pr3 valid case: Set up exp3=1 condition then test nan_f
        $display("Testing pr3 valid case: nan_f=1 and exp3 was true 3 cycles ago");
        a = 32'h00000000;  // Zero (exp = 0)
        b = 32'h7F800000;  // +infinity (exp = 0xFF)
        rnd = IEEE_near;
        @(posedge clk);  // Cycle 1 - exp3 should be true here
        @(posedge clk);  // Cycle 2
        @(posedge clk);  // Cycle 3 - exp3 was true 3 cycles ago
        // Now the natural result should be NaN, so nan_f should be valid
        @(posedge clk);  // Should not trigger pr3 violation
        
        // Test pr4: huge_f should imply z is infinity or max normal
        $display("Testing pr4 violation: huge_f=1 but z is not huge");
        a = 32'h3F800000;  // 1.0
        b = 32'h40000000;  // 2.0  
        rnd = IEEE_near;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        // Force huge_f but z is normal result (2.0)
        force uut.status = 8'b00000100;  // huge_f = 1
        @(posedge clk);  // Should trigger pr4 violation
        release uut.status;
        
        // Test pr4 valid case: huge_f=1 and z is infinity
        $display("Testing pr4 valid case: huge_f=1 and z is infinity");
        force uut.status = 8'b00000100;  // huge_f = 1
        force uut.z = 32'h7F800000;      // z = +infinity
        @(posedge clk);  // Should not trigger pr4 violation
        release uut.status;
        release uut.z;
        
        // Test pr4 valid case: huge_f=1 and z is max normal
        $display("Testing pr4 valid case: huge_f=1 and z is max normal");
        force uut.status = 8'b00000100;     // huge_f = 1
        force uut.z = 32'h7F7FFFFF;         // z = max normal (exp=0xFE, mantissa=all 1s)
        @(posedge clk);  // Should not trigger pr4 violation
        release uut.status;
        release uut.z;
        
        // Test pr5: tiny_f should imply z is subnormal or min normal  
        $display("Testing pr5 violation: tiny_f=1 but z is not tiny");
        a = 32'h3F800000;  // 1.0
        b = 32'h40000000;  // 2.0
        rnd = IEEE_near;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        // Force tiny_f but z is normal result (2.0)
        force uut.status = 8'b00000010;  // tiny_f = 1
        @(posedge clk);  // Should trigger pr5 violation
        release uut.status;
        
        // Test pr5 valid case: tiny_f=1 and z is subnormal
        $display("Testing pr5 valid case: tiny_f=1 and z is subnormal");
        force uut.status = 8'b00000010;  // tiny_f = 1
        force uut.z = 32'h00000001;      // z = smallest positive subnormal
        @(posedge clk);  // Should not trigger pr5 violation
        release uut.status;
        release uut.z;
        
        // Test pr5 valid case: tiny_f=1 and z is min normal
        $display("Testing pr5 valid case: tiny_f=1 and z is min normal");
        force uut.status = 8'b00000010;  // tiny_f = 1
        force uut.z = 32'h00800000;      // z = min normal (exp=1, mantissa=0)
        @(posedge clk);  // Should not trigger pr5 violation (based on your pr5 definition)
        release uut.status;
        release uut.z;

        @(posedge clk);
        @(posedge clk);

        // Final summary
        $display("\n=== Test Summary ===");
        if (random_flag || corner_flag) begin
            $display("Some tests FAILED - check error messages above");
        end else begin
            $display("All functional tests PASSED");
        end
        
        $display("Assertion tests completed - check for assertion violations");
        $display("=== Tests Completed ===");

        $finish;
        
        $display("Assertion testing completed.");
*/

		$finish;
    end

endmodule
