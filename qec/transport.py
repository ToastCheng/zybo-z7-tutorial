"""Bounded framed UART protocol; no device is opened on import."""
from functools import reduce
from operator import xor


def request(seq, syndrome):
    if not 0 <= seq <= 255 or not 0 <= syndrome <= 255:
        raise ValueError('sequence and syndrome must be bytes')
    data = bytes([0xA5, seq, syndrome])
    return data + bytes([reduce(xor, data)])


def exchange(endpoint, seq, syndrome, timeout=1.0):
    """Endpoint reads/writes must themselves be bounded by timeout."""
    import time
    deadline = time.monotonic() + timeout
    packet = request(seq, syndrome)
    if endpoint.write(packet) != len(packet):
        raise IOError('short request write')
    parser = Parser()
    while time.monotonic() < deadline:
        frames = parser.feed(endpoint.read(64))
        if frames:
            if len(frames) != 1 or frames[0][0] != seq:
                raise ValueError('response sequence mismatch or duplicate')
            return frames[0][1:]
    raise TimeoutError('response deadline expired; close/reopen endpoint before retry')


class Loopback:
    """Software only. Cycle count is zero: no RTL timing is simulated."""
    def __init__(self, table):
        self.table = table
        self.pending = bytearray()

    def write(self, packet):
        if len(packet) != 4 or packet[0] != 0xA5 or reduce(xor, packet):
            raise ValueError('invalid request')
        data = bytes([0x5A, packet[1], int(self.table[packet[2]]), 0, 0])
        self.pending.extend(data + bytes([reduce(xor, data)]))
        return len(packet)

    def read(self, size):
        data = bytes(self.pending[:size])
        del self.pending[:size]
        return data


class Parser:
    def __init__(self):
        self.buffer = bytearray()

    def feed(self, data):
        frames = []
        for value in data:
            if not self.buffer and value != 0x5A:
                continue
            self.buffer.append(value)
            if len(self.buffer) == 6:
                frame = bytes(self.buffer)
                self.buffer.clear()
                if reduce(xor, frame) != 0 or frame[2] not in (0, 1):
                    raise ValueError('invalid response checksum or prediction')
                frames.append((frame[1], frame[2], frame[3] | frame[4] << 8))
        return frames
