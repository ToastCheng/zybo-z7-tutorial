#------------------------------------------------------------------------------
# Zybo Z7-10 constraints
# Pin assignments and timing constraints for the Zybo Z7-10 (Zynq-7010).
#
# These constraints match the standard top-level port names used throughout
# this project:
#   clk      : 125 MHz single-ended clock
#   btn[3:0] : PL-connected push-buttons, active high when pressed
#   sw[3:0]  : Slide switches
#   led[3:0] : Single-color LEDs, active high
#   rgb_led[2:0] : RGB LED LD6, active high (rgb_led[2]=R, [1]=G, [0]=B)
#------------------------------------------------------------------------------

# System clock (125 MHz, 8 ns period)
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

# Push-buttons (active high when pressed)
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { btn[0] }];
set_property -dict { PACKAGE_PIN P16 IOSTANDARD LVCMOS33 } [get_ports { btn[1] }];
set_property -dict { PACKAGE_PIN K19 IOSTANDARD LVCMOS33 } [get_ports { btn[2] }];
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports { btn[3] }];

# Slide switches
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];

# Single-color LEDs LD0..LD3 (active high)
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

# RGB LED LD6 (Zybo Z7-10 and Z7-20)
# rgb_led[2]=R, rgb_led[1]=G, rgb_led[0]=B
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { rgb_led[2] }];
set_property -dict { PACKAGE_PIN F17 IOSTANDARD LVCMOS33 } [get_ports { rgb_led[1] }];
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports { rgb_led[0] }];

# Note: RGB LED LD5 exists only on the Zybo Z7-20. Its pins are:
#   led5_r -> Y11, led5_g -> T5, led5_b -> Y12
# Uncomment and add a second rgb_led entry if you migrate to the Z7-20.

#------------------------------------------------------------------------------
# UART pins on Pmod JE (standard Pmod, 200 ohm series resistors).
#   JE1 (V12) = uart_rx   (FPGA input from host TX)
#   JE2 (W16) = uart_tx   (FPGA output to host RX)
#------------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { uart_rx }];
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];
