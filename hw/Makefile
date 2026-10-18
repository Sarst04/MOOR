################################################################################
# File       : Makefile
# Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
# Created    : 2026-10-13
# Description: Verilator build / lint / run targets for the MOOR RV32E SoC.
#
# Revisions:
#   2026-10-13 - Initial release
#   2026-10-13 - Shared warning set for build and lint
#   2026-10-13 - Paths updated for rtl/core, rtl/periph/uart, rtl/soc layout
#   2026-10-13 - SEED variable for +verilator+seed (random memory latency)
################################################################################

VERILATOR ?= verilator

TOP      := MOOR_tb
OBJ_DIR  := build/obj_dir
BIN      := $(OBJ_DIR)/$(TOP)

RTL_CORE   := rtl/core
RTL_PERIPH := rtl/periph
RTL_SOC    := rtl/soc

# RNG seed for $urandom_range (memory latency) and any other SV randomization.
#   0            -> non-deterministic (time-based)
#   <nonzero>    -> reproducible run
# Override on the command line:  make run SEED=12345
SEED     ?= 0

SV_SOURCES := \
	$(RTL_CORE)/MOOR_pkg.sv \
	$(RTL_CORE)/MOOR_axi_if.sv \
	$(RTL_CORE)/MOOR_alu.sv \
	$(RTL_CORE)/MOOR_controller.sv \
	$(RTL_CORE)/MOOR_csr.sv \
	$(RTL_CORE)/MOOR_datapath.sv \
	$(RTL_CORE)/MOOR_imm_gen.sv \
	$(RTL_CORE)/MOOR_lsu.sv \
	$(RTL_CORE)/MOOR_pc_unit.sv \
	$(RTL_CORE)/MOOR_regfile.sv \
	$(RTL_CORE)/MOOR_shifter.sv \
	$(RTL_CORE)/MOOR_core.sv \
	mem/MOOR_mem.sv \
	$(RTL_PERIPH)/uart/MOOR_uart.sv \
	$(RTL_PERIPH)/timer/MOOR_timer.sv \
	$(RTL_SOC)/MOOR_dmem_router.sv \
	$(RTL_SOC)/MOOR_SoC.sv \
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

VERILATOR_FLAGS := --binary $(COMMON_FLAGS) \
	-O3 \
	-CFLAGS "-O3 -march=native -flto" \
	-LDFLAGS "-flto"

LINT_FLAGS      := --lint-only $(COMMON_FLAGS)

.PHONY: all build run run-seed lint clean help

all: run

build: $(BIN)

$(BIN): $(SV_SOURCES)
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--Mdir $(OBJ_DIR) \
		-o $(TOP) \
		$(SV_SOURCES)

run: build
	@mkdir -p sim/out
	@if [ "$(SEED)" != "0" ]; then \
		echo "Running with +verilator+seed+$(SEED)"; \
	fi
	cd sim && ../$(BIN) +verilator+seed+$(SEED)

# Explicit target for a fixed reproducible seed.
# Usage: make run-seed SEED=12345
run-seed: build
	@mkdir -p sim/out
	@if [ "$(SEED)" = "0" ]; then \
		echo "error: set SEED=<nonzero> (e.g. make run-seed SEED=12345)"; \
		exit 1; \
	fi
	@echo "Running with +verilator+seed+$(SEED)"
	cd sim && ../$(BIN) +verilator+seed+$(SEED)

lint:
	$(VERILATOR) $(LINT_FLAGS) $(SV_SOURCES)

clean:
	rm -rf build sim/out

help:
	@echo "MOOR Verilator targets:"
	@echo "  make                     Build and run the testbench"
	@echo "  make build               Compile the simulation"
	@echo "  make run                 Run (SEED=0 -> non-deterministic)"
	@echo "  make run SEED=12345      Run with a fixed RNG seed"
	@echo "  make run-seed SEED=12345 Run with a fixed RNG seed (errors if 0)"
	@echo "  make lint                Check RTL and testbench warnings"
	@echo "  make clean               Remove generated build files"