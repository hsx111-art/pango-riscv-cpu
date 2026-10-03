#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TB_DIR="$ROOT_DIR/top_cache_axi/tb"
TEST_IMAGE="${TEST_IMAGE:-$ROOT_DIR/isa_sim/images/basic.elf}"
CACHE_WORKLOAD_OUT="${CACHE_WORKLOAD_OUT:-$ROOT_DIR/.build/cache}"
CACHE_WORKLOAD_IMAGE="${CACHE_WORKLOAD_IMAGE:-$CACHE_WORKLOAD_OUT/cache_workload.elf}"
SYSTEMC_HOME="${SYSTEMC_HOME:-/usr}"
VERILATOR_SRC="${VERILATOR_SRC:-/usr/share/verilator/include}"

export PATH="${RISCV_TOOLCHAIN_BIN:-$HOME/.local/riscv-tools/usr/bin}:$PATH"

for tool in verilator g++ make riscv64-unknown-elf-gcc riscv64-unknown-elf-objdump riscv64-unknown-elf-readelf; do
    command -v "$tool" >/dev/null || {
        echo "CACHE_INFRA_FAIL: missing $tool" >&2
        exit 2
    }
done

make -C "$ROOT_DIR/verification/cache" clean
make -C "$ROOT_DIR/verification/cache" OUT="$CACHE_WORKLOAD_OUT"

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

for metric in CACHE_METRICS icache_line_refills= dcache_line_refills=; do
    if ! grep -Fq "$metric" <<<"$output"; then
        echo "CACHE_WSL_FAIL basic metrics missing=$metric" >&2
        exit 1
    fi
done

echo "CACHE_WSL_PASS image=$TEST_IMAGE tests=${#expected_tests[@]}"

echo "CACHE_WSL_RUN directed image=$CACHE_WORKLOAD_IMAGE"
set +e
workload_output=$(cd "$TB_DIR" && ENABLE_WAVES=no ./build/test.x -f "$CACHE_WORKLOAD_IMAGE" 2>&1)
workload_status=$?
set -e
printf '%s\n' "$workload_output"

if [[ $workload_status -ne 0 ]]; then
    echo "CACHE_WSL_FAIL directed status=$workload_status" >&2
    exit 1
fi
for marker in "CACHE_WORKLOAD_PASS" "CACHE_METRICS"; do
    if ! grep -Fq "$marker" <<<"$workload_output"; then
        echo "CACHE_WSL_FAIL directed missing=$marker" >&2
        exit 1
    fi
done

metric_value() {
    local line="$1"
    local name="$2"
    printf '%s\n' "$line" | grep -o "${name}=[0-9][0-9]*" | tail -n 1 | cut -d= -f2
}

assert_metric_ge() {
    local line="$1"
    local name="$2"
    local minimum="$3"
    local value
    value=$(metric_value "$line" "$name")
    if [[ -z "$value" || "$value" -lt "$minimum" ]]; then
        echo "CACHE_WSL_FAIL metric=$name value=${value:-missing} minimum=$minimum" >&2
        exit 1
    fi
}

assert_metric_ge "$workload_output" icache_line_refills 1
assert_metric_ge "$workload_output" dcache_line_refills 1
assert_metric_ge "$workload_output" dcache_line_writebacks 2
assert_metric_ge "$workload_output" dcache_write_beats 16

echo "CACHE_WSL_DIRECTED_PASS image=$CACHE_WORKLOAD_IMAGE"
