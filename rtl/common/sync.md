# `sync` — Input Synchronizer

## Goal

Safely bring an asynchronous external signal (like a push-button) into the FPGA clock domain.

## Concepts

### Clock Domains

Your FPGA design runs on a single clock (125 MHz in our case). Buttons, however, are pressed by a human — they change at completely unrelated times. A signal that is not governed by your clock is called **asynchronous**.

### Metastability

If a flip-flop samples an input exactly when it is changing, the flip-flop can enter a **metastable** state: its output hovers between 0 and 1 for an unpredictable amount of time. This can corrupt downstream logic.

We cannot eliminate metastability, but we can reduce the probability that it affects the rest of the design by passing the signal through a chain of flip-flops. Each stage gives the signal more time to settle to a valid 0 or 1.

> **Rule of thumb:** 2 flip-flops is enough for most FPGA applications.

### When Does Metastability Happen?

A flip-flop has a **setup time** and a **hold time** around each clock edge. During this window, the input must remain stable.

```text
     setup time              hold time
   (before edge)           (after edge)
        |                       |
        v                       v
<-------|-----------------------|-------> time
        |                       |
        |<--------------------->|
        |   forbidden region    |
        |  (input must stay     |
        |     stable here)      |
        |                       |
        |         ^             |
        |         |             |
        |      clock edge       |
        |                       |
```

- **Setup time** (`t_su`): the input must be stable for this long **before** the clock edge.
- **Hold time** (`t_h`): the input must remain stable for this long **after** the clock edge.
- **Forbidden region** = `t_su` + `t_h` around the clock edge.

If the input changes inside this forbidden region, the flip-flop may go metastable.

### Example

Suppose a flip-flop has:

- Setup time `t_su` = 0.5 ns
- Hold time `t_h` = 0.3 ns

Then the forbidden region is 0.8 ns wide, centered on the clock edge:

```text
      0.5 ns             0.3 ns
<---------------->|<---------------->
                 |
              clock edge
                 |
      input must be stable from here
      to here (total 0.8 ns window)
```

- Input changes at `t = -5 ns` → **safe**.
- Input changes at `t = -0.2 ns` → **inside setup window, metastability risk**.
- Input changes at `t = +0.1 ns` → **inside hold window, metastability risk**.
- Input changes at `t = +5 ns` → **safe**.

At 125 MHz, the clock period is 8 ns, so the forbidden window is only about 10% of the cycle. Metastability is rare, but not impossible.

## Why the Shift Register Helps

Here is the 2-stage synchronizer from `sync.sv`:

```text
async din --> [FF1] --> [FF2] --> dout
                  ^         ^
                  |         |
              sampled   sampled
              at T=0    at T=8ns
```

Your question is: *"We still output the value from the previous cycle, so how does that reduce risk?"*

The key insight is that we are not trying to get the newest value faster. We are deliberately waiting one clock cycle so that **FF1 has time to resolve to a valid 0 or 1 before FF2 samples it**.

### What happens at each clock edge

1. **First clock edge:**
   - `din` is asynchronous. If it changes inside the forbidden window, `FF1` may go metastable.
   - `FF1` captures either the old value or the new value, or enters metastability.

2. **During the next 8 ns (one clock period):**
   - If `FF1` went metastable, it has the entire 8 ns to settle to a valid `0` or `1`.
   - Most of the time it settles long before the next clock edge.

3. **Second clock edge:**
   - `FF2` samples the output of `FF1`.
   - If `FF1` has already resolved, `FF2` captures a clean digital level and will **not** go metastable.
   - Only if `FF1` is still metastable after 8 ns can `FF2` also fail. That probability is extremely small.

### What if we use more stages?

You might ask: *"The input is locked into FF1 at the first clock edge. Adding more stages does not give `din0` more time to change FF1, so how does it help?"*

The answer is that extra stages give the **metastable state inside the flip-flops** more time to resolve.

Here is a 3-stage synchronizer:

```text
clock X    clock X+1    clock X+2
  |            |            |
  v            v            v
FF1  ------>  FF2  ------>  FF3  ------> dout
```

| Clock | What happens |
|---|---|
| X | FF1 samples `din0`. If unlucky, FF1 goes metastable. |
| X → X+1 | FF1 has 8 ns to resolve to a valid `0` or `1`. |
| X+1 | FF2 samples FF1. If FF1 resolved, FF2 gets a clean value and we are done. If FF1 is **still** metastable (very rare), FF2 may also go metastable. |
| X+1 → X+2 | FF2 now has another 8 ns to resolve. |
| X+2 | FF3 samples FF2. The chance that FF2 is still metastable is now extremely tiny. |

With 3 stages, a metastable state has **16 ns** total to die out before it can reach `dout`.

### The resolved value may not match `din0`

When FF1 resolves from metastability, it settles to either `0` or `1`. Which one it chooses is unpredictable — it might be the old value or the new value.

For example, if you press a button and the input changes at the exact wrong time, the synchronizer might output:

- the pressed value, or
- the not-pressed value for one more cycle.

**This is fine.** For a button, we only care that the output is a valid `0` or `1`, not that it matches the exact current state of the button. The press will be registered one cycle earlier or later, which is irrelevant to a human.

> **Key takeaway:** A synchronizer guarantees a valid digital level. It does not guarantee which level, if the input changes during the forbidden window.

### What we give up

The output `dout` is **not** the current value of `din`. It is the value of `din` from one clock cycle ago. That is fine for a button — we do not care whether the press is detected 8 ns earlier or later.

> **Trade-off:** latency in exchange for reliability.

## Block Diagram

```
din --> [FF1] --> [FF2] --> ... --> [FFn] --> dout
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `STAGES`  | 2       | Number of flip-flops in the chain. More stages = lower metastability risk, but more latency. |

## Code Walkthrough

```systemverilog
module sync #(
    parameter int STAGES = 2
)(
    input  logic clk,
    input  logic din,
    output logic dout
);
```

- `#(...)` declares **parameters**. They let you customize the module when you instantiate it.
- `parameter int STAGES = 2` means the default is 2, but you can override it.

```systemverilog
    logic [STAGES-1:0] shift_reg;

    always_ff @(posedge clk) begin
        shift_reg <= {shift_reg[STAGES-2:0], din};
    end
```

- `logic [STAGES-1:0] shift_reg` creates a shift register whose width is set by the parameter.
- `{shift_reg[STAGES-2:0], din}` concatenates the lower bits of the register with the new input, shifting everything one position to the left.

```systemverilog
    assign dout = shift_reg[STAGES-1];
```

- The output is the last stage of the shift register.

## Usage Example

```systemverilog
sync sync_btn0 (
    .clk  (clk),
    .din  (btn[0]),
    .dout (btn_sync[0])
);
```

## Exercises

1. Why do we not simply write `assign dout = din;` for an external button?
2. What happens if you increase `STAGES` to 5? (Hint: latency.)
3. Draw the waveform of `din`, `shift_reg[0]`, and `dout` for a button press.
