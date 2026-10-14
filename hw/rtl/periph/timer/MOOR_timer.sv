////////////////////////////////////////////////////////////////////////////////
// File       : MOOR_timer.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-14
// Description: Cycle-counting machine timer. 64-bit MTIME counts clk cycles
//              while enabled. IRQ asserts when MTIME >= MTIMECMP and enable
//              is set. No clear-on-write: lower MTIMECMP or disable to clear.
//
// Revisions:
//   2026-10-14 - Initial release (Sayyid Amirreza Sayyid Torabi)
////////////////////////////////////////////////////////////////////////////////
module MOOR_timer #(
    parameter [31:0] TIMER_ADDR = 32'h1000_1000
) (
    input  logic clk,
    input  logic rst,

    MOOR_axi_if.slave dmem,

    output logic timerIrq
);
    localparam logic [31:0] REG_MTIME_LO    = 32'h00;
    localparam logic [31:0] REG_MTIME_HI    = 32'h04;
    localparam logic [31:0] REG_MTIMECMP_LO = 32'h08;
    localparam logic [31:0] REG_MTIMECMP_HI = 32'h0C;
    localparam logic [31:0] REG_CONTROL     = 32'h10;

    localparam logic [63:0] MTIMECMP_RESET = 64'hFFFF_FFFF_FFFF_FFFF;
    localparam integer      ENABLE_BIT     = 0;
    localparam integer      BYTE_LSB       = 0;
    localparam integer      BYTE_MSB       = 7;
    localparam integer      BYTE1_LSB      = 8;
    localparam integer      BYTE1_MSB      = 15;
    localparam integer      BYTE2_LSB      = 16;
    localparam integer      BYTE2_MSB      = 23;
    localparam integer      BYTE3_LSB      = 24;
    localparam integer      BYTE3_MSB      = 31;

    logic [63:0] mtime;
    logic [63:0] mtimecmp;
    logic        enable;

    logic        write_en;
    logic [31:0] write_off;
    logic [31:0] read_off;
    logic [31:0] rdata_mux;

    assign write_en  = dmem.awvalid & dmem.wvalid;
    assign write_off = dmem.awaddr - TIMER_ADDR;
    assign read_off  = dmem.araddr - TIMER_ADDR;

    always_comb begin
        unique0 case (read_off)
            REG_MTIME_LO:    rdata_mux = mtime[31:0];
            REG_MTIME_HI:    rdata_mux = mtime[63:32];
            REG_MTIMECMP_LO: rdata_mux = mtimecmp[31:0];
            REG_MTIMECMP_HI: rdata_mux = mtimecmp[63:32];
            REG_CONTROL:     rdata_mux = {31'b0, enable};
            default:         rdata_mux = 32'h0000_0000;
        endcase
    end

    assign dmem.arready = 1'b1;
    assign dmem.rvalid  = dmem.arvalid;
    assign dmem.rdata   = rdata_mux;
    assign dmem.rresp   = 2'b00;

    assign dmem.awready = 1'b1;
    assign dmem.wready  = 1'b1;
    assign dmem.bvalid  = dmem.awvalid & dmem.wvalid;
    assign dmem.bresp   = 2'b00;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mtime    <= 64'd0;
            mtimecmp <= MTIMECMP_RESET;
            enable   <= 1'b0;
        end
        else begin
            if (enable)
                mtime <= mtime + 64'd1;

            if (write_en) begin
                unique0 case (write_off)
                    REG_MTIME_LO: begin
                        if (dmem.wstrb[0]) mtime[BYTE_LSB  +: 8] <= dmem.wdata[BYTE_LSB  +: 8];
                        if (dmem.wstrb[1]) mtime[BYTE1_LSB +: 8] <= dmem.wdata[BYTE1_LSB +: 8];
                        if (dmem.wstrb[2]) mtime[BYTE2_LSB +: 8] <= dmem.wdata[BYTE2_LSB +: 8];
                        if (dmem.wstrb[3]) mtime[BYTE3_LSB +: 8] <= dmem.wdata[BYTE3_LSB +: 8];
                    end
                    REG_MTIME_HI: begin
                        if (dmem.wstrb[0]) mtime[32 + BYTE_LSB  +: 8] <= dmem.wdata[BYTE_LSB  +: 8];
                        if (dmem.wstrb[1]) mtime[32 + BYTE1_LSB +: 8] <= dmem.wdata[BYTE1_LSB +: 8];
                        if (dmem.wstrb[2]) mtime[32 + BYTE2_LSB +: 8] <= dmem.wdata[BYTE2_LSB +: 8];
                        if (dmem.wstrb[3]) mtime[32 + BYTE3_LSB +: 8] <= dmem.wdata[BYTE3_LSB +: 8];
                    end
                    REG_MTIMECMP_LO: begin
                        if (dmem.wstrb[0]) mtimecmp[BYTE_LSB  +: 8] <= dmem.wdata[BYTE_LSB  +: 8];
                        if (dmem.wstrb[1]) mtimecmp[BYTE1_LSB +: 8] <= dmem.wdata[BYTE1_LSB +: 8];
                        if (dmem.wstrb[2]) mtimecmp[BYTE2_LSB +: 8] <= dmem.wdata[BYTE2_LSB +: 8];
                        if (dmem.wstrb[3]) mtimecmp[BYTE3_LSB +: 8] <= dmem.wdata[BYTE3_LSB +: 8];
                    end
                    REG_MTIMECMP_HI: begin
                        if (dmem.wstrb[0]) mtimecmp[32 + BYTE_LSB  +: 8] <= dmem.wdata[BYTE_LSB  +: 8];
                        if (dmem.wstrb[1]) mtimecmp[32 + BYTE1_LSB +: 8] <= dmem.wdata[BYTE1_LSB +: 8];
                        if (dmem.wstrb[2]) mtimecmp[32 + BYTE2_LSB +: 8] <= dmem.wdata[BYTE2_LSB +: 8];
                        if (dmem.wstrb[3]) mtimecmp[32 + BYTE3_LSB +: 8] <= dmem.wdata[BYTE3_LSB +: 8];
                    end
                    REG_CONTROL: begin
                        if (dmem.wstrb[0]) enable <= dmem.wdata[ENABLE_BIT];
                    end
                    default: ;
                endcase
            end
        end
    end

    assign timerIrq = enable & (mtime >= mtimecmp);

endmodule
