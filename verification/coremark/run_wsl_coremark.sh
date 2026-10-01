#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${COREMARK_OUT:-$ROOT_DIR/.build/coremark}"
ITERATIONS="${ITERATIONS:-1}"
TOTAL_DATA_SIZE="${TOTAL_DATA_SIZE:-2000}"
CLOCK_HZ="${CLOCK_HZ:-1000000}"
RUN_TYPE="${RUN_TYPE:-validation}"
TEST_TIMEOUT_SEC="${TEST_TIMEOUT_SEC:-120}"

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

pushd "$ROOT_DIR/top_tcm_axi/tb" >/dev/null
if [[ ! -x build/test.x ]]; then
    bash "$ROOT_DIR/verification/wsl_baseline.sh" >/dev/null
fi

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
if [[ "$output" != *"COREMARK_METRICS"* || "$output" != *"cpi_x1000"* ]]; then
    echo "COREMARK_SMOKE_FAIL: CoreMark architectural metrics marker missing" >&2
    exit 1
fi

echo "COREMARK_SMOKE_PASS ITERATIONS=$ITERATIONS TOTAL_DATA_SIZE=$TOTAL_DATA_SIZE RUN_TYPE=$RUN_TYPE"
