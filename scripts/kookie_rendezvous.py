#!/usr/bin/env python3
"""Small authenticated UDP rendezvous for KOOKIE's bounded WAN demo."""

from __future__ import annotations

import argparse
import os
import socket
import struct
import time
from dataclasses import dataclass

TRANSPORT_MAGIC = 0x4B4F4F4B
TRANSPORT_VERSION = 1
HEADER_WORDS = 6
MAX_WORDS = 300
LOBBY_MAGIC = 1263488843
LOBBY_VERSION = 1
HELLO = 1
ACCEPT = 2
LEAVE = 3
WAIT = 4
PEER = 5
ROOM_TTL_SECONDS = 30.0
MAX_ROOMS = 4096


def rotate_left(value: int, shift: int) -> int:
    return ((value << shift) | (value >> (64 - shift))) & 0xFFFFFFFFFFFFFFFF


def sip_round(values: list[int]) -> None:
    v0, v1, v2, v3 = values
    v0 = (v0 + v1) & 0xFFFFFFFFFFFFFFFF
    v1 = rotate_left(v1, 13) ^ v0
    v0 = rotate_left(v0, 32)
    v2 = (v2 + v3) & 0xFFFFFFFFFFFFFFFF
    v3 = rotate_left(v3, 16) ^ v2
    v0 = (v0 + v3) & 0xFFFFFFFFFFFFFFFF
    v3 = rotate_left(v3, 21) ^ v0
    v2 = (v2 + v1) & 0xFFFFFFFFFFFFFFFF
    v1 = rotate_left(v1, 17) ^ v2
    v2 = rotate_left(v2, 32)
    values[:] = [v0, v1, v2, v3]


def mac(data: bytes, key: tuple[int, int]) -> int:
    key0, key1 = key
    values = [
        0x736F6D6570736575 ^ key0,
        0x646F72616E646F6D ^ key1,
        0x6C7967656E657261 ^ key0,
        0x7465646279746573 ^ key1,
    ]
    offset = 0
    while offset + 8 <= len(data):
        message = int.from_bytes(data[offset : offset + 8], "little")
        values[3] ^= message
        sip_round(values)
        sip_round(values)
        values[0] ^= message
        offset += 8
    final = len(data) << 56
    for index, value in enumerate(data[offset:]):
        final |= value << (index * 8)
    values[3] ^= final
    sip_round(values)
    sip_round(values)
    values[0] ^= final
    values[2] ^= 0xFF
    sip_round(values)
    sip_round(values)
    sip_round(values)
    sip_round(values)
    return values[0] ^ values[1] ^ values[2] ^ values[3]


def parse_key() -> tuple[int, int]:
    encoded = os.environ.get("KOOKIE_TRANSPORT_KEY_HEX", "")
    if len(encoded) == 32:
        try:
            words = [int(encoded[index : index + 8], 16) for index in range(0, 32, 8)]
        except ValueError:
            words = []
        if len(words) == 4:
            return words[0] | (words[1] << 32), words[2] | (words[3] << 32)
    return (
        1263488843 | (1330332754 << 32),
        1229737803 | (1162760019 << 32),
    )


def unpack_frame(data: bytes, key: tuple[int, int]) -> tuple[int, list[int]] | None:
    if len(data) < HEADER_WORDS * 4 or len(data) % 4 != 0:
        return None
    words = list(struct.unpack(f"!{len(data) // 4}I", data))
    count = words[2]
    sequence = words[3]
    if (
        words[0] != TRANSPORT_MAGIC
        or words[1] != TRANSPORT_VERSION
        or count <= 0
        or count > MAX_WORDS
        or len(words) != HEADER_WORDS + count
        or sequence == 0
    ):
        return None
    expected = words[4] | (words[5] << 32)
    words[4] = 0
    words[5] = 0
    unsigned = struct.pack(f"!{len(words)}I", *words)
    if mac(unsigned, key) != expected:
        return None
    return sequence, words[HEADER_WORDS:]


def pack_frame(sequence: int, payload: list[int], key: tuple[int, int]) -> bytes:
    header = [TRANSPORT_MAGIC, TRANSPORT_VERSION, len(payload), sequence, 0, 0]
    unsigned = struct.pack(f"!{len(header) + len(payload)}I", *(header + payload))
    digest = mac(unsigned, key)
    header[4] = digest & 0xFFFFFFFF
    header[5] = (digest >> 32) & 0xFFFFFFFF
    return struct.pack(
        f"!{len(header) + len(payload)}I", *(header + payload)
    )


def ipv4_words(address: tuple[str, int]) -> list[int]:
    return [int(part) for part in address[0].split(".")] + [address[1]]


@dataclass
class Client:
    address: tuple[str, int]
    role: int
    name: int
    last_sequence: int = 0
    send_sequence: int = 0
    last_seen: float = 0.0

    def next_sequence(self) -> int:
        self.send_sequence += 1
        if self.send_sequence >= 0xFFFFFFFF:
            self.send_sequence = 1
        return self.send_sequence


class Rendezvous:
    def __init__(self, bind: str, port: int, key: tuple[int, int]) -> None:
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.socket.settimeout(1.0)

        self.socket.bind((bind, port))
        self.key = key
        self.rooms: dict[int, list[Client]] = {}

    def send(self, client: Client, payload: list[int]) -> None:
        data = pack_frame(client.next_sequence(), payload, self.key)
        self.socket.sendto(data, client.address)

    def find_client(self, address: tuple[str, int]) -> tuple[int, Client] | None:
        for room, clients in self.rooms.items():
            for client in clients:
                if client.address == address:
                    return room, client
        return None

    def remove(self, client: Client, room: int) -> None:
        clients = self.rooms.get(room, [])
        self.rooms[room] = [candidate for candidate in clients if candidate is not client]
        if not self.rooms[room]:
            del self.rooms[room]

    def handle(self, data: bytes, address: tuple[str, int]) -> None:
        frame = unpack_frame(data, self.key)
        if frame is None:
            return
        sequence, payload = frame
        if len(payload) < 6 or payload[0] != LOBBY_MAGIC or payload[1] != LOBBY_VERSION:
            return
        operation, room, role, name = payload[2:6]
        if room <= 0 or room > 1_000_000 or role not in (1, 2):
            return
        existing = self.find_client(address)
        if existing is not None:
            old_room, client = existing
            if old_room != room:
                self.remove(client, old_room)
                existing = None
            elif sequence <= client.last_sequence:
                return
            else:
                client.last_sequence = sequence
                client.role = role
                client.name = name if 1 <= name <= 4 else 1
                client.last_seen = time.monotonic()
        if existing is None:
            client = Client(
                address,
                role,
                name if 1 <= name <= 4 else 1,
                last_sequence=sequence,
                last_seen=time.monotonic(),
            )
            if room not in self.rooms and len(self.rooms) >= MAX_ROOMS:
                return

            clients = self.rooms.setdefault(room, [])
            clients[:] = [candidate for candidate in clients if candidate.address != address]
            if len(clients) >= 2:
                clients.pop(0)
            clients.append(client)
        if operation == LEAVE:
            self.remove(client, room)
            return
        if operation != HELLO:
            return
        clients = self.rooms.get(room, [])
        if len(clients) < 2:
            self.send(client, [LOBBY_MAGIC, LOBBY_VERSION, WAIT, room])
            return
        for peer in clients:
            other = clients[1] if peer is clients[0] else clients[0]
            self.send(
                peer,
                [LOBBY_MAGIC, LOBBY_VERSION, PEER, room, *ipv4_words(other.address)],
            )
    def expire(self) -> None:
        now = time.monotonic()
        for room in list(self.rooms):
            clients = [
                client
                for client in self.rooms[room]
                if now - client.last_seen <= ROOM_TTL_SECONDS
            ]
            if clients:
                self.rooms[room] = clients
            else:
                del self.rooms[room]


    def run(self) -> None:
        print(f"KOOKIE rendezvous UDP listening on {self.socket.getsockname()[0]}:{self.socket.getsockname()[1]}", flush=True)
        try:
            while True:
                try:
                    data, address = self.socket.recvfrom(
                        (HEADER_WORDS + MAX_WORDS) * 4
                    )
                except socket.timeout:
                    self.expire()
                    continue
                self.handle(data, address)
        except KeyboardInterrupt:
            pass
        finally:
            self.socket.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=47101)
    args = parser.parse_args()
    if args.port <= 0 or args.port > 65535:
        parser.error("--port must be in 1..65535")
    Rendezvous(args.bind, args.port, parse_key()).run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
