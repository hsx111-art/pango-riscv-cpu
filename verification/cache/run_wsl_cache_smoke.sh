#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TB_DIR="$ROOT_DIR/top_cache_axi/tb"
TEST_IMAGE="${TEST_IMAGE:-$ROOT_DIR/isa_sim/images/basic.elf}"
SYSTEMC_HOME="${SYSTEMC_HOME:-/usr}"
VERILATOR_SRC="${VERILATOR_SRC:-/usr/share/verilator/include}"

export PATH="${RISCV_TOOLCHAIN_BIN:-$HOME/.local/riscv-tools/usr/bin}:$PATH"

for tool in verilator g++ make; do
    command -v "$tool" >/dev/null || {
        echo "CACHE_INFRA_FAIL: missing $tool" >&2
        exit 2
    }
done

pushd "$TB_DIR" >/dev/null
env -u NAME -u SRC -u CORE make -f makefile.generate_verilated \
    CORE=riscv NAME=riscv_top SRC=riscv_top clean
env -u NAME -u SRC -u CORE make -f makefile.generate_verilated \
    CORE=riscv NAME=riscv_top SRC=riscv_top VERILATE_PARAMS="--trace"

env -u NAME -u SRC -u CORE make -f makefile.build_verilated clean
env -u NAME -u SRC -u CORE make -f makefile.build_verilated -j2 \
    SYSTEMC_HOME="$SYSTEMC_HOME" VERILATOR_SRC="$VERILATOR_SRC"

env -u NAME -u SRC -u CORE make -f makefile.build_sysc_tb clean
env -u NAME -u SRC -u CORE make -f makefile.build_sysc_tb -j2 \
    SYSTEMC_HOME="$SYSTEMC_HOME" VERILATOR_SRC="$VERILATOR_SRC"

set +e
output=$(ENABLE_WAVES=no ./build/test.x -f "$TEST_IMAGE" 2>&1)
status=$?
set -e
printf '%s\n' "$output"
popd >/dev/null

expected_tests=(
    "1. Initialised data"
    "2. Multiply"
    "3. Divide"
    "4. Shift left"
    "5. Shift right"
    "6. Shift right arithmetic"
    "7. Signed comparision"
    "8. Word access"
    "9. Byte access"
    "10. Comparision"
)

if [[ $status -ne 0 || "$output" == *"TEST FAILED"* ]]; then
    echo "CACHE_WSL_FAIL status=$status" >&2
    exit 1
fi

for expected in "${expected_tests[@]}"; do
    if ! grep -Fq "$expected" <<<"$output"; then
        echo "CACHE_WSL_FAIL missing=$expected" >&2
        exit 1
    fi
done

echo "CACHE_WSL_PASS image=$TEST_IMAGE tests=${#expected_tests[@]}"
