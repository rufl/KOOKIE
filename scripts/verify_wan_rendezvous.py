#!/usr/bin/env python3
"""Exercise the authenticated UDP rendezvous and direct peer handoff."""

from __future__ import annotations

import os
import socket
import threading
import time

from kookie_rendezvous import (
    HELLO,
    LEAVE,
    LOBBY_MAGIC,
    LOBBY_VERSION,
    PEER,
    Rendezvous,
    WAIT,
    pack_frame,
    parse_key,
    unpack_frame,
)

KEY = (0x22110000FFEEDDCC, 0x66554433BBAA9988)
ROOM = 7127


def receive_frame(
    sock: socket.socket,
    timeout: float = 1.0,
) -> tuple[int, list[int]]:
    deadline = time.monotonic() + timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise AssertionError("timed out waiting for rendezvous frame")
        sock.settimeout(remaining)
        try:
            data, _ = sock.recvfrom(4096)
        except TimeoutError as error:
            raise AssertionError("timed out waiting for rendezvous frame") from error
        frame = unpack_frame(data, KEY)
        if frame is not None:
            return frame


def assert_no_frame(sock: socket.socket, timeout: float = 0.15) -> None:
    sock.settimeout(timeout)
    try:
        sock.recvfrom(4096)
    except TimeoutError:
        return
    raise AssertionError("unexpected rendezvous response")


def hello(
    sock: socket.socket,
    sequence: int,
    role: int,
    name: int,
    operation: int = HELLO,
) -> None:
    payload = [LOBBY_MAGIC, LOBBY_VERSION, operation, ROOM, role, name]
    sock.sendto(pack_frame(sequence, payload, KEY), SERVER_ADDRESS)


def expect_lobby(frame: tuple[int, list[int]], operation: int) -> list[int]:
    _, payload = frame
    assert payload[:4] == [LOBBY_MAGIC, LOBBY_VERSION, operation, ROOM]
    return payload


def test_key_configuration() -> None:
    previous = os.environ.pop("KOOKIE_TRANSPORT_KEY_HEX", None)
    try:
        try:
            parse_key()
        except ValueError:
            pass
        else:
            raise AssertionError("rendezvous accepted a missing key")
        os.environ["KOOKIE_TRANSPORT_KEY_HEX"] = "0" * 32
        try:
            parse_key()
        except ValueError:
            pass
        else:
            raise AssertionError("rendezvous accepted an all-zero key")
    finally:
        if previous is None:
            os.environ.pop("KOOKIE_TRANSPORT_KEY_HEX", None)
        else:
            os.environ["KOOKIE_TRANSPORT_KEY_HEX"] = previous


def main() -> int:
    global SERVER_ADDRESS
    test_key_configuration()
    server = Rendezvous("127.0.0.1", 0, KEY)
    SERVER_ADDRESS = ("127.0.0.1", server.bound_port())
    thread = threading.Thread(target=server.run, daemon=True)
    thread.start()
    first = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    second = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    third = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        first.bind(("127.0.0.1", 0))
        second.bind(("127.0.0.1", 0))
        third.bind(("127.0.0.1", 0))

        hello(first, 1, 1, 1)
        expect_lobby(receive_frame(first), WAIT)

        hello(second, 1, 2, 2)
        first_peer = expect_lobby(receive_frame(first), PEER)
        second_peer = expect_lobby(receive_frame(second), PEER)
        assert first_peer[4:] == [127, 0, 0, 1, second.getsockname()[1]]
        assert second_peer[4:] == [127, 0, 0, 1, first.getsockname()[1]]

        direct_payload = [0x47555345, ROOM, 1]
        second_address = ("127.0.0.1", second.getsockname()[1])
        first.sendto(pack_frame(1, direct_payload, KEY), second_address)
        _, received_direct = receive_frame(second)
        assert received_direct == direct_payload

        forged = bytearray(
            pack_frame(
                2,
                [LOBBY_MAGIC, LOBBY_VERSION, HELLO, ROOM, 1, 1],
                KEY,
            )
        )
        forged[-1] ^= 1
        first.sendto(forged, SERVER_ADDRESS)
        assert_no_frame(first)

        hello(third, 1, 1, 3)
        assert_no_frame(third)
        hello(first, 2, 1, 1)
        expect_lobby(receive_frame(first), PEER)
        expect_lobby(receive_frame(second), PEER)
        hello(first, 2, 1, 1)
        assert_no_frame(first)

        hello(first, 3, 1, 1, LEAVE)
        hello(second, 2, 2, 2)
        expect_lobby(receive_frame(second), WAIT)
        print("KOOKIE WAN rendezvous punchthrough verified")
        print("wan-room=7127")
        print("wan-direct-peer=authenticated")
        print("wan-room-capacity=2")
        return 0
    finally:
        first.close()
        second.close()
        third.close()
        server.close()
        thread.join(timeout=2.0)


if __name__ == "__main__":
    raise SystemExit(main())
