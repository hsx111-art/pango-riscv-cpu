#include <stdint.h>

#ifndef AI_REPEAT
#define AI_REPEAT 16
#endif

#define CSR_DSCRATCH 0x7b2

static volatile int8_t dot_a[64];
static volatile int8_t dot_b[64];
static volatile int8_t gemm_a[64];
static volatile int8_t gemm_b[64];
static volatile int32_t gemm_c[64];
static volatile int8_t conv_input[100];
static volatile int8_t conv_kernel[9];
static volatile int32_t conv_output[64];
static volatile int8_t relu_input[64];
static volatile int8_t relu_output[64];
static volatile int32_t ai_sink;

static inline uint32_t read_mcycle(void)
{
    uint32_t value;
    asm volatile ("csrr %0, mcycle" : "=r"(value));
    return value;
}

static inline uint32_t read_minstret(void)
{
    uint32_t value;
    asm volatile ("csrr %0, minstret" : "=r"(value));
    return value;
}

static inline void sim_putc(char value)
{
    uint32_t command = 0x01000000u | (uint8_t)value;
    asm volatile ("csrw dscratch, %0" : : "r"(command));
}

static inline void sim_exit(uint32_t code)
{
    register uint32_t value asm("t0") = code;
    asm volatile ("csrw dscratch, %0" : : "r"(value));
}

static void print_text(const char *text)
{
    while (*text)
        sim_putc(*text++);
}

static void print_u32(uint32_t value)
{
    char buffer[10];
    unsigned length = 0;

    if (value == 0) {
        sim_putc('0');
        return;
    }

    while (value != 0) {
        buffer[length++] = (char)('0' + (value % 10));
        value /= 10;
    }
    while (length != 0)
        sim_putc(buffer[--length]);
}

static void report_metric(const char *name,
                          uint32_t start_cycle,
                          uint32_t end_cycle,
                          uint32_t start_retired,
                          uint32_t end_retired,
                          int32_t checksum)
{
    uint32_t cycles = end_cycle - start_cycle;
    uint32_t retired = end_retired - start_retired;
    uint32_t cpi_x1000 = retired ? (cycles * 1000u) / retired : 0;

    print_text("AI_METRICS workload=");
    print_text(name);
    print_text(" cycles=");
    print_u32(cycles);
    print_text(" retired=");
    print_u32(retired);
    print_text(" cpi_x1000=");
    print_u32(cpi_x1000);
    print_text(" checksum=");
    print_u32((uint32_t)checksum);
    print_text("\n");
}

static void init_data(void)
{
    unsigned i;

    for (i = 0; i < 64; i++) {
        dot_a[i] = (int8_t)((i % 17) - 8);
        dot_b[i] = (int8_t)(((i * 3) % 19) - 9);
        gemm_a[i] = (int8_t)((i % 11) - 5);
        gemm_b[i] = (int8_t)(((i * 5) % 13) - 6);
        relu_input[i] = (int8_t)((i & 1) ? ((i % 23) - 11) : (11 - (i % 23)));
        relu_output[i] = 0;
        gemm_c[i] = 0;
        conv_output[i] = 0;
    }
    for (i = 0; i < 100; i++)
        conv_input[i] = (int8_t)((i % 7) - 3);
    for (i = 0; i < 9; i++)
        conv_kernel[i] = (int8_t)(((i * 2) % 5) - 2);
}

static int32_t run_dot_i8(void)
{
    int32_t acc = 0;
    unsigned repeat;
    unsigned i;

    for (repeat = 0; repeat < AI_REPEAT; repeat++)
        for (i = 0; i < 64; i++)
            acc += (int32_t)dot_a[i] * (int32_t)dot_b[i];
    ai_sink = acc;
    return acc;
}

static int32_t run_gemm_i8(void)
{
    int32_t checksum = 0;
    unsigned repeat;
    unsigned row;
    unsigned col;
    unsigned k;

    for (repeat = 0; repeat < AI_REPEAT; repeat++) {
        for (row = 0; row < 8; row++) {
            for (col = 0; col < 8; col++) {
                int32_t acc = 0;
                for (k = 0; k < 8; k++)
                    acc += (int32_t)gemm_a[row * 8 + k] *
                           (int32_t)gemm_b[k * 8 + col];
                gemm_c[row * 8 + col] = acc;
            }
        }
    }
    for (row = 0; row < 64; row++)
        checksum += gemm_c[row];
    ai_sink = checksum;
    return checksum;
}

static int32_t run_conv_i8(void)
{
    int32_t checksum = 0;
    unsigned repeat;
    unsigned row;
    unsigned col;
    unsigned kr;
    unsigned kc;

    for (repeat = 0; repeat < AI_REPEAT; repeat++) {
        for (row = 0; row < 8; row++) {
            for (col = 0; col < 8; col++) {
                int32_t acc = 0;
                for (kr = 0; kr < 3; kr++)
                    for (kc = 0; kc < 3; kc++)
                        acc += (int32_t)conv_input[(row + kr) * 10 + col + kc] *
                               (int32_t)conv_kernel[kr * 3 + kc];
                conv_output[row * 8 + col] = acc;
            }
        }
    }
    for (row = 0; row < 64; row++)
        checksum += conv_output[row];
    ai_sink = checksum;
    return checksum;
}

static int32_t run_relu_i8(void)
{
    int32_t checksum = 0;
    unsigned repeat;
    unsigned i;

    for (repeat = 0; repeat < AI_REPEAT; repeat++) {
        for (i = 0; i < 64; i++) {
            int32_t value = ((int32_t)relu_input[i] * 7 + 3) >> 3;
            if (value < 0)
                value = 0;
            if (value > 127)
                value = 127;
            relu_output[i] = (int8_t)value;
        }
    }
    for (i = 0; i < 64; i++)
        checksum += relu_output[i];
    ai_sink = checksum;
    return checksum;
}

int main(void)
{
    uint32_t start_cycle;
    uint32_t end_cycle;
    uint32_t start_retired;
    uint32_t end_retired;
    int32_t checksum;
    int pass = 1;

    init_data();

#if defined(WORKLOAD_DOT_I8)
    start_cycle = read_mcycle();
    start_retired = read_minstret();
    checksum = run_dot_i8();
    end_retired = read_minstret();
    end_cycle = read_mcycle();
    report_metric("dot_i8", start_cycle, end_cycle, start_retired, end_retired, checksum);
    if (checksum != 4656)
        pass = 0;
#elif defined(WORKLOAD_GEMM_I8)
    start_cycle = read_mcycle();
    start_retired = read_minstret();
    checksum = run_gemm_i8();
    end_retired = read_minstret();
    end_cycle = read_mcycle();
    report_metric("gemm_i8", start_cycle, end_cycle, start_retired, end_retired, checksum);
    if (checksum != 49)
        pass = 0;
#elif defined(WORKLOAD_CONV_I8)
    start_cycle = read_mcycle();
    start_retired = read_minstret();
    checksum = run_conv_i8();
    end_retired = read_minstret();
    end_cycle = read_mcycle();
    report_metric("conv_i8", start_cycle, end_cycle, start_retired, end_retired, checksum);
    if (checksum != -3)
        pass = 0;
#elif defined(WORKLOAD_RELU_I8)
    start_cycle = read_mcycle();
    start_retired = read_minstret();
    checksum = run_relu_i8();
    end_retired = read_minstret();
    end_cycle = read_mcycle();
    report_metric("relu_i8", start_cycle, end_cycle, start_retired, end_retired, checksum);
    if (checksum != 158)
        pass = 0;
#else
    pass = 0;
#endif

    if (pass) {
        print_text("AI_PASS\n");
        sim_putc('P');
        sim_exit(0);
    }

    print_text("AI_FAIL\n");
    sim_putc('F');
    sim_exit(1);
    return 1;
}
