# FPGA 实现 Baseline

## 审计结论

截至 `2c8b46b`，仓库中没有紫光同创 PDS 工程源文件、器件目标、pin
constraint、clock constraint、综合/布局布线脚本或资源/时序报告。Windows
环境的 PATH 中也没有发现可执行的 `pds_shell` 或同类 PDS 命令；因此当前
不能报告真实的 LUT、FF、DSP、BRAM、Fmax、WNS、TNS 或 critical path。

这不是 RTL 综合失败，而是 FPGA 实现输入尚未建立。Verilator lint、ModelSim
elaboration 和仿真 cycle 不足以替代 PDS implementation evidence。

## 当前可作为实现起点的 RTL

| 目标 | 文件 |
| --- | --- |
| TCM baseline top | `top_tcm_axi/src_v/riscv_tcm_top.v` |
| alternative TCM wrapper | `top_tcm_wrapper/riscv_tcm_wrapper.v` |
| cache top | `top_cache_axi/src_v/riscv_top.v` |
| CPU core | `core/riscv/riscv_core.v` |
| instruction/data adapters | `core/riscv/riscv_mmu.v`、各 top 的 AXI/TCM wrapper |

## 必须补齐的输入

- PDS 软件版本和命令行/GUI 工程模板；
- 具体 FPGA 器件型号和开发板；
- 时钟、复位和 IO pin 约束；
- TCM/BRAM 推断或 vendor memory IP 策略；
- UART/GPIO/中断外设连接方式；
- synthesis、place-and-route、timing report 导出方法。

## 后续记录格式

拿到工具和器件后，每个候选版本应记录：

```text
commit:
pds_version:
device:
board:
constraints_revision:
clock_target_mhz:
fmax_mhz:
lut:
ff:
dsp:
bram:
wns:
tns:
critical_path:
bitstream_hash:
software_image_hash:
```

在这些字段有真实输出前，`doc/competition-metrics.md` 中对应项必须保持
`Not measured` 或 `Not available yet`。
