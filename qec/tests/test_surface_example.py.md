# Single-shot tutorial tests

Run `python -m pytest qec/tests/test_surface_example.py -q` from the repository root
with the QEC virtual environment active.

The tests execute the checked-in module as a reader would. They verify a real
Stim sample has nonzero detectors, little-endian packing matches the request,
correction edges cancel parity, predictions are bits and the logical-error flag
compares against the observable. A separate invocation parses `--circuit` output
with Stim and verifies its detector/observable counts and two-qubit noise.

The serial-path test uses a local pseudo-terminal to check actual pyserial byte
I/O and reply parsing. It is a host transport test, not FPGA or RTL evidence.
