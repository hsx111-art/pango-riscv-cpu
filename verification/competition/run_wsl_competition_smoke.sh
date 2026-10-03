#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${COMPETITION_VERILATOR_OUT:-$ROOT_DIR/.build/competition-verilator}"
TIMEOUT_SEC="${COMPETITION_TIMEOUT_SEC:-120}"

export PATH="${RISCV_TOOLCHAIN_BIN:-$HOME/.local/riscv-tools/usr/bin}:$PATH"

for tool in riscv64-unknown-elf-gcc python3 verilator g++ make timeout; do
    command -v "$tool" >/dev/null || {
        echo "COMPETITION_INFRA_FAIL: missing $tool" >&2
        exit 2
    }
done

make -C "$ROOT_DIR/verification/competition" clean all

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

python3 "$ROOT_DIR/verification/modelsim/elf_to_memh.py" \
    --elf "$ROOT_DIR/.build/competition/competition_smoke.elf" \
    --output "$OUT_DIR/competition.memh" \
    --ram-words 16384

verilator \
    --binary \
    --timing \
    --Wno-fatal \
    --top-module tb_competition \
    -I"$ROOT_DIR/core/riscv" \
    "$ROOT_DIR"/core/riscv/*.v \
    "$ROOT_DIR"/top_tcm_axi/src_v/*.v \
    "$ROOT_DIR/competition/competition_peripherals.v" \
    "$ROOT_DIR/competition/competition_top.v" \
    "$ROOT_DIR/verification/modelsim/tb_competition.v" \
    --Mdir "$OUT_DIR" \
    -o competition_sim

pushd "$OUT_DIR" >/dev/null
set +e
output=$(timeout --foreground "${TIMEOUT_SEC}s" ./competition_sim 2>&1)
status=$?
set -e
popd >/dev/null

printf '%s\n' "$output"

if [[ $status -ne 0 || "$output" != *"COMPETITION_TCM_PASS"* ||
      "$output" == *"COMPETITION_FAIL"* ]]; then
    echo "COMPETITION_WSL_VERILATOR_FAIL status=$status" >&2
    exit 1
fi

echo "COMPETITION_WSL_VERILATOR_PASS"
