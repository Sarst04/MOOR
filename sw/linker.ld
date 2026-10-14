/*//////////////////////////////////////////////////////////////////////////////
// File       : linker.ld
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-13
// Description: Linker script for the MOOR RV32E SoC.
//
//              RAM size must match the testbench PC_BITS:
//                PC_BITS = 13  ->  MEM_WORDS = 2048  ->  8 KB
//
//              Layout (sequential, no hardcoded offsets):
//                .text / .rodata / .data / .sdata / .bss  from 0x0000 up
//                _stack_top                                top of RAM - 4
//                _endsim                                   top of RAM - 16
//
//              The end-of-simulation marker written by startup.s lives at
//              _endsim, in the last 16 bytes of RAM, so it can never collide
//              with code, data or stack regardless of how the image grows.
//
// Revisions:
//   2026-10-13 - Initial release
//   2026-10-13 - Define __global_pointer$ for gp-relative addressing
//   2026-10-14 - RAM size matched to PC_BITS = 13; marker moved to _endsim
//////////////////////////////////////////////////////////////////////////////*/

ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.start))
        *(.text.init)
        *(.text .text.*)
        . = ALIGN(4);
    } > RAM

    .rodata : ALIGN(4) {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
    } > RAM

    .data : ALIGN(4) {
        _data_start = .;
        *(.data .data.*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM

    .sdata : ALIGN(4) {
        __global_pointer$ = . + 0x800;
        *(.sdata .sdata.*)
        *(.sbss .sbss.*)
        . = ALIGN(4);
    } > RAM

    .bss : ALIGN(4) {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    . = ALIGN(4);
    _end = .;

    _endsim    = ORIGIN(RAM) + LENGTH(RAM) - 16;
    _stack_top = ORIGIN(RAM) + LENGTH(RAM) - 4;

    /DISCARD/ : {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame.*)
        *(.riscv.attributes)
    }
}