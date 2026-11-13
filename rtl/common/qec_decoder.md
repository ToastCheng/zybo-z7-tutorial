# Full-shot LUT decoder tutorial

`qec_decoder.sv` maps one eight-bit detector vector to one observable prediction using the generated 256-entry `qec/lut.mem`. This is the distance-three repetition code with three complete measurement rounds (eight Stim detection events), **not** an indefinitely streaming rounds decoder. Detector zero is syndrome bit zero (little-endian packing). The host generation uses PyMatching with circuit noise p=0.001; changing that model requires regenerating the ROM.

## Interface and theory

All ports are synchronous to `clk`. Active-high synchronous `rst` aborts work and clears outputs. At an edge with `in_valid && in_ready`, the core captures `syndrome`. At the next edge it reads the ROM; at the second edge it registers `prediction` and asserts `out_valid`. Thus `cycles=2` means rising-edge accept-to-result interval, excluding any input wait, response stall or UART latency. The testbench independently counts those edges. At the default 125 MHz this interval is 16 ns; this is a design interval, not a host end-to-end deadline guarantee.

`out_valid` and the payload stay stable until `out_ready`; `in_ready` is low throughout processing and result holding. There is one outstanding shot, no queue and no simultaneous output retirement/input acceptance. `LUT_FILE` defaults to `qec/lut.mem`, loaded by `$readmemh`; there is no fallback or stub ROM. Reset gates both handshakes. The ROM itself is not reset. Its words use the packed one-bit type `logic [0:0]` because Vivado synthesis ignores `$readmemh` on a scalar unpacked memory. The dedicated build promotes that diagnostic to an error; `python scripts/qec_sim.py --netlist` checks the synthesized truth table.

## Run

From repository root, generate the actual LUT using the qec tooling, then run `python scripts/qec_sim.py`. For implementation run `~/amd/2025.2/Vivado/bin/vivado -mode batch -source scripts/qec_build.tcl -tclargs core`. Reports are generated under `build/qec_core/`.

## Limits

The entire 8-bit domain is tiny and suitable for a LUT; exponential LUT growth makes this architecture unsuitable for arbitrary distance or rounds. This module predicts an observable; it does not apply physical corrections. Simulation compares ROM behavior, not quantum hardware fidelity. Fixed core latency does not bound USB, OS or network scheduling tails.
