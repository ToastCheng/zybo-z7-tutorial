# Testbench Guide

This directory contains SystemVerilog testbenches for the reusable modules in `rtl/common/`.

## What is a testbench?

A testbench is just another SystemVerilog module, but it has **no input or output ports**. Its job is to:

1. Instantiate the module you want to test (the **Device Under Test**, or DUT).
2. Generate a clock and drive input signals (stimulus).
3. Check that the outputs behave as expected.
4. Print a pass/fail message.

Testbench code is **not synthesised** — it only runs in the simulator.

## Running a testbench

Use the Makefile from the project root:

```bash
make sim TB=tb_sync
make sim TB=tb_debounce
make sim TB=tb_edge_detect
```

This invokes Vivado Simulator (`xsim`) through `scripts/sim.tcl`.

## Time, clocks, and delays

Every `.sv` file starts with:

```systemverilog
`timescale 1ns / 1ps
```

This means:

- The simulator’s **time unit** is 1 nanosecond (ns).
- The simulator’s **precision** is 1 picosecond (ps).

So a delay like `#100` means **100 ns**, and `#80` means **80 ns**.

The Zybo Z7-10 clock is 125 MHz, which has a period of 8 ns. In every testbench you will see:

```systemverilog
initial begin
    clk = 0;
    forever #4 clk = ~clk;
end
```

`#4` means wait 4 ns, so the clock toggles every 4 ns and has a full period of 8 ns.

### Stimulus example: `tb_debounce.sv`

```systemverilog
din = 1; #100;  // drive din high, wait 100 ns
din = 0; #80;   // drive din low, wait 80 ns
din = 1; #120;  // ... and so on
```

This sequence models a real mechanical button: the contact bounces on and off several times before finally settling. The delays are chosen to be shorter than the debouncer’s stable-time threshold, so the output should ignore them.

## Assertions and pass/fail checks

Because these are simple module-level testbenches, we use plain `if` statements instead of a formal assertion library. This is the hardware equivalent of a software unit-test assertion.

### Explicit pass/fail (`tb_sync.sv`, `tb_edge_detect.sv`)

```systemverilog
int error_count;

// ... drive stimulus ...

if (dout !== expected_value) begin
    $error("Output did not match expected value");
    error_count++;
end

if (error_count == 0) begin
    $display("testbench passed.");
end else begin
    $display("testbench failed with %0d errors.", error_count);
end
```

- `$error(...)` prints an error message and is the equivalent of `ASSERT_*` in a C++ unit-test framework or `assert` in Python.
- `$display(...)` prints an informational message.
- `$finish` stops the simulator.

### Implicit pass/fail (`tb_debounce.sv`)

`tb_debounce.sv` uses `wait` statements instead of counting errors:

```systemverilog
wait (dout == 1);
$display("Output went high after bounce settled.");
```

This works because the debouncer is supposed to reject the bounce and eventually assert `dout`. If the output never changes, the `wait` will hang and the simulator will time out. That is the failure mode, but it is not as obvious as the `$error`/`error_count` style used in the other testbenches.

A more explicit version could:

- Count how many times `dout` transitions (it should be exactly two: one low→high and one high→low).
- Add a timeout so the testbench fails quickly if `dout` never changes.

## Sampling on clock edges

Flip-flops update on a clock edge. To avoid race conditions between the DUT updating its outputs and the testbench reading them, checks are usually done at the opposite clock edge from the update, or after waiting for a full clock cycle.

For example, if the DUT updates on `posedge clk`, the testbench samples on `negedge clk`:

```systemverilog
@(negedge clk);
if (dout !== expected_value) ...
```

## One-cycle pulses

Some outputs, like `rising` and `falling` in `edge_detect`, are high for only **one clock cycle**. You cannot check them easily from an `initial` block because the pulse may be gone by the time you look. The usual trick is to capture the pulse in a register:

```systemverilog
always_ff @(posedge clk) begin
    if (reset_flags) begin
        rising_seen <= 0;
    end else if (rising) begin
        rising_seen <= 1;
    end
end
```

Later in the test you can check whether `rising_seen` was ever set.

## Summary

| Concept | Software equivalent | How it appears here |
|---------|---------------------|---------------------|
| Testbench | Test fixture / test class | `module tb_*;` with no ports |
| Stimulus | Test input values | `din = 1; #100;` |
| Assertion | `assert` / `EXPECT_*` | `if (x !== y) $error(...);` |
| Pass/fail | Test runner output | `$display(...)` and `$finish` |
| Clock | Event loop / scheduler | `forever #4 clk = ~clk;` |

For concrete examples, see the comments at the top of each testbench file.
