#------------------------------------------------------------------------------
# Makefile for the Zybo Z7-10 pure FPGA project.
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

# SoC top-level module and Vitis executables.
SOC_TOP ?= top_ps_hello
VITIS   ?= vitis
XSCT    ?= xsct

# Build the block design, bitstream, and XSA for the selected SoC top module.
build_soc:
	$(VIVADO) -mode batch -source scripts/build_soc.tcl -tclargs $(SOC_TOP)

# Build the bare-metal PS application from the exported XSA.
app:
	$(VITIS) -s vitis/ps_hello/build_app.py

# Program the PL and download/run the PS application via JTAG.
run_soc:
	$(XSCT) scripts/run_soc.tcl build/ps_hello.bit build/vitis_ws/ps_hello_app/build/ps_hello_app.elf

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
	@echo "  make build_soc           - Build PS+PL block design, bitstream, and XSA"
	@echo "  make app                 - Build the bare-metal PS application (Vitis)"
	@echo "  make run_soc             - Program PL and run the PS app via JTAG"
	@echo "  make clean               - Remove build and simulation artifacts"
