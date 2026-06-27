# `tb_sync` — Testbench for the Input Synchronizer

## Goal

Verify that the `sync` module delays the input by two clock cycles and always produces a clean digital output (`0` or `1`).

## Important Note About Metastability

This testbench cannot directly simulate metastability. Simulators model flip-flops as ideal digital elements, so an input that changes at the wrong time will still resolve to either `0` or `1` instantly.

In real hardware, the first flip-flop can enter a metastable state and take some time to settle. The synchronizer's job is to give it that time. This testbench verifies the **latency and structure** of the synchronizer, which are the parts we can simulate.

## Concepts

### Verifying Latency

```systemverilog
din = 1;
@(posedge clk);
if (dout !== 0) $error("dout should still be 0 after 1 cycle");
@(posedge clk);
if (dout !== 1) $error("dout should be 1 after 2 cycles");
```

With 2 stages, the input should appear at the output two clock cycles later.

### Clean Digital Values

```systemverilog
if (dout === 1'bx || dout === 1'bz) $error("dout is not a clean digital value");
```

- `x` means unknown.
- `z` means high-impedance (floating).
- A properly functioning synchronizer output should never be `x` or `z`.

## How to Run

```bash
make sim TB=tb_sync
```

## Expected Output

```
Starting sync testbench...
sync testbench passed.
```

## Exercises

1. Change `STAGES` to 3 and verify the output is delayed by 3 cycles.
2. What happens if you use `STAGES = 1`?
3. Try changing `din` exactly on the clock edge. What value does the simulator choose?
