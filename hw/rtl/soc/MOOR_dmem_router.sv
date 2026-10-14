////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_dmem_router.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-13
// Description: Address router for the core's data-memory port. Presents one
//              AXI4 slave port to the CPU and three AXI4 master ports (mem,
//              uart, timer). Addresses are matched on 4 KB pages so each
//              peripheral owns a full page.
//
// Revisions:
//   2026-10-13 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-14 - Three-way routing, 4 KB page matching, timer port added
////////////////////////////////////////////////////////////////////////////////
module MOOR_dmem_router #(
    parameter [31:0] UART_ADDR  = 32'h1000_0000,
    parameter [31:0] TIMER_ADDR = 32'h1000_1000
) (
    input  logic clk,
    input  logic rst,

    MOOR_axi_if.slave  up,
    MOOR_axi_if.master mem,
    MOOR_axi_if.master uart,
    MOOR_axi_if.master timer
);
    localparam integer PAGE_LSB = 12;
    localparam integer PAGE_MSB = 31;

    logic read_uart_sel;
    logic read_timer_sel;
    logic write_uart_sel;
    logic write_timer_sel;

    assign read_uart_sel   = up.arvalid & (up.araddr[PAGE_MSB:PAGE_LSB] == UART_ADDR[PAGE_MSB:PAGE_LSB]);
    assign read_timer_sel  = up.arvalid & (up.araddr[PAGE_MSB:PAGE_LSB] == TIMER_ADDR[PAGE_MSB:PAGE_LSB]);

    assign write_uart_sel  = up.awvalid & (up.awaddr[PAGE_MSB:PAGE_LSB] == UART_ADDR[PAGE_MSB:PAGE_LSB]);
    assign write_timer_sel = up.awvalid & (up.awaddr[PAGE_MSB:PAGE_LSB] == TIMER_ADDR[PAGE_MSB:PAGE_LSB]);

    assign mem.araddr   = up.araddr;
    assign mem.arvalid  = up.arvalid & ~read_uart_sel & ~read_timer_sel;
    assign mem.rready   = up.rready;

    assign uart.araddr  = up.araddr;
    assign uart.arvalid = up.arvalid & read_uart_sel;
    assign uart.rready  = up.rready;

    assign timer.araddr  = up.araddr;
    assign timer.arvalid = up.arvalid & read_timer_sel;
    assign timer.rready  = up.rready;

    assign up.arready = read_uart_sel  ? uart.arready
                      : read_timer_sel ? timer.arready
                      :                  mem.arready;

    assign up.rvalid  = read_uart_sel  ? uart.rvalid
                      : read_timer_sel ? timer.rvalid
                      :                  mem.rvalid;

    assign up.rdata   = read_uart_sel  ? uart.rdata
                      : read_timer_sel ? timer.rdata
                      :                  mem.rdata;

    assign up.rresp   = read_uart_sel  ? uart.rresp
                      : read_timer_sel ? timer.rresp
                      :                  mem.rresp;

    assign mem.awaddr  = up.awaddr;
    assign mem.awvalid = up.awvalid & ~write_uart_sel & ~write_timer_sel;
    assign mem.wdata   = up.wdata;
    assign mem.wstrb   = up.wstrb;
    assign mem.wvalid  = up.wvalid & ~write_uart_sel & ~write_timer_sel;
    assign mem.bready  = up.bready;

    assign uart.awaddr  = up.awaddr;
    assign uart.awvalid = up.awvalid & write_uart_sel;
    assign uart.wdata   = up.wdata;
    assign uart.wstrb   = up.wstrb;
    assign uart.wvalid  = up.wvalid & write_uart_sel;
    assign uart.bready  = up.bready;

    assign timer.awaddr  = up.awaddr;
    assign timer.awvalid = up.awvalid & write_timer_sel;
    assign timer.wdata   = up.wdata;
    assign timer.wstrb   = up.wstrb;
    assign timer.wvalid  = up.wvalid & write_timer_sel;
    assign timer.bready  = up.bready;

    assign up.awready = write_uart_sel  ? uart.awready
                      : write_timer_sel ? timer.awready
                      :                   mem.awready;

    assign up.wready  = write_uart_sel  ? uart.wready
                      : write_timer_sel ? timer.wready
                      :                   mem.wready;

    assign up.bvalid  = write_uart_sel  ? uart.bvalid
                      : write_timer_sel ? timer.bvalid
                      :                   mem.bvalid;

    assign up.bresp   = write_uart_sel  ? uart.bresp
                      : write_timer_sel ? timer.bresp
                      :                   mem.bresp;

endmodule
