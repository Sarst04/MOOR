////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_mul.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-18
// Description: Zmmul sequencer. Serial radix-2 shift-add multiplier that has
//              no adder of its own: every addition and subtraction is done by
//              the shared adder in MOOR_alu.
//
//              Register use:
//                opA  = accumulator (high product word), updated through
//                       accNext
//                loR  = multiplier bits shifting out / low product word
//                rf   = multiplicand (rs1) is read from the register file
//                       with addB_rs2 during every step
//
//              Sequence (cntR counts down from 34):
//                34..3 : 32 shift-add steps. If loR[0] is set the shared
//                        adder computes opA + rs1 and {cout, sum} is shifted
//                        right into {opA, loR}; otherwise opA is just shifted.
//                2     : correction A, opA - rs2 when rs1 is negative and
//                        signed (MULH, MULHSU)
//                1     : correction B, opA - rs1 when rs2 is negative and
//                        signed (MULH)
//                0     : ready. MUL reads loR, MULH* read opA.
//
//              Operand signs are captured at mulLoad. cntR has no reset -
//              ready is only sampled in MULT after mulLoad. ZMMUL = 0 removes
//              all state and ties ready high.
//
// Revisions:
//   2026-10-18 - Initial release (Sayyid Amirreza Sayyid Torabi)
////////////////////////////////////////////////////////////////////////////////
module MOOR_mul #(
    parameter bit ZMMUL = 1'b1
) (
    input  logic        clk,

    input  logic        mulLoad,
    input  logic        mulStep,

    input  logic [31:0] opA,
    input  logic [31:0] rfReadData,
    input  logic [31:0] sum,
    input  logic        adderCout,
    input  logic        signA,
    input  logic        signB,

    output logic [31:0] accNext,
    output logic [31:0] mulLo,
    output logic        ready,
    output logic        corrA,
    output logic        corrB
);

    generate
        if (ZMMUL) begin : g_mul
            logic [5:0]  cntR;
            logic [31:0] loR;
            logic        aNegR;
            logic        bNegR;
            logic        bitSet;
            logic        corrCond;

            assign ready    = (cntR == 6'd0);
            assign corrA    = (cntR == 6'd2);
            assign corrB    = (cntR == 6'd1);
            assign bitSet   = loR[0];
            assign corrCond = corrA ? aNegR : bNegR;
            assign mulLo    = loR;

            always_comb begin
                if (mulLoad)
                    accNext = 32'b0;
                else if (corrA | corrB)
                    accNext = corrCond ? sum : opA;
                else if (bitSet)
                    accNext = {adderCout, sum[31:1]};
                else
                    accNext = {1'b0, opA[31:1]};
            end

            always_ff @(posedge clk) begin
                if (mulLoad) begin
                    cntR  <= 6'd34;
                    loR   <= rfReadData;
                    aNegR <= signA & opA[31];
                    bNegR <= signB & rfReadData[31];
                end
                else if (mulStep) begin
                    cntR <= cntR - 6'd1;
                    if (!(corrA | corrB))
                        loR <= {(bitSet ? sum[0] : opA[0]), loR[31:1]};
                end
            end
        end
        else begin : g_nomul
            assign accNext = 32'b0;
            assign mulLo   = 32'b0;
            assign ready   = 1'b1;
            assign corrA   = 1'b0;
            assign corrB   = 1'b0;
        end
    endgenerate

endmodule
