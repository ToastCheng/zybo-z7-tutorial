# Algorithmic surface decoder reference and graph export
Use `qec/.venv/bin/python qec/surface/decoder.py --distance 3 --basis z --out qec/surface/graphs/d3_z_r3`.
Stim rotated memory circuits contain both stabilizer detector sectors; one logical
memory basis/observable is evaluated per run. PyMatching supplies graphlike DEM
edges including boundary and observable labels, NOT a syndrome prediction table.
The reference grows odd clusters in deterministic sorted edge order, counts two
half edges per complete edge, unions with explicit root relabeling, retains a
spanning forest and peels its non-boundary leaves. The boundary root absorbs odd
parity. Corrections must cancel every input detector; XOR edge observable labels
produce the logical-frame prediction. Disconnected odd components return error.

This first RTL-matched variant is unweighted, serial and finite-window. It is
not MWPM, weighted union-find, near-linear optimized union-find or a threshold
claim. Decomposed correlated DEM edges are treated independently. Storage is
O(V+E); serial scans/relabeling have polynomial latency that grows with graph size.
Distance/round/basis regenerate graph configuration, not a 2^detectors LUT.
Export writes packed endpoint/observable edge ROM and JSON provenance/hash.
Tests verify synthetic correction parity and d3/d5 X/Z sampled windows.
