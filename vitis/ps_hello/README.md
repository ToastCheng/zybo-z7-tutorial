# Phase 9: PS Hello — Button-Triggered UART Message from the ARM Core

## Goal

Bring up the **Processing System (PS)** for the first time: a bare-metal C
application running on the ARM Cortex-A9 prints a hello message over the
USB-UART every time **BTN0** is pressed.

## Concepts

| Concept | What it means here |
|---------|--------------------|
| PS vs. PL | The PS (ARM CPU) runs C code; the PL (FPGA fabric) only routes the button pin into the PS. |
| Block design | The PS7 is configured as an IP block in a Vivado block design (DDR3, UART1, MIO) instead of being described in HDL. |
| EMIO GPIO | The PS GPIO peripheral can be extended into the PL via **EMIO**. BTN0 (a PL pin) becomes PS GPIO pin 54 (pins 0–53 are MIO). |
| XSA | The hardware handoff file (`build/ps_hello.xsa`) replaces the plain bitstream as the deliverable to Vitis. It contains the PS configuration **and** the bitstream. |
| Bare-metal app | A standalone C program (no OS, no Linux) linked against the standalone BSP, started over JTAG. |
| ps7_init | Before the app can run from DDR3, the PS clocks/DDR/MIO must be initialized (`ps7_init` in `scripts/run_soc.tcl`). |

## Block Diagram

```
 BTN0 (PL pin K18)
    │
    ▼  EMIO GPIO bit 0 (PS pin 54)
┌─────────────────────────────┐
│  Zynq PS7                   │
│  ┌─────────┐  ┌──────────┐  │
│  │ GPIO    │  │ UART1    │──┼──► USB-UART bridge (MIO 48/49)
│  └─────────┘  └──────────┘  │    → host terminal, 115200 baud
│  Cortex-A9 ← bare-metal app │
└─────────────────────────────┘
```

The PL contains **no logic at all** — just the wire from the button pin into
the PS.

## Files

| File | Purpose |
|------|---------|
| `scripts/build_soc.tcl` | Project-mode Vivado build: block design → bitstream → XSA |
| `rtl/top/top_ps_hello.sv` | Top level: instantiates the PS7 wrapper, connects BTN0 |
| `constraints/top_ps_hello.xdc` | BTN0 pin constraint (K18, LVCMOS33) |
| `vitis/ps_hello/src/main.c` | Bare-metal app: debounced button poll → `xil_printf` |
| `vitis/ps_hello/build_app.py` | Vitis script: platform from XSA + app build |
| `scripts/run_soc.tcl` | xsct script: program PL, `ps7_init`, download ELF, run |

## How to Build and Run

```bash
make build_soc    # Vivado: block design, bitstream, build/ps_hello.xsa
make app          # Vitis: platform + app -> build/vitis_ws/ps_hello_app/build/ps_hello_app.elf
make run_soc      # JTAG: program PL, init PS, download and start the app
```

Then open the UART console (the same PROG/UART micro-USB cable):

```bash
screen /dev/ttyUSB1 115200    # ttyUSB0 is usually JTAG, ttyUSB1 the UART
```

Press **BTN0** — each press prints:

```
Hello from PS! BTN0 pressed (1)
```

## Code Walkthrough (main.c)

1. `XGpioPs_LookupConfig` / `XGpioPs_CfgInitialize` — attach to the PS GPIO
   peripheral using the parameters Vitis generated from the XSA.
2. `XGpioPs_SetDirectionPin(&gpio, 54, 0)` — EMIO bit 0 = pin 54, direction
   input.
3. Poll loop with debounce: a level is only accepted after it stays stable
   across two 10 ms polls; a rising stable edge increments the counter and
   prints.

## Exercises

- Use all four buttons (widen the EMIO GPIO to 4 bits in `build_soc.tcl` and
  poll pins 54–57), printing which button was pressed.
- Make BTN1 toggle an LED from the PS instead of printing.
- Measure button latency: toggle a PS GPIO on press and probe it with a scope.

## Troubleshooting

- **No UART output:** check you opened the UART device (not the JTAG one) and
  that `run_soc` printed `Application running`.
- **App crashes or nothing happens:** `ps7_init` may have failed — re-run
  `make run_soc`; the DDR3 critical warnings during the Vivado build are
  expected with the Digilent preset and are harmless on this board.
