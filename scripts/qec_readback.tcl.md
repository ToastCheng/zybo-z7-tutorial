# Programmed-device readback status
Run Vivado batch after scripts/run_soc.tcl. Connects the already authorized
localhost JTAG server and reads the exact xc7z010_1 configuration properties.
The captured report includes DONE/INIT/CRC/configuration registers where
supported. This is configuration-status readback, not a full bitstream
readback or comparison. No state is written and no persistent flash touched.
