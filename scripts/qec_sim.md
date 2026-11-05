# Isolated HDL simulation tutorial

Run `python scripts/qec_sim.py` from any directory after generating `qec/lut.mem`. Python 3 and Vivado xsim tools are required. `VIVADO_BIN` can override the default `~/amd/2025.2/Vivado/bin` directory.

The script compiles only the QEC core/top, existing UART/synchronizer dependencies and two QEC testbenches. It creates `build/qec_sim/`, links its `qec` directory to the real source data (so `$readmemh` resolves correctly), elaborates both testbenches and runs each to completion. It rejects a tool error, HDL Fatal or missing PASS marker. Tool logs and wave databases remain in the build directory; no source files are generated or mutated.

Add `--netlist` after the core build to simulate `build/qec_core/post_synth.v` against the exhaustive core bench in an isolated `build/qec_netlist_sim/` directory. This mode uses Vivado UNISIM primitives and global startup reset. The bench holds reset for 160 ns so it starts after the 100 ns configuration reset. It verifies that synthesis preserved the real ROM truth table.

These are functional RTL or post-synthesis simulations, not post-route timing simulation, fault injection into physical qubits or board programming. An absent real LUT is an error, never replaced by a stub.
