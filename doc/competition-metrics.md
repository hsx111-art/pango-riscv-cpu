# 赛题指标记录

本文档是紫光同创 FPGA 创新设计赛题一的长期指标台账。所有数值必须来自
可复现的源码版本、工具版本和实验命令；没有真实证据的项目明确标记为
`Not measured`、`Not implemented` 或 `Not available yet`，不使用估算值代替。

## 当前版本与范围

| 项目 | 当前记录 |
| --- | --- |
| Git base revision | 分支 `perf/microarchitecture-profiling`；具体 revision 以本轮提交后的 `git log` 为准 |
| CPU | RV32IM，Machine mode，MMU off |
| 主要验证 top | `top_tcm_axi/src_v/riscv_tcm_top.v` |
| TCM | 64 KiB，CPU 与 AXI 装载/访问路径 |
| WSL/SystemC/Verilator | 71 total；65 runnable PASS，2 unsupported，4 not yet tested，0 failed |
| Windows/ModelSim | 71 total；65 runnable PASS，2 unsupported，4 not yet tested，0 failed |
| Dynamic predictor | 16-entry BTB/BHT with optional recovery validated；default baseline remains disabled |
| FPGA PDS flow | Not available yet |

## 功能指标

| 指标 | 状态 | 证据/限制 |
| --- | --- | --- |
| RV32I | Partially validated | `doc/verification/isa-validation-matrix.md`；不能宣称完整 compliance |
| RV32M | Validated for current matrix | `MUL*`、`DIV*`、`REM*` directed tests and baseline workloads |
| Machine CSR/trap | Validated for covered cases | ECALL/EBREAK/illegal/interrupt cases are matrix-scoped |
| Supervisor/MMU/PMP | Unsupported for default baseline | `SUPPORT_SUPER=0`、`SUPPORT_MMU=0`；没有默认配置证据 |
| C/F/D/A extensions | Not implemented/validated | 当前项目不声明这些扩展 |
| I/D cache | Implemented in cache top | `top_cache_axi` has 2-way cache; ModelSim compatibility still open |
| Dynamic branch prediction | Optional 16-entry BTB/BHT with recovery path | `directed/predictor_recovery` and full matrix pass both environments；predictor-on benchmark is slower |
| UART/GPIO | Validated for competition RTL smoke | `competition/competition_top.v` and `tb_competition.v` check UART markers, GPIO input/output and output-enable; board pins are not assigned yet |
| Timer source | Validated for competition RTL smoke | `competition_peripherals.v` implements `mtime/mtimecmp` and drives the core `timer_intr_i` path; this is not a full CLINT/PLIC claim |
| Competition integration top | Validated for RTL smoke | WSL/Verilator and ModelSim both produce `COMPETITION_TCM_PASS cycles=1123 gpio_out=600d0001` |

## 性能指标

架构计数器是软件区间的唯一比较依据：

```text
cycles  = delta(mcycle)
retired = delta(minstret)
CPI     = cycles / retired
```

| workload | 当前 smoke 结果 | 说明 |
| --- | --- | --- |
| CoreMark validation, 1 iteration, direct redirect + MUL E1 bypass, predictor off | 375,330 cycles; 315,440 retired; CPI 1.189 | 正确性/测量通路 smoke，不满足正式十秒计分条件 |
| CoreMark validation, 1 iteration, predictor on | 410,143 cycles; 315,440 retired; CPI 1.300 | 功能 PASS，但比正式 baseline 慢 6.59% |
| `dot_i8` | 12,368 cycles | checksum 4656 |
| `gemm_i8` | 125,841 cycles at `AI_REPEAT=16` | checksum 49 |
| `conv_i8` | 159,922 cycles | checksum -3 |
| `relu_i8` | 18,000 cycles at `AI_REPEAT=16` | checksum 158 |
| CoreMark/MHz | Not available yet | 缺少真实 FPGA 时钟与正式运行时长 |
| IPC | Not reported | 当前为单主 issue；CPI 足够支撑 baseline 比较 |
| branch accuracy | Diagnostic per-test metric available | predictor-on reports event/correct/mispredict/recovery counts；准确率不等于性能收益 |
| stall breakdown | Diagnostic only | SystemC/ModelSim profile signal，不替代架构计数器 |

## FPGA 实现指标

| 指标 | 状态 |
| --- | --- |
| PDS version | Not available yet |
| FPGA device / board | Not available yet |
| Clock constraint | Not available yet |
| Fmax | Not measured |
| LUT / FF | Not measured |
| DSP / BRAM | Not measured |
| WNS / TNS / critical path | Not measured |
| CoreMark/LUT | Not available yet |

当前仓库没有 PDS 工程、器件目标、约束或综合报告，不能从 Verilator/ModelSim
仿真结果推导这些指标。实现 baseline 必须在拿到 PDS 和目标板卡信息后重新记录。

## AI / YOLO 指标

| 指标 | 状态 |
| --- | --- |
| INT8 dot/GEMM/conv/ReLU | Workload smoke validated in both simulators |
| INT8 model size / activation memory | Not measured |
| YOLO model and operator set | Not selected |
| YOLO latency / FPS | Not measured |
| mAP / recognition accuracy | Not measured |
| FPGA resource cost | Not measured |
| External DDR requirement | Not decided |

当前 INT8 workload 只证明 CPU 算子和计量通路可运行，不能等价为 YOLO
推理结果或 FPGA 加速结论。

竞赛 UART image 使用 `OUTPUT_DEVICE=competition-uart`，将 CoreMark 字符输出
映射到 `0x10000000`/`0x10000004`；`verification/coremark/build_fpga_coremark.sh`
同时生成 ELF、MEMH 和构建参数记录。当前 `ITERATIONS=1` UART 运行仍是
short-run correctness smoke，正式 CoreMark 分数必须在真实 Pango 时钟下满足
至少十秒的测量条件。

## 指标实验规则

1. 每个 before/after 结果必须记录 commit、工具版本、参数、image hash 和输出 marker。
2. correctness 必须同时通过 WSL/SystemC/Verilator 与 Windows/ModelSim；单环境结果不进入稳定表。
3. 仿真 cycle 只能用于同一 RTL/configuration 下的相对比较，不能冒充 FPGA Fmax 或 CoreMark/MHz。
4. predictor、cache、流水线等改动必须同时记录性能变化与 LUT/FF/Fmax 变化；实现数据缺失时保留 `Not measured`。当前 predictor recovery 已完成 TCM 双环境功能验证，但 predictor-on 在 CoreMark/AI smoke 上为负收益，不能宣称优化成功。
