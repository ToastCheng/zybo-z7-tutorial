# USB-only physical QEC bring-up

## Verified and blocked boundaries

The board is actually connected: FTDI `0403:6010`, Digilent target
`localhost:3121/xilinx_tcf/Digilent/210351BE7C3EA`, Zynq `xc7z010_1`.
PS UART1 is `/dev/ttyUSB1`, stable alias
`/dev/serial/by-id/usb-Digilent_Digilent_Adept_USB_Device_210351BE7C3E-if01-port0`.

Vivado/Vitis 2025.2 generated a real PS+PL bitstream and ARM ELF. XSCT
programmed PL, initialized PS and downloaded/started firmware. A subsequent
independent Vivado configuration-status read found DONE internal/pin = 1,
INIT_B internal/pin = 1, CRC_ERROR = 0, IDCODE_ERROR = 0, EOS = 1.
This is **configuration status**, not full configuration-memory readback.
No flash, SD card, QSPI or persistent boot image was modified.

The first Python serial transaction command was blocked by the execution
tool because its approval prompt timed out. The tool explicitly states the
command did not run and prohibits retrying/rephrasing without renewed approval.
Thus **zero physical decoder transactions are verified**. Do not interpret
successful configuration, simulation or the unexercised runner as a successful
board corpus. Serial approval, exhaustive hardware checks, Stim replay and
measured host/USB latency remain outstanding.

## Reproduction after serial approval

From repository root:

```sh
VIVADO=/home/toastcheng/amd/2025.2/Vivado/bin
VITIS=/home/toastcheng/amd/2025.2/Vitis/bin
$VIVADO/vivado -mode batch -source scripts/build_soc.tcl -tclargs top_qec_soc > build/qec_soc_build.log 2>&1
$VITIS/vitis -s vitis/qec/build_app.py > build/qec_firmware_build.log 2>&1
$VITIS/xsct scripts/run_soc.tcl build/qec_soc.bit build/vitis_ws/qec_app/build/qec_app.elf build/qec_soc.xsa > build/qec_program.log 2>&1
$VIVADO/vivado -mode batch -source scripts/qec_readback.tcl > build/qec_readback.log 2>&1
qec/.venv/bin/python qec/hardware_run.py --port /dev/ttyUSB1 --board-id 210351BE7C3EA --shots 8192 --noise .01 --seed 20261105 --out qec/results/hardware-approved-run
```

The last command must receive renewed tool permission; it has **not run**.
Use a new output directory every time. A successful run must include all
256 LUT syndromes, 8192 real Stim shots, raw request/reply hex, checksum and
partial-frame timeout recovery, comparisons against the fixed LUT and
PyMatching, observable failures, and a manifest with source/artifact hashes.
Its hardware main may reveal issues not covered by unit or RTL tests.

## Timing boundaries

FCLK_CLK0 is configured and routed at **100 MHz**, not the PL oscillator's
125 MHz. Routed WNS **3.192 ns**, WHS **0.053 ns**; 0 failing setup/hold
endpoints, 0 unclocked registers, 0 unconstrained internal endpoints.
The four LED outputs have no external output-delay requirement and are
reported as no_output_delay. Whole SoC utilization is 511 LUTs and 950 FFs.
The Digilent PS preset retains negative DDR DQS skew parameter warnings;
these were not suppressed. Full top-level DDR/MIO ports are preserved, so
there are no unsupported internal-pin property warnings. Bitstream step:
0 warnings, 0 critical warnings, 0 errors.

The bridge contains a real free-running FCLK timestamp difference and
reports acceptance to first out_valid availability, subtracting the one
observer cycle needed to capture the registered result. Independent RTL
edge checks yield **2 cycles = 20 ns at configured 100 MHz**, while status
capture takes 3 cycles = 30 ns. These are **simulation-verified boundaries,
not yet a board timing measurement**. PS polling, AXI latency and USB/UART
roundtrip are separate. Firmware ignores the old core's constant schedule
field. This is finite-shot repetition-code observable prediction only.

## Tests

Strict TDD RED/GREEN evidence: missing bridge module fails xelab before
implementation; exhaustive bridge simulation then passes. Missing firmware
fails native gcc compile before parser implementation; exact shared parser
then passes checksum/framing/recovery/timeout tests. Missing physical runner
fails pytest before implementation; accounting test then passes.

```sh
QEC_RTL=1 qec/.venv/bin/python -m pytest qec/tests -q
# 9 passed

gcc -std=c11 -Wall -Wextra -Werror qec/test_ps_firmware.c -o build/test_ps_firmware
build/test_ps_firmware
# PASS PS firmware frame/checksum/recovery/timeout

$VIVADO/xvlog --sv rtl/common/qec_decoder.sv rtl/common/qec_ps_bridge.sv qec/tb_ps_bridge.sv
$VIVADO/xelab tb_ps_bridge -s ps_bridge
$VIVADO/xsim ps_bridge -runall
# PASS PS bridge 256 predictions, counter edges, hold and reset
```

The first firmware build caught a real version mismatch: Vitis unified 2025.2
uses `xiltimer.h`, not legacy `xtime_l.h`. The corrected build succeeded.
Original `qec/results` software/RTL datasets and `qec/lut.mem` are unchanged.
