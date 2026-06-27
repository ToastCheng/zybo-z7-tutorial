# `tb_debounce` — Testbench for the Debouncer

## Goal

Verify that the `debounce` module ignores rapid mechanical bounce and only updates its output after the input has been stable for the programmed time.

## Concepts

### Parameter Override in Testbench

```systemverilog
debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .STABLE_US   (STABLE_US)
) dut (...);
```

The `#(...)` syntax overrides the module's default parameters. Here we use `STABLE_US = 1` so the simulation finishes quickly. On the real board, the module uses the default `10_000` (10 ms).

### Simulating Bounce

```systemverilog
din = 1; #100;
din = 0; #80;
din = 1; #120;
din = 0; #60;
din = 1; #2000;
```

This creates a series of rapid transitions that model a real mechanical button bounce. The output should stay low until the input has been stable high for at least `STABLE_US`.

### `wait`

```systemverilog
wait (dout == 1);
```

This pauses the testbench until the condition becomes true. It is useful when you do not know exactly how many clock cycles something will take.

## How to Run

```bash
make sim TB=tb_debounce
```

## Expected Output

```
Starting debounce testbench...
Output went high after bounce settled.
Output went low after bounce settled.
debounce testbench passed.
```

## Exercises

1. Reduce `STABLE_US` until the testbench fails. What happens?
2. Add a counter to track how many times `dout` changes. Verify it equals 2.
3. Try removing the bounce and applying a clean press. How does the output respond?
