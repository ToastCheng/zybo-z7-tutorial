"""Generate real surface shots and run actual algorithmic decoder RTL."""
import argparse
from pathlib import Path
import subprocess
import random
import stim
from decoder import graph,decode,export


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--distance',type=int,default=3)
    ap.add_argument('--basis',choices=['x','z'],default='z')
    ap.add_argument('--shots',type=int,default=128)
    args=ap.parse_args()
    root=Path(__file__).resolve().parents[2]
    out=root/f'build/surface_sim_d{args.distance}_{args.basis}'; out.mkdir(parents=True,exist_ok=True)
    g=graph(distance=args.distance,basis=args.basis); n=g['detectors']
    export(g,out/'graph')
    c=stim.Circuit(g['circuit']); detectors=c.compile_detector_sampler(seed=1945).sample(args.shots)
    syndromes=[0]+[1<<i for i in range(n)]
    syndromes += [(1<<a)^((1<<b) if b<n else 0) for a,b,_ in g['edges']]
    syndromes += [sum(int(v)<<i for i,v in enumerate(bits)) for bits in detectors]
    rng=random.Random(1946); syndromes += [rng.getrandbits(n) for _ in range(64)]
    words=[]
    for s in syndromes:
        r=decode(n,g['edges'],s)
        assert not r['error']
        words.append((s<<2)|int(r['error'])<<1|r['prediction'])
    (out/'cases.mem').write_text(''.join(f'{w:x}\n' for w in words))
    (out/'wrapper.sv').write_text('module tb_surface_run; surface_core_test #('+f'.N({n}),.E({len(g["edges"])}),.CASES({len(words)}),'+f'.GRAPH("{out}/graph.mem"),.VECTORS("{out}/cases.mem")'+') t(); endmodule\n')
    tools=Path.home()/'amd/2025.2/Vivado/bin'
    commands=[['xvlog','--sv',str(root/'rtl/common/surface_decoder.sv'),str(root/'qec/surface/tb_surface.sv'),str(out/'wrapper.sv')],
              ['xelab','tb_surface_run','-s','surface_run'],['xsim','surface_run','-runall']]
    for command in commands:
        result=subprocess.run([str(tools/command[0]),*command[1:]],cwd=out,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        (out/(command[0]+'.txt')).write_text(result.stdout)
        print(result.stdout,flush=True)
        if result.returncode or 'Fatal:' in result.stdout or 'FATAL' in result.stdout:
            raise SystemExit(f'{command[0]} failed')
    if 'PASS algorithmic surface' not in result.stdout: raise SystemExit('missing PASS')


if __name__=='__main__': main()
