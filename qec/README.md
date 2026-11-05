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

No FPGA is connected or measured. [rtl_bridge.md](rtl_bridge.md) documents actual host-to-UART-HDL interaction through Vivado xsim, including 4096 committed raw shots. Run `QEC_RTL=1 qec/.venv/bin/python -m pytest qec/tests -q` to include that integration test. Software-loopback is not RTL simulation. The circuit has 8 little-endian detector bits and one logical observable. Fixed d3/r3 finite-shot repetition memory handles one error type; it is not a streaming/full-QEC decoder. RTL acceptance-to-result cycle counts exclude UART latency. At p=.001, the committed 100000-shot corpus gives identity 573 errors vs PyMatching and LUT each 2 errors, with 95% Wilson bounds in CSV. Software batch throughput and single-call latency must remain separate.
