# USB-only physical QEC bring-up

## Verified physical boundaries

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

The earlier approval timeout is preserved in the historical
`results/hardware-20261105-usb-blocked/` snapshot. After explicit user approval,
the real serial probe returned request `a5013793`, reply `5a0101020058`
(sequence 1, prediction 1, measured cycles 2). Two full physical runs then
succeeded; they are not loopback or pseudo-terminal results.

- `results/hardware-approved-run/`: all 256 syndromes, 8192 real Stim
  shots at p=.01 / seed 20261105, and three malformed-traffic recovery checks.
  Zero hardware-vs-LUT or hardware-vs-PyMatching mismatches. Observable
  errors 51/8192 (0.6226%; 95% Wilson 0.4738–0.8176%) versus identity 458/8192.
- `results/hardware-after-reset/`: after volatile PL reprogramming and
  processor reset/relaunch, all 256 syndromes, 4096 p=.001 / seed 20261106
  shots and the same three recovery checks passed. Observable errors 0/4096
  versus identity 20/4096. Zero observed errors is not zero underlying risk:
  the 95% Wilson upper bound is 0.09370%.
- In total, 12806 captured successful request/reply transactions:
  12288 Stim shots, 512 exhaustive checks, six recovery requests. The single
  preliminary probe is separately recorded above and excluded from that total.
- Every captured reply reported 2 measured PL cycles. Both physical runs
  rejected bad checksum, garbage and an abandoned partial frame, then
  accepted the next good request.

Independent validation re-created the exact seeded Stim syndromes/observables
and PyMatching references, parsed every archived request/reply/checksum,
checked every prediction against the original LUT, and verified all 14
original artifact hashes in each manifest. Exhaustive rows use LUT values
as placeholder observables; only Stim rows define logical-error statistics.
The source revision is ae3362bea8b61564ee7bc0623d163a743a20a2bc; the only
then-untracked files were output directories, not modified source.

## Reproduction

From repository root:

```sh
VIVADO=/home/toastcheng/amd/2025.2/Vivado/bin
VITIS=/home/toastcheng/amd/2025.2/Vitis/bin
$VIVADO/vivado -mode batch -source scripts/build_soc.tcl -tclargs top_qec_soc > build/qec_soc_build.log 2>&1
$VITIS/vitis -s vitis/qec/build_app.py > build/qec_firmware_build.log 2>&1
$VITIS/xsct scripts/run_soc.tcl build/qec_soc.bit build/vitis_ws/qec_app/build/qec_app.elf build/qec_soc.xsa > build/qec_program.log 2>&1
$VIVADO/vivado -mode batch -source scripts/qec_readback.tcl > build/qec_readback.log 2>&1
qec/.venv/bin/python qec/hardware_run.py --port /dev/ttyUSB1 --board-id 210351BE7C3EA --shots 8192 --noise .01 --seed 20261105 --out qec/results/hardware-reproduction-01
```

Use a new output directory every time; execution may require approving the
terminal permission card. The completed runs contain all 256 LUT syndromes,
real Stim shots, raw request/reply hex, malformed-traffic recovery, fixed-LUT
and matching comparisons, observables and source/artifact hashes. To repeat
the reset test, execute run_soc.tcl and qec_readback.tcl again before running
with `--shots 4096 --noise .001 --seed 20261106` into another fresh directory.
Reset coverage is full volatile reload/processor restart, not an isolated
in-flight reset or power cycle. No persistent boot image is written.

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
capture takes 3 cycles = 30 ns. The real board returned the instrumented
2-cycle count for every captured transaction. Conversion to nanoseconds uses
the configured clock, not an oscilloscope frequency measurement.

Inclusive host/USB/UART/ARM/AXI Stim roundtrip timing:
- 8192-shot p=.01 run: median 15.858794 ms, p99 16.558837 ms,
  minimum 14.912443 ms, maximum 16.957489 ms.
- 4096-shot p=.001 run after reload: median 15.876542 ms, p99 16.573238 ms,
  minimum 14.787078 ms, maximum 16.846082 ms.

The 10-byte 115200-baud 8N1 wire-time lower bound is 0.868056 ms; the measured
roundtrip includes USB buffering and scheduling. No FTDI-latency attribution
or tuning was independently tested. Do not compare 20 ns core timing with
CPU end-to-end latency or infer a quantum feedback deadline. Firmware ignores
the old core's constant schedule field. No initiation-interval benchmark,
isolated in-flight reset, deliberate PS UART stop-bit fault, adaptive quantum
feedforward or physical quantum correction was tested. This is finite-shot
simulated repetition-code observable prediction on real classical hardware.

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
