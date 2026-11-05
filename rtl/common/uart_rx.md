# `uart_rx` — UART Receiver

## Goal

Receive an 8-bit byte from a UART serial line using the standard **8-N-1** format: one start bit, eight data bits (LSB first), and one stop bit.

## Concepts

### Input synchronization

The `rx` pin is asynchronous to the system clock, so it is first passed through a 2-stage synchronizer. This reduces the chance of metastability and also filters very short noise spikes.

### Start-bit detection

The receiver waits for the synchronized serial line to fall from idle (`1`) to `0`. That falling edge is the beginning of the start bit.

### Sampling at bit centers

To avoid sampling near bit transitions, the receiver waits **1.5 bit periods** after the falling edge before reading the first data bit. That lands exactly in the middle of the first data bit. After that, it waits one full bit period for each remaining bit.

```
        start           D0           D1
         |              |             |
    ____                ___________   ___________
        |______________|           |_|
        ^ falling      ^ sample here
```

### False-start rejection

If the line is no longer low at the **start-bit center**, the receiver discards the candidate and returns to idle. This filters out very short noise glitches.

### Stop-bit validation and recovery

One bit period after sampling data bit 7, the receiver samples the synchronized stop bit. Only HIGH produces a one-cycle `valid` pulse; LOW silently discards the byte. Both cases return to IDLE. There is no added reset or framing-error port. Consumers must ignore `data` unless `valid` is high: the shift register still contains sampled bits from rejected frames. After an idle interval, a subsequent well-formed frame is received normally; arbitrary break/continuous-low resynchronization is not guaranteed.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CLK_FREQ_HZ` | `125_000_000` | Frequency of `clk` in hertz. |
| `BAUD_RATE` | `115_200` | Desired baud rate. |

## Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock. |
| `rx` | input | 1 | Serial input. |
| `data` | output | 8 | Received byte. Valid while/after `valid` is high. |
| `valid` | output | 1 | One-cycle pulse after a complete frame is received. |

## Usage Example

```systemverilog
uart_rx #(
    .CLK_FREQ_HZ(125_000_000),
    .BAUD_RATE  (115_200)
) rx_inst (
    .clk   (clk),
    .rx    (uart_rx_pin),
    .data  (rx_data),
    .valid (rx_valid)
);
```

## Testing

See `rtl/tb/tb_uart_rx.sv` for nominal byte reception. Run `python scripts/qec_sim.py` for the paired [`tb_uart_rx_framing`](../tb/tb_uart_rx_framing.md) regression: an incoming `0xA5` with a LOW stop bit must produce no pulse, then a valid `0x3C` after idle must produce exactly one single-cycle pulse without reset.
