# Phase 2: `top_pwm_rgb` — PWM RGB LED

## Goal

Use pulse-width modulation (PWM) to smoothly control the brightness and color of the RGB LED.

## What You Should See

The RGB LED (`LD6`) slowly fades through a range of colors. Because the red, green, and blue channels change at different rates, the color mix continuously shifts.

The four single-color LEDs (`LD0`–`LD3`) are off in this phase.

## Concepts

### PWM for Brightness

A digital pin can only be fully on (`1`) or fully off (`0`). PWM rapidly switches the pin on and off. The **duty cycle** is the fraction of time the pin spends on.

| Duty cycle | Perceived brightness |
|---|---|
| 0% | Off |
| 25% | Dim |
| 50% | Medium |
| 75% | Bright |
| ~100% | Full brightness |

Our eyes average the rapid flashes, so we see a steady brightness rather than flickering.

### PWM Frequency

With an 8-bit counter running at 125 MHz, the PWM frequency is:

```
125 MHz / 256 ≈ 488 kHz
```

This is far faster than the human eye can perceive, so the LED looks steady.

### Color Mixing

The RGB LED has three independent channels: red, green, and blue. By setting each channel to a different brightness, we can create many colors:

| Red | Green | Blue | Color |
|---|---|---|---|
| High | Low | Low | Red |
| Low | High | Low | Green |
| Low | Low | High | Blue |
| High | High | Low | Yellow |
| High | Low | High | Magenta |
| Low | High | High | Cyan |
| High | High | High | White |

### Slow Color Updates

The duty cycles are updated every 0.134 seconds. Because each channel increments by a different amount (`+1`, `+2`, `+3`), their relative values drift over time, creating a changing color mix.

## Block Diagram

```
         +-----------+
  clk -->|  Counter  |--> color update tick (every 0.134 s)
         +-----------+
                |
                v
         +--------------+
         | Duty Cycle   |---> duty_r
         | Generators   |---> duty_g
         | (+1, +2, +3) |---> duty_b
         +--------------+
                |
    +-----------+-----------+
    |           |           |
    v           v           v
 +-----+     +-----+     +-----+
 | PWM |     | PWM |     | PWM |
 |  R  |     |  G  |     |  B  |
 +--+--+     +--+--+     +--+--+
    |           |           |
    v           v           v
 rgb_led[2]  rgb_led[1]  rgb_led[0]
```

## Code Walkthrough

```systemverilog
    logic [7:0] duty_r;
    logic [7:0] duty_g;
    logic [7:0] duty_b;
```

These registers hold the current brightness level for each color channel. An 8-bit value gives 256 brightness steps.

```systemverilog
    always_ff @(posedge clk) begin
        if (counter[23:0] == 0) begin
            duty_r <= duty_r + 8'd1;
            duty_g <= duty_g + 8'd2;
            duty_b <= duty_b + 8'd3;
        end
    end
```

Every 0.134 seconds, each duty cycle is incremented by a different amount. The different rates cause the color mix to evolve over time.

```systemverilog
    pwm #(.N(8)) pwm_r (
        .clk     (clk),
        .duty    (duty_r),
        .pwm_out (rgb_led[RGB_R])
    );
```

The `pwm` module is instantiated three times, once per color channel. The `#(.N(8))` part overrides the default parameter value.

## Parameters

This top module has no parameters, but it uses the `pwm` module with `N = 8`.

## How to Build and Test

1. Build the bitstream:

```bash
make build TOP=top_pwm_rgb
```

2. Program the board:

```bash
make prog TOP=top_pwm_rgb
```

3. Watch the RGB LED. It should slowly cycle through colors.

## Exercises

1. Change the update rate by using a different bit of `counter`.
2. Make all three duty cycles increment by the same amount. What happens to the color?
3. Use the slide switches to select a fixed color (e.g., SW0 = red, SW1 = green, SW2 = blue).
4. Add a button that pauses the color fade.
