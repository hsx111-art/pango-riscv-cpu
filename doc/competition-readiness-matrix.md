# Competition Readiness Matrix

This matrix is the delivery gate for the Pango RISC-V competition project. A
feature is marked `DONE` only when there is executable evidence; RTL presence
alone is not enough.

| Area | Status | Evidence or blocking condition |
| --- | --- | --- |
| RV32I | DONE | 71-entry TCM matrix; 65 runnable tests pass in both environments |
| RV32M | DONE | Multiply/divide tests pass; MUL E1 bypass is regression-covered |
| Pipeline and hazards | DONE | TCM regression covers data, control, LSU and exception recovery |
| UART | DONE | `competition/competition_peripherals.v` and software UART smoke |
| GPIO | DONE | Input, output and output-enable checked by `tb_competition.v` |
| Timer and machine timer IRQ | DONE | `mtime/mtimecmp`, `mcause=0x80000007`, handler and `MRET` checked |
| Basic exceptions | DONE | ECALL, EBREAK, illegal and misaligned directed tests pass |
| TCM competition top | DONE | ModelSim and WSL/Verilator produce `COMPETITION_TCM_PASS` |
| 2-way ICache | PARTIAL | Basic and directed cache workloads pass in WSL/SystemC/Verilator; ModelSim cache compatibility remains blocked |
| 2-way DCache | PARTIAL | Directed load/store, dirty eviction, writeback and refill workload passes in WSL/SystemC/Verilator; board evidence is unavailable |
| AXI burst path | PARTIAL | BFM observes 8-beat refill/writeback bursts; hit rate, performance and target-board evidence are not measured |
| Dynamic branch predictor | PARTIAL | Optional BTB/BHT recovery is regression-covered; current measured configuration keeps it off |
| CoreMark smoke | DONE | CRCs and architectural `mcycle/minstret` interval pass in both environments |
| Official CoreMark score | BLOCKED | Must run at least 10 seconds with a real target clock |
| CoreMark/MHz | BLOCKED | Requires measured FPGA clock and runtime |
| Fmax | NOT STARTED | No PDS project, target device or timing report in this checkout |
| LUT/FF/BRAM/DSP | NOT STARTED | Requires PDS synthesis and implementation reports |
| CoreMark/LUT | NOT STARTED | Depends on both CoreMark/MHz and resource reports |
| INT8 kernels | DONE | `dot_i8`, `gemm_i8`, `conv_i8`, and `relu_i8` checksums pass |
| YOLO application route | PARTIAL | Candidate model and deployment constraints are documented; no board demo yet |
| Sensor/display integration | NOT STARTED | Board IO and peripheral requirements are not available yet |
| PDS flow | NOT STARTED | Awaiting PDS version, device, board, constraints and project template |
| Waveform evidence | PARTIAL | RTL simulation evidence exists; Pango logic-analyzer/ILA equivalent is not captured |
| Reproduction documentation | DONE | Scripts and evidence are recorded under `verification/` and `doc/` |

## Required interpretation

`DONE` means the current repository can reproduce the stated behavior. `PARTIAL`
means a functional subset is real but an important environment, performance or
hardware proof is missing. `BLOCKED` means the next action requires an external
condition. `NOT STARTED` means no implementation or measurement should be
claimed yet.

## Current gates

The correctness gate remains:

```text
WSL/SystemC/Verilator: TOTAL=71 PASS=65 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4
Windows/ModelSim:      TOTAL=71 PASS=65 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4
```

The competition software gate is:

```text
COMPETITION_TCM_PASS cycles=1123 gpio_out=600d0001
```

The cache gate is intentionally separate because its ModelSim source-compatibility
problem has not been silently converted into a passing result. The WSL cache
functional gate is:

```text
CACHE_WSL_PASS tests=10
CACHE_WSL_DIRECTED_PASS
```

The directed workload checks dirty two-way conflict replacement and requires at
least two observed 8-beat DCache writeback bursts. Detailed evidence is recorded
in `doc/verification/cache-functional-evidence.md`.
