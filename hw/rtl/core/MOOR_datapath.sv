////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_datapath.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Datapath top level. instrReg[1:0] is not stored (always 2'b11
//              for 32-bit instructions). WB_SHIFT restored for timing.
//
//              Address widths:
//                dmemAddr   = 32 bits (full ALU sum, computed in MEMORY)
//                imemAddr   = PC_BITS wide
//              targetWord holds only the PC word address of control-flow
//              targets; load/store effective addresses are produced by the
//              shared ALU during MEMORY instead of being stored.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - instrReg[1:0] not stored, pcBranchEn wired to pc_unit
//   2026-10-13 - WB_SHIFT restored for timing
//   2026-10-13 - USE_LATCH, SERIAL_SHIFTER, HART_ID propagated
//   2026-10-13 - imemAddr narrowed to PC_BITS
//   2026-10-13 - targetWord narrowed; dmemAddr uses full ALU sum
//   2026-10-18 - Zmmul: MOOR_mul sequencer on shared adder, opA as accumulator
////////////////////////////////////////////////////////////////////////////////
module MOOR_datapath
    import MOOR_pkg::*;
#(
    parameter [31:0] RESET_PC       = 32'h0000_0000,
    parameter [29:0] MTVEC_RESET    = 30'd0,
    parameter integer PC_BITS       = 12,
    parameter bit    USE_LATCH      = 1'b1,
    parameter bit    SERIAL_SHIFTER = 1'b0,
    parameter bit    ZMMUL          = 1'b1,
    parameter [31:0] HART_ID        = 32'd0
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        instrLoad,
    input  logic        opALoad,
    input  logic        opAShift,
    input  logic        shiftLoad,
    input  logic        shiftDec,
    input  logic        shiftUseRs2,
    input  logic        mulLoad,
    input  logic        mulStep,
    input  logic        captureTarget,
    input  logic        pcWrite,
    input  pc_sel_t     pcSel,
    input  logic        pcBranchEn,
    input  logic        rfWrite,
    input  logic [3:0]  rfReadAddr,
    input  logic [3:0]  rfWriteAddr,
    input  wb_sel_t     wbSel,
    input  logic        csrWriteEn,
    input  logic        trapEnter,
    input  logic        mretEnter,
    input  logic        addA_pc,
    input  logic        addA_zero,
    input  logic        addA_rs1,
    input  logic        addB_rs2,
    input  logic        addSub,
    input  logic        isOpAny,

    output logic [PC_BITS-1:0] imemAddr,
    input  logic [31:0] imemRData,

    output logic [31:0] dmemAddr,
    output logic [3:0]  dmemStrb,
    output logic [31:0] dmemWData,
    input  logic [31:0] dmemRData,

    input  logic        swIrq,
    input  logic        timerIrq,
    input  logic        extIrq,

    output logic [31:0] instrReg,
    output logic        shiftReady,
    output logic        mulReady,
    output logic        mulCorrA,
    output logic        mulCorrB,
    output logic        irqTake
);
    localparam integer PC_W = PC_BITS - 2;

    logic [2:0]         funct3;
    logic [31:2]        instrHi;
    logic [PC_W-1:0]    pcReg;
    logic [PC_W-1:0]    pcPlus1;
    logic [PC_W-1:0]    targetWord;
    logic [PC_BITS-1:0] targetAddr;
    logic [31:0]        opA;
    logic [4:0]         shiftAmount;

    logic               branchTaken;

    logic [31:0] imm;
    logic [31:0] rfReadData;
    logic [31:0] rfWriteData;
    logic [31:0] sum;
    logic [31:0] aluResult;
    logic [31:0] shiftNext;
    logic [31:0] accNext;
    logic [31:0] mulLo;
    logic        adderCout;
    logic [31:0] loadData;
    logic [31:0] csrReadData;
    logic [31:0] csrSrc;
    logic [31:2] mtvecBase;
    logic [31:2] mepcOut;
    logic [31:0] pcReg32;

    assign instrReg    = {instrHi, 2'b11};
    assign funct3      = instrReg[14:12];
    assign dmemAddr    = sum;
    assign targetAddr  = {targetWord, 2'b00};
    assign pcReg32     = {{(32-PC_BITS){1'b0}}, pcReg, 2'b00};
    assign csrSrc      = instrReg[14] ? {27'b0, instrReg[19:15]} : opA;
    assign shiftAmount = shiftUseRs2 ? rfReadData[4:0] : instrReg[24:20];

    MOOR_imm_gen u_imm_gen (
        .instr (instrReg),
        .imm   (imm)
    );

    MOOR_regfile #(
        .USE_LATCH (USE_LATCH)
    ) u_regfile (
        .clk       (clk),
        .readAddr  (rfReadAddr),
        .readData  (rfReadData),
        .writeEn   (rfWrite),
        .writeAddr (rfWriteAddr),
        .writeData (rfWriteData)
    );

    MOOR_alu u_alu (
        .opA         (opA),
        .pc          (pcReg32),
        .rfReadData  (rfReadData),
        .imm         (imm),
        .addA_pc     (addA_pc),
        .addA_zero   (addA_zero),
        .addA_rs1    (addA_rs1),
        .addB_rs2    (addB_rs2),
        .addSub      (addSub),
        .isOpAny     (isOpAny),
        .funct3      (funct3),
        .sum         (sum),
        .adderCout   (adderCout),
        .aluResult   (aluResult),
        .branchTaken (branchTaken)
    );

    MOOR_shifter #(
        .SERIAL_SHIFTER (SERIAL_SHIFTER)
    ) u_shifter (
        .clk         (clk),
        .shiftLoad   (shiftLoad),
        .shiftDec    (shiftDec),
        .shiftAmount (shiftAmount),
        .opA         (opA),
        .rightShift  (funct3[2]),
        .arithShift  (instrReg[30]),
        .shiftNext   (shiftNext),
        .ready       (shiftReady)
    );

    MOOR_mul #(
        .ZMMUL (ZMMUL)
    ) u_mul (
        .clk        (clk),
        .mulLoad    (mulLoad),
        .mulStep    (mulStep),
        .opA        (opA),
        .rfReadData (rfReadData),
        .sum        (sum),
        .adderCout  (adderCout),
        .signA      (~(funct3[1] & funct3[0])),
        .signB      (~funct3[1]),
        .accNext    (accNext),
        .mulLo      (mulLo),
        .ready      (mulReady),
        .corrA      (mulCorrA),
        .corrB      (mulCorrB)
    );

    MOOR_lsu u_lsu (
        .addr      (dmemAddr),
        .rs2       (rfReadData),
        .dmemRData (dmemRData),
        .funct3    (funct3),
        .dmemWData (dmemWData),
        .dmemStrb  (dmemStrb),
        .loadData  (loadData)
    );

    MOOR_csr #(
        .MTVEC_RESET (MTVEC_RESET),
        .PC_BITS     (PC_BITS),
        .HART_ID     (HART_ID)
    ) u_csr (
        .clk         (clk),
        .rst         (rst),
        .csrAddr     (instrReg[31:20]),
        .csrOp       (instrReg[13:12]),
        .csrSrc      (csrSrc),
        .csrWriteEn  (csrWriteEn),
        .csrReadData (csrReadData),
        .trapEnter   (trapEnter),
        .trapPc      ({{(30-PC_W){1'b0}}, pcReg}),
        .mretEnter   (mretEnter),
        .swIrq       (swIrq),
        .timerIrq    (timerIrq),
        .extIrq      (extIrq),
        .mtvecBase   (mtvecBase),
        .mepcOut     (mepcOut),
        .irqTake     (irqTake)
    );

    MOOR_pc_unit #(
        .RESET_PC (RESET_PC),
        .PC_BITS  (PC_BITS)
    ) u_pc (
        .clk         (clk),
        .rst         (rst),
        .pcWrite     (pcWrite),
        .pcSel       (pcSel),
        .pcBranchEn  (pcBranchEn),
        .branchTaken (branchTaken),
        .targetReg   (targetAddr),
        .mtvecBase   (mtvecBase),
        .mepcOut     (mepcOut),
        .pcReg       (pcReg),
        .pcPlus1     (pcPlus1),
        .imemAddr    (imemAddr)
    );

    always_comb begin
        unique0 case (wbSel)
            WB_PC4:   rfWriteData = {{(32-PC_BITS){1'b0}}, pcPlus1, 2'b00};
            WB_LOAD:  rfWriteData = loadData;
            WB_CSR:   rfWriteData = csrReadData;
            WB_SHIFT: rfWriteData = opA;
            WB_MUL:   rfWriteData = mulLo;
            default:  rfWriteData = aluResult;
        endcase
    end

    always_ff @(posedge clk) begin
        if (instrLoad)
            instrHi <= imemRData[31:2];
    end

    always_ff @(posedge clk) begin
        if (opALoad)
            opA <= rfReadData;
        else if (opAShift)
            opA <= shiftNext;
        else if (mulLoad | mulStep)
            opA <= accNext;
    end

    always_ff @(posedge clk) begin
        if (captureTarget)
            targetWord <= sum[PC_BITS-1:2];
    end

endmodule
