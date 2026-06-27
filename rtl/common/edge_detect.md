# `edge_detect` — Edge Detector

## Goal

Convert a level change in a signal into a single-clock-cycle pulse.

## Concepts

### Levels vs. Pulses

A **level** stays high or low for many clock cycles. A **pulse** is high for just one clock cycle.

When you press a button, the debounced output becomes high and stays high until you release it. But for toggling an LED, we want to react only once per press, not every clock cycle. An edge detector gives us that single reaction.

### Detecting Edges

To detect an edge, we remember the previous value of the signal and compare it to the current value:

| Previous (`din_q`) | Current (`din`) | Edge |
|---|---|---|
| 0 | 1 | Rising |
| 1 | 0 | Falling |
| 0 | 0 | None |
| 1 | 1 | None |

## Block Diagram

```
          +--------+
din ----->|   FF   |---> din_q
          +--------+

rising  = din  AND (NOT din_q)
falling = (NOT din) AND din_q
```

## Code Walkthrough

```systemverilog
    logic din_q;

    always_ff @(posedge clk) begin
        din_q <= din;
    end
```

- `din_q` is a **one-clock-cycle delayed copy** of `din`.
- On each rising clock edge, `din_q` is updated to whatever `din` was **just before that edge**.
- This means `din_q` always shows the value of `din` from the previous clock cycle.

```systemverilog
    assign rising  = din && !din_q;
    assign falling = !din && din_q;
```

- `assign` is combinational: it re-evaluates immediately whenever `din` or `din_q` changes.
- `!din_q` means "`din_q` was low last cycle."
- `&&` is the logical AND operator.

### Why `din` and `din_q` are not the same

At first glance, `din_q <= din` looks like it makes `din_q` equal to `din`. But because of the clock, `din_q` is always **one cycle behind**.

Think of it as a photographer taking a picture of `din` at every clock edge. The photo (`din_q`) shows what `din` looked like at the **previous** snapshot, not right now.

### Step-by-step timing example

Suppose a button press makes `din` go high just before clock cycle 3, and stay high until it is released after cycle 6.

```
Clock cycle:    0    1    2    3    4    5    6    7
                |    |    |    |    |    |    |    |
clk          __|____|____|____|____|____|____|____|__
             0    1    2    3    4    5    6    7

din          ____/-----------------------\__________
             0  0  0  1  1  1  1  0

din_q        ___________/-----------------------\___
             0  0  0  0  1  1  1  1

rising       ______________/\_______________________
             0  0  0  1  0  0  0  0

falling      ________________________________/\_____
             0  0  0  0  0  0  0  1
```

### What happens at each rising clock edge

| Cycle | `din` before edge | `din_q` before edge | After edge, `din_q` becomes | `rising` = `din && !din_q` | `falling` = `!din && din_q` |
|---|---|---|---|---|---|
| 0 | 0 | 0 (initial) | 0 | 0 | 0 |
| 1 | 0 | 0 | 0 | 0 | 0 |
| 2 | 0 | 0 | 0 | 0 | 0 |
| 3 | 1 | 0 | 1 | **1** | 0 |
| 4 | 1 | 1 | 1 | 0 | 0 |
| 5 | 1 | 1 | 1 | 0 | 0 |
| 6 | 1 | 1 | 1 | 0 | 0 |
| 7 | 0 | 1 | 0 | 0 | **1** |

### Key observations

- `rising` is high only in cycle 3, the first cycle where `din` is `1` but `din_q` (the previous value) is still `0`.
- `falling` is high only in cycle 7, the first cycle where `din` is `0` but `din_q` is still `1`.
- Each pulse lasts exactly **one clock cycle**, no matter how long the button is held.

## Usage Example

```systemverilog
edge_detect edge_btn0 (
    .clk     (clk),
    .din     (btn_deb[0]),
    .rising  (btn_rising[0]),
    .falling ()              // unused output
);
```

## Exercises

1. What would happen if you used the raw button signal instead of the debounced signal?
2. Draw the waveform of `din`, `din_q`, and `rising` for one button press.
3. How could you detect both edges with a single output?
