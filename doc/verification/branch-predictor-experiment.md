# Dynamic Branch Predictor 实验记录

## 设计边界

第一版 predictor 是一个可关闭的小型动态 predictor，目标是建立赛题动态
分支预测指标和最小 recovery 闭环，而不是一次性完成高复杂度前端重构。

- 16-entry direct-mapped BTB；
- 16-entry 2-bit BHT；
- 条件分支使用 BHT 决策，B-type immediate 计算 target；
- JAL 继续使用已验证的 direct redirect 路径；
- JALR、CSR redirect、exception、interrupt、FENCE/FENCE.I、WFI 不预测；
- 同时只跟踪一个待解析分支，避免在当前单 issue/单 fetch 结构中引入多项
  未验证的 wrong-path 状态；
- prediction error 由 execute branch outcome 触发统计；当 redirect 开关打开时，
  `recover_pc_o` 使用 execute 已解析的正确下一条 PC，fetch 丢弃错误路径的
  outstanding response，issue 阻止同周期错误路径指令进入执行；
- recovery 只覆盖当前单 issue/单 outstanding branch 结构，不能据此宣称已经
  具备通用 speculative pipeline 能力；
- `ENABLE_BRANCH_PREDICTOR=0` 是默认配置，必须与现有 baseline 保持兼容。

## 必须记录的事件

```text
branch_count
taken_count
prediction_attempts
predicted_taken
prediction_correct
prediction_mispredict
recover_request
```

预测准确率定义为：

```text
accuracy = prediction_correct / prediction_attempts
```

只有在 WSL/SystemC/Verilator 与 Windows/ModelSim 的 checksum、CRC、PASS
marker 全部一致后，才允许把 predictor-on 作为功能不回归的实验配置。当前
recovery 已有 directed coverage，但 predictor-on 的 cycle/CPI 仍只能作为
受控对照结果；FPGA LUT、FF、BRAM、Fmax 在 PDS 工具可用前保持
`Not measured`。

## 当前状态

| 配置 | 状态 |
| --- | --- |
| baseline-off | Existing verified configuration |
| predictor-on compile | Validated in WSL/SystemC/Verilator and Windows/ModelSim |
| predictor-on directed branch tests | Validated; `directed/predictor_recovery` checks both mismatch directions and suppresses wrong-path store/CSR/illegal side effects |
| predictor-on full matrix | Validated; `TOTAL=71 PASS=65 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4` in both environments |
| predictor accuracy | Measured diagnostically per test; no performance claim |
| predictor redirect/recovery | Validated for the supported single-branch path; `predictor_recover` matches mismatch events in directed and workload runs |
| FPGA area/timing delta | Not measured |

## Reproduction evidence

The default regression remains predictor-off:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_riscv_regression.ps1 `
  -EnableBranchPredictor 0 -MaxCycles 1000000
```

The observational predictor can be compared without changing the test images:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\verification\modelsim\run_riscv_regression.ps1 `
  -EnableBranchPredictor 1 -MaxCycles 1000000
```

Both ModelSim runs completed with the same matrix result:

```text
MODELSIM_REGRESSION_SUMMARY TOTAL=71 PASS=65 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4
```

The WSL/SystemC/Verilator predictor-on run produced the same summary. The
directed recovery test passes with predictor-off and predictor-on in both
environments. It checks predicted-taken/actual-not-taken and
predicted-not-taken/actual-taken cases, including wrong-path store, CSR write,
and illegal-instruction suppression.

The controlled performance comparison is negative on the current shallow
pipeline. CoreMark validation smoke changed from `384726` cycles and CPI
`1.219` to `410143` cycles and CPI `1.300` with the predictor enabled. The
AI workload intervals changed as follows:

| Workload | Predictor off cycles | Predictor on cycles | Delta |
| --- | ---: | ---: | ---: |
| `dot_i8` | 13,392 | 13,459 | +0.50% |
| `gemm_i8` | 125,841 | 130,521 | +3.72% |
| `conv_i8` | 169,138 | 186,106 | +10.03% |
| `relu_i8` | 18,000 | 18,071 | +0.39% |

All checksums and CRCs remained correct. Therefore the predictor/recovery
implementation is functionally usable for further experiments, but the current
configuration is not a performance optimization. The formal baseline keeps
both predictor parameters disabled.
