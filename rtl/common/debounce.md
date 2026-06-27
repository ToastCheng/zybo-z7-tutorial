# `debounce` — Button Debouncer

## Goal

Filter out mechanical switch bounce from a push-button so that one physical press produces exactly one clean logic transition.

## Concepts

### Switch Bounce

When you press or release a mechanical button, the metal contacts do not separate or connect instantly. They bounce against each other for a short time (typically 1–10 ms), causing the electrical signal to toggle rapidly.

```
Expected:  ____|--------|
Actual:    ____|-|-||--||-|
```

Without debouncing, the FPGA might see many "presses" from a single button push.

### How This Debouncer Works

This module uses a **stability timer**:

1. Compare the input to the current debounced output.
2. If they are the same, reset the timer.
3. If they differ, start counting clock cycles.
4. Only update the output when the input has stayed different for `STABLE_US` microseconds.

Bounces are short, so they reset the timer before it reaches the threshold. A real press lasts much longer, so eventually the timer expires and the output updates.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CLK_FREQ_HZ` | 125_000_000 | System clock frequency in Hz. |
| `STABLE_US` | 10_000 | Required stable time in microseconds. 10 ms is conservative for most tactile buttons. |

## Code Walkthrough

```systemverilog
localparam int THRESHOLD  = (CLK_FREQ_HZ / 1_000_000) * STABLE_US;
localparam int CNT_WIDTH  = $clog2(THRESHOLD + 1);
```

- `localparam` is like `parameter` but cannot be overridden from outside the module.
- `$clog2(x)` returns the number of bits needed to represent `x` values.
- `THRESHOLD` converts microseconds into clock cycles.

```systemverilog
    if (din == dout_reg) begin
        counter <= '0;
    end else begin
        if (counter < THRESHOLD) begin
            counter <= counter + 1'b1;
        end else begin
            dout_reg <= din;
            counter  <= '0;
        end
    end
```

This is the core state machine:
- Same input → reset counter.
- Different input → count up.
- Reached threshold → accept the new value.

## Usage Example

```systemverilog
debounce debounce_btn0 (
    .clk  (clk),
    .din  (btn_sync[0]),
    .dout (btn_deb[0])
);
```

## Exercises

1. What happens if `STABLE_US` is too short (e.g., 1 us)?
2. What happens if `STABLE_US` is very long (e.g., 1 s)?
3. How would you modify the module to produce a pulse only when the output changes?
