////////////////////////////////////////////////////////////////////////////////
// File       : main.c
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-10-13
// Description: Bare-metal UART demo for the MOOR RV32E SoC.
//
//              All output goes through the bus-functional UART at
//              0x1000_0000. Exercises stores, loads, arithmetic, branches,
//              shifts, comparisons and function calls so the core is
//              reasonably covered. No result words are written to memory -
//              the end-of-test marker is emitted by startup.s after main()
//              returns.
//
// Revisions:
//   2026-10-13 - Initial release
//   2026-10-13 - UART-only version (memory checks removed from tb)
////////////////////////////////////////////////////////////////////////////////

#include <stdint.h>

#define UART_TX  (*(volatile uint8_t *)0x10000000u)


static void uart_putc(char c)
{
    UART_TX = (uint8_t)c;
}

static void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

static void uart_putc_hex(uint8_t nib)
{
    uart_putc(nib < 10 ? (char)('0' + nib)
                       : (char)('A' + nib - 10));
}

static void uart_put_hex32(uint32_t v)
{
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4)
        uart_putc_hex((uint8_t)((v >> i) & 0xF));
}

static void uart_put_u32(uint32_t v)
{
    char buf[11];
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

static void uart_put_i32(int32_t v)
{
    if (v < 0) {
        uart_putc('-');
        uart_put_u32((uint32_t)(-v));
    } else {
        uart_put_u32((uint32_t)v);
    }
}

static uint32_t fib(uint32_t n)
{
    uint32_t a = 0, b = 1;
    while (n--) {
        uint32_t t = a + b;
        a = b;
        b = t;
    }
    return a;
}

static uint32_t mix(uint32_t x)
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

static void banner(void)
{
    uart_puts("\n");
    uart_puts("UART base : 0x10000000\n");
    uart_puts("Hello, MOOR!\n\n");
}

static void test_fib(void)
{
    uart_puts("[fib] ");
    for (uint32_t i = 0; i < 12; i++) {
        uart_put_u32(fib(i));
        uart_putc(i == 11 ? '\n' : ' ');
    }
}

static void test_mix(void)
{
    uart_puts("[mix] ");
    uint32_t x = 0x00000001u;
    for (int i = 0; i < 6; i++) {
        x = mix(x);
        uart_put_hex32(x);
        uart_putc(i == 5 ? '\n' : ' ');
    }
}

static void test_signed(void)
{
    uart_puts("[sgn] ");
    int32_t v = -100;
    for (int i = 0; i < 8; i++) {
        uart_put_i32(v);
        uart_putc(i == 7 ? '\n' : ' ');
        v = (v * 3) / 2;   /* no M: compiles to shifts/adds */
    }
}

static void test_strings(void)
{
    static const char *const words[] = {
        "alpha", "bravo", "charlie", "delta"
    };

    uart_puts("[str] ");
    for (int i = 0; i < 4; i++) {
        uart_puts(words[i]);
        uart_putc(i == 3 ? '\n' : ' ');
    }
}

int main(void)
{
    banner();

    test_fib();
    test_mix();
    test_signed();
    test_strings();

    uart_puts("\nDone.\n");
    return 0;
}