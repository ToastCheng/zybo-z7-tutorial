import importlib.util
from pathlib import Path
import pytest

spec=importlib.util.spec_from_file_location('hardware_run',Path(__file__).parents[1]/'hardware_run.py')

def test_validate_rows_separates_lut_accuracy_and_observables():
    assert spec.loader is not None
    assert Path(spec.origin).exists(), 'physical evidence runner is not implemented'
    m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    rows=[dict(syndrome=0,prediction=1,observable=0,reference=1,cycles=2,host_ns=100),
          dict(syndrome=1,prediction=0,observable=0,reference=1,cycles=2,host_ns=200)]
    result=m.evaluate(rows,[1,0])
    assert result['lut_mismatches']==0
    assert result['reference_mismatches']==1
    assert result['logical_errors']==1
    assert result['host_roundtrip_ns_median']==150
    assert result['cycles_min']==result['cycles_max']==2
    rows[0]['prediction']=0
    assert m.evaluate(rows,[1,0])['lut_mismatches']==1
