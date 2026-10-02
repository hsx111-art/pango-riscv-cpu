#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${AI_MICROBENCH_OUT:-$ROOT_DIR/.build/ai_microbench}"
AI_REPEAT="${AI_REPEAT:-16}"
TEST_TIMEOUT_SEC="${TEST_TIMEOUT_SEC:-120}"
SYSTEMC_HOME="${SYSTEMC_HOME:-/usr}"
VERILATOR_SRC="${VERILATOR_SRC:-/usr/share/verilator/include}"
LIB_OPT="${LIB_OPT:-/usr/lib/x86_64-linux-gnu/libsystemc.so}"
ENABLE_BRANCH_PREDICTOR="${ENABLE_BRANCH_PREDICTOR:-0}"
ENABLE_BRANCH_PREDICTOR_REDIRECT="${ENABLE_BRANCH_PREDICTOR_REDIRECT:-0}"
VERILATE_PARAMS="${VERILATE_PARAMS:---trace}"
if [[ "$ENABLE_BRANCH_PREDICTOR" == "1" ]]; then
    VERILATE_PARAMS="$VERILATE_PARAMS -GENABLE_BRANCH_PREDICTOR=1"
fi
if [[ "$ENABLE_BRANCH_PREDICTOR_REDIRECT" == "1" ]]; then
    VERILATE_PARAMS="$VERILATE_PARAMS -GENABLE_BRANCH_PREDICTOR_REDIRECT=1"
fi

export PATH="${RISCV_TOOLCHAIN_BIN:-$HOME/.local/riscv-tools/usr/bin}:$PATH"

make -C "$ROOT_DIR/verification/ai_microbench" clean
make -C "$ROOT_DIR/verification/ai_microbench" \
    OUT="$OUT_DIR" AI_REPEAT="$AI_REPEAT" -j2
echo "WSL_AI_CONFIG predictor=$ENABLE_BRANCH_PREDICTOR redirect=$ENABLE_BRANCH_PREDICTOR_REDIRECT"

pushd "$ROOT_DIR/top_tcm_axi/tb" >/dev/null
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

for workload in dot_i8 gemm_i8 conv_i8 relu_i8; do
    image="$OUT_DIR/$workload.elf"
    echo "WSL_AI_RUN $workload"
    set +e
    output=$(timeout --foreground "${TEST_TIMEOUT_SEC}s" \
        env -u NAME ENABLE_WAVES=no ./build/test.x -f "$image" 2>&1)
    status=$?
    set -e
    printf '%s\n' "$output"

    if [[ $status -ne 0 || "$output" != *"AI_PASS"* ||
          "$output" != *"AI_METRICS workload=$workload"* ||
          "$output" != *"WSL_METRICS"* ||
          "$output" != *"WSL_PROFILE"* ||
          "$output" != *"WSL_WORKLOAD_PROFILE"* ||
          "$output" == *"WSL_WORKLOAD_PROFILE_MISSING"* ]]; then
        echo "WSL_AI_FAIL $workload"
        exit 1
    fi
    echo "WSL_AI_PASS $workload"
done

popd >/dev/null
echo "WSL_AI_REGRESSION_PASS AI_REPEAT=$AI_REPEAT"
