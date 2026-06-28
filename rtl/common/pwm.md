# `pwm` — Pulse-Width Modulation Generator

## Goal

Generate a digital pulse train whose average voltage is proportional to an input duty-cycle value. This lets us control LED brightness and create colors on an RGB LED.

## Concepts

### What Is PWM?

A digital pin can only be `0` or `1`. To create the illusion of an intermediate brightness, we rapidly toggle the pin. If the pin is high for a larger fraction of each cycle, the LED appears brighter.

```
10% duty:  _|‾|_________|‾|_________
50% duty:  _______|‾‾‾‾‾‾‾‾|_______
90% duty:  ‾‾‾‾‾‾‾‾‾|_|‾‾‾‾‾‾‾‾‾‾‾
```

Our eyes integrate the rapid flashing, so we perceive average brightness rather than individual pulses.

### How This Module Works

The module contains a free-running `N`-bit counter. The counter increments every clock cycle and wraps around after `2^N` cycles.

The output is high whenever the counter value is less than `duty`:

```systemverilog
assign pwm_out = (counter < duty);
```

- `duty = 0` → always low.
- `duty = 2^(N-1)` → 50% brightness.
- `duty = 2^N - 1` → almost always high (maximum brightness).

> Note: with this implementation, `duty = 2^N - 1` is the brightest value, not `2^N`. An `N`-bit `duty` cannot represent `2^N`.

### PWM Frequency

The PWM output frequency is:

```
f_pwm = f_clk / 2^N
```

With the default `N = 8` and a 125 MHz clock:

```
f_pwm = 125 MHz / 256 ≈ 488 kHz
```

This is fast enough that the LED will not flicker.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `N` | 8 | Bit width of the duty input and internal counter. Determines resolution and PWM frequency. |

## Code Walkthrough

```systemverilog
module pwm #(
    parameter int N = 8
)(
    input  logic clk,
    input  logic [N-1:0] duty,
    output logic pwm_out
);
```

- `parameter int N = 8` lets the user choose the resolution when instantiating the module.
- `duty` is an `N`-bit unsigned value controlling brightness.

```systemverilog
    logic [N-1:0] counter;

    always_ff @(posedge clk) begin
        counter <= counter + 1'b1;
    end
```

The counter wraps naturally when it reaches its maximum value.

```systemverilog
    assign pwm_out = (counter < duty);
```

This comparator produces the PWM waveform.

## Usage Example

```systemverilog
pwm #(.N(8)) pwm_red (
    .clk     (clk),
    .duty    (8'd128),  // 50% brightness
    .pwm_out (rgb_led[RGB_R])
);
```

## Exercises

1. What PWM frequency do you get with `N = 12`?
2. How would you invert the PWM polarity (active-low)?
3. Add an `enable` input that forces the output low when disabled.
