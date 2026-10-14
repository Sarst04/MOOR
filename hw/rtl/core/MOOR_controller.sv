////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_controller.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: FSM and control signal generator. Reduced ECALL/MRET decode;
//              pcSel/pcBranchEn computed by dedicated logic after the case
//              block so the branch redirect is a single mux from imemAddr.
//              Load/store targets are no longer precomputed; the shared ALU
//              computes the effective address during MEMORY.
//              WFI: completes as a NOP when an enabled interrupt is already
//              pending, otherwise advances PC once and stalls in HALT until
//              irqTake, at which point the trap is taken with mepc pointing
//              to the instruction after WFI.
//
//              imem latency: every state that issues an instruction prefetch
//              gates instrLoad/pcWrite on imemReady and holds its own state
//              until imemReady. Non-idempotent side effects fire only on the
//              completing cycle. ALU controls for isBranch/isOpAny are set
//              unconditionally so branchTaken is stable across stall cycles.
//
//              dmem request is a single-cycle pulse. dmemDone latches the
//              completion and holds it until the FSM leaves MEMORY, so the
//              FSM can wait for imemReady after the dmem transaction has
//              finished without re-issuing the dmem transaction.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Area optimization: cheaper priv decode, dedicated pcSel
//   2026-10-13 - WB_SHIFT restored, SHIFT no longer uses adder with x0
//   2026-10-13 - Load/store target precomputation removed
//   2026-10-13 - WFI / HALT state added
//   2026-10-14 - imem latency handled in EXECUTE/SHIFT/MEMORY/HALT
//   2026-10-14 - dmem request pulsed; dmemDone sticky
////////////////////////////////////////////////////////////////////////////////
module MOOR_controller
    import MOOR_pkg::*;
(
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] instrReg,
    input  logic        imemReady,
    input  logic        dmemReady,
    input  logic        shiftReady,
    input  logic        irqTake,

    output logic        imemReq,
    output logic        dmemReq,
    output logic        dmemWrite,

    output logic        instrLoad,
    output logic        opALoad,
    output logic        opAShift,
    output logic        shiftLoad,
    output logic        shiftDec,
    output logic        shiftUseRs2,
    output logic        captureTarget,
    output logic        pcWrite,
    output pc_sel_t     pcSel,
    output logic        pcBranchEn,
    output logic        rfWrite,
    output logic [3:0]  rfReadAddr,
    output logic [3:0]  rfWriteAddr,
    output wb_sel_t     wbSel,
    output logic        csrWriteEn,
    output logic        trapEnter,
    output logic        mretEnter,
    output logic        addA_pc,
    output logic        addA_zero,
    output logic        addA_rs1,
    output logic        addB_rs2,
    output logic        addSub,
    output logic        isOpAny
);
    localparam logic [1:0]  CSR_OP_WRITE = 2'b01;
    localparam logic [11:0] WFI_IMM      = 12'h105;

    state_t currentState, nextState;
    logic   trapPending;
    logic   imemStall;
    logic   dmemSent;
    logic   dmemDone;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instrReg[6:0];
    assign funct3 = instrReg[14:12];
    assign funct7 = instrReg[31:25];

    logic isLui, isAuipc, isJal, isJalr, isBranch, isLoad, isStore;
    logic isOpImm, isOp, isShift, isCsr, isEcall, isMret, isSysPriv, isWfi;
    logic isTargetPrecompute;

    assign isLui    = (opcode == OPC_LUI);
    assign isAuipc  = (opcode == OPC_AUIPC);
    assign isJal    = (opcode == OPC_JAL);
    assign isJalr   = (opcode == OPC_JALR);
    assign isBranch = (opcode == OPC_BRANCH);
    assign isLoad   = (opcode == OPC_LOAD);
    assign isStore  = (opcode == OPC_STORE);
    assign isOpImm  = (opcode == OPC_OPIMM);
    assign isOp     = (opcode == OPC_OP);
    assign isOpAny  = isOpImm | isOp;
    assign isShift  = isOpAny & ((funct3 == F3_SLL) | (funct3 == F3_SRL));
    assign isCsr    = (opcode == OPC_SYSTEM) & (funct3 != F3_PRIV) & (funct3 != F3_XOR);

    assign isSysPriv = (opcode == OPC_SYSTEM) & (funct3 == F3_PRIV);
    assign isEcall   = isSysPriv & ~instrReg[20] & ~instrReg[21];
    assign isMret    = isSysPriv & ~instrReg[20] &  instrReg[21] & instrReg[29];
    assign isWfi     = isSysPriv & (instrReg[31:20] == WFI_IMM);

    assign isTargetPrecompute = isJal | isBranch | isJalr;

    assign imemStall = imemReq & ~imemReady;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            currentState <= FETCH;
        else
            currentState <= nextState;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            trapPending <= 1'b0;
        else if (currentState == DECODE)
            trapPending <= irqTake | isEcall;
        else if (currentState == EXECUTE && trapPending && !imemReady)
            trapPending <= 1'b1;
        else
            trapPending <= 1'b0;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dmemSent <= 1'b0;
            dmemDone <= 1'b0;
        end
        else if (currentState != MEMORY) begin
            dmemSent <= 1'b0;
            dmemDone <= 1'b0;
        end
        else begin
            dmemSent <= 1'b1;
            if (dmemReady || dmemDone)
                dmemDone <= 1'b1;
        end
    end

    always_comb begin
        imemReq       = 1'b0;
        dmemReq       = 1'b0;
        dmemWrite     = 1'b0;
        instrLoad     = 1'b0;
        opALoad       = 1'b0;
        opAShift      = 1'b0;
        shiftLoad     = 1'b0;
        shiftDec      = 1'b0;
        shiftUseRs2   = 1'b0;
        captureTarget = 1'b0;
        pcWrite       = 1'b0;
        rfWrite       = 1'b0;
        wbSel         = WB_ALU;
        csrWriteEn    = 1'b0;
        trapEnter     = 1'b0;
        mretEnter     = 1'b0;
        addA_pc       = 1'b0;
        addA_zero     = 1'b0;
        addA_rs1      = 1'b0;
        addB_rs2      = 1'b0;
        addSub        = 1'b0;

        rfReadAddr  = instrReg[23:20];
        rfWriteAddr = instrReg[10:7];

        unique0 case (currentState)
            FETCH: begin
                imemReq = 1'b1;
                if (imemReady) begin
                    instrLoad = 1'b1;
                    pcWrite   = 1'b1;
                end
            end

            DECODE: begin
                rfReadAddr = instrReg[18:15];
                opALoad    = 1'b1;
                if (isTargetPrecompute) begin
                    captureTarget = 1'b1;
                    addA_pc       = isJal | isBranch;
                    addA_rs1      = isJalr;
                end
            end

            EXECUTE: begin
                if (trapPending) begin
                    imemReq = 1'b1;
                    if (imemReady) begin
                        trapEnter = 1'b1;
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
                else if (isMret) begin
                    imemReq = 1'b1;
                    if (imemReady) begin
                        mretEnter = 1'b1;
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
                else if (isCsr) begin
                    imemReq = 1'b1;
                    if (imemReady) begin
                        csrWriteEn = (instrReg[13:12] == CSR_OP_WRITE) |
                                     (instrReg[19:15] != 5'd0);
                        rfWrite   = 1'b1;
                        wbSel     = WB_CSR;
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
                else if (isWfi) begin
                    imemReq = 1'b1;
                    if (imemReady) begin
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
                else if (isShift) begin
                    shiftLoad   = 1'b1;
                    shiftUseRs2 = isOp;
                end
                else if (isOpAny || isLui || isAuipc) begin
                    addA_zero = isLui;
                    addA_pc   = isAuipc;
                    addB_rs2  = isOp;
                    if (isOp)
                        addSub = ((funct3 == F3_ADD) & funct7[5]) |
                                 (funct3 == F3_SLT)  | (funct3 == F3_SLTU);
                    else if (isOpImm)
                        addSub = (funct3 == F3_SLT) | (funct3 == F3_SLTU);
                    imemReq = 1'b1;
                    if (imemReady) begin
                        rfWrite   = 1'b1;
                        wbSel     = WB_ALU;
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
                else if (isJal || isJalr) begin
                    imemReq = 1'b1;
                    if (imemReady) begin
                        rfWrite   = 1'b1;
                        wbSel     = WB_PC4;
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
                else if (isBranch) begin
                    addB_rs2 = 1'b1;
                    addSub   = 1'b1;
                    imemReq  = 1'b1;
                    if (imemReady) begin
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
                else begin
                    imemReq = 1'b1;
                    if (imemReady) begin
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
            end

            SHIFT: begin
                if (!shiftReady) begin
                    opAShift = 1'b1;
                    shiftDec = 1'b1;
                end
                else begin
                    rfWrite = 1'b1;
                    wbSel   = WB_SHIFT;
                    imemReq = 1'b1;
                    if (imemReady) begin
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
            end

            MEMORY: begin
                dmemReq   = isStore ? ~dmemSent : 1'b1;
                dmemWrite = isStore;
                imemReq   = 1'b1;

                if (imemReady && dmemDone) begin
                    if (isLoad) begin
                        rfWrite = 1'b1;
                        wbSel   = WB_LOAD;
                    end
                    instrLoad = 1'b1;
                    pcWrite   = 1'b1;
                end
            end

            HALT: begin
                if (irqTake) begin
                    imemReq = 1'b1;
                    if (imemReady) begin
                        trapEnter = 1'b1;
                        instrLoad = 1'b1;
                        pcWrite   = 1'b1;
                    end
                end
            end
        endcase
    end

    logic isEx, isHalt, selHi, selLo;
    assign isEx       = (currentState == EXECUTE);
    assign isHalt     = (currentState == HALT);
    assign selHi      = trapPending | (isEx & isMret) | (isHalt & irqTake);
    assign selLo      = ~trapPending & isEx & (isMret | isJal | isJalr);
    assign pcSel      = pc_sel_t'({selHi, selLo});
    assign pcBranchEn = isEx & isBranch & ~trapPending;

    always_comb begin
        nextState = currentState;
        unique0 case (currentState)
            FETCH:   nextState = imemReady ? DECODE : FETCH;
            DECODE:  nextState = (isLoad || isStore) ? MEMORY : EXECUTE;
            EXECUTE: nextState = imemStall ? EXECUTE
                               : (isWfi && !irqTake) ? HALT
                               : (isShift && !trapPending) ? SHIFT
                               : DECODE;
            SHIFT:   nextState = (shiftReady && imemReady) ? DECODE : SHIFT;
            MEMORY:  nextState = (imemReady && dmemDone) ? DECODE : MEMORY;
            HALT:    nextState = (irqTake && imemReady) ? DECODE : HALT;
            default: nextState = FETCH;
        endcase
    end
endmodule
