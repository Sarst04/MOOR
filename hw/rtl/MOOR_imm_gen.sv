////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_imm_gen.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Instruction immediate generator.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
////////////////////////////////////////////////////////////////////////////////
module MOOR_imm_gen
    import MOOR_pkg::*;
(
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    always_comb begin
        imm = {{20{instr[31]}}, instr[31:20]};
        unique0 case (instr[6:0])
            OPC_STORE:          imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            OPC_BRANCH:         imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            OPC_LUI, OPC_AUIPC: imm = {instr[31:12], 12'b0};
            OPC_JAL:            imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
        endcase
    end
endmodule

