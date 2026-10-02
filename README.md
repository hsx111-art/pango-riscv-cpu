# 紫光同创 RISC-V CPU 竞赛工程

本仓库面向 **2026 全国大学生嵌入式芯片与系统设计竞赛 FPGA 创新设计赛道赛题一：基于紫光同创 RISC-V 指令集 CPU 设计**。工程以 `ultraembedded/riscv` 为上游，保留原始 Git 历史、commit SHA、tag 和 upstream lineage，在可重复验证基础上开展 CPU、存储系统、FPGA 落地和 AI inference adaptation 工作。

> 仓库当前按 Private 工程管理。公开前必须重新检查上游许可证、第三方 benchmark、PDS 生成内容、器件 IP 和板卡资料的再分发条款。

## 项目简介

当前稳定开发起点是 RV32IM、Machine mode、MMU 关闭的 TCM 配置。工程已经建立两条一致的 RTL 验证链路：

- WSL + SystemC + Verilator + C++ ISA simulator；
- Windows + ModelSim SE-64 2020.4 + 纯 HDL TCM testbench。

所有功能或性能结论必须绑定明确的源码 revision、配置、工具版本、命令、PASS marker 和测量区间。仅有 RTL 代码、decode 参数或仿真编译成功，不等于功能已经 validated。

## 赛题目标

- 保持 RV32IM 功能回归稳定，逐步补齐赛题要求的 CPU 功能与系统集成；
- 用 `mcycle`、`minstret`、CPI 和固定 workload 建立可比较的性能证据；
- 后续以 PDS 实测获得 Fmax、LUT/FF、BRAM/DSP、CoreMark/MHz 和 CoreMark/LUT；
- 评估动态分支预测、Cache、流水线、定制指令和 INT8 加速，但只接受经双环境回归和 before/after 数据支持的方案；
- 最终完成 UART、GPIO、timer、interrupt、存储和板级启动闭环。

## 当前 CPU 架构

- 32-bit、in-order、single-issue 取向的 Verilog CPU；
- `riscv_fetch`、`riscv_decode`、`riscv_issue`/scoreboard、`riscv_exec`、`riscv_lsu`、`riscv_csr`、`riscv_pipe_ctrl` 等模块协同工作；
- `SUPPORT_MULDIV=1` 时启用硬件乘除法；
- 稳定 baseline 使用 `top_tcm_axi` 和 64 KiB 双口 TCM；
- TCM 内程序入口为 `0x00002000`，CPU reset 与装载接口 reset 分离；
- `top_cache_axi` 提供独立 I/D cache 的另一套上游 wrapper，但尚未进入正式 functional regression。

详细架构审计见 [`doc/project_audit_2026-09-29.md`](doc/project_audit_2026-09-29.md)。

## 指令集支持

默认配置的保守声明为：

- RV32I：40 个现有 directed/standard test 通过，但不是完整 compliance 声明；
- RV32M：`MUL*`、`DIV*`、`REM*` 共 8 项通过；
- Zicsr / Machine CSR：已覆盖当前 matrix 中的读写、trap 和 counter 子集；
- Zifencei：已有可执行测试；
- Machine mode：当前正式 baseline；
- Supervisor、MMU/SV32、PMP：未纳入默认 baseline；
- A、C、F、D：当前不声明实现或验证。

完整分类见 [`doc/verification/isa-validation-matrix.md`](doc/verification/isa-validation-matrix.md)。

## 流水线与控制流

该核心不是按文件名机械划分的教科书五级流水。fetch/decode/issue、E1/E2/WB、LSU、CSR 和 scoreboard 之间存在独立 hold、bypass、squash 与 redirect 控制。当前已验证的直接 branch redirect 相比早期版本降低了 taken redirect 延迟，并形成 `v0.2.0-perf-baseline` 的性能基准。

任何后续控制流修改必须检查：

- wrong-path 指令不能写寄存器、发 store、改 CSR 或提交 trap；
- outstanding instruction response 必须正确丢弃；
- scoreboard 和依赖状态不能残留；
- exception、interrupt、JAL/JALR、MRET、FENCE/FENCE.I 与 WFI 语义不能回归。

## 动态分支预测

当前实验分支包含可关闭的 16-entry direct-mapped BTB 和 16-entry 2-bit BHT，并增加了适配现有 single-issue 核心的最小 recovery：

- 条件分支在 fetch 侧预测 taken/not-taken；
- execute 提供实际 outcome 和正确下一条 PC；
- mismatch 时 fetch 丢弃错误路径 response，issue 阻止同周期错误路径指令进入执行；
- `directed/predictor_recovery` 覆盖两种 mismatch 方向，以及 wrong-path store、CSR write、illegal instruction 抑制；
- 默认仍为 `ENABLE_BRANCH_PREDICTOR=0`、`ENABLE_BRANCH_PREDICTOR_REDIRECT=0`。

predictor-on 已通过 WSL 和 ModelSim 的完整 correctness gate，但当前性能为负收益：

| Workload | Predictor off | Predictor on | 变化 |
| --- | ---: | ---: | ---: |
| CoreMark validation smoke cycles | 384,726 | 410,143 | +6.59% |
| `dot_i8` cycles | 13,392 | 13,459 | +0.50% |
| `gemm_i8` cycles | 125,841 | 130,521 | +3.72% |
| `conv_i8` cycles | 169,138 | 186,106 | +10.03% |
| `relu_i8` cycles | 18,000 | 18,071 | +0.39% |

因此 predictor recovery 当前是“功能正确的实验能力”，不是已接受的性能优化。正式 baseline 继续关闭 predictor。实验记录见 [`doc/verification/branch-predictor-experiment.md`](doc/verification/branch-predictor-experiment.md)。

## Cache 与存储系统

`top_cache_axi` 复用同一 `riscv_core`，包含：

- 16 KiB、2-way ICache；
- 16 KiB、2-way write-back/read-write-allocate DCache；
- 32-byte cache line；
- AXI burst refill，DCache 支持 writeback burst。

当前状态：

- Verilator 5.020 cache top compile audit 通过；
- ModelSim 2020.4 在 `dcache_core.v` 和 `icache.v` 上复现 14 个先使用后声明/重复声明兼容错误；
- cache functional smoke、hit rate、miss penalty、PDS 资源和时序尚未建立；
- Cache 问题独立于 TCM predictor correctness gate，不阻塞当前稳定 baseline。

详见 [`doc/verification/cache-competition-audit.md`](doc/verification/cache-competition-audit.md)。

## 验证环境

当前 `verification/riscv_tests/manifest.tsv` 共 71 项：

| 分类 | 数量 | WSL/SystemC/Verilator | Windows/ModelSim |
| --- | ---: | --- | --- |
| Runnable | 65 | 65 PASS | 65 PASS |
| Unsupported | 2 | 报告但不运行 | 报告但不运行 |
| Not yet tested | 4 | 报告但不运行 | 报告但不运行 |
| Failed | 0 | 0 | 0 |

已覆盖 RV32I/RV32M 子集、CSR、ECALL、EBREAK、MRET、WFI、FENCE、FENCE.I、illegal instruction、misaligned load/store/fetch、machine external interrupt、internal timer compare、`mcycle` 和 `minstret`。

### WSL 完整回归

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; TEST_TIMEOUT_SEC=10 bash verification/riscv_tests/run_wsl_regression.sh"
```

predictor-on 对照：

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv; ENABLE_BRANCH_PREDICTOR=1 ENABLE_BRANCH_PREDICTOR_REDIRECT=1 TEST_TIMEOUT_SEC=10 bash verification/riscv_tests/run_wsl_regression.sh"
```

### Windows ModelSim 完整回归

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_riscv_regression.ps1 `
  -MaxCycles 200000
```

predictor-on 对照：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_riscv_regression.ps1 `
  -MaxCycles 200000 `
  -EnableBranchPredictor 1 `
  -EnableBranchPredictorRedirect 1
```

ModelSim 2020.4 的稳定入口是 `vsim -batch`、显式 `modelsim.ini` 和 ASCII work directory。`vsim -c` 在当前安装上会触发 `FileWatch(fileName)` Tcl 初始化错误。

## CoreMark 性能

CoreMark 源码固定在 `third_party/coremark/`，TCM port 位于 `verification/coremark/`。架构测量合同为：

```text
cycles  = delta(mcycle)
retired = delta(minstret)
CPI     = cycles / retired
```

当前 direct-redirect、predictor-off 的 1-iteration validation smoke：

```text
cycles=384726 retired=315440 cpi_x1000=1219
```

该结果在两套仿真环境中一致，CRC 正确，但运行时间不足 CoreMark 官方至少 10 秒的计分要求，因此不是正式 CoreMark score，也不能推导 CoreMark/MHz。正式成绩必须在真实 FPGA 时钟下记录 compiler flags、iterations、运行时间、cycles、retired、CPI 和 CRC。

详见 [`doc/verification/performance-baseline.md`](doc/verification/performance-baseline.md)。

## FPGA 资源与时序

当前仓库没有可用的紫光同创 PDS 工程、目标器件、板卡 pin constraint 或 implementation report，因此以下指标保持未测：

- Fmax：`Not measured`；
- LUT / FF：`Not measured`；
- BRAM / DSP：`Not measured`；
- WNS / TNS / critical path：`Not measured`；
- CoreMark/MHz：`Not available yet`；
- CoreMark/LUT：`Not available yet`。

Verilator/ModelSim 的仿真 cycle 不能替代 FPGA implementation evidence。详见 [`doc/verification/fpga-implementation-baseline.md`](doc/verification/fpga-implementation-baseline.md)。

## AI / YOLO 加速路线

当前已建立固定 INT8 CPU workload：`dot_i8`、`gemm_i8`、`conv_i8`、`relu_i8`。它们用于检查 checksum、cycles、retired、CPI 及基础 profile event，不能等价为完整 YOLO 推理。

后续 YOLO 路线仍需明确：

- 轻量模型与 INT8 quantization 方案；
- weights、activation 和 workspace 内存规模；
- 64 KiB TCM 可容纳范围及 external DDR 需求；
- dominant operators 与 CPU/Cache 瓶颈；
- custom instruction、MAC/SIMD 或独立 accelerator 的资源收益。

在模型、内存和 profile 证据明确前，不同时推进 predictor、custom ISA 和 accelerator。

## 外设与系统集成

当前 CPU top 尚未形成竞赛板级 UART/GPIO 子系统：

| 项目 | 当前状态 |
| --- | --- |
| UART | 尚未集成 |
| GPIO | 尚未集成 |
| Machine external interrupt | testbench 注入路径已验证；无 PLIC |
| Timer interrupt | core 内部 compare 路径已验证；无正式 CLINT/板级 timer |
| AXI/APB peripheral path | TCM top 有 AXI-Lite 外部访问路径；板级地址映射未冻结 |

## 如何运行

WSL 原作者基础链路：

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv && bash verification/wsl_baseline.sh"
```

Windows ModelSim TCM 基础链路：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_tcm_baseline.ps1
```

CoreMark 与 AI microbenchmark：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\coremark\run_modelsim_coremark.ps1 `
  -Iterations 1 -RunType validation -ClockHz 1000000 -MaxCycles 2000000

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\ai_microbench\run_modelsim_ai_microbench.ps1 `
  -AiRepeat 16 -MaxCycles 2000000
```

## 目录结构

| 路径 | 作用 |
| --- | --- |
| `core/riscv/` | CPU 核心 RTL |
| `top_tcm_axi/` | 当前正式 TCM baseline wrapper 与 SystemC testbench |
| `top_cache_axi/` | 上游 I/D cache wrapper 与原始 cache testbench |
| `top_tcm_wrapper/` | 更完整 AXI 信号的 TCM wrapper |
| `isa_sim/` | C++ ISA simulator、ELF loader、cosimulation API |
| `verification/` | WSL、ModelSim、riscv-tests、CoreMark、AI microbench |
| `third_party/` | 固定版本的 riscv-tests、test-env 和 CoreMark |
| `doc/` | 架构、验证、性能、Cache 和 FPGA 证据文档 |

## Git 与版本管理

- `main` 是稳定、已验证的比赛开发线；
- `v0.1.0-tcm-baseline` 冻结最初双环境 TCM baseline；
- `v0.2.0-perf-baseline` 冻结 counters、CoreMark/AI workload 和 direct redirect 性能 baseline；
- 实验分支使用 Conventional Commits，并保持 RTL、test、docs 的职责可审查；
- 不提交 build、obj、ModelSim work/log、WLF/VCD、ELF/MEMH、PDS generated tree、bitstream、凭据或本机配置；
- 新功能进入 `main` 前必须重跑对应双环境 regression 和 benchmark correctness gate。

## 当前限制

- 不是完整 RISC-V compliance 结果；
- predictor recovery 的当前实现范围有限，且尚无性能收益；
- Cache 尚无 ModelSim elaboration 与 functional regression；
- 没有正式 CoreMark score、CoreMark/MHz 或 CoreMark/LUT；
- 没有 PDS 资源/时序结果；
- 没有完整 YOLO 模型、DDR 和板级外设集成；
- Supervisor、MMU、PMP、A/C/F/D 不属于当前正式 baseline。

## 后续计划

1. 保持 71-entry 双环境 regression、CoreMark CRC 和 AI checksum 全绿；
2. 优先分析 predictor 负收益的 recovery penalty、fetch latency 和 issue blocking，而不是盲目扩大 BTB/BHT；
3. 独立修复 cache 的 ModelSim 兼容性并建立 cache functional smoke；
4. 获取 PDS、目标器件、板卡和约束，建立可重复的 synthesis/implementation 流程；
5. 根据 CoreMark、INT8 profile 和 FPGA 资源结果选择下一项 CPU/AI 优化；
6. 完成 UART、GPIO、timer、interrupt 和板级程序加载闭环。

## 上游项目与许可证

- 上游仓库：<https://github.com/ultraembedded/riscv>
- 上游基线 commit：`7ae6f803e30f78c6ea3121e73c3adf50ff912730`
- 上游 release：`v1.0.1`
- 原作者/组织：Ultra-Embedded.com
- 许可证：BSD，详见仓库根目录 [`LICENSE`](LICENSE)

本仓库保留上游历史、版权和许可证文本。不得翻译、删除或弱化第三方 copyright、license 与 disclaimer。
