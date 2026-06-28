# Phase 4 — UART Loopback

## Goal

Receive bytes over a UART serial interface and immediately echo them back. This phase introduces serial communication, one of the most common ways for an FPGA to talk to a host computer or microcontroller.

## Hardware Setup

The Zybo Z7-10 does **not** route the on-board USB-UART bridge to the FPGA fabric; it is connected to the ARM processor (PS). For this phase you need an external USB-to-UART adapter connected to **Pmod JE**:

| Pmod JE Pin | Signal | Direction | Connect to adapter |
|-------------|--------|-----------|--------------------|
| JE1 (V12) | `uart_rx` | FPGA input | adapter TX |
| JE2 (W16) | `uart_tx` | FPGA output | adapter RX |
| GND | GND | - | adapter GND |

> **Important:** Do not connect the adapter’s 3.3 V output to the Pmod power pin unless you are sure it is needed. Power and ground from the Zybo are sufficient.

## Concepts

### UART frame

UART sends data one bit at a time. A single byte is wrapped in a frame:

```
idle  start  D0  D1  D2  D3  D4  D5  D6  D7  stop  idle
  1     0    b0  b1  b2  b3  b4  b5  b6  b7   1     1
```

The line idles high. A start bit (`0`) marks the beginning, then the eight data bits are sent least-significant bit first, and finally a stop bit (`1`) returns the line to idle.

### Loopback

The top-level module does three things:

1. Receive a byte on `uart_rx`.
2. Store it in a one-byte buffer.
3. Transmit the buffered byte on `uart_tx` as soon as the transmitter is idle.

Because the UART runs at the same baud rate in both directions, the echo is a constant stream of bytes at the same rate they arrive.

### Baud-rate generation

Both `uart_rx` and `uart_tx` divide the 125 MHz system clock by `CLK_FREQ_HZ / BAUD_RATE` to produce one bit period. With the default 115200 baud, each bit lasts about 8.7 µs.

## Build and Run

```bash
make build TOP=top_uart_loopback
make prog TOP=top_uart_loopback
```

After programming, open a serial terminal (e.g., `picocom`, `minicom`, or PuTTY) connected to your USB-UART adapter at **115200 baud, 8 data bits, no parity, 1 stop bit**. Anything you type should be echoed back, and the lower nibble of the last received byte appears on `LD0`–`LD3`.

## Exercises

1. Change the baud rate to 9600 or 921600 and verify the terminal still echoes correctly.
2. Display the full received byte on the RGB LED using three PWM channels (red = upper 3 bits, green = middle 3 bits, blue = lower 2 bits).
3. Add a FIFO so the design can echo back-to-back bytes without dropping them.
