# MUL E1 Dependency Bypass Experiment

Date: 2026-10-02  
Branch: `perf/microarchitecture-profiling`  
Scope: `riscv_core` + `top_tcm_axi`, RV32IM, Machine mode, MMU off, 64 KiB TCM

## Decision

The optional `SUPPORT_MUL_E1_BYPASS` path is accepted as the default for the
TCM competition configuration. The generic `riscv_core` and cache wrapper
defaults remain disabled so existing upstream-style instantiations preserve
their original behavior. The TCM wrappers and their WSL/ModelSim runners now
default to `SUPPORT_MUL_E1_BYPASS=1`.

This is a narrowly scoped dependency/forwarding optimization. It does not
change the ISA, pipeline stage structure, branch predictor state, cache RTL,
or multiplier arithmetic.

## Root cause and RTL change

The workload profile identified scoreboard blocks in `dot_i8` and `conv_i8`
that matched their multiply instruction counts:

| Workload | MUL instructions | Scoreboard blocks before |
| --- | ---: | ---: |
| `dot_i8` | 1,024 | 1,024 |
| `conv_i8` | 9,216 | 9,216 |

The multiplier already computes `result_r` from the registered E1 operands in
`core/riscv/riscv_multiplier.v`. The normal writeback result is one stage
later. The change:

1. exposes `result_r` as `writeback_e1_value_o`;
2. forwards that value from `riscv_core.v` into `riscv_issue.v`;
3. excludes `pipe_mul_e1_w` from the scoreboard only when the parameter is
   enabled; and
4. selects the E1 multiply value in the existing E1 operand-bypass priority.

Load E1 interlocks, multiply E2 interlocks, divide/CSR serialization, and the
normal writeback path are unchanged. With the parameter disabled, the old
scoreboard and bypass behavior is retained.

Relevant files:

- `core/riscv/riscv_multiplier.v`
- `core/riscv/riscv_issue.v`
- `core/riscv/riscv_core.v`
- `top_tcm_axi/src_v/riscv_tcm_top.v`
- `top_tcm_wrapper/riscv_tcm_wrapper.v`

## Controlled configuration

Both sides use the same software images and compiler configuration:

```text
ISA       = RV32IM + Zicsr + Zifencei
ABI       = ilp32
Compiler  = riscv64-unknown-elf-gcc 13.2.0
Optimize  = -O2
TCM       = 64 KiB, boot address 0x00002000
Predictor = disabled
Repeat    = AI_REPEAT=16
```

The comparison changes only `SUPPORT_MUL_E1_BYPASS` from `0` to `1`.

## AI workload result

The architectural interval is measured by the software `mcycle` and
`minstret` brackets. Checksums are unchanged. The same values were observed
in WSL/SystemC/Verilator and Windows/ModelSim 2020.4.

| Workload | Bypass off cycles | Bypass on cycles | Delta | Retired | On CPI x1000 | Checksum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `dot_i8` | 13,392 | 12,368 | -7.646% | 11,322 | 1,092 | 4,656 |
| `gemm_i8` | 125,841 | 125,841 | 0.000% | 117,564 | 1,070 | 49 |
| `conv_i8` | 169,138 | 159,922 | -5.449% | 150,621 | 1,061 | -3 |
| `relu_i8` | 18,000 | 18,000 | 0.000% | 16,891 | 1,065 | 158 |

The direct profile evidence is consistent with the mechanism:

| Workload | Scoreboard blocks off | Scoreboard blocks on |
| --- | ---: | ---: |
| `dot_i8` | 1,024 | 0 |
| `gemm_i8` | 0 | 0 |
| `conv_i8` | 9,216 | 0 |
| `relu_i8` | 0 | 0 |

The unchanged `gemm_i8` and `relu_i8` intervals are expected: their measured
scoreboard-block counts were already zero. This is evidence for a targeted
dependency optimization, not a claim that all integer workloads improve.

## CoreMark smoke result

Configuration: pinned CoreMark source, `ITERATIONS=1`, `TOTAL_DATA_SIZE=2000`,
`RUN_TYPE=validation`, `CLOCK_HZ=1000000`, RV32IM TCM, `-O2`.

| Environment | Bypass off cycles | Bypass on cycles | Retired | On CPI x1000 | CRC result |
| --- | ---: | ---: | ---: | ---: | --- |
| WSL/SystemC/Verilator | 384,726 | 375,330 | 315,440 | 1,189 | all validation CRCs match |
| Windows/ModelSim 2020.4 | 384,726 | 375,330 | 315,440 | 1,189 | all validation CRCs match |

The one-iteration run is a smoke test only. It prints the official
short-runtime notice because it is below ten seconds, so no formal CoreMark
score or CoreMark/MHz value is claimed.

## Correctness gates

The enabled TCM configuration passed the same matrix in both environments:

```text
TOTAL=71 PASS=65 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4
```

Additional checks completed with bypass enabled:

- TCM `basic.elf`: `BASELINE_B_PASS` in ModelSim;
- AI microbench: all four workloads report `AI_PASS`;
- CoreMark: validation CRCs match and `COREMARK_METRICS` is present;
- full WSL/SystemC/Verilator regression: no runnable failures;
- full Windows/ModelSim regression: no runnable failures;
- ModelSim `vlog -lint`: `Errors: 0, Warnings: 0`.

The two unsupported and four not-yet-tested manifest entries are unchanged.
They remain explicit baseline limitations and were not converted into passes.

## Reproduction

The TCM competition configuration is now the default for these commands:

```text
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; bash verification/wsl_baseline.sh"
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; bash verification/ai_microbench/run_wsl_ai_microbench.sh"
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; bash verification/coremark/run_wsl_coremark.sh"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\modelsim\run_tcm_baseline.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\ai_microbench\run_modelsim_ai_microbench.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\coremark\run_modelsim_coremark.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\modelsim\run_riscv_regression.ps1
```

Pass `SUPPORT_MUL_E1_BYPASS=0` in WSL or `-SupportMulE1Bypass 0` in
PowerShell to reproduce the controlled off comparison.

## FPGA and timing risk

The forwarding path is combinational from the multiplier E1 result into the
existing issue operand mux. It may affect the issue/execute combinational
path and must be checked by the Pango PDS flow when the target device and
constraints are available. No LUT, FF, Fmax, DSP, BRAM, WNS, TNS, or
CoreMark/MHz claim is made from RTL simulation. The implementation remains
vendor-neutral and does not add FPGA primitives.

## Acceptance boundary

This experiment is accepted because it has a measured cross-environment
correctness gate, architectural before/after counters, workload-specific
profile evidence, and a small RTL surface. It does not authorize branch
predictor expansion, cache changes, pipeline restructuring, FPU work, or
custom INT8 instructions in this commit series.
