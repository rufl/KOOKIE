#!/usr/bin/env python3
"""Verify the bounded browser WebSocket session path without third-party deps."""

from __future__ import annotations

import base64
import json
import os
import re
import socket
import ssl
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from kookie_websocket_session import (  # noqa: E402
    GAME,
    ERROR,
    GAME_COMMAND_MARKER,
    GAME_MOVE_LEFT,
    GAME_FULL_SCENE_PROBE,
    GAME_FULL_SCENE_SNAPSHOT_MARKER,
    GAME_SNAPSHOT_MARKER,
    GAME_MELEE,
    GAME_MOVE_FORWARD,
    GAME_RESET,
    GAME_SCENE_PROBE,
    GAME_SCENE_SNAPSHOT_MARKER,
    GAME_SPECIAL,
    GAME_PROBE_PAYLOAD,
    HELLO,
    PING,
    PONG,
    decode_session_frame,
    encode_session_frame,
    message_checksum,
)


MAX_PAYLOAD = 16 + 64 * 4


def recv_exact(sock: socket.socket, count: int) -> bytes:
    data = bytearray()
    while len(data) < count:
        chunk = sock.recv(count - len(data))
        if not chunk:
            raise AssertionError("peer closed before expected bytes")
        data.extend(chunk)
    return bytes(data)


def read_server_frame(sock: socket.socket) -> tuple[int, bytes]:
    first, second = recv_exact(sock, 2)
    assert first & 0x80, "server frame must be final"
    opcode = first & 0x0F
    assert not (second & 0x80), "server frame must not be masked"
    length = second & 0x7F
    if length == 126:
        length = struct.unpack(">H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack(">Q", recv_exact(sock, 8))[0]
    assert length <= MAX_PAYLOAD, "server frame exceeded bounded payload"
    return opcode, recv_exact(sock, length)


def client_frame(payload: bytes, opcode: int = 2) -> bytes:
    mask = b"KOF!"
    length = len(payload)
    header = bytearray((0x80 | opcode, 0x80))
    if length < 126:
        header[1] |= length
    elif length <= 0xFFFF:
        header[1] |= 126
        header.extend(struct.pack(">H", length))
    else:
        header[1] |= 127
        header.extend(struct.pack(">Q", length))
    header.extend(mask)
    header.extend(value ^ mask[index % 4] for index, value in enumerate(payload))
    return bytes(header)


def start_gateway(
    certfile: str | None = None,
    keyfile: str | None = None,
    auth_token: str | None = None,
    auth_token_file: str | None = None,
    once: bool = True,
) -> tuple[subprocess.Popen[str], int]:
    command = [
        sys.executable, str(SCRIPT_DIR / "kookie_websocket_session.py"),
        "--port", "0",
    ]
    if once:
        command.append("--once")
    if certfile is not None and keyfile is not None:
        command.extend(["--tls-certfile", certfile, "--tls-keyfile", keyfile])
    if auth_token is not None:
        command.extend(["--auth-token", auth_token])
    if auth_token_file is not None:
        command.extend(["--auth-token-file", auth_token_file])
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert process.stdout is not None
    line = process.stdout.readline().strip()
    match = re.search(r":(\d+)(?:\s|$)", line)
    assert match and "listening" in line, line
    return process, int(match.group(1))


def connect(
    port: int, tls: bool = False, auth_token: str | None = None
) -> socket.socket:
    sock = socket.create_connection(("127.0.0.1", port), timeout=5.0)
    if tls:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        sock = context.wrap_socket(sock, server_hostname="localhost")
    key = base64.b64encode(b"0123456789abcdef").decode("ascii")
    protocols = ["kookie.v1"]
    if auth_token is not None:
        protocols.append("bearer." + auth_token)
    request = (
        "GET /session HTTP/1.1\r\n"
        "Host: 127.0.0.1\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        f"Sec-WebSocket-Protocol: {', '.join(protocols)}\r\n\r\n"
    ).encode("ascii")
    sock.sendall(request)
    response = bytearray()
    while b"\r\n\r\n" not in response:
        response.extend(sock.recv(1024))
    assert response.startswith(b"HTTP/1.1 101 Switching Protocols"), response
    assert b"Sec-WebSocket-Protocol: kookie.v1" in response
    return sock

def rejected_upgrade(port: int, auth_token: str | None = None) -> bytes:
    with socket.create_connection(("127.0.0.1", port), timeout=5.0) as sock:
        key = base64.b64encode(b"0123456789abcdef").decode("ascii")
        protocols = ["kookie.v1"]
        if auth_token is not None:
            protocols.append("bearer." + auth_token)
        request = (
            "GET /session HTTP/1.1\r\n"
            "Host: 127.0.0.1\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            f"Sec-WebSocket-Protocol: {', '.join(protocols)}\r\n\r\n"
        ).encode("ascii")
        sock.sendall(request)
        response = bytearray()
        while b"\r\n\r\n" not in response:
            response.extend(sock.recv(1024))
        return bytes(response)

def http_get(port: int, path: str) -> tuple[bytes, bytes]:
    with socket.create_connection(("127.0.0.1", port), timeout=5.0) as sock:
        request = (
            f"GET {path} HTTP/1.1\r\n"
            "Host: 127.0.0.1\r\n"
            "Connection: close\r\n\r\n"
        ).encode("ascii")
        sock.sendall(request)
        response = bytearray()
        while b"\r\n\r\n" not in response:
            response.extend(sock.recv(1024))
        header_end = response.index(b"\r\n\r\n") + 4
        headers = bytes(response[:header_end])
        match = re.search(
            rb"(?im)^Content-Length:\s*(\d+)\r\n", headers
        )
        assert match, headers
        body_length = int(match.group(1))
        while len(response) - header_end < body_length:
            response.extend(sock.recv(body_length - (len(response) - header_end)))
        return headers, bytes(response[header_end:header_end + body_length])

def admit_hello(sock: socket.socket) -> None:
    hello_words = [2, HELLO, 1, 1, 1, 1, 1]
    hello_words.append(message_checksum(hello_words))
    sock.sendall(client_frame(encode_session_frame(HELLO, 1, hello_words)))
    opcode, payload = read_server_frame(sock)
    assert opcode == 2
    ack = decode_session_frame(payload)
    assert ack.kind == 2 and ack.sequence == 1 and ack.words[3] == 1





def run_health_and_metrics() -> None:
    process, port = start_gateway(
        auth_token="qualification-token", once=False
    )
    try:
        headers, body = http_get(port, "/healthz")
        assert headers.startswith(b"HTTP/1.1 200 OK"), headers
        health = json.loads(body)
        assert health == {
            "active_sessions": 0,
            "auth_required": True,
            "auth_source": "flag",
            "protocol": "kookie.v1",
            "status": "ok",
            "transport": "ws",
        }, health

        headers, body = http_get(port, "/metrics")
        assert headers.startswith(b"HTTP/1.1 200 OK"), headers
        metrics = body.decode("utf-8")
        assert "kookie_gateway_auth_required 1" in metrics
        assert 'kookie_gateway_auth_source{name="flag"} 1' in metrics
        assert "kookie_gateway_health_requests 1" in metrics
        assert "kookie_gateway_metrics_requests 1" in metrics

        headers, _ = http_get(port, "/not-a-route")
        assert headers.startswith(b"HTTP/1.1 404 Not Found"), headers
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)


def run_valid_session() -> None:
    process, port = start_gateway()
    try:
        with connect(port) as sock:
            hello_words = [2, HELLO, 1, 1, 1, 1, 1]
            hello_words.append(message_checksum(hello_words))
            sock.sendall(client_frame(encode_session_frame(HELLO, 1, hello_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            ack = decode_session_frame(payload)
            assert ack.kind == 2 and ack.sequence == 1 and ack.words[3] == 1

            ping_words = [2, PING, 2]
            ping_words.append(message_checksum(ping_words))
            sock.sendall(client_frame(encode_session_frame(PING, 2, ping_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            pong = decode_session_frame(payload)
            assert pong.kind == PONG and pong.sequence == 2

            game_words = [2, GAME, 3, GAME_PROBE_PAYLOAD]
            game_words.append(message_checksum(game_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 3, game_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            echoed = decode_session_frame(payload)
            assert echoed.kind == GAME and echoed.words == tuple(game_words)

            move_words = [2, GAME, 4, GAME_COMMAND_MARKER, GAME_MOVE_LEFT, -8]
            move_words.append(message_checksum(move_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 4, move_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            moved = decode_session_frame(payload)
            assert moved.words[3:6] == (GAME_SNAPSHOT_MARKER, 1, -8)

            melee_words = [2, GAME, 5, GAME_COMMAND_MARKER, GAME_MELEE, 0]
            melee_words.append(message_checksum(melee_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 5, melee_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            melee = decode_session_frame(payload)
            assert melee.words[4:10] == (2, -8, 100, 90, 1, 1)

            special_words = [2, GAME, 6, GAME_COMMAND_MARKER, GAME_SPECIAL, 0]
            special_words.append(message_checksum(special_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 6, special_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            special = decode_session_frame(payload)
            assert special.words[4:10] == (3, -8, 100, 65, 0, 2)

            reset_words = [2, GAME, 7, GAME_COMMAND_MARKER, GAME_RESET, 0]
            reset_words.append(message_checksum(reset_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 7, reset_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            reset = decode_session_frame(payload)
            assert reset.words[4:10] == (4, 0, 100, 100, 0, 0)

            scene_probe_words = [2, GAME, 8, GAME_COMMAND_MARKER, GAME_SCENE_PROBE, 0]
            scene_probe_words.append(message_checksum(scene_probe_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 8, scene_probe_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            scene = decode_session_frame(payload)
            assert scene.words[3] == GAME_SCENE_SNAPSHOT_MARKER
            assert len(scene.words) == 30
            assert scene.words[4:13] == (4, 0, 0, 0, 100, 100, 0, 0, 3)
            assert scene.words[25:29] == (0, 0, 0, 0)

            scene_special_words = [2, GAME, 9, GAME_COMMAND_MARKER, GAME_SPECIAL, 0]
            scene_special_words.append(message_checksum(scene_special_words))
            sock.sendall(client_frame(encode_session_frame(
                GAME, 9, scene_special_words
            )))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            scene_special = decode_session_frame(payload)
            assert scene_special.words[3] == GAME_SCENE_SNAPSHOT_MARKER
            assert scene_special.words[4:13] == (5, 0, 0, 0, 100, 75, 0, 2, 3)
            assert scene_special.words[25] == 1
            assert scene_special.words[26:29] == (12, 0, 6)

            full_reset_words = [2, GAME, 10, GAME_COMMAND_MARKER, GAME_RESET, 0]
            full_reset_words.append(message_checksum(full_reset_words))
            sock.sendall(client_frame(encode_session_frame(
                GAME, 10, full_reset_words
            )))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            full_reset = decode_session_frame(payload)
            assert full_reset.words[3] == GAME_SCENE_SNAPSHOT_MARKER

            full_probe_words = [2, GAME, 11, GAME_COMMAND_MARKER, GAME_FULL_SCENE_PROBE, 0]
            full_probe_words.append(message_checksum(full_probe_words))
            sock.sendall(client_frame(encode_session_frame(
                GAME, 11, full_probe_words
            )))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            full_scene = decode_session_frame(payload)
            assert full_scene.words[3] == GAME_FULL_SCENE_SNAPSHOT_MARKER
            assert len(full_scene.words) == 61
            assert full_scene.words[4:15] == (6, 32, 1, 52, 0, -8, 100, 100, 24, 0, 0)
            assert full_scene.words[20] == 4
            assert full_scene.words[49:61] == (0, 0, 0, 0, 0, 0, 1, 1, 128, 1, 112,
                                                full_scene.words[60])

            forward_words = [2, GAME, 12, GAME_COMMAND_MARKER, GAME_MOVE_FORWARD, 8]
            forward_words.append(message_checksum(forward_words))
            sock.sendall(client_frame(encode_session_frame(
                GAME, 12, forward_words
            )))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            forward = decode_session_frame(payload)
            assert forward.words[4] == 7 and forward.words[7] == 60

            fire_words = [2, GAME, 13, GAME_COMMAND_MARKER, 14, 0]
            fire_words.append(message_checksum(fire_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 13, fire_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            fired = decode_session_frame(payload)
            assert fired.words[4] == 8 and fired.words[12] == 23
            assert fired.words[50] == 1 and fired.words[54] == 10

            jump_words = [2, GAME, 14, GAME_COMMAND_MARKER, 15, 0]
            jump_words.append(message_checksum(jump_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 14, jump_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            jumped = decode_session_frame(payload)
            assert jumped.words[4] == 9 and jumped.words[6] == 8
            sock.sendall(client_frame(struct.pack(">H", 1000), opcode=8))
        process.wait(timeout=5)
        assert process.returncode == 0
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)


def run_tls_session() -> None:
    with tempfile.TemporaryDirectory(prefix="kookie-wss-") as directory:
        directory_path = Path(directory)
        certificate = directory_path / "localhost.crt"
        key = directory_path / "localhost.key"
        subprocess.run(
            [
                "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                "-keyout", str(key), "-out", str(certificate),
                "-subj", "/CN=localhost", "-days", "1",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        process, port = start_gateway(str(certificate), str(key))
        try:
            with connect(port, tls=True) as sock:
                hello_words = [2, HELLO, 1, 1, 1, 1, 1]
                hello_words.append(message_checksum(hello_words))
                sock.sendall(
                    client_frame(encode_session_frame(HELLO, 1, hello_words))
                )
                opcode, payload = read_server_frame(sock)
                assert opcode == 2
                ack = decode_session_frame(payload)
                assert ack.words[3] == 1
                sock.sendall(client_frame(struct.pack(">H", 1000), opcode=8))
            process.wait(timeout=5)
            assert process.returncode == 0
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)


def run_authenticated_session() -> None:
    token = "qualification-token"
    process, port = start_gateway(auth_token=token)
    try:
        response = rejected_upgrade(port)
        assert response.startswith(b"HTTP/1.1 401 Unauthorized"), response
        process.wait(timeout=5)
        assert process.returncode == 0
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)

    process, port = start_gateway(auth_token=token)
    try:
        with connect(port, auth_token=token) as sock:
            hello_words = [2, HELLO, 1, 1, 1, 1, 1]
            hello_words.append(message_checksum(hello_words))
            sock.sendall(
                client_frame(encode_session_frame(HELLO, 1, hello_words))
            )
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            ack = decode_session_frame(payload)
            assert ack.words[3] == 1
            sock.sendall(client_frame(struct.pack(">H", 1000), opcode=8))
        process.wait(timeout=5)
        assert process.returncode == 0
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)


def run_authenticated_file_session() -> None:
    token = "qualification-token"
    with tempfile.TemporaryDirectory(prefix="kookie-auth-") as directory:
        token_file = Path(directory) / "gateway.token"
        token_file.write_text(token + "\n", encoding="ascii")
        token_file.chmod(0o600)
        process, port = start_gateway(
            auth_token_file=str(token_file), once=False
        )
        try:
            response = rejected_upgrade(port)
            assert response.startswith(b"HTTP/1.1 401 Unauthorized"), response
            with connect(port, auth_token=token) as sock:
                admit_hello(sock)
                sock.sendall(client_frame(struct.pack(">H", 1000), opcode=8))
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)



def run_rejection_session() -> None:
    process, port = start_gateway()
    try:
        with connect(port) as sock:
            # The frame builder rejects invalid message checksums. Corrupt the
            # finished wire instead, exercising the gateway's wire validator.
            valid = [2, HELLO, 1, 1, 1, 1, 1]
            valid.append(message_checksum(valid))
            wire = bytearray(encode_session_frame(HELLO, 1, valid))
            wire[-1] ^= 1
            sock.sendall(client_frame(bytes(wire)))
            opcode, _ = read_server_frame(sock)
            assert opcode == 2
        process.wait(timeout=5)
        assert process.returncode == 0
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)


def run_empty_game_rejection_session() -> None:
    process, port = start_gateway()
    try:
        with connect(port) as sock:
            hello_words = [2, HELLO, 1, 1, 1, 1, 1]
            hello_words.append(message_checksum(hello_words))
            sock.sendall(client_frame(encode_session_frame(HELLO, 1, hello_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            ack = decode_session_frame(payload)
            assert ack.kind == 2 and ack.words[3] == 1

            empty_game = [2, GAME, 2]
            empty_game.append(message_checksum(empty_game))
            sock.sendall(client_frame(encode_session_frame(GAME, 2, empty_game)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            error = decode_session_frame(payload)
            assert error.kind == ERROR and error.words[3] > 0
        process.wait(timeout=5)
        assert process.returncode == 0
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)


def run_out_of_order_rejection_session() -> None:
    process, port = start_gateway()
    try:
        with connect(port) as sock:
            hello_words = [2, HELLO, 1, 1, 1, 1, 1]
            hello_words.append(message_checksum(hello_words))
            sock.sendall(client_frame(encode_session_frame(HELLO, 1, hello_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            ack = decode_session_frame(payload)
            assert ack.kind == 2 and ack.words[3] == 1

            move_words = [2, GAME, 2, GAME_COMMAND_MARKER, GAME_MOVE_LEFT, -8]
            move_words.append(message_checksum(move_words))
            sock.sendall(client_frame(encode_session_frame(GAME, 2, move_words)))
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            snapshot = decode_session_frame(payload)
            assert snapshot.words[3] == GAME_SNAPSHOT_MARKER

            duplicate_words = [
                2, GAME, 2, GAME_COMMAND_MARKER, GAME_MELEE, 0
            ]
            duplicate_words.append(message_checksum(duplicate_words))
            sock.sendall(
                client_frame(encode_session_frame(GAME, 2, duplicate_words))
            )
            opcode, payload = read_server_frame(sock)
            assert opcode == 2
            error = decode_session_frame(payload)
            assert error.kind == ERROR and error.words[3] > 0
        process.wait(timeout=5)
        assert process.returncode == 0
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)


def main() -> int:
    run_health_and_metrics()
    run_valid_session()
    run_tls_session()
    run_authenticated_session()
    run_authenticated_file_session()
    run_rejection_session()
    run_empty_game_rejection_session()
    run_out_of_order_rejection_session()
    print("KOOKIE WebSocket session/health/metrics/rejection paths verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
