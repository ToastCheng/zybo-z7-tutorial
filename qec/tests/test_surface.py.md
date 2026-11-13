# Surface reference TDD
Run `qec/.venv/bin/python -m pytest qec/tests/test_surface.py -q`.
RED stages: missing decoder, missing decode operation, missing graph export.
GREEN stages implement each behavior separately. Tests check a 24-detector d3
surface graph, endpoint/observable ROM roundtrip, small independent chain
examples, disconnected odd failure, widened-frame checksum/sequence/width checks,
explicit physical-target CLI rejection, and explicit correction-syndrome cancellation
on actual Stim d3/d5 X/Z circuits. No equality with optimal matching is assumed.
