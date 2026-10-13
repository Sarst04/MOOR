`timescale 1ns/1ps
////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_mem.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Word-addressable AXI4 slave memory model for MOR testbench.
//              Responds combinationally (zero-latency) so the core's CPI is
//              preserved. Read data returns in the same cycle as ARVALID.
//
//              Array index width is $clog2(MEM_WORDS) so the slice does not
//              generate WIDTHTRUNC warnings.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Converted to AXI4 slave interface
//   2026-10-13 - AXI4 interface with modport
//   2026-10-13 - IDX_W slice; timescale added
////////////////////////////////////////////////////////////////////////////////
module MOOR_mem #(
    parameter INIT_FILE = "program.hex",
    parameter MEM_WORDS = 4096
) (
    input  logic clk,
    input  logic rst,

    MOOR_axi_if.slave imem,
    MOOR_axi_if.slave dmem
);
    localparam integer IDX_W = $clog2(MEM_WORDS);

    logic [31:0] mem [0:MEM_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'h0000_0000;

        if (INIT_FILE != "") begin
            $display("[MEM] Loading %s", INIT_FILE);
            $readmemh(INIT_FILE, mem);
        end
    end

    assign imem.arready = 1'b1;
    assign imem.rvalid  = imem.arvalid;
    assign imem.rdata   = mem[imem.araddr[IDX_W+1:2]];
    assign imem.rresp   = 2'b00;

    assign dmem.arready = 1'b1;
    assign dmem.rvalid  = dmem.arvalid;
    assign dmem.rdata   = mem[dmem.araddr[IDX_W+1:2]];
    assign dmem.rresp   = 2'b00;

    assign dmem.awready = 1'b1;
    assign dmem.wready  = 1'b1;
    assign dmem.bvalid  = dmem.awvalid & dmem.wvalid;
    assign dmem.bresp   = 2'b00;

    always @(posedge clk) begin
        if (dmem.awvalid && dmem.wvalid) begin
            if (dmem.wstrb[0]) mem[dmem.awaddr[IDX_W+1:2]][7:0]   <= dmem.wdata[7:0];
            if (dmem.wstrb[1]) mem[dmem.awaddr[IDX_W+1:2]][15:8]  <= dmem.wdata[15:8];
            if (dmem.wstrb[2]) mem[dmem.awaddr[IDX_W+1:2]][23:16] <= dmem.wdata[23:16];
            if (dmem.wstrb[3]) mem[dmem.awaddr[IDX_W+1:2]][31:24] <= dmem.wdata[31:24];
        end
    end
endmodule
