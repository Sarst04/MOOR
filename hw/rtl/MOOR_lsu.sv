////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_lsu.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Load/store alignment unit. Assumes naturally aligned accesses
//              (LW addr[1:0]==0, LH/LHU addr[0]==0). Single sign bit derived
//              from the raw memory byte instead of a separate aligned byte bus.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Load path collapsed (area)
////////////////////////////////////////////////////////////////////////////////
module MOOR_lsu (
    input  logic [31:0] addr,
    input  logic [31:0] rs2,
    input  logic [31:0] dmemRData,
    input  logic [2:0]  funct3,

    output logic [31:0] dmemWData,
    output logic [3:0]  dmemStrb,
    output logic [31:0] loadData
);
    logic [7:0] loadByte;
    logic [7:0] loadHalfHi;
    logic       loadSign;
    logic       signRaw;

    always_comb begin
        dmemWData = rs2;
        unique0 case (funct3[1:0])
            2'b00: dmemWData = {4{rs2[7:0]}};
            2'b01: dmemWData = {2{rs2[15:0]}};
        endcase
    end

    always_comb begin
        dmemStrb = 4'b1111;
        unique0 case (funct3[1:0])
            2'b00: dmemStrb = 4'b0001 << addr[1:0];
            2'b01: dmemStrb = 4'b0011 << {addr[1], 1'b0};
        endcase
    end

    always_comb begin
        loadByte = dmemRData[31:24];
        unique0 case (addr[1:0])
            2'd0: loadByte = dmemRData[7:0];
            2'd1: loadByte = dmemRData[15:8];
            2'd2: loadByte = dmemRData[23:16];
        endcase

        loadHalfHi = addr[1] ? dmemRData[31:24] : dmemRData[15:8];

        if (funct3[0])
            signRaw = addr[1] ? dmemRData[31] : dmemRData[15];
        else
            unique0 case (addr[1:0])
                2'd0: signRaw = dmemRData[7];
                2'd1: signRaw = dmemRData[15];
                2'd2: signRaw = dmemRData[23];
                2'd3: signRaw = dmemRData[31];
            endcase

        loadSign = ~funct3[2] & signRaw;

        loadData[7:0]   = loadByte;
        loadData[15:8]  = (funct3[1:0] == 2'b00) ? {8{loadSign}} : loadHalfHi;
        loadData[31:16] = funct3[1] ? dmemRData[31:16] : {16{loadSign}};
    end
endmodule

