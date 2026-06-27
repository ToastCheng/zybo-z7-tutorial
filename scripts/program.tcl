#------------------------------------------------------------------------------
# program.tcl
# Program the Zybo Z7-10 FPGA via JTAG.
#
# Usage:
#   vivado -mode batch -source scripts/program.tcl -tclargs <top_module>
#
# If no top module is provided, it defaults to "top_hello".
# The corresponding bitstream is expected at build/<top_module>.bit.
#------------------------------------------------------------------------------

# Parse the top-module argument.
set top [lindex $argv 0]
if { $top eq "" } {
    set top top_hello
}

set bitstream_file "build/${top}.bit"

if { ![file exists $bitstream_file] } {
    puts "ERROR: Bitstream not found: $bitstream_file"
    puts "Run 'make build TOP=$top' first."
    exit 1
}

puts "Programming bitstream: $bitstream_file"

# Open the hardware manager and connect to the local server.
open_hw_manager
connect_hw_server -allow_non_jtag

# Open the first available JTAG target.
open_hw_target

# Select the first device on the target.
set hw_device [lindex [get_hw_devices] 0]
puts "Using hardware device: $hw_device"

# Attach the bitstream and program the device.
set_property PROGRAM.FILE $bitstream_file $hw_device
program_hw_devices $hw_device

# Clean up.
close_hw_target
disconnect_hw_server
close_hw_manager

puts "Programming complete."
