"""Fixed d3/r3 repetition-code observable predictor."""
import numpy as np
import stim
import pymatching


def model(p=0.001):
    circuit = stim.Circuit.generated(
        'repetition_code:memory', distance=3, rounds=3,
        after_clifford_depolarization=p, before_round_data_depolarization=p,
        before_measure_flip_probability=p, after_reset_flip_probability=p)
    if circuit.num_detectors != 8:
        raise ValueError('hardware requires exactly 8 detectors')
    return circuit, pymatching.Matching.from_detector_error_model(
        circuit.detector_error_model(decompose_errors=True))


def pack(detectors):
    return np.asarray(detectors, dtype=np.uint8) @ (1 << np.arange(8))


def make_lut():
    _, matching = model()
    syndromes = ((np.arange(256)[:, None] >> np.arange(8)) & 1).astype(np.uint8)
    return matching.decode_batch(syndromes)[:, 0].astype(np.uint8)


if __name__ == '__main__':
    from pathlib import Path
    np.savetxt(Path(__file__).with_name('lut.mem'), make_lut(), fmt='%x')
