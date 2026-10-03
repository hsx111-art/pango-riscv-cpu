#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COREMARK_OUT="${COREMARK_UART_OUT:-$ROOT_DIR/.build/coremark-uart-smoke}"
SIM_OUT="${COREMARK_UART_SIM_OUT:-$ROOT_DIR/.build/coremark-uart-verilator}"
TIMEOUT_SEC="${COREMARK_UART_TIMEOUT_SEC:-600}"

export PATH="${RISCV_TOOLCHAIN_BIN:-$HOME/.local/riscv-tools/usr/bin}:$PATH"

for tool in riscv64-unknown-elf-gcc python3 verilator g++ make timeout; do
    command -v "$tool" >/dev/null || {
        echo "COREMARK_UART_INFRA_FAIL: missing $tool" >&2
        exit 2
    }
done

make -C "$ROOT_DIR/verification/coremark" clean OUT="$COREMARK_OUT"
make -C "$ROOT_DIR/verification/coremark" \
    OUT="$COREMARK_OUT" ITERATIONS=1 RUN_TYPE=validation CLOCK_HZ=1000000 \
    OUTPUT_DEVICE=competition-uart

rm -rf "$SIM_OUT"
mkdir -p "$SIM_OUT"
python3 "$ROOT_DIR/verification/modelsim/elf_to_memh.py" \
    --elf "$COREMARK_OUT/coremark.elf" \
    --output "$SIM_OUT/competition.memh" \
    --ram-words 16384

verilator \
    --binary --timing --Wno-fatal --top-module tb_competition \
    -I"$ROOT_DIR/core/riscv" \
    "$ROOT_DIR"/core/riscv/*.v \
    "$ROOT_DIR"/top_tcm_axi/src_v/*.v \
    "$ROOT_DIR/competition/competition_peripherals.v" \
    "$ROOT_DIR/competition/competition_top.v" \
    "$ROOT_DIR/verification/modelsim/tb_competition.v" \
    --Mdir "$SIM_OUT" -o coremark_uart_sim

pushd "$SIM_OUT" >/dev/null
set +e
output=$(timeout --foreground "${TIMEOUT_SEC}s" ./coremark_uart_sim +COREMARK_MODE 2>&1)
status=$?
set -e
popd >/dev/null
printf '%s\n' "$output"

if [[ $status -ne 0 || "$output" != *"COREMARK_UART_PASS"* ||
      "$output" != *"seedcrc          : 0x18f2"* ||
      "$output" != *"[0]crclist       : 0xe3c1"* ||
      "$output" != *"[0]crcmatrix     : 0x0747"* ||
      "$output" != *"[0]crcstate      : 0x8d84"* ||
      "$output" != *"[0]crcfinal      : 0xe3c1"* ||
      "$output" == *"ERROR! list crc"* ||
      "$output" == *"ERROR! matrix crc"* ||
      "$output" == *"ERROR! state crc"* ||
      "$output" == *"PORT_TYPE_ERROR"* ]]; then
    echo "COREMARK_UART_SMOKE_FAIL status=$status" >&2
    exit 1
fi

echo "COREMARK_UART_SMOKE_PASS ITERATIONS=1 VALIDITY=short-run"
