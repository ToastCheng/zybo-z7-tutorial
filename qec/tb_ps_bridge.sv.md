# PS bridge regression
Run xvlog on the core, bridge and this test; xelab tb_ps_bridge; xsim -runall.
Enumerates every LUT syndrome, independently timestamps input acceptance and
first out_valid visibility after NBA updates, verifies measured status cycles,
checks stable completion while request is held and software reset/recovery.
Initial RED: xelab fails because qec_ps_bridge does not exist; GREEN: 256 pass.
