# Phase 9: `top_ps_hello` — PS Bring-up (Button → UART Hello)

## Goal

Use the Zynq **Processing System (PS)** for the first time. A bare-metal C
application running on the ARM Cortex-A9 polls **BTN0** and prints a hello
message over the USB-UART on every press.

This top-level is intentionally almost empty: its only job is to instantiate
the PS7 block-design wrapper and connect the button pin to the PS through a
1-bit **EMIO GPIO**. All the "logic" lives in software on the ARM core.

## What You Should See

- After `make run_soc`, the UART console (115200 baud on the PROG/UART
  micro-USB port) shows:

  ```
  Phase 9: PS hello - press BTN0
  ```

- Each press of **BTN0** prints one line:

  ```
  Hello from PS! BTN0 pressed (1)
  ```

## Concepts

### The PS is configured, not described in HDL

In Phases 0–8 everything was HDL synthesized into the FPGA fabric (PL). The
ARM processor cannot be synthesized — it is fixed silicon. Instead, Vivado
treats it as an IP block (`processing_system7`) in a **block design**, where
we check boxes for DDR3 timing, UART1 on MIO 48/49, and so on. The Zybo Z7-10
board preset fills in all of these values; see `scripts/build_soc.tcl`.

### EMIO: borrowing PS pins through the fabric

The PS GPIO peripheral has 54 pins connected to dedicated PS pads (**MIO**).
It can be extended by up to 64 more pins routed through the PL (**EMIO**).
Since the Zybo buttons are wired to PL pins, this is the cheapest way for
software to read a button: the PL contains no logic, just a wire.

- MIO pins are GPIO 0–53.
- The first EMIO bit is GPIO **54** — that is the pin number the C code uses.

### Tri-state wrapper port

The block design exposes the EMIO GPIO as an inout tri-state port
(`GPIO_0_0_tri_io`). The direction is **not** decided in HDL — the PS GPIO
peripheral drives the output-enable itself, and the C application configures
the pin as an input at startup (`XGpioPs_SetDirectionPin`).

### XSA replaces the bitstream as the software handoff

Vitis does not consume a `.bit` file. The Vivado build exports
`build/ps_hello.xsa`, which bundles the PS configuration, the memory map, and
the bitstream. The Vitis platform and the bare-metal BSP are generated from
it. Before the app can run from DDR3, the PS must also be initialized over
JTAG (`ps7_init` in `scripts/run_soc.tcl`).

## Block Diagram

```
 BTN0 (PL pin K18)
    │
    ▼  EMIO GPIO bit 0 (PS GPIO pin 54)
┌──────────────────────────────┐
│  Zynq PS7                    │
│  ┌─────────┐  ┌───────────┐  │
│  │ GPIO    │  │ UART1     │──┼──► USB-UART bridge (MIO 48/49)
│  └─────────┘  └───────────┘  │    → host terminal, 115200 baud
│  Cortex-A9 ← bare-metal app  │
└──────────────────────────────┘
```

## Code Walkthrough

```systemverilog
module top_ps_hello (
    inout  wire btn     // BTN0, active high when pressed (PS GPIO input)
);
```

- `inout` because the EMIO GPIO is tri-state: the PS decides the direction.
  We never drive it from the PL side.

```systemverilog
    system_wrapper ps (
        .GPIO_0_0_tri_io (btn)
    );
```

- `system_wrapper` is the HDL wrapper Vivado generates around the block
  design. It contains the PS7 (and its DDR/FIXED_IO pins, which connect to
  dedicated pads and need no constraints).
- The port name `GPIO_0_0_tri_io` comes from the block design: interface
  `GPIO_0`, external port `GPIO_0_0`.

Note what is **absent**: no `clk` port, no `always_ff`, no reset. The PS has
its own clock and reset pins on dedicated pads, and this phase uses no fabric
logic at all.

## Parameters

None. The PS configuration (DDR3, UART, GPIO) lives in the block design in
`scripts/build_soc.tcl`, not in HDL parameters.

## How to Build and Test

```bash
make build_soc   # Vivado: block design -> bitstream + build/ps_hello.xsa
make app         # Vitis: platform + bare-metal app (build/vitis_ws/)
make run_soc     # JTAG: program PL, ps7_init, download ELF, run
```

Then open the UART console and press BTN0:

```bash
screen /dev/ttyUSB1 115200
```

See `vitis/ps_hello/README.md` for the software side (the C application and
the Vitis flow) and troubleshooting.

## Exercises

1. Widen the EMIO GPIO to 4 bits in `scripts/build_soc.tcl`, expose all four
   buttons, and print which button was pressed.
2. Add an EMIO GPIO output bit and let the PS drive `LD0` when BTN0 is held.
3. Instead of polling, connect the button to a PS interrupt (hint: the PS GPIO
   supports interrupts on EMIO pins; the app needs the GIC driver `XScuGic`).
