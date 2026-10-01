# AI Microbenchmark and Microarchitecture Profiling Baseline

Date: 2026-10-01  
Scope: `riscv_core` + `top_tcm_axi` TCM, RV32IM, Machine mode, MMU off

This record defines the first repeatable integer AI-oriented workload baseline
for the competition branch. It is a measurement and verification artifact,
not an architectural optimization result. The CPU RTL datapath and pipeline
behavior are unchanged.

## Workloads

The bare-metal image in `verification/ai_microbench/` contains four fixed,
deterministic int8 workloads:

| Workload | Kernel | Repeat count | Expected checksum |
| --- | --- | ---: | ---: |
| `dot_i8` | 64-element signed int8 dot product | 16 | 4656 |
| `gemm_i8` | 8x8x8 signed int8 matrix multiply | 16 | 49 |
| `conv_i8` | 8x8 output, 3x3 signed int8 convolution | 16 | -3 |
| `relu_i8` | 64-element int8 affine ReLU/clamp | 16 | 158 |

The checksums are computed independently from the C implementation and are
checked by the program before it emits `AI_PASS`. The workload interval is
bracketed by `mcycle` and `minstret` reads:

```text
cycles  = end_mcycle  - start_mcycle
retired = end_minstret - start_minstret
CPI     = cycles / retired
```

Build configuration:

```text
ISA       = RV32IM + Zicsr + Zifencei
ABI       = ilp32
Compiler  = riscv64-unknown-elf-gcc 13.2.0
Optimize  = -O2
Link      = 0x00002000 TCM boot address
TCM       = 64 KiB
AI_REPEAT = 16
```

## Workload interval results

The software interval is identical in both supported environments. `cpi_x1000`
is CPI multiplied by 1000 with integer arithmetic.

| Workload | Cycles | Retired | CPI x1000 | Checksum |
| --- | ---: | ---: | ---: | ---: |
| `dot_i8` | 14,402 | 11,318 | 1,272 | 4,656 |
| `gemm_i8` | 134,082 | 117,560 | 1,140 | 49 |
| `conv_i8` | 178,403 | 150,617 | 1,184 | -3 |
| `relu_i8` | 19,073 | 16,887 | 1,129 | 158 |

These are the numbers to use for comparing later CPU implementations. The
full harness counters include startup, output, and simulation-exit activity
and must not replace the bracketed workload interval.

## Verification-only profile events

The `verilator public` functions added to `core/riscv/riscv_issue.v` expose
existing control signals without adding state or changing synthesized logic.
The two harnesses sample the same event classes:

```text
issue retire lsu_stall pipe_stall div_hold csr_hold
load store mul div csr branch branch_taken redirect interrupt issue_blocked
```

The following profile counts were observed in both environments. The harness
cycle total differs by one boundary sample between SystemC and ModelSim, while
the event counts and workload intervals agree.

| Workload | Issue | Retire | Pipe hold | Div hold | CSR hold | Load | Store | Mul | Div | Branch | Taken | Redirect | Blocked |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `dot_i8` | 15,385 | 15,385 | 15,378 | 15,844 | 291 | 2,138 | 644 | 1,025 | 466 | 4,036 | 3,894 | 1,299 | 16,420 |
| `gemm_i8` | 121,631 | 121,631 | 15,378 | 15,844 | 294 | 16,539 | 1,668 | 8,193 | 466 | 26,885 | 25,590 | 8,531 | 16,426 |
| `conv_i8` | 154,792 | 154,792 | 15,906 | 16,388 | 318 | 18,595 | 1,676 | 9,217 | 482 | 33,077 | 28,710 | 9,571 | 17,018 |
| `relu_i8` | 20,945 | 20,945 | 15,312 | 15,776 | 291 | 1,178 | 1,667 | 1 | 464 | 4,223 | 4,080 | 1,361 | 16,352 |

The profile signals are diagnostic counters, not architectural CSRs. They are
sampled at the harness clock boundary and are intended to identify hypotheses
for later work such as branch redirection cost, divider hold time, or issue
blocking. Any optimization decision must be rechecked against the same
workload interval counters and the full 70-entry regression.

## Reproduction

Run `verification/ai_microbench/run_wsl_ai_microbench.sh` in WSL or run
`verification/ai_microbench/run_modelsim_ai_microbench.ps1` in PowerShell.

Expected terminal markers are WSL_AI_REGRESSION_PASS AI_REPEAT=16 and
MODELSIM_AI_REGRESSION_PASS AI_REPEAT=16.

## Interpretation and next use

The workload intervals and profile event counts agree across the two
simulation environments, which is sufficient to establish a repeatable
comparison point for later RTL revisions. The event counters are sampled
diagnostics: they do not prove that a particular event is the sole cause of a
cycle, and they do not replace architectural `mcycle`/`minstret` measurements.
In particular, the harness cycle total includes boot, output, and termination
activity, while each workload interval excludes that activity.

This baseline is ready for hypothesis generation and regression comparison,
not for claiming an optimization win by itself. A later change must preserve
the four checksums, rerun both environments, compare the bracketed workload
intervals, and pass the full 70-entry matrix before any branch, pipeline, LSU,
or memory-system conclusion is accepted. Formal CoreMark scoring remains a
separate FPGA or appropriately timed target measurement.
