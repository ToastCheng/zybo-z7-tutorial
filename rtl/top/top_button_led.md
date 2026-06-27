# Phase 1: `top_button_led` — Button-Controlled LED

## Goal

Press a push-button and toggle one of the single-color LEDs. This introduces the full input-conditioning chain:

```
raw button --> synchronizer --> debouncer --> edge detector --> toggle flip-flop --> LED
```

## What You Should See

- All LEDs start off.
- Press `BTN0` → `LD0` toggles on/off.
- Press `BTN1` → `LD1` toggles on/off.
- Press `BTN2` → `LD2` toggles on/off.
- Press `BTN3` → `LD3` toggles on/off.

Each press should toggle the LED exactly once, even though the mechanical button bounces.

## Concepts

### Input Conditioning

Signals from the outside world are not ready to use directly. They must be:

1. **Synchronized** to the clock domain to avoid metastability.
2. **Debounced** to remove mechanical switch bounce.
3. **Edge-detected** so one press causes one action, not a continuous action while held.

### Toggle Flip-Flop

A toggle flip-flop changes state every time it receives a trigger. In SystemVerilog:

```systemverilog
led_reg[j] <= ~led_reg[j];
```

This inverts the current value: 0 becomes 1, and 1 becomes 0.

### Initial Values in FPGAs

```systemverilog
logic [NUM_LEDS-1:0] led_reg = '0;
```

This sets the power-on value of the register by initializing it in the declaration. It is **synthesizable in FPGAs** because the bitstream configures the initial state of each flip-flop. It is **not synthesizable in ASICs**, where a reset signal is required.

For this learning board, initialization keeps the design simple. In safety-critical or ASIC designs, you would use a dedicated reset.

### `generate` Loops

```systemverilog
genvar i;
generate
    for (i = 0; i < NUM_BUTTONS; i++) begin : g_button_channel
        sync sync_inst (...);
        debounce debounce_inst (...);
        edge_detect edge_detect_inst (...);
    end
endgenerate
```

`generate` creates multiple instances of hardware at compile time. It is not a runtime loop — it is a template that tells the synthesizer "make four copies of this circuitry."

## Block Diagram

```
+--------+   +----------+   +-------------+   +--------------+
|  btn   |-->|   sync   |-->|  debounce   |-->|  edge_detect |--+
+--------+   +----------+   +-------------+   +--------------+  |
                                                                |
                                              +---------------+ |
                                              | toggle FF     |<+
                                              | led_reg[j]    |
                                              +---------------+
                                                       |
                                                       v
                                                     led[j]
```

## How to Build and Test

1. Build the bitstream:

```bash
make build TOP=top_button_led
```

2. Program the board:

```bash
make prog TOP=top_button_led
```

3. Press each button and verify that the matching LED toggles once per press.

## Exercises

1. Change the code so a button turns its LED on when pressed and off when released (level-sensitive instead of edge-sensitive).
2. Add the slide switches: use `SW0` to select whether buttons toggle or momentarily light the LEDs.
3. Remove the debouncer and observe the bouncing behavior. How does the LED respond?
4. Modify the edge detector to react to the falling edge instead of the rising edge.
