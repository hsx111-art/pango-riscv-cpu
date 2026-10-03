# Pango PDS Bring-up Checklist

This checklist records the information needed to turn the vendor-neutral RTL
baseline into a reproducible Pango FPGA implementation. Until the first real
PDS report is available, implementation metrics must remain `Not measured`.

## Tool and target

- [ ] PDS version and exact installation path recorded
- [ ] FPGA device part number recorded
- [ ] Development board name and revision recorded
- [ ] PDS project template or command-line flow archived
- [ ] Repository commit used for the build recorded

## Top-level integration

- [ ] Final competition top selected (`competition_top` or a board wrapper)
- [ ] Clock input and target frequency recorded
- [ ] Reset polarity, synchronization and release sequence recorded
- [ ] UART TX/RX pins assigned
- [ ] GPIO pins assigned and direction semantics checked
- [ ] Timer/interrupt source connection checked
- [ ] External memory or DDR requirement decided
- [ ] TCM RAM inference strategy checked in synthesis

## Constraints and implementation

- [ ] Pin constraint file added without vendor-specific RTL changes
- [ ] Clock constraint file added
- [ ] Synthesis completes without inferred-latch or undriven-port errors
- [ ] Place and route completes
- [ ] Timing report captured, including WNS/TNS and critical path
- [ ] Resource report captured for LUT, FF, BRAM and DSP
- [ ] Bitstream generated and hash recorded

## Board validation

- [ ] UART boot marker observed
- [ ] GPIO output marker observed
- [ ] GPIO input loopback or board stimulus checked
- [ ] Timer interrupt demonstration observed
- [ ] CoreMark smoke image loaded and CRC checked
- [ ] INT8 workload checksum checked
- [ ] Clock frequency and runtime measured with the same software image used in simulation

## Evidence record

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

The current repository has no Pango device, board constraint or PDS project
metadata. That is an external bring-up dependency, not evidence of an RTL
failure.
