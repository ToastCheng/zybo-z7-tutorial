"""Physical surface-code graph decoder capture, never a software endpoint."""
from functools import reduce
from operator import xor


def request(seq,syndrome,nbytes=3):
    if not 0<=seq<256: raise ValueError('sequence must fit byte')
    if syndrome is None: payload=b''
    else:
        if syndrome<0 or syndrome>>(8*nbytes): raise ValueError('syndrome width')
        payload=int(syndrome).to_bytes(nbytes,'little')
    data=bytes([0xc3,seq,len(payload)])+payload
    return data+bytes([reduce(xor,data)])


def parse(data,seq):
    if len(data)!=9 or data[0]!=0x3c or data[1]!=seq or reduce(xor,data) or data[3]>1:
        raise ValueError('invalid surface reply length/header/sequence/checksum/prediction')
    if data[2]: raise IOError(f'PL/transport error status {data[2]}')
    return data[3],int.from_bytes(data[4:8],'little')


def main():
    import argparse,csv,json,time,hashlib,shutil,subprocess
    from pathlib import Path
    import numpy as np
    import serial,stim,pymatching
    from decoder import graph,decode
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--port',required=True)
    ap.add_argument('--board-id',required=True)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--shots',type=int,default=4096)
    ap.add_argument('--noise',type=float,default=.001)
    ap.add_argument('--seed',type=int,default=20261107)
    args=ap.parse_args()
    if args.shots<1:ap.error('shots must be positive')
    out=args.out;out.mkdir(parents=True,exist_ok=False)
    configured=json.loads(Path('qec/surface/graphs/d3_z_r3.json').read_text())
    g=graph(noise=args.noise);n=g['detectors'];edges=configured['edges']
    assert g['detectors']==configured['detectors']==24
    circuit=stim.Circuit(g['circuit'])
    det,obs=circuit.compile_detector_sampler(seed=args.seed).sample(args.shots,separate_observables=True)
    matching=pymatching.Matching.from_detector_error_model(circuit.detector_error_model(decompose_errors=True))
    matched=matching.decode_batch(det)[:,0]
    rows=[];controls=[];recovery=[]
    with serial.Serial(args.port,115200,timeout=1,write_timeout=1) as ep,(out/'transactions.csv').open('w') as f:
        ep.reset_input_buffer();writer=None
        def transact(kind,s,observable=None,mwpm=None):
            nonlocal writer
            seq=len(rows)%256;tx=request(seq,s);start=time.perf_counter_ns()
            assert ep.write(tx)==len(tx);rx=ep.read(9);elapsed=time.perf_counter_ns()-start
            pred,cycles=parse(rx,seq);expected=decode(n,edges,s)
            row=dict(kind=kind,index=len(rows),syndrome=s,prediction=pred,uf_reference=expected['prediction'],
                     reference_error=expected['error'],observable=observable,pymatching=mwpm,cycles=cycles,
                     host_ns=elapsed,tx_hex=tx.hex(),rx_hex=rx.hex())
            if writer is None:writer=csv.DictWriter(f,fieldnames=list(row));writer.writeheader()
            writer.writerow(row);f.flush();rows.append(row)
            if expected['error'] or pred!=expected['prediction'] or not cycles:
                raise AssertionError(f'physical UF mismatch {row}')
            return row
        transact('zero',0)
        for i in range(n):transact('single_detector',1<<i)
        for a,b,_ in edges:transact('edge_error',(1<<a)^((1<<b) if b<n else 0))
        import random
        rng=random.Random(20261108)
        for _ in range(64):transact('dense_random',rng.getrandbits(n))
        for i,bits in enumerate(det):
            s=sum(int(v)<<k for k,v in enumerate(bits))
            transact('stim',s,int(obs[i,0]),int(matched[i]))
        ep.timeout=.12
        bad=request(90,0);bad=bad[:-1]+bytes([bad[-1]^1])
        for name,data in [('checksum',bad),('garbage',b'\x00\x11\xff'),
                          ('partial_timeout',bytes([0xc3,90,3])),('bad_length',bytes([0xc3,90,17,0]))]:
            ep.write(data);rx=ep.read(9)
            if rx:raise AssertionError(f'malformed response {name} {rx.hex()}')
            row=transact('recovery',0)
            recovery.append(dict(case=name,bad_tx_hex=data.hex(),rejected_rx_hex=rx.hex(),recovered_rx_hex=row['rx_hex']))
        # A real firmware command resets the PL without reprogramming.
        tx=request(91,None);ep.write(tx);rx=ep.read(9);pred,cycles=parse(rx,91)
        assert pred==0 and cycles==0
        controls.append(dict(kind='pl_reset',tx_hex=tx.hex(),rx_hex=rx.hex()))
        transact('after_pl_reset',0)
    shots=[r for r in rows if r['kind']=='stim'];counts=[r['cycles'] for r in rows]
    errors=sum(r['prediction']!=r['observable'] for r in shots)
    def interval(k,total):
        z=1.959963984540054;p=k/total;den=1+z*z/total
        center=(p+z*z/(2*total))/den;half=z*((p*(1-p)+z*z/(4*total))/total)**.5/den
        return [max(0.,center-half),center+half]
    summary=dict(mode='physical-surface-unweighted-union-find-peeling',fpga_measured=True,
        board_id=args.board_id,port=args.port,distance=3,rounds=3,basis='z',detectors=n,edges=len(edges),
        shots=len(shots),noise=args.noise,seed=args.seed,transactions=len(rows),
        uf_mismatches=sum(r['prediction']!=r['uf_reference'] for r in rows),
        pymatching_disagreements=sum(r['prediction']!=r['pymatching'] for r in shots),
        logical_errors=errors,logical_error_wilson95=interval(errors,len(shots)),
        pymatching_logical_errors=sum(r['pymatching']!=r['observable'] for r in shots),
        identity_errors=sum(r['observable'] for r in shots),
        fclk_hz=100000000,cycles_min=min(counts),cycles_median=float(np.median(counts)),cycles_max=max(counts),
        host_stim_ns_median=float(np.median([r['host_ns'] for r in shots])),
        host_stim_ns_p99=float(np.percentile([r['host_ns'] for r in shots],99)),
        recovery=recovery,controls=controls,
        timing_boundary='instrumented core acceptance to result availability; excludes PS/AXI/USB',
        limitations='Unweighted serial finite-window union-find, not MWPM/streaming/near-linear hardware latency or physical quantum correction. Only d3 Z is programmed here; d5 and X are RTL simulation evidence.')
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    (out/'circuit.stim').write_text(str(circuit))
    artifacts=['build/surface_soc.bit','build/surface_soc.xsa','build/vitis_ws/surface_app/build/surface_app.elf',
               'build/surface_build.log','build/surface_firmware_build.log','build/surface_program.log',
               'build/surface_readback.log','build/top_surface_soc_timing_summary.rpt',
               'build/top_surface_soc_utilization.rpt','qec/surface/graphs/d3_z_r3.mem','qec/surface/graphs/d3_z_r3.json',
               'build/surface_sim_d3.log','build/surface_sim_d5.log','build/surface_sim_x.log','build/surface_bridge_sim.log']
    for path in artifacts:shutil.copy2(path,out/Path(path).name)
    rev=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    subprocess.run(['git','archive','--format=tar.gz','-o',str(out.resolve()/'sources.tar.gz'),'HEAD'],check=True)
    manifest=dict(source_revision=rev,source_status=subprocess.check_output(['git','status','--porcelain'],text=True),
        board_id=args.board_id,port=args.port,stim_version=stim.__version__,pymatching_version=pymatching.__version__,
        pyserial_version=serial.__version__,numpy_version=np.__version__,
        files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.iterdir()) if p.is_file()})
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(summary,indent=2))


if __name__=='__main__':main()
