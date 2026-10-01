#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la t0, data_word
  addi t0, t0, 1
  li TESTNUM, 1
  lw t1, 0(t0)
  li t2, 1
  bne TESTNUM, t2, fail
  TEST_PASSFAIL

.align 2
.global mtvec_handler
mtvec_handler:
  li t3, CAUSE_MISALIGNED_LOAD
  csrr t4, mcause
  bne t3, t4, fail
  csrr t3, mtval
  bne t3, t0, fail
  csrr t3, mepc
  addi t3, t3, 4
  csrw mepc, t3
  mret

RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
data_word:
  .word 0x12345678
TEST_DATA
RVTEST_DATA_END
