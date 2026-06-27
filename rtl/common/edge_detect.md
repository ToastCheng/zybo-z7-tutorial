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

- `din_q` is a one-clock-cycle delayed copy of the input.

```systemverilog
    assign rising  = din && !din_q;
    assign falling = !din && din_q;
```

- `!din_q` means "din_q was low last cycle."
- `&&` is the logical AND operator.

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
