# AI Application Route

The project has a repeatable RV32IM INT8 kernel baseline, but it does not yet
claim a complete AI demo. The delivery path below keeps the software and CPU
work measurable before introducing a custom instruction or accelerator.

## Current evidence

The fixed workloads in `verification/ai_microbench/` are:

| Kernel | Purpose | Current interval with MUL E1 bypass |
| --- | --- | ---: |
| `dot_i8` | 64-element signed INT8 dot product | 12,368 cycles |
| `gemm_i8` | 8x8x8 INT8 matrix multiply | 125,841 cycles |
| `conv_i8` | 8x8 output, 3x3 INT8 convolution | 159,922 cycles |
| `relu_i8` | INT8 affine ReLU/clamp | 18,000 cycles |

All four checksums pass in the WSL/Verilator and Windows/ModelSim flows. The
architectural `mcycle`/`minstret` interval is the comparison authority.

## Candidate demonstration

The preferred application route is a small quantized object-detection or image
classification demo:

```text
image or sensor input
    -> fixed-point preprocessing
    -> quantized lightweight model
    -> INT8 convolution / activation kernels
    -> class or bounding-box result
    -> UART, GPIO or board display
```

The exact model must be selected only after measuring the available TCM/DDR
capacity, operator set and board IO. A model is not accepted merely because it
fits in a host-side simulator.

## Feasibility gate

Before implementing a custom instruction, record:

- model name and license
- input dimensions and quantization scheme
- weight and activation memory at peak
- operator list and unsupported operators
- estimated cycles for the current RV32IM kernels
- required external memory bandwidth
- expected UART/display output format
- FPGA resource and clock assumptions

The current INT8 results show a useful CPU-only baseline. They do not yet prove
that packed INT8 hardware is the dominant bottleneck. A custom 4xINT8 dot or
packed MAC should only be added after the model profile shows that arithmetic
instructions dominate and load/store bandwidth is not the limiting factor.

## Delivery stages

1. Keep the four kernel checksums and counter intervals as regression gates.
2. Choose one small model and produce a host-side quantized reference output.
3. Port only the required operators to the bare-metal runtime.
4. Demonstrate the result through the competition UART/GPIO path.
5. Profile again on the target FPGA before deciding on a custom instruction.

No YOLO, sensor or display integration is claimed until the board and PDS
inputs are available and the complete data path has a reproducible checksum or
observable result.
