# Software-only endpoint run
`qec/.venv/bin/python qec/host.py --mode loopback --shots 20000 --seed 90210` generated held-out Stim windows at p=.001, with 3 logical failures vs identity 109 and no PyMatching prediction mismatches. Loopback cycles zero are explicit placeholders. Host Python roundtrip timing includes framing but no real UART, FPGA or RTL. Timing varies across runs.
