////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_dmem_router.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-13
// Description: Address router for the core's data-memory port. Presents one
//              AXI4 slave port to the CPU and two AXI4 master ports (mem,
//              uart). Traffic to UART_ADDR is steered to the UART; all other
//              traffic goes to memory. Both downstream slaves are assumed
//              zero-latency, matching the rest of the design.
//
//              The read and write channels are routed independently: the
//              read select is derived from ARADDR, the write select from
//              AWADDR, each gated by the corresponding VALID. Because the
//              core never issues a simultaneous read and write, this is
//              sufficient.
//
// Revisions:
//   2026-10-13 - Initial release (Sayyid Amirreza Sayyid Torabi)
////////////////////////////////////////////////////////////////////////////////
module MOOR_dmem_router #(
    parameter [31:0] UART_ADDR = 32'h1000_0000
) (
    input  logic clk,
    input  logic rst,

    MOOR_axi_if.slave  up,
    MOOR_axi_if.master mem,
    MOOR_axi_if.master uart
);
    logic read_uart_sel;
    logic write_uart_sel;

    assign read_uart_sel  = up.arvalid & (up.araddr == UART_ADDR);
    assign write_uart_sel = up.awvalid & (up.awaddr == UART_ADDR);

    assign mem.araddr  = up.araddr;
    assign mem.arvalid = up.arvalid & ~read_uart_sel;
    assign mem.rready  = up.rready;

    assign uart.araddr  = up.araddr;
    assign uart.arvalid = up.arvalid & read_uart_sel;
    assign uart.rready  = up.rready;

    assign up.arready = read_uart_sel ? uart.arready : mem.arready;
    assign up.rvalid  = read_uart_sel ? uart.rvalid  : mem.rvalid;
    assign up.rdata   = read_uart_sel ? uart.rdata   : mem.rdata;
    assign up.rresp   = read_uart_sel ? uart.rresp   : mem.rresp;


    assign mem.awaddr  = up.awaddr;
    assign mem.awvalid = up.awvalid & ~write_uart_sel;
    assign mem.wdata   = up.wdata;
    assign mem.wstrb   = up.wstrb;
    assign mem.wvalid  = up.wvalid & ~write_uart_sel;
    assign mem.bready  = up.bready;

    assign uart.awaddr  = up.awaddr;
    assign uart.awvalid = up.awvalid & write_uart_sel;
    assign uart.wdata   = up.wdata;
    assign uart.wstrb   = up.wstrb;
    assign uart.wvalid  = up.wvalid & write_uart_sel;
    assign uart.bready  = up.bready;

    assign up.awready = write_uart_sel ? uart.awready : mem.awready;
    assign up.wready  = write_uart_sel ? uart.wready  : mem.wready;
    assign up.bvalid  = write_uart_sel ? uart.bvalid  : mem.bvalid;
    assign up.bresp   = write_uart_sel ? uart.bresp   : mem.bresp;
endmodule
