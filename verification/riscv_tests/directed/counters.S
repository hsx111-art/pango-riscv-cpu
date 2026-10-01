#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  # Machine cycle counter and read-only cycle aliases.
  li t0, 0x12345
  csrw mcycle, t0
  csrr t1, mcycle
  bltu t1, t0, fail
  csrr t2, cycle
  bltu t2, t1, fail

  li t0, 0x23456
  csrw mcycleh, t0
  csrr t1, mcycleh
  bne t0, t1, fail
  csrr t1, cycleh
  bne t0, t1, fail

  # minstret writes suppress the implicit increment of the writing CSR.
  li t0, 0x100
  csrw minstret, t0
  csrr t1, minstret
  bne t0, t1, fail
  csrr t2, instret
  bltu t2, t1, fail

  li t0, 0x2
  csrw minstreth, t0
  csrr t1, minstreth
  bne t0, t1, fail
  csrr t1, instreth
  bne t0, t1, fail

  # A normal instruction must advance the architectural retired count.
  csrr t1, minstret
  addi t2, x0, 0
  csrr t3, minstret
  bltu t3, t1, fail

  li TESTNUM, 1
  TEST_PASSFAIL

.align 2
.global mtvec_handler
mtvec_handler:
  j fail

RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
TEST_DATA
RVTEST_DATA_END