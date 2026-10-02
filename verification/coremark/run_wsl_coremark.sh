#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${COREMARK_OUT:-$ROOT_DIR/.build/coremark}"
ITERATIONS="${ITERATIONS:-1}"
TOTAL_DATA_SIZE="${TOTAL_DATA_SIZE:-2000}"
CLOCK_HZ="${CLOCK_HZ:-1000000}"
RUN_TYPE="${RUN_TYPE:-validation}"
TEST_TIMEOUT_SEC="${TEST_TIMEOUT_SEC:-120}"
ENABLE_BRANCH_PREDICTOR="${ENABLE_BRANCH_PREDICTOR:-0}"
ENABLE_BRANCH_PREDICTOR_REDIRECT="${ENABLE_BRANCH_PREDICTOR_REDIRECT:-0}"

export PATH="${RISCV_TOOLCHAIN_BIN:-$HOME/.local/riscv-tools/usr/bin}:$PATH"

required=(riscv64-unknown-elf-gcc riscv64-unknown-elf-objdump riscv64-unknown-elf-readelf)
for tool in "${required[@]}"; do
    command -v "$tool" >/dev/null || {
        echo "COREMARK_INFRA_FAIL: missing $tool" >&2
        exit 2
    }
done

make -C "$ROOT_DIR/verification/coremark" clean
make -C "$ROOT_DIR/verification/coremark" \
    OUT="$OUT_DIR" ITERATIONS="$ITERATIONS" TOTAL_DATA_SIZE="$TOTAL_DATA_SIZE" \
    CLOCK_HZ="$CLOCK_HZ" RUN_TYPE="$RUN_TYPE"
echo "COREMARK_WSL_CONFIG predictor=$ENABLE_BRANCH_PREDICTOR redirect=$ENABLE_BRANCH_PREDICTOR_REDIRECT"

pushd "$ROOT_DIR/top_tcm_axi/tb" >/dev/null
env -u NAME -u SRC make -f makefile.generate_verilated CORE=riscv NAME=riscv_tcm_top SRC=riscv_tcm_top clean
VERILATE_PARAMS="--trace"
if [[ "$ENABLE_BRANCH_PREDICTOR" == "1" ]]; then
    VERILATE_PARAMS="$VERILATE_PARAMS -GENABLE_BRANCH_PREDICTOR=1"
fi
if [[ "$ENABLE_BRANCH_PREDICTOR_REDIRECT" == "1" ]]; then
    VERILATE_PARAMS="$VERILATE_PARAMS -GENABLE_BRANCH_PREDICTOR_REDIRECT=1"
fi
env -u NAME -u SRC make -f makefile.generate_verilated CORE=riscv NAME=riscv_tcm_top SRC=riscv_tcm_top VERILATE_PARAMS="$VERILATE_PARAMS"
env -u NAME -u SRC make -f makefile.build_verilated clean
env -u NAME -u SRC make -f makefile.build_verilated -j2
env -u NAME -u SRC make -f makefile.build_sysc_tb clean
env -u NAME -u SRC make -f makefile.build_sysc_tb -j2

set +e
output=$(timeout --foreground "${TEST_TIMEOUT_SEC}s" \
    env -u NAME ENABLE_WAVES=no ./build/test.x -f "$OUT_DIR/coremark.elf" 2>&1)
status=$?
set -e
popd >/dev/null

printf '%s\n' "$output"

if [[ $status -ne 0 ]]; then
    echo "COREMARK_SMOKE_FAIL: simulator exit code $status" >&2
    exit 1
fi
if [[ "$output" != *"seedcrc"* || "$output" != *"crclist"* ||
      "$output" != *"crcmatrix"* || "$output" != *"crcstate"* ]]; then
    echo "COREMARK_SMOKE_FAIL: CoreMark CRC markers missing" >&2
    exit 1
fi
if [[ "$output" == *"ERROR! list crc"* || "$output" == *"ERROR! matrix crc"* ||
      "$output" == *"ERROR! state crc"* || "$output" == *"PORT_TYPE_ERROR"* ]]; then
    echo "COREMARK_SMOKE_FAIL: CoreMark algorithm or port validation failed" >&2
    exit 1
fi
short_run_notice=false
if [[ "$output" == *"Errors detected"* ]]; then
    if [[ "$output" != *"Must execute for at least 10 secs for a valid result!"* ]]; then
        echo "COREMARK_SMOKE_FAIL: CoreMark reported an unexpected error" >&2
        exit 1
    fi
    short_run_notice=true
fi
if [[ "$output" != *"COREMARK_METRICS"* || "$output" != *"cpi_x1000"* ]]; then
    echo "COREMARK_SMOKE_FAIL: CoreMark architectural metrics marker missing" >&2
    exit 1
fi

validity=reportable
if [[ "$short_run_notice" == true ]]; then
    echo "COREMARK_SMOKE_NOTICE VALIDITY=short-run MIN_SECONDS=10"
    validity=short-run
fi
echo "COREMARK_SMOKE_PASS ITERATIONS=$ITERATIONS TOTAL_DATA_SIZE=$TOTAL_DATA_SIZE RUN_TYPE=$RUN_TYPE VALIDITY=$validity"
