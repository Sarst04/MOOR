////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_mem.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-12
// Description: Word-addressable AXI4 slave memory model for MOR testbench.
//
//              Configurable random read/write latency via parameters:
//                IMEM_MAX_LAT = 0, DMEM_MAX_LAT = 0 -> original zero-latency
//                IMEM_MAX_LAT = N, DMEM_MAX_LAT = N -> 1..N cycle random stall
//
//              WARNING: the current controller only stalls on imemReady during
//              the initial FETCH. After that, instruction prefetch during
//              EXECUTE asserts instrLoad unconditionally, i.e. the core assumes
//              zero-latency instruction memory. Setting IMEM_MAX_LAT > 0 will
//              corrupt execution unless the controller is also modified to
//              gate instrLoad/pcWrite on imemReady in EXECUTE. The DMEM path
//              is fully stall-based and works with any DMEM_MAX_LAT.
//
// Revisions:
//   2026-10-12 - Initial release (Sayyid Amirreza Sayyid Torabi)
//   2026-10-13 - Converted to AXI4 slave interface
//   2026-10-13 - AXI4 interface with modport
//   2026-10-13 - IDX_W slice; timescale added
//   2026-10-13 - Configurable random read/write latency added
////////////////////////////////////////////////////////////////////////////////
module MOOR_mem #(
    parameter INIT_FILE            = "program.hex",
    parameter MEM_WORDS            = 4096,
    parameter integer IMEM_MAX_LAT = 7,
    parameter integer DMEM_MAX_LAT = 7
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

        if (IMEM_MAX_LAT > 0)
            $display("[MEM] WARNING: IMEM_MAX_LAT=%0d requires controller change, see header",
                     IMEM_MAX_LAT);
        if (DMEM_MAX_LAT > 0)
            $display("[MEM] Random DMEM latency enabled, max=%0d cycles",
                     DMEM_MAX_LAT);
    end

    logic       imem_pend;
    logic [8:0] imem_cnt;
    logic       imem_rvalid_r;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            imem_pend     <= 1'b0;
            imem_cnt      <= 9'd0;
            imem_rvalid_r <= 1'b0;
        end
        else if (imem_rvalid_r) begin
            imem_rvalid_r <= 1'b0;
            imem_pend     <= 1'b0;
        end
        else if (!imem_pend && imem.arvalid) begin
            imem_pend <= 1'b1;
            if (IMEM_MAX_LAT == 0) begin
                imem_rvalid_r <= 1'b1;
                imem_cnt      <= 9'd0;
            end
            else begin
                imem_cnt <= 9'($urandom_range(1, IMEM_MAX_LAT));
            end
        end
        else if (imem_pend && imem_cnt != 0) begin
            if (imem_cnt == 1) begin
                imem_rvalid_r <= 1'b1;
                imem_cnt      <= 9'd0;
            end
            else begin
                imem_cnt <= imem_cnt - 1;
            end
        end
    end

    assign imem.arready = 1'b1;
    assign imem.rvalid  = (IMEM_MAX_LAT == 0) ? imem.arvalid : imem_rvalid_r;
    assign imem.rdata   = mem[imem.araddr[IDX_W+1:2]];
    assign imem.rresp   = 2'b00;
    
    logic       dmem_rd_pend;
    logic [8:0] dmem_rd_cnt;
    logic       dmem_rvalid_r;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dmem_rd_pend  <= 1'b0;
            dmem_rd_cnt   <= 9'd0;
            dmem_rvalid_r <= 1'b0;
        end
        else if (dmem_rvalid_r) begin
            dmem_rvalid_r <= 1'b0;
            dmem_rd_pend  <= 1'b0;
        end
        else if (!dmem_rd_pend && dmem.arvalid) begin
            dmem_rd_pend <= 1'b1;
            if (DMEM_MAX_LAT == 0) begin
                dmem_rvalid_r <= 1'b1;
                dmem_rd_cnt   <= 9'd0;
            end
            else begin
                dmem_rd_cnt <= 9'($urandom_range(1, DMEM_MAX_LAT));
            end
        end
        else if (dmem_rd_pend && dmem_rd_cnt != 0) begin
            if (dmem_rd_cnt == 1) begin
                dmem_rvalid_r <= 1'b1;
                dmem_rd_cnt   <= 9'd0;
            end
            else begin
                dmem_rd_cnt <= dmem_rd_cnt - 1;
            end
        end
    end

    assign dmem.arready = 1'b1;
    assign dmem.rvalid  = (DMEM_MAX_LAT == 0) ? dmem.arvalid : dmem_rvalid_r;
    assign dmem.rdata   = mem[dmem.araddr[IDX_W+1:2]];
    assign dmem.rresp   = 2'b00;


    logic       dmem_wr_pend;
    logic [8:0] dmem_wr_cnt;
    logic       dmem_bvalid_r;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dmem_wr_pend  <= 1'b0;
            dmem_wr_cnt   <= 9'd0;
            dmem_bvalid_r <= 1'b0;
        end
        else if (dmem_bvalid_r) begin
            dmem_bvalid_r <= 1'b0;
            dmem_wr_pend  <= 1'b0;
        end
        else if (!dmem_wr_pend && dmem.awvalid && dmem.wvalid) begin
            dmem_wr_pend <= 1'b1;
            if (DMEM_MAX_LAT == 0) begin
                dmem_bvalid_r <= 1'b1;
                dmem_wr_cnt   <= 9'd0;
            end
            else begin
                dmem_wr_cnt <= 9'($urandom_range(1, DMEM_MAX_LAT));
            end
        end
        else if (dmem_wr_pend && dmem_wr_cnt != 0) begin
            if (dmem_wr_cnt == 1) begin
                dmem_bvalid_r <= 1'b1;
                dmem_wr_cnt   <= 9'd0;
            end
            else begin
                dmem_wr_cnt <= dmem_wr_cnt - 1;
            end
        end
    end

    assign dmem.awready = 1'b1;
    assign dmem.wready  = 1'b1;
    assign dmem.bvalid  = (DMEM_MAX_LAT == 0)
                        ? (dmem.awvalid & dmem.wvalid)
                        : dmem_bvalid_r;
    assign dmem.bresp   = 2'b00;

    always_ff @(posedge clk) begin
        if (dmem.awvalid && dmem.wvalid) begin
            if (dmem.wstrb[0]) mem[dmem.awaddr[IDX_W+1:2]][7:0]   <= dmem.wdata[7:0];
            if (dmem.wstrb[1]) mem[dmem.awaddr[IDX_W+1:2]][15:8]  <= dmem.wdata[15:8];
            if (dmem.wstrb[2]) mem[dmem.awaddr[IDX_W+1:2]][23:16] <= dmem.wdata[23:16];
            if (dmem.wstrb[3]) mem[dmem.awaddr[IDX_W+1:2]][31:24] <= dmem.wdata[31:24];
        end
    end
endmodule
