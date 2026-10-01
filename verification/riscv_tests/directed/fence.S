#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  fence rw, rw
  addi a0, zero, 1
  bne a0, TESTNUM, fail
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
