#------------------------------------------------------------------------------
# Constraints for top_audio_fx_soc
# 125 MHz fabric clock, debug LEDs, and the audio codec pins.
#
# The codec I2C pins are driven by the PS I2C1 controller through EMIO; they
# are still PL pins, so they are constrained here like any other fabric pin.
#------------------------------------------------------------------------------

# 125 MHz system clock (feeds the audio MMCM; the PS has its own clock).
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

# Single-color LEDs LD0..LD3 (debug mirror of the control word)
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

# I2S clocks and data.
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports { ac_bclk }];
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { ac_mclk }];
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { ac_pbdat }];
set_property -dict { PACKAGE_PIN T19 IOSTANDARD LVCMOS33 } [get_ports { ac_pblrc }];
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports { ac_recdat }];
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports { ac_reclrc }];

# I2C control interface (driven by PS I2C1 via EMIO).
set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ac_scl }];
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ac_sda }];

# Active-low mute control.
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { ac_muten }];

# Declare the generated MCLK that drives the codec.
create_generated_clock -name ac_mclk_pin \
    -source [get_pins clk_gen/mmcm_inst/CLKOUT0] \
    [get_ports ac_mclk]

# The AXI GPIO control word is a quasi-static level signal written by the PS
# (FCLK domain) and sampled in the MCLK domain through 2-flop synchronizers.
# Do not time it as a synchronous path.
set_false_path -to [get_cells ctrl_sync_0_reg[*]]

# The 125 MHz fabric clock and the audio MCLK come from different sources
# (pin vs. MMCM) with no fixed phase relationship.  The only cross-domain
# signals are quasi-static levels through synchronizers, so disable
# inter-clock timing analysis between the domains.
set_clock_groups -asynchronous -group [get_clocks sys_clk_pin] -group [get_clocks mclk_unbuf]
