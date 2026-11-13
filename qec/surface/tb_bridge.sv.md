# Surface GPIO bridge TDD
Missing surface_ps_bridge fails xelab before implementation. GREEN tests40
reference syndromes over actual word-load/start mailbox RTL, measured nonzero
result counters, reset/zero-shot recovery and out-of-range word rejection.
Run after sim.py --shots256 has produced d3 cases; compile core, bridge and this
bench with xvlog, xelab tb_surface_bridge, xsim -runall. Require PASS/no Fatal.
