import importlib.util
import json
import csv
from pathlib import Path
import sys
import subprocess
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def test_reproducible_sweep_benchmarks_and_charts(tmp_path):
    assert importlib.util.find_spec('experiments') is not None, 'experiments missing'
    import experiments
    import decoder
    assert experiments.wilson(0, 100)[0] == 0
    lo, hi = experiments.wilson(50, 100)
    assert 0.40 < lo < 0.41 and 0.59 < hi < 0.60
    subprocess.run([sys.executable, 'qec/experiments.py', '--shots', '2000', '--seed', '12345', '--out', str(tmp_path)], check=True)
    rows = list(csv.DictReader((tmp_path / 'noise_sweep.csv').open()))
    assert len(rows) == 21
    for i, p in enumerate(experiments.NOISE):
        circuit, matching = decoder.model(p)
        d, obs = circuit.compile_detector_sampler(seed=12345 + i).sample(2000, separate_observables=True)
        expected = {'identity': np.zeros(2000, dtype=np.uint8),
                    'pymatching': matching.decode_batch(d)[:, 0],
                    'fixed_lut': decoder.make_lut()[decoder.pack(d)]}
        for row in rows[3*i:3*i+3]:
            errors = int(np.sum(expected[row['decoder']] != obs[:, 0]))
            assert int(row['errors']) == errors
            assert float(row['ci_low']) <= errors/2000 <= float(row['ci_high'])
    meta = json.loads((tmp_path / 'metadata.json').read_text())
    assert meta['fpga_measured'] is False
    assert meta['seed'] == 12345
    assert meta['num_detectors'] == 8
    timings = list(csv.DictReader((tmp_path / 'timings.csv').open()))
    assert {r['method'] for r in timings} == {'pymatching_batch', 'pymatching_single', 'lut_single', 'lut_batch'}
    assert all(int(r['elapsed_ns']) > 0 for r in timings)
    for filename in ['noise_sweep.png', 'software_performance.png']:
        assert (tmp_path / filename).stat().st_size > 1000
