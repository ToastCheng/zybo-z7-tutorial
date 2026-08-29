#------------------------------------------------------------------------------
# bd/top_ps_hello.tcl
# Block design for Phase 9 (top_ps_hello): PS7 with a 1-bit EMIO GPIO.
#
# Sourced by scripts/build_soc.tcl after `create_bd_design system`.
#------------------------------------------------------------------------------

# Add the Zynq PS7 and apply the Zybo Z7-10 board preset (DDR3 timing, MIO
# mapping, UART1 on the USB-UART bridge, 50 MHz PS clock input).
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]

# Enable a 1-bit EMIO GPIO so the PS can see a PL pin (the button).
# No AXI ports and no fabric clock are needed for this phase.
set_property -dict [list \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {1} \
    CONFIG.PCW_GPIO_EMIO_GPIO_IO {1} \
    CONFIG.PCW_USE_M_AXI_GP0 {0} \
] [get_bd_cells ps7]

# Expose the EMIO GPIO as an external port (GPIO_0 with tri_i/tri_o/tri_t).
make_bd_intf_pins_external [get_bd_intf_pins ps7/GPIO_0]
