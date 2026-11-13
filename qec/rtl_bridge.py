"""Real xsim UART HDL bridge using host-generated Stim request bytes."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import numpy as np
from decoder import model, pack
from transport import request, Parser

ROOT = Path(__file__).resolve().parents[1]


def run(shots, seed, noise, out=None):
    build = ROOT / 'qec/.rtl'
    build.mkdir(exist_ok=True)
    link = build / 'qec'
    if not link.exists():
        link.symlink_to(ROOT / 'qec', target_is_directory=True)
    circuit, matching = model(noise)
    detectors, obs = circuit.compile_detector_sampler(seed=seed).sample(shots, separate_observables=True)
    packets = b''.join(request(i % 256, int(s)) for i, s in enumerate(pack(detectors)))
    (build / 'requests.mem').write_text(''.join(f'{b:02x}\n' for b in packets))
    output = build / 'responses.mem'
    output.unlink(missing_ok=True)
    binary = Path(os.environ.get('VIVADO_BIN', str(Path.home() / 'amd/2025.2/Vivado/bin')))
    sources = ['rtl/common/sync.sv', 'rtl/common/uart_rx.sv', 'rtl/common/uart_tx.sv',
               'rtl/common/qec_decoder.sv', 'rtl/top/top_qec_uart.sv', 'qec/tb_host_bridge.sv']
    commands = [('xvlog', '--sv', *(str(ROOT/p) for p in sources)),
                ('xelab', 'work.tb_host_bridge', '--snapshot', 'tb_host_bridge', '--debug', 'typical'),
                ('xsim', 'tb_host_bridge', '--runall', '--testplusarg', f'shots={shots}', '--log', 'host_bridge.log')]
    for command in commands:
        result = subprocess.run([str(binary/command[0]), *command[1:]], cwd=build,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150)
        (build / f'{command[0]}.stdout.log').write_text(result.stdout)
        if result.returncode or 'Fatal:' in result.stdout or 'FATAL' in result.stdout:
            raise RuntimeError(f'{command[0]} failed: {result.stdout}')
        if command[0] == 'xsim' and 'PASS host wire exchange' not in result.stdout:
            raise RuntimeError('HDL simulation missing PASS marker')
    wire = bytes(int(s, 16) for s in output.read_text().split())
    parser = Parser()
    frames = []
    # Intentionally exercise host partial-frame parser on actual HDL output.
    for offset in range(0, len(wire), 5):
        frames.extend(parser.feed(wire[offset:offset+5]))
    if len(frames) != shots or parser.buffer:
        raise ValueError('RTL response count/truncation mismatch')
    if [f[0] for f in frames] != [i % 256 for i in range(shots)]:
        raise ValueError('RTL response sequence mismatch')
    predictions = np.array([f[1] for f in frames])
    table = np.loadtxt(ROOT / 'qec/lut.mem', dtype=np.uint8)
    if out is not None:
        import csv
        out.mkdir(parents=True, exist_ok=True)
        with (out / 'rtl_shots.csv').open('w', newline='') as stream:
            writer = csv.writer(stream)
            writer.writerow(['shot', 'sequence', 'syndrome', 'observable', 'prediction', 'cycles'])
            for i, (syndrome, observable, frame) in enumerate(zip(pack(detectors), obs[:, 0], frames)):
                writer.writerow([i, frame[0], int(syndrome), int(observable), frame[1], frame[2]])
    return dict(mode='rtl-uart-simulation', fpga_measured=False, shots=shots, seed=seed, noise=noise,
                prediction_mismatches=int(np.sum(predictions != table[pack(detectors)])),
                pymatching_disagreements=int(np.sum(predictions != matching.decode_batch(detectors)[:, 0])),
                logical_errors=int(np.sum(predictions != obs[:, 0])), identity_errors=int(np.sum(obs)),
                received_frames=len(frames), cycles=sorted({f[2] for f in frames}),
                timing_note='Functional RTL acceptance-to-result cycles only; no UART/board latency measurement')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shots', type=int, default=256)
    parser.add_argument('--seed', type=int, default=314159)
    parser.add_argument('--noise', type=float, default=0.03)
    parser.add_argument('--out', type=Path, help='optional raw per-shot CSV directory')
    args = parser.parse_args()
    if not 1 <= args.shots <= 4096:
        parser.error('RTL bridge supports 1..4096 shots')
    print(json.dumps(run(args.shots, args.seed, args.noise, args.out), indent=2))
