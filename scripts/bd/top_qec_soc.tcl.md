# USB-only QEC block design
Uses the proven Zybo Z7-10 PS board preset (DDR and UART1 MIO) instead of
suppressing ZPS7-1. GP0 connects dual-channel AXI GPIO at 0x41200000;
channel 1 is control output, channel 2 is status input. FCLK_CLK0 is configured
100 MHz and supplies GPIO, interconnect and decoder. Export its synchronized
peripheral reset. Build using scripts/build_soc.tcl -tclargs top_qec_soc.
No Pmod pins or adapter required. The XSA includes PS initialization and bitstream.
