#!/usr/bin/env python3
"""Exercise concurrent 8-player/4-spectator admission and authoritative movement."""
import base64
import hashlib
import json
import os
import socket
import struct
import subprocess
import sys
import time
import urllib.request
import queue
import threading


def checksum(words):
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
    assert words[0] == 2 and words[2] == sequence
    assert words[-1] == checksum(words[:-1])
    return words


class Client:
    def __init__(self, port, spectator=False, accepted=True, path=None):
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=5)
        self.sock.settimeout(5)
        self.closed = False
        self.sequence = 1
        role = 2 if spectator else 1
        path = path or ("/spectate" if spectator else "/session")
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (f"GET {path} HTTP/1.1\r\nHost: localhost\r\n"
                   "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                   f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n"
                   "Sec-WebSocket-Protocol: kookie.v1\r\n\r\n")
        self.sock.sendall(request.encode("ascii"))
        headers = bytearray()
        while b"\r\n\r\n" not in headers:
            part = self.sock.recv(1)
            if not part:
                raise AssertionError("socket closed before WebSocket upgrade")
            headers.extend(part)
        header = bytes(headers).split(b"\r\n\r\n", 1)[0]
        assert header.startswith(b"HTTP/1.1 101"), header
        expected_accept = base64.b64encode(hashlib.sha1(
            (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
        assert b"Sec-WebSocket-Accept: " + expected_accept in header

        hello = [2, 1, 1, 1, 1, 1, 1]
        hello.append(checksum(hello))
        self.send(1, hello)
        ack = self.receive()
        assert ack[1:4] == [2, 1, 1] and ack[3] == 1, ack
        self.sequence = 2
        join = [2, 6, self.sequence, 5, role]
        join.append(checksum(join))
        self.send(6, join)
        response = self.receive()
        assert response[3] == 6 and response[5] == role, response
        assert response[4] == (1 if accepted else 0), response
        self.role = role
        self.player_id = response[6]
        self.join_response = response
        self.inbox = queue.Queue()
        self.reader = threading.Thread(target=self._read_loop, daemon=True)
        self.reader.start()


    def input(self, move_x=0, move_z=0, look_yaw=0, look_pitch=0,
              held=0, edge=0):
        self.sequence += 1
        words = [2, 6, self.sequence, 8, 0, move_x, move_z,
                 look_yaw, look_pitch, held, edge]
        words.append(checksum(words))
        self.send(6, words)
        return self.sequence
    def send(self, kind, words):
        data = encode(kind, words[2], words)
        mask = os.urandom(4)
        masked = bytes(value ^ mask[i & 3] for i, value in enumerate(data))
        length = len(data)
        header = (bytes((0x82, 0x80 | length)) if length < 126 else
                  bytes((0x82, 0xfe)) + struct.pack(">H", length))
        self.sock.sendall(header + mask + masked)

    def _read_exact(self, size):
        result = bytearray()
        while len(result) < size:
            part = self.sock.recv(size - len(result))
            if not part:
                self.closed = True
                raise EOFError("WebSocket closed")
            result.extend(part)
        return bytes(result)

    def _read_frame(self):
        first, second = self._read_exact(2)
        assert first & 0x80 and first & 0x0f == 2 and not second & 0x80
        length = second & 0x7f
        if length == 126:
            length = struct.unpack(">H", self._read_exact(2))[0]
        assert length <= 1104
        return decode(self._read_exact(length))

    def _read_loop(self):
        while not self.closed:
            try:
                self.inbox.put(self._read_frame())
            except Exception as error:
                self.inbox.put(error)
                return

    def receive(self):
        if not hasattr(self, "inbox"):
            return self._read_frame()
        try:
            result = self.inbox.get(timeout=self.sock.gettimeout())
        except queue.Empty as error:
            raise TimeoutError("timed out waiting for WebSocket frame") from error
        if isinstance(result, BaseException):
            raise result
        return result

    def snapshot(self, expected_players=None, expected_spectators=None):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            words = self.receive()
            if len(words) < 19 or words[3] != 7:
                continue
            if expected_players is not None and words[15] != expected_players:
                continue
            if expected_spectators is not None and words[16] != expected_spectators:
                continue
            return words
        raise AssertionError("no matching multiplayer snapshot")

    def wait_closed(self):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                self.receive()
            except EOFError:
                return
        raise AssertionError("WebSocket remained connected")

    def close(self):
        if self.closed:
            return
        try:
            self.sock.sendall(b"\x88\x80\x01\x02\x03\x04")
        except OSError:
            pass
        self.sock.close()
        self.closed = True


def health(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/healthz", timeout=3) as response:
        return json.loads(response.read())


def actor_record(scene, player_id):
    return next(scene[18 + index * 8:26 + index * 8]
                for index in range(scene[17])
                if scene[18 + index * 8] == player_id)


def wait_for_actor(client, players, spectators, player_id, predicate, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        scene = client.snapshot(players, spectators)
        actor = actor_record(scene, player_id)
        if predicate(actor, scene):
            return scene, actor
    raise AssertionError(f"authoritative state predicate failed for actor {player_id}")

def input_acknowledgement(scene):
    trailer = 18 + scene[17] * 8
    return scene[trailer] if len(scene) >= trailer + 5 else 0


def wait_for_input_ack(client, input_sequence, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        scene = client.snapshot(expected_players=8, expected_spectators=4)
        if input_acknowledgement(scene) >= input_sequence:
            return scene
    raise AssertionError(f"input sequence {input_sequence} was not acknowledged after authoritative application")

def main():
    binary, port_text = os.path.abspath(sys.argv[1]), sys.argv[2]
    port = int(port_text)
    env = dict(os.environ, KOOKIE_WEB_PORT=port_text)
    process = subprocess.Popen([binary], cwd=os.path.dirname(binary), env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    clients = []
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise AssertionError("server exited before accepting connections: " +
                                     process.stderr.read().decode(errors="replace"))
            try:
                if health(port)["status"] == "ok":
                    break
            except (OSError, ValueError):
                time.sleep(0.05)
        else:
            raise AssertionError("server did not become healthy")

        players = [Client(port) for _ in range(8)]
        clients.extend(players)
        for player in players:
            scene = player.snapshot(expected_players=8, expected_spectators=0)
            assert scene[5] == 1 and scene[6] == player.player_id
            assert scene[17] == 8

        spectators = [Client(port, spectator=True) for _ in range(4)]
        clients.extend(spectators)
        for spectator in spectators:
            scene = spectator.snapshot(expected_players=8, expected_spectators=4)
            assert scene[5] == 2 and scene[6] == 0
            assert scene[17] == 8
        powerup_tester = players[0]
        pickup_deadline = time.monotonic() + 5
        pickup_actor = None
        while time.monotonic() < pickup_deadline:
            powerup_tester.input()
            pickup_scene = spectators[0].snapshot(expected_players=8,
                                                   expected_spectators=4)
            pickup_actor = actor_record(pickup_scene, powerup_tester.player_id)
            if pickup_actor[5] // 8 % 16 == 1:
                break
            time.sleep(.04)
        assert pickup_actor is not None and pickup_actor[5] // 8 % 16 == 1, (
            "authoritative coffee pickup was not replicated; actor="
            f"{pickup_actor}")
        shooter = players[0]
        target = players[3]
        target_before = actor_record(target.snapshot(8, 4), target.player_id)[4]
        shooter.input(look_yaw=-900, held=32)
        _, target_after = wait_for_actor(
            spectators[0], 8, 4, target.player_id,
            lambda state, snapshot: state[4] < target_before)
        assert target_after[4] < target_before, "hitscan did not damage an aimed player"
        shooter.input(held=0)

        mover = players[0]
        flyer = players[1]
        _, flyer_start = wait_for_actor(
            spectators[0], 8, 4, flyer.player_id, lambda state, snapshot: True)
        flight_start_y = flyer_start[2]
        flyer.input(held=16)
        _, flight_actor = wait_for_actor(
            spectators[0], 8, 4, flyer.player_id,
            lambda state, snapshot: state[2] > flight_start_y)
        assert flight_actor[2] > flight_start_y, "fly did not gain altitude"
        flyer.input(held=0)

        _, settled_actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[5] // 128 == 0)
        before = mover.snapshot(expected_players=8, expected_spectators=4)
        actor = next(18 + i * 8 for i in range(before[17])
                     if before[18 + i * 8] == mover.player_id)
        old_x = before[actor + 1]
        sent_input_sequence = mover.input(move_x=1000)
        ack_scene = wait_for_input_ack(mover, sent_input_sequence)
        assert input_acknowledgement(ack_scene) >= sent_input_sequence
        scene, moved_actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[1] != old_x)
        assert moved_actor[1] != old_x
        assert moved_actor[5] // 128 == 9, (
            f"ordinary locomotion did not select walk animation: {moved_actor}")
        mover.input()

        mover.input(held=1, edge=1)
        scene, actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[5] & 1 == 0)
        assert actor[5] // 128 == 6, f"jump animation missing: {actor}"
        dash_start = actor[1]
        mover.input(move_x=1000, edge=4)
        scene, actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[1] > dash_start and state[5] // 128 == 1)
        roll_start = actor[1]
        mover.input(move_x=1000, edge=2)
        scene, actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[1] > roll_start and state[5] // 128 == 7)
        mover.input(held=8)
        scene, actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[5] & 4 != 0)

        ammo_before = mover.snapshot(8, 4)[14]
        mover.input(look_yaw=-900, held=32)
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            scene = mover.snapshot(8, 4)
            if scene[14] < ammo_before:
                break
        else:
            raise AssertionError("shoot input did not consume authoritative ammunition")
        mover.input(held=0)
        trailer = 18 + scene[17] * 8
        mover.input(look_yaw=0, edge=128)
        scene = spectators[0].snapshot(8, 4)
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            trailer = 18 + scene[17] * 8
            if scene[trailer + 1] > 0:
                break
            scene = spectators[0].snapshot(8, 4)
        else:
            raise AssertionError("special projectile was not replicated")
        mover.input(edge=256)
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            scene = spectators[0].snapshot(8, 4)
            trailer = 18 + scene[17] * 8
            if scene[trailer + 2] > 0:
                break
        else:
            raise AssertionError("throwable was not replicated")
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            trailer = 18 + scene[17] * 8
            if scene[trailer + 3] > 0:
                break
            scene = spectators[0].snapshot(8, 4)
        else:
            raise AssertionError("throwable detonation impact was not replicated")
        collision_mover = players[1]
        collision_target = players[5]
        collision_mover.input(move_z=-1000)
        deadline = time.monotonic() + 2
        minimum_gap = 1000000
        while time.monotonic() < deadline:
            collision_scene = spectators[0].snapshot(8, 4)
            collision_state = actor_record(collision_scene, collision_mover.player_id)
            collision_target_state = actor_record(collision_scene, collision_target.player_id)
            gap = abs(collision_state[3] - collision_target_state[3])
            minimum_gap = min(minimum_gap, gap)
            if gap <= 5:
                break
        collision_mover.input()
        assert 4 <= minimum_gap <= 5, (
            "swept player contact did not stop movement at capsule separation")
        target_health = actor_record(collision_scene, collision_target.player_id)[4]
        collision_mover.input(look_yaw=1800, edge=64)
        _, melee_target = wait_for_actor(
            spectators[0], 8, 4, collision_target.player_id,
            lambda state, snapshot: state[4] < target_health)
        assert melee_target[4] < target_health, "melee input did not damage the contacted player"

        read_only = spectators[1]
        read_only.sequence += 1
        forged_move = [2, 6, read_only.sequence, 1, 2, 8]
        forged_move.append(checksum(forged_move))
        read_only.send(6, forged_move)
        read_only.wait_closed()
        clients.remove(read_only)

        spectators[0].close()
        clients.remove(spectators[0])
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError("server exited while freeing a spectator")
            try:
                if health(port)["active_sessions"] == 10:
                    break
            except (OSError, ValueError):
                time.sleep(0.05)
                continue
            time.sleep(0.05)
        else:
            raise AssertionError("spectator disconnect did not free session capacity")

        overflow_player = Client(port, accepted=False)
        overflow_player.close()
        time.sleep(0.1)
        replacements = [Client(port, spectator=True) for _ in range(2)]
        clients.extend(replacements)
        for replacement in replacements:
            scene = replacement.snapshot(
                expected_players=8, expected_spectators=4)
            assert scene[17] == 8

        for client in clients:
            client.close()
        clients.clear()
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                if health(port)["active_sessions"] == 0:
                    break
            except (OSError, ValueError):
                pass
            time.sleep(0.05)
        else:
            raise AssertionError("disconnects did not release every websocket")
        print("KOOKIE 8-player/4-spectator concurrent session qualification passed")
    finally:
        failed = sys.exc_info()[0] is not None
        for client in clients:
            client.close()
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
        if failed and process.stderr is not None:
            server_log = process.stderr.read().decode(errors="replace")
            if server_log:
                print("server stderr:\n" + server_log, file=sys.stderr)


if __name__ == "__main__":
    main()
