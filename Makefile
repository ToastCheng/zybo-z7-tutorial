#------------------------------------------------------------------------------
# Makefile for the Zybo Z7-10 FPGA & SoC project (command-line only, no IDE).
#------------------------------------------------------------------------------

# Default top-level module.
TOP ?= top_hello

# Vivado executable.
VIVADO ?= vivado

.PHONY: all build prog sim build_soc app run_soc clean help

all: build

# Build the bitstream for the selected top module.
build:
	$(VIVADO) -mode batch -source scripts/build.tcl -tclargs $(TOP)

# Program the FPGA with the bitstream for the selected top module.
prog:
	$(VIVADO) -mode batch -source scripts/program.tcl -tclargs $(TOP)

# Run a simulation using Vivado Simulator.
# Example: make sim TB=tb_edge_detect
TB ?= tb_edge_detect
sim:
	$(VIVADO) -mode batch -source scripts/sim.tcl -tclargs $(TB)

#------------------------------------------------------------------------------
# SoC targets (Phase 9 and later: PS + PL designs)
#------------------------------------------------------------------------------

# SoC top-level module, Vitis application, and Vitis executables.
# SOC_TOP selects the hardware (build/<soc_name>.bit/.xsa); APP selects the
# bare-metal application in vitis/<app>/.
SOC_TOP  ?= top_ps_hello
SOC_NAME  = $(SOC_TOP:top_%=%)
APP      ?= ps_hello
VITIS    ?= vitis
XSCT     ?= xsct

# Build the block design, bitstream, and XSA for the selected SoC top module.
build_soc:
	$(VIVADO) -mode batch -source scripts/build_soc.tcl -tclargs $(SOC_TOP)

# Build the bare-metal PS application from the exported XSA.
app:
	$(VITIS) -s vitis/$(APP)/build_app.py

# Program the PL and download/run the PS application via JTAG.
run_soc:
	$(XSCT) scripts/run_soc.tcl build/$(SOC_NAME).bit \
		build/vitis_ws/$(APP)_app/build/$(APP)_app.elf \
		build/$(SOC_NAME).xsa

# Remove generated build and simulation artifacts.
clean:
	rm -rf build/ xsim.dir/ .Xil/
	rm -f *.pb *.log *.jou *.str

# Print a short help message.
help:
	@echo "Targets:"
	@echo "  make build TOP=<top>     - Synthesize and generate a bitstream"
	@echo "  make prog  TOP=<top>     - Program the FPGA via JTAG"
	@echo "  make sim   TB=<tb>       - Run a testbench in Vivado Simulator"
	@echo "  make build_soc SOC_TOP=<top> - Build PS+PL block design, bitstream, and XSA"
	@echo "  make app       APP=<app>     - Build the bare-metal PS application (Vitis)"
	@echo "  make run_soc   SOC_TOP=<top> APP=<app> - Program PL and run the PS app via JTAG"
	@echo "  make clean               - Remove build and simulation artifacts"
