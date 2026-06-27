# Phase 0: `top_hello` — Hello LED

## Goal

Get a working bitstream onto the Zybo Z7-10 and make the LEDs blink. This proves that:

- Vivado can synthesize our HDL.
- The constraints file maps our signals to the correct pins.
- The JTAG programming chain works.
- The board is alive.

## What You Should See

- The four single-color LEDs (`LD0`–`LD3`) blink at different rates.
- The RGB LED (`LD6`) slowly cycles through colors.

## Concepts

### Clocks and Counters

An FPGA design is synchronous: it uses a clock signal to update flip-flops on every rising edge. A **counter** is a register that increments by 1 each clock cycle.

At 125 MHz, the counter increments 125 million times per second. We cannot see that, but if we look at the higher bits of the counter, those change much more slowly.

### Bit Slicing

In SystemVerilog, `counter[26:23]` selects four adjacent bits. Each bit toggles at half the frequency of the bit below it, so each LED blinks half as fast as the previous one.

### Active-High Outputs

The Zybo Z7-10 LEDs turn on when the FPGA pin is driven to `1`.

## Block Diagram

```
         +-----------+
  clk -->|  Counter  |--+
         +-----------+  |
                        |---> led[3:0]  = counter[26:23]
                        |---> rgb_led   = counter[28:26]
```

## Top-Level Module = Entry Point

`top_hello` is the **top-level module** of this design. In FPGA development, the top-level module is the equivalent of a `main()` function in software — it is the entry point where synthesis begins.

### There is no `main()` in HDL

In software:

```c
int main() {
    // program starts here
}
```

In HDL/FPGA:

```systemverilog
module top_hello (
    // ports connected to the outside world
);
    // hardware starts here
endmodule
```

The entire design is a parallel hardware circuit. Every `always_ff` block and every `assign` statement describes hardware that runs simultaneously once the FPGA is configured.

### Standard port list

Every top-level module in this project uses the same ports:

```systemverilog
module top_xxx (
    input  logic clk,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic [2:0] rgb_led
);
```

This lets us reuse the same `constraints/zybo_z7_10.xdc` file. You only change `TOP=` in the Makefile to switch between demo phases.

### Hierarchy for Phase 0

Phase 0 is very simple: the top-level module contains only a counter and some wiring. There are no sub-modules yet.

```text
top_hello  (top-level entry point)
│
└── counter + combinational assignments to LEDs
```

Later phases will instantiate reusable modules inside the top-level module.

## Code Walkthrough

```systemverilog
module top_hello (
    input  logic clk,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic [2:0] rgb_led
);
```

- `module` declares a hardware block.
- `input` / `output` define the direction of each port.
- `logic` is a SystemVerilog type that can represent either a wire or a register, depending on how it is assigned.
- Vectors like `[3:0]` group related signals.

```systemverilog
    logic [31:0] counter;

    always_ff @(posedge clk) begin
        counter <= counter + 1'b1;
    end
```

- `always_ff` is a sequential block. It describes hardware that updates on a clock edge.
- `@(posedge clk)` means "on the rising edge of `clk`."
- `<=` is the non-blocking assignment. Inside `always_ff`, it describes a flip-flop update.
- `1'b1` is a 1-bit binary value of 1.

```systemverilog
    assign led = counter[26:23];
```

- `assign` creates a continuous combinational connection.
- Here the four LED outputs are wired to four counter bits.

## Parameters

This module has no parameters; everything is hard-coded. Later phases will introduce `parameter` to make modules reusable.

## How to Build and Test

1. Make sure the board is connected via the **PROG/UART** micro-USB port.
2. Build the bitstream:

```bash
make build TOP=top_hello
```

3. Program the FPGA:

```bash
make prog TOP=top_hello
```

4. Watch the LEDs. If the build succeeds but nothing lights up:
   - Check the board power LED.
   - Verify the power-select jumper is set to USB (if powering from USB).
   - Re-run `make prog`.

## Exercises

1. Change `counter[26:23]` to `counter[24:21]`. How does the blink rate change?
2. Make all LEDs blink at the same rate.
3. Display a binary pattern instead of counting (for example, `4'b1010`).
4. Add the slide switches: drive `led` with `sw` so the switches directly control the LEDs.
