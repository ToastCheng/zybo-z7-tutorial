# Firmware parser regression
RED: gcc fails because vitis/qec/src/main.c is not yet implemented.
GREEN: `gcc -std=c11 -Wall -Wextra -Werror qec/test_ps_firmware.c -o build/test_ps_firmware && build/test_ps_firmware`.
Tests exact response framing including a non-default cycle count, rejection of
bad checksum without decoder invocation, next-frame recovery and partial-frame
timeout. Callback stands in for MMIO only; physical exhaustive tests verify it.
