# Host tutorial
Run from repo root: `qec/.venv/bin/python qec/host.py --mode loopback --shots 20000 --seed 90210`. This samples real Stim detector/observable windows and exchanges framed syndromes with software only. JSON reports logical errors and prediction mismatches against noise-matched PyMatching.

## Later board run
Program the QEC UART bitstream separately, confirm 115200 baud and wiring, then run `qec/.venv/bin/python qec/host.py --mode serial --port /dev/ttyUSB1 --baud 115200 --shots 1000 --seed 90210 --timeout 1`. Explicit port is mandatory; the CLI never discovers or opens a board by default. pyserial OS errors are fatal. No board is attached during current experiments. Serial roundtrip includes host scheduling and UART; reported RTL cycles measure acceptance-to-result only. A mismatched-noise table may differ from noise-matched PyMatching.
