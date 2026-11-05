# PS UART1 binary bridge
Keeps the A5/sequence/syndrome/XOR request and 5A/sequence/prediction/16-bit
little-endian cycles/XOR reply. It does not compute predictions in ARM software.
Every valid packet toggles AXI GPIO request and polls the independent PL
completion; prediction and measured cycle count come from GPIO status.
The parser slides to recover malformed checksums and expires partial packets
after 50 ms interbyte idle. Hardware decode has a 100 ms timeout, resets PL
and sends no success reply on failure. Startup resets PL. UART is 115200 8N1.
Native test compiles the exact parser by defining QEC_NATIVE_TEST; only the
platform-dependent UART/MMIO main is excluded. Onboard hardware tests are
required to establish the MMIO and physical transport boundary.
