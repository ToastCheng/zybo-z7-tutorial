# Actual surface RTL simulation
Run `qec/.venv/bin/python qec/surface/sim.py --distance 3 --basis z --shots 256`;
repeat with --distance 5 and --basis x. Generates graph ROM and reference vectors
in distinct ignored build directories, compiles real surface_decoder.sv and test
bench with Vivado xsim, and requires a PASS marker while rejecting HDL fatals.
No software loopback is used. The generated wrapper/case files are disposable
simulation artifacts; paired source tutorials explain the generator and bench.
