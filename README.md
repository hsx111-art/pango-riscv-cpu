# Pango RISC-V CPU Competition Project

A long-lived FPGA and CPU design workspace for the **2026 National Undergraduate Embedded Chip and System Design Competition**, **FPGA Innovation Design Track**, **Purple Mountain FPGA / 紫光同创赛题一：基于紫光同创 RISC-V 指令集 CPU 设计**.

This repository starts from a verified, upstream-derived RISC-V CPU baseline. The immediate engineering rule is simple: a version enters the verified table only after its exact source revision and reproducible commands pass on both supported simulation paths.

> **Repository status:** this project is intended to remain **Private**. It contains third-party open-source RTL, competition materials, and future PDS/IP integration work. Before any future publication, review upstream licenses, PDS-generated content, board collateral, and every third-party dependency for redistribution permissions.

## Project goals

The project will evolve the current CPU baseline through measured, reviewable stages:

- preserve a working functional baseline while adding directed and compliance-oriented tests;
- evaluate timing, area, CPI, memory-system behavior, and FPGA implementation constraints;
- add competition-specific functionality only after regression evidence exists;
- keep every stable milestone reproducible on Windows and WSL;
- record future PDS synthesis, timing-closure, and board bring-up evidence without committing generated tool trees.

No branch-prediction, pipeline, cache, ISA, or performance redesign is part of the initial repository-freeze milestone.

## Upstream and attribution

- **Source repository:** <https://github.com/ultraembedded/riscv>
- **Upstream baseline commit:** `7ae6f803e30f78c6ea3121e73c3adf50ff912730`
- **Upstream release marker:** `v1.0.1`
- **Original author/organization:** ultraembedded
- **License:** retain and follow the upstream `LICENSE` file in this repository.

The original commit history is preserved. Local commits add verification infrastructure, documentation, and tool-version compatibility fixes; they do not erase the upstream lineage.

## Current CPU baseline

The current competition starting point is the upstream-derived `core/riscv` RV32 core with the `top_tcm_axi` wrapper:

- 32-bit in-order-oriented Verilog core;
- fetch, decode, issue/scoreboard, execute, LSU, CSR, exception/interrupt, and optional MMU blocks;
- hardware integer multiply/divide path when `SUPPORT_MULDIV=1`;
- 64 KiB dual-port TCM with separate CPU reset and AXI loading/access ports;
- AXI4-Lite peripheral access path;
- no dynamic BTB/BHT/RAS branch predictor in the current baseline;
- no CPU-core RTL changes were made while establishing this repository baseline.

### ISA claims for the default baseline

The verified default configuration is conservative:

- RV32I integer base instructions exercised by the supplied program;
- M extension hardware path (`MUL`, `MULH*`, `DIV*`, `REM*`);
- CSR/System instruction path used by the core and simulation exit mechanism;
- Machine mode;
- `SUPPORT_MMU=0`;
- compressed C, atomic A, and floating-point F/D extensions are **not claimed as verified hardware support**;
- supervisor/MMU/Linux configurations remain separate, unverified targets for later work.

The upstream README contains historical statements about RISCV-DV, Linux, CoreMark, and Dhrystone. Those statements are retained as upstream context, not treated as evidence for this checkout unless a reproducible test record is added here.

## Verified versions

| Tag | Date | CPU/configuration | Verification environments | Status |
| --- | --- | --- | --- | --- |
| `v0.1.0-tcm-baseline` | 2026-09-30 | RV32IM + CSR/System, Machine mode, MMU off, `top_tcm_axi` TCM | WSL SystemC/Verilator/ISA simulator; Windows ModelSim SE-64 2020.4 HDL regression | Verified: `basic.elf` passed on both paths |

The tag is only valid for the exact commit named by the annotated tag. Cache, compliance, benchmark, supervisor, MMU, and board-level claims are outside this first verified scope.

## Reproduce the baseline

### Baseline A: WSL and the original SystemC/Verilator path

Environment used for the first verified version:

- WSL distribution: `Ubuntu-A`
- Ubuntu: `24.04.1 LTS`
- Verilator: `5.020`
- SystemC: `2.3.4`
- packages: `libelf-dev`, `binutils-dev`, `libsystemc-dev`

From PowerShell at the repository root:

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv && bash verification/wsl_baseline.sh"
```

The script rebuilds `isa_sim`, regenerates the Verilator model, builds the SystemC harness, loads `isa_sim/images/basic.elf`, checks all ten supplied software test markers, and requires a zero exit status with `BASELINE_A_PASS`.

### Baseline B: Windows ModelSim TCM regression

Environment used for the first verified version:

- ModelSim SE-64 `2020.4`, installed at `A:\modletech64_2020.4`
- Python 3 for the standard-library ELF-to-memory converter
- ASCII work directory under `C:\ultraembedded-riscv-modelsim\`

From PowerShell at the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_tcm_baseline.ps1
```

The script converts `basic.elf` to a 64 KiB word image, compiles the TCM RTL and `tb_tcm_basic.v` with `+define+verilog_sim`, runs `vsim -batch`, releases reset, executes the image, and requires `BASELINE_B_PASS` with zero ModelSim errors and warnings.

`vsim -c` is not the supported entry point in this environment because ModelSim 2020.4 reproduces a `FileWatch(fileName)` Tcl initialization error even with a minimal unrelated Verilog testcase. `-batch`, explicit `MODEL_TECH`/`MTI_HOME`, the installed `modelsim.ini`, and an ASCII work directory are the validated combination.

## Current verification status

The first baseline has been rerun from a clean build state:

- WSL/SystemC/Verilator: ten `basic.elf` checks passed, simulation ended at approximately `109020 ns`, `BASELINE_A_PASS`.
- Windows/ModelSim TCM: ten `basic.elf` checks passed, simulation ended at approximately `109010 ns`, `Errors: 0, Warnings: 0`, `BASELINE_B_PASS`.
- Standard-test matrix: 59 manifest entries, 51 runnable entries passed in both environments, 2 entries are explicitly unsupported, and 6 entries are not yet tested.
- The only core RTL change is the RV32 shift-immediate legality fix in `core/riscv/riscv_defs.v`; no microarchitectural optimization was made.
- Cache ModelSim compatibility remains a separate issue: the cache RTL has declaration-order problems under ModelSim 2020.4 and is not part of this tag.

Detailed evidence is in [`doc/verification/v0.1.0-tcm-baseline.md`](doc/verification/v0.1.0-tcm-baseline.md), the ISA matrix in [`doc/verification/isa-validation-matrix.md`](doc/verification/isa-validation-matrix.md), and the broader architecture audit in [`doc/project_audit_2026-09-29.md`](doc/project_audit_2026-09-29.md).

### Standard RV32IM regression

The vendored test subset is built and run through the same TCM memory model on
both supported paths. The manifest is the source of truth for the distinction
between `run`, `unsupported`, and `not-yet-tested` entries.

From PowerShell at the repository root:

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; TEST_TIMEOUT_SEC=10 bash verification/riscv_tests/run_wsl_regression.sh"

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_riscv_regression.ps1 `
  -MaxCycles 200000
```

Both commands must report zero failures. The WSL command ends with
`BASELINE_A_PASS` plus a `REGRESSION_SUMMARY`; the ModelSim command reports a
`MODELSIM_REGRESSION_SUMMARY`. See the [ISA validation matrix](doc/verification/isa-validation-matrix.md)
for the exact current counts and limitations.

## Repository layout

| Path | Purpose |
| --- | --- |
| `core/riscv/` | Upstream CPU RTL. Keep close to upstream layout for synchronization. |
| `top_tcm_axi/` | Primary competition baseline wrapper and original SystemC testbench. |
| `top_cache_axi/` | Cache wrapper and original cache-oriented testbench; not in the first ModelSim baseline. |
| `top_tcm_wrapper/` | Alternative TCM integration wrapper with fuller AXI signals. |
| `isa_sim/` | C++ ISA simulator, ELF loader, cosimulation API, and supplied images. |
| `verification/` | Reproducible WSL and Windows ModelSim baseline entry points. |
| `third_party/riscv-tests/` | Vendored RV32I/RV32M and selected machine-mode test sources used by the manifest. |
| `third_party/riscv-test-env/` | Vendored headers and environment macros required to build the selected tests. |
| `doc/` | Architecture audit, upstream specifications, and verification evidence. |
| `.codex/skills/` | Repository-local operating procedures, including Git hygiene. |

Generated build directories, ModelSim work state, VCD/WLF waveforms, temporary memory images, PDS project trees, bitstreams, and large reports are excluded by `.gitignore` and must not enter commits accidentally.

## Git and versioning policy

- `main` is the stable, verified competition line.
- `feat/...`, `fix/...`, `perf/...`, and `test/...` branches are used for isolated work.
- A change reaches `main` only after the relevant regression evidence is recorded.
- Use Conventional Commits and keep fixes, tests, documentation, and maintenance separable.
- Annotated tags require exact reproducible evidence; future board versions must also record PDS version, device, constraints, frequency, timing result, bitstream hash, image hash, and board evidence.
- The original upstream remote is retained as `upstream`; the competition repository is `origin` when available.

The detailed local policy is [`.codex/skills/riscv-git-hygiene/SKILL.md`](.codex/skills/riscv-git-hygiene/SKILL.md).

## Known limitations

- This checkout contains a deliberately limited, vendored subset of `riscv-tests` and `riscv-test-env`; it does not contain a complete compliance suite, RISCV-DV, or benchmark source tree.
- `basic.elf` is the current verified software image; passing it is not a complete ISA compliance claim.
- The standard-test matrix currently has 51 passes, 2 unsupported entries, and 6 not-yet-tested entries. RV32I is therefore not claimed complete.
- `misa` reports RV32I/M for the default configuration. A/C/F/D are not claimed as implemented or verified.
- The baseline has machine-mode CSR and trap paths, but external/timer interrupts, `minstret`, supervisor mode, MMU, and PMP are not fully validated.
- Cache RTL passes Verilator lint but currently has ModelSim 2020.4 declaration compatibility errors.
- Supervisor, MMU-enabled, Linux, timer-interrupt, and board-level configurations require separate directed tests.
- The current baseline has no dynamic branch predictor and is not being performance-optimized in this repository-freeze milestone.

## Roadmap

1. Keep Baseline A/B and the current 59-entry matrix green while adding directed CSR, system, trap, and interrupt tests.
2. Fill the not-yet-tested and unsupported entries only when the baseline configuration and termination protocol are defined clearly.
3. Add fixed-version compliance-oriented tests and preserve their images/log summaries.
4. Resolve cache tool portability independently and establish a cache regression.
5. Add measurement infrastructure for CPI, branch penalty, load-use stalls, area, and Fmax.
6. Evaluate one competition architecture direction at a time: branch prediction, memory system, ISA extension, or FPGA integration.
7. Establish PDS synthesis, timing closure, and board bring-up records before claiming hardware results.

## Third-party and redistribution note

This repository includes upstream ultraembedded source and supplied third-party or generated materials. Preserve each license and copyright notice. PDS-generated outputs, vendor IP, board files, and future external test suites may carry additional terms. The repository is private while this inventory and permission review remain incomplete.
