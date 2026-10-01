# ISA Validation Matrix

Date: 2026-10-01
Scope: `riscv_core` + `top_tcm_axi` TCM, Machine mode, `SUPPORT_MMU=0`

This document separates RTL presence from executable evidence. A feature is
not called validated merely because a decoder, CSR, or parameter exists.

## Status definitions

- **Implemented**: the current RTL contains a decode and execution or control
  path for the feature. This is a source-level statement only.
- **Validated**: a test in `verification/riscv_tests/manifest.tsv` ran to the
  simulation exit protocol and passed in both WSL/SystemC/Verilator and
  Windows/ModelSim regression.
- **Unsupported**: the current baseline or its test environment is not a
  supported target. The regression reports it without running the image.
- **Not yet tested**: the source or RTL path may exist, but this checkout does
  not yet provide a terminating, reproducible test for the current baseline.

## Regression totals

The manifest contains 70 entries:

| Category | Count | WSL/SystemC/Verilator | Windows/ModelSim |
| --- | ---: | --- | --- |
| Runnable entries | 64 | 64 pass | 64 pass |
| Unsupported entries | 2 | reported, not run | reported, not run |
| Not-yet-tested entries | 4 | reported, not run | reported, not run |
| Failed entries | 0 | 0 | 0 |

Commands used for the full matrix are:

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "export PATH=/home/shixin/.local/riscv-tools/usr/bin:`$PATH; cd /mnt/a/ultraembedded-riscv; TEST_TIMEOUT_SEC=10 bash verification/riscv_tests/run_wsl_regression.sh"

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_riscv_regression.ps1 `
  -MaxCycles 200000
```

The WSL runner rebuilds every runnable ELF, reruns `basic.elf`, and executes
the manifest through the original SystemC/Verilator testbench. The ModelSim
runner converts the same ELF files to `$readmemh` images and uses the pure HDL
TCM testbench. Both runners classify results from explicit PASS/FAIL markers,
timeouts, and process exit status.

## RV32I

| Feature | Implemented | Validated tests | Status | Evidence / limitation |
| --- | --- | --- | --- | --- |
| Integer arithmetic and logical operations | Yes | `add`, `addi`, `sub`, `and`, `andi`, `or`, `ori`, `xor`, `xori` | Validated | `core/riscv/riscv_decoder.v:61-120,168-188`; 9 runnable tests pass in both environments. |
| Comparisons | Yes | `slt`, `slti`, `sltiu`, `sltu` | Validated | Decoder and ALU path are exercised by 4 runnable tests. |
| Register and immediate shifts | Yes | `sll`, `slli`, `srl`, `srli`, `sra`, `srai` | Validated | Decoder masks are in `core/riscv/riscv_defs.v:82-94`; 6 runnable tests pass. |
| Conditional branches | Yes | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` | Validated | Target/taken handling is in `core/riscv/riscv_exec.v:323-372`; 6 tests pass. |
| Jumps | Yes | `jal`, `jalr` | Validated | Link and target handling is in `riscv_exec.v:323-345`; 2 tests pass. |
| Loads | Yes | `lb`, `lbu`, `lh`, `lhu`, `lw` | Validated | LSU path in `core/riscv/riscv_lsu.v`; 5 tests pass. |
| Stores | Yes | `sb`, `sh`, `sw` | Validated | LSU byte enables and write path are exercised by 3 tests. |
| Load/store addressing | Yes | `ld_st`, `st_ld` | Validated | 2 addressing tests pass through the TCM memory port. |
| Upper immediates | Yes | `auipc`, `lui` | Validated | 2 tests pass. |
| Instruction fence | Yes | `fence_i` | Validated | `IFENCE` decode/control exists in `riscv_csr.v:114-116`; 1 test passes. Plain `FENCE` has no standalone validated test. |
| Misaligned data access test | Trap path exists | `ma_data` is not run | Unsupported in this matrix | The core raises misaligned access exceptions, but this test image lacks a terminating handler for the current TCM environment. |
| RV32 shift immediate legality | Yes | `rv32mi/shamt` | Validated | The test catches illegal `shamt[5]`; the mask fix is in `riscv_defs.v:85-94` and mirrored in `isa_sim/riscv_isa.h`. |

**RV32I conclusion:** 40 RV32I entries pass and one is unsupported by the
current test environment. This is strong directed evidence, but it is not a
claim of complete architectural compliance.

## RV32M

| Feature | Validated tests | Status | Evidence |
| --- | --- | --- | --- |
| `MUL` | `rv32um/mul` | Validated | `riscv_decoder.v:113-116`, `riscv_multiplier.v` |
| `MULH`, `MULHSU`, `MULHU` | `rv32um/mulh`, `mulhsu`, `mulhu` | Validated | Multiplier writeback path in `riscv_core.v:454-474`. |
| `DIV`, `DIVU` | `rv32um/div`, `divu` | Validated | Divider path in `riscv_core.v:476-496`. |
| `REM`, `REMU` | `rv32um/rem`, `remu` | Validated | Decoder and divider result path are exercised. |

All 8 RV32M entries pass in both regression environments. The default core
configuration enables `SUPPORT_MULDIV=1` in `core/riscv/riscv_core.v:42-53`.

## CSR and system instructions

| Feature | Implemented | Validated | Status | Evidence / limitation |
| --- | --- | --- | --- | --- |
| CSR read/write/set/clear, immediate forms | Yes | `rv32mi/mcsr` | Validated in the tested subset | Decode and data selection are in `core/riscv/riscv_csr.v:104-150`; register access is in `riscv_csr_regfile.v:182-210,434-461`. The test does not cover every CSR or every privilege rule. |
| `misa`, `mhartid`, writable machine CSRs | Yes | `rv32mi/mcsr` | Validated | `misa_w` is formed in `riscv_csr.v:155-157`; the test passes. |
| `ECALL` | Yes | `directed/ecall` | Validated | Machine ECALL cause, zero `mtval`, `mepc` advance, and `mret` are checked by a terminating handler. |
| `EBREAK` | Yes | `directed/ebreak` | Validated | Breakpoint cause, zero `mtval`, `mepc` advance, and `mret` are checked by a terminating handler. |
| `MRET` / xRET | Yes | `rv32mi/ma_addr`, directed trap tests | Validated in machine mode | xRET decode and privilege return are in `riscv_csr.v` and `riscv_csr_regfile.v`. Supervisor return is not part of the baseline configuration. |
| `WFI` | Yes | `directed/wfi` | Validated for legal decode/forward progress | The test proves the baseline does not deadlock on WFI without a pending interrupt. It does not claim a low-power implementation. |
| `FENCE` | Yes | `directed/fence` | Validated for TCM forward progress | The test proves legal decode and forward progress; external memory ordering is outside this TCM-only check. |
| `FENCE.I` | Yes | `rv32ui/fence_i` | Validated | `riscv_csr.v:116` and the fetch invalidation path are exercised. |
| Simulation exit / putc CSR | Yes | all runnable tests | Validated as infrastructure | Custom `CSR_DSCRATCH` / `CSR_SIM_CTRL` handling is in `riscv_defs.v:325-329` and `riscv_csr_regfile.v:561-577`. |
| `mcycle` / read-only cycle aliases | Yes | `rv32mi/zicntr`, `directed/counters` | Validated for 32-bit TCM measurements | Counter writes, high halves, and `cycle/cycleh` aliases are checked. The current TCM baseline exposes 32-bit low/high CSRs. |
| `minstret` / `instret` | Yes | `rv32mi/zicntr`, `rv32mi/instret_overflow`, `directed/counters` | Validated for retirement and overflow behavior | The counter increments from the RTL retirement event, suppresses the writing instruction's implicit increment, and is exposed through read-only aliases. |

The `misa` value returned by this baseline explicitly reports RV32, I, and M
only. Constants for A/C/F/D exist in `riscv_defs.v`, but they are not evidence
of implemented or verified extensions.

## Trap, exception, and interrupt status

| Area | Status | Evidence / limitation |
| --- | --- | --- |
| Illegal instruction exception | Validated | `rv32mi/shamt` and `directed/illegal` check `mcause`, `mtval`, `mepc`, and `mret`. |
| Misaligned load/store exception | Validated | `directed/misaligned_load` and `directed/misaligned_store` check cause, `mtval`, `mepc`, and return. `rv32ui/ma_data` remains unsupported because its original image has no terminating handler. |
| Misaligned fetch/branch target | Validated | `directed/misaligned_fetch` reaches the handler and returns. |
| Machine trap entry and `mret` | Validated | `mtvec`, `mepc`, `mcause`, and `mtval` are checked by the directed trap handlers. |
| External interrupt input | Validated as testbench-injected machine interrupt | `directed/external_interrupt` drives `intr_i` at `IRQ_CYCLE=200`. This does not claim a PLIC or external interrupt controller implementation. |
| Timer interrupt | Validated as internal `mtimecmp`/`mcycle` source | `directed/timer_interrupt` programs the internal compare path. This does not claim a platform CLINT integration. |
| Supervisor mode | Not in baseline configuration | `riscv_core.v:48` defaults `SUPPORT_SUPER=0`; supervisor code exists but is not enabled or validated. |
| MMU / SV32 | Not in baseline configuration | `riscv_core.v:49` defaults `SUPPORT_MMU=0`; the MMU module is instantiated but bypass configuration is used. |
| PMP | Unsupported | No PMP implementation is enabled for this machine-mode TCM baseline; `rv32mi/pmpaddr` is reported unsupported. |

## Extension claims

| Extension / mode | Implemented in source | Validated in this baseline | Claim |
| --- | --- | --- | --- |
| RV32I | Broad decode and execution path | 40 directed tests pass; `ma_data` unsupported | Partially validated; not full compliance |
| RV32M | Yes, enabled by default | 8/8 tests pass | Validated for the tested operations |
| Zicsr | CSR decoder and register file | `mcsr` subset passes | Partially validated |
| Zifencei | `FENCE.I` path | `fence_i` passes | Validated for the tested path |
| A | No hardware claim | None | Unsupported / not implemented in baseline |
| C | No compressed decode claim | None | Unsupported / not implemented in baseline |
| F/D | No floating-point datapath claim | None | Unsupported / not implemented in baseline |
| Machine mode | Yes | CSR/trap subset passes | Baseline mode, partially validated |
| Supervisor mode | Optional source path only | None | Not enabled or validated |
| MMU | Optional source module only | None | Disabled and not validated |

## Measurement and benchmark readiness

The regression reports architectural `mcycle` and `minstret` values in both
environments. `retired` in the metrics line is the final architectural
`minstret` value; the ModelSim writeback probe is reported separately as
`retired_probe` for diagnostics only. `steps`/`cycles` are harness counters and
are useful for debugging, but benchmark comparisons must use counter deltas.
CPI is computed as `delta(mcycle) / delta(minstret)` after counters are reset
or bracketed around the measured region. The CoreMark port prints its own
bracketed `COREMARK_METRICS` line with cycles, retired instructions, and
integer CPI. Branch, stall, and IPC counters are not yet architectural signals
in this baseline.

## Current conclusion

The repository is suitable as a frozen RV32IM Machine-mode TCM development
starting point. It is not yet a complete RISC-V compliance result and it has
no reportable CoreMark score yet. The pinned CoreMark source, RV32IM TCM port,
CRC smoke run, and bracketed cycle/retirement metrics are now reproducible in
both environments. No branch predictor, pipeline, cache, multiplier, or
divider optimization is included in this baseline.
