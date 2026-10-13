#//////////////////////////////////////////////////////////////////////////////
# File       : startup.s
# Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
# Created    : 2026-10-13
# Description: MOOR RV32E reset entry point. Sets up gp and sp, zeroes .bss,
#              calls main(), writes DEADBEEF to 0x400 as an end-of-test
#              marker, then spins. Only x0..x15 are used (RV32E).
#
# Revisions:
#   2026-10-13 - Initial release
#   2026-10-13 - Use '#' comments for GAS (// is not accepted in .s files)
#//////////////////////////////////////////////////////////////////////////////

    .section .text.init, "ax", @progbits
    .globl  _start
    .type   _start, @function

_start:
    # Global pointer (RISC-V small-data addressing).
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    # Stack pointer: top of RAM.
    la      sp, _stack_top

    # Zero .bss.
    la      a0, __bss_start
    la      a1, __bss_end
1:  bgeu    a0, a1, 2f
    sw      zero, 0(a0)
    addi    a0, a0, 4
    j       1b
2:

    # int main(void)
    call    main
    
    li      t0, 0x20000000
    li      t1, 0x1
    sw      t1, 0(t0)

3:  j       3b

    .size   _start, . - _start
