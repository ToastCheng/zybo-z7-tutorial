#------------------------------------------------------------------------------
# run_soc.tcl
# Program the PL and run the PS application on the Zybo Z7-10 via JTAG.
#
# Usage (from the repository root):
#   xsct scripts/run_soc.tcl <bitstream> <elf> [xsa]
# e.g.
#   xsct scripts/run_soc.tcl build/ps_hello.bit \
#       build/vitis_ws/ps_hello_app/build/ps_hello_app.elf build/ps_hello.xsa
#
# Requires the board to be connected and powered, and hw_server to be
# reachable (xsct starts one automatically if none is running).
#------------------------------------------------------------------------------

set bit [lindex $argv 0]
set elf [lindex $argv 1]
set xsa [lindex $argv 2]

if { $bit eq "" || $elf eq "" } {
    error "usage: xsct scripts/run_soc.tcl <bitstream> <elf> [xsa]"
}

# The PS (DDR, clocks, MIO) must be initialized before the app can run.
# ps7_init.tcl is generated with the Vitis platform (<app>_platform, derived
# from the ELF path); fall back to the copy inside the XSA if given.
set app_dir  [file tail [file dirname [file dirname $elf]]]
set platform [string map {_app _platform} $app_dir]
set init_tcl [glob -nocomplain build/vitis_ws/$platform/export/$platform/hw/sdt/ps7_init.tcl]
if { $init_tcl eq "" && $xsa ne "" } {
    puts "ps7_init.tcl not found in platform export, extracting from $xsa ..."
    file mkdir build/ps7_init
    exec unzip -o -j $xsa ps7_init.tcl -d build/ps7_init
    set init_tcl build/ps7_init/ps7_init.tcl
}
if { $init_tcl eq "" } {
    error "ps7_init.tcl not found (no platform export and no XSA given)"
}

connect

# Program the PL (FPGA fabric) with the bitstream.
puts "Programming PL with $bit ..."
targets -set -nocase -filter {name =~ "*xc7z010*"}
fpga -file $bit

# Initialize the PS (DDR3, clocks, MIO pin mux).
puts "Initializing PS ..."
targets -set -nocase -filter {name =~ "APU*"}
source $init_tcl
ps7_init
ps7_post_config

# Download and start the application on Cortex-A9 core 0.
puts "Downloading $elf ..."
targets -set -nocase -filter {name =~ "ARM*#0"}
rst -processor
dow $elf
con

puts "Application running. Open the UART (115200 baud) to interact with it."
