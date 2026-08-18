# Agent Guidelines for This Project

This file contains project-specific conventions and workflow preferences for anyone (or any agent) working on this codebase.

## Git Workflow

- **Initialize tracking:** This repository uses Git. New work should be committed so progress is tracked.
- **Small, reviewable commits:** Prefer many small commits over one large commit. Each commit should represent a single logical change (e.g., one module, one fix, one documentation update).
- **Commit messages:** Write concise, descriptive commit messages in the present tense.
  - Good: `Add Phase 0 hello-LED top module and build scripts`
  - Bad: `stuff`
- **Do not mutate history:** Do not run `git rebase`, `git reset`, or force-push unless explicitly instructed.
- **No automatic pushes:** Do not run `git push` unless explicitly asked.
- **Build artifacts:** The `build/` directory is generated and should not be committed. It is excluded via `.gitignore`.

## Coding Style

- **Language:** SystemVerilog-2017 for RTL and testbenches unless there is a specific reason to use plain Verilog.
- **Module structure:**
  - Use `module_name.sv` filenames.
  - Declare ports with `logic` and explicit direction (`input`, `output`, `inout`).
  - Prefer `always_ff` for flip-flops and `always_comb` for combinational logic.
- **Documentation:** Every reusable module and every top-level design must have an accompanying `README.md` explaining its purpose, parameters, and how to use it.
- **Constraints:** All pin and timing constraints live in `constraints/zybo_z7_10.xdc` or a similarly named board-specific file.

## Build and Program Commands

- Build a top module: `make build TOP=<top_module_name>`
- Program the board: `make prog`
- Simulate a testbench: `make sim TB=<testbench_module_name>`
- Clean generated files: `make clean`

### SoC (PS + PL) designs — Phase 9 onward

- Build the block design, bitstream, and XSA: `make build_soc SOC_TOP=<soc_top_module_name>`
- Build the bare-metal PS application: `make app`
- Program the PL and run the PS app over JTAG: `make run_soc`
- SoC application sources live in `vitis/<app_name>/`; generated Vitis workspace files go to `build/vitis_ws/` (ignored by git).

## Testing on Hardware

- The Zybo Z7-10 board is connected to the host via the PROG/UART micro-USB port.
- Before programming, confirm the board is powered. The board can be powered from USB; set the power-select jumper to USB if needed.
- After generating a bitstream, always attempt to program the board and verify behavior visually on the LEDs.

## Project Roadmap

Refer to `README.md` for the current phase and roadmap. Implement one phase at a time, committing after each phase or logical sub-step.
