////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_core.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: MOR RV32E multi-cycle core top level with AXI4 master
//              interfaces (interface with modport). Internally the core uses
//              a simple request/ready handshake; a thin combinational adapter
//              translates that to AXI4. The AXI slave must respond in the
//              same cycle (zero latency) to preserve the original CPI.
//
//              Address widths at the core boundary:
//                imem.araddr = 32 bits, zero-extended from PC_BITS.
//                dmem.*addr  = 32 bits, driven directly.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Area optimization revision
//   2026-10-13 - pcBranchEn wired for late branchTaken timing optimization
//   2026-10-13 - USE_LATCH, SERIAL_SHIFTER, HART_ID parameters added
//   2026-10-13 - AXI4 master interfaces
//   2026-10-13 - AXI4 interface with modport
//   2026-10-13 - imemAddr narrowed to PC_BITS, zero-extended at AXI boundary
//   2026-10-13 - branchTaken internal wire dropped
////////////////////////////////////////////////////////////////////////////////
module MOOR_core
    import MOOR_pkg::*;
#(
    parameter [31:0] RESET_PC       = 32'h0000_0000,
    parameter [29:0] MTVEC_RESET    = 30'd0,
    parameter integer PC_BITS       = 12,
    parameter bit    USE_LATCH      = 1'b1,
    parameter bit    SERIAL_SHIFTER = 1'b0,
    parameter [31:0] HART_ID        = 32'd0
) (
    input  logic clk,
    input  logic rst,

    MOOR_axi_if.master imem,
    MOOR_axi_if.master dmem,

    input  logic swIrq,
    input  logic timerIrq,
    input  logic extIrq
);
    logic               imemReq;
    logic [PC_BITS-1:0] imemAddr;
    logic               imemReady;
    logic [31:0]        imemRData;
    logic               dmemReq;
    logic               dmemWrite;
    logic [31:0]        dmemAddr;
    logic [3:0]         dmemStrb;
    logic [31:0]        dmemWData;
    logic               dmemReady;
    logic [31:0]        dmemRData;

    logic        instrLoad;
    logic        opALoad;
    logic        opAShift;
    logic        shiftLoad;
    logic        shiftDec;
    logic        shiftUseRs2;
    logic        captureTarget;
    logic        pcWrite;
    pc_sel_t     pcSel;
    logic        pcBranchEn;
    logic        rfWrite;
    logic [3:0]  rfReadAddr;
    logic [3:0]  rfWriteAddr;
    wb_sel_t     wbSel;
    logic        csrWriteEn;
    logic        trapEnter;
    logic        mretEnter;
    logic        addA_pc;
    logic        addA_zero;
    logic        addA_rs1;
    logic        addB_rs2;
    logic        addSub;
    logic        isOpAny;

    logic [31:0] instrReg;
    logic        shiftReady;
    logic        irqTake;

    MOOR_controller u_ctrl (
        .clk           (clk),
        .rst           (rst),
        .instrReg      (instrReg),
        .imemReady     (imemReady),
        .dmemReady     (dmemReady),
        .shiftReady    (shiftReady),
        .irqTake       (irqTake),
        .imemReq       (imemReq),
        .dmemReq       (dmemReq),
        .dmemWrite     (dmemWrite),
        .instrLoad     (instrLoad),
        .opALoad       (opALoad),
        .opAShift      (opAShift),
        .shiftLoad     (shiftLoad),
        .shiftDec      (shiftDec),
        .shiftUseRs2   (shiftUseRs2),
        .captureTarget (captureTarget),
        .pcWrite       (pcWrite),
        .pcSel         (pcSel),
        .pcBranchEn    (pcBranchEn),
        .rfWrite       (rfWrite),
        .rfReadAddr    (rfReadAddr),
        .rfWriteAddr   (rfWriteAddr),
        .wbSel         (wbSel),
        .csrWriteEn    (csrWriteEn),
        .trapEnter     (trapEnter),
        .mretEnter     (mretEnter),
        .addA_pc       (addA_pc),
        .addA_zero     (addA_zero),
        .addA_rs1      (addA_rs1),
        .addB_rs2      (addB_rs2),
        .addSub        (addSub),
        .isOpAny       (isOpAny)
    );

    MOOR_datapath #(
        .RESET_PC       (RESET_PC),
        .MTVEC_RESET    (MTVEC_RESET),
        .PC_BITS        (PC_BITS),
        .USE_LATCH      (USE_LATCH),
        .SERIAL_SHIFTER (SERIAL_SHIFTER),
        .HART_ID        (HART_ID)
    ) u_dp (
        .clk           (clk),
        .rst           (rst),
        .instrLoad     (instrLoad),
        .opALoad       (opALoad),
        .opAShift      (opAShift),
        .shiftLoad     (shiftLoad),
        .shiftDec      (shiftDec),
        .shiftUseRs2   (shiftUseRs2),
        .captureTarget (captureTarget),
        .pcWrite       (pcWrite),
        .pcSel         (pcSel),
        .pcBranchEn    (pcBranchEn),
        .rfWrite       (rfWrite),
        .rfReadAddr    (rfReadAddr),
        .rfWriteAddr   (rfWriteAddr),
        .wbSel         (wbSel),
        .csrWriteEn    (csrWriteEn),
        .trapEnter     (trapEnter),
        .mretEnter     (mretEnter),
        .addA_pc       (addA_pc),
        .addA_zero     (addA_zero),
        .addA_rs1      (addA_rs1),
        .addB_rs2      (addB_rs2),
        .addSub        (addSub),
        .isOpAny       (isOpAny),
        .imemAddr      (imemAddr),
        .imemRData     (imemRData),
        .dmemAddr      (dmemAddr),
        .dmemStrb      (dmemStrb),
        .dmemWData     (dmemWData),
        .dmemRData     (dmemRData),
        .swIrq         (swIrq),
        .timerIrq      (timerIrq),
        .extIrq        (extIrq),
        .instrReg      (instrReg),
        .shiftReady    (shiftReady),
        .irqTake       (irqTake)
    );

    assign imem.araddr  = {{(32-PC_BITS){1'b0}}, imemAddr};
    assign imem.arvalid = imemReq;
    assign imem.rready  = 1'b1;
    assign imemReady    = imem.rvalid;
    assign imemRData    = imem.rdata;

    assign dmem.araddr  = dmemAddr;
    assign dmem.arvalid = dmemReq & ~dmemWrite;
    assign dmem.rready  = 1'b1;
    assign dmemRData    = dmem.rdata;

    assign dmem.awaddr  = dmemAddr;
    assign dmem.awvalid = dmemReq & dmemWrite;
    assign dmem.wdata   = dmemWData;
    assign dmem.wstrb   = dmemStrb;
    assign dmem.wvalid  = dmemReq & dmemWrite;
    assign dmem.bready  = 1'b1;

    assign dmemReady = dmemWrite ? (dmem.bvalid & dmem.bready) : (dmem.rvalid & dmem.rready);

endmodule
