#------------------------------------------------------------------------------
# build_soc.tcl
# Project-mode Vivado build for SoC (PS + PL) designs.
#
# Usage:
#   vivado -mode batch -source scripts/build_soc.tcl -tclargs <top_module>
#
# Unlike the pure-PL build (build.tcl, non-project mode), SoC designs use a
# block design for the Zynq PS7, which requires project mode.  The generated
# project lives under build/ and is regenerated on every run.
#
# The block-design contents are per-top: scripts/bd/<top_module>.tcl is
# sourced after `create_bd_design system` and must leave a valid design.
#
# Outputs:
#   build/<name>.bit  - bitstream (PS7 configuration + PL routing)
#   build/<name>.xsa  - hardware handoff for Vitis (includes the bitstream)
#------------------------------------------------------------------------------

# Parse the top-module argument.
set top [lindex $argv 0]
if { $top eq "" } {
    set top top_ps_hello
}

# Short name used for output files: top_ps_hello -> ps_hello.
set name [string map {top_ ""} $top]

puts "Building SoC top module: $top"

# Target device: Zynq-7010 in CLG400 package, speed grade -1.
set part_name  xc7z010clg400-1
set board_part digilentinc.com:zybo-z7-10:part0:1.2

# The Digilent board files live in the AMD install tree but are not on the
# default board search path.
set_param board.repoPaths [list /home/toastcheng/amd/2025.2/data/boards/board_files]

# Output directories.
file mkdir build
set proj_dir build/vivado_${name}
file delete -force $proj_dir

#------------------------------------------------------------------------------
# Project and block design
#------------------------------------------------------------------------------

create_project $name $proj_dir -part $part_name -force
set_property board_part $board_part [current_project]

create_bd_design system

# The block-design contents are specific to each SoC top module; the per-top
# script is sourced here and must leave a valid `system` block design.
set bd_script scripts/bd/${top}.tcl
if { ![file exists $bd_script] } {
    error "No block-design script for top '$top' (expected $bd_script)"
}
source $bd_script

validate_bd_design
generate_target all [get_files system.bd]

# Generate the HDL wrapper around the block design.
make_wrapper -files [get_files system.bd] -top
set wrapper [glob $proj_dir/${name}.gen/sources_1/bd/system/hdl/system_wrapper.v]
add_files -norecurse $wrapper

#------------------------------------------------------------------------------
# Top-level RTL and constraints
#------------------------------------------------------------------------------

# Shared packages and reusable common modules (SoC tops may use any of them).
add_files -norecurse [glob rtl/pkg/*.sv]
if { [llength [glob -nocomplain rtl/common/*.sv]] > 0 } {
    add_files -norecurse [glob rtl/common/*.sv]
}

add_files -norecurse rtl/top/${top}.sv
set_property top $top [current_fileset]

add_files -norecurse constraints/${top}.xdc

#------------------------------------------------------------------------------
# Synthesis, implementation, bitstream
#------------------------------------------------------------------------------

puts "Starting synthesis and implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if { [get_property PROGRESS [get_runs impl_1]] ne "100%" } {
    error "Implementation failed; see $proj_dir/${name}.runs/impl_1 for logs"
}

#------------------------------------------------------------------------------
# Reports, bitstream copy, and XSA export
#------------------------------------------------------------------------------

open_run impl_1

puts "Writing reports..."
report_utilization -file build/${top}_utilization.rpt
report_timing_summary -file build/${top}_timing_summary.rpt

puts "Copying bitstream..."
file copy -force $proj_dir/${name}.runs/impl_1/${top}.bit build/${name}.bit

puts "Exporting hardware platform (XSA)..."
write_hw_platform -fixed -include_bit -force build/${name}.xsa

puts "Build complete: build/${name}.bit and build/${name}.xsa"
