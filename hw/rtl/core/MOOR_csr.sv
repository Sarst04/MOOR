////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_csr.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Minimal machine-mode CSR unit. Partial decode on
//              {csrAddr[11], csrAddr[6], csrAddr[2:0]} - unimplemented CSRs
//              alias to the nearest implemented one. mhartid (0xF14) reads
//              a parameter-driven constant.
//

//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Partial decode, csrValid removed, mtvec/mepc width fixed
//   2026-10-13 - mhartid CSR added with HART_ID parameter
//   2026-10-13 - Explicit zero-extension of mtvec/mepc; timescale added
////////////////////////////////////////////////////////////////////////////////
module MOOR_csr #(
    parameter [29:0]  MTVEC_RESET = 30'd0,
    parameter integer PC_BITS     = 12,
    parameter [31:0]  HART_ID     = 32'd0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic [11:0] csrAddr,
    input  logic [1:0]  csrOp,
    input  logic [31:0] csrSrc,
    input  logic        csrWriteEn,
    output logic [31:0] csrReadData,
    input  logic        trapEnter,
    input  logic [31:2] trapPc,
    input  logic        mretEnter,
    input  logic        swIrq,
    input  logic        timerIrq,
    input  logic        extIrq,
    output logic [31:2] mtvecBase,
    output logic [31:2] mepcOut,
    output logic        irqTake
);
    localparam logic [4:0] CSR_KEY_MSTATUS = 5'b0_0_000;
    localparam logic [4:0] CSR_KEY_MIE     = 5'b0_0_100;
    localparam logic [4:0] CSR_KEY_MTVEC   = 5'b0_0_101;
    localparam logic [4:0] CSR_KEY_MEPC    = 5'b0_1_001;
    localparam logic [4:0] CSR_KEY_MIP     = 5'b0_1_100;
    localparam logic [4:0] CSR_KEY_MHARTID = 5'b1_0_100;

    localparam logic [1:0] CSR_OP_WRITE = 2'b01;
    localparam logic [1:0] CSR_OP_SET   = 2'b10;
    localparam logic [1:0] CSR_OP_CLEAR = 2'b11;

    localparam integer MSTATUS_MIE_BIT  = 3;
    localparam integer MSTATUS_MPIE_BIT = 7;
    localparam logic [1:0] MSTATUS_MPP  = 2'b11;

    localparam integer MIE_MSIE_BIT = 3;
    localparam integer MIE_MTIE_BIT = 7;
    localparam integer MIE_MEIE_BIT = 11;

    localparam integer CSR_W    = PC_BITS - 2;
    localparam integer PAD30    = 30 - CSR_W;
    localparam integer PAD32    = 32 - PC_BITS;

    logic mstatusMie, mstatusMpie;
    logic mieMsie, mieMtie, mieMeie;
    logic [CSR_W-1:0] mtvecReg;
    logic [CSR_W-1:0] mepcReg;

    logic [4:0]  csrKey;
    logic [31:0] csrNew;

    assign csrKey    = {csrAddr[11], csrAddr[6], csrAddr[2:0]};
    assign mtvecBase = {{PAD30{1'b0}}, mtvecReg};
    assign mepcOut   = {{PAD30{1'b0}}, mepcReg};
    assign irqTake   = mstatusMie & ((swIrq & mieMsie) | (timerIrq & mieMtie) | (extIrq & mieMeie));

    always_comb begin
        csrReadData = 32'b0;
        unique0 case (csrKey)
            CSR_KEY_MSTATUS: csrReadData = {19'b0, MSTATUS_MPP, 3'b0, mstatusMpie, 3'b0, mstatusMie, 3'b0};
            CSR_KEY_MIE:     csrReadData = {20'b0, mieMeie, 3'b0, mieMtie, 3'b0, mieMsie, 3'b0};
            CSR_KEY_MTVEC:   csrReadData = {{PAD32{1'b0}}, mtvecReg, 2'b00};
            CSR_KEY_MEPC:    csrReadData = {{PAD32{1'b0}}, mepcReg,  2'b00};
            CSR_KEY_MIP:     csrReadData = {20'b0, extIrq, 3'b0, timerIrq, 3'b0, swIrq, 3'b0};
            CSR_KEY_MHARTID: csrReadData = HART_ID;
        endcase
    end

    always_comb begin
        csrNew = csrReadData;
        unique0 case (csrOp)
            CSR_OP_WRITE: csrNew = csrSrc;
            CSR_OP_SET:   csrNew = csrReadData | csrSrc;
            CSR_OP_CLEAR: csrNew = csrReadData & ~csrSrc;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mstatusMie  <= 1'b0;
            mstatusMpie <= 1'b0;
        end
        else if (trapEnter) begin
            mstatusMpie <= mstatusMie;
            mstatusMie  <= 1'b0;
        end
        else if (mretEnter) begin
            mstatusMie  <= mstatusMpie;
            mstatusMpie <= 1'b1;
        end
        else if (csrWriteEn && (csrKey == CSR_KEY_MSTATUS)) begin
            mstatusMie  <= csrNew[MSTATUS_MIE_BIT];
            mstatusMpie <= csrNew[MSTATUS_MPIE_BIT];
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mieMsie <= 1'b0;
            mieMtie <= 1'b0;
            mieMeie <= 1'b0;
        end
        else if (csrWriteEn && (csrKey == CSR_KEY_MIE)) begin
            mieMsie <= csrNew[MIE_MSIE_BIT];
            mieMtie <= csrNew[MIE_MTIE_BIT];
            mieMeie <= csrNew[MIE_MEIE_BIT];
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            mtvecReg <= MTVEC_RESET[CSR_W-1:0];
        else if (csrWriteEn && (csrKey == CSR_KEY_MTVEC))
            mtvecReg <= csrNew[PC_BITS-1:2];
    end

    always_ff @(posedge clk) begin
        if (trapEnter)
            mepcReg <= trapPc[PC_BITS-1:2];
        else if (csrWriteEn && (csrKey == CSR_KEY_MEPC))
            mepcReg <= csrNew[PC_BITS-1:2];
    end
endmodule
