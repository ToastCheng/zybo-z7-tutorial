#------------------------------------------------------------------------------
# Makefile for the Zybo Z7-10 pure FPGA project.
#------------------------------------------------------------------------------

# Default top-level module.
TOP ?= top_hello

# Vivado executable.
VIVADO ?= vivado

.PHONY: all build prog sim clean

all: build

# Build the bitstream for the selected top module.
build:
	$(VIVADO) -mode batch -source scripts/build.tcl -tclargs $(TOP)

# Program the FPGA with the bitstream for the selected top module.
prog:
	$(VIVADO) -mode batch -source scripts/program.tcl -tclargs $(TOP)

# Run a simulation (placeholder; will be implemented in a later phase).
sim:
	@echo "Simulation target not yet implemented. Set TB=<testbench> when ready."

# Remove generated build artifacts.
clean:
	rm -rf build/

# Print a short help message.
help:
	@echo "Targets:"
	@echo "  make build TOP=<top>   - Synthesize and generate a bitstream"
	@echo "  make prog  TOP=<top>   - Program the FPGA via JTAG"
	@echo "  make clean             - Remove build artifacts"
