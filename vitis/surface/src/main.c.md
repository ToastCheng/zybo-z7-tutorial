# Variable-width surface framing and MMIO firmware
The old repetition packet is intentionally not reused: its 8-bit syndrome and
16-bit cycle count are insufficient. New request: C3 seq byte_count payload XOR;
payload is little-endian packed detectors. Current d3/r3 build requires3 bytes;
byte_count0 requests reset. Response: 3C seq status prediction cycles[4 little
endian bytes] XOR,9 bytes. Status0 success,1 decoder/mailbox error,2 MMIO timeout.
Malformed length/checksum and partial-packet50ms timeout resynchronize without
calling the decoder. Main uses real PS UART1 and no software decoding.
It loads each16-bit word through AXI GPIO, starts PL, polls matching completion,
and returns the PL instrumented cycle count. No polynomial algorithm runs on ARM.
DETECTOR_BYTES is a compile-time capacity check; larger core graphs require an
updated firmware define alongside graph/RTL parameters. Buffer capacity16 detector
bytes, counter transport32 bits (mailbox28 bits, overflow reported as error).
Reset command pulses PL core reset and clears loaded syndrome words.
Native test includes the exact parser and replaces only the MMIO callback.
