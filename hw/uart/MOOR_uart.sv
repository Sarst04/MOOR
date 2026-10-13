////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_uart.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-13
// Description: Bus-functional UART AXI4 slave. Writes to UART_ADDR print the
//              low byte of WDATA as ASCII. Reads return 0. Zero-latency.
//
//              $fflush() removed: calling it inside a clocked process was
//              triggering ModelSim's Autofindloop at the end of simulation.
//              Output is flushed by $finish or with "vsim -onfinish flush".
//
// Revisions:
//   2026-10-13 - Initial release
//   2026-10-13 - $fflush removed from always_ff
////////////////////////////////////////////////////////////////////////////////
module MOOR_uart #(
    parameter [31:0] UART_ADDR = 32'h1000_0000
) (
    input  logic clk,
    input  logic rst,

    MOOR_axi_if.slave dmem
);
    logic hit;
    assign hit = (dmem.awaddr == UART_ADDR);

    assign dmem.arready = 1'b1;
    assign dmem.rvalid  = dmem.arvalid;
    assign dmem.rdata   = 32'b0;
    assign dmem.rresp   = 2'b00;

    assign dmem.awready = 1'b1;
    assign dmem.wready  = 1'b1;
    assign dmem.bvalid  = dmem.awvalid & dmem.wvalid;
    assign dmem.bresp   = 2'b00;

    always_ff @(posedge clk) begin
        if (dmem.awvalid && dmem.wvalid && hit)
            $write("%c", dmem.wdata[7:0]);
    end
endmodule
