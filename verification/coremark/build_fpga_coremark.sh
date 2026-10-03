#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${COREMARK_FPGA_OUT:-$ROOT_DIR/.build/coremark-fpga}"
ITERATIONS="${ITERATIONS:-1000}"
CLOCK_HZ="${CLOCK_HZ:-50000000}"
TOTAL_DATA_SIZE="${TOTAL_DATA_SIZE:-2000}"

export PATH="${RISCV_TOOLCHAIN_BIN:-$HOME/.local/riscv-tools/usr/bin}:$PATH"

for tool in riscv64-unknown-elf-gcc riscv64-unknown-elf-objdump \
            riscv64-unknown-elf-readelf python3; do
    command -v "$tool" >/dev/null || {
        echo "COREMARK_FPGA_BUILD_FAIL: missing $tool" >&2
        exit 2
    }
done

make -C "$ROOT_DIR/verification/coremark" clean OUT="$OUT_DIR"
make -C "$ROOT_DIR/verification/coremark" \
    OUT="$OUT_DIR" \
    ITERATIONS="$ITERATIONS" \
    TOTAL_DATA_SIZE="$TOTAL_DATA_SIZE" \
    CLOCK_HZ="$CLOCK_HZ" \
    RUN_TYPE=performance \
    OUTPUT_DEVICE=competition-uart \
    all info

python3 "$ROOT_DIR/verification/modelsim/elf_to_memh.py" \
    --elf "$OUT_DIR/coremark.elf" \
    --output "$OUT_DIR/coremark.memh" \
    --ram-words 16384

cat >"$OUT_DIR/build-config.txt" <<EOF
commit=$(git -C "$ROOT_DIR" rev-parse HEAD)
iterations=$ITERATIONS
total_data_size=$TOTAL_DATA_SIZE
clock_hz=$CLOCK_HZ
run_type=performance
output_device=competition-uart
isa=rv32im_zicsr_zifencei
abi=ilp32
EOF

echo "COREMARK_FPGA_BUILD_PASS elf=$OUT_DIR/coremark.elf memh=$OUT_DIR/coremark.memh"
