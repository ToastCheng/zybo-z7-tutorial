import importlib.util
from pathlib import Path
import sys
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def test_lut_matches_all_pymatching_syndromes():
    assert importlib.util.find_spec('decoder') is not None, 'decoder module not implemented'
    import decoder
    circuit, matching = decoder.model(0.001)
    assert circuit.num_detectors == 8
    assert circuit.num_observables == 1
    table = decoder.make_lut()
    syndromes = ((np.arange(256)[:, None] >> np.arange(8)) & 1).astype(np.uint8)
    assert table.shape == (256,)
    np.testing.assert_array_equal(table, matching.decode_batch(syndromes)[:, 0])
    np.testing.assert_array_equal(decoder.pack(syndromes), np.arange(256))
