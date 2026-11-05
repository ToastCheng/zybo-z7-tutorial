# Host tutorial
Run from repo root: `qec/.venv/bin/python qec/host.py --mode loopback --shots 20000 --seed 90210`. This samples real Stim detector/observable windows and exchanges framed syndromes with software only. JSON reports logical errors and prediction mismatches against noise-matched PyMatching. `fpga_measured=false` is deliberately conservative: this generic serial client cannot certify that an explicitly supplied port is a programmed board rather than a pseudo-terminal. Board identity/programming evidence must be supplied separately. The automated tests exercise real pyserial against a Linux pseudo-terminal with an emulated responder, not physical hardware.

## PL UART wiring and hardware status

The current PL design requires an **external 3.3 V USB–UART adapter**, configured for **115200 baud, 8N1**:

| Adapter / host signal | Zybo Z7-10 connection | PL direction |
|---|---|---|
| host TX (adapter TXD) | Pmod JE1, FPGA package pin V12 | `uart_rx` input |
| host RX (adapter RXD) | Pmod JE2, FPGA package pin W16 | `uart_tx` output |
| GND | Board/Pmod GND | Common ground |

Use 3.3 V logic, **not 5 V TTL or RS-232 voltage levels**. The onboard **PROG/UART** USB serial connection goes to **PS UART1**, not this PL-only UART design. The new `top_qec_soc` path bridges PS UART1 to PL through AXI GPIO; it needs no adapter. See [hardware-bringup.md](hardware-bringup.md) for build/program evidence and current approval blocker.

The separate report-only `scripts/qec_build.tcl` flow still produces no bitstream; use `scripts/build_soc.tcl -tclargs top_qec_soc` for the real PS+PL image. The actual board was successfully programmed and configuration status read back, but serial execution approval timed out before the first transaction.

## USB-only physical corpus

After renewed serial tool approval, run the physical-only [hardware_run.py](hardware_run.py) using the documented explicit board ID and serial port. It archives real request/reply bytes, observable/reference comparisons and source/bitstream hashes. It has not yet run on hardware; only its accounting helper is unit-tested. `host.py` intentionally retains conservative generic `serial-unverified-hardware` provenance because a supplied port alone cannot certify board identity.

For an independently programmed **PL-only UART** plus correctly wired external adapter, the generic client remains `qec/.venv/bin/python qec/host.py --mode serial --port <adapter-port> --baud 115200 --shots 1000 --seed 90210 --timeout 1`. Explicit port is mandatory. No auto-discovery occurs. Roundtrip includes host/USB/UART/ARM/AXI overhead; core cycles exclude these and do not establish a system feedback deadline. A mismatched-noise table may differ from noise-matched PyMatching.
