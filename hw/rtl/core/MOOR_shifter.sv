////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_shifter.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Shifter with integrated shift counter. Two configurations
//              selectable via a bit parameter:
//                SERIAL_SHIFTER = 1 -> serial shifter, 1 bit per cycle
//                SERIAL_SHIFTER = 0 -> three-stage barrel shifter, 1..7 bits/cycle
//
//              Supports SLL, SRL and SRA. Sign extension for SRA always uses
//              the original MSB opA[31], which is invariant under arithmetic
//              right shift. cntR has no reset ? ready is only sampled in SHIFT
//              after shiftLoad.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Reset removed from counter (area)
//   2026-10-13 - Parameterised serial / three-stage configuration
////////////////////////////////////////////////////////////////////////////////
module MOOR_shifter #(
    parameter bit SERIAL_SHIFTER = 1'b0
) (
    input  logic        clk,

    input  logic        shiftLoad,
    input  logic        shiftDec,
    input  logic [4:0]  shiftAmount,

    input  logic [31:0] opA,
    input  logic        rightShift,
    input  logic        arithShift,

    output logic [31:0] shiftNext,
    output logic        ready
);

    logic [4:0]  cntR;
    logic        active;
    logic        en1, en2, en4;
    logic [4:0]  cnt_delta;
    logic        fillBit;
    logic [31:0] stg1, stg2, stg3;

    assign ready   = (cntR == 5'd0);
    assign fillBit = arithShift & opA[31];

    generate
        if (SERIAL_SHIFTER) begin : g_serial
            assign active    = 1'b0;
            assign en1       = cntR[0];
            assign en2       = 1'b0;
            assign en4       = 1'b0;
            assign cnt_delta = 5'd1;
        end
        else begin : g_3stage
            assign active    = |cntR[4:3];
            assign en1       = cntR[0] | active;
            assign en2       = cntR[1] | active;
            assign en4       = cntR[2] | active;
            assign cnt_delta = {2'b00, en4, en2, en1};
        end
    endgenerate

    always_comb begin
        if (rightShift)
            stg1 = en1 ? {fillBit, opA[31:1]} : opA;
        else
            stg1 = en1 ? {opA[30:0], 1'b0} : opA;
    end

    always_comb begin
        if (rightShift)
            stg2 = en2 ? {(arithShift ? {2{fillBit}} : 2'b00), stg1[31:2]} : stg1;
        else
            stg2 = en2 ? {stg1[29:0], 2'b00} : stg1;
    end

    always_comb begin
        if (rightShift)
            stg3 = en4 ? {(arithShift ? {4{fillBit}} : 4'b0000), stg2[31:4]} : stg2;
        else
            stg3 = en4 ? {stg2[27:0], 4'b0000} : stg2;
    end

    assign shiftNext = stg3;

    always_ff @(posedge clk) begin
        if (shiftLoad)
            cntR <= shiftAmount;
        else if (shiftDec)
            cntR <= cntR - cnt_delta;
    end

endmodule
