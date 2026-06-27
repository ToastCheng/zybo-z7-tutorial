#------------------------------------------------------------------------------
# Makefile for the Zybo Z7-10 pure FPGA project.
#------------------------------------------------------------------------------

# Default top-level module.
TOP ?= top_hello

# Vivado executable.
VIVADO ?= vivado

.PHONY: all build prog sim clean help

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

# Remove generated build and simulation artifacts.
clean:
	rm -rf build/ xsim.dir/ .Xil/
	rm -f *.pb *.log *.jou *.str

# Print a short help message.
help:
	@echo "Targets:"
	@echo "  make build TOP=<top>   - Synthesize and generate a bitstream"
	@echo "  make prog  TOP=<top>   - Program the FPGA via JTAG"
	@echo "  make sim   TB=<tb>     - Run a testbench in Vivado Simulator"
	@echo "  make clean             - Remove build and simulation artifacts"
