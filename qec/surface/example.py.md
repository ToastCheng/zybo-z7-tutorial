# Single-shot surface-code example

Run from the repository root after activating `qec/.venv`:

```sh
python -m qec.surface.example
python -m qec.surface.example --circuit
# Only after loading the matching surface bitstream and ARM firmware:
python -m qec.surface.example --port /dev/ttyUSB1
```

[QUICKSTART.md](../QUICKSTART.md) explains each small code section, the actual
circuit and its noise instructions, detector packing and byte-level requests
and replies. The module keeps the software and optional board example together;
it requires no copied script or intermediate window file.

The example samples 256 shots with seed 20261107 from the committed d3 Z-memory
circuit and chooses the first nonzero detector window. This selection illustrates
a decoder input; it is not an unbiased accuracy experiment. It checks correction
parity and prints both the union-find prediction and weighted PyMatching baseline
alongside Stim's true observable. A nonzero residual or a union-find error fails.
`--circuit` prints only the actual full Stim text, without contacting a board.

With `--port`, the same shot is sent as a seven-byte request at 115200 baud; the
nine-byte reply is validated by the existing protocol parser. Hardware must match
the Python union-find reference, not necessarily PyMatching. Serial failures do
not fall back to software. The script does not build/program hardware or capture
a complete provenance archive; use `host.py` for the full experiment.

The fixed seed is reproducible within the installed Stim version; circuit text
and graph order stay pinned to the committed metadata. The selected shot may
change with Stim versions. If no detector fires in the fixed batch, the example
fails rather than silently substituting a different input.
