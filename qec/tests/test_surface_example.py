"""Exercise the checked-in single-shot tutorial without a board."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def test_surface_example_explains_a_real_noisy_shot():
    run = subprocess.run(
        [sys.executable, '-m', 'qec.surface.example'],
        cwd=ROOT, text=True, capture_output=True,
    )
    assert run.returncode == 0, run.stderr
    window = json.loads(run.stdout)
    assert window['detector_indices']
    assert window['syndrome'] == sum(1 << i for i in window['detector_indices'])
    assert window['residual'] == 0
    assert window['observable'] in (0, 1)
    assert window['pymatching'] in (0, 1)
    assert window['logical_error'] == (window['prediction'] != window['observable'])
    from qec.surface.host import request
    assert window['tx_hex'] == request(0, window['syndrome']).hex(' ')


def test_surface_example_prints_the_actual_circuit():
    run = subprocess.run(
        [sys.executable, '-m', 'qec.surface.example', '--circuit'],
        cwd=ROOT, text=True, capture_output=True,
    )
    assert run.returncode == 0, run.stderr
    import stim
    circuit = stim.Circuit(run.stdout)
    assert circuit.num_detectors == 24
    assert circuit.num_observables == 1
    assert 'DEPOLARIZE2(0.001)' in str(circuit)


def test_surface_example_serial_path():
    import os
    import pty
    import select
    from functools import reduce
    from operator import xor
    from qec.surface.host import request

    # A local transport endpoint only: this is not a physical FPGA result.
    master, slave = pty.openpty()
    process = subprocess.Popen(
        [sys.executable, '-m', 'qec.surface.example', '--port', os.ttyname(slave)],
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    try:
        assert select.select([master], [], [], 10)[0], 'no serial request'
        tx = os.read(master, 7)
        assert tx == request(0, 2048)
        reply = bytes.fromhex('3c 00 00 00 a9 03 00 00')
        reply += bytes([reduce(xor, reply)])
        os.write(master, reply)
        stdout, stderr = process.communicate(timeout=10)
        assert process.returncode == 0, stderr
        window = json.loads(stdout)
        assert window['board_prediction'] == window['prediction'] == 0
        assert window['pl_cycles'] == 937
        assert window['rx_hex'] == reply.hex(' ')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(master)
        os.close(slave)
