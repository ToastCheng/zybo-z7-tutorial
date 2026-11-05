"""Surface-code decoding graph; graph-size storage, never a syndrome LUT."""
import stim
import pymatching


def graph(distance=3,rounds=3,basis='z',noise=.001):
    if distance<3 or distance%2==0 or rounds<1 or basis not in ('x','z'):
        raise ValueError('odd distance >=3, positive rounds and x/z basis required')
    circuit=stim.Circuit.generated('surface_code:rotated_memory_'+basis,
        distance=distance,rounds=rounds,after_clifford_depolarization=noise,
        before_round_data_depolarization=noise,before_measure_flip_probability=noise,
        after_reset_flip_probability=noise)
    matching=pymatching.Matching.from_detector_error_model(
        circuit.detector_error_model(decompose_errors=True))
    n=circuit.num_detectors
    edges=sorted((min(a,n if b is None else b),max(a,n if b is None else b),
                  int(0 in data['fault_ids'])) for a,b,data in matching.edges())
    return dict(distance=distance,rounds=rounds,basis=basis,noise=noise,
                detectors=n,observables=circuit.num_observables,edges=edges,
                circuit=str(circuit),decoder='serial-half-edge-union-find-peeling-unweighted')


def decode(n,edges,syndrome):
    """Deterministic serial half-edge growth, relabel unions, forest peeling.

    Unweighted graph; edge order is scheduling/tie policy. Boundary root n
    absorbs odd parity. O(V+E) storage; sequential relabel/peel costs are not
    the near-linear optimized software union-find complexity claim.
    """
    if syndrome<0 or syndrome>>n:
        raise ValueError('syndrome does not fit graph')
    labels=list(range(n+1)); parity=[(syndrome>>i)&1 for i in range(n)]+[0]
    growth=[0]*len(edges); forest=set(); degree=[0]*(n+1)
    for sweep in range(2*(n+1)):
        if not any(parity[:n]): break
        for i,(a,b,_) in enumerate(edges):
            ra,rb=labels[a],labels[b]
            active=int(ra!=n and parity[ra]!=0)+int(rb!=n and parity[rb]!=0)
            if ra==rb or not active: continue
            growth[i]=min(2,growth[i]+active)
            if growth[i]<2: continue
            winner=n if n in (ra,rb) else min(ra,rb)
            loser=rb if winner==ra else ra
            parity[winner]=parity[ra]^parity[rb]; parity[loser]=0
            labels=[winner if r==loser else r for r in labels]
            forest.add(i); degree[a]+=1; degree[b]+=1
    else:
        return dict(prediction=0,error=True,correction_edges=[])
    work=[(syndrome>>i)&1 for i in range(n)]+[0]; prediction=0; correction=[]
    while forest:
        leaves=[i for i in range(n) if degree[i]==1]
        if not leaves: return dict(prediction=prediction,error=True,correction_edges=correction)
        leaf=leaves[0]
        e=next(i for i in sorted(forest) if leaf in edges[i][:2])
        a,b,obs=edges[e]; other=b if a==leaf else a
        if work[leaf]:
            work[other]^=1; prediction^=obs; correction.append(e)
        work[leaf]=0; degree[a]-=1; degree[b]-=1; forest.remove(e)
    return dict(prediction=prediction,error=any(work[:n]),correction_edges=correction)


def export(g,target):
    from pathlib import Path
    import json
    import hashlib
    target=Path(target); target.parent.mkdir(parents=True,exist_ok=True)
    vb=g['detectors'].bit_length()
    words=[a|(b<<vb)|(obs<<(2*vb)) for a,b,obs in g['edges']]
    text=''.join(f'{word:0{(2*vb+4)//4}x}\n' for word in words)
    target.with_suffix('.mem').write_text(text)
    metadata=dict(g,vertex_bits=vb,edge_count=len(words),
                  mem_sha256=hashlib.sha256(text.encode()).hexdigest(),
                  stim_version=stim.__version__,pymatching_version=pymatching.__version__)
    target.with_suffix('.json').write_text(json.dumps(metadata,indent=2)+'\n')


if __name__=='__main__':
    import argparse
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--distance',type=int,default=3)
    ap.add_argument('--rounds',type=int,default=3)
    ap.add_argument('--basis',choices=['x','z'],default='z')
    ap.add_argument('--out',required=True)
    args=ap.parse_args()
    export(graph(args.distance,args.rounds,args.basis),args.out)

