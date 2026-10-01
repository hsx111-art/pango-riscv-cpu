#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li s0, 0
  csrr t0, mcycle
  addi t0, t0, 1024
  csrw 0x7c0, t0
  li t0, (1 << IRQ_M_TIMER)
  csrw mie, t0
  li t0, MSTATUS_MIE
  csrs mstatus, t0
1:
  addi s1, s1, 1
  beqz s0, 1b
  li t0, 1
  bne s0, t0, fail
  li TESTNUM, 1
  TEST_PASSFAIL

.align 2
.global mtvec_handler
mtvec_handler:
  li t0, 0x80000007
  csrr t1, mcause
  bne t0, t1, fail
  csrr t0, mtval
  bnez t0, fail
  csrwi mip, 0
  li s0, 1
  mret

RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
TEST_DATA
RVTEST_DATA_END
