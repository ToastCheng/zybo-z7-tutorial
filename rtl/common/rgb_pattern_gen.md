# `rgb_pattern_gen` — RGB LED Pattern Generator

## Goal

Produce red, green, and blue PWM duty-cycle values for a single RGB LED based on a user-selected mode. This module demonstrates two key digital-design ideas:

1. **Multiplexers** — a `case` statement selects one of many pre-defined outputs.
2. **Pattern generators** — counters and arithmetic create repeating color sequences.

## Concepts

### Multiplexing

The `mode` input is a 4-bit value, so it can select one of 16 patterns. Inside the module a `case` statement acts like a multiplexer: the same hardware computes all possible outputs, then the selected one is routed to the output pins.

### Animation state

Static modes ignore the `tick` input and produce a constant color. Animated modes use a free-running counter (`state`) that advances by one every `tick`. Because the counter has the same width as the intensity output, it wraps around automatically, giving a smooth repeating sequence.

### Breathe effect

The breathe pattern uses a triangle wave: a counter counts up to the maximum intensity, then back down to zero, then up again. This makes the LED slowly fade in and out.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `INTENSITY_BITS` | `3` | Number of bits per color channel. With the default, intensity ranges from `0` (off) to `7` (maximum brightness). |

## Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock. |
| `tick` | input | 1 | One-cycle pulse. Static modes ignore it; animated modes advance by one step on each pulse. |
| `mode` | input | 4 | Pattern selector (see table below). |
| `r` | output | `INTENSITY_BITS` | Red channel intensity. |
| `g` | output | `INTENSITY_BITS` | Green channel intensity. |
| `b` | output | `INTENSITY_BITS` | Blue channel intensity. |

## Mode Table

| Mode | Pattern | Behavior |
|------|---------|----------|
| 0 | Off | All channels are `0`. |
| 1 | Red | Red only. |
| 2 | Green | Green only. |
| 3 | Blue | Blue only. |
| 4 | Yellow | Red + green. |
| 5 | Cyan | Green + blue. |
| 6 | Magenta | Red + blue. |
| 7 | White | All channels at maximum. |
| 8 | Slow rainbow | Phase-shifted ramps; colors cross-fade slowly. |
| 9 | Fast rainbow | Same idea as mode 8, with larger phase steps. |
| 10 | White breathe | All channels follow a triangle wave, so the LED breathes. |
| 11–15 | Off | Reserved/unused. |

## Usage Example

```systemverilog
logic [2:0] r_duty, g_duty, b_duty;

rgb_pattern_gen #(.INTENSITY_BITS(3)) pat (
    .clk  (clk),
    .tick (update_tick),
    .mode (sw[3:0]),
    .r    (r_duty),
    .g    (g_duty),
    .b    (b_duty)
);
```

The 3-bit intensity values can be connected to PWM modules either directly (if the PWM is also 3-bit) or zero-extended to a higher-resolution PWM, as in `top_switch_modes`.

## Testing

See `rtl/tb/tb_rgb_pattern_gen.sv`. It verifies:

- Static modes produce the expected color.
- Animated modes change their output after one or more ticks.
