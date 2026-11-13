"""Opt-in real Vivado/HDL integration, never replaced by software loopback."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import pytest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.mark.skipif(os.environ.get('QEC_RTL') != '1', reason='set QEC_RTL=1 to run real Vivado RTL')
def test_stim_requests_cross_real_uart_rtl(tmp_path):
    assert importlib.util.find_spec('rtl_bridge') is not None, 'RTL bridge missing'
    result = subprocess.run([sys.executable, 'qec/rtl_bridge.py', '--shots', '256', '--seed', '314159', '--noise', '0.03', '--out', str(tmp_path)],
                            check=True, capture_output=True, text=True, timeout=180)
    report = json.loads(result.stdout)
    assert report['mode'] == 'rtl-uart-simulation'
    assert report['fpga_measured'] is False
    assert report['shots'] == 256
    assert report['prediction_mismatches'] == 0
    assert report['cycles'] == [2]
    assert report['received_frames'] == 256
    import csv
    import decoder
    import numpy as np
    rows = list(csv.DictReader((tmp_path / 'rtl_shots.csv').open()))
    assert len(rows) == 256
    circuit, _ = decoder.model(0.03)
    d, obs = circuit.compile_detector_sampler(seed=314159).sample(256, separate_observables=True)
    np.testing.assert_array_equal([int(r['syndrome']) for r in rows], decoder.pack(d))
    np.testing.assert_array_equal([int(r['observable']) for r in rows], obs[:, 0])
    np.testing.assert_array_equal([int(r['prediction']) for r in rows], decoder.make_lut()[decoder.pack(d)])
