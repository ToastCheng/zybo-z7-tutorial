# UART protocol regression tutorial

`tb_qec_uart.sv` is a portless non-synthesizable testbench. It overrides UART parameters for 32 clock ticks per bit while preserving 8N1 timing, sends pin-level serial requests, and independently samples outgoing start/data/stop bits rather than reusing the DUT receiver as its scoreboard.

Run `python scripts/qec_sim.py`. The bench loads the actual LUT and checks reply marker, echoed sequence, prediction, little-endian cycle bytes and XOR. It tests ignored leading garbage, a corrupted checksum with no reply, recovery to valid frames, A5 in sequence/syndrome payloads, FF and zero sequences, reset abandoning an incomplete request, timeout recovery without reset, and all 256 syndromes over the UART. A watchdog catches deadlock. Success prints `PASS UART exhaustive 256 syndromes, framing/checksums/malformed recovery/reset/timeout: 260 replies`.

The accelerated baud does not validate electrical margins or USB behavior. The interface deliberately requires one outstanding transaction; it is not a throughput test or a real-time latency claim.
