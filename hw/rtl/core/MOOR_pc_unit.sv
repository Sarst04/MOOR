`timescale 1ns/1ps////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_pc_unit.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Program counter with redirect mux. pcReg resets to RESET_PC-1
//              (in words); the first FETCH uses PC_PLUS1 and advances pcReg
//              when imemReady, so no PC_REG hold input is needed.
//
//              Early-arriving selects (pcSel) resolve first; the late branch
//              decision (branchTaken) drives only the final 2:1 stage, so it
//              is one mux from imemAddr.
//
//              imemAddr is PC_BITS wide; zero extension to the AXI address
//              bus happens at the core boundary.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - PC_REG mux input removed (area)
//   2026-10-13 - pcBranchEn/branchTaken split for timing
//   2026-10-13 - imemAddr narrowed to PC_BITS
////////////////////////////////////////////////////////////////////////////////
module MOOR_pc_unit
    import MOOR_pkg::*;
#(
    parameter [31:0] RESET_PC = 32'h0000_0000,
    parameter integer PC_BITS = 12
) (
    input  logic                 clk,
    input  logic                 rst,

    input  logic                 pcWrite,
    input  pc_sel_t              pcSel,
    input  logic                 pcBranchEn,
    input  logic                 branchTaken,
    input  logic [PC_BITS-1:0]   targetReg,
    input  logic [31:2]          mtvecBase,
    input  logic [31:2]          mepcOut,

    output logic [PC_BITS-3:0]   pcReg,
    output logic [PC_BITS-3:0]   pcPlus1,
    output logic [PC_BITS-1:0]   imemAddr
);
    localparam integer PC_W = PC_BITS - 2;

    logic [PC_W-1:0] fetchWord;
    logic [PC_W-1:0] otherWord;

    assign pcPlus1 = pcReg + 1'b1;

    always_comb begin
        otherWord = pcPlus1;
        unique0 case (pcSel)
            PC_PLUS1:  otherWord = pcPlus1;
            PC_TARGET: otherWord = targetReg[PC_BITS-1:2];
            PC_TRAP:   otherWord = mtvecBase[PC_BITS-1:2];
            PC_EPC:    otherWord = mepcOut[PC_BITS-1:2];
        endcase
    end

    assign fetchWord = (pcBranchEn & branchTaken) ? targetReg[PC_BITS-1:2] : otherWord;

    assign imemAddr  = {fetchWord, 2'b00};

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pcReg <= RESET_PC[PC_BITS-1:2] - 1'b1;
        else if (pcWrite)
            pcReg <= fetchWord;
    end
endmodule
