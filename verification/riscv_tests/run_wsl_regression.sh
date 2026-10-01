#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TB_DIR="$ROOT_DIR/top_tcm_axi/tb"
TEST_DIR="$ROOT_DIR/verification/riscv_tests"
OUT_DIR="${REGRESSION_OUT:-/tmp/ultraembedded-riscv-regression}"
TEST_TIMEOUT_SEC="${TEST_TIMEOUT_SEC:-30}"

export PATH="${RISCV_TOOLCHAIN_BIN:-$HOME/.local/riscv-tools/usr/bin}:$PATH"

required=(riscv64-unknown-elf-gcc riscv64-unknown-elf-objdump riscv64-unknown-elf-readelf)
for tool in "${required[@]}"; do
    command -v "$tool" >/dev/null || {
        echo "REGRESSION_INFRA_FAIL: missing $tool" >&2
        exit 2
    }
done

echo "Building RV32IM standard tests into $OUT_DIR"
make -C "$TEST_DIR" OUT="$OUT_DIR" clean
make -C "$TEST_DIR" OUT="$OUT_DIR" -j2

echo "Rebuilding and checking the existing WSL baseline"
bash "$ROOT_DIR/verification/wsl_baseline.sh"

pushd "$TB_DIR" >/dev/null
pass=0
fail=0
unsupported=0
not_tested=0
total=0
while IFS=$'\t' read -r name isa status comment; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    total=$((total + 1))

    case "$status" in
        unsupported)
            echo "REGRESSION_UNSUPPORTED $name: $comment"
            unsupported=$((unsupported + 1))
            continue
            ;;
        not-yet-tested)
            echo "REGRESSION_NOT_TESTED $name: $comment"
            not_tested=$((not_tested + 1))
            continue
            ;;
        run|planned)
            ;;
        *)
            echo "REGRESSION_INFRA_FAIL: invalid manifest status '$status' for $name" >&2
            exit 2
            ;;
    esac

    image="$OUT_DIR/${name}.elf"
    [[ -f "$image" ]] || {
        echo "REGRESSION_INFRA_FAIL: missing image $image" >&2
        exit 2
    }

    echo "RUN $name"
    set +e
    output=$(timeout --foreground "${TEST_TIMEOUT_SEC}s" env -u NAME ENABLE_WAVES=no ./build/test.x -f "$image" 2>&1)
    rc=$?
    set -e
    printf '%s\n' "$output"

    if [[ $rc -eq 0 && "$output" == *$'P\n'* && "$output" != *$'F\n'* ]]; then
        echo "REGRESSION_PASS $name"
        pass=$((pass + 1))
    else
        echo "REGRESSION_FAIL $name (rc=$rc)" >&2
        fail=$((fail + 1))
    fi
done < "$TEST_DIR/manifest.tsv"
popd >/dev/null

echo "REGRESSION_SUMMARY TOTAL=$total PASS=$pass FAIL=$fail UNSUPPORTED=$unsupported NOT_TESTED=$not_tested"
if [[ $fail -ne 0 ]]; then
    exit 1
fi
