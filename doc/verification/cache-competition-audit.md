# Cache 赛题要求审计

## 现有结构

`top_cache_axi/src_v/riscv_top.v` 复用同一个 `core/riscv/riscv_core.v`，并
将指令和数据端分别接到 `icache` 与 `dcache`。当前 RTL 参数和状态机显示：

| 项目 | ICache | DCache |
| --- | --- | --- |
| 容量 | 16 KiB | 16 KiB |
| 组相联度 | 2-way | 2-way |
| line | 32 bytes / 8 words | 32 bytes / 8 words |
| replacement | 由现有 cache 状态机管理 | 由现有 cache 状态机管理 |
| write policy | instruction refill | write-back、read/write allocate |
| burst | AXI refill burst | AXI refill and writeback burst |

这意味着 upstream cache top 已经覆盖赛题中“2-way I/D cache + burst”的
结构方向，当前不应重复实现一套 cache。

## 验证状态

- TCM top：Baseline A/B 已验证。
- cache top：使用 Verilator 5.020、`CORE=riscv` 和
  `SRC=riscv_top` 显式生成成功；这只证明 RTL 可编译，不等于 cache
  functional regression 已建立。
- ModelSim 2020.4：在独立 work library 中复现 14 个编译错误。错误集中在
  `dcache_core.v` 的 `tag*_hit_m_w`、`data*_data_out_m_w`、`flush_addr_q`
  先使用后声明/重复声明，以及 `icache.v` 的 `flush_addr_q` 先使用后声明。
  这是工具兼容性问题，不能归因于 predictor recovery 改动；本轮不修改
  cache RTL，也不把 cache top 纳入 TCM regression。
- cache Fmax、资源、miss penalty、hit rate：`Not measured`。

### Reproduction commands

Verilator compile audit（WSL）：

```bash
env -u NAME -u SRC -u CORE make -C /mnt/a/ultraembedded-riscv/top_cache_axi/tb \
  -f makefile.generate_verilated \
  SRC=riscv_top NAME=riscv_top clean all
```

ModelSim compile audit（Windows）：使用 `+define+verilog_sim`、
`+incdir+A:\ultraembedded-riscv\core\riscv` 和 cache source list 编译
`riscv_top.v`。当前命令在 `dcache_core.v`/`icache.v` 声明顺序处停止，尚未
进入 cache elaboration。

## 后续顺序

1. 保持 TCM predictor recovery correctness gate 独立为当前主线。
2. 单独修复并回归 cache top 的 ModelSim 声明顺序兼容性，再建立 cache
   functional smoke；这不是 predictor 性能实验的一部分。
3. 只有 cache regression 和 PDS 实现数据都具备后，才评估 cache 微架构优化。
