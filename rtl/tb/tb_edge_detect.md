# `tb_edge_detect` — Testbench for the Edge Detector

## Goal

Verify that the `edge_detect` module produces a single-cycle pulse on `rising` when `din` goes from `0` to `1`, and a single-cycle pulse on `falling` when `din` goes from `1` to `0`.

## What Is a Testbench?

A testbench is an HDL module that is **not synthesized**. It exists only in simulation. It instantiates the module you want to test (called the **Device Under Test**, or **DUT**), generates input signals, and checks that the outputs are correct.

## Concepts

### `timescale

```systemverilog
`timescale 1ns / 1ps
```

This directive tells the simulator that:
- Time values are in **nanoseconds**.
- Precision is **picoseconds**.

So `#4` means 4 ns, and `#4.5` means 4.5 ns.

### Generating a Clock

```systemverilog
initial begin
    clk = 0;
    forever #4 clk = ~clk;
end
```

This creates a clock with an 8 ns period (125 MHz). `forever` means the loop runs for the entire simulation.

### Capturing One-Cycle Pulses

`rising` and `falling` are each high for only one clock cycle. If we try to check them directly, we can hit a **race condition**: the check and the flip-flop update happen at the same clock edge, and the order is unpredictable.

To avoid this, the testbench latches the pulses into registers:

```systemverilog
always_ff @(posedge clk) begin
    if (reset_flags) begin
        rising_seen  <= 0;
        falling_seen <= 0;
    end else begin
        if (rising)  rising_seen  <= 1;
        if (falling) falling_seen <= 1;
    end
end
```

These flags stay high until we synchronously reset them, so we can safely check them later in the simulation.

### Checking Outputs

```systemverilog
if (rising_seen !== 1) begin
    $error("Expected rising pulse after rising edge");
    error_count++;
end
```

- `!==` is the case-equality operator; it also checks for `x` and `z` values.
- `$error` prints an error message but continues the simulation.
- We count errors and report pass/fail at the end.

### Why Check at `negedge clk`?

Registered signals (like `dout` of a synchronizer) are stable shortly after the rising clock edge. But combinational pulses generated at the rising edge are only valid for a brief moment. By checking the latched flags at the **falling** clock edge, we give the flags time to update and avoid race conditions.

## How to Run

```bash
make sim TB=tb_edge_detect
```

## Expected Output

```
Starting edge_detect testbench...
edge_detect testbench passed.
```

## Exercises

1. Modify the testbench to test multiple rising and falling edges.
2. What happens if `din` changes on the falling clock edge instead of between clock edges?
3. Add a check that both `rising` and `falling` are never high at the same time.
