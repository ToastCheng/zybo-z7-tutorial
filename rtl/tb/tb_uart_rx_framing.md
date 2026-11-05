# Incoming UART framing-error regression

`tb_uart_rx_framing.sv` drives the real receiver input, not an outbound UART monitor. It sends `0xA5` with a LOW stop bit and requires **no** `valid` pulse, including the following three idle bit periods. It then sends a valid `0x3C` frame without resetting the receiver and requires exactly one matching, single-cycle pulse. The interface intentionally has no reset or framing-error output.

Stimulus changes on falling clock edges; output checks occur after rising-edge nonblocking updates. A 32-clock bit period leaves margin for the input synchronizer. A watchdog makes missing completion fatal. Recovery is checked after idle; this does not promise arbitrary break/continuous-low or zero-gap malformed-stream resynchronization.

Run from the repository root with `python scripts/qec_sim.py` (includes this regression). Before the stop-bit fix, xsim must fail with `Unexpected received byte 0xa5 (count=0)`; after the fix it prints `PASS tb_uart_rx_framing: bad stop rejected, next frame recovered`.
