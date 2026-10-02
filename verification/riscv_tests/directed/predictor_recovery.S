#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  # Use a private handler so an illegal instruction on either speculative
  # path is an observable test failure instead of an unbounded default trap.
  la t0, predictor_trap_handler
  csrw mtvec, t0

  la t0, predictor_side_effect
  sw zero, 0(t0)
  csrw mscratch, zero

  # The first visit is taken. The reset BHT state predicts not-taken.
  li s0, 0
branch_site:
  beq s0, zero, taken_target

  # This is the fall-through path on the first visit and the architecturally
  # correct path on the second visit. The side effects must never execute on
  # the first visit when predicted-not-taken recovery is active.
  bnez s0, second_fallthrough
wrong_not_taken_path:
  li t1, 0x13579bdf
  sw t1, 0(t0)
  csrw mscratch, t1
  .word 0xffffffff

second_fallthrough:
  li t1, 1
  bne s0, t1, fail
  lw t1, 0(t0)
  bnez t1, fail
  csrr t1, mscratch
  bnez t1, fail
  li TESTNUM, 1
  TEST_PASSFAIL

taken_target:
  # First visit sets up a second visit to the same branch PC. The predictor
  # then learns taken, so the second visit is predicted-taken but resolves
  # not-taken. Its predicted target must be discarded before these side
  # effects can execute.
  bnez s0, wrong_taken_path
  li s0, 1
  jal zero, branch_site

wrong_taken_path:
  li t1, 0x2468ace0
  sw t1, 0(t0)
  csrw mscratch, t1
  .word 0xffffffff

predictor_trap_handler:
  j fail

RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
predictor_side_effect:
  .word 0
TEST_DATA
RVTEST_DATA_END
