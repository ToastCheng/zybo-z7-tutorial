# Physical surface-code runner

Run from repository root after building/programming surface_soc and surface_app:
`qec/.venv/bin/python qec/surface/host.py --port /dev/ttyUSB1 --board-id 210351BE7C3EA --shots 4096 --noise .001 --seed 20261107 --out qec/surface/results/hardware-d3-z-p001`.
The explicit port/board/output arguments are mandatory; no loopback mode exists.
Use a fresh output directory. The board ID is supplied metadata, corroborated by
actual program/readback logs rather than authenticated by the UART packet.

Request C3/seq/length/packed detector bytes/XOR; response3C/seq/status/prediction/
32-bit little-endian cycles/XOR. Reset uses zero request length. Invalid reply
status, sequence, checksum and length are fatal. Current image is24 detector bits.
The runner sends zero, single-detector, every graph-edge error, dense random and
seeded actual Stim detector windows through the physical endpoint. It compares
against the fixed unweighted union-find reference, and separately compares
logical-observable accuracy with noise-matched weighted PyMatching and identity.
Those decoders need not agree; disagreements are data, not an RTL failure.

It then injects checksum/garbage/partial-timeout/length errors, proves next-frame
recovery, executes a real PL reset command without reprogramming and decodes zero
again. Raw CSV captures exact TX/RX bytes, measured core cycles, inclusive host
timing and true Stim observables only for kind=stim. Summary provides Wilson95%
bounds. Manifest archives graph, source revision/snapshot, bitstream/ELF/XSA,
tool/program/status logs and SHA-256 values. Earlier datasets are untouched.

TDD: missing framing first failed pytest; then wrong reply/checksum/sequence/width
checks passed. Missing main failed the explicit-target test, then the CLI was
implemented and verified to reject implicit serial targets before opening a port.
Main's real transport/decoder boundary must additionally pass on actual hardware.
Core counter excludes PS/MMIO/USB overhead; no system reaction deadline or physical
quantum correction is established. d5/X simulation is not d5/X board evidence.
