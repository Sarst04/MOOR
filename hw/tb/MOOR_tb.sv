////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_tb.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Testbench for MOR RV32E core with AXI4 master interfaces.
//              UART-only variant. Waits for 0xDEADBEEF at mem[0x400].
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - AXI4 interface with modport
//   2026-10-13 - UART-only variant; marker at 0x400
//   2026-10-13 - Clock/counter init moved to initial; marker index uses PC_BITS
//   2026-10-14 - Elapsed time and cycle count printed before $finish
//   2026-10-18 - Optional CPI calculation via ENABLE_CPI_CALCULATE
//   2026-10-18 - Zmmul: MULT state counted as retirement
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module MOOR_tb;
    localparam integer PC_BITS   = 16;
    localparam integer MEM_WORDS = 1 << (PC_BITS - 2);

    localparam [31:0] ENDSIM_ADDR  = 32'h2000_0000;
    localparam [31:0] ENDSIM_VALUE = 32'h0000_0001;
    localparam bit    ENABLE_TIMEOUT = 1'b0;
    localparam integer TIMEOUT_CYCLES = 4_000_000_000;
    localparam bit    ENABLE_CPI_CALCULATE = 1'b1;

    reg clk, rst;

    initial begin
        clk = 0;
        rst = 1;
        forever #5 clk = ~clk;
    end

    logic swIrq = 0, timerIrq = 0, extIrq = 0;

    MOOR_SoC #(
        .RESET_PC       (32'h0000_0000),
        .MTVEC_RESET    (30'd0),
        .PC_BITS        (PC_BITS),
        .USE_LATCH      (1'b0),
        .SERIAL_SHIFTER (1'b0),
        .ZMMUL          (1'b1),
        .HART_ID        (32'd0),
        .INIT_FILE      ("program.hex"),
        .MEM_WORDS      (MEM_WORDS),
        .UART_ADDR      (32'h1000_0000),
        .IMEM_MAX_LAT   (0),
        .DMEM_MAX_LAT   (0)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .swIrq    (swIrq),
        .timerIrq (timerIrq),
        .extIrq   (extIrq)
    );

    integer cycleCount;
    integer instrRetired;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            cycleCount <= 0;
        else
            cycleCount <= cycleCount + 1;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            instrRetired <= 0;
        else if (
            (dut.u_core.u_ctrl.currentState == MOOR_pkg::EXECUTE &&
             dut.u_core.u_ctrl.imemReady &&
             !dut.u_core.u_ctrl.trapPending &&
             !dut.u_core.u_ctrl.isShift) ||
            (dut.u_core.u_ctrl.currentState == MOOR_pkg::MULT &&
             dut.u_core.u_ctrl.mulReady &&
             dut.u_core.u_ctrl.imemReady) ||
            (dut.u_core.u_ctrl.currentState == MOOR_pkg::SHIFT &&
             dut.u_core.u_ctrl.shiftReady &&
             dut.u_core.u_ctrl.imemReady) ||
            (dut.u_core.u_ctrl.currentState == MOOR_pkg::MEMORY &&
             dut.u_core.u_ctrl.imemReady &&
             dut.u_core.u_ctrl.dmemDone)
        )
            instrRetired <= instrRetired + 1;
    end

    integer waitTimeout;
    initial begin
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;

        waitTimeout = 0;
        while (dut.u_mem.mem[ENDSIM_ADDR[PC_BITS-1:2]] !== ENDSIM_VALUE) begin
            @(posedge clk);
            if (ENABLE_TIMEOUT) begin
                waitTimeout = waitTimeout + 1;
                if (waitTimeout > TIMEOUT_CYCLES) begin
                    $display("TIMEOUT");
                    $fatal(1);
                end
            end
        end

        repeat (2) @(posedge clk);
        $display("Simulation finished");
        $display("  Sim time : %0t", $time);
        $display("  Cycles   : %0d", cycleCount);
        $finish;
    end

    final begin
        if (ENABLE_CPI_CALCULATE) begin
            $display("  Instructions retired : %0d", instrRetired);
            if (instrRetired > 0)
                $display("  CPI                  : %f", real'(cycleCount) / real'(instrRetired));
            else
                $display("  CPI                  : N/A");
        end
    end
endmodule
