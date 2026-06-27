# Zybo Z7-10 Pure FPGA Learning Lab

A modular, beginner-friendly FPGA project for the **Digilent Zybo Z7-10** board.

This project uses **only the FPGA fabric (PL)** — no ARM processor (PS), no SoC code, no Vitis. The goal is to learn digital design hands-on, starting from a blinking LED and building up to more interesting interfaces.

---

## Table of Contents

1. [Project Goals](#project-goals)
2. [Why Pure FPGA?](#why-pure-fpga)
3. [Board Overview: Zybo Z7-10](#board-overview-zybo-z7-10)
4. [Repository Structure](#repository-structure)
5. [Toolchain & Workflow](#toolchain--workflow)
   - [Do I need the Vivado GUI?](#do-i-need-the-vivado-gui)
   - [Command-Line Workflow](#command-line-workflow)
6. [Learning Roadmap](#learning-roadmap)
7. [How to Read the Educational Material](#how-to-read-the-educational-material)
8. [Prerequisites](#prerequisites)
9. [Getting Started](#getting-started)
10. [Module Index](#module-index)
11. [References](#references)

---

## Project Goals

- Learn FPGA design from the ground up using **real hardware**.
- Keep every design **modular and reusable**.
- Stay in a **text editor / command-line workflow** as much as possible.
- Document each module so a beginner can understand **what it does**, **how it works**, and **how to use it**.

---

## Why Pure FPGA?

The Zybo Z7-10 contains a Zynq-7000 chip, which has two parts:

| Part | Name | What it is |
|------|------|------------|
| PS   | Processing System | A dual-core ARM Cortex-A9 CPU (like a small Linux-capable computer) |
| PL   | Programmable Logic | The FPGA fabric where we write HDL |

Many Zybo tutorials jump straight into Linux + SoC design. This project ignores the PS and focuses entirely on the PL. That keeps things simple: we write HDL, synthesize it, and download a bitstream directly to the FPGA.

> **Analogy:** The PS is like a Raspberry Pi sitting next to the FPGA. We are not using it. We are programming the FPGA directly.

---

## Board Overview: Zybo Z7-10

Key features we will use:

| Resource | Count | Notes |
|----------|-------|-------|
| Slide switches (SW) | 4 | `SW0`–`SW3`, connected to FPGA pins |
| Push buttons (BTN) | 4 | `BTN0`–`BTN3`, also connected to FPGA pins |
| LEDs (single-color) | 4 | `LD0`–`LD3`, standard LEDs |
| RGB LEDs | 4 | Each has Red, Green, and Blue channels (so 12 FPGA outputs total) |
| System clock | 125 MHz | Single-ended oscillator on the board |

### Important: Active-Low vs. Active-High

On the Zybo Z7-10:

- **Buttons and switches** are active-high when pressed/on.
- **LEDs** turn on when driven **high** (`1`).
- Always double-check the board reference manual; some boards use active-low LEDs.

---

## Repository Structure

```
zybo_z7_fpga/
├── rtl/
│   ├── pkg/              # Shared SystemVerilog packages
│   │   └── board_pkg.sv  # Board constants (clock freq, widths, etc.)
│   ├── common/           # Reusable building blocks
│   │   ├── debounce.sv
│   │   ├── edge_detect.sv
│   │   ├── pwm.sv
│   │   └── ...
│   ├── top/              # One top-level per learning stage
│   │   ├── top_hello.sv
│   │   ├── top_button_led.sv
│   │   └── ...
│   └── tb/               # Testbenches
├── constraints/
│   └── zybo_z7_10.xdc    # Pin mapping and timing constraints
├── scripts/
│   ├── build.tcl         # Vivado non-project build flow
│   ├── program.tcl       # Program the FPGA via JTAG
│   └── sim.tcl           # Run simulation
├── build/                # Generated artifacts (ignored by git)
├── Makefile              # Convenience commands
└── README.md             # This file
```

### Directory Meaning for Beginners

| Directory | Purpose |
|-----------|---------|
| `rtl/` | **Register Transfer Level** code — this is your HDL. The name is historical; think of it as "the actual digital logic." |
| `rtl/pkg/` | Packages are like shared header files in C. They hold constants and types used by many modules. |
| `rtl/common/` | Small, reusable blocks. Once written, we reuse them instead of copy-pasting code. |
| `rtl/top/` | The top-level design for each stage. This is what gets synthesized into the FPGA. |
| `rtl/tb/` | Testbenches. These are HDL files used only in simulation, not on hardware. |
| `constraints/` | Tells Vivado which FPGA pin connects to which signal and how fast the clock is. |
| `scripts/` | Tcl scripts that control Vivado from the command line. |
| `build/` | Output files: bitstreams, reports, logs. Regenerated every build. |

---

## Toolchain & Workflow

We use **Xilinx Vivado** for synthesis, implementation, and bitstream generation.

### Do I Need the Vivado GUI?

**No.** For a pure-HDL project, every step can be run from the command line:

| Step | Command |
|------|---------|
| Build bitstream | `make build` |
| Program board | `make prog` |
| Run simulation | `make sim` |
| Clean artifacts | `make clean` |

The Vivado GUI is useful only for:

- Viewing the synthesized schematic.
- Using the **Integrated Logic Analyzer (ILA)** to debug signals on hardware.
- Generating complex Xilinx IP cores.

We will avoid all of those until we really need them.

### Command-Line Workflow

Vivado can run in **batch mode**, meaning it executes a Tcl script without opening a window:

```bash
vivado -mode batch -source scripts/build.tcl
```

Our `Makefile` wraps these commands so you do not need to remember them.

> **What is Tcl?** Tcl (pronounced "tickle") is a scripting language. Vivado reads Tcl commands. We use it to tell Vivado: "read these files, synthesize this top module, place and route, generate a bitstream."

---

## Learning Roadmap

We build the project in small, self-contained phases. Each phase adds one new concept and produces a working bitstream.

| Phase | Name | Concept | Top Module |
|-------|------|---------|------------|
| 0 | Hello LED | Toolchain + blinking LED | `top_hello` |
| 1 | Button-Controlled LED | Synchronization, debounce, edge detection | `top_button_led` |
| 2 | PWM RGB LED | Pulse-width modulation, parameters | `top_pwm_rgb` |
| 3 | Switch Modes | Multiplexers, pattern generators | `top_switch_modes` |
| 4 | UART Loopback | Serial communication | `top_uart_loopback` |
| 5 | PMOD / External I/O | Off-board interfaces | TBD |

Each phase has:

- A top-level module in `rtl/top/`
- Reusable common blocks added to `rtl/common/`
- A section in this README
- Its own `README.md` explaining the theory, code, and how to test it

---

## How to Read the Educational Material

Every module contains a `README.md` with these sections:

1. **Goal** — What this module does.
2. **Concepts** — The digital-design ideas you will learn.
3. **Block Diagram** — How the pieces connect.
4. **Code Walkthrough** — Line-by-line explanation of new syntax.
5. **Parameters** — How to configure the module.
6. **Usage Example** — How to instantiate it in a top-level design.
7. **Testing** — How to simulate and run on hardware.
8. **Exercises** — Optional challenges to deepen understanding.

> **For beginners:** Do not rush. Read the code, run the simulation, load the bitstream, and observe the hardware. Change one thing at a time and see what happens.

---

## Prerequisites

1. **Hardware**
   - Digilent Zybo Z7-10 board.
   - Micro-USB cable for JTAG programming and power.

2. **Software**
   - Xilinx Vivado (WebPACK edition is free). Version 2020.2 or later recommended.
   - A text editor (VS Code, Vim, Emacs, etc.).
   - `make` (usually available on Linux/macOS; on Windows use WSL or Git Bash).

3. **Knowledge**
   - Basic digital logic: AND, OR, NOT, flip-flops, clocks.
   - Some programming experience is helpful but not required.

---

## Getting Started

1. Clone or open this repository.
2. Connect the Zybo Z7-10 to your computer via the **PROG/UART** micro-USB port.
3. Set the board power switch to **USB** if you are powering from USB.
4. Run the first build:

```bash
make build TOP=top_hello
```

5. Program the FPGA:

```bash
make prog
```

6. Observe the LEDs. If the build succeeded, you should see the expected LED behavior for the current phase.

> The first build may take a few minutes because Vivado is synthesizing and implementing the design. Later builds are faster if you only change HDL.

---

## Module Index

| Module | Path | Description |
|--------|------|-------------|
| `board_pkg` | `rtl/pkg/board_pkg.sv` | Shared board constants |
| `top_hello` | `rtl/top/top_hello.sv` | Phase 0: simple LED blinker |

This table will grow as we add phases.

---

## References

- [Zybo Z7-10 Reference Manual](https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual)
- [Zybo Z7-10 Master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Zybo-Z7-Master.xdc)
- [Xilinx Vivado Tcl Command Reference](https://docs.xilinx.com/r/en-US/ug835-vivado-tcl-commands)
- [SystemVerilog IEEE 1800-2017 Standard](https://ieeexplore.ieee.org/document/8299595)

---

## License

This project is educational. Use it for learning and experimentation.
