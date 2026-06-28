#------------------------------------------------------------------------------
# build.tcl
# Non-project mode Vivado build script.
#
# Usage:
#   vivado -mode batch -source scripts/build.tcl -tclargs <top_module>
#
# If no top module is provided, it defaults to "top_hello".
#------------------------------------------------------------------------------

# Parse the top-module argument.
set top [lindex $argv 0]
if { $top eq "" } {
    set top top_hello
}

puts "Building top module: $top"

# Target device: Zynq-7010 in CLG400 package, speed grade -1.
set part_name xc7z010clg400-1
set_part $part_name

# Output directory.
file mkdir build

# Read the shared package, all reusable common modules, and the requested
# top-level module. As we add more common modules, they are picked up
# automatically from rtl/common/.
read_verilog -sv [glob rtl/pkg/*.sv]
read_verilog -sv [glob rtl/common/*.sv]
read_verilog -sv rtl/top/${top}.sv

# Read the shared board constraints.
read_xdc constraints/zybo_z7_10.xdc

# Optionally read per-top constraints for designs that use extra pins
# (for example, the audio codec pins on Phase 6).
set top_xdc "constraints/${top}.xdc"
if { [file exists $top_xdc] } {
    puts "Reading per-top constraints: $top_xdc"
    read_xdc $top_xdc
}

# Run synthesis.
puts "Starting synthesis..."
synth_design -top $top -part $part_name

# Optimization, placement, and routing.
puts "Running optimization..."
opt_design

puts "Running placement..."
place_design

puts "Running routing..."
route_design

# Generate reports.
puts "Writing reports..."
report_utilization -file build/${top}_utilization.rpt
report_timing_summary -file build/${top}_timing_summary.rpt

# Write the bitstream.
puts "Writing bitstream..."
write_bitstream -force build/${top}.bit

puts "Build complete: build/${top}.bit"
