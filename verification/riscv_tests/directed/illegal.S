#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  .word 0xffffffff
  li t0, 1
  bne TESTNUM, t0, fail
  TEST_PASSFAIL

.align 2
.global mtvec_handler
mtvec_handler:
  li t0, CAUSE_ILLEGAL_INSTRUCTION
  csrr t1, mcause
  bne t0, t1, fail
  li t0, -1
  csrr t1, mtval
  bne t0, t1, fail
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
TEST_DATA
RVTEST_DATA_END
