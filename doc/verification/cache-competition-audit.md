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
- cache top：Verilator 路径有历史 lint 通过记录，但还需要独立的完整
  functional regression 和实现报告。
- ModelSim 2020.4：历史问题集中在 `dcache_core.v` 的声明顺序/隐式 net
  以及 `icache.v` 的 `flush_addr_q` 声明顺序；这是工具兼容性问题，不能
  归因于 direct branch redirect 改动，直到重新编译得到相反证据。
- cache Fmax、资源、miss penalty、hit rate：`Not measured`。

## 后续顺序

1. 共享 `riscv_fetch` predictor 的 TCM correctness gate 已完成；当前只作为
   统计型 prototype，redirect/squash 仍未验证。
2. 再对 cache top 做单独的 Verilator/ModelSim compile audit。
3. 只有 cache regression 和 PDS 实现数据都具备后，才评估 cache 微架构优化。
