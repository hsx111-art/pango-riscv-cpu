typedef unsigned int uint32_t;

#define CSR_DSCRATCH 0x7b2
#define SIM_CTRL_EXIT 0u
#define SIM_CTRL_PUTC (1u << 24)

static inline void sim_putc(int ch)
{
    uint32_t arg = SIM_CTRL_PUTC | ((uint32_t)ch & 0xffu);
    asm volatile ("csrw dscratch,%0" : : "r"(arg));
}

static inline void sim_exit(int code)
{
    uint32_t arg = SIM_CTRL_EXIT | ((uint32_t)code & 0xffu);
    asm volatile ("csrw dscratch,%0" : : "r"(arg));
}

static void print_text(const char *text)
{
    while (*text)
        sim_putc(*text++);
}

static void fail(const char *name)
{
    print_text("CACHE_WORKLOAD_FAIL ");
    print_text(name);
    print_text("\n");
    sim_exit(1);
    for (;;)
        ;
}

#define EXPECT_EQ(name, actual, expected) \
    do { \
        if ((actual) != (expected)) \
            fail(name); \
    } while (0)

/* These four addresses share index bits [12:5] and differ in tag bits. */
volatile uint32_t cache_a __attribute__((section(".cache_a"), aligned(32))) = 0x11111111u;
volatile uint32_t cache_b __attribute__((section(".cache_b"), aligned(32))) = 0x22222222u;
volatile uint32_t cache_c __attribute__((section(".cache_c"), aligned(32))) = 0x33333333u;
volatile uint32_t cache_d __attribute__((section(".cache_d"), aligned(32))) = 0x44444444u;

int main(void)
{
    uint32_t value;

    value = cache_a;
    EXPECT_EQ("initial_a", value, 0x11111111u);
    value = cache_a;
    EXPECT_EQ("hit_a", value, 0x11111111u);
    cache_a = 0xa5a5a5a5u;
    value = cache_a;
    EXPECT_EQ("read_after_write_a", value, 0xa5a5a5a5u);

    value = cache_b;
    EXPECT_EQ("initial_b", value, 0x22222222u);
    cache_b = 0x5a5a5a5au;
    value = cache_b;
    EXPECT_EQ("read_after_write_b", value, 0x5a5a5a5au);

    value = cache_c;
    EXPECT_EQ("initial_c", value, 0x33333333u);
    value = cache_d;
    EXPECT_EQ("initial_d", value, 0x44444444u);

    /* C and D force dirty A and B out of the two ways. */
    value = cache_a;
    EXPECT_EQ("writeback_a", value, 0xa5a5a5a5u);
    value = cache_b;
    EXPECT_EQ("writeback_b", value, 0x5a5a5a5au);

    print_text("CACHE_WORKLOAD_PASS\n");
    sim_exit(0);
    for (;;)
        ;
}