# Competition Readiness Snapshot

This document records the delivery state on branch
`perf/microarchitecture-profiling`. The exact commit is recorded in Git; it is evidence-based; a module existing in
RTL is not marked as validated without an executable PASS result.

## Functional gates

| Area | Status | Evidence |
| --- | --- | --- |
| RV32IM TCM regression | DONE | WSL and ModelSim: `TOTAL=71 PASS=65 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4` |
| Machine trap and interrupt directed tests | DONE | ECALL, EBREAK, WFI, FENCE, illegal, misaligned load/store/fetch, external IRQ, timer IRQ |
| Competition UART/GPIO/timer top | DONE for RTL smoke | `competition/competition_top.v`, `verification/modelsim/tb_competition.v`, `COMPETITION_MODELSIM_PASS` |
| Competition UART/GPIO/timer top on WSL | DONE for RTL smoke | `verification/competition/run_wsl_competition_smoke.sh`, `COMPETITION_WSL_VERILATOR_PASS` |
| Competition software build on WSL | DONE | `make -C verification/competition clean all info` with the RISC-V toolchain on `PATH` |
| I/D cache functional smoke | DONE for WSL/Verilator path | `verification/cache/run_wsl_cache_smoke.sh` checks basic image plus directed dirty eviction/writeback workload; `CACHE_WSL_PASS` and `CACHE_WSL_DIRECTED_PASS` |
| Cache ModelSim path | BLOCKED | ModelSim 2020.4 still reports declaration-order/redeclaration errors in cache RTL |
| CoreMark smoke | DONE | One-iteration correctness and architectural counter measurement; not an official timed score |
| CoreMark competition UART path | DONE for short-run smoke | WSL and ModelSim check CRCs plus `COREMARK_UART_PASS`; use `OUTPUT_DEVICE=competition-uart` |
| FPGA-ready CoreMark image build | DONE for image generation | `verification/coremark/build_fpga_coremark.sh` emits ELF, MEMH and build metadata |
| PDS synthesis and FPGA measurements | NOT STARTED | Board/device, constraints and PDS project are not in this checkout |

## Ready-for-board gate

`READY_FOR_BOARD = NO` as of 2026-10-03. The local CPU/software verification
gate is green, but board handoff is intentionally blocked until the external
Pango inputs and the remaining board-facing evidence are available.

| Gate | Status | Evidence or blocker |
| --- | --- | --- |
| RV32IM dual-environment regression | PASS | WSL and ModelSim: `TOTAL=71 PASS=65 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4` |
| Competition top UART/GPIO/timer smoke | PASS | Both environments: `COMPETITION_TCM_PASS cycles=1123 gpio_out=600d0001` |
| CoreMark software/counter path | PASS, short-run | Both environments: `375330` cycles, `315440` retired, `CPI x1000=1189`; official ten-second score remains unclaimed |
| INT8 CPU workload path | PASS | `dot_i8`, `gemm_i8`, `conv_i8`, `relu_i8` pass in both environments at `AI_REPEAT=16` |
| Cache functional evidence | PASS, WSL only | Basic plus directed refill/writeback evidence; ModelSim cache source compatibility remains blocked |
| FPGA image and UART path | PARTIAL | FPGA-ready image flow exists; no board, pins, constraints or physical UART observation |
| Pango PDS implementation data | BLOCKED | PDS version, device, board template, constraints, timing and resource reports unavailable |
| Application demo | PARTIAL | INT8 kernels are validated; no selected complete model and no board demo |

## Competition top

`competition_top` reuses the TCM CPU and terminates the CPU AXI-Lite data port
with `competition_peripherals`. The current memory map is:

| Block | Base | Registers |
| --- | ---: | --- |
| UART | `0x10000000` | TX and status |
| GPIO | `0x10000010` | OUT, IN, OE |
| Timer | `0x10000020` | `mtime`, `mtimecmp`, control, status |

The ModelSim smoke loads the software image through the external AXI TCM port,
releases reset, checks GPIO input/output, observes UART output, triggers the
machine timer interrupt, checks `mcause=0x80000007`, executes `MRET`, and
requires the final GPIO marker `0x600d0001`.

## Reproduction commands

WSL TCM regression:

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; TEST_TIMEOUT_SEC=10 bash verification/riscv_tests/run_wsl_regression.sh"
```

Windows ModelSim TCM regression:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\modelsim\run_riscv_regression.ps1 -MaxCycles 200000
```

Competition ModelSim smoke:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\modelsim\run_competition.ps1
```

Competition WSL/Verilator smoke:

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; bash verification/competition/run_wsl_competition_smoke.sh"
```

CoreMark UART smoke in both simulators:

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; bash verification/coremark/run_wsl_coremark_uart_smoke.sh"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\modelsim\run_coremark_uart.ps1 -Iterations 1 -RunType validation -ClockHz 1000000
```

Cache Verilator smoke:

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; bash verification/cache/run_wsl_cache_smoke.sh"
```

The cache runner intentionally uses separate `clean` and build invocations.
Combining `clean all -j2` creates a make-level race and is not a valid command.

## Known limits

- `UNSUPPORTED` remains PMP and the current machine-mode configuration does not
  claim Supervisor, MMU, A, C, F or D support.
- The 65 runnable matrix tests are the correctness gate; cache smoke is an
  additional workload path and is not silently merged into that count. Cache
  directed evidence is currently WSL/Verilator-only because the cache RTL does
  not compile under the pinned ModelSim 2020.4 source-compatibility gate.
- Verilator/SystemC cycle counts are useful for relative comparisons only. Fmax,
  LUT/FF, BRAM/DSP, CoreMark/MHz and CoreMark/LUT require the target Pango FPGA
  and PDS implementation reports.
- The CoreMark UART path proves the software/image/peripheral interface, but the
  one-iteration run remains a short-run correctness smoke. It is not a formal
  CoreMark score until the official ten-second rule and a real FPGA clock are
  used.
