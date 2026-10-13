/*//////////////////////////////////////////////////////////////////////////////
// File       : linker.ld
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-13
// Description: Linker script for the MOOR RV32E SoC.
//
//              Memory layout (matches MOOR_mem with PC_BITS = 12, 4 KiB):
//                0x000 - 0x3FF  .text / .rodata
//                0x400          end-of-test marker (written by startup.s)
//                0x500 - 0x5FF  result words (checked by MOOR_tb)
//                0x800 - 0xFFC  .data / .bss / stack
//
//              Stack grows down from _stack_top = 0xFFC.
//
// Revisions:
//   2026-10-13 - Initial release
//   2026-10-13 - Define __global_pointer$ for gp-relative addressing
//////////////////////////////////////////////////////////////////////////////*/

ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.init))
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

    /* Small data: globals reachable via gp + 12-bit signed offset.
       __global_pointer$ must sit ~0x800 below the small-data region
       so that the whole 4 KiB of small data fits in +/-2 KiB. */
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

    /* Stack: top of RAM minus one word. */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM) - 4;

    /DISCARD/ : {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame.*)
        *(.riscv.attributes)
    }
}