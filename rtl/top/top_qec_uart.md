# UART-connected full-shot QEC tutorial

`top_qec_uart.sv` wraps the fixed-cycle decoder with the existing `uart_rx`, `uart_tx`, and two-flop `sync` modules. It handles complete shots, not an indefinitely streaming measurement-round stream.

## Ports and board connection

`clk` defaults to 125 MHz; parameters `CLK_FREQ_HZ` and `BAUD_RATE` (default 115200) configure the existing 8N1 UART modules. `LUT_FILE` passes through to the decoder (default `qec/lut.mem`). `btn[0]` is synchronized active-high reset; remaining buttons and `sw` are unused. `led[3:0]` show the low nibble of completed replies. RGB red indicates a checksum error, blue indicates a transaction in progress; green is off.

Use the existing board XDC: K17 clock, JE1/V12 RX from host TX, JE2/W16 TX to host RX, common ground and **3.3 V** logic. This PL UART is on the Pmod, not the board's USB-UART PS connection. No board programming is performed by the dedicated script.

## Wire protocol

Request is exactly `[A5, seq, syndrome, A5 XOR seq XOR syndrome]` (hex bytes). Response is exactly `[5A, seq, prediction, cycles_lo, cycles_hi, XOR_of_previous_five]`. Prediction is zero or one. The syndrome packs eight Stim detectors little-endian. The result's cycle field is the decoder's two-clock accept-to-result interval, not UART transit or host latency.

Only one request may be outstanding: wait for the entire six-byte reply before sending the next. The parser does not receive during decode/transmission; there is no RTS/CTS or queue. A bad checksum produces no reply; the next valid header starts recovery. A bad checksum byte equal to A5 is reused as a possible next header. Arbitrary A5 bytes within payloads are legal. Noise bytes outside a frame are discarded.

## Reset and limitations

Reset aborts parser/core state and clears LEDs. Existing UART blocks have no reset input: a byte already transmitting finishes and a partial received UART byte may still arrive. Reset should therefore be held with RX idle and the host should drain pending bytes before retrying. A partial packet is abandoned after twenty configured bit periods without a completed byte (roughly two byte times). Keep inter-byte idle below ten bit periods; after a truncated packet, wait at least twenty bit periods before sending a new header. Existing RX does not reject invalid stop bits, so checksum detects some but not all framing errors. XOR is not a CRC and offers no adversarial integrity guarantee.

## Invoke

Run `python scripts/qec_sim.py`. Build/report with `~/amd/2025.2/Vivado/bin/vivado -mode batch -source scripts/qec_build.tcl -tclargs uart`. No hardware connection is required; synthesis/routing is not hardware verification or a hard real-time host deadline claim.
