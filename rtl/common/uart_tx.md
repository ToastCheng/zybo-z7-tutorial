# `uart_tx` — UART Transmitter

## Goal

Transmit an 8-bit byte over a UART serial line using the standard **8-N-1** format: one start bit, eight data bits (LSB first), and one stop bit.

## Concepts

### UART frame

A UART frame looks like this on the wire:

```
      start   D0   D1   D2   D3   D4   D5   D6   D7   stop
         |    |    |    |    |    |    |    |    |    |
    ____      ____ ____ ____ ____ ____ ____ ____ ____ ____
        |____|    |    |    |    |    |    |    |
         0    b0   b1   b2   b3   b4   b5   b6   b7   1
```

The line idles at `1`. A `0` start bit announces a new byte, then the data bits are sent least-significant bit first, and finally the line returns to `1` for at least one stop bit.

### Bit timing

The transmitter divides the system clock down to the requested baud rate. A counter counts `CLK_FREQ_HZ / BAUD_RATE` clock cycles for each bit. For the default 125 MHz clock and 115200 baud, each bit lasts about 8.7 µs.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CLK_FREQ_HZ` | `125_000_000` | Frequency of `clk` in hertz. |
| `BAUD_RATE` | `115_200` | Desired baud rate. |

## Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock. |
| `start` | input | 1 | One-cycle pulse that begins a transmission. |
| `data` | input | 8 | Byte to transmit. |
| `tx` | output | 1 | Serial output. |
| `busy` | output | 1 | High while a transmission is in progress. |

## Usage Example

```systemverilog
uart_tx #(
    .CLK_FREQ_HZ(125_000_000),
    .BAUD_RATE  (115_200)
) tx_inst (
    .clk   (clk),
    .start (tx_start),
    .data  (tx_data),
    .tx    (uart_tx_pin),
    .busy  (tx_busy)
);
```

## Testing

See `rtl/tb/tb_uart_tx.sv`. It transmits a known byte and samples the `tx` line at each bit center to verify the frame shape.
