#include <stdint.h>
#define UART_TX (*(volatile uint8_t *)0x10000000u)
#define T_LO  (*(volatile uint32_t *)0x10001000u)
#define T_HI  (*(volatile uint32_t *)0x10001004u)
#define C_LO  (*(volatile uint32_t *)0x10001008u)
#define C_HI  (*(volatile uint32_t *)0x1000100Cu)
#define T_CTL (*(volatile uint32_t *)0x10001010u)
#ifndef PERIOD
#define PERIOD 70u
#endif
static void putc_(char c){ UART_TX=(uint8_t)c; }
static void puts_(const char*s){ while(*s) putc_(*s++); }
static void puth(uint32_t v){ for(int i=28;i>=0;i-=4){ uint32_t n=(v>>i)&15; putc_(n<10?'0'+n:'A'+n-10);} }

static inline uint32_t hw_mul(uint32_t a,uint32_t b){uint32_t r;asm volatile("mul %0,%1,%2":"=r"(r):"r"(a),"r"(b));return r;}
static inline uint32_t hw_mulh(uint32_t a,uint32_t b){uint32_t r;asm volatile("mulh %0,%1,%2":"=r"(r):"r"(a),"r"(b));return r;}
static inline uint32_t hw_mulhsu(uint32_t a,uint32_t b){uint32_t r;asm volatile("mulhsu %0,%1,%2":"=r"(r):"r"(a),"r"(b));return r;}
static inline uint32_t hw_mulhu(uint32_t a,uint32_t b){uint32_t r;asm volatile("mulhu %0,%1,%2":"=r"(r):"r"(a),"r"(b));return r;}

/* software reference, no multiply operator: 64-bit unsigned shift-add */
static void ref_umul(uint32_t a,uint32_t b,uint32_t*hi,uint32_t*lo){
    uint32_t h=0,l=0;
    for(int i=31;i>=0;i--){
        /* {h,l} <<= 1 */
        h=(h<<1)|(l>>31); l<<=1;
        if((b>>i)&1u){ uint32_t nl=l+a; if(nl<l) h++; l=nl; }
    }
    *hi=h; *lo=l;
}
static uint32_t neg(uint32_t x){ return ~x+1u; }

volatile uint32_t irq_count, isr_errs;
void trap_handler(void) __attribute__((interrupt("machine")));
void trap_handler(void){
    /* multiply inside the ISR too: must not disturb interrupted code */
    uint32_t x = 0x9E3779B9u, y = 0x85EBCA6Bu;
    if(hw_mul(x,y)!=0xc10eda53u) isr_errs++;
    if(hw_mulhu(x,y)!=0x52c48c43u) isr_errs++;
    irq_count++;
    uint32_t lo=T_LO, hi=T_HI, nlo=lo+PERIOD+((irq_count&31u)<<1); C_HI=(nlo<lo)?hi+1u:hi; C_LO=nlo;
}
static uint32_t rng=0x12345678u;
static uint32_t rnd(void){ rng^=rng<<13; rng^=rng>>17; rng^=rng<<5; return rng; }

int main(void){
    static const uint32_t ed[]={0u,1u,2u,0xFFFFFFFFu,0x80000000u,0x7FFFFFFFu,0x80000001u,0xFFFFFFFEu,0xFFFFu,0x10000u,0xDEADBEEFu};
    uint32_t errs=0, n=0;
    asm volatile("csrw mtvec,%0"::"r"((uint32_t)trap_handler));
    C_HI=0; C_LO=T_LO+PERIOD; T_CTL=1u;
    asm volatile("csrs mie,%0"::"r"(1u<<7));
    asm volatile("csrs mstatus,%0"::"r"(1u<<3));
    for(uint32_t k=0;k<1500u;k++){
        uint32_t a,b;
        if(k<121u){ a=ed[k/11u]; b=ed[k%11u]; } else { a=rnd(); b=rnd(); }
        uint32_t uh,ul; ref_umul(a,b,&uh,&ul);
        uint32_t sh_ss=uh-(((int32_t)a<0)?b:0u)-(((int32_t)b<0)?a:0u);
        uint32_t sh_su=uh-(((int32_t)a<0)?b:0u);
        uint32_t m0=hw_mul(a,b), m1=hw_mulh(a,b), m2=hw_mulhsu(a,b), m3=hw_mulhu(a,b);
        n++;
        if(m0!=ul||m1!=sh_ss||m2!=sh_su||m3!=uh){ errs++; if(errs<4){puts_("BAD ");puth(a);putc_(' ');puth(b);putc_(' ');puth(m1);putc_(' ');puth(sh_ss);putc_('\n');} }
    }
    asm volatile("csrc mstatus,%0"::"r"(1u<<3));
    puts_("vectors="); puth(n); puts_(" errs="); puth(errs); puts_(" isr_errs="); puth(isr_errs); puts_(" irqs="); puth(irq_count); putc_('\n');
    puts_((errs==0&&isr_errs==0&&irq_count>50u)?"ZMMUL PASS\n":"ZMMUL FAIL\n");
    return 0;
}
