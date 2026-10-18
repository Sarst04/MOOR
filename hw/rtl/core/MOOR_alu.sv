////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_alu.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Shared adder and ALU. addA_zero kept for timing (LUI forces
//              adder A to zero). Produces the sum, ALU result and branch
//              decision from the single 32-bit adder.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - addA_zero restored for timing
//   2026-10-18 - adderCout exported for Zmmul shift-add
////////////////////////////////////////////////////////////////////////////////
module MOOR_alu
    import MOOR_pkg::*;
(
    input  logic [31:0] opA,
    input  logic [31:0] pc,
    input  logic [31:0] rfReadData,
    input  logic [31:0] imm,

    input  logic        addA_pc,
    input  logic        addA_zero,
    input  logic        addA_rs1,
    input  logic        addB_rs2,
    input  logic        addSub,
    input  logic        isOpAny,
    input  logic [2:0]  funct3,

    output logic [31:0] sum,
    output logic        adderCout,
    output logic [31:0] aluResult,
    output logic        branchTaken
);
    logic [31:0] adderA, adderB, adderBx;
    logic        sumZero, ltSigned, ltUnsigned;

    always_comb begin
        if      (addA_zero) adderA = 32'b0;
        else if (addA_pc)   adderA = pc;
        else if (addA_rs1)  adderA = rfReadData;
        else                adderA = opA;

        adderB  = addB_rs2 ? rfReadData : imm;
        adderBx = adderB ^ {32{addSub}};
    end

    assign {adderCout, sum} = adderA + adderBx + addSub;
    assign sumZero    = (sum == 32'b0);
    assign ltSigned   = (adderA[31] ^ adderB[31]) ? adderA[31] : sum[31];
    assign ltUnsigned = ~adderCout;

    always_comb begin
        aluResult = sum;
        if (isOpAny) begin
            unique0 case (funct3)
                F3_SLT:  aluResult = {31'b0, ltSigned};
                F3_SLTU: aluResult = {31'b0, ltUnsigned};
                F3_XOR:  aluResult = adderA ^ adderB;
                F3_OR:   aluResult = adderA | adderB;
                F3_AND:  aluResult = adderA & adderB;
                default: aluResult = sum;
            endcase
        end
    end

    always_comb begin
        unique0 case (funct3)
            F3_BEQ:  branchTaken = sumZero;
            F3_BNE:  branchTaken = ~sumZero;
            F3_BLT:  branchTaken = ltSigned;
            F3_BGE:  branchTaken = ~ltSigned;
            F3_BLTU: branchTaken = ltUnsigned;
            F3_BGEU: branchTaken = ~ltUnsigned;
            default: branchTaken = 1'b0;
        endcase
    end
endmodule
