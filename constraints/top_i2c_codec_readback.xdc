#------------------------------------------------------------------------------
# Constraints for top_i2c_codec_readback
# Uses the on-board SSM2603 audio codec I2C control interface.
#------------------------------------------------------------------------------

# I2C clock (FPGA drives SCL master)
set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ac_scl }];

# I2C data (open-drain, external pull-up required)
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ac_sda }];

# Active-low mute control.  The board has a pull-down, so drive high to enable
# the codec's analog outputs.
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { ac_muten }];
