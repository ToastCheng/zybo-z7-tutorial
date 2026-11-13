# Surface SoC block design
Sources the proven PS board-preset/AXI GPIO/common100MHz FCLK configuration;
adds d3_z_r3 graph ROM to project sources. The inherited repetition lut.mem file
is unused by the surface top and has no decoder instances in its hierarchy.
Build with scripts/build_soc.tcl -tclargs top_surface_soc. XSA/bitstream outputs
are build/surface_soc.xsa and .bit, distinct from repetition artifacts.
