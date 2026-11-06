# QEC quick start: manually decode a complete window

Run all commands from the **repository root**. This guide uses the algorithmic
**surface-code sample** first (distance 3, three rounds, Z memory), then shows
how to switch to the smaller repetition-code LUT sample.

## 1. What actually happens?

```text
Host PC: Stim noisy circuit → measurement-derived detectors (24 bits)
    → USB UART → ARM firmware (PS) → AXI GPIO → FPGA decoder (PL)
    → union-find growth + forest peeling → predicted logical flip
    → AXI GPIO → ARM → USB UART → host compares with Stim's true observable
```

A detector bit records a measurement-parity change relative to the circuit's
expected behavior. A complete set for one shot is the decoder input; bit i goes
in integer bit i (little-endian packing). The decoder groups detection events
using the graph, then selects correction edges by peeling a spanning forest.
The XOR of their logical-observable labels is the predicted logical flip.

Stim supplies both the detector input and the true logical flip for evaluation.
**The true flip is not sent to the FPGA.** A prediction of 1 means invert the
logical measurement interpretation; it is not a command to physically flip a
qubit. The sample does not connect to a quantum processor, execute physical
corrections, or run continuous feedback. It processes completed simulated shots.

**Agent-selected starting point:** use the surface sample to see an algorithm
run in hardware. The repetition sample instead indexes a 256-entry prediction
LUT. Their firmware, bitstreams and packet formats are incompatible.

## 2. Prepare Python (no board needed)

```sh
uv venv --python 3.12 qec/.venv
uv pip install --python qec/.venv/bin/python -r qec/requirements.txt
PY=qec/.venv/bin/python
mkdir -p build
$PY -m pytest qec/tests -q
```

If `qec/.venv` already exists, reuse it and skip creation. Python requirements
include Stim, PyMatching, NumPy, pyserial and pytest. Vivado/Vitis are only needed
for the later RTL/build/board steps.

## 3. Manually inspect one noisy shot in software

Save this as `build/manual_surface.py`. It chooses the first nonzero detector
window from a seeded batch (or the first window if all are zero), runs the
reference algorithm against the **committed hardware graph**, and checks the
correction's detector parity independently.

```python
import json
from pathlib import Path

import stim
from qec.surface.decoder import decode

config = json.loads(Path("qec/surface/graphs/d3_z_r3.json").read_text())
circuit = stim.Circuit(config["circuit"])
detectors, observables = circuit.compile_detector_sampler(seed=20261107).sample(
    32, separate_observables=True
)
index = next((i for i, row in enumerate(detectors) if row.any()), 0)
syndrome = sum(int(bit) << i for i, bit in enumerate(detectors[index]))
result = decode(config["detectors"], config["edges"], syndrome)
assert not result["error"]

residual = syndrome
for edge in result["correction_edges"]:
    a, b, _ = config["edges"][edge]
    residual ^= 1 << a
    if b < config["detectors"]:  # the extra vertex is the boundary
        residual ^= 1 << b
assert residual == 0

window = dict(
    syndrome=syndrome,
    observable=int(observables[index, 0]),
    prediction=result["prediction"],
    correction_edges=result["correction_edges"],
)
Path("build/manual_surface_window.json").write_text(json.dumps(window, indent=2))
print(json.dumps(window, indent=2))
print("Logical error:", window["prediction"] != window["observable"])
```

```sh
PYTHONPATH=. $PY build/manual_surface.py
```

`syndrome` is the packed 24-bit input, `correction_edges` indexes the graph's
edges, and `prediction` is the one-bit answer. Zero residual means the selected
edges explain the detector parity; it does **not** guarantee the correct logical
answer. Different errors can produce the same detectors. A logical error is a
prediction different from Stim's observable, not necessarily an implementation
bug. The FPGA returns prediction and cycle count, not the correction-edge list.

## 4. Run the actual RTL before using a board

These commands use the installed AMD 2025.2 tools. Adjust paths for your machine.
The current `surface/sim.py` itself expects `$HOME/amd/2025.2/Vivado/bin`.

```sh
VIVADO="$HOME/amd/2025.2/Vivado/bin"
VITIS="$HOME/amd/2025.2/Vitis/bin"

$PY qec/surface/sim.py --distance 3 --basis z --shots 256 > build/surface_sim_d3.log 2>&1
$PY qec/surface/sim.py --distance 5 --basis z --shots 128 > build/surface_sim_d5.log 2>&1
$PY qec/surface/sim.py --distance 3 --basis x --shots 128 > build/surface_sim_x.log 2>&1
$VIVADO/xvlog --sv rtl/common/surface_decoder.sv rtl/common/surface_ps_bridge.sv qec/surface/tb_bridge.sv
$VIVADO/xelab tb_surface_bridge -s surface_bridge
$VIVADO/xsim surface_bridge -runall > build/surface_bridge_sim.log 2>&1
```

Run each command only after the previous one succeeds. Core logs must contain
`PASS algorithmic surface`; the bridge log must contain
`PASS surface AXI GPIO bridge`. Reject any `Fatal:`/`FATAL`, even if xsim exits
zero. The core runner checks these markers automatically. Keep the d3 Z run at
256 shots: the bridge bench reads its generated 423-case vector file.
The d5/X runs validate RTL configurations, **not** those configurations on board.

## 5. Build and load the surface SoC

Use a **Zybo Z7-10**, powered and connected through **PROG/UART USB**. This
USB-only design uses the ARM's UART; no Pmod wiring is needed. Install the
Digilent Zybo board files and AMD cable drivers if not already available.

```sh
$VIVADO/vivado -mode batch -source scripts/build_soc.tcl -tclargs top_surface_soc > build/surface_build.log 2>&1
$VITIS/vitis -s vitis/surface/build_app.py > build/surface_firmware_build.log 2>&1
```

Require successful builds and the actual files `build/surface_soc.bit`,
`build/surface_soc.xsa`, and
`build/vitis_ws/surface_app/build/surface_app.elf` before proceeding. Review
build errors/DRCs and routed timing reports; a checkpoint is not a bitstream.

Discover the serial port (do not assume it is always `/dev/ttyUSB1`):

```sh
$PY -m serial.tools.list_ports -v
```

The board's FTDI UART was `/dev/ttyUSB1` in archived runs; its recorded board
serial was `210351BE7C3EA`. Use your actual UART port and board serial below.
Close any serial monitor before running a host script. Ensure your account has
serial-device access (commonly membership in `dialout`; log in again after a
membership change).

**The next command replaces the running FPGA design and restarts ARM core 0.**
It loads volatile state over JTAG; it does not write flash or SD storage.

```sh
$VITIS/xsct scripts/run_soc.tcl build/surface_soc.bit build/vitis_ws/surface_app/build/surface_app.elf build/surface_soc.xsa > build/surface_program.log 2>&1
$VIVADO/vivado -mode batch -source scripts/qec_readback.tcl > build/surface_readback.log 2>&1
```

Require successful programming and configuration status DONE=1, INIT_B=1,
CRC_ERROR=0 in the readback log. This checks configuration status, not full
bitstream-memory readback or successful decoding. Power loss requires reloading.

## 6. Send exactly the window you inspected

Save as `build/manual_surface_board.py`. It sends one binary request; this is
not a text-terminal protocol. Run only with the matching surface image loaded.

```python
import json
import sys
from pathlib import Path

import serial
from qec.surface.host import request, parse

window = json.loads(Path("build/manual_surface_window.json").read_text())
seq = 0
tx = request(seq, window["syndrome"])
with serial.Serial(sys.argv[1], 115200, timeout=1, write_timeout=1) as port:
    port.reset_input_buffer()
    assert port.write(tx) == len(tx)
    rx = port.read(9)
prediction, cycles = parse(rx, seq)
print("TX:", tx.hex(), "RX:", rx.hex())
print("prediction:", prediction, "PL cycles:", cycles)
assert prediction == window["prediction"], "FPGA/reference mismatch"
assert cycles > 0
print("Logical error:", prediction != window["observable"])
```

```sh
PORT=/dev/ttyUSB1  # replace with the discovered board UART
BOARD_ID=210351BE7C3EA  # replace with your board's serial
PYTHONPATH=. $PY build/manual_surface_board.py "$PORT"
```

Request: `C3 | sequence | payload-length=03 | 3 syndrome bytes | XOR checksum`.
Reply: `3C | sequence | status | prediction | 4 cycle bytes | XOR checksum`.
Multi-byte fields are little-endian. `parse()` validates framing, checksum,
sequence and success status. Core time in ns is `cycles * 10` for the configured
100 MHz FCLK. This excludes host, USB, UART, ARM and AXI time.

## 7. Run and inspect the complete captured experiment

After **all** simulation/build/program/readback steps above, run:

```sh
$PY qec/surface/host.py --port "$PORT" --board-id "$BOARD_ID" --shots 4096 --noise .001 --seed 20261107 --out build/manual-surface-run
```

Use a fresh output directory every time. The runner first checks zero, single
detectors, graph-edge syndromes and dense windows, then samples and decodes the
Stim shots. It also tests malformed-packet recovery and explicit PL reset.
The `--board-id` value is an archive label, not automatic board identification.

Inspect `build/manual-surface-run/summary.json` and `transactions.csv`:

- `uf_mismatches` must be zero: hardware agrees with this algorithm's reference.
- `logical_errors` counts FPGA predictions different from true Stim observables.
- `pymatching_logical_errors` is a weighted matching baseline; disagreements with
  this different algorithm are not automatically RTL failures.
- `cycles_min/median/max` measures the PL boundary; `host_stim_ns_median` includes
  the serial transaction. Do not interpret one as the other.
- Only `kind=stim` CSV rows support sampled logical-error statistics. Other rows
  are diagnostics. `manifest.json` hashes the archived files.

The capture runner also copies all three simulation logs, bridge log, build and
program/readback logs, timing/utilization reports, bitstream, XSA and ELF. Missing
prerequisite artifacts can fail archiving **after** transactions have run; do not
skip earlier steps or reuse stale logs from another build. Avoid source edits
between build and capture: its source snapshot is `git archive HEAD`, with dirty
status recorded separately. There is no software-loopback fallback in this path.

## 8. Prefer the smaller repetition-code sample?

For a no-board software demo:

```sh
$PY qec/host.py --mode loopback --shots 20000 --seed 90210
```

For actual board decoding, replace **both** the surface bitstream and firmware:

```sh
$VIVADO/vivado -mode batch -source scripts/build_soc.tcl -tclargs top_qec_soc > build/qec_soc_build.log 2>&1
$VITIS/vitis -s vitis/qec/build_app.py > build/qec_firmware_build.log 2>&1
$VITIS/xsct scripts/run_soc.tcl build/qec_soc.bit build/vitis_ws/qec_app/build/qec_app.elf build/qec_soc.xsa > build/qec_program.log 2>&1
$VIVADO/vivado -mode batch -source scripts/qec_readback.tcl > build/qec_readback.log 2>&1
$PY qec/hardware_run.py --port "$PORT" --board-id "$BOARD_ID" --shots 4096 --noise .001 --seed 20261105 --out build/manual-repetition-run
```

Apply the same build/configuration checks as above before sending requests.
This sample packs eight detectors into one byte; the PL looks up a logical flip
in `qec/lut.mem`. The runner exhausts all 256 inputs, samples real Stim shots,
and checks malformed-frame recovery. Evaluate sampled accuracy under the
summary's `stim` object, not the diagnostic `exhaustive` object. Its four-byte
request/six-byte response is **not** the surface protocol. To return to surface,
repeat the surface load command in step 5 with its own bitstream, ELF and XSA.

## Troubleshooting and further reading

- **No UART/JTAG device:** check board power, data-capable USB cable, drivers and
  permissions. Seeing a UART does not establish a working JTAG connection.
- **Timeout/invalid reply:** close serial monitors; confirm port, 115200 baud,
  successful ARM start, and matching bitstream/firmware/host. Do not assume the
  previously loaded image survived a power cycle.
- **Prediction differs from Stim but matches reference:** possible decoder error;
  syndrome agreement alone does not establish logical success.
- **Want PL-only UART?** That separate design needs a 3.3 V TTL adapter on
  JE1/V12 (FPGA RX), JE2/W16 (FPGA TX), and ground. The onboard USB UART does
  not directly reach those PL pins. `scripts/qec_build.tcl` is report-only,
  not a replacement for the SoC bitstream build.

See [surface/README.md](surface/README.md) for scope and archived board results,
[surface/decoder.py.md](surface/decoder.py.md) for the algorithm,
[surface/host.py.md](surface/host.py.md) for capture details, and
[README.md](README.md) for the repetition baseline.
