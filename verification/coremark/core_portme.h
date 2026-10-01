/* RV32IM TCM port for the pinned CoreMark source. */
#ifndef ULTRAEMBEDDED_CORE_PORTME_H
#define ULTRAEMBEDDED_CORE_PORTME_H

#include <stddef.h>

#define HAS_FLOAT 0
#define HAS_TIME_H 0
#define USE_CLOCK 0
#define HAS_STDIO 0
#define HAS_PRINTF 0

#ifndef COREMARK_CLOCK_HZ
#define COREMARK_CLOCK_HZ 1000000u
#endif
#define COREMARK_TICKS_PER_SEC COREMARK_CLOCK_HZ
typedef unsigned int CORE_TICKS;
typedef unsigned int secs_ret;

typedef signed short ee_s16;
typedef unsigned short ee_u16;
typedef signed int ee_s32;
typedef unsigned char ee_u8;
typedef unsigned int ee_u32;
typedef ee_u32 ee_ptr_int;
typedef size_t ee_size_t;
typedef double ee_f32;

#define align_mem(x) (void *)(4 + (((ee_ptr_int)(x)-1) & ~3))

#define SEED_VOLATILE 2
#define SEED_METHOD SEED_VOLATILE

#define MEM_STATIC 0
#define MEM_MALLOC 1
#define MEM_STACK 2
#define MEM_METHOD MEM_STATIC

#define MULTITHREAD 1
#define USE_PTHREAD 0
#define USE_FORK 0
#define USE_SOCKET 0
#define MAIN_HAS_NOARGC 1
#define MAIN_HAS_NORETURN 0

#define COMPILER_VERSION "riscv64-unknown-elf-gcc RV32IM"
#define COMPILER_FLAGS "-march=rv32im_zicsr_zifencei -mabi=ilp32 -O2 -mno-relax"
#define MEM_LOCATION "TCM"

extern ee_u32 default_num_contexts;

typedef struct CORE_PORTABLE_S {
    ee_u8 portable_id;
} core_portable;

void portable_init(core_portable *p, int *argc, char *argv[]);
void portable_fini(core_portable *p);

void start_time(void);
void stop_time(void);
CORE_TICKS get_time(void);
secs_ret time_in_secs(CORE_TICKS ticks);

int ee_printf(const char *fmt, ...);

#if !defined(PROFILE_RUN) && !defined(PERFORMANCE_RUN) && !defined(VALIDATION_RUN)
#if (TOTAL_DATA_SIZE == 1200)
#define PROFILE_RUN 1
#elif (TOTAL_DATA_SIZE == 2000)
#define PERFORMANCE_RUN 1
#else
#define VALIDATION_RUN 1
#endif
#endif

#endif
