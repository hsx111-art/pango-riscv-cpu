#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TB_DIR="$ROOT_DIR/top_tcm_axi/tb"

SYSTEMC_HOME="${SYSTEMC_HOME:-/usr}"
VERILATOR_SRC="${VERILATOR_SRC:-/usr/share/verilator/include}"
LIB_OPT="${LIB_OPT:-/usr/lib/x86_64-linux-gnu/libsystemc.so}"
TEST_IMAGE="${TEST_IMAGE:-$ROOT_DIR/isa_sim/images/basic.elf}"
VERILATE_PARAMS="${VERILATE_PARAMS:---trace}"
if [[ "${ENABLE_BRANCH_PREDICTOR:-0}" == "1" ]]; then
    VERILATE_PARAMS="${VERILATE_PARAMS} -GENABLE_BRANCH_PREDICTOR=1"
fi

echo "WSL baseline root: $ROOT_DIR"
echo "SystemC: $SYSTEMC_HOME"
echo "Verilator headers: $VERILATOR_SRC"
echo "Test image: $TEST_IMAGE"

env -u NAME -u SRC make -C "$ROOT_DIR/isa_sim" clean
env -u NAME -u SRC make -C "$ROOT_DIR/isa_sim" -j2

pushd "$TB_DIR" >/dev/null
env -u NAME -u SRC make -f makefile.generate_verilated CORE=riscv NAME=riscv_tcm_top SRC=riscv_tcm_top clean
env -u NAME -u SRC make -f makefile.generate_verilated CORE=riscv NAME=riscv_tcm_top SRC=riscv_tcm_top VERILATE_PARAMS="$VERILATE_PARAMS"
env -u NAME -u SRC make -f makefile.build_verilated clean
env -u NAME -u SRC make -f makefile.build_verilated -j2 \
    SYSTEMC_HOME="$SYSTEMC_HOME" \
    VERILATOR_SRC="$VERILATOR_SRC" \
    LIB_OPT="$LIB_OPT"
env -u NAME -u SRC make -f makefile.build_sysc_tb clean
env -u NAME -u SRC make -f makefile.build_sysc_tb -j2 \
    SYSTEMC_HOME="$SYSTEMC_HOME" \
    VERILATOR_SRC="$VERILATOR_SRC"

set +e
output=$(env -u NAME ENABLE_WAVES=no ./build/test.x -f "$TEST_IMAGE" 2>&1)
status=$?
set -e
printf '%s\n' "$output"

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
    echo "BASELINE_A_FAIL"
    exit 1
fi

for expected in "${expected_tests[@]}"; do
    if ! grep -Fq "$expected" <<<"$output"; then
        echo "BASELINE_A_FAIL: missing test output: $expected"
        exit 1
    fi
done

echo "BASELINE_A_PASS"
popd >/dev/null
