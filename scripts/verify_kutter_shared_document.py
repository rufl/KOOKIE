#!/usr/bin/env python3
"""Verify two Kutter clients observe one authoritative Kof document."""
import base64
import hashlib
import os
import socket
import struct
import subprocess
import sys
import time
import urllib.request

PROTOCOL = 2
KIND_HELLO = 1
KIND_ACK = 2
KIND_GAME = 6
REQUEST = 1987145331
RESPONSE = 1987145332
COMMAND_GET = 1
COMMAND_TOOL = 2
COMMAND_CURSOR = 3
COMMAND_APPLY = 4
COMMAND_UPDATE = 18
COMMAND_HEIGHT = 19
COMMAND_PREVIEW = 20
COMMAND_IMPORT = 16
TRANSFER_WORDS = 256


def message_checksum(words):
    value = 53
    for word in words:
        value = (value * 31 + word % 1000003) % 1000003
    return value


def wire_checksum(data):
    return sum((0 if i in (14, 15) else byte) * (i + 1)
               for i, byte in enumerate(data)) & 0xffff


def encode(kind, sequence, words):
    wire = bytearray(b"KWS1" + bytes((1, kind, 0, 0)) +
                     struct.pack(">IHH", sequence, len(words), 0))
    wire.extend(struct.pack(">" + "i" * len(words), *words))
    wire[14:16] = struct.pack(">H", wire_checksum(wire))
    return bytes(wire)


def decode(wire):
    assert wire[:4] == b"KWS1" and wire[4] == 1
    sequence, count, expected = struct.unpack(">IHH", wire[8:16])
    assert len(wire) == 16 + count * 4 and wire_checksum(wire) == expected
    words = list(struct.unpack(">" + "i" * count, wire[16:]))
    assert words[0] == PROTOCOL and words[2] == sequence
    assert words[-1] == message_checksum(words[:-1])
    return words


class KutterClient:
    def __init__(self, port):
        self.socket = socket.create_connection(("127.0.0.1", port), timeout=5)
        self.socket.settimeout(5)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (f"GET /session HTTP/1.1\r\nHost: localhost\r\n"
                   "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                   f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n"
                   "Sec-WebSocket-Protocol: kookie.v1\r\n\r\n")
        self.socket.sendall(request.encode("ascii"))
        headers = bytearray()
        while b"\r\n\r\n" not in headers:
            part = self.socket.recv(1)
            if not part:
                raise AssertionError("server closed before WebSocket upgrade")
            headers.extend(part)
        header = bytes(headers).split(b"\r\n\r\n", 1)[0]
        assert header.startswith(b"HTTP/1.1 101"), header
        assert b"Sec-WebSocket-Accept: " + base64.b64encode(hashlib.sha1(
            (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()) in header
        self.sequence = 1
        hello = [PROTOCOL, KIND_HELLO, 1, 1, 1, 1, 1]
        hello.append(message_checksum(hello))
        self.send(KIND_HELLO, hello)
        ack = self.receive()
        assert ack[1] == KIND_ACK and ack[3] == 1, ack
        self.sequence = 1

    def send(self, kind, words):
        payload = encode(kind, words[2], words)
        mask = os.urandom(4)
        size = len(payload)
        header = (bytes((0x82, 0x80 | size)) if size < 126 else
                  bytes((0x82, 0xfe)) + struct.pack(">H", size))
        masked = bytes(value ^ mask[index & 3]
                       for index, value in enumerate(payload))
        self.socket.sendall(header + mask + masked)

    def _read_exact(self, count):
        result = bytearray()
        while len(result) < count:
            part = self.socket.recv(count - len(result))
            if not part:
                raise EOFError("Kutter WebSocket closed")
            result.extend(part)
        return bytes(result)

    def receive(self):
        first, second = self._read_exact(2)
        assert first == 0x82 and not second & 0x80
        size = second & 0x7f
        if size == 126:
            size = struct.unpack(">H", self._read_exact(2))[0]
        assert size <= 1296
        return decode(self._read_exact(size))

    def request(self, command, args=()):
        self.sequence += 1
        words = [PROTOCOL, KIND_GAME, self.sequence, REQUEST, command, *args]
        words.append(message_checksum(words))
        self.send(KIND_GAME, words)
        chunks = None
        total = None
        while True:
            response = self.receive()
            if response[1] != KIND_GAME or response[3] != RESPONSE:
                continue
            if response[2] != self.sequence:
                continue  # Shared-state broadcasts can precede this response.
            assert response[4] == command and response[5] == 0, response
            chunk_total = response[14]
            if chunk_total == 0:
                return None
            if total is None:
                total = chunk_total
                chunks = [None] * total
            assert chunk_total == total
            offset = response[13]
            payload = response[15:-1]
            assert offset >= 0 and offset + len(payload) <= total
            chunks[offset:offset + len(payload)] = payload
            if all(word is not None for word in chunks):
                return chunks

    def close(self):
        try:
            self.socket.sendall(b"\x88\x80\x01\x02\x03\x04")
        except OSError:
            pass
        self.socket.close()


def health(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/healthz", timeout=3) as response:
        return response.read()


def main():
    binary = os.path.abspath(sys.argv[1])
    port = int(sys.argv[2])
    env = dict(os.environ, KOOKIE_WEB_PORT=str(port))
    process = subprocess.Popen([binary], cwd=os.path.dirname(binary), env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    clients = []
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise AssertionError("Kof server exited: " +
                                     process.stderr.read().decode(errors="replace"))
            try:
                if b'"status":"ok"' in health(port):
                    break
            except OSError:
                time.sleep(0.05)
        else:
            raise AssertionError("Kof server did not become healthy")

        first = KutterClient(port)
        second = KutterClient(port)
        clients.extend((first, second))
        initial = first.request(COMMAND_GET)
        assert initial[7] == 1
        assert second.request(COMMAND_GET)[7] == 1
        first.request(COMMAND_PREVIEW)
        preview_sync = second.receive()
        assert preview_sync[12] & 8
        first.request(COMMAND_TOOL, [2])
        tool_sync = second.receive()
        assert tool_sync[2] == 1000000 and tool_sync[8] == 2
        assert tool_sync[12] & 8
        first.request(COMMAND_CURSOR, [100, 200])
        cursor_sync = second.receive()
        assert cursor_sync[2] == 1000000 and cursor_sync[9:11] == [100, 200]
        placed = first.request(COMMAND_APPLY)
        pushed = second.receive()
        assert pushed[2] == 1000000 and pushed[3] == RESPONSE
        assert pushed[15 + 7] == 2
        assert placed[7] == 2
        first.request(COMMAND_HEIGHT, [1])
        raised = second.receive()
        assert raised[15 + 11 + 13 + 4] == 200
        observed = second.request(COMMAND_GET)
        assert observed[7] == 2
        assert observed[11 + 13 + 3] == 200
        assert observed[11 + 13 + 4] == 200
        assert observed[11 + 13 + 5] == 400

        changed = first.request(COMMAND_UPDATE,
                                [300, 500, 200, 15000, 1000, 1000,
                                 1000, 0x00ff00, 41001])
        pushed = second.receive()
        assert pushed[2] == 1000000 and pushed[3] == RESPONSE
        assert pushed[15 + 11 + 13 + 3] == 600
        observed = second.request(COMMAND_GET)
        assert changed[7] == 2 and observed[7] == 2
        assert observed[11 + 13 + 3] == 600
        assert observed[11 + 13 + 4] == 1000
        assert observed[11 + 13 + 5] == 400
        assert observed[11 + 13 + 12] == 41001

        total = len(changed)
        for offset in range(0, total, TRANSFER_WORDS):
            chunk = changed[offset:offset + TRANSFER_WORDS]
            imported = first.request(COMMAND_IMPORT, [total, offset, *chunk])
        assert imported == changed
        assert second.request(COMMAND_GET) == changed
        print("KOOKIE shared Kutter document protocol passed")
    finally:
        for client in clients:
            client.close()
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


if __name__ == "__main__":
    main()
