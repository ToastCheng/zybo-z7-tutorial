"""Stim shot-window -> framed endpoint -> observable validation."""
import argparse
import json
from pathlib import Path
import time
import numpy as np
from decoder import model, pack
from transport import exchange, Loopback


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['loopback', 'serial'], default='loopback')
    parser.add_argument('--port', help='explicit serial device, never auto-detected')
    parser.add_argument('--baud', type=int, default=115200)
    parser.add_argument('--timeout', type=float, default=1.0)
    parser.add_argument('--shots', type=int, default=1000)
    parser.add_argument('--seed', type=int, default=90210)
    parser.add_argument('--noise', type=float, default=0.001)
    args = parser.parse_args()
    if args.shots <= 0 or args.timeout <= 0:
        parser.error('shots and timeout must be positive')
    if args.mode == 'serial' and not args.port:
        parser.error('--port is required for serial; no device opened')
    table = np.loadtxt(Path(__file__).with_name('lut.mem'), dtype=np.uint8)
    circuit, matching = model(args.noise)
    detectors, observables = circuit.compile_detector_sampler(seed=args.seed).sample(args.shots, separate_observables=True)
    if args.mode == 'serial':
        import serial
        endpoint = serial.Serial(args.port, args.baud, timeout=min(args.timeout, 0.01), write_timeout=args.timeout)
        endpoint.reset_input_buffer()
    else:
        endpoint = Loopback(table)
    predictions, cycles, elapsed = [], [], []
    try:
        for i, syndrome in enumerate(pack(detectors)):
            start = time.perf_counter_ns()
            prediction, count = exchange(endpoint, i % 256, int(syndrome), args.timeout)
            elapsed.append(time.perf_counter_ns() - start)
            predictions.append(prediction)
            cycles.append(count)
    finally:
        if args.mode == 'serial':
            endpoint.close()
    print(json.dumps(dict(mode='software-loopback' if args.mode == 'loopback' else 'serial-unverified-hardware',
        shots=args.shots, seed=args.seed, noise=args.noise,
        prediction_mismatches=int(np.sum(np.asarray(predictions) != matching.decode_batch(detectors)[:, 0])),
        logical_errors=int(np.sum(np.asarray(predictions) != observables[:, 0])),
        identity_errors=int(np.sum(observables)),
        response_cycles_min=int(min(cycles)), response_cycles_max=int(max(cycles)),
        host_roundtrip_ns_median=float(np.median(elapsed)),
        timing_note='Loopback cycles are placeholders; real cycles are acceptance-to-result, not UART latency.'), indent=2))


if __name__ == '__main__':
    main()
