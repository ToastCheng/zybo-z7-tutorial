"""Build surface ARM transport only; all decoding happens in programmable logic."""
from pathlib import Path
source=Path("vitis/ps_hello/build_app.py").read_text()
source=source.replace("ps_hello","surface").replace('"build/surface.xsa"','"build/surface_soc.xsa"')
exec(compile(source,"vitis/surface/build_app.py","exec"))
