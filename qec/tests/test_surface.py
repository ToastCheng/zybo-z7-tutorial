"""Algorithmic surface-code graph/reference tests, not a syndrome LUT."""
from pathlib import Path
import importlib.util
import sys
import numpy as np

ROOT=Path(__file__).parents[2]

def module():
    path=ROOT/'qec/surface/decoder.py'
    assert path.exists(), 'surface graph decoder is not implemented'
    spec=importlib.util.spec_from_file_location('surface_decoder',path)
    m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m

def test_surface_graph_is_not_an_exponential_syndrome_lut():
    m=module()
    g=m.graph(distance=3,rounds=3,basis='z')
    assert g['detectors']==24 and g['observables']==1
    assert len(g['edges'])>24 and len(g['edges'])<200
    assert all(0<=a<b<=24 and o in (0,1) for a,b,o in g['edges'])
    assert g['decoder']=='serial-half-edge-union-find-peeling-unweighted'

def test_graph_export_is_roundtrippable_and_scales(tmp_path):
    m=module()
    assert hasattr(m,'export'), 'graph ROM export is missing'
    for distance in (3,5):
        g=m.graph(distance=distance)
        target=tmp_path/f'd{distance}'
        m.export(g,target)
        vb=g['detectors'].bit_length()
        words=[int(s,16) for s in target.with_suffix('.mem').read_text().split()]
        assert len(words)==len(g['edges'])
        assert [(v&((1<<vb)-1),(v>>vb)&((1<<vb)-1),v>>(2*vb)) for v in words]==g['edges']
        assert target.with_suffix('.json').exists()

def test_union_find_peeling_cancels_syndrome_and_tracks_observable():
    m=module()
    assert hasattr(m,'decode'), 'union-find/peeling reference is missing'
    # Two defects pair internally; one defect connects to boundary carrying L0.
    edges=[(0,1,0),(1,2,0),(2,3,1)]
    assert m.decode(3,edges,0)['prediction']==0
    assert m.decode(3,edges,0b011)['prediction']==0
    assert m.decode(3,edges,0b100)['prediction']==1
    assert m.decode(3,[],1)['error']
    for basis in ('x','z'):
        for distance in (3,5):
            g=m.graph(distance=distance,basis=basis)
            c=__import__('stim').Circuit(g['circuit'])
            det,obs=c.compile_detector_sampler(seed=1201).sample(128,separate_observables=True)
            for bits in det:
                syndrome=sum(int(v)<<i for i,v in enumerate(bits))
                r=m.decode(g['detectors'],g['edges'],syndrome)
                assert not r['error']
                residual=syndrome; prediction=0
                for e in r['correction_edges']:
                    a,b,o=g['edges'][e]
                    residual^=1<<a
                    if b<g['detectors']: residual^=1<<b
                    prediction^=o
                assert residual==0 and prediction==r['prediction']
