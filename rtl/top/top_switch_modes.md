# Phase 3 — Switch-Controlled RGB LED Modes

## Goal

Use the Zybo’s four slide switches (`SW0`–`SW3`) to choose one of 16 RGB LED patterns. This phase introduces two new ideas:

1. **Multiplexers** — selecting one of many possible outputs based on a control input.
2. **Pattern generators** — using counters and arithmetic to create animated light effects.

## Concepts

### Mode selection as a multiplexer

The value on `sw[3:0]` is treated as a 4-bit number. Inside `rgb_pattern_gen`, a `case` statement uses that number to pick which color or animation to output. This is conceptually the same as a 16-to-1 multiplexer.

### Reusing the PWM building block

The `pwm` module from Phase 2 is reused unchanged. The new `rgb_pattern_gen` module only decides *what* duty cycle each channel should have; the PWM modules still produce the actual waveform.

### Keeping the LED comfortable

As in Phase 2, the 3-bit intensity values are zero-extended to the 8-bit PWM input. That caps the brightest setting at 7/256, which is easy to look at on the board.

## Hardware Behavior

| Switch value (`sw[3:0]`) | Mode | What the RGB LED does |
|--------------------------|------|------------------------|
| `0000` (all off) | 0 | LED off |
| `0001` | 1 | Solid red |
| `0010` | 2 | Solid green |
| `0011` | 3 | Solid blue |
| `0100` | 4 | Solid yellow |
| `0101` | 5 | Solid cyan |
| `0110` | 6 | Solid magenta |
| `0111` | 7 | Solid white |
| `1000` | 8 | Slow rainbow fade |
| `1001` | 9 | Fast rainbow fade |
| `1010` | 10 | White breathe |
| `1011`–`1111` | 11–15 | Off (reserved) |

The four single-color LEDs (`LD0`–`LD3`) mirror the switch positions, so you can see at a glance which switches are on.

## Build and Run

```bash
make build TOP=top_switch_modes
make prog TOP=top_switch_modes
```

After programming, try changing the slide switches. Each switch combination selects a different color or animation.

## Exercises

1. Add a new animated mode, for example a "police light" that flashes red and blue.
2. Make the animation speed depend on one of the push buttons.
3. Extend the pattern generator to 4-bit intensities (0–15) and see whether the higher brightness is still comfortable.
