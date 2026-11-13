# Actual Zybo USB-only QEC results: hardware-after-reset

Real board `210351BE7C3EA`, `/dev/ttyUSB1`, PS UART1 115200 8N1, ARM firmware,
AXI GPIO and actual PL decoder. No adapter, software prediction endpoint or
pseudo-terminal. Source snapshot: `ae3362bea8b61564ee7bc0623d163a743a20a2bc`.

- 256/256 exhaustive syndrome predictions match the unchanged LUT.
- 4096 real Stim d3/r3 shots, p=0.001, seed=20261106.
- Zero physical prediction mismatches against LUT or noise-matched PyMatching.
- Observable errors: 0/4096; identity/no-decoding errors: 20/4096.
- All replies contain 2 measured PL cycles, 20 ns using configured 100 MHz.
  This is acceptance-to-availability, not USB latency. Status capture is one
  additional FCLK edge. Host-inclusive Stim median: 15.876542 ms;
  p99: 16.573238 ms.
- Bad checksum, garbage and abandoned partial-frame timeout were silent;
  each was followed by a successful valid frame.

`transactions.csv` retains every successful request/reply byte sequence and
Stim observable/reference. `summary.json` is the original runner output;
`manifest.json` hashes all 14 original artifacts including bitstream, ELF,
XSA, source archive and actual program/configuration-status logs. These raw
artifacts were not rewritten when adding this README and verification.json.
The source-status field records output directories as untracked; implementation
source was unchanged. The original LUT SHA-256 remains
`5b701c6d4b7a86f2331a380305758a3209afee1645c2e548b12f27952a3dc905`.

Independent validation checked all 14 hashes, re-created the seeded Stim
syndromes/observables and matching references, reparsed every TX/RX/checksum,
and checked every prediction/cycle value. `verification.json` includes the
95% Wilson logical-error interval. Zero observed errors does not mean zero risk.

**Only Stim rows define logical-error statistics.** The exhaustive rows use
LUT values as placeholder observable/reference fields; their logical_errors
and identity_errors summary fields are not quantum accuracy measurements.
Reset testing is full volatile reprogramming/processor restart, not an isolated
in-flight reset or power cycle. No full bitstream-memory readback, oscilloscope
frequency measurement, adaptive quantum feedback or physical quantum correction
is claimed. Configuration-status readback is DONE/INIT_B/CRC status only.

See [reproduction and timing boundaries](../../hardware-bringup.md).
