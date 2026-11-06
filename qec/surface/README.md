# Algorithmic surface-code decoder on Zybo

For a guided first run, see [the QEC quick start](../QUICKSTART.md): inspect one noisy window, run RTL, load the board, and send the same window through the FPGA.

This is a separate surface-code implementation beside the preserved repetition
baseline. The USB/PS/AXI infrastructure is reused; the PL decoder is replaced by
**parameterized serial half-edge union-find growth and spanning-forest peeling**.
There is no exponential syndrome LUT and no ARM-side decoding.

## What is supported

- Stim rotated surface-code finite-shot memory circuits, one logical memory
  basis per experiment, including circuit-level noise and terminal detectors.
- Actual programmed board: **d3, 3 rounds, Z memory, 24 detectors, 78 graph edges**.
  Both stabilizer detector sectors are represented, but only the memory-Z logical
  observable is evaluated on this board image.
- RTL simulation: d3 Z (423 cases), d3 X (295), d5 Z (543; **72 detectors,
  278 edges**). Includes single detectors, every graph-edge syndrome, seeded Stim,
  dense random windows, independent cycle-edge checks, backpressure and reset.
- Python correction-parity checks also exercise d3/d5 X/Z graphs.

State is O(V+E). Increasing graph size changes parameters and the edge ROM,
not a table with 2^detectors predictions. This implementation deliberately uses
serial scans and explicit root relabeling; it is **not** an optimized near-linear
union-find engine, a large-distance throughput result, MWPM, or a streaming
quantum-feedback decoder. It ignores matching weights and decomposed-error
correlations. Larger graph firmware width and top parameters require a coordinated
rebuild; the current physical runner intentionally rejects non-24-bit targets.
No qLDPC support or physical quantum correction is claimed.

## Actual hardware results

Board `210351BE7C3EA`, onboard USB `/dev/ttyUSB1`, no Pmod adapter. Configuration
status after volatile programming: DONE=1, INIT_B=1, CRC_ERROR=0. No persistent
flash/SD boot image was written. The surface image remains loaded after tests.

Two independent 4096-shot runs completed:

- p=.001, seed 20261107: **zero hardware/UF-reference mismatches**;
  UF observable errors **4/4096**, weighted PyMatching **4/4096**, identity
  **108/4096**. UF/PyMatching disagree on four predictions. UF Wilson 95%
  error-rate interval: **0.03798–0.25084%**.
- p=.01, seed 20261109: **zero hardware/UF-reference mismatches**;
  UF errors **304/4096**, PyMatching **237/4096**, identity **811/4096**.
  UF/PyMatching disagree on 209 predictions. UF Wilson 95% interval:
  **6.6584–8.2651%**. The accuracy gap is real, not hidden as an RTL failure.

Each run additionally checks zero, 24 single-detector windows, all 78 graph-edge
syndromes and 64 dense random windows. Four malformed-transport cases reject
and recover (checksum, garbage, partial timeout, invalid length). A real reset
packet pulses PL reset and is followed by a successful zero-window decode.
Combined archives contain **8536 decode transactions plus two reset controls**.
They are not exhaustive over all 2^24 syndromes.

### Timing and resources

- Real PL instrumented latency across captured windows: **153–2227 cycles**,
  **1.53–22.27 us** at configured **100 MHz**. Counter measures core acceptance
  to output availability and includes per-shot initialization and scans.
- Host-inclusive Stim median: **15.900884 ms** at p=.001 and **15.843418 ms**
  at p=.01. USB/UART/PS/AXI time is not core time. No feedback deadline or
  CPU speedup is inferred. Clock frequency was not independently scope-measured.
- Whole SoC routed utilization: **1801 LUTs, 1328 FFs, 0 BRAM tiles**.
  Routed setup WNS **0.089 ns**, hold WHS **0.040 ns** at 100 MHz; constraints
  met. Margin is small and larger-distance fit/timing has not been established.
- Digilent PS preset DDR negative-skew parameter warnings are retained;
  configuration status readback is not full bitstream-memory readback.

## Reproduce from repository root

```sh
PY=qec/.venv/bin/python
VIVADO=/home/toastcheng/amd/2025.2/Vivado/bin
VITIS=/home/toastcheng/amd/2025.2/Vitis/bin

$PY -m pytest qec/tests -q
$PY qec/surface/sim.py --distance 3 --basis z --shots 256 > build/surface_sim_d3.log 2>&1
$PY qec/surface/sim.py --distance 5 --basis z --shots 128 > build/surface_sim_d5.log 2>&1
$PY qec/surface/sim.py --distance 3 --basis x --shots 128 > build/surface_sim_x.log 2>&1
$VIVADO/xvlog --sv rtl/common/surface_decoder.sv rtl/common/surface_ps_bridge.sv qec/surface/tb_bridge.sv
$VIVADO/xelab tb_surface_bridge -s surface_bridge
$VIVADO/xsim surface_bridge -runall > build/surface_bridge_sim.log 2>&1
$VIVADO/vivado -mode batch -source scripts/build_soc.tcl -tclargs top_surface_soc > build/surface_build.log 2>&1
$VITIS/vitis -s vitis/surface/build_app.py > build/surface_firmware_build.log 2>&1
$VITIS/xsct scripts/run_soc.tcl build/surface_soc.bit build/vitis_ws/surface_app/build/surface_app.elf build/surface_soc.xsa > build/surface_program.log 2>&1
$VIVADO/vivado -mode batch -source scripts/qec_readback.tcl > build/surface_readback.log 2>&1
$PY qec/surface/host.py --port /dev/ttyUSB1 --board-id 210351BE7C3EA --shots 4096 --noise .001 --seed 20261107 --out qec/surface/results/hardware-reproduce-01
```

Use a fresh output folder. Require the PASS/no-Fatal markers in each xsim log:
xsim can exit zero after an HDL fatal. `sim.py` enforces this for core runs.
The bridge bench expects the d3 423-case vector file generated above.
For the second noise point use `.01`, seed `20261109`, another fresh folder.
The generic repetition host/framing is incompatible with this surface image;
use the paired [surface firmware protocol](../../vitis/surface/src/main.c.md).
To return to repetition, volatile-program its preserved qec_soc image and ELF.

## Evidence and provenance

- [Low-noise board run](results/hardware-d3-z-p001/README.md)
- [Higher-noise board run](results/hardware-d3-z-p01/README.md)
- [Algorithm/reference and graph export](decoder.py.md)
- [Actual RTL simulation](sim.py.md)
- [Physical corpus capture](host.py.md)

Each immutable run manifest hashes 19 raw artifacts: source snapshot, graph
configuration, bitstream/ELF/XSA, tool/program/configuration-status reports,
three core simulations, bridge simulation, CSV and summary. Independent replay
verified all hashes, exact seeded Stim detectors/observables and matching
predictions, every UART frame, and every correction's detector parity/observable.
READMEs and verification.json are later explanatory addenda. All original
repetition datasets, bitstream archives and qec/lut.mem remain unchanged.

Strict TDD RED/GREEN was exercised for graph generation, reference decoding,
export, RTL core, GPIO bridge, firmware parser and widened host framing/entrypoint.
Final regression: **14 pytest tests passed**, plus actual xsim and native C parser
runs. This first version provides a real algorithmic/hardware baseline; weighted
noise-aware growth, larger-distance hardware builds, parallelization, streaming
windows and full Pauli-frame output remain further development.
