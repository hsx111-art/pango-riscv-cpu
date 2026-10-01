#include "coremark.h"
#include "core_portme.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#elif PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#else
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

static CORE_TICKS start_time_val;
static CORE_TICKS stop_time_val;
static CORE_TICKS start_instret_val;
static CORE_TICKS stop_instret_val;

static CORE_TICKS read_mcycle(void)
{
    CORE_TICKS value;
    asm volatile ("csrr %0, mcycle" : "=r"(value));
    return value;
}

static CORE_TICKS read_minstret(void)
{
    CORE_TICKS value;
    asm volatile ("csrr %0, minstret" : "=r"(value));
    return value;
}

void start_time(void)
{
    start_time_val = read_mcycle();
    start_instret_val = read_minstret();
}

void stop_time(void)
{
    stop_time_val = read_mcycle();
    stop_instret_val = read_minstret();
}

CORE_TICKS get_time(void)
{
    return stop_time_val - start_time_val;
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
    return ticks / COREMARK_TICKS_PER_SEC;
}

ee_u32 default_num_contexts = 1;

void portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    if (sizeof(ee_u8) != 1 || sizeof(ee_u16) != 2 || sizeof(ee_u32) != 4 ||
        sizeof(ee_ptr_int) != sizeof(void *)) {
        ee_printf("PORT_TYPE_ERROR\n");
    }
    p->portable_id = 1;
}

void portable_fini(core_portable *p)
{
    CORE_TICKS cycles = stop_time_val - start_time_val;
    CORE_TICKS retired = stop_instret_val - start_instret_val;
    ee_printf("COREMARK_METRICS cycles=%u retired=%u cpi_x1000=%u\n",
              cycles,
              retired,
              retired ? (cycles * 1000u) / retired : 0u);
    p->portable_id = 0;
}
