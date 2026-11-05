#!/usr/bin/env python3
"""Run isolated Vivado xsim regressions; fail on any HDL fatal or absent PASS."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BIN = Path(os.environ.get("VIVADO_BIN", str(Path.home()/"amd/2025.2/Vivado/bin")))
BUILD = ROOT / "build/qec_sim"
BUILD.mkdir(parents=True, exist_ok=True)
link = BUILD / "qec"
if not link.exists():
    link.symlink_to(ROOT / "qec", target_is_directory=True)
if not (ROOT / "qec/lut.mem").is_file():
    raise SystemExit("Generate the real qec/lut.mem first; no fallback LUT is used")
sources = ["rtl/common/sync.sv", "rtl/common/uart_rx.sv", "rtl/common/uart_tx.sv",
           "rtl/common/qec_decoder.sv", "rtl/top/top_qec_uart.sv",
           "rtl/tb/tb_qec_decoder.sv", "rtl/tb/tb_qec_uart.sv"]
def run(tool, *args):
    result = subprocess.run([str(BIN/tool), *args], cwd=BUILD,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end="", flush=True)
    if result.returncode or "Fatal:" in result.stdout or "FATAL" in result.stdout:
        raise SystemExit(f"{tool} failed")
    return result.stdout
run("xvlog", "--sv", *(str(ROOT/s) for s in sources))
for tb in ["tb_qec_decoder", "tb_qec_uart"]:
    run("xelab", "work."+tb, "--snapshot", tb, "--debug", "typical")
    output = run("xsim", tb, "--runall", "--log", tb+".log")
    if "PASS " not in output:
        raise SystemExit(f"{tb}: missing PASS marker")
