# Stim-to-endpoint repetition-code experiment

Start with [QUICKSTART.md](QUICKSTART.md) for a step-by-step explanation, a manual single-window decode, and the complete simulation-to-board flow for both samples.

For the new **algorithmic surface-code version**, see [surface/README.md](surface/README.md): parameterized union-find/peeling RTL, d3 Z actual-board results and d5/X RTL simulation. It uses the same onboard USB/PS infrastructure but a different decoder and widened framing. The latest physical tests leave the **surface image loaded**; reprogram the preserved repetition image before using the repetition host/protocol below.

See [decoder.md](decoder.md) for circuit/LUT generation, [transport.md](transport.md) for exact UART framing and failure behavior, [host.md](host.md) for software loopback and later board CLI, and [experiments.md](experiments.md) for reproducible science and software benchmarks. Every source/test/config has a paired tutorial.

## Quick start (repository root)
```
uv venv --python 3.12 qec/.venv
uv pip install --python qec/.venv/bin/python -r qec/requirements.txt
qec/.venv/bin/python qec/decoder.py
qec/.venv/bin/python -m pytest qec/tests -q
qec/.venv/bin/python qec/host.py --mode loopback --shots 20000 --seed 90210
qec/.venv/bin/python qec/experiments.py --shots 100000 --seed 20261105
```

## Hardware connection and readiness

**USB-only PS/PL path is implemented:** build `top_qec_soc` with `scripts/build_soc.tcl`, then build `vitis/qec/build_app.py` and launch via `scripts/run_soc.tcl`. The Zybo board preset enables PS UART1 MIO on the onboard FTDI; AXI GPIO at `0x41200000` connects the processor to the unchanged PL LUT decoder on a common 100 MHz FCLK. No Pmod adapter is required. See [hardware_run.py.md](hardware_run.py.md), the paired SoC/firmware tutorials, and [hardware-bringup.md](hardware-bringup.md).

**Physical status: verified on actual hardware.** Digilent `210351BE7C3EA` was programmed over onboard USB, and configuration readback shows DONE=1, INIT_B=1, CRC_ERROR=0. All 256 syndromes matched the unchanged LUT, followed by 8192 real Stim shots at p=.01 with zero LUT/PyMatching mismatches (51 observable errors versus 458 without decoding). After volatile reprogramming/PS restart, another exhaustive pass and 4096 p=.001 shots passed (zero observable errors versus 20 without decoding). Bad checksum, garbage and partial-frame timeout recovered in both runs. Every captured transaction returned 2 measured PL cycles: 20 ns at configured 100 MHz, excluding PS/AXI/USB. Stim host roundtrip medians were 15.859 ms and 15.877 ms. See `results/hardware-approved-run/` and `results/hardware-after-reset/`; the earlier approval-blocked snapshot is retained as history.

The separate PL-only UART still requires an external 3.3 V adapter on JE1/V12 and JE2/W16 with common ground; its report-only build does not produce a programmable PS design. Existing historical results remain unchanged.

[rtl_bridge.md](rtl_bridge.md) documents host-to-UART-HDL interaction through Vivado xsim, including 4096 committed raw shots. Run `QEC_RTL=1 qec/.venv/bin/python -m pytest qec/tests -q` to include that integration test. The new PS bridge test independently checks all 256 syndromes, acceptance/availability counter edges and software reset. Neither simulation nor successful programming establishes end-to-end hardware decoding. This is finite-shot repetition-code observable prediction, not physical quantum correction.
