# ISA Validation Matrix

Date: 2026-09-30
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

The manifest contains 59 entries:

| Category | Count | WSL/SystemC/Verilator | Windows/ModelSim |
| --- | ---: | --- | --- |
| Runnable entries | 51 | 51 pass | 51 pass |
| Unsupported entries | 2 | reported, not run | reported, not run |
| Not-yet-tested entries | 6 | reported, not run | reported, not run |
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
| `ECALL` | Yes | no terminating test in manifest | Not yet tested | Exception generation is in `riscv_csr.v:239-246`; the vendored `rv32mi/scall.S` source depends on a missing `rv64si/scall.S`. |
| `EBREAK` | Yes | no terminating test in manifest | Not yet tested | Breakpoint exception generation is in `riscv_csr.v:246-250`; `rv32mi/sbreak.S` has the same missing-source limitation. |
| `MRET` / xRET | Yes | `rv32mi/ma_addr` | Validated in this path | xRET decode and privilege return are in `riscv_csr.v:106-107,244-247` and `riscv_csr_regfile.v:597-609`. Supervisor return is not part of the baseline configuration. |
| `WFI` | Yes | no standalone test | Not yet tested | Decoder path is present at `riscv_csr.v:114`; no current test proves the wait/interrupt behavior. |
| `FENCE` | Yes | no standalone test | Not yet tested | Decoder path is present at `riscv_csr.v:115`; only `fence_i` is in the runnable matrix. |
| `FENCE.I` | Yes | `rv32ui/fence_i` | Validated | `riscv_csr.v:116` and the fetch invalidation path are exercised. |
| Simulation exit / putc CSR | Yes | all runnable tests | Validated as infrastructure | Custom `CSR_DSCRATCH` / `CSR_SIM_CTRL` handling is in `riscv_defs.v:325-329` and `riscv_csr_regfile.v:561-577`. |
| `mcycle` / `mtime` | Yes | no architectural counter test | Implemented, not fully validated | `csr_mcycle_q` and upper-half counter state are in `riscv_csr_regfile.v:103-104,266,503-510`. |
| `minstret` / `instret` | No evidence in current RTL | `zicntr`, `instret_overflow` not run | Not yet tested / currently unavailable | No `minstret` or `instret` implementation was found in the current RTL. |

The `misa` value returned by this baseline explicitly reports RV32, I, and M
only. Constants for A/C/F/D exist in `riscv_defs.v`, but they are not evidence
of implemented or verified extensions.

## Trap, exception, and interrupt status

| Area | Status | Evidence / limitation |
| --- | --- | --- |
| Illegal instruction exception | Validated for RV32 shift immediate | `rv32mi/shamt` checks `mcause == CAUSE_ILLEGAL_INSTRUCTION`; exception encoding is in `riscv_defs.v:485-491`. General illegal-instruction coverage is not complete. |
| Misaligned load/store exception | Validated for `ma_addr`; test environment unsupported for `ma_data` | LSU fault outputs connect through `riscv_core.v:362-404`; trap handling is in `riscv_csr_regfile.v:381-430`. |
| Misaligned fetch/branch target | Implemented, not independently tested | `riscv_pipe_ctrl.v:138,190-201` creates the fetch exception. |
| Machine trap entry and `mret` | Validated in `ma_addr` and `shamt` | `mtvec`, `mepc`, `mcause`, and trap branch logic are in `riscv_csr_regfile.v:282-337,587-628`. |
| External interrupt input | Implemented in RTL, not tested | `intr_i` is wired from `top_tcm_axi/src_v/riscv_tcm_top.v:186` into `riscv_csr.v:176`; no interrupt test passes in the current matrix. |
| Timer interrupt | Not available in this baseline | `timer_irq_w` is hard-wired to `1'b0` in `riscv_csr.v:155`; the CSR file has timer-compare state but no active timer source. |
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

The current regression has a timeout cycle counter in
`verification/modelsim/tb_tcm_regression.v`, but it does not yet export a
canonical instruction count, completed-instruction count, or CPI report. The
RTL exposes `mcycle` but no complete `minstret` counter was found. Therefore
there is currently no defensible CoreMark score or CPI baseline. Establishing
those measurements is a follow-up verification task, not a microarchitectural
optimization in this phase.

## Current conclusion

The repository is suitable as a frozen RV32IM Machine-mode TCM development
starting point. It is not yet a complete RISC-V compliance result. The next
verification work should extend the matrix for CSR/system and trap behavior,
add an explicit interrupt test environment, and only then establish cycle and
benchmark measurements. No branch predictor, pipeline, cache, multiplier, or
divider optimization is included in this baseline.
