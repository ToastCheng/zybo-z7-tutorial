#------------------------------------------------------------------------------
# bd/top_audio_fx_soc.tcl
# Block design for Phase 11 (top_audio_fx_soc): PS-controlled audio effects.
#
#   - I2C1 routed through EMIO to the PL codec pins (the PS configures the
#     SSM2603 from software; no RTL I2C master in this design).
#   - AXI GPIO on M_AXI_GP0: a 32-bit control word the PS writes to select
#     the effect, the intensity, codec_ready, and mute in the PL.
#
# Sourced by scripts/build_soc.tcl after `create_bd_design system`.
#------------------------------------------------------------------------------

# Add the Zynq PS7 and apply the Zybo Z7-10 board preset (DDR3 timing, MIO
# mapping, UART1 on the USB-UART bridge, 50 MHz PS clock input).
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]

# I2C1 through EMIO: the codec control pins (N17/N18) are PL pins, so the
# hard PS I2C controller reaches them through the fabric.
set_property -dict [list \
    CONFIG.PCW_I2C1_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_I2C1_I2C1_IO {EMIO} \
] [get_bd_cells ps7]

make_bd_intf_pins_external [get_bd_intf_pins ps7/IIC_1]

# AXI GPIO: one 32-bit output-only channel = the control word.
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {32} \
    CONFIG.C_ALL_OUTPUTS {1} \
] [get_bd_cells axi_gpio_0]

# Wire S_AXI to M_AXI_GP0; automation creates the AXI interconnect and the
# proc_sys_reset block and clocks everything from FCLK_CLK0.
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/ps7/M_AXI_GP0" Clk "Auto"} \
    [get_bd_intf_pins axi_gpio_0/S_AXI]

# Export the control word to the PL top level.
make_bd_pins_external [get_bd_pins axi_gpio_0/gpio_io_o]
