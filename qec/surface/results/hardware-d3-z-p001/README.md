# Real surface-code hardware run: hardware-d3-z-p001

Actual board210351BE7C3EA on onboard USB UART1, programmed with surface_soc
and surface_app. Source revision bfefc702bd8fc844d6a7bf5db76b10016c0f25aa.
Rotated d3/r3 Z-memory,24 detectors,78 graph edges. Unweighted serial half-edge
union-find/peeling RTL, **not a syndrome LUT and not MWPM**.

- 4096 actual Stim shots, noise0.001, seed20261107.
- Zero RTL/physical prediction mismatches with the fixed union-find reference.
- Logical-observable errors: UF4/4096, PyMatching4/4096,
  identity/no-decoding108/4096. UF and PyMatching disagree on
  4 predictions. Equal error totals do not imply identical decisions.
- Before shots: zero syndrome,24 single detectors,78 graph-edge syndromes,
  and64 dense random windows also matched the UF reference.
- Four malformed-transport cases rejected and recovered; a real zero-length
  reset command reset the PL, followed by successful decode without reprogramming.
- 4268 captured decode transactions plus one separately captured reset command.
- Core measured153–2227 cycles =1.53–22.27 us at configured100MHz across all
  captured windows. This is a real variable-latency counter, not a schedule field.
  Inclusive Stim host/USB/PS/AXI median 15.900884 ms.

`transactions.csv` has exact TX/RX hex, input detectors, physical output,
software-UF reference, measured cycles and host timing. Only kind=stim rows
contain true Stim observables/PyMatching reference values. `summary.json`
includes Wilson95% confidence bounds and exact recovery/reset bytes.
`manifest.json` preserves source/graph/software provenance and hashes19 original
artifacts including bitstream,ELF,XSA,source archive,actual program/status logs,
three core RTL simulations and bridge simulation. This README/verification.json
are explanatory addenda, not replacements for immutable original artifacts.

Independent validation verified all19 hashes, regenerated seeded Stim detectors,
observables and weighted matching predictions, reparsed every request/reply,
re-ran UF on every syndrome and checked that every selected correction-edge set
cancels its syndrome and reproduces its observable prediction.

Only d3 Z has actual board evidence. d3 X and d5 Z are real RTL simulation
checks, not larger-distance board validation. The design is finite-window and
serial, with graph-size state but polynomial scan/relabel latency, not an optimized
near-linear/parallel streaming decoder. Error weights/correlations are not used;
accuracy can be worse than weighted PyMatching. No threshold, adaptive quantum
feedback or physical quantum correction is claimed. See ../../README.md.
