################################################################################
# File       : Makefile
# Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
# Created    : 2026-10-13
# Description: Build program.hex for the MOOR RV32E SoC from startup.s + main.c.
#
# Revisions:
#   2026-10-13 - Initial release
################################################################################

CROSS   ?= riscv32-unknown-elf-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy
OBJDUMP  = $(CROSS)objdump
SIZE     = $(CROSS)size
NM       = $(CROSS)nm

ARCH    ?= rv32e
ABI     ?= ilp32e

# -ffreestanding -nostdlib: no host runtime.
# No M extension, no C extension (core decodes only 32-bit base instrs).
# -fno-builtin -fno-stack-protector: keep codegen predictable.
CFLAGS  = -march=$(ARCH) -mabi=$(ABI) -Os -g \
          -ffreestanding -nostdlib -nostartfiles \
          -fno-builtin -fno-stack-protector -fno-common \
          -Wall -Wextra -Wno-unused-parameter \
          -I.

LDFLAGS = -march=$(ARCH) -mabi=$(ABI) \
          -T linker.ld -nostdlib -nostartfiles -Wl,--gc-sections

TARGET  = program.hex
ELF     = program.elf
OBJS    = startup.o main.o

all: $(TARGET)

$(TARGET): $(ELF)
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@
	$(OBJDUMP) -d -M no-aliases $< > program.dump
	$(SIZE) $<
	@echo "Built $(TARGET)"

$(ELF): $(OBJS) linker.ld
	$(CC) $(LDFLAGS) -o $@ $(OBJS) -lgcc

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

dump: $(ELF)
	$(OBJDUMP) -d -M no-aliases $< | less

nm: $(ELF)
	$(NM) -n $<

clean:
	rm -f $(OBJS) $(ELF) $(TARGET) program.dump

.PHONY: all clean dump nm