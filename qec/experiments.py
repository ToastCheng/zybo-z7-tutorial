"""Reproducible noisy Stim sweep and explicitly software-only timings."""
import argparse
import csv
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path
import platform
import time
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from decoder import model, make_lut, pack

NOISE = [0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03, 0.1]


def wilson(errors, shots):
    z = 1.959963984540054
    rate = errors / shots
    denominator = 1 + z*z/shots
    center = (rate + z*z/(2*shots)) / denominator
    radius = z * math.sqrt(rate*(1-rate)/shots + z*z/(4*shots*shots)) / denominator
    return (0.0 if errors == 0 else max(0.0, center-radius),
            1.0 if errors == shots else min(1.0, center+radius))


def write_csv(path, rows):
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def run(out, shots, seed):
    out.mkdir(parents=True, exist_ok=True)
    table = make_lut()
    rows = []
    for i, noise in enumerate(NOISE):
        circuit, matching = model(noise)
        detectors, obs = circuit.compile_detector_sampler(seed=seed+i).sample(shots, separate_observables=True)
        predictions = {'identity': np.zeros(shots, dtype=np.uint8),
                       'pymatching': matching.decode_batch(detectors)[:, 0],
                       'fixed_lut': table[pack(detectors)]}
        for name, pred in predictions.items():
            errors = int(np.sum(pred != obs[:, 0]))
            lo, hi = wilson(errors, shots)
            rows.append(dict(noise=noise, decoder=name, seed=seed+i, shots=shots,
                             errors=errors, logical_error_rate=errors/shots,
                             ci_low=lo, ci_high=hi,
                             disagreements_with_pymatching=int(np.sum(pred != predictions['pymatching']))))
    write_csv(out / 'noise_sweep.csv', rows)
    circuit, matching = model()
    detectors = circuit.compile_detector_sampler(seed=seed+100).sample(shots)
    indices = pack(detectors)
    # Warm up caches and library entry points outside measurement.
    matching.decode_batch(detectors)
    table[indices]
    timings = []
    for repeat in range(7):
        for name, operation in [('pymatching_batch', lambda: matching.decode_batch(detectors)),
                                ('lut_batch', lambda: table[indices])]:
            start = time.perf_counter_ns()
            operation()
            elapsed = time.perf_counter_ns() - start
            timings.append(dict(method=name, repeat=repeat, sample=-1, shots=shots,
                                elapsed_ns=elapsed, ns_per_shot=elapsed/shots,
                                shots_per_second=shots*1e9/elapsed))
    for i in range(min(shots, 2000)):
        # Time one actual API call/access, no enclosing list/batch division.
        start = time.perf_counter_ns()
        matching.decode(detectors[i])
        elapsed = time.perf_counter_ns() - start
        timings.append(dict(method='pymatching_single', repeat=0, sample=i, shots=1,
                            elapsed_ns=elapsed, ns_per_shot=elapsed, shots_per_second=1e9/elapsed))
        start = time.perf_counter_ns()
        int(table[indices[i]])
        elapsed = time.perf_counter_ns() - start
        timings.append(dict(method='lut_single', repeat=0, sample=i, shots=1,
                            elapsed_ns=elapsed, ns_per_shot=elapsed, shots_per_second=1e9/elapsed))
    write_csv(out / 'timings.csv', timings)
    summary = {}
    for name in sorted({r['method'] for r in timings}):
        values = np.array([r['ns_per_shot'] for r in timings if r['method'] == name])
        summary[name] = dict(median_ns_per_shot=float(np.median(values)),
                             p05_ns_per_shot=float(np.percentile(values, 5)),
                             p95_ns_per_shot=float(np.percentile(values, 95)),
                             samples=len(values))
    metadata = dict(seed=seed, shots_per_noise=shots, noise_values=NOISE,
                    num_detectors=8, distance=3, rounds=3, lut_noise=0.001,
                    circuit_generator='repetition_code:memory',
                    noise_channels=['after_clifford_depolarization', 'before_round_data_depolarization',
                                    'before_measure_flip_probability', 'after_reset_flip_probability'],
                    lut_sha256=hashlib.sha256(Path(__file__).with_name('lut.mem').read_bytes()).hexdigest(),
                    versions={p: importlib.metadata.version(p) for p in ['stim', 'pymatching', 'numpy', 'matplotlib', 'pyserial', 'pytest']},
                    python=platform.python_version(), platform=platform.platform(),
                    fpga_measured=False, confidence_interval='95% Wilson marginal binomial',
                    timing_clock='perf_counter_ns', timing_summary=summary,
                    limitations=['fixed shot window, not streaming', 'one error type, not full quantum error correction',
                                 'software timing excludes sampling and transport', 'batch amortized cost is not single-shot latency',
                                 'FPGA acceptance-to-result cycles are not UART latency',
                                 'timing varies by host/load; seeds require same Stim version and sample calls'])
    (out / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    fig, ax = plt.subplots(figsize=(7, 4))
    for name in predictions:
        subset = [r for r in rows if r['decoder'] == name]
        y = np.array([r['logical_error_rate'] for r in subset])
        ax.errorbar(NOISE, y, yerr=[y-np.array([r['ci_low'] for r in subset]),
                                   np.array([r['ci_high'] for r in subset])-y],
                    marker='o', capsize=3, label=name)
    ax.set(xscale='log', xlabel='Circuit noise parameter p (all four channels)',
           ylabel='Logical error per shot window', title='Stim repetition d=3, rounds=3; 95% Wilson intervals')
    ax.legend()
    fig.tight_layout()
    fig.savefig(out / 'noise_sweep.png', dpi=160)
    plt.close(fig)
    fig, ax = plt.subplots(figsize=(7, 4))
    names = list(summary)
    values = [summary[n]['median_ns_per_shot'] for n in names]
    ax.bar(names, values)
    ax.set(yscale='log', ylabel='Median ns/shot (log scale)',
           title='Software only: batch amortized cost vs single-call latency')
    ax.tick_params(axis='x', labelrotation=15)
    fig.tight_layout()
    fig.savefig(out / 'software_performance.png', dpi=160)
    plt.close(fig)
    return metadata


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shots', type=int, default=100000)
    parser.add_argument('--seed', type=int, default=20261105)
    parser.add_argument('--out', type=Path, default=Path(__file__).with_name('results'))
    args = parser.parse_args()
    if args.shots <= 0 or args.seed < 0:
        parser.error('shots must be positive and seed nonnegative')
    print(json.dumps(run(args.out, args.shots, args.seed), indent=2))
