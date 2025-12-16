// defs.svh
`ifndef SHARED_DEFS
`define SHARED_DEFS
    
    typedef enum logic [2:0] {
		IEEE_near   = 3'b000,
		IEEE_zero   = 3'b001,
		IEEE_pinf   = 3'b010,
		IEEE_ninf   = 3'b011,
		near_up     = 3'b100,
		away_zero   = 3'b101
	} rounding_mode;
	
	typedef enum logic [31:0] {
		POS_INF = 32'h7F800000,
		NEG_INF = 32'hFF800000,
		POS_ZERO = 32'h00000000,
		NEG_ZERO = 32'h80000000,
		POS_NAN = 32'h7FC00001,
		NEG_NAN = 32'hFFF80001,
		POS_SNAN = 32'h7F800001,
		NEG_SNAN = 32'hFFF00001,
		NEG_NORMAL = 32'hC0000000,
		POS_NORMAL = 32'h40000000,
		NEG_DENORMAL = 32'h80000001,
		POS_DENORMAL = 32'h00000001
	} corner_case_t;

`endif