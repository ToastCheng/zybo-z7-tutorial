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
