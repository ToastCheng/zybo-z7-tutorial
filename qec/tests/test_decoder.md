# Exhaustive decoder test
Run `qec/.venv/bin/python -m pytest qec/tests/test_decoder.py -q`. This checks circuit dimensions, little-endian packing and all 256 PyMatching predictions. RED was an absent decoder assertion; GREEN uses real Stim and PyMatching.
