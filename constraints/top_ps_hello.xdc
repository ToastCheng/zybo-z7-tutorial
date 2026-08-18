#------------------------------------------------------------------------------
# top_ps_hello.xdc
# Phase 9 per-top constraints.
#
# Only the button pin is constrained here: the EMIO GPIO carries it straight
# into the PS, and there is no fabric logic or fabric clock in this design.
# The PS pins (DDR, FIXED_IO) are dedicated pads and need no constraints.
#------------------------------------------------------------------------------

# BTN0 (active high when pressed)
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { btn }];
