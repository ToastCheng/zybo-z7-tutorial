# Host tutorial
Run from repo root: `qec/.venv/bin/python qec/host.py --mode loopback --shots 20000 --seed 90210`. This samples real Stim detector/observable windows and exchanges framed syndromes with software only. JSON reports logical errors and prediction mismatches against noise-matched PyMatching. `fpga_measured=false` is deliberately conservative: this generic serial client cannot certify that an explicitly supplied port is a programmed board rather than a pseudo-terminal. Board identity/programming evidence must be supplied separately. The automated tests exercise real pyserial against a Linux pseudo-terminal with an emulated responder, not physical hardware.

## PL UART wiring and hardware status

The current PL design requires an **external 3.3 V USB–UART adapter**, configured for **115200 baud, 8N1**:

| Adapter / host signal | Zybo Z7-10 connection | PL direction |
|---|---|---|
| host TX (adapter TXD) | Pmod JE1, FPGA package pin V12 | `uart_rx` input |
| host RX (adapter RXD) | Pmod JE2, FPGA package pin W16 | `uart_tx` output |
| GND | Board/Pmod GND | Common ground |

Use 3.3 V logic, **not 5 V TTL or RS-232 voltage levels**. The onboard **PROG/UART** USB serial connection goes to the **PS UART**, not this PL UART design. It may provide JTAG programming access, but opening its serial port will not reach this endpoint. USB-only serial use would require a PS/PL bridge that is not implemented here.

This is **not a turnkey board image**. The report-only `scripts/qec_build.tcl` flow has generated **no QEC bitstream** and does not program hardware. The routed UART report still contains DRC warning `ZPS7-1` (PS7 block required); PS configuration and hardware bring-up remain unresolved. Passing simulation/routed timing is not evidence of physical UART operation.

## Later board run

Only after resolving the PS configuration/DRC bring-up issue, generating and separately programming a suitable QEC bitstream, and checking the adapter wiring above, run `qec/.venv/bin/python qec/host.py --mode serial --port /dev/ttyUSB1 --baud 115200 --shots 1000 --seed 90210 --timeout 1`. Replace the example port with the external adapter's actual port, not the onboard PS serial port. Explicit port is mandatory; the CLI never discovers or opens a board by default. pyserial OS errors are fatal. No board is attached during current experiments. Serial roundtrip includes host scheduling and UART; reported RTL cycles measure acceptance-to-result only. A mismatched-noise table may differ from noise-matched PyMatching.
