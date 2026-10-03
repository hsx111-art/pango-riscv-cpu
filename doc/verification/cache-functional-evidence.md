# Cache Functional Evidence

Date: 2026-10-03

## Scope

This document records functional evidence for the existing `top_cache_axi`
cache path. It does not claim a cache RTL redesign, target-board timing,
resource utilization, hit-rate counters, or ModelSim cache compatibility.

The test uses the existing `riscv_core` plus the upstream `icache` and `dcache`
modules. Only the SystemC/Verilator verification harness and a standalone
software workload were extended.

## Reproduction

From WSL Ubuntu-A:

```bash
cd /mnt/a/ultraembedded-riscv
TEST_TIMEOUT_SEC=120 bash verification/cache/run_wsl_cache_smoke.sh
SEED=7 TEST_TIMEOUT_SEC=120 bash verification/cache/run_wsl_cache_smoke.sh
```

The script performs these steps:

1. Builds `verification/cache/cache_workload.elf` with
   `-march=rv32im_zicsr_zifencei -mabi=ilp32 -O2`.
2. Generates and builds the cache Verilator/SystemC testbench.
3. Runs `isa_sim/images/basic.elf` and checks all ten original output lines.
4. Runs the directed cache workload and checks its explicit pass marker.
5. Checks lower bounds on observed AXI transactions.

## Workload Contract

`verification/cache/cache_workload.c` places four words at:

| Symbol | Address | Purpose |
| --- | ---: | --- |
| `cache_a` | `0x00010000` | first dirty line |
| `cache_b` | `0x00012000` | second dirty line |
| `cache_c` | `0x00014000` | conflict line |
| `cache_d` | `0x00016000` | second conflict line |

For the current 32-byte line and 256-set geometry, these addresses share the
same set index bits `[12:5]` and differ in tag bits. The sequence performs:

- first load and repeated load of A;
- store and read-after-write of A;
- first load, store, and read-after-write of B;
- loads of C and D to force two-way conflict replacement;
- reloads of A and B to check writeback/refill data preservation.

The linker explicitly provides a 4 KiB stack region at `0x5000-0x5fff`. This
is required because the ELF loader creates memory regions from the image and
the workload uses normal C calls and stack frames.

## Observed AXI Evidence

The BFM now reports handshake-level counters at test termination:

- read burst commands and read beats;
- 8-beat line refill bursts and their beats;
- write burst commands and write beats;
- 8-beat line writeback bursts.

These are external AXI observations. They are not architectural hit/miss
counters and must not be presented as exact cache access statistics.

Representative directed result, reproduced with `SEED=1` and `SEED=7`:

```text
CACHE_WORKLOAD_PASS
CACHE_METRICS cycles=949..1000 icache_read_bursts=12 icache_line_refills=12 icache_read_beats=96 dcache_read_bursts=8 dcache_line_refills=8 dcache_read_beats=64 dcache_write_bursts=2 dcache_line_writebacks=2 dcache_write_beats=16
CACHE_WSL_DIRECTED_PASS
```

The exact cycle count varies with the BFM delay seed. The structural lower
bounds required by the regression are:

```text
icache_line_refills >= 1
dcache_line_refills >= 1
dcache_line_writebacks >= 2
dcache_write_beats >= 16
```

The basic ELF remains covered by the same script. A representative result is:

```text
CACHE_WSL_PASS tests=10
CACHE_METRICS cycles=14442 icache_line_refills=90 dcache_line_refills=147 dcache_line_writebacks=1
```

## Status and Limitations

- WSL/SystemC/Verilator basic cache smoke: PASS.
- WSL/SystemC/Verilator directed dirty eviction/writeback workload: PASS for
  seed 1 and seed 7.
- Functional evidence covers instruction refill, repeated instruction fetch,
  data refill, store, read-after-write, dirty eviction, writeback, refill, and
  AXI burst lengths as observed by the BFM.
- ICache/DCache hit and miss totals are not directly instrumented in RTL.
- ModelSim cache compatibility remains blocked by the previously recorded
  declaration-order/redeclaration errors in the cache source set.
- FPGA timing, resources, miss penalty, hit rate, and board behavior remain
  unmeasured.

Therefore the readiness matrix should keep ICache, DCache, and AXI burst rows
at `PARTIAL`: functional WSL evidence is now real, but cross-tool and hardware
proof is still incomplete.