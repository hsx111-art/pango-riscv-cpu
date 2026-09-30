# ultraembedded/riscv 项目审计与基线报告

审计日期：2026-09-29
仓库：`A:\ultraembedded-riscv`
Git 分支：`main`
审计提交：`7ae6f80`
上游版本标记：`v1.0.1`

## 1. 审计范围与结论

本次工作没有修改 CPU 核心 RTL、测试程序或原有功能脚本。为使原有验证链在当前工具版本下可运行，只做了两处验证侧兼容修复，并新增了可复现的 WSL/ModelSim 入口和辅助文件。构建产物均为可再生文件，不纳入提交。

当前工程的真实形态是：

1. `core/riscv` 是一个 32 位、顺序发射为主的 RV32IM 核心，带可配置的额外 decode stage、旁路、基础 MMU、CSR/异常/中断和独立的乘除法单元。
2. `top_tcm_axi` 是最容易作为竞赛 RTL baseline 的封装，包含 64KB 双口 TCM、AXI4 外部加载端口和 AXI4-Lite 外设端口。
3. `top_cache_axi` 是另一套独立封装，包含 16KB、2-way ICache 和 16KB、2-way write-back/write-allocate DCache，使用两路 AXI4 master 端口。
4. 代码没有动态分支预测器。`riscv_exec` 会在执行阶段计算分支结果，`riscv_fetch` 在分支确认后重定向 PC。
5. `riscv_core.v` 传递了 `.SUPPORT_DUAL_ISSUE(1)`，但当前 `riscv_issue.v` 只有一个 primary issue slot、一个寄存器写回口和 `complete_*0` 调试接口，实际不能按双发射核心理解。
6. ISA 代码路径对应 RV32I 加 M、CSR/System 指令，README 将其描述为 `RV32IMZicsr`。A/C/F/D 没有硬件解码实现。README 所说的 Linux atomics 是软件模拟，不是 A 扩展硬件。
7. TCM 和 wrapper 的 Verilog 在 ModelSim SE-64 2020.4 下可以 `vlog -lint` 通过；cache wrapper 在相同工具下因源码中的先使用后声明/重复声明报 14 个错误。Cache 问题仍单独保留，不阻塞 TCM baseline。
8. WSL 中已补齐 `libelf-dev`、`binutils-dev` 和 `libsystemc-dev`，并使用发行版 SystemC/Verilator 5.020 成功完成 SystemC/Verilator 协同仿真；`basic.elf` 已真实执行并得到 10 项测试通过和 `BASELINE_A_PASS`。
9. Windows 侧已新增不修改核心 RTL 的纯 HDL TCM testbench、ELF-to-memory 转换器和 ModelSim 启动脚本；ModelSim `vlog`、`vsim -batch` elaboration、reset、镜像加载、CPU 执行和 CSR 退出均已完成，得到 `BASELINE_B_PASS`。仓库仍没有原生 RISCV-DV 或官方 compliance 测试源码。

因此，当前工程已经具备可冻结的 TCM 功能 baseline：原作者 WSL 协同验证链和 Windows + ModelSim TCM 纯 HDL 链均已完成端到端 PASS。这个结论只覆盖 `basic.elf`、TCM wrapper 和当前固定工具入口；cache、compliance、benchmark 及其他特权配置仍不能外推。

## 2. 目录结构

| 路径 | 内容和职责 |
| --- | --- |
| `core/riscv/` | 共享 RV32 核心 RTL，包括取指、译码、发射、执行、LSU、CSR、MMU、乘除法、流水线控制和寄存器堆。 |
| `top_tcm_axi/src_v/` | TCM 版本顶层 RTL。`riscv_tcm_top.v` 连接核心、TCM、AXI4 slave 和 AXI4-Lite master。 |
| `top_tcm_axi/tb/` | SystemC + Verilator TCM 协同仿真 testbench，使用 C++ 直接访问 Verilator TCM RAM。 |
| `top_cache_axi/src_v/` | Cache 版本顶层 RTL。`riscv_top.v` 连接 ICache、DCache 和核心。 |
| `top_cache_axi/tb/` | SystemC + Verilator cache 协同仿真 testbench，使用独立 AXI4 memory model。 |
| `top_tcm_wrapper/` | 面向集成的 TCM wrapper 版本，接口比 `top_tcm_axi` 更完整，含 AXI ID、burst 等信号。 |
| `isa_sim/` | C++ RV32 ISA simulator、cosimulation API、ELF loader、预编译 ELF 镜像。 |
| `isa_sim/images/` | `basic.elf` 和 `linux.elf` 两个预编译 RISC-V ELF。 |
| `doc/` | RISC-V ISA/privileged spec PDF、结构图以及本次审计文档。 |
| `README.md` | 上游工程概览、参数说明、接口说明和基本 Makefile 用法。 |

`core/riscv` 中的关键文件如下：

| 文件 | 作用 |
| --- | --- |
| `riscv_core.v` | 核心集成顶层，实例化所有 pipeline、执行、CSR、MMU 和访存单元。默认参数在第 47 至 55 行。 |
| `riscv_fetch.v` | PC、取指请求、分支重定向、取指响应和 skid buffer。 |
| `riscv_decode.v` | 可选额外 decode stage，并调用 `riscv_decoder`。 |
| `riscv_decoder.v` | 指令分类和非法指令检测。 |
| `riscv_issue.v` | 读寄存器、scoreboard、旁路、发射选择和流水线握手。 |
| `riscv_pipe_ctrl.v` | E1、E2、WB pipeline register、停顿、异常 squash 和提交。 |
| `riscv_exec.v` | ALU、JAL/JALR 和条件分支计算。 |
| `riscv_lsu.v` | load/store 地址、字节写使能、非对齐检查、响应格式化和访存停顿。 |
| `riscv_csr.v` | CSR 指令、xRET、FENCE、SFENCE、异常入口和中断入口的上层控制。 |
| `riscv_csr_regfile.v` | machine/supervisor CSR、特权状态、异常保存和中断 pending/mask。 |
| `riscv_multiplier.v` | M 扩展乘法流水。 |
| `riscv_divider.v` | 迭代除法，发射后会阻塞 pipeline。 |
| `riscv_mmu.v` | 可选 SV32 风格页表 walker、I/D TLB 和权限检查。 |
| `riscv_regfile.v` | 1 写 2 读通用寄存器堆。 |
| `riscv_defs.v` | 指令 mask、CSR 地址、特权级、异常号、MMU/PTE 定义。 |
| `riscv_trace_sim.v` | Verilator 下的指令调试字符串和 trace 辅助模块，不是 standalone testbench。 |

## 3. 顶层和数据通路

### 3.1 TCM 顶层

`top_tcm_axi/src_v/riscv_tcm_top.v:45` 定义 `riscv_tcm_top`，主要实例关系为：

```text
riscv_tcm_top
  ├── riscv_core u_core
  ├── dport_mux  u_dmux
  ├── tcm_mem    u_tcm
  │     ├── tcm_mem_ram
  │     └── tcm_mem_pmem
  └── dport_axi  u_axi
```

关键行为：

- `BOOT_VECTOR` 默认是 `32'h00002000`，见 `riscv_tcm_top.v:50`。
- `TCM_MEM_BASE` 默认是 0，`dport_mux.v:114` 将 `[TCM_MEM_BASE, TCM_MEM_BASE + 64KB)` 路由到 TCM，其他地址路由到外部 AXI-Lite。
- `tcm_mem_ram.v` 是 64KB、32-bit word、双端口同步 RAM，指令端口和数据端口分别使用两个时钟过程。
- `axi_t_*` 是用于加载 TCM、DMA 或外部访问 TCM 的 AXI4 slave；`axi_i_*` 是 CPU 访问外部 peripheral 的 AXI4-Lite master。
- `rst_i` 与 `rst_cpu_i` 分离，允许先装载程序，再释放 CPU reset。该接口定义和连接位于 `riscv_tcm_top.v:64-110` 以及 `riscv_tcm_top.v:167-366`。
- `intr_i` 顶层虽然是 32 bit，当前只连接 `intr_i[0:0]` 到核心，见 `riscv_tcm_top.v:186`。

README 给出的默认地址语义是：`0x00000000-0x0000ffff` 为 TCM，`0x00002000` 为 boot address，`0x80000000-0xffffffff` 为外设空间。实际外部路由在 `dport_mux.v` 中只按 64KB TCM 窗口判断，外设的更细粒度属性由核心 `MEM_CACHE_ADDR_MIN/MAX` 决定。

### 3.2 Cache 顶层

`top_cache_axi/src_v/riscv_top.v:45` 定义 `riscv_top`，连接关系为：

```text
riscv_top
  ├── dcache u_dcache
  │     ├── dcache_mux
  │     ├── dcache_core
  │     ├── dcache_if_pmem
  │     ├── dcache_pmem_mux
  │     └── dcache_axi
  ├── riscv_core u_core
  └── icache u_icache
```

其中：

- ICache 和 DCache 分别连接独立的 AXI4 master 端口，见 `riscv_top.v:146-285`。
- ICache 是 16KB、2-way、256 lines、32-byte line、每 line 8 words，参数在 `icache.v:107-116`。
- DCache 也是 16KB、2-way、256 lines、32-byte line、每 line 8 words；`dcache_core.v:84-96` 明确说明 write-back、read/write allocate。
- DCache 状态机包含 reset、flush、lookup、read、write、refill、evict、writeback 和 invalidate，见 `dcache_core.v:132-143` 和 `dcache_core.v:688-807`。
- `MEM_CACHE_ADDR_MIN/MAX` 决定核心 LSU 请求是否标记为 cacheable，核心默认值是 `0x80000000-0x8fffffff`，但 cache wrapper 的顶层默认参数是全地址范围，见 `riscv_core.v:54-55` 与 `riscv_top.v:50-52`。实际集成时应明确覆盖这些参数，避免把外设窗口错误地标成 cacheable。

### 3.3 TCM wrapper

`top_tcm_wrapper/riscv_tcm_wrapper.v` 与 `top_tcm_axi/src_v/riscv_tcm_top.v` 的内部结构基本一致，但 wrapper 接口保留了更完整的 AXI4 ID、burst 和 response 信号，适合后续接入 FPGA SoC 或比赛平台。ModelSim 对该 wrapper 的全量 `vlog -lint` 编译通过。

## 4. 流水线和核心模块关系

### 4.1 实际流水线形态

该核心不应简单标注为传统 IF/ID/EX/MEM/WB 五级。更准确的逻辑分层是：

```text
取指请求/响应
    │
    ▼
riscv_fetch
    │ fetch_valid/instr/pc/fault
    ▼
riscv_decode
    │ 可选 EXTRA_DECODE_STAGE
    ▼
riscv_issue
    │ 单个 primary issue slot + scoreboard + 旁路
    ├──────────────┬──────────────┬──────────────┬──────────────┐
    ▼              ▼              ▼              ▼
riscv_exec      riscv_lsu      riscv_csr    mul/div unit
    │              │              │              │
    └──────────────┴──────┬───────┴──────────────┘
                           ▼
                    riscv_pipe_ctrl
                    E1 -> E2 -> WB
                           │
                           ├── GPR writeback
                           ├── CSR writeback
                           ├── exception/interrupt squash
                           └── branch/return redirect
```

证据：

- 核心集成顺序见 `riscv_core.v:224-642`。
- `riscv_pipe_ctrl.v` 明确定义 E1 地址/ALU 阶段、E2 memory result 阶段和 WB/commit 阶段，分别见 `riscv_pipe_ctrl.v:141-229`、`riscv_pipe_ctrl.v:230-340`、`riscv_pipe_ctrl.v:342-477`。
- `riscv_decode.v:90-161` 由 `EXTRA_DECODE_STAGE` 选择带 buffer 的 decode 或直通 decode。
- `riscv_issue.v:367-420` 只有一个 `opcode_issue_r/opcode_accept_r` primary slot。虽然参数名 `SUPPORT_DUAL_ISSUE` 存在于 `riscv_issue.v:48`，当前代码没有第二套 `issue_*1`、`pipe_*1` 或 `complete_*1` 通路，核心只传入 `.SUPPORT_DUAL_ISSUE(1)`，见 `riscv_core.v:498-504`。

### 4.2 IF

`riscv_fetch.v` 负责：

- 维护 `pc_f_q` 和上一次发起请求的 `pc_d_q`，见 `riscv_fetch.v:172-220`。
- 默认顺序 PC 是对齐后的当前 fetch PC 加 4，见 `riscv_fetch.v:185-189`。
- 分支请求进入 `branch_q`，等待取指端口不忙后重定向，见 `riscv_fetch.v:97-126`。
- 使用 `icache_fetch_q` 跟踪一个 outstanding instruction request，见 `riscv_fetch.v:151-169` 和 `riscv_fetch.v:231`。
- 用 66 bit skid buffer 保存反压时的指令、PC 和 fault，见 `riscv_fetch.v:236-263`。

没有看到 BTB、BHT、两位饱和计数器、RAS 或其他动态预测表。条件分支在执行阶段确认后才改变 PC，因此 taken branch 至少会产生 redirect/squash 代价。

### 4.3 ID

`riscv_decode.v` 只做分类，不生成完整控制微码。`riscv_decoder.v` 输出 `exec_o/lsu_o/branch_o/mul_o/div_o/csr_o/rd_valid_o/invalid_o`，下游 `riscv_issue` 根据这些分类把指令发往执行单元。

### 4.4 Issue、寄存器堆和旁路

- `riscv_issue.v:367-420` 维护 32 bit scoreboard，阻止源寄存器或目标寄存器冲突。
- `riscv_issue.v:431-468` 实例化 `riscv_regfile`，寄存器堆是 1 写 2 读。
- `riscv_issue.v:470-490` 附近实现 WB、E2、E1 旁路，旁路能力由 `SUPPORT_LOAD_BYPASS` 和 `SUPPORT_MUL_BYPASS` 控制。
- 除 load/multiply 依赖外，乘法、除法和 CSR 操作在特定情况下会阻塞后续发射。除法和 CSR 的 pending 状态见 `riscv_issue.v:330-360`。

### 4.5 EX

`riscv_exec.v` 的 ALU 覆盖整数算术、逻辑、比较、移位、LUI/AUIPC 和 JAL/JALR 返回地址。条件分支在 `riscv_exec.v` 的 branch operation 区域计算 taken/not-taken，并输出 call、return、jump 标志。输出结果先经过 `result_q`，再由 `riscv_pipe_ctrl` 送到 E2/WB。

### 4.6 MEM/LSU

`riscv_lsu.v`：

- 支持 byte、halfword、word load/store，并生成 byte write strobe，见 `riscv_lsu.v:93-280`。
- 检测 word/halfword 非对齐访问，产生对应异常，不做多次 bus transaction 拼接。
- 用 `pending_lsu_e2_q` 跟踪 outstanding memory response，见 `riscv_lsu.v:116-137`。
- 用内部 FIFO 保存 load response 的地址、符号扩展和大小信息，见 `riscv_lsu.v:345-438`。
- 通过 `mem_cacheable_o` 将地址区间属性传给 wrapper；`MEM_CACHE_ADDR_MIN/MAX` 由 `riscv_core` 参数传入。
- 支持 `CSR_DFLUSH/CSR_DWRITEBACK/CSR_DINVALIDATE` 这些非标准 cache control CSR，见 `riscv_lsu.v:230-238` 和 `riscv_defs.v:373-378`。

### 4.7 WB/commit

`riscv_pipe_ctrl.v:342-477` 将 ALU、load、multiply、divide 和 CSR 结果统一进入 WB。该模块还：

- 对 memory fault 和 exception 清除目标寄存器写回有效位。
- 通过 `squash_e1_e2` 和 `squash_wb` 清除错误路径上的 pipeline state。
- 输出 `valid_wb_o`、`rd_wb_o`、`result_wb_o` 和 CSR writeback 信号。
- 在 `verilator` define 下实例化 `riscv_trace_sim`，供协同仿真提取 issue/WB trace。

## 5. ISA、CSR、特权和异常

### 5.1 ISA 支持结论

| ISA/功能 | 当前结论 | 代码依据 |
| --- | --- | --- |
| RV32I | 主要 RV32I 整数、立即数、比较、移位、跳转、条件分支、load/store 均有硬件 decoder 和执行路径。不能仅凭源码宣称已通过完整 compliance。 | `riscv_defs.v:60-208`，`riscv_decoder.v:62-198` |
| M | 支持 `MUL/MULH/MULHSU/MULHU` 和 `DIV/DIVU/REM/REMU`。默认 `SUPPORT_MULDIV=1`。 | `riscv_defs.v:248-277`，`riscv_multiplier.v`，`riscv_divider.v`，`riscv_core.v:47` |
| Zicsr/System | 支持 CSR read/write/set/clear、`ECALL`、`EBREAK`、xRET、`WFI`、`FENCE`、`FENCE.I`、`SFENCE.VMA` 的分类和相应控制。 | `riscv_defs.v:212-293`，`riscv_decoder.v:221-233`，`riscv_csr.v:101-150` |
| A | 没有 AMO/LR/SC 指令 mask 或 decoder。README 所称 Linux atomics 是软件模拟。 | `riscv_defs.v` 没有 AMO/LR/SC 定义；`isa_sim/riscv.cpp:914` 只明确提到不支持 RVC，Linux 镜像和 README 表明 A 是软件路径 |
| C | 不支持 16 bit compressed instruction。取指按 32 bit、PC+4 工作；ISA simulator 在 `riscv.cpp:914` 明确写明 RVC 不支持。 | `riscv_fetch.v:185-189`，`riscv.cpp:914` |
| F/D | 没有浮点寄存器堆、浮点执行单元或 F/D decoder。 | `riscv_defs.v` 和 `riscv_decoder.v` 未发现对应指令路径 |
| `LWU` | decoder 支持 `LWU`，但 RV32I 中该编码不是常规 RV32I load 集合，应作为非标准/兼容性行为单独记录。 | `riscv_defs.v:196-197`，`riscv_decoder.v:95-96` |

`riscv_defs.v` 定义了 `MISA_RVA/RVF/RVD/RVC/RVS/RVU` 常量，但这些定义不是硬件实现证据。真正返回的 `misa_w` 在 `riscv_csr.v:157` 只显式包含 RV32、I，以及按 `SUPPORT_MULDIV` 选择的 M。

### 5.2 CSR

machine CSR 主要包括 `mstatus`、`misa`、`medeleg`、`mideleg`、`mie/mip`、`mtvec`、`mepc`、`mcause`、`mtval`、`mcycle/mtime/mtimeh`、`mhartid`。supervisor CSR 包括 `sstatus`、`sie/sip`、`stvec`、`sepc`、`scause`、`stval`、`satp`、`sscratch`。地址和 mask 在 `riscv_defs.v:334-399`，读写实现主要在 `riscv_csr_regfile.v:182-210`、`riscv_csr_regfile.v:436-461`。

默认核心参数是：

```verilog
SUPPORT_SUPER = 0
SUPPORT_MMU   = 0
SUPPORT_MULDIV = 1
```

因此默认 TCM/cache 顶层实际上是 machine-mode、无 MMU、带 M 扩展的配置。打开 `SUPPORT_SUPER=1` 后，CSR register file 才启用 supervisor/user 状态迁移、delegation 和 S-mode CSR。

需要后续规范复核的一点是：`riscv_csr.v:157` 在 `SUPPORT_SUPER=1` 时仍没有把 `MISA_RVS` 或 `MISA_RVU` 加入硬件返回值；而 `riscv_csr_regfile.v` 又确实实现了对应 supervisor/user 相关 CSR 和权限逻辑。这可能导致 `misa` 自描述与实际可用特权模式不一致。

### 5.3 异常和中断

异常类型定义在 `riscv_defs.v:482-527`，包括：

- instruction misaligned、instruction fault、illegal instruction、breakpoint；
- load/store misaligned、load/store fault；
- ECALL；
- instruction/load/store page fault；
- interrupt、xRET 和 pipeline fence/flush 内部事件。

`riscv_csr_regfile.v:280-430` 保存 `mepc/sepc`、`mcause/scause`、`mtval/stval`，根据 delegation 决定进入 `mtvec` 或 `stvec`，并实现 MRET/SRET 的状态恢复。

外部 interrupt 由 `intr_i` 进入 `riscv_csr_regfile`，通过 `mie/mip/mideleg` 做 mask/delegation。`riscv_csr.v:155` 将 `timer_irq_w` 固定为 0，所以当前核心没有外部可配置的 timer interrupt 输入；CSR register file 内部虽有 `mtimecmp` 逻辑，但默认 top-level 并没有通过 `riscv_csr.v` 的 timer input 注入外部计时中断。

仿真控制使用 `CSR_DSCRATCH` 或 `CSR_SIM_CTRL`，在 `verilator` 或 `verilog_sim` define 下触发 `$finish` 或 `$write`，见 `riscv_csr_regfile.v:490-580`。

## 6. MMU、Cache 和总线

### 6.1 MMU

`riscv_mmu.v` 在 `SUPPORT_MMU=1` 时启用：

- SV32 风格两级页表 walker，`STATE_LEVEL_FIRST` 和 `STATE_LEVEL_SECOND`，见 `riscv_mmu.v:132-260`。
- 一个 I-TLB 和一个 D-TLB，见 `riscv_mmu.v:276-360`。
- 使用 `satp` 的 mode/PPN，支持 machine bypass、supervisor/user 区分。
- 基本检查 PTE present/read/write/exec/user、SUM 和 MXR，见 `riscv_mmu.v:330-440`。
- MMU page table fetch 使用标记为 `{1'b0,3'b111,7'b0}` 的内部 response tag，和普通 LSU 共用外部 memory port。
- 默认 `SUPPORT_MMU=0`，无 MMU 时是直通路径，见 `riscv_mmu.v` 的 `No MMU support` 分支。

这是一套可运行的基础 MMU，不应等同于完整 Linux 级别的 TLB、页表写回、A/D bit 管理或多项并行 TLB。后续若以 Linux 或 supervisor 模式作为竞赛目标，需要单独验证页表 fault、权限和 fence 行为。

### 6.2 Cache

ICache 的状态机是 flush、lookup、refill、relookup，使用 burst read refill。DCache 除 lookup/read/write/refill 外，包含 dirty eviction、writeback 和 invalidate，理论上适合较高带宽 AXI memory。

但当前 cache 源码存在明显的工具兼容性问题。ModelSim 错误来自：

- `dcache_core.v:205` 使用 `tag_hit_any_m_w`，实际声明在 `dcache_core.v:428`；
- `dcache_core.v:261` 使用 `flush_addr_q`，实际声明在 `dcache_core.v:609`；
- `dcache_core.v:329/385/452/467` 使用若干 tag/data 信号，声明分别出现在 `369/425/544/581`；
- `dcache_core.v:369/425/428/544/581/609` 又被 ModelSim 报为重复声明，因为前面的使用被按隐式 net 处理；
- `icache.v:210` 使用 `flush_addr_q`，声明在 `icache.v:387`，产生 undefined plus already declared 错误。

这不是本阶段要修复的 RTL 问题，但它直接影响 Windows + ModelSim/Questa 路线。Verilator 的语义容忍度更高，在本次 `--lint-only` 中没有报错，不能据此认定 ModelSim 也可运行。

### 6.3 AXI

- TCM 版本的数据路径通过 `dport_mux` 在 TCM 和 AXI-Lite 之间选择，外部 `dport_axi.v` 只允许有限 outstanding transaction，并有小 FIFO。
- Cache 版本的 `icache` 和 `dcache_axi` 以 burst 为主，`AWLEN/ARLEN` 对 32-byte cache line 使用 8 个 word 的 burst。
- TCM 的外部加载路径支持 AXI4 burst，`tcm_mem_pmem.v` 将 AXI request 拆成 RAM request 和响应 FIFO。
- AXI response/error 通过 `mem_ack/mem_error/mem_resp_tag` 返回给 LSU 或 cache。

后续 FPGA 移植需要重点检查 AXI ready/valid 的 backpressure、读写独立通道、burst 边界、外部 memory latency 和 reset release 顺序。当前没有 AXI protocol assertion 或独立 bus functional model 以外的形式化检查。

## 7. 现有验证体系

### 7.1 RTL/SystemC testbench

仓库没有 standalone Verilog/SystemVerilog testbench。现有 testbench 是 C++ SystemC 驱动的 Verilator model：

- `top_tcm_axi/tb/testbench.h` 实例化 `riscv_tcm_top_rtl`，通过 Verilator hierarchy 访问 `u_tcm` 的 `write/read` function，见 `testbench.h:20-112`。
- `top_cache_axi/tb/testbench.h` 实例化 `riscv_top`，并连接两个 `tb_axi4_mem`，分别模拟 ICache memory 和 DCache memory，见 `testbench.h:20-116`。
- 两个 testbench 都调用 `cosim::instance()->attach_cpu("rtl", this)`、`attach_mem` 和 `riscv_main`，将 RTL 与 C++ ISA simulator 同步，见两个 `testbench.h:50-57`。
- `main.cpp` 设置时钟、reset、assert handler 和 `sc_start()`。断言失败打印 `TEST FAILED`，见两个 `main.cpp:40-50`。

### 7.2 Simulator 和脚本

Makefile 的依赖链是：

```text
top_*/tb/make
  └── make -C ../../isa_sim lib
  └── make -f makefile.generate_verilated
  └── make -f makefile.build_verilated
  └── make -f makefile.build_sysc_tb
```

具体依赖：

- `make`、`gcc/g++`；
- `libelf` 和 `libbfd`，见 `isa_sim/makefile:21`、`top_*/tb/makefile.build_sysc_tb:26`；
- SystemC，默认假设 `SYSTEMC_HOME=/usr/local/systemc-2.3.1`；
- Verilator，默认假设 `VERILATOR_SRC=/usr/share/verilator/include`；
- Linux shell 命令 `mkdir -p`、`rm -rf`、`grep`、`wc`，见各 Makefile。

仓库 Makefile 没有 Icarus、ModelSim 或 Questa 目标。README 只明确说明 Verilator/SystemC testbench。ModelSim/Questa 需要用户自行建立 file list、library、define 和 testbench。

### 7.3 软件程序、加载和 pass/fail

`isa_sim/README.md` 说明 simulator 通过 ELF loader 加载 `images/basic.elf` 或 `images/linux.elf`。当前镜像属性为：

- `basic.elf`：ELF32 RISC-V、soft-float、静态链接，入口 `0x00002000`，适合 64KB TCM；
- `linux.elf`：ELF32 RISC-V、soft-float、静态链接，适合较大的 memory window，默认 Makefile 运行参数为 `-b 0x80000000 -s 33554432`。

`riscv_main.cpp` 负责解析 `-f`、加载 ELF、创建 memory region、reset、step 和退出处理。`CSR_SIM_CTRL_EXIT` 通过 simulator/RTL 的 CSR 控制退出码；`CSR_SIM_CTRL_PUTC` 用于输出字符。RTL 端只在 `verilator` 或 `verilog_sim` define 下启用这些仿真 CSR。

波形方面：

- SystemC 默认创建 `sysc_wave.vcd`，可通过 `--vcd_name` 改名；
- Verilator model 默认打开 `verilator.vcd`；
- 环境变量 `ENABLE_WAVES=no` 可以关闭 SystemC wave；
- 当前没有 GTKWave、Questa waveform 或波形回归脚本。

### 7.4 Compliance 和 benchmark

仓库本身没有 `riscv-compliance`、`riscv-tests`、RISCV-DV 或 benchmark 源码目录。README 声称过去使用 Google RISCV-DV 和外部 `exactstep` 做过随机指令协同仿真，也给出了 CoreMark/Dhrystone 指标，但本仓库没有足够脚本和输入重现这些结果。因此本次只能把它记录为上游声明，不能作为当前 checkout 的已运行证据。

## 8. 实际运行记录

### 8.1 Baseline A：WSL + Verilator/SystemC

环境和最小依赖：

| 项目 | 实际值 |
| --- | --- |
| WSL 发行版 | `Ubuntu-A` |
| Ubuntu | `24.04.1 LTS` |
| 仓库路径 | `/mnt/a/ultraembedded-riscv`，对应 Windows `A:\ultraembedded-riscv` |
| Verilator | `5.020` |
| SystemC | `2.3.4`，使用 Ubuntu `libsystemc-dev` |
| 依赖 | 实际版本 |
| --- | --- |
| `libelf-dev` | `0.190-1.1ubuntu0.1` |
| `binutils-dev` | `2.42-4ubuntu2.10` |
| `libsystemc-dev` | `2.3.4-3build1` |
| `verilator` | `5.020-1` |
| `gcc/g++` | `13.2.0-7ubuntu1` |
| `make` | `4.3-4.1build2` |
| Windows Python | `3.8.1`，用于 ModelSim ELF 转换 |

固定入口：

```powershell
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv && bash verification/wsl_baseline.sh"
```

该脚本实际执行：

1. `make -C isa_sim clean` 后重新构建 ISA simulator；
2. 构建 Verilator model，并显式加入 `verilated_threads.cpp`；
3. 构建 SystemC testbench；
4. 以 `ENABLE_WAVES=no ./build/test.x -f isa_sim/images/basic.elf` 运行。

实际结果：

- `basic.elf` 成功加载，入口为 `0x00002000`；
- 软件测试的 10 个检查全部输出并完成；
- 仿真时间约 `109020 ns`；
- 退出码为 0，输出 `BASELINE_A_PASS`。

原作者链路中的真实 pass/fail 机制是：C++ ISA simulator 和 RTL 协同执行同一 ELF，SystemC 断言失败时输出 `TEST FAILED` 并返回非零；仿真正常完成且没有失败标记时，固定脚本输出 `BASELINE_A_PASS`。RTL 侧的仿真 CSR 仍通过 `CSR_DSCRATCH/CSR_SIM_CTRL` 触发结束。

### 8.2 Baseline B：Windows + ModelSim + TCM

环境：

| 项目 | 实际值 |
| --- | --- |
| ModelSim | ModelSim SE-64 `2020.4` |
| 安装目录 | `A:\modletech64_2020.4` |
| 工作目录 | `C:\ultraembedded-riscv-modelsim\<timestamp>`，纯 ASCII |
| 输入镜像 | `isa_sim\images\basic.elf` |

固定入口：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_tcm_baseline.ps1
```

脚本执行顺序为：

1. `elf_to_memh.py` 用 Python 标准库解析 ELF32 little-endian alloc sections，生成 16384 words 的 `basic.memh`；
2. `vlib work` 创建独立库；
3. `vlog -lint +define+verilog_sim -f verification\modelsim\filelist.f verification\modelsim\tb_tcm_basic.v` 编译核心、TCM wrapper 和 testbench；
4. `vsim -batch -modelsimini <ModelSim安装目录>\modelsim.ini work.tb_tcm_basic -do "run -all; quit -f"` 完成 elaboration 和运行；
5. testbench 在 reset 释放前直接 `$readmemh` 到 `dut.u_tcm.u_ram.ram`，释放 `rst_i/rst_cpu_i`，监视已有 `CSR_DSCRATCH` 写回；退出码 0 表示软件 exit code 为 0。

实际结果：

- `vlog` 编译完成，0 errors，0 warnings；
- `vsim -batch` elaboration 成功；
- `basic.elf` 镜像成功加载，CPU 从 `0x00002000` 开始执行；
- 10 项软件测试全部完成，仿真时间约 `109010 ns`；
- ModelSim 输出 `Errors: 0, Warnings: 0` 和 `BASELINE_B_PASS`。

### 8.3 已解决的阻塞与根因

- `libelf.h` 缺失：由 `libelf-dev` 解决；`binutils-dev` 提供 `bfd` 头和库，SystemC 依赖由 `libsystemc-dev` 提供。
- 原 Makefile 默认 `SYSTEMC_HOME=/usr/local/systemc-2.3.1` 与 Ubuntu 包路径不一致：固定脚本显式使用 `SYSTEMC_HOME=/usr`、`VERILATOR_SRC=/usr/share/verilator/include` 和 `LIB_OPT=/usr/lib/x86_64-linux-gnu/libsystemc.so`。
- WSL 的 `NAME` 环境变量会覆盖 Makefile 中的测试名：入口脚本对子 Make 调用使用 `env -u NAME`。
- Verilator 5 不再提供旧版 `__VlSymsp` 私有层次接口：`top_tcm_axi/tb/testbench.h` 改用公开的 `m_rtl->v->u_tcm->write/read` 访问方式。
- Verilator 5 的线程运行时不在原 Makefile 源文件列表中：`top_tcm_axi/tb/makefile.build_verilated` 增加 `verilated_threads.cpp`。
- ModelSim `vsim -c` 的 `FileWatch(fileName)` Tcl 错误：在当前宿主上用最小 `riscv_alu` testcase 也可复现，因此不是 TCM RTL 逻辑错误。显式设置 `MODEL_TECH/MTI_HOME`、使用纯 ASCII 独立工作目录并采用 `-batch` 后，TCM elaboration 和功能仿真稳定通过。当前证据支持“ModelSim 2020.4 的当前命令模式/宿主初始化路径兼容问题”，但没有证据把它归因到单一用户 Tcl 文件或 `modelsim.ini` 条目；后续应继续保留 `-batch` 作为固定入口。

### 8.4 当前仍未解决但不阻塞 baseline 的问题

- `top_cache_axi` 的 `icache.v`/`dcache_core.v` 在 ModelSim 2020.4 下仍有 14 个先使用后声明/重复声明错误；Verilator lint 通过，但不等价于 ModelSim 可编译。
- 仓库没有随 checkout 提供 RISC-V compliance、`riscv-tests`、RISCV-DV 或 benchmark 回归源码；当前 PASS 只证明 `basic.elf` 这条固定协同测试。
- WSL 原 Makefile 仍是 Linux shell 语法；Windows 侧使用独立 PowerShell/ModelSim 入口，不把原 Makefile 强行移植到 PowerShell。

## 9. Windows + VS Code + ModelSim/Questa 可行性

### 9.1 当前可行部分

Windows 原生 ModelSim SE-64 2020.4 已经能够完成 TCM baseline 的完整闭环。TCM 和 wrapper 的 Verilog 在 `vlog -lint` 下通过，且新 testbench 通过 `+define+verilog_sim` 启用已有仿真 CSR 退出路径。

固定文件和职责：

| 文件 | 职责 |
| --- | --- |
| `verification/modelsim/filelist.f` | 明确列出 `core/riscv` 和 `top_tcm_axi/src_v` 的 RTL 编译顺序及 `+incdir+core/riscv`。 |
| `verification/modelsim/tb_tcm_basic.v` | 时钟、reset、TCM RAM 初始化、AXI 外部端口 idle、CSR exit 监控和超时判定。 |
| `verification/modelsim/elf_to_memh.py` | 不依赖第三方 Python 包，将 `basic.elf` 转为 `$readmemh` 可用的 32-bit word 镜像。 |
| `verification/modelsim/run_tcm_baseline.ps1` | 固定工具路径、ASCII 工作目录、编译、elaboration、运行和 PASS/FAIL 检查。 |

最小编译/运行命令由脚本展开为：

```powershell
& A:\modletech64_2020.4\win64\vlib.exe work
& A:\modletech64_2020.4\win64\vlog.exe -work <build>\work `
  +define+verilog_sim -lint `
  -f A:\ultraembedded-riscv\verification\modelsim\filelist.f `
  A:\ultraembedded-riscv\verification\modelsim\tb_tcm_basic.v
& A:\modletech64_2020.4\win64\vsim.exe -batch `
  -modelsimini A:\modletech64_2020.4\modelsim.ini `
  work.tb_tcm_basic -do "run -all; quit -f"
```

include path、define 和参数已经固定：`+incdir+core/riscv`、`+define+verilog_sim`，TCM 默认 `BOOT_VECTOR=0x00002000`、`TCM_MEM_BASE=0`，testbench 明确传入 64KB TCM 对应的参数。

### 9.2 ModelSim `FileWatch(fileName)` 问题

该错误不是所有 ModelSim 仿真都不可用：最小 testcase 和原 TCM top 在 `vsim -c` 下都能复现，但同一安装、同一库和同一 RTL 在 `vsim -batch` 下可以 elaboration 并运行。当前可复现的稳定规避条件是：

- 使用 `-batch`，不使用触发错误的 `-c` 入口；
- 显式设置 `MODEL_TECH` 和 `MTI_HOME`；
- 工作目录、库目录和日志目录使用 ASCII 路径；
- 显式传递安装目录的 `modelsim.ini`；
- 不依赖 VS Code/用户目录中的启动脚本状态。

这已经足以形成可重复 baseline，但尚未证明一个具体的 Tcl 初始化文件是唯一根因。若后续需要恢复交互式 `-c`/GUI 流程，应以相同最小 testcase 对比 ModelSim 2020.4、Questa 或另一台 Windows 主机的启动环境。

### 9.3 WSL 还是 Windows 原生

- WSL 负责 ISA simulator、Verilator/SystemC 协同执行和软件回归；这是原作者验证链的自然运行环境。
- Windows ModelSim/Questa 负责纯 RTL 编译、elaboration、波形和 FPGA 目标相关的时序前置检查；当前 TCM baseline 已可直接使用。
- 两边共享同一个 `isa_sim/images/basic.elf`，WSL 走 C++ ELF loader，ModelSim 走 `elf_to_memh.py`，两边均以软件 CSR exit code 0 判定 PASS。
- Cache 版本的 ModelSim 编译兼容性仍是独立任务，不能把 TCM baseline 的通过外推到 cache。

## 10. 作为竞赛 baseline 的评价

### 10.1 优点

- 已有相对完整的 RV32IM 执行路径、CSR、异常、中断和可选 MMU，适合快速做功能扩展。
- 取指、数据访存和外部接口已经抽象为握手式 memory port，TCM/cache 可以替换而不重写核心 pipeline。
- 参数化了 MULDIV、supervisor、MMU、load/mul bypass、额外 decode stage 和 cacheable address window，适合建立多配置实验矩阵。
- TCM 版本结构简单，64KB 双口 RAM 和分离 CPU reset 很适合先做 FPGA bring-up。
- 上游已有 C++ ISA model、ELF loader 和 trace/cosim 设计，补齐依赖后可以形成有价值的回归基础。

### 10.2 架构和性能风险

1. **发射宽度**：当前是一个 primary issue slot，`SUPPORT_DUAL_ISSUE` 参数不能视为真实双发射。吞吐上限、依赖停顿和 branch penalty 都由单发射路径决定。
2. **分支预测**：没有 BTB/BHT/RAS，所有条件分支在 EX 后才重定向，循环和函数调用有明显控制相关损失。
3. **长延迟单元**：除法为 2 至 34 周期且阻塞发射；CSR 也用 pending 状态避免流水化，可能拉低控制密集程序吞吐。
4. **访存延迟**：LSU 只维护有限 outstanding state，cache miss、AXI response 和非对齐异常会形成较长停顿。
5. **cache 工具兼容性**：cache RTL 先使用后声明导致 ModelSim 失败，必须先解决语言/tool portability，才能在比赛环境评估性能。
6. **MMU 范围**：基础 SV32 walker 和单项 TLB 适合功能演示，但并行度、TLB 容量、页表访问缓存和权限边界仍有限。
7. **ISA 自描述**：supervisor 逻辑可选，但 `misa_w` 没有明确反映 S/U，后续软件可能根据 `misa` 做错误能力判断。
8. **中断计时器**：`riscv_csr.v:155` 将 timer input 固定为 0，timer/mtimecmp 需要单独验证，不能默认视为完整 CLINT 级能力。

### 10.3 面积、主频和 FPGA 移植方向

- **面积**：首先比较 `EXTRA_DECODE_STAGE`、`SUPPORT_MUL_BYPASS`、`SUPPORT_LOAD_BYPASS`、`SUPPORT_MMU` 和 cache 开关。若竞赛偏资源利用率，TCM 配置比 cache/MMU 配置更容易控制 LUT、FF、BRAM 和 DSP 使用量。
- **主频**：优先检查 issue scoreboard、旁路 mux、分支比较/目标生成、CSR 权限判定、DCache tag/data RAM 输出和 AXI burst 控制。`EXTRA_DECODE_STAGE=1` 已是源码提供的时序优化开关，应先做综合对比。
- **性能**：先测单发射 CPI、load-use penalty、branch taken penalty、MUL/DIV latency、ICache/DCache miss penalty，再决定是否引入预测器或更深流水。
- **分支**：推荐先做静态 not-taken baseline，再加入小型 BHT/BTB 和可选 RAS，保持预测错误时仍复用现有 `branch_request`/`squash_decode` 机制。
- **Cache/存储**：先修复 ModelSim 可移植性，再验证 line refill、dirty eviction、flush/invalidate、uncached peripheral 和 AXI backpressure。Cacheable address window 必须与 FPGA memory map 明确绑定。
- **扩展**：A 扩展、压缩 C 扩展和更完整 privileged/interrupt 支持都属于高风险扩展，不建议在功能基线尚未形成前并行推进。
- **FPGA**：`tcm_mem_ram.v` 和 cache RAM 文件使用 Verilog array 推断存储器，需检查紫光同创综合器对双时钟双口 RAM、read-first 行为、byte write enable、异步 reset 和 `/*verilator public*/` 注释的处理。AXI4 burst、ID、ready/valid 和复位释放必须用板级或 BFM 验证。

## 11. 已发现问题清单

| 优先级 | 问题 | 影响 | 当前状态/建议 |
| --- | --- | --- | --- |
| 已解决 | WSL 缺少 `libelf.h`、BFD 和 SystemC 依赖 | 原作者验证链不能构建 | 已安装 `libelf-dev`、`binutils-dev`、`libsystemc-dev`，Baseline A PASS。 |
| 已解决 | 没有 Windows HDL testbench，TCM top 不能独立执行 | ModelSim 只能编译，不能跑程序 | 已新增 `tb_tcm_basic.v`、ELF 转换器和 PowerShell 入口，Baseline B PASS。 |
| 已解决 | Verilator 5 私有层次 API/线程运行时与原 Makefile 不兼容 | SystemC/Verilator testbench 构建失败 | 已做两处最小验证兼容修复，未改 CPU 核心。 |
| P1 | ModelSim 2020.4 的 `vsim -c` 触发 `FileWatch(fileName)` Tcl 错误 | 交互式/旧批处理入口不稳定 | `-batch` + 显式环境 + ASCII 工作目录已稳定通过；保留为工具环境遗留项。 |
| P1 | cache 在 ModelSim 报 14 个声明错误 | cache 版本暂不能作为 Windows ModelSim baseline | 单独建立工具兼容修复任务，不阻塞 TCM。 |
| P1 | 没有仓库内 compliance/RISCV-DV 回归 | RV32I 完整性没有当前 checkout 证据 | 后续引入外部测试时固定版本并保存 ELF、日志和工具版本。 |
| P1 | `SUPPORT_DUAL_ISSUE` 名称与实现不一致 | 误导架构判断和性能预期 | 文档先澄清，代码改动另行评审。 |
| P1 | `misa` 未明确反映 S/U | supervisor 软件能力探测可能不一致 | 规范对照和 CSR directed test。 |
| P2 | timer interrupt 在 `riscv_csr.v` 固定为 0 | timer/mtimecmp 语义不完整 | 作为中断子系统专项验证。 |
| P2 | `LWU` 在 RV32 中属于额外行为 | 工具链/规范兼容性需要说明 | 加 directed test 和文档约束。 |
| P2 | cache/MMU/AXI 缺少 protocol assertion | 边界条件错误可能只在长回归中出现 | 先补 BFM assertions，再做优化。 |

## 12. 下一阶段建议

当前不要开始 CPU 微架构优化。建议把下面两条命令固定为回归入口，并在每次 RTL 修改后先跑完：

1. `wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv && bash verification/wsl_baseline.sh"`
2. `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\modelsim\run_tcm_baseline.ps1`

基线稳定后的顺序建议：

1. 把两个脚本加入团队回归说明，固定 Ubuntu、Verilator、SystemC、ModelSim 和 Python 版本；
2. 引入官方 `riscv-tests` 或固定版本 RISCV-DV，并保存通过/失败日志和 ELF；
3. 单独修复 cache 的 ModelSim 声明顺序兼容性，再对 cache 做功能回归；
4. 以 `EXTRA_DECODE_STAGE`、旁路开关、TCM/cache、MMU 开关建立面积、Fmax、CPI 的 baseline matrix；
5. 只有在功能回归稳定后，再选择分支预测、A/C 扩展、双发射或 FPGA 外设集成等竞赛方向。

这一步已经回答了“原始、未进行架构优化的 ultraembedded CPU 能否真实执行测试程序并正确结束”：在当前环境中，WSL/SystemC/Verilator 和 Windows/ModelSim TCM 两条链路都能真实执行 `basic.elf`，并以 exit code 0 明确结束。

## 13. 当前 baseline 定义

```text
Baseline A：WSL Ubuntu-A + Verilator 5.020 + SystemC 2.3.4
           isa_sim + top_tcm_axi SystemC/Verilator 协同仿真
           basic.elf，10 项测试通过，BASELINE_A_PASS

Baseline B：Windows + ModelSim SE-64 2020.4 + top_tcm_axi TCM
           vlog + vsim -batch + tb_tcm_basic.v
           basic.elf，10 项测试通过，BASELINE_B_PASS

功能配置：RV32IM + Zicsr/System，machine mode，SUPPORT_MMU=0，TCM wrapper
核心 RTL：core/riscv 未修改
Cache 状态：Verilator lint 通过；ModelSim 14 个声明兼容错误仍未处理
Compliance：当前 checkout 没有官方 compliance/RISCV-DV 回归，不宣称完整合规
```

本 baseline 已足够作为竞赛后续开发的功能起点，但冻结范围应限定为 `TCM + riscv_core` 和两条已验证脚本。不能把 cache、MMU、supervisor、Linux 或 benchmark 的上游声明当成已验证能力。

### 13.1 本阶段文件变更

已修改：

- `top_tcm_axi/tb/testbench.h`：适配 Verilator 5 的公开层次访问 API，仅影响 testbench 访问 TCM RAM。
- `top_tcm_axi/tb/makefile.build_verilated`：加入 Verilator 5 所需的 `verilated_threads.cpp`，仅影响 testbench 构建。

已新增：

- `verification/wsl_baseline.sh`：WSL Baseline A 固定入口。
- `verification/modelsim/elf_to_memh.py`：ELF32 到 `$readmemh` 镜像转换器。
- `verification/modelsim/filelist.f`：TCM ModelSim RTL/testbench file list。
- `verification/modelsim/tb_tcm_basic.v`：独立 TCM HDL testbench。
- `verification/modelsim/run_tcm_baseline.ps1`：Windows ModelSim Baseline B 固定入口。
- `doc/project_audit_2026-09-29.md`：本审计和基线记录。

`isa_sim/libisa_sim.a`、`isa_sim/riscv-sim`、`isa_sim/obj/`、`top_tcm_axi/tb/build/`、`lib/`、`obj/`、`obj_verilated/`、`verilated/` 等均为构建产物，完成复跑后应清理，不提交。