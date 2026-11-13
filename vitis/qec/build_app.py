"""Build the USB-only QEC ARM firmware using the proven ps_hello flow."""
from pathlib import Path
# Reuse platform/domain/CMake setup; only select this app's source and XSA.
source = Path("vitis/ps_hello/build_app.py").read_text()
source = source.replace("ps_hello", "qec").replace('"build/qec.xsa"', '"build/qec_soc.xsa"')
exec(compile(source, "vitis/qec/build_app.py", "exec"))
