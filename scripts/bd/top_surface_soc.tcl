# Reuse the proven board preset and AXI GPIO/FCLK wiring, not its decoder.
source scripts/bd/top_qec_soc.tcl
add_files -norecurse qec/surface/graphs/d3_z_r3.mem
