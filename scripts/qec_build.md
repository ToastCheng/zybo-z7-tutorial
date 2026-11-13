# QEC synthesis and routing tutorial

`qec_build.tcl` isolates QEC from unrelated project RTL and avoids the general build's bitstream/programming workflow. It targets `xc7z010clg400-1`, loads the real `qec/lut.mem` and runs synthesis, optimization, placement and routing with four threads. It never accesses hardware or writes a bitstream.

## Invocation

From repository root (generate the host LUT first):

```sh
mkdir -p build
~/amd/2025.2/Vivado/bin/vivado -mode batch -source scripts/qec_build.tcl \
  -log build/qec_core.log -journal build/qec_core.jou -tclargs core
~/amd/2025.2/Vivado/bin/vivado -mode batch -source scripts/qec_build.tcl \
  -log build/qec_uart.log -journal build/qec_uart.jou -tclargs uart
python scripts/qec_sim.py
python scripts/qec_sim.py --netlist
```

Mode is `core` or `uart` (default UART). The script normalizes its repository location before reading sources. Reports/checkpoints go in `build/qec_core/` or `build/qec_uart/`: `post_synth_utilization.rpt`, `post_synth_timing.rpt`, `post_synth.dcp`, functional `post_synth.v`, `post_route_utilization.rpt`, `post_route_timing.rpt`, `post_route_drc.rpt`, and `post_route.dcp`. Completion requires setup and hold paths with nonnegative slack. The generated functional core netlist is exhaustively checked by the same scoreboard with `--netlist`.

## Constraints and interpretation

Core mode is out-of-context at 8 ns with explicit 0.5 ns virtual input/output budgets; its interface routes and upstream clock placement are not a board timing signoff. UART mode reads the existing board pin XDC and its physical 125 MHz clock. External asynchronous UART/button/switch inputs and asynchronous UART/LED outputs are false-pathed at the port boundary only; internal synchronizer and functional register paths remain timed. There is no synchronous external capture clock for these outputs. No claim about analog metastability MTBF or UART electrical margin follows from static timing.

Vivado emits expected out-of-context clock-source/partition-pin warnings in core mode. DRC reports the existing PL-only Zynq design's `ZPS7-1` warning (PS7 block required); no PS7 is instantiated by this milestone. These builds deliberately stop before bitstream generation. Review actual reports rather than treating process exit status as board qualification.

## Observed results (Vivado 2025.2)

| Routed design | Slice LUTs | Flip-flops | BRAM | DSP | WNS | WHS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Core, OOC | 9 | 15 | 0 | 0 | 3.930 ns | 0.059 ns |
| UART board top | 106 | 132 | 0 | 0 | 3.513 ns | 0.146 ns |

Both report zero setup/hold failing endpoints, zero unconstrained internal endpoints and an 8 ns requested clock. The UART build uses 11 IOBs and one BUFG. These are tool-observed implementation results, not measured board performance or a maximum-frequency characterization.

## ROM inference pitfall and regression

A scalar unpacked array (`logic lut [0:255]`) simulated correctly but Vivado ignored its `$readmemh`, removed the syndrome address and synthesized a bogus constant ROM. The actual error was `Synth 8-2898: ignoring malformed $readmem task: invalid memory name`. The core therefore uses **packed one-bit words**, `logic [0:0] lut [0:255]`. This script promotes that synthesis message to ERROR. Functional post-synthesis simulation additionally checks every LUT entry, two-cycle timing, held-output backpressure and reset abort, so a successful synthesis with an incorrectly inferred ROM is not accepted as sufficient evidence.

The synthesized truth table may optimize to LUT logic rather than a RAM primitive; zero LUT-as-memory usage does not mean the source table was omitted. Changing code distance, rounds or decoder/noise model requires regenerating the table and repeating all tests. Observed timing and host tail latencies are not a hard real-time deadline guarantee.
