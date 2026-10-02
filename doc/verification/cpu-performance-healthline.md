# CPU Performance Healthline

Date: 2026-10-02  
Reference functional commit: `e9b3f9d`  
Branch: `perf/microarchitecture-profiling`  
Scope: `riscv_core` + `top_tcm_axi` TCM, RV32IM, Machine mode, MMU off

This document is the decision record for the first performance-oriented
optimization stage. The profiling additions on this branch are verification
only: they expose existing RTL conditions to the WSL/SystemC/Verilator and
ModelSim harnesses, but do not participate in fetch, issue, retirement,
memory, or trap control.

## Configuration gate

The formal comparison configuration is:

```text
ISA                         RV32IM + Zicsr + Zifencei
Privilege                   Machine mode
MMU                         Disabled
TCM                         64 KiB, boot address 0x00002000
ENABLE_BRANCH_PREDICTOR    0
ENABLE_BRANCH_PREDICTOR_REDIRECT 0
Compiler                    riscv64-unknown-elf-gcc 13.2.0
ABI                         ilp32
Optimization                -O2
```

The correctness gate is the manifest in
`verification/riscv_tests/manifest.tsv`:

| Gate | Total | Pass | Fail | Unsupported | Not yet tested |
| --- | ---: | ---: | ---: | ---: | ---: |
| WSL/SystemC/Verilator | 71 | 65 | 0 | 2 | 4 |
| Windows/ModelSim 2020.4 | 71 | 65 | 0 | 2 | 4 |

The two unsupported entries are deliberate baseline limitations, not hidden
passes. The current matrix does not claim PMP support, and the original
`rv32ui/ma_data` image is not a terminating test for this TCM environment.
The four not-yet-tested entries remain outside the runnable gate until they
have a terminating image and an explicit pass condition.

## Measurement contract

Architectural counters are the comparison authority:

```text
cycles  = end_mcycle  - start_mcycle
retired = end_minstret - start_minstret
CPI     = cycles / retired
```

The interval is bracketed in software. Harness cycle counters and issue or
retirement probes include boot, output, and termination activity and are
diagnostic only. The RTL profile signals are sampled by both environments and
are used to explain a measured interval, not to replace it.

The current profiling surface includes:

```text
fetch_req fetch_wait fetch_resp fetch_drop fetch_backpressure
fetch_mem_block fetch_redirect
issue_lsu_block issue_pipe_block issue_div_block issue_csr_block
issue_scoreboard_block issue_unclassified_block
```

The event classes are mutually exclusive within the issue-blocking
classification. A count is not automatically an avoidable cycle: overlapping
conditions, redirect recovery, and the shallow pipeline must be considered
before accepting a proposed RTL change.

## CoreMark smoke baseline

The pinned CoreMark source is built for RV32IM TCM with `-O2`, one context,
`TOTAL_DATA_SIZE=2000`, `RUN_TYPE=validation`, and `ITERATIONS=1`.

| Environment | Cycles | Retired | CPI x1000 | Correctness markers |
| --- | ---: | ---: | ---: | --- |
| WSL/SystemC/Verilator | 384,726 | 315,440 | 1,219 | CRCs match |
| Windows/ModelSim | 384,726 | 315,440 | 1,219 | CRCs match |

Both runs produced:

```text
seedcrc          : 0x18f2
[0]crclist       : 0xe3c1
[0]crcmatrix     : 0x0747
[0]crcstate      : 0x8d84
[0]crcfinal      : 0xe3c1
COREMARK_METRICS cycles=384726 retired=315440 cpi_x1000=1219
```

This is a correctness and measurement smoke run, not a reportable CoreMark
score. One iteration completes in less than ten seconds, so the official
CoreMark source emits its short-run validity notice and `Errors detected`.
The runners now accept that exact notice only when no CRC, data-type, or port
error is present, and report `VALIDITY=short-run` explicitly. A formal score
requires the official performance configuration, at least ten seconds, and a
real target clock measurement.

The earlier direct-redirect experiment reduced this smoke interval from
423,772 to 384,726 cycles. The optional predictor recovery experiment measured
410,143 cycles and is therefore not the active performance configuration.

## AI workload baseline

The four deterministic int8 workloads use `AI_REPEAT=16` and bracket their
kernel interval with `mcycle` and `minstret`:

| Workload | Cycles | Retired | CPI x1000 | Checksum |
| --- | ---: | ---: | ---: | ---: |
| `dot_i8` | 13,392 | 11,322 | 1,182 | 4,656 |
| `gemm_i8` | 125,841 | 117,564 | 1,070 | 49 |
| `conv_i8` | 169,138 | 150,621 | 1,122 | -3 |
| `relu_i8` | 18,000 | 16,891 | 1,065 | 158 |

The WSL and ModelSim runners both report `AI_PASS` for all four workloads.
The architectural intervals and checksums agree; only the harness marker
boundary can differ by one diagnostic sample.

Representative frontend and issue-blocking observations are:

| Workload | Fetch wait | Fetch memory block | Fetch backpressure | Fetch redirect | LSU block | Pipe block | Div block | CSR block | Scoreboard block |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `dot_i8` | 0 | 0 | 1,029 | 1,023 | 0 | 0 | 0 | 5 | 1,024 |
| `gemm_i8` | 0 | 0 | 5 | 8,254 | 0 | 0 | 0 | 5 | 0 |
| `conv_i8` | 0 | 0 | 9,221 | 9,278 | 0 | 0 | 0 | 6 | 9,216 |
| `relu_i8` | 0 | 0 | 5 | 1,086 | 0 | 0 | 0 | 5 | 0 |

These observations support the following current hypotheses:

1. `dot_i8` and `conv_i8` have a real dependency/interlock signal that is
   absent from `gemm_i8` and `relu_i8`. The next experiment should explain
   which register classes and producer latency create those blocks before
   changing scoreboard semantics.
2. TCM fetch latency is not the limiting factor for these workloads:
   `fetch_wait` and `fetch_mem_block` are zero, and `issue_lsu_block` is zero.
3. Redirect volume is high, but the predictor-on experiment is slower. Redirect
   count alone is not evidence that a larger BTB/BHT is the best next change.
4. Divider hold is not present in the four AI kernels, but it remains visible
   in the full RV32M divider tests and should be kept separate from the AI
   dependency investigation.

## Current bottleneck ranking

### P0: dependency/interlock cost in selected integer kernels

The strongest cross-workload signal is scoreboard blocking in `dot_i8` and
`conv_i8`, with zero scoreboard blocking in `gemm_i8` and `relu_i8`. This is a
candidate for a narrowly scoped forwarding or interlock experiment, not yet a
justification for weakening the scoreboard globally.

### P1: control-flow and redirect overhead

The direct redirect experiment was beneficial, but the current predictor
configuration is negative on CoreMark and all four AI comparisons. Keep the
predictor disabled for the formal baseline until prediction benefit exceeds
redirect and recovery overhead across the workload set.

### P2: divider serialization outside the AI path

The full regression exposes long divider hold and pipeline-block intervals on
`rv32um/div*` and `rv32um/rem*`. This is a valid future target only if a change
also preserves the current general-purpose and AI workload results.

## Not measured or not ready to claim

The following are intentionally open:

```text
Cache miss/refill/writeback performance       Not measured
Cache ModelSim compatibility                   Known historical issue
FPGA Fmax/LUT/FF/DSP/BRAM/WNS/TNS              Not measured
Formal CoreMark score or CoreMark/MHz          Not measured
DDR/streaming/YOLO system performance          Not measured
PMP/Supervisor/MMU feature claim               Unsupported or disabled
```

The cache RTL remains a separate validation track. The TCM healthline is a
core execution baseline and must not be used to infer DDR or cache behavior.

## Acceptance rule for the next RTL experiment

A proposed optimization is accepted only when it:

1. Passes all 65 runnable matrix entries in both environments.
2. Preserves all four AI checksums and improves or preserves their bracketed
   cycle/CPI intervals.
3. Preserves CoreMark CRCs and reports the architectural counter interval.
4. Explains the measured change with the profile data and does not rely on a
   single event count as a proxy for cycles.
5. Leaves the predictor-off configuration unchanged unless a controlled
   predictor comparison becomes an actual cross-workload win.

This healthline is sufficient to begin one narrowly scoped optimization
experiment. It is not evidence that the CPU is already optimized, nor is it a
formal FPGA competition score.
