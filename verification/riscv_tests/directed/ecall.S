#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la t0, mtvec_handler
  csrw mtvec, t0
  li TESTNUM, 1
  ecall
  li t0, 1
  bne TESTNUM, t0, fail
  TEST_PASSFAIL

.align 2
.global mtvec_handler
mtvec_handler:
  li t0, CAUSE_MACHINE_ECALL
  csrr t1, mcause
  bne t0, t1, fail
  csrr t0, mtval
  bnez t0, fail
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
TEST_DATA
RVTEST_DATA_END
