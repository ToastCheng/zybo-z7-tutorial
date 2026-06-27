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

### Checking Outputs

```systemverilog
if (rising !== 1) $error("Expected rising pulse after rising edge");
```

- `!==` is the case-equality operator; it also checks for `x` and `z` values.
- `$error` prints an error message but continues the simulation.
- `$fatal` would stop the simulation immediately.

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
