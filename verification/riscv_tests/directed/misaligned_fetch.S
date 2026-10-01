#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la t0, misaligned_target
  addi t0, t0, 2
  li TESTNUM, 1
  jalr zero, t0, 0
after_jalr:
  li t1, 1
  bne TESTNUM, t1, fail
  TEST_PASSFAIL

.align 2
misaligned_target:
  nop

.global mtvec_handler
mtvec_handler:
  li t0, CAUSE_MISALIGNED_FETCH
  csrr t1, mcause
  bne t0, t1, fail
  la t0, after_jalr
  csrw mepc, t0
  mret

RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
TEST_DATA
RVTEST_DATA_END
