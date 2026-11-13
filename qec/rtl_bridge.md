# Host-to-real-HDL tutorial
Run from repo root:
```
QEC_RTL=1 qec/.venv/bin/python -m pytest qec/tests -q
qec/.venv/bin/python qec/rtl_bridge.py --shots 4096 --seed 314159 --noise 0.03 --out qec/results > qec/results/rtl_bridge.json
```
This is NOT Python loopback: host Stim generates real noisy detector/observable shots, frames actual A5 requests, and writes request bytes. Vivado xvlog/xelab/xsim compile the hardware agent's actual UART RX/TX, synchronizer, decoder and UART top with qec/tb_host_bridge.sv. The bench drives every UART wire bit and independently receives outgoing wire bits. The host reads those emitted bytes through its bounded response parser in five-byte chunks, validates checksum/sequence/frame count and compares the returned prediction to the committed LUT and PyMatching. Optional --out records all raw per-shot syndromes, ground-truth observables, predictions and cycles.

Vivado defaults to ~/amd/2025.2/Vivado/bin; override VIVADO_BIN if needed. Missing tools, nonzero tool exits, HDL Fatal, missing PASS or malformed response fail rather than substitute software output. Logs and transient wire files are in ignored qec/.rtl/. Runs share that directory: do not run this bridge concurrently. Supports 1..4096 shots per invocation. Functional accelerated UART is not baud-accurate host wall timing, post-route simulation or hardware measurement. Cycle value 2 is decoder acceptance-to-result in the current RTL, not UART latency. Existing hardware regressions can also run independently via `python scripts/qec_sim.py`; this bridge does not modify hardware-agent files.
