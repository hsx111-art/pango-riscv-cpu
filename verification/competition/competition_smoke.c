typedef unsigned int uint32_t;

#define UART_TX       (*(volatile uint32_t *)0x10000000u)
#define UART_STATUS   (*(volatile uint32_t *)0x10000004u)
#define GPIO_OUT      (*(volatile uint32_t *)0x10000010u)
#define GPIO_IN       (*(volatile uint32_t *)0x10000014u)
#define GPIO_OE       (*(volatile uint32_t *)0x10000018u)
#define TIMER_LO      (*(volatile uint32_t *)0x10000020u)
#define TIMER_HI      (*(volatile uint32_t *)0x10000024u)
#define TIMECMP_LO    (*(volatile uint32_t *)0x10000028u)
#define TIMECMP_HI    (*(volatile uint32_t *)0x1000002cu)
#define TIMER_CTRL    (*(volatile uint32_t *)0x10000030u)

#define MSTATUS_MIE   (1u << 3)
#define MIE_MTIE      (1u << 7)
#define MTIP_MCAUSE   0x80000007u

volatile uint32_t timer_seen;
volatile uint32_t test_failed;

static void uart_putc(char ch)
{
    while (UART_STATUS & 2u)
        ;
    UART_TX = (uint32_t)(unsigned char)ch;
}

static void uart_puts(const char *text)
{
    while (*text)
        uart_putc(*text++);
}

void timer_trap_handler(void)
{
    uint32_t cause;

    asm volatile ("csrr %0, mcause" : "=r" (cause));
    if (cause == MTIP_MCAUSE)
    {
        timer_seen = 1;
        TIMER_CTRL = 0;
        asm volatile ("csrwi mip, 0" ::: "memory");
    }
    else
        test_failed = 1;
}

static void fail(const char *reason)
{
    test_failed = 1;
    GPIO_OUT = 0xdeadu;
    uart_puts("COMPETITION_FAIL:");
    uart_puts(reason);
    uart_puts("\n");
    for (;;)
        ;
}

int main(void)
{
    uint32_t now;

    GPIO_OE  = 0xffffffffu;
    GPIO_OUT = 0x13579bdfu;
    if (GPIO_OUT != 0x13579bdfu)
        fail("gpio_out");
    if (GPIO_IN != 0x5a5a1234u)
        fail("gpio_in");

    uart_puts("COMPETITION_SMOKE\n");

    now = TIMER_LO;
    TIMER_HI   = 0;
    TIMECMP_HI = 0;
    TIMECMP_LO = now + 256u;
    TIMER_CTRL = 1;

    asm volatile ("csrs mie, %0" : : "r" (MIE_MTIE));
    asm volatile ("csrs mstatus, %0" : : "r" (MSTATUS_MIE));

    while (!timer_seen && !test_failed)
        GPIO_OUT = 0x2468ace0u;

    if (test_failed || !timer_seen)
        fail("timer");

    GPIO_OUT = 0x600d0001u;
    uart_puts("COMPETITION_PASS\n");
    for (;;)
        ;
}
