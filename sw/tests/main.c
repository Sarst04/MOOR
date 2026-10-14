////////////////////////////////////////////////////////////////////////////////
// File       : main.c
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-14
// Description: Comprehensive bare-metal test for the MOOR RV32E SoC. Exercises
//              arithmetic, shifts, compares, memory, branches, calls, function
//              pointers, strings, software mul/div, and the machine timer with
//              periodic, one-shot and burst interrupt patterns.
//
// Revisions:
//   2026-10-14 - Initial release
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
#define TIMER_ENABLE      1u

#define TICK_PERIOD       2000u
#define PERIODIC_TICKS    5u
#define STORM_TICKS       20u
#define STORM_PERIOD      50u
#define LOG_SIZE          32u

volatile uint32_t irq_count;
volatile uint32_t irq_log[LOG_SIZE];

/* -------- UART helpers --------------------------------------------------- */

static void uart_putc(char c) { UART_TX = (uint8_t)c; }

static void uart_puts(const char *s) { while (*s) uart_putc(*s++); }

static void uart_putc_hex(uint8_t n)
{
    uart_putc(n < 10 ? (char)('0' + n) : (char)('A' + n - 10));
}

static void uart_put_hex32(uint32_t v)
{
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4)
        uart_putc_hex((uint8_t)((v >> i) & 0xF));
}

static void uart_put_u32(uint32_t v)
{
    char b[11];
    int  n = 0;
    if (v == 0) { uart_putc('0'); return; }
    while (v && n < 10) { b[n++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (n--) uart_putc(b[n]);
}

static void uart_put_i32(int32_t v)
{
    if (v < 0) { uart_putc('-'); uart_put_u32((uint32_t)(-v)); }
    else uart_put_u32((uint32_t)v);
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

static inline void csr_clear_mie(uint32_t v)
{
    asm volatile ("csrc mie, %0" :: "r"(v));
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
    uint32_t lo  = TIMER_MTIME_LO;
    uint32_t hi  = TIMER_MTIME_HI;
    uint32_t nlo = lo + period;
    uint32_t nhi = (nlo < lo) ? (hi + 1u) : hi;
    TIMER_MTIMECMP_HI = nhi;
    TIMER_MTIMECMP_LO = nlo;
    TIMER_CONTROL     = TIMER_ENABLE;
}

static void timer_reschedule(uint32_t period)
{
    uint32_t lo  = TIMER_MTIME_LO;
    uint32_t hi  = TIMER_MTIME_HI;
    uint32_t nlo = lo + period;
    uint32_t nhi = (nlo < lo) ? (hi + 1u) : hi;
    TIMER_MTIMECMP_HI = nhi;
    TIMER_MTIMECMP_LO = nlo;
}

static void timer_disable(void) { TIMER_CONTROL = 0u; }

/* -------- trap handler --------------------------------------------------- */

void trap_handler(void) __attribute__((interrupt("machine")));

void trap_handler(void)
{
    uint32_t idx = irq_count;
    if (idx < LOG_SIZE)
        irq_log[idx] = TIMER_MTIME_LO;
    irq_count = idx + 1u;
    timer_reschedule(TICK_PERIOD);
}

/* -------- test infrastructure -------------------------------------------- */

static uint32_t test_failures;

static void section(const char *name)
{
    uart_puts("\n== ");
    uart_puts(name);
    uart_puts(" ==\n");
}

static void check(const char *name, int ok)
{
    uart_puts("  [");
    uart_puts(ok ? "PASS" : "FAIL");
    uart_puts("] ");
    uart_puts(name);
    uart_puts("\n");
    if (!ok)
        test_failures++;
}

/* -------- test 1: arithmetic --------------------------------------------- */

static void test_arith(void)
{
    section("arithmetic");
    volatile uint32_t a = 0x12345678u;
    volatile uint32_t b = 0x0F0F0F0Fu;

    check("add", (a + b) == 0x21436587u);
    check("sub", (a - b) == 0x03254769u);
    check("and", (a & b) == 0x02040608u);
    check("or",  (a | b) == 0x1F3F5F7Fu);
    check("xor", (a ^ b) == 0x1D3B5977u);
}

/* -------- test 2: shifts ------------------------------------------------- */

static void test_shifts(void)
{
    section("shifts");
    volatile uint32_t a = 0x80000001u;
    volatile int32_t  s = -1;
    volatile uint32_t n = 4;

    check("sll imm", (a << 4) == 0x00000010u);
    check("srl imm", (a >> 4) == 0x08000000u);
    check("sra imm", (s >> 4) == -1);
    check("sll var", (a << n) == 0x00000010u);
    check("srl var", (a >> n) == 0x08000000u);
    check("sra var", (s >> n) == -1);
}

/* -------- test 3: signed vs unsigned compares ---------------------------- */

static void test_compares(void)
{
    section("compares");
    volatile int32_t  m1 = -1;
    volatile uint32_t p1 = 1u;

    check("signed   -1 < 1",  (m1 < (int32_t)p1) == 1);
    check("unsigned -1 > 1",  (((uint32_t)m1) > p1) == 1);
    check("signed   -1 > -2", ((int32_t)-1 > (int32_t)-2) == 1);
}

/* -------- test 4: memory access ------------------------------------------ */

static volatile uint32_t buf32[8];
static volatile uint8_t  buf8[4];
static volatile uint16_t buf16[2];

static void test_memory(void)
{
    section("memory");

    int ok = 1;
    for (int i = 0; i < 8; i++)
        buf32[i] = 0xDEAD0000u + (uint32_t)i;
    for (int i = 0; i < 8; i++)
        if (buf32[i] != (0xDEAD0000u + (uint32_t)i))
            ok = 0;
    check("sw/lw", ok);

    buf8[0] = 0x12; buf8[1] = 0x34;
    buf8[2] = 0x56; buf8[3] = 0x78;
    check("sb/lbu",
          buf8[0] == 0x12 && buf8[1] == 0x34 &&
          buf8[2] == 0x56 && buf8[3] == 0x78);

    buf8[0] = 0xAB;
    check("lb sign",  ((int8_t)buf8[0])  == -85);
    check("lbu zero", buf8[0] == 0xAB);

    buf16[0] = 0xBEEF;
    buf16[1] = 0xCAFE;
    check("sh/lhu",
          buf16[0] == 0xBEEF && buf16[1] == 0xCAFE);
}

/* -------- test 5: branches ----------------------------------------------- */

static void test_branches(void)
{
    section("branches");
    volatile uint32_t a = 5, b = 5, c = 7;

    check("beq", (a == b) == 1);
    check("bne", (a != c) == 1);
    check("blt", (a <  c) == 1);
    check("bge", (c >= a) == 1);
    check("bltu",(a <  c) == 1);
    check("bgeu",(c >= a) == 1);
}

/* -------- test 6: recursion ---------------------------------------------- */

static uint32_t fib(uint32_t n)
{
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

static uint32_t gcd_rec(uint32_t a, uint32_t b)
{
    if (b == 0) return a;
    return gcd_rec(b, a % b);
}

static void test_recursion(void)
{
    section("recursion");
    check("fib(10) == 55",    fib(10) == 55);
    check("fib(15) == 610",   fib(15) == 610);
    check("gcd(48,18) == 6",  gcd_rec(48, 18) == 6);
    check("gcd(1071,462) == 21", gcd_rec(1071, 462) == 21);
}

/* -------- test 7: function pointers -------------------------------------- */

typedef uint32_t (*fp_t)(uint32_t);

static uint32_t fn_inc(uint32_t x) { return x + 1u; }
static uint32_t fn_dbl(uint32_t x) { return x * 2u; }
static uint32_t fn_sqr(uint32_t x) { return x * x; }

static const fp_t fn_tbl[3] = { fn_inc, fn_dbl, fn_sqr };

static void test_fptr(void)
{
    section("function pointers");
    volatile uint32_t x = 5;
    check("inc(5) == 6",   fn_tbl[0](x) == 6);
    check("dbl(5) == 10",  fn_tbl[1](x) == 10);
    check("sqr(5) == 25",  fn_tbl[2](x) == 25);
}

/* -------- test 8: strings ------------------------------------------------ */

static uint32_t str_len(const char *s)
{
    uint32_t n = 0;
    while (s[n]) n++;
    return n;
}

static int str_eq(const char *a, const char *b)
{
    while (*a && *a == *b) { a++; b++; }
    return *a == *b;
}

static void test_strings(void)
{
    section("strings");
    check("strlen(hello) == 5", str_len("hello") == 5u);
    check("streq foo/foo",     str_eq("foo", "foo"));
    check("streq foo/bar fail", !str_eq("foo", "bar"));
    check("streq empty/empty", str_eq("", ""));
}

/* -------- test 9: soft multiply and divide ------------------------------- */

static uint32_t mul_soft(uint32_t a, uint32_t b)
{
    uint32_t r = 0;
    while (b) {
        if (b & 1u) r += a;
        a <<= 1;
        b >>= 1;
    }
    return r;
}

static uint32_t div_soft(uint32_t a, uint32_t b)
{
    if (b == 0) return 0xFFFFFFFFu;
    uint32_t q = 0;
    uint32_t r = 0;
    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((a >> i) & 1u);
        if (r >= b) { r -= b; q |= (1u << i); }
    }
    return q;
}

static void test_muldiv(void)
{
    section("soft mul/div");
    check("mul(13,7) == 91",         mul_soft(13, 7) == 91u);
    check("mul(255,255) == 65025",   mul_soft(255, 255) == 65025u);
    check("mul(65535,65535) == 0xFFFE0001",
          mul_soft(0xFFFFu, 0xFFFFu) == 0xFFFE0001u);
    check("div(100,7) == 14",        div_soft(100, 7) == 14u);
    check("div(1000000,1000) == 1000",
          div_soft(1000000u, 1000u) == 1000u);
}

/* -------- test 10: timer periodic IRQ ------------------------------------ */

static void test_timer_periodic(void)
{
    section("timer periodic IRQ");

    irq_count = 0;
    csr_clear_mstatus(MSTATUS_MIE);
    csr_clear_mie(MIE_MTIE);

    csr_write_mtvec((uint32_t)trap_handler);
    timer_arm(TICK_PERIOD);
    csr_set_mie(MIE_MTIE);
    csr_set_mstatus(MSTATUS_MIE);

    while (irq_count < PERIODIC_TICKS)
        ;

    csr_clear_mstatus(MSTATUS_MIE);
    timer_disable();

    for (uint32_t i = 0; i < PERIODIC_TICKS; i++) {
        uart_puts("  tick ");
        uart_put_u32(i + 1u);
        uart_puts(" @ mtime = ");
        uart_put_u32(irq_log[i]);
        uart_puts("\n");
    }
    check("periodic count", irq_count == PERIODIC_TICKS);
}

/* -------- test 11: timer one-shot ---------------------------------------- */

static void test_timer_oneshot(void)
{
    section("timer one-shot");

    irq_count = 0;
    csr_clear_mstatus(MSTATUS_MIE);
    timer_arm(TICK_PERIOD * 2u);
    csr_set_mstatus(MSTATUS_MIE);

    uint32_t spin = 0;
    while (irq_count < 1u && spin < 10000000u)
        spin++;

    csr_clear_mstatus(MSTATUS_MIE);
    timer_disable();

    check("one-shot fired exactly once", irq_count == 1u);
}

/* -------- test 12: timer burst ------------------------------------------- */

static void test_timer_burst(void)
{
    section("timer burst");

    irq_count = 0;
    csr_clear_mstatus(MSTATUS_MIE);
    timer_arm(STORM_PERIOD);
    csr_set_mstatus(MSTATUS_MIE);

    uint32_t spin = 0;
    while (irq_count < STORM_TICKS && spin < 100000000u)
        spin++;

    csr_clear_mstatus(MSTATUS_MIE);
    timer_disable();

    uart_puts("  burst IRQ count = ");
    uart_put_u32(irq_count);
    uart_puts("\n");
    check("burst got >= 20 IRQs", irq_count >= STORM_TICKS);
}

/* -------- test 13: mixed integer workload -------------------------------- */

static uint32_t hash_state = 0x12345678u;

static uint32_t hash_step(uint32_t x)
{
    x ^= x >> 16;
    x += 0x7ED55D16u;
    x ^= x << 12;
    x -= 0x165667B1u;
    x ^= x >> 5;
    x += 0xD3A2646Cu;
    x ^= x << 9;
    return x;
}

static void test_workload(void)
{
    section("mixed workload");

    uint32_t h = hash_state;
    for (uint32_t i = 0; i < 64u; i++)
        h = hash_step(h + i);
    hash_state = h;

    uart_puts("  hash = ");
    uart_put_hex32(h);
    uart_puts("\n");
    check("hash produced nonzero", h != 0u);
}

/* -------- banner and main ------------------------------------------------ */

static void banner(void)
{
    uart_puts("\n");
    uart_puts("========================================\n");
    uart_puts("  MOOR RV32E - full core + IRQ test\n");
    uart_puts("========================================\n");
    uart_puts("Timer base : 0x10001000\n");
    uart_puts("UART base  : 0x10000000\n");
}

int main(void)
{
    banner();

    test_arith();
    test_shifts();
    test_compares();
    test_memory();
    test_branches();
    test_recursion();
    test_fptr();
    test_strings();
    test_muldiv();
    test_workload();
    test_timer_periodic();
    test_timer_oneshot();
    test_timer_burst();

    uart_puts("\n");
    if (test_failures == 0) {
        uart_puts("ALL TESTS PASSED\n");
    } else {
        uart_puts("FAILURES: ");
        uart_put_u32(test_failures);
        uart_puts("\n");
    }

    uart_puts("Done.\n");
    return 0;
}