////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_pkg.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Shared types and instruction encodings for the MOR RV32E core.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Area optimization: WB_SHIFT restored for timing
////////////////////////////////////////////////////////////////////////////////
package MOOR_pkg;

	typedef enum logic [2:0] {
		FETCH   = 3'd0,
		DECODE  = 3'd1,
		EXECUTE = 3'd2,
		SHIFT   = 3'd3,
		MEMORY  = 3'd4
	} state_t;

	typedef enum logic [2:0] {
		WB_ALU   = 3'd0,
		WB_PC4   = 3'd1,
		WB_LOAD  = 3'd2,
		WB_CSR   = 3'd3,
		WB_SHIFT = 3'd4
	} wb_sel_t;

	typedef enum logic [1:0] {
		PC_PLUS1  = 2'd0,
		PC_TARGET = 2'd1,
		PC_TRAP   = 2'd2,
		PC_EPC    = 2'd3
	} pc_sel_t;

	localparam logic [6:0] OPC_LUI     = 7'b0110111;
	localparam logic [6:0] OPC_AUIPC   = 7'b0010111;
	localparam logic [6:0] OPC_JAL     = 7'b1101111;
	localparam logic [6:0] OPC_JALR    = 7'b1100111;
	localparam logic [6:0] OPC_BRANCH  = 7'b1100011;
	localparam logic [6:0] OPC_LOAD    = 7'b0000011;
	localparam logic [6:0] OPC_STORE   = 7'b0100011;
	localparam logic [6:0] OPC_OPIMM   = 7'b0010011;
	localparam logic [6:0] OPC_OP      = 7'b0110011;
	localparam logic [6:0] OPC_MISCMEM = 7'b0001111;
	localparam logic [6:0] OPC_SYSTEM  = 7'b1110011;

	localparam logic [2:0] F3_BEQ  = 3'b000;
	localparam logic [2:0] F3_BNE  = 3'b001;
	localparam logic [2:0] F3_BLT  = 3'b100;
	localparam logic [2:0] F3_BGE  = 3'b101;
	localparam logic [2:0] F3_BLTU = 3'b110;
	localparam logic [2:0] F3_BGEU = 3'b111;

	localparam logic [2:0] F3_LB  = 3'b000;
	localparam logic [2:0] F3_LH  = 3'b001;
	localparam logic [2:0] F3_LW  = 3'b010;
	localparam logic [2:0] F3_LBU = 3'b100;
	localparam logic [2:0] F3_LHU = 3'b101;

	localparam logic [2:0] F3_ADD  = 3'b000;
	localparam logic [2:0] F3_SLL  = 3'b001;
	localparam logic [2:0] F3_SLT  = 3'b010;
	localparam logic [2:0] F3_SLTU = 3'b011;
	localparam logic [2:0] F3_XOR  = 3'b100;
	localparam logic [2:0] F3_SRL  = 3'b101;
	localparam logic [2:0] F3_OR   = 3'b110;
	localparam logic [2:0] F3_AND  = 3'b111;

	localparam logic [2:0] F3_JALR = 3'b000;
	localparam logic [2:0] F3_PRIV = 3'b000;

endpackage
