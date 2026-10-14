    .section .text.start, "ax", @progbits
    .globl _start
    .type _start, @function
_start:
    la   sp, _stack_top

    la   t0, __bss_start
    la   t1, __bss_end
.L_bss_loop:
    bgeu t0, t1, .L_bss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    .L_bss_loop
.L_bss_done:

    la   t0, default_trap
    csrw mtvec, t0

    call main

    la   t0, _endsim
    li   t1, 1
    sw   t1, 0(t0)

.L_hang:
    li      t0, 0x20000000
    li      t1, 0x1
    sw      t1, 0(t0)
    j    .L_hang

    .size _start, . - _start

    .section .text
    .align 2
    .globl default_trap
    .type default_trap, @function
default_trap:
    mret
    .size default_trap, . - default_trap