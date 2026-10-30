#!/usr/bin/env python3
"""Exercise concurrent 8-player/4-spectator admission and authoritative movement."""
import base64
import hashlib
import json
import math
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
    def __init__(self, port, spectator=False, accepted=True, path=None,
                 role=None):
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=5)
        self.sock.settimeout(5)
        self.closed = False
        self.sequence = 1
        role = (2 if spectator else 1) if role is None else role
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
        assert length <= 1296
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

    def abort(self):
        if self.closed:
            return
        self.sock.setsockopt(
            socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
        self.sock.close()
        self.closed = True



def health(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/healthz", timeout=3) as response:
        return json.loads(response.read())


def actor_record(scene, player_id):
    return next(scene[18 + index * 8:26 + index * 8]
                for index in range(scene[17])
                if scene[18 + index * 8] == player_id)

def actor_with_powerup(scene, kind):
    return next((scene[18 + index * 8:26 + index * 8]
                 for index in range(scene[17])
                 if (scene[23 + index * 8] // 8) % 16 == kind), None)



def wait_for_actor(client, players, spectators, player_id, predicate, timeout=5):
    deadline = time.monotonic() + timeout
    last_actor = None
    last_tick = None
    while time.monotonic() < deadline:
        scene = client.snapshot(players, spectators)
        actor = actor_record(scene, player_id)
        last_actor = actor
        last_tick = scene[4]
        if predicate(actor, scene):
            return scene, actor
    raise AssertionError(
        f"authoritative state predicate failed for actor {player_id} "
        f"at tick {last_tick}: {last_actor}")

def input_acknowledgement(scene):
    trailer = 18 + scene[17] * 8
    return scene[trailer] if len(scene) >= trailer + 5 else 0

def throwable_suffix(scene):
    trailer = 18 + scene[17] * 8
    cursor = trailer + 4 + scene[trailer + 1] * 8
    cursor += scene[trailer + 2] * 8 + scene[trailer + 3] * 8
    # New suffix has ten fixed words plus count * four; six-word legacy remains valid.
    checksum_index = len(scene) - 1
    if checksum_index - cursor >= 10:
        count = scene[cursor + 9]
        if checksum_index == cursor + 10 + count * 4:
            return scene[cursor:cursor + 10 + count * 4]
    return scene[cursor:cursor + 6]
def projectile_records(scene):
    trailer = 18 + scene[17] * 8
    count = scene[trailer + 1]
    cursor = trailer + 4
    return [scene[cursor + index * 8:cursor + (index + 1) * 8]
            for index in range(count)]
def impact_events(scene):
    trailer = 18 + scene[17] * 8
    count = scene[trailer + 3]
    cursor = trailer + 4 + scene[trailer + 1] * 8 + scene[trailer + 2] * 8
    return [scene[cursor + index * 8:cursor + (index + 1) * 8]
            for index in range(count)]



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
            suffix = throwable_suffix(scene)
            assert suffix[0] == 1 and 1 <= suffix[4] <= 5, (
                "initial shared throwable must have a valid randomized item type")
            assert 4 <= suffix[1] <= 316 and 0 <= suffix[2] <= 100 and \
                4 <= suffix[3] <= 276, (
                    "randomized throwable pickup must be within arena bounds")
        coffee_deadline = time.monotonic() + 5
        coffee_actor = None
        while time.monotonic() < coffee_deadline:
            pickup_scene = spectators[0].snapshot(expected_players=8,
                                                   expected_spectators=4)
            coffee_actor = actor_with_powerup(pickup_scene, 1)
            if coffee_actor is not None:
                break
            time.sleep(.04)
        assert coffee_actor is not None, (
            f"authoritative coffee pickup was not replicated at tick "
            f"{pickup_scene[4]}; actors=" +
            repr([pickup_scene[18 + index * 8:26 + index * 8]
                  for index in range(pickup_scene[17])]))
        wizard_deadline = time.monotonic() + 5
        wizard_scene = None
        wizard_actor = None
        while time.monotonic() < wizard_deadline:
            wizard_scene = spectators[0].snapshot(
                expected_players=8, expected_spectators=4)
            wizard_actor = actor_with_powerup(wizard_scene, 8)
            if wizard_actor is not None:
                break
            time.sleep(.04)
        assert wizard_scene is not None and wizard_actor is not None, (
            "Wizard Hat pickup was not replicated; actors=" +
            repr([wizard_scene[18 + index * 8:26 + index * 8]
                  for index in range(wizard_scene[17])]))
        wizard_tester = next(client for client in players
                             if client.player_id == wizard_actor[0])
        wizard_scene = wizard_tester.snapshot(
            expected_players=8, expected_spectators=4)
        turn_sequence = wizard_tester.input(look_yaw=900)
        wizard_scene = wait_for_input_ack(wizard_tester, turn_sequence)
        for expected_shots in (4, 3, 2, 1, 0):
            before_projectiles = len(projectile_records(wizard_scene))
            sequence = wizard_tester.input(edge=128)
            wizard_scene = wait_for_input_ack(wizard_tester, sequence)
            assert throwable_suffix(wizard_scene)[8] == expected_shots, (
                "special action must consume one fireball charge")
            records = projectile_records(wizard_scene)
            assert len(records) == before_projectiles + 1 and records[-1][7] == 3, (
                "each Wizard Hat action must replicate one fireball projectile")
        shooter = players[0]
        target = players[2]
        aim_scene = spectators[0].snapshot(8, 4)
        shooter_state = actor_record(aim_scene, shooter.player_id)
        target_state = actor_record(aim_scene, target.player_id)
        target_before = target_state[4]
        desired_yaw = round(math.degrees(math.atan2(
            target_state[1] - shooter_state[1],
            target_state[3] - shooter_state[3],
        )))
        yaw_delta = (desired_yaw - shooter_state[7] + 180) % 360 - 180
        shooter.input(look_yaw=yaw_delta * 10, held=32)
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

        jump_start = settled_actor[2]
        mover.input(held=1, edge=1)
        jump_peak = jump_start
        saw_jump_animation = False
        jump_deadline = time.monotonic() + 1.5
        landed = False
        while time.monotonic() < jump_deadline:
            scene = spectators[0].snapshot(expected_players=8,
                                           expected_spectators=4)
            actor = actor_record(scene, mover.player_id)
            jump_peak = max(jump_peak, actor[2])
            saw_jump_animation |= actor[5] // 128 == 6
            if actor[2] <= jump_start and jump_peak > jump_start:
                landed = True
                break
        mover.input(held=0)
        assert jump_peak >= jump_start + 12, (
            f"authoritative jump arc too low: start={jump_start}, peak={jump_peak}")
        assert landed, "jump did not land within 1.5 seconds"
        assert saw_jump_animation, f"jump animation missing: {actor}"
        double_jump_start = actor[2]
        mover.input(held=1, edge=1)
        _, airborne_actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[2] > double_jump_start)
        double_jump_start = airborne_actor[2]
        mover.input(held=0)
        double_jump_sequence = mover.input(
            move_x=-1000, held=1, edge=1)
        double_jump_scene = wait_for_input_ack(
            mover, double_jump_sequence)
        double_jump_actor = actor_record(
            double_jump_scene, mover.player_id)
        assert (
            double_jump_actor[2] > double_jump_start and
            double_jump_actor[5] // 128 == 7 and
            double_jump_actor[5] & 64 != 0
        ), (
            "second Space press after release must launch and replicate a "
            "side-directed roll animation: "
            f"{double_jump_actor}")
        held_frame_sequence = mover.input(move_x=-1000, held=1)
        held_frame_scene = wait_for_input_ack(mover, held_frame_sequence)
        held_frame_actor = actor_record(held_frame_scene, mover.player_id)
        assert (
            held_frame_actor[5] // 128 == 7 and
            held_frame_actor[5] & 64 != 0
        ), (
            "double-jump roll must persist while Space remains held: "
            f"{held_frame_actor}")
        mover.input(held=0)
        _, actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot:
                state[5] // 128 != 7 and (state[5] & 1) != 0)
        dash_start = actor[1]
        dash_sequence = mover.input(move_x=1000, edge=4)
        dash_scene = wait_for_input_ack(mover, dash_sequence)
        actor = actor_record(dash_scene, mover.player_id)
        assert actor[1] > dash_start and actor[5] // 128 == 1, (
            f"dash input must move and select run animation: {actor}")
        scene, actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[1] > dash_start and state[5] // 128 == 1)
        roll_start = actor[1]
        mover.input(move_x=1000, edge=2)
        scene, actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot: state[1] > roll_start and state[5] // 128 == 7)
        roll_start_x, roll_start_z, roll_yaw = actor[1], actor[3], actor[7]
        mover.input(edge=2)
        forward_x = math.sin(math.radians(roll_yaw))
        forward_z = math.cos(math.radians(roll_yaw))
        scene, actor = wait_for_actor(
            spectators[0], 8, 4, mover.player_id,
            lambda state, snapshot:
                (state[1] - roll_start_x) * forward_x +
                (state[3] - roll_start_z) * forward_z > 0 and
                state[5] // 128 == 7)
        assert ((actor[1] - roll_start_x) * forward_x +
                (actor[3] - roll_start_z) * forward_z) > 0, (
            f"stationary roll did not travel in facing direction: {actor}")
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
        before_special_scene = mover.snapshot(8, 4)
        before_special_trailer = 18 + before_special_scene[17] * 8
        before_special_projectiles = before_special_scene[before_special_trailer + 1]
        assert throwable_suffix(before_special_scene)[8] == 0
        special_sequence = mover.input(look_yaw=0, edge=128)
        scene = wait_for_input_ack(mover, special_sequence)
        time.sleep(.2)
        scene = mover.snapshot(8, 4)
        trailer = 18 + scene[17] * 8
        assert scene[trailer + 1] == before_special_projectiles and \
            throwable_suffix(scene)[8] == 0, (
                "special action must not launch seed projectiles without seed ammo")
        legacy_edge_sequence = mover.input(edge=256)
        scene = wait_for_input_ack(mover, legacy_edge_sequence)
        trailer = 18 + scene[17] * 8
        assert scene[trailer + 2] == 0 and throwable_suffix(scene)[5] == 0, (
            "edge-only throwable input must not bypass shared pickup ownership")
        mover = players[0]
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            scene = mover.snapshot(8, 4)
            actor = actor_record(scene, mover.player_id)
            pickup = throwable_suffix(scene)
            dx, dz = pickup[1] - actor[1], pickup[3] - actor[3]
            if dx * dx + dz * dz <= 36:
                break
            sequence = mover.input(
                move_x=0 if dx == 0 else (1000 if dx > 0 else -1000),
                move_z=0 if dz == 0 else (1000 if dz > 0 else -1000))
            scene = wait_for_input_ack(mover, sequence)
        else:
            raise AssertionError("player could not reach the shared throwable pickup")
        pickup_sequence = mover.input(held=256)
        scene = wait_for_input_ack(mover, pickup_sequence)
        assert throwable_suffix(scene)[0] == 0 and \
            throwable_suffix(scene)[5:7] == [1, 0] and \
            throwable_suffix(scene)[7] in range(1, 6), (
            f"a press within pickup radius must disable pickup and carry the "
            f"throwable: suffix={throwable_suffix(scene)}, "
            f"actor={actor_record(scene, mover.player_id)}, tick={scene[4]}")
        carried_type = throwable_suffix(scene)[7]
        release_sequence = mover.input(held=0)
        wait_for_input_ack(mover, release_sequence)
        charge_sequence = mover.input(held=256)
        scene = wait_for_input_ack(mover, charge_sequence)
        charge_deadline = time.monotonic() + 2
        while time.monotonic() < charge_deadline:
            if throwable_suffix(scene)[6] >= 5:
                break
            scene = mover.snapshot(8, 4)
        else:
            raise AssertionError("held throwable charge did not advance on server ticks")
        assert throwable_suffix(scene)[5] == 1
        last_impact_sequence = max(
            (impact[0] for impact in impact_events(scene)), default=0)
        release_sequence = mover.input(held=0)
        scene = wait_for_input_ack(mover, release_sequence)
        assert throwable_suffix(scene)[0] == 0 and \
            throwable_suffix(scene)[5:7] == [0, 0] and \
            throwable_suffix(scene)[7] == 0, (
            "releasing a charged throwable must throw and clear carried charge")
        deadline = time.monotonic() + 3
        grenade_id = None
        while time.monotonic() < deadline:
            trailer = 18 + scene[17] * 8
            throwable_cursor = trailer + 4 + scene[trailer + 1] * 8
            if scene[trailer + 2] > 0:
                grenade_id = scene[throwable_cursor]
                assert scene[throwable_cursor + 6] == carried_type, (
                    "thrown record must preserve the picked-up throwable type")
                break
            events = impact_events(scene)
            if any(event[0] > last_impact_sequence and
                   event[2] == mover.player_id for event in events):
                grenade_id = 0
                break
            scene = mover.snapshot(8, 4)
        else:
            raise AssertionError(
                f"released charged throwable was neither replicated nor "
                f"resolved at tick {scene[4]}: "
                f"throwable_count={throwable_suffix(scene)[2]}, "
                f"impacts={impact_events(scene)}")
        resolved_tick = scene[4]
        resolution_deadline = time.monotonic() + 3
        observed_impact_kinds = {
            event[1] for event in impact_events(scene)
            if event[0] > last_impact_sequence
        }
        last_throwable_record = None
        last_throwable_y = None
        watermelon_descending = False
        watermelon_bounced = False
        last_scene_tick = scene[4]
        while grenade_id != 0 and time.monotonic() < resolution_deadline:
            next_scene = spectators[0].snapshot(8, 4)
            if next_scene[4] <= last_scene_tick:
                continue
            scene = next_scene
            last_scene_tick = scene[4]
            trailer = 18 + scene[17] * 8
            throwable_cursor = trailer + 4 + scene[trailer + 1] * 8
            live_ids = [scene[throwable_cursor + index * 8]
                        for index in range(scene[trailer + 2])]
            observed_impact_kinds.update(
                event[1] for event in impact_events(scene)
                if event[0] > last_impact_sequence)
            if grenade_id in live_ids:
                item_index = live_ids.index(grenade_id)
                last_throwable_record = scene[
                    throwable_cursor + item_index * 8:
                    throwable_cursor + item_index * 8 + 8]
                if carried_type == 3:
                    watermelon_y = last_throwable_record[3]
                    if last_throwable_y is not None:
                        if watermelon_y < last_throwable_y:
                            watermelon_descending = True
                        elif watermelon_descending and \
                                last_throwable_y <= 4 and \
                                watermelon_y > last_throwable_y:
                            watermelon_bounced = True
                    last_throwable_y = watermelon_y
            else:
                resolved_tick = scene[4]
                break
        if grenade_id != 0 and time.monotonic() >= resolution_deadline:
            raise AssertionError("thrown grenade did not resolve")
        trailer = 18 + scene[17] * 8
        throwable_cursor = trailer + 4 + scene[trailer + 1] * 8
        observed_impact_kinds.update(
            event[1] for event in impact_events(scene)
            if event[0] > last_impact_sequence)
        kinds = observed_impact_kinds
        if carried_type == 1:
            assert 5 in kinds, (
                f"bomb impact missing: id={grenade_id}, "
                f"last_throwable={last_throwable_record}, "
                f"kinds={sorted(kinds)}, "
                f"last_sequence={last_impact_sequence}, "
                f"final_events={impact_events(scene)}, "
                f"counts={scene[trailer + 1:trailer + 4]}, "
                f"throwables={scene[throwable_cursor:throwable_cursor + 16]}, "
                f"suffix={throwable_suffix(scene)}, "
                f"tick={scene[4]}, mover={actor_record(scene, mover.player_id)}")
        elif carried_type == 2:
            assert 6 in kinds, "flour package must create a no-damage smoke impact"
        elif carried_type == 3:
            assert 7 in kinds and throwable_suffix(scene)[9] == 4, (
                "watermelon must shatter into four collectible slices")
            assert watermelon_bounced, (
                "watermelon must bounce once from the ground before shattering")
        else:
            assert 5 in kinds or 3 in kinds, (
                "crate/boulder must resolve as a generic non-explosive prop")
        if carried_type == 3:
            slice_record = throwable_suffix(scene)[10:14]
            mover_state = actor_record(scene, mover.player_id)
            dx, dz = slice_record[1] - mover_state[1], \
                slice_record[3] - mover_state[3]
            pickup_deadline = time.monotonic() + 3
            while dx * dx + dz * dz > 36 and time.monotonic() < pickup_deadline:
                sequence = mover.input(
                    move_x=0 if dx == 0 else (1000 if dx > 0 else -1000),
                    move_z=0 if dz == 0 else (1000 if dz > 0 else -1000))
                scene = wait_for_input_ack(mover, sequence)
                mover_state = actor_record(scene, mover.player_id)
                dx, dz = slice_record[1] - mover_state[1], \
                    slice_record[3] - mover_state[3]
            assert dx * dx + dz * dz <= 36, "player could not reach watermelon slice"
            seed_ammo_before = throwable_suffix(scene)[8]
            slice_health_before = actor_record(scene, mover.player_id)[4]
            slice_count_before = throwable_suffix(scene)[9]
            sequence = mover.input(held=256)
            scene = wait_for_input_ack(mover, sequence)
            slice_count_after = throwable_suffix(scene)[9]
            picked_slices = slice_count_before - slice_count_after
            assert picked_slices > 0 and throwable_suffix(scene)[8] == \
                min(30, seed_ammo_before + picked_slices * 3), (
                    "each collected slice must add three capped seed rounds")
            assert actor_record(scene, mover.player_id)[4] == \
                min(100, slice_health_before + picked_slices * 8), (
                    "each slice must restore eight health up to the maximum")
            seed_scene = mover.snapshot(8, 4)
            seed_trailer = 18 + seed_scene[17] * 8
            seed_projectiles_before = seed_scene[seed_trailer + 1]
            sequence = mover.input(edge=128)
            seed_scene = wait_for_input_ack(mover, sequence)
            assert throwable_suffix(seed_scene)[8] == \
                min(30, seed_ammo_before + picked_slices * 3) - 1, (
                    "special action must consume exactly one acquired seed")
            seed_trailer = 18 + seed_scene[17] * 8
            assert seed_scene[seed_trailer + 1] == seed_projectiles_before + 1, (
                "acquired seed must launch one special projectile")
        respawn_deadline = time.monotonic() + 5
        while time.monotonic() < respawn_deadline:
            if (throwable_suffix(scene)[0] == 1 and
                    scene[4] >= resolved_tick + 180):
                break
            scene = spectators[0].snapshot(8, 4)
        else:
            raise AssertionError(
                "shared throwable did not respawn 180 ticks after resolution")
        respawn_suffix = throwable_suffix(scene)
        assert 1 <= respawn_suffix[4] <= 5 and \
            4 <= respawn_suffix[1] <= 316 and 4 <= respawn_suffix[3] <= 276, (
                "respawn must randomize a valid item type and in-bounds location")
        collision_mover = players[1]
        collision_scene = spectators[0].snapshot(8, 4)
        collision_mover_state = actor_record(
            collision_scene, collision_mover.player_id)
        alive_targets = [
            client for client in players
            if client.player_id != collision_mover.player_id and
            actor_record(collision_scene, client.player_id)[4] > 0
        ]
        collision_target = min(
            alive_targets,
            key=lambda client: abs(
                actor_record(collision_scene, client.player_id)[1] -
                collision_mover_state[1]) +
                abs(actor_record(collision_scene, client.player_id)[3] -
                    collision_mover_state[3]),
        )
        deadline = time.monotonic() + 2
        minimum_gap = 1000000
        while time.monotonic() < deadline:
            collision_target_state = actor_record(
                collision_scene, collision_target.player_id)
            dx = collision_target_state[1] - collision_mover_state[1]
            dz = collision_target_state[3] - collision_mover_state[3]
            gap = round(math.hypot(dx, dz))
            minimum_gap = min(minimum_gap, gap)
            if gap <= 5:
                break
            input_sequence = collision_mover.input(
                move_x=1000 if dx > 0 else -1000 if dx < 0 else 0,
                move_z=1000 if dz > 0 else -1000 if dz < 0 else 0)
            collision_scene = wait_for_input_ack(
                collision_mover, input_sequence)
            collision_mover_state = actor_record(
                collision_scene, collision_mover.player_id)
        collision_mover.input()
        assert 4 <= minimum_gap <= 5, (
            "swept player contact did not stop movement at capsule separation; "
            f"minimum_gap={minimum_gap}, mover={collision_mover_state}, "
            f"target={collision_target_state}")
        target_health = collision_target_state[4]
        desired_yaw = round(math.degrees(math.atan2(
            collision_target_state[1] - collision_mover_state[1],
            collision_target_state[3] - collision_mover_state[3],
        )))
        yaw_delta = (desired_yaw - collision_mover_state[7] + 180) % 360 - 180
        collision_mover.input(look_yaw=yaw_delta * 10, edge=64)
        _, melee_target = wait_for_actor(
            spectators[0], 8, 4, collision_target.player_id,
            lambda state, snapshot: state[4] < target_health)
        assert melee_target[4] < target_health, (
            "melee input did not damage the contacted player")

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

        departed = players[0]
        departed.close()
        clients.remove(departed)
        scene = replacements[0].snapshot(
            expected_players=7, expected_spectators=4)
        assert scene[17] == 7
        assert all(scene[18 + index * 8] != departed.player_id
                   for index in range(scene[17])), (
            f"disconnected player {departed.player_id} remained in actor snapshots")
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
        training = Client(port, role=3)
        clients.append(training)
        scene = training.snapshot(expected_players=1, expected_spectators=0)
        assert scene[5] == 3 and scene[17] == 5, (
            "training admission must replicate the player and four dolls")
        dolls = [scene[18 + index * 8:26 + index * 8]
                 for index in range(scene[17])
                 if scene[24 + index * 8] == 3]
        assert [doll[0] for doll in dolls] == [-1, -2, -3, -4]
        damage_confirmed = False
        for _ in range(240):
            player = actor_record(scene, training.player_id)
            living_dolls = [
                actor for actor in
                (scene[18 + index * 8:26 + index * 8]
                 for index in range(scene[17]))
                if actor[6] == 3 and actor[4] > 0
            ]
            assert living_dolls, "training dummies disappeared"
            target = min(
                living_dolls,
                key=lambda actor: abs(actor[1] - player[1]) +
                abs(actor[2] - player[2]) + abs(actor[3] - player[3]))
            distance = (abs(target[1] - player[1]) +
                        abs(target[2] - player[2]) +
                        abs(target[3] - player[3]))
            if distance <= 5:
                before = target[4]
                training.input(edge=64)
                for _ in range(8):
                    scene = training.snapshot(
                        expected_players=1, expected_spectators=0)
                    current = next(
                        actor for actor in
                        (scene[18 + index * 8:26 + index * 8]
                         for index in range(scene[17]))
                        if actor[0] == target[0])
                    trailer = 18 + scene[17] * 8
                    impact_count = scene[trailer + 3]
                    impacts = [
                        scene[trailer + 4 + index * 8:
                              trailer + 12 + index * 8]
                        for index in range(impact_count)
                    ]
                    if current[4] < before and any(
                            impact[1] == 2 and impact[3] == 0 and
                            impact[7] > 0 for impact in impacts):
                        damage_confirmed = True
                        break
                if damage_confirmed:
                    break
            else:
                move_x = max(-1000, min(1000, (target[1] - player[1]) * 500))
                move_z = max(-1000, min(1000, (target[3] - player[3]) * 500))
                training.input(move_x=move_x, move_z=move_z)
                scene = training.snapshot(
                    expected_players=1, expected_spectators=0)
        assert damage_confirmed, (
            "training melee must damage a doll and replicate a damage impact")
        training.close()
        clients.remove(training)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if health(port)["active_sessions"] == 0:
                break
            time.sleep(0.05)
        else:
            raise AssertionError("training disconnect did not clean up its dummies")

        abrupt = Client(port, role=3)
        clients.append(abrupt)
        abrupt.abort()
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            assert process.poll() is None, "server exited after abrupt TCP reset"
            if health(port)["active_sessions"] == 0:
                break
            time.sleep(0.05)
        else:
            raise AssertionError("abrupt TCP reset did not release its session")
        replacement = Client(port, role=3)
        clients.append(replacement)
        replacement.snapshot(expected_players=1, expected_spectators=0)
        assert process.poll() is None, "server exited before replacement session joined"
        replacement.close()
        clients.remove(replacement)
        clients.remove(abrupt)
        print("KOOKIE 8-player/4-spectator, training-dummy, and abrupt-disconnect qualification passed")
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
