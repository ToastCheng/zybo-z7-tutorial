# Surface PS/PL command mailbox
Reuses same-clock PS AXI GPIO at 0x41200000. ctrl[31] request toggle,
ctrl[27:24] opcode, ctrl[23:16] word index, ctrl[15:0] little-endian word.
Opcode1 loads a 16-bit syndrome word; opcode2 launches the hardware decoder;
opcode3 resets the core and clears syndrome words. Hold each command until
status[31] matches request. status[30] result-valid, [29] error, [28] prediction,
[27:0] measured cycles. Decoder counter overflow is explicitly an error.
One command/window outstanding. Word count derives from DETECTORS; padding in
the last word is ignored. Firmware validates packet length against configured
code before issuing writes. The core itself retains full32-bit instrumentation.
