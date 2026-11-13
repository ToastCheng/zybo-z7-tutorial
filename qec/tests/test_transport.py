import importlib.util
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def test_loopback_heldout_circuits_and_cli(tmp_path):
    import transport
    import decoder
    import numpy as np
    import subprocess
    assert hasattr(transport, 'Loopback'), 'loopback missing'
    circuit, matching = decoder.model()
    detectors, observables = circuit.compile_detector_sampler(seed=90210).sample(2000, separate_observables=True)
    table = decoder.make_lut()
    endpoint = transport.Loopback(table)
    predictions = [transport.exchange(endpoint, i % 256, int(s))[0]
                   for i, s in enumerate(decoder.pack(detectors))]
    np.testing.assert_array_equal(predictions, matching.decode_batch(detectors)[:, 0])
    result = subprocess.run([sys.executable, 'qec/host.py', '--mode', 'loopback', '--shots', '2000', '--seed', '90210'], capture_output=True, text=True, check=True)
    import json
    report = json.loads(result.stdout)
    assert report['mode'] == 'software-loopback'
    assert report['shots'] == 2000
    assert report['prediction_mismatches'] == 0
    assert report['logical_errors'] == int(np.sum(table[decoder.pack(detectors)] != observables[:, 0]))


def test_pyserial_pty_cli_marks_output_as_unmeasured_hardware():
    import os
    import select
    import threading
    import time
    import json
    import subprocess
    import decoder
    import transport
    master, slave = os.openpty()
    slave_name = os.ttyname(slave)
    table = decoder.make_lut()
    errors = []
    def serve():
        pending = bytearray()
        try:
            for _ in range(32):
                deadline = time.monotonic() + 10
                while len(pending) < 4:
                    if time.monotonic() > deadline:
                        raise TimeoutError('PTY request deadline')
                    if select.select([master], [], [], 0.05)[0]:
                        pending.extend(os.read(master, 4096))
                packet = bytes(pending[:4])
                del pending[:4]
                assert packet == transport.request(packet[1], packet[2])
                data = bytes([90, packet[1], int(table[packet[2]]), 2, 0])
                from functools import reduce
                from operator import xor
                reply = data + bytes([reduce(xor, data)])
                os.write(master, reply[:2])
                os.write(master, reply[2:])
        except BaseException as error:
            errors.append(error)
    worker = threading.Thread(target=serve, daemon=True)
    worker.start()
    try:
        result = subprocess.run([sys.executable, 'qec/host.py', '--mode', 'serial', '--port', slave_name,
                                 '--shots', '32', '--seed', '90210'], capture_output=True, text=True, check=True, timeout=15)
        worker.join(timeout=2)
        assert not errors
        report = json.loads(result.stdout)
        assert report['mode'] == 'serial-unverified-hardware'
        assert report['fpga_measured'] is False
        assert report['prediction_mismatches'] == 0
        assert report['response_cycles_min'] == report['response_cycles_max'] == 2
    finally:
        os.close(master)
        os.close(slave)


def test_expired_response_is_not_accepted():
    import time
    import pytest
    import transport
    class LateEndpoint:
        def write(self, data):
            return len(data)
        def read(self, size):
            time.sleep(0.01)
            return bytes([90, 7, 1, 52, 18, 122])
    with pytest.raises(TimeoutError):
        transport.exchange(LateEndpoint(), 7, 129, timeout=0.001)


def test_partial_response_and_exact_request():
    assert importlib.util.find_spec('transport') is not None, 'transport missing'
    import transport
    assert transport.request(7, 129) == bytes([165, 7, 129, 35])
    parser = transport.Parser()
    assert parser.feed(b'garbage\x5a\x07') == []
    assert parser.feed(bytes([1, 52, 18, 122])) == [(7, 1, 0x1234)]
    assert len(parser.buffer) <= 5


def test_exchange_validates_sequence_checksum_and_timeout():
    import transport
    import pytest
    assert hasattr(transport, 'exchange'), 'exchange missing'
    class Endpoint:
        def __init__(self, response):
            self.response = bytearray(response)
        def write(self, data):
            self.sent = data
            return len(data)
        def read(self, size):
            value = self.response[:1]
            del self.response[:1]
            return bytes(value)
    good = bytes([90, 7, 1, 52, 18, 122])
    endpoint = Endpoint(good)
    assert transport.exchange(endpoint, 7, 129, timeout=0.05) == (1, 0x1234)
    assert endpoint.sent == transport.request(7, 129)
    with pytest.raises(ValueError, match='sequence'):
        transport.exchange(Endpoint(good), 8, 129, timeout=0.05)
    with pytest.raises(ValueError, match='checksum'):
        transport.exchange(Endpoint(good[:-1] + b'\x00'), 7, 129, timeout=0.05)
    with pytest.raises(ValueError, match='prediction'):
        transport.Parser().feed(bytes([90, 7, 2, 0, 0, 95]))
    with pytest.raises(TimeoutError):
        transport.exchange(Endpoint(good[:3]), 7, 129, timeout=0.001)
    with pytest.raises(ValueError):
        transport.request(256, 0)
    parser = transport.Parser()
    assert parser.feed(b'x' * 100000) == []
    assert len(parser.buffer) == 0
