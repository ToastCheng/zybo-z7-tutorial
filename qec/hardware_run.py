"""Physical-only USB UART QEC corpus and transaction archive. No loopback path."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
import numpy as np


def evaluate(rows, table):
    return dict(transactions=len(rows),
        lut_mismatches=sum(r['prediction'] != int(table[r['syndrome']]) for r in rows),
        reference_mismatches=sum(r['prediction'] != r['reference'] for r in rows),
        logical_errors=sum(r['prediction'] != r['observable'] for r in rows),
        identity_errors=sum(r['observable'] for r in rows),
        cycles_min=min(r['cycles'] for r in rows), cycles_max=max(r['cycles'] for r in rows),
        host_roundtrip_ns_min=min(r['host_ns'] for r in rows),
        host_roundtrip_ns_median=float(np.median([r['host_ns'] for r in rows])),
        host_roundtrip_ns_p99=float(np.percentile([r['host_ns'] for r in rows],99)),
        host_roundtrip_ns_max=max(r['host_ns'] for r in rows))


def main():
    from decoder import model, pack
    from transport import request, Parser
    import serial
    import stim
    import pymatching
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--port',required=True)
    ap.add_argument('--out',required=True,type=Path)
    ap.add_argument('--board-id',required=True)
    ap.add_argument('--shots',type=int,default=8192)
    ap.add_argument('--seed',type=int,default=20261105)
    ap.add_argument('--noise',type=float,default=.01)
    a=ap.parse_args()
    if a.shots<1: ap.error('shots must be positive')
    out=a.out; out.mkdir(parents=True,exist_ok=False)
    table=np.loadtxt('qec/lut.mem',dtype=np.uint8)
    circuit,matching=model(a.noise)
    det,obs=circuit.compile_detector_sampler(seed=a.seed).sample(a.shots,separate_observables=True)
    refs=matching.decode_batch(det)[:,0]
    rows=[]; recovery=[]
    with serial.Serial(a.port,115200,timeout=.5,write_timeout=.5) as ep, (out/'transactions.csv').open('w') as f:
        ep.reset_input_buffer(); writer=None
        def transact(kind,index,syndrome,observable,reference):
            nonlocal writer
            tx=request(index%256,int(syndrome)); start=time.perf_counter_ns()
            assert ep.write(tx)==4
            rx=ep.read(6); elapsed=time.perf_counter_ns()-start
            frames=Parser().feed(rx)
            if len(rx)!=6 or len(frames)!=1 or frames[0][0]!=index%256:
                raise RuntimeError(f'invalid response tx={tx.hex()} rx={rx.hex()}')
            seq,pred,cycles=frames[0]
            row=dict(kind=kind,index=index,syndrome=int(syndrome),observable=int(observable),
                     reference=int(reference),prediction=pred,cycles=cycles,host_ns=elapsed,
                     tx_hex=tx.hex(),rx_hex=rx.hex())
            if writer is None:
                writer=csv.DictWriter(f,fieldnames=list(row)); writer.writeheader()
            writer.writerow(row); f.flush(); rows.append(row)
            return row
        for s in range(256): transact('exhaustive',s,s,int(table[s]),int(table[s]))
        for i,s in enumerate(pack(det)):
            transact('stim',i,int(s),obs[i,0],refs[i])
        # Silence is required for malformed traffic. Each subsequent good
        # request proves parser recovery, not simply rejection.
        ep.timeout=.12
        for label,bad in [('bad_checksum',bytes.fromhex('a5123700')),
                          ('garbage',bytes.fromhex('001122ff')),
                          ('partial_timeout',bytes.fromhex('a512'))]:
            ep.write(bad); received=ep.read(6)
            if received: raise RuntimeError(f'malformed traffic replied: {label} {received.hex()}')
            row=transact('recovery',0x31,0x37,int(table[0x37]),int(table[0x37]))
            recovery.append(dict(case=label,bad_tx_hex=bad.hex(),rejected_rx_hex=received.hex(),
                                 recovered_rx_hex=row['rx_hex']))
    exhaustive=[r for r in rows if r['kind']=='exhaustive']
    sampled=[r for r in rows if r['kind']=='stim']
    summary=dict(mode='physical-zybo-ps-uart1-axi-gpio-pl',fpga_measured=True,
                 board_id=a.board_id,serial_port=a.port,baud=115200,
                 shots=a.shots,seed=a.seed,noise=a.noise,fclk_hz=100000000,
                 core_timing_boundary='input acceptance to first out_valid availability; observer subtracts one cycle',
                 status_capture_cycles=3,core_cycles_measured=True,
                 exhaustive=evaluate(exhaustive,table),stim=evaluate(sampled,table),
                 recovery=recovery,
                 limitations='Finite-shot simulated repetition-code observable prediction, not physical quantum correction. UART roundtrip is host/USB/ARM/AXI inclusive, not a feedback deadline.')
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    (out/'circuit.stim').write_text(str(circuit))
    artifacts=['build/qec_soc.bit','build/qec_soc.xsa','build/vitis_ws/qec_app/build/qec_app.elf',
               'build/qec_soc_build.log','build/qec_firmware_build.log','build/qec_program.log',
               'build/qec_readback.log','build/top_qec_soc_timing_summary.rpt',
               'build/top_qec_soc_utilization.rpt','qec/lut.mem']
    for p in artifacts: shutil.copy2(p,out/Path(p).name)
    revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    subprocess.run(['git','archive','--format=tar.gz','-o',str(out.resolve()/'sources.tar.gz'),'HEAD'],check=True)
    manifest=dict(source_revision=revision,source_status=subprocess.check_output(['git','status','--porcelain'],text=True),
        board_id=a.board_id,serial_port=a.port,stim_version=stim.__version__,pymatching_version=pymatching.__version__,
        numpy_version=np.__version__,pyserial_version=serial.__version__,
        files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.iterdir()) if p.is_file()})
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
    assert summary['exhaustive']['lut_mismatches']==0
    assert summary['stim']['lut_mismatches']==0
    assert all(r['cycles']==2 for r in rows)


if __name__=='__main__': main()
