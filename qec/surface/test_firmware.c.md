# Surface parser TDD
RED gcc failed because new firmware did not exist. GREEN compiles exact parser
with SURFACE_NATIVE_TEST, validates24-bit syndrome payload,32-bit cycle value,
reply checksum, malformed packet silence/recovery, partial timeout and reset.
Run gcc -std=c11 -Wall -Wextra -Werror qec/surface/test_firmware.c -o
build/test_surface_firmware, then execute it. This is parser evidence, not board
transport evidence; actual hardware tests exercise the UART/MMIO half separately.
