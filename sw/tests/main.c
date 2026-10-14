////////////////////////////////////////////////////////////////////////////////
// File       : main.c
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-14
// Description: Bare-metal timer and interrupt test for the MOOR RV32E SoC.
//              Programs the machine timer, enables MTIE and MIE. The trap
//              handler records each tick (mtime + tick index) into a small
//              log and reschedules MTIMECMP. Main prints the log after all
//              ticks have fired, so no tick is missed regardless of how long
//              the UART print path takes.
//
// Revisions:
//   2026-10-14 - Initial release
//   2026-10-14 - Tick logging moved into the ISR
////////////////////////////////////////////////////////////////////////////////

#include <stdint.h>

#define UART_TX           (*(volatile uint8_t  *)0x10000000u)

#define TIMER_MTIME_LO    (*(volatile uint32_t *)0x10001000u)
#define TIMER_MTIME_HI    (*(volatile uint32_t *)0x10001004u)
#define TIMER_MTIMECMP_LO (*(volatile uint32_t *)0x10001008u)
#define TIMER_MTIMECMP_HI (*(volatile uint32_t *)0x1000100Cu)
#define TIMER_CONTROL     (*(volatile uint32_t *)0x10001010u)

#define MSTATUS_MIE       (1u << 3)
#define MIE_MTIE          (1u << 7)

#define TICK_PERIOD       5000u
#define TICK_TARGET       5u

volatile uint32_t tick_count;
volatile uint32_t tick_log[TICK_TARGET];

/* -------- tiny UART helpers --------------------------------------------- */

static void uart_putc(char c)
{
    UART_TX = (uint8_t)c;
}

static void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

static void uart_put_u32(uint32_t v)
{
    char buf[10];
    int  n = 0;

    if (v == 0) {
        uart_putc('0');
        return;
    }
    while (v && n < 10) {
        buf[n++] = (char)('0' + (v % 10u));
        v /= 10u;
    }
    while (n--)
        uart_putc(buf[n]);
}

/* -------- CSR helpers ---------------------------------------------------- */

static inline void csr_write_mtvec(uint32_t v)
{
    asm volatile ("csrw mtvec, %0" :: "r"(v));
}

static inline void csr_set_mie(uint32_t v)
{
    asm volatile ("csrs mie, %0" :: "r"(v));
}

static inline void csr_set_mstatus(uint32_t v)
{
    asm volatile ("csrs mstatus, %0" :: "r"(v));
}

static inline void csr_clear_mstatus(uint32_t v)
{
    asm volatile ("csrc mstatus, %0" :: "r"(v));
}

/* -------- timer helpers -------------------------------------------------- */

static void timer_arm(uint32_t period)
{
    uint32_t now_lo  = TIMER_MTIME_LO;
    uint32_t now_hi  = TIMER_MTIME_HI;
    uint32_t next_lo = now_lo + period;
    uint32_t next_hi = (next_lo < now_lo) ? (now_hi + 1u) : now_hi;

    TIMER_MTIMECMP_HI = next_hi;
    TIMER_MTIMECMP_LO = next_lo;
    TIMER_CONTROL     = 1u;
}

static void timer_disable(void)
{
    TIMER_CONTROL = 0u;
}

/* -------- trap handler --------------------------------------------------- */

void trap_handler(void) __attribute__((interrupt("machine")));

void trap_handler(void)
{
    uint32_t idx    = tick_count;
    uint32_t now_lo = TIMER_MTIME_LO;
    uint32_t now_hi = TIMER_MTIME_HI;
    uint32_t next_lo;
    uint32_t next_hi;

    if (idx < TICK_TARGET)
        tick_log[idx] = now_lo;

    tick_count = idx + 1u;

    next_lo = now_lo + TICK_PERIOD;
    next_hi = (next_lo < now_lo) ? (now_hi + 1u) : now_hi;

    TIMER_MTIMECMP_HI = next_hi;
    TIMER_MTIMECMP_LO = next_lo;
}

/* -------- banner --------------------------------------------------------- */

static void banner(void)
{
    uart_puts("\n");
    uart_puts("========================================\n");
    uart_puts("  MOOR RV32E - timer + IRQ test\n");
    uart_puts("========================================\n");
    uart_puts("Timer base : 0x10001000\n");
    uart_puts("Period     : ");
    uart_put_u32(TICK_PERIOD);
    uart_puts(" cycles\n");
    uart_puts("Ticks      : ");
    uart_put_u32(TICK_TARGET);
    uart_puts("\n\n");
}

/* -------- main ----------------------------------------------------------- */

int main(void)
{
    banner();

    tick_count = 0;
    for (uint32_t i = 0; i < TICK_TARGET; i++)
        tick_log[i] = 0;

    csr_write_mtvec((uint32_t)trap_handler);
    uart_puts("[trap] mtvec = ");
    uart_put_u32((uint32_t)trap_handler);
    uart_puts("\n");

    timer_arm(TICK_PERIOD);
    uart_puts("[timer] armed and enabled\n");

    csr_set_mie(MIE_MTIE);
    csr_set_mstatus(MSTATUS_MIE);
    uart_puts("[csr] MTIE + MIE set, waiting for ticks...\n\n");

    while (tick_count < TICK_TARGET)
        ;

    csr_clear_mstatus(MSTATUS_MIE);
    timer_disable();

    for (uint32_t i = 0; i < TICK_TARGET; i++) {
        uart_puts("[tick ");
        uart_put_u32(i + 1u);
        uart_puts("] mtime = ");
        uart_put_u32(tick_log[i]);
        uart_puts("\n");
    }

    uart_puts("\n[timer] disabled, total ticks = ");
    uart_put_u32(tick_count);
    uart_puts("\n");

    uart_puts("\nDone.\n");
    return 0;
}