# Phase 5: FIFO Loopback

## Goal

Use the reusable `fifo_sync` module in a real design. Push switch values into a FIFO with one button, pop them back out onto the LEDs with another button, and clear the FIFO with a third button.

## Hardware Setup

No external hardware is required. The design uses only the on-board switches, buttons, and LEDs.

| Control | Action |
|---------|--------|
| `SW0`–`SW3` | 4-bit data value to push. |
| `BTN0` | Hold to clear (reset) the FIFO. |
| `BTN1` | Push the current switch value into the FIFO. |
| `BTN2` | Pop the oldest value from the FIFO onto the LEDs. |
| `LD0`–`LD3` | Display the value currently at the FIFO read port. |
| RGB LED red | FIFO is full (dimmed via PWM). |
| RGB LED green | FIFO is empty (dimmed via PWM). |
| RGB LED blue | FIFO has data but is not full (dimmed via PWM). |

## Concepts

### Flow control

`full` and `empty` are the two basic flow-control signals of a FIFO. The producer must not write when `full` is high, and the consumer must not read when `empty` is high. In this design those signals are shown on the RGB LED.

### Switch debouncing and edge detection

The push and pop buttons are debounced, then a single-clock-cycle pulse is generated on each rising edge. This turns a long button press into one clean FIFO operation.

## Build and Run

```bash
make build TOP=top_fifo_loopback
make prog  TOP=top_fifo_loopback
```

## Try It

1. Set `SW0`–`SW3` to a pattern, then press `BTN1` to push it.
2. Change the switches and push a second value.
3. Press `BTN2` to pop the first value; it should appear on `LD0`–`LD3`.
4. Press `BTN2` again to see the second value.
5. Hold `BTN0` to clear the FIFO; the green LED should come on.
