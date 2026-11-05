# Physical corpus capture
Run with explicit serial port and board ID after volatile JTAG programming.
No loopback mode exists. Requests go through the existing framed protocol;
responses include the real PL counter. Every TX/RX byte, syndrome, Stim
observable, PyMatching reference, prediction and host perf_counter interval
is retained in transactions.csv. First 256 rows exhaust the table; then a
seeded real Stim detector sampler produces thousands of finite-shot windows.
Finally bad checksum, garbage and partial-packet idle timeout must be silent
and recover to a valid frame. summary.json separates LUT agreement, logical
observable failures and inclusive host/USB/PS/AXI timing. At 100 MHz two
PL cycles mean 20 ns core availability, not USB reaction latency. Register
capture is one later edge. Manifest hashes include bitstream, ELF, XSA,
source archive, table, logs and data. Requires build/qec_program.log and
build/qec_readback.log so provenance cannot be silently omitted.
Hardware-only assertions gate completion; library evaluation is tested by
qec/tests/test_hardware_run.py. Use a distinct new results directory each run.

Physical runs are archived under results/hardware-approved-run and
results/hardware-after-reset. Each manifest records the source revision and
hashes all 14 original artifacts; READMEs/verification addenda explain independent
replay validation. Exhaustive rows use LUT predictions as placeholder observable
and reference fields: their logical_errors/identity_errors are NOT sampled
quantum statistics. Only kind=stim rows have true Stim observables and regenerated
PyMatching references. The captured hardware predictions agree with the LUT for
all row kinds. No isolated in-flight reset or deliberate UART stop-bit fault
was injected on the PS UART; reset testing here is a full volatile reload/PS restart.
