# Stim-to-endpoint repetition-code experiment

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

**Physical status:** a real bitstream was generated and loaded on Digilent `210351BE7C3EA`, and the ARM application was downloaded/started. Configuration readback shows DONE=1, INIT_B=1, CRC_ERROR=0. Routed timing meets the 100 MHz constraint. The first serial transaction command was **blocked by a tool-approval timeout and did not execute**. Consequently no board prediction, corpus correctness, real runtime count, or USB latency has yet been measured. The physical corpus runner is implemented and unit-tested, but its hardware main is unexercised. Renewed serial-tool approval is required before continuing.

The separate PL-only UART still requires an external 3.3 V adapter on JE1/V12 and JE2/W16 with common ground; its report-only build does not produce a programmable PS design. Existing historical results remain unchanged.

[rtl_bridge.md](rtl_bridge.md) documents host-to-UART-HDL interaction through Vivado xsim, including 4096 committed raw shots. Run `QEC_RTL=1 qec/.venv/bin/python -m pytest qec/tests -q` to include that integration test. The new PS bridge test independently checks all 256 syndromes, acceptance/availability counter edges and software reset. Neither simulation nor successful programming establishes end-to-end hardware decoding. This is finite-shot repetition-code observable prediction, not physical quantum correction.
