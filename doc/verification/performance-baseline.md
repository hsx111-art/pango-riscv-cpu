# Performance Measurement Baseline

Date: 2026-10-01
Scope: `riscv_core` + `top_tcm_axi` TCM, RV32IM, Machine mode, MMU off

## Measurement contract

The architectural counters are the source of truth for benchmark intervals:

```text
cycles  = delta(mcycle)
retired = delta(minstret)
CPI     = cycles / retired
```

The CoreMark port samples `mcycle` and `minstret` immediately before and after
CoreMark's timed `iterate()` region. It prints the interval as
`COREMARK_METRICS cycles=... retired=... cpi_x1000=...`; `cpi_x1000` is CPI
multiplied by 1000 using integer arithmetic. The WSL and ModelSim harness
metrics remain useful for debugging, but their absolute counters include
startup, output, and shutdown activity and must not replace the interval.

The current baseline exposes 32-bit low/high machine counter CSRs and their
read-only aliases. The CoreMark smoke run is short enough that 32-bit wrap is
not a factor. Longer FPGA runs must either bracket the interval below one
32-bit wrap or extend the measurement code to combine the high halves.

## Profiling contract

The verification harnesses also report diagnostic event counts for issue,
retirement, LSU and pipeline holds, divider and CSR holds, load/store/multiply
/divide/CSR issue, branch requests, taken branches, redirects, interrupts, and
issue blocking. These are sampled from existing RTL control signals and are not
architectural CSRs. They are useful for comparing the same workload across
revisions, but the architectural `mcycle`/`minstret` interval remains the
performance comparison authority.

The exact event definitions, four deterministic int8 workloads, and their
recorded results are in [`ai-microbench-baseline.md`](ai-microbench-baseline.md).

## Pinned source and port

- Source: EEMBC CoreMark
- Pinned source commit: `1f483d5b8316753a742cbf5590caf5bd0a4e4777`
- Unmodified benchmark sources: `third_party/coremark/`
- RV32IM TCM port: `verification/coremark/`
- Link address: `0x00002000`
- TCM size: 64 KiB
- ISA/ABI: `-march=rv32im_zicsr_zifencei -mabi=ilp32`
- Compiler optimization: `-O2`
- Data mode: static 2 KiB CoreMark block, one context

The port uses `mcycle` for timing, `minstret` for retirement counting, and
the existing `dscratch` simulation-control CSR for character output and exit.
The startup file initializes `sp` to `0x0000fff0`, calls `main`, emits a
harness completion marker, and then requests simulation exit.

## Reproduce the smoke run

WSL/SystemC/Verilator:

```powershell
Push-Location C:\
try {
  wsl.exe -d Ubuntu-A -- env -i `
    HOME=/home/shixin `
    PATH=/home/shixin/.local/riscv-tools/usr/bin:/usr/bin:/bin `
    ITERATIONS=1 RUN_TYPE=validation TEST_TIMEOUT_SEC=600 `
    bash -lc 'cd /mnt/a/ultraembedded-riscv; bash verification/coremark/run_wsl_coremark.sh'
}
finally { Pop-Location }
```

Windows/ModelSim SE-64 2020.4:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\coremark\run_modelsim_coremark.ps1 `
  -Iterations 1 -RunType validation -ClockHz 1000000 -MaxCycles 2000000
```

The two commands build the same ELF and use the same `2K validation` seeds.
The manifest regression is independent and must still be run after RTL or
verification changes.

## Observed smoke result

Both environments produced the same CoreMark correctness values:

```text
2K validation run parameters for coremark.
CoreMark Size    : 666
seedcrc          : 0x18f2
[0]crclist       : 0xe3c1
[0]crcmatrix     : 0x0747
[0]crcstate      : 0x8d84
[0]crcfinal      : 0xe3c1
COREMARK_METRICS cycles=423772 retired=315440 cpi_x1000=1343
```

The one-iteration smoke run also prints `Total time (secs): 0` and the
official CoreMark source reports that the minimum ten-second reporting rule
was not met. This is intentional: the result proves the workload, CRCs,
bare-metal port, TCM image path, and counter interval, but it is **not** a
reportable CoreMark score.

## Formal benchmark status

No formal CoreMark score or CoreMark/MHz result is claimed yet. A reportable
run must use the official performance seeds, run for at least ten seconds, and
use a real target clock frequency. RTL simulation is suitable for smoke and
correctness checks, but a ten-second benchmark run is expected to be measured
on the FPGA or another appropriately timed platform. The future report must
include the FPGA clock, clock constraints, exact compiler flags, iterations,
cycles, retired instructions, CPI, and the resulting CoreMark score.
