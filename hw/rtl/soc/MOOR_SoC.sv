////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_SoC.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-13
// Description: MOR RV32E SoC wrapper. Instantiates the core and the AXI4
//              memory model and wires them through internal AXI4 interfaces.
//              A MOOR_dmem_router steers data-memory traffic: accesses to
//              UART_ADDR go to MOOR_uart, everything else goes to MOOR_mem.
//              INIT_FILE, MEM_WORDS and UART_ADDR are exposed as parameters.
//
// Revisions:
//   2026-10-13 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Added bus-functional UART and dmem address router
////////////////////////////////////////////////////////////////////////////////
module MOOR_SoC
    import MOOR_pkg::*;
#(
    parameter [31:0] RESET_PC       = 32'h0000_0000,
    parameter [29:0] MTVEC_RESET    = 30'd0,
    parameter integer PC_BITS       = 32,
    parameter bit    USE_LATCH      = 1'b0,
    parameter bit    SERIAL_SHIFTER = 1'b0,
    parameter [31:0] HART_ID        = 32'd0,
    parameter        INIT_FILE      = "program.hex",
    parameter integer MEM_WORDS     = 1 << (PC_BITS - 2),
    parameter [31:0] UART_ADDR      = 32'h1000_0000,
    parameter integer IMEM_MAX_LAT  = 0,
    parameter integer DMEM_MAX_LAT  = 0
) (
    input  logic clk,
    input  logic rst,
    input  logic swIrq,
    input  logic timerIrq,
    input  logic extIrq
);

    MOOR_axi_if imem_if      ();
    MOOR_axi_if dmem_if      ();
    MOOR_axi_if dmem_mem_if  ();
    MOOR_axi_if dmem_uart_if ();

    MOOR_core #(
        .RESET_PC       (RESET_PC),
        .MTVEC_RESET    (MTVEC_RESET),
        .PC_BITS        (PC_BITS),
        .USE_LATCH      (USE_LATCH),
        .SERIAL_SHIFTER (SERIAL_SHIFTER),
        .HART_ID        (HART_ID)
    ) u_core (
        .clk      (clk),
        .rst      (rst),
        .imem     (imem_if.master),
        .dmem     (dmem_if.master),
        .swIrq    (swIrq),
        .timerIrq (timerIrq),
        .extIrq   (extIrq)
    );

    MOOR_dmem_router #(
        .UART_ADDR (UART_ADDR)
    ) u_dmem_router (
        .clk  (clk),
        .rst  (rst),
        .up   (dmem_if.slave),
        .mem  (dmem_mem_if.master),
        .uart (dmem_uart_if.master)
    );

    MOOR_mem #(
        .INIT_FILE     (INIT_FILE),
        .MEM_WORDS     (MEM_WORDS),
        .IMEM_MAX_LAT  (IMEM_MAX_LAT),
        .DMEM_MAX_LAT  (DMEM_MAX_LAT)
    ) u_mem (
        .clk   (clk),
        .rst   (rst),
        .imem  (imem_if.slave),
        .dmem  (dmem_mem_if.slave)
    );

    MOOR_uart #(
        .UART_ADDR (UART_ADDR)
    ) u_uart (
        .clk  (clk),
        .rst  (rst),
        .dmem (dmem_uart_if.slave)
    );

endmodule
