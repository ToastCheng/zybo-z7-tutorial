# Surface-code USB SoC top
Retains proven PS DDR/MIO/FCLK/reset wiring from top_qec_soc, but replaces its
repetition LUT bridge with surface_ps_bridge and graph-configured algorithmic
surface_decoder. Initial hardware target is rotated d3/r3 memory Z, 24 detectors
and78 graph edges. LED[3:0] mirrors mailbox acknowledgement/valid/error/prediction.
No Pmod pins or external UART adapter. No repetition LUT is used by this top.
