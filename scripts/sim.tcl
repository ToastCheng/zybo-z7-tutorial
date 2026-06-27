#------------------------------------------------------------------------------
# sim.tcl
# Run a SystemVerilog testbench using Vivado Simulator (xsim).
#
# Usage:
#   vivado -mode batch -source scripts/sim.tcl -tclargs <testbench_module>
#
# If no testbench is provided, it defaults to "tb_edge_detect".
#------------------------------------------------------------------------------

# Parse the testbench argument.
set tb [lindex $argv 0]
if { $tb eq "" } {
    set tb tb_edge_detect
}

puts "Simulating testbench: $tb"

# Clean up artifacts from previous runs.
file delete -force xsim.dir
file delete -force xvlog.pb
file delete -force xelab.pb
file delete -force xsim.pb

# Gather source files: package, common modules, and the selected testbench.
set sv_files [glob -nocomplain rtl/pkg/*.sv rtl/common/*.sv rtl/tb/${tb}.sv]
if { [llength $sv_files] == 0 } {
    puts "ERROR: No source files found for testbench $tb"
    exit 1
}

# Compile.
puts "Compiling: $sv_files"
set compile_cmd [concat [list xvlog -sv] $sv_files]
exec {*}$compile_cmd

# Elaborate.
puts "Elaborating $tb..."
exec xelab $tb -s ${tb}_sim

# Run simulation.
puts "Running simulation..."
exec xsim ${tb}_sim -runall

# Vivado Simulator writes $display output to xsim.log.
# Print it so the user sees the testbench messages.
set log_file "xsim.log"
if { [file exists $log_file] } {
    puts ""
    puts "--- $log_file ---"
    set fh [open $log_file r]
    puts [read $fh]
    close $fh
}

puts "Simulation complete."
