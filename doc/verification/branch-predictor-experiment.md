# Dynamic Branch Predictor 实验记录

## 设计边界

第一版 predictor 是一个可关闭的统计型 prototype，目标是建立赛题动态
分支预测指标闭环，而不是一次性完成高复杂度前端重构。

- 16-entry direct-mapped BTB；
- 16-entry 2-bit BHT；
- 条件分支使用 BHT 决策，B-type immediate 计算 target；
- JAL 继续使用已验证的 direct redirect 路径；
- JALR、CSR redirect、exception、interrupt、FENCE/FENCE.I、WFI 不预测；
- 同时只跟踪一个待解析分支，避免在当前单 issue/单 fetch 结构中引入多项
  未验证的 wrong-path 状态；
- prediction error 由 execute branch outcome 触发统计；当前实现不把恢复请求
  接入流水线 squash/kill，因此不能把 predictor-on 当作可用的 wrong-path
  redirect 优化；
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
marker 全部一致后，才允许把 predictor-on 作为功能不回归的实验配置。由于
当前没有错误路径 squash/kill，predictor-on 的 cycle/CPI 不作为性能结果；
FPGA LUT、FF、BRAM、Fmax 在 PDS 工具可用前保持 `Not measured`。

## 当前状态

| 配置 | 状态 |
| --- | --- |
| baseline-off | Existing verified configuration |
| predictor-on compile | Validated in WSL/SystemC/Verilator and Windows/ModelSim |
| predictor-on directed branch tests | Validated; 64 runnable matrix entries pass in both environments |
| predictor-on full matrix | Validated; `TOTAL=70 PASS=64 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4` in both environments |
| predictor accuracy | Measured diagnostically per test; no performance claim |
| predictor redirect/squash | Unsupported / not validated; `predictor_recover=0` |
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
MODELSIM_REGRESSION_SUMMARY TOTAL=70 PASS=64 FAIL=0 UNSUPPORTED=2 NOT_TESTED=4
```

The WSL/SystemC/Verilator predictor-on run produced the same summary. A basic
workload smoke sample reported `steps=9552`, `retired=6453`, `mcycle=0x254f`,
`minstret=0x1935`, and `CPI=1.480087` with predictor-off and with predictor-on.
The predictor-on sample additionally reported 1,524 prediction events, 1,488
predicted-taken events, 1,447 correct predictions, and 77 mispredictions; these
are instrumentation values, not an architectural performance result.

The predictor is therefore suitable for collecting branch behavior data. It is
not yet suitable for claiming a cycle reduction, because a misprediction can
reach wrong-path state before execute-stage observation and there is no tested
pipeline flush protocol.
