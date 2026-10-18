################################################################################
# File       : Makefile
# Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
# Created    : 2026-10-13
# Description: Build program.hex for the MOOR RV32E SoC from startup.s + main.c.
#              Objects go to build/, final artifacts go to out/, and
#              out/program.hex is copied to hw/sim/ for the Verilator testbench.
#
# Revisions:
#   2026-10-13 - Initial release
#   2026-10-14 - build/ and out/ directories; auto-copy to hw/sim/
################################################################################

CROSS   ?= riscv32-unknown-elf-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy
OBJDUMP  = $(CROSS)objdump
SIZE     = $(CROSS)size
NM       = $(CROSS)nm

ARCH    ?= rv32e_zicsr_zmmul
ABI     ?= ilp32e

CFLAGS  = -march=$(ARCH) -mabi=$(ABI) -Os -g \
          -ffreestanding -nostdlib -nostartfiles \
          -fno-builtin -fno-stack-protector -fno-common \
          -Wall -Wextra -Wno-unused-parameter \
          -I.

LDFLAGS = -march=$(ARCH) -mabi=$(ABI) \
          -T linker.ld -nostdlib -nostartfiles -Wl,--gc-sections

BUILD_DIR := build
OUT_DIR   := out
HW_SIM    := ../hw/sim

OBJS := $(BUILD_DIR)/startup.o $(BUILD_DIR)/tests/main.o

ELF  := $(OUT_DIR)/program.elf
HEX  := $(OUT_DIR)/program.hex
DUMP := $(OUT_DIR)/program.dump

all: $(HEX)

$(HEX): $(ELF)
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@
	$(OBJDUMP) -d -M no-aliases $< > $(DUMP)
	$(SIZE) $<
	@echo "Built $(HEX)"
	@mkdir -p $(HW_SIM)
	@cp $(HEX) $(HW_SIM)/program.hex
	@echo "Copied $(HEX) -> $(HW_SIM)/program.hex"

$(ELF): $(OBJS) linker.ld
	@mkdir -p $(OUT_DIR)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) -lgcc

$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.s
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

dump: $(ELF)
	$(OBJDUMP) -d -M no-aliases $< | less

nm: $(ELF)
	$(NM) -n $<

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)

distclean: clean
	rm -f $(HW_SIM)/program.hex

.PHONY: all clean distclean dump nm