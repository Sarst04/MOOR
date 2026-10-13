////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_regfile.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-13
// Description: Area-oriented RV32E register file with one-hot read selection.
//              x0 is implemented as an unselected read address.
//              Selectable latch/FF storage.
//
//              Write path follows the Ibex latch-based register file pattern:
//              a sample FF captures writeData once per write, and each
//              per-register storage element captures the sampled value. The
//              sample FF breaks the combinational path from readData through
//              the ALU back into the storage element, which is what allows
//              the latch variant to close without a delta-cycle loop.
//
//              The sample FF is edge-triggered on the falling clock edge so
//              that it captures the current cycle's settled writeData (the
//              multi-cycle core computes writeData combinationally during
//              EXECUTE), and the latch is transparent during the low phase
//              that immediately follows.
//
// Revisions:
//   2026-10-13 - One-hot read decoder and direct write enables
//   2026-10-13 - Sample FF on the write-data path (Ibex-style)
////////////////////////////////////////////////////////////////////////////////
module MOOR_regfile #(
    parameter bit USE_LATCH = 1'b1
) (
    input  logic        clk,
    input  logic [3:0]  readAddr,
    output logic [31:0] readData,
    input  logic        writeEn,
    input  logic [3:0]  writeAddr,
    input  logic [31:0] writeData
);
    logic [31:0] regs [1:15];
    logic [15:1] readSel;
    logic [15:1] writeSel;
    logic [31:0] wdata_q;
    genvar g;

    always_ff @(negedge clk) begin
        if (writeEn) 
            wdata_q <= writeData;
    end

    generate
        for (g = 1; g < 16; g = g + 1) begin : g_reg
            localparam logic [3:0] REG_ADDR = g;

            assign readSel[g]  = (readAddr == REG_ADDR);
            assign writeSel[g] = writeEn && (writeAddr == REG_ADDR);

            if (USE_LATCH) begin : g_latch
                always_latch begin
                    if (!clk && writeSel[g])
                        regs[g] = wdata_q;
                end
            end
            else begin : g_ff
                always_ff @(posedge clk) begin
                    if (writeSel[g])
                        regs[g] <= wdata_q;
                end
            end
        end
    endgenerate

    initial begin
        for (int i = 1; i < 16; i++)
            regs[i] = 32'b0;
    end

    always_comb begin
        readData = 32'b0;
        for (integer i = 1; i < 16; i = i + 1)
            readData = readData | (regs[i] & {32{readSel[i]}});
    end
endmodule
