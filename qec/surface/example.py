"""Inspect one simulated surface-code shot; optionally send it to the board.

Run from the repository root: python -m qec.surface.example [--port PORT].
See example.py.md and ../QUICKSTART.md for the step-by-step explanation.
"""
import argparse
import json
from pathlib import Path

import pymatching
import stim

from qec.surface.decoder import decode
from qec.surface.host import parse, request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--circuit', action='store_true', help='print the full Stim circuit only')
    parser.add_argument('--port', help='send this same shot to a loaded d3 Z surface image')
    args = parser.parse_args()
    config = json.loads(Path('qec/surface/graphs/d3_z_r3.json').read_text())
    circuit = stim.Circuit(config['circuit'])
    if args.circuit:
        print(circuit)
        return

    detectors, observables = circuit.compile_detector_sampler(seed=20261107).sample(
        256, separate_observables=True
    )
    index = next(i for i, row in enumerate(detectors) if row.any())
    bits = detectors[index]
    syndrome = sum(int(bit) << i for i, bit in enumerate(bits))
    result = decode(config['detectors'], config['edges'], syndrome)
    assert not result['error']
    residual = syndrome
    for edge in result['correction_edges']:
        a, b, _ = config['edges'][edge]
        residual ^= 1 << a
        if b < config['detectors']:
            residual ^= 1 << b
    assert residual == 0
    matching = pymatching.Matching.from_detector_error_model(
        circuit.detector_error_model(decompose_errors=True)
    )
    seq = 0
    tx = request(seq, syndrome)
    window = dict(
        shot=index, detector_indices=[i for i, bit in enumerate(bits) if bit],
        syndrome=syndrome, observable=int(observables[index, 0]),
        prediction=result['prediction'], pymatching=int(matching.decode(bits)[0]),
        correction_edges=result['correction_edges'], residual=residual,
        logical_error=result['prediction'] != int(observables[index, 0]),
        tx_hex=tx.hex(' '),
    )
    if args.port:
        import serial
        with serial.Serial(args.port, 115200, timeout=1, write_timeout=1) as port:
            port.reset_input_buffer()
            assert port.write(tx) == len(tx)
            rx = port.read(9)
        prediction, cycles = parse(rx, seq)
        window.update(rx_hex=rx.hex(' '), board_prediction=prediction, pl_cycles=cycles)
        assert prediction == result['prediction'], 'FPGA/reference mismatch'
        assert cycles > 0
    print(json.dumps(window, indent=2))


if __name__ == '__main__':
    main()
