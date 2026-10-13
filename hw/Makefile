################################################################################
# File       : Makefile
# Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
# Created    : 2026-10-13
# Description: Verilator build / lint / run targets for the MOOR RV32E SoC.
#
# Revisions:
#   2026-10-13 - Initial release
#   2026-10-13 - Shared warning set for build and lint
################################################################################

VERILATOR ?= verilator

TOP      := MOOR_tb
OBJ_DIR  := build/obj_dir
BIN      := $(OBJ_DIR)/$(TOP)

RTL_DIR  := rtl

SV_SOURCES := \
	$(RTL_DIR)/MOOR_pkg.sv \
	$(RTL_DIR)/MOOR_axi_if.sv \
	$(RTL_DIR)/MOOR_alu.sv \
	$(RTL_DIR)/MOOR_controller.sv \
	$(RTL_DIR)/MOOR_csr.sv \
	$(RTL_DIR)/MOOR_datapath.sv \
	$(RTL_DIR)/MOOR_imm_gen.sv \
	$(RTL_DIR)/MOOR_lsu.sv \
	$(RTL_DIR)/MOOR_pc_unit.sv \
	$(RTL_DIR)/MOOR_regfile.sv \
	$(RTL_DIR)/MOOR_shifter.sv \
	$(RTL_DIR)/MOOR_core.sv \
	mem/MOOR_mem.sv \
	MOOR_dmem_router.sv \
	uart/MOOR_uart.sv \
	MOOR_SoC.sv \
	tb/MOOR_tb.sv

# Warnings deliberately suppressed:
#   TIMESCALEMOD  - testbench-only concern; no delays in RTL
#   UNUSEDSIGNAL  - decode-tree bits, unused slave clk/rst
#   UNUSEDPARAM   - package constants reserved for future opcodes
COMMON_FLAGS := \
	--timing \
	--sv \
	--top-module $(TOP) \
	-Wall \
	-Wno-fatal \
	-Wno-TIMESCALEMOD \
	-Wno-UNUSEDSIGNAL \
	-Wno-UNUSEDPARAM

VERILATOR_FLAGS := --binary $(COMMON_FLAGS)
LINT_FLAGS      := --lint-only $(COMMON_FLAGS)

.PHONY: all build run lint clean help

all: run

build: $(BIN)

$(BIN): $(SV_SOURCES)
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--Mdir $(OBJ_DIR) \
		-o $(TOP) \
		$(SV_SOURCES)

run: build
	cd sim && ../$(BIN)

lint:
	$(VERILATOR) $(LINT_FLAGS) $(SV_SOURCES)

clean:
	rm -rf build

help:
	@echo "MOOR Verilator targets:"
	@echo "  make       Build and run the testbench"
	@echo "  make build Compile the simulation"
	@echo "  make run   Run the simulation"
	@echo "  make lint  Check RTL and testbench warnings"
	@echo "  make clean Remove generated build files"