# Graph configurations, not syndrome LUTs
Each .mem word packs endpoint A, endpoint B and one logical-observable label.
The paired .json contains the Stim circuit, distance/round/basis, generator
versions, edge list and memory SHA-256. Boundary index equals detector count.
The core computes predictions by growth/union/peeling; storage scales with
vertices/edges rather than 2^detectors. d3 Z is the first board build; d3 X and
d5 Z are larger/alternate-basis RTL simulation configurations. Their existence
alone is not board validation. Generate with ../decoder.py, not by hand.
