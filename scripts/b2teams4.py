#!/usr/bin/env python3
"""Run an interactive 4v4 goose-vs-cat bot battle against a local KOOKIE server."""
import math
import os
import queue
import socket
import subprocess
import json
import sys
import threading
import time
import urllib.error

from verify_web_multiplayer import Client, actor_record, health


HELD_FIRE = 32
BOT_COUNT = 8


def wait_healthy(port, process):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("KOOKIE server exited during startup")
        try:
            if health(port)["status"] == "ok":
                return
        except (OSError, ValueError, urllib.error.URLError):
            time.sleep(.05)
    raise TimeoutError("KOOKIE web server did not become healthy")

def latest_snapshot(client, expected_spectators=None):
    scene = client.snapshot(expected_players=BOT_COUNT,
                            expected_spectators=expected_spectators)
    while True:
        try:
            candidate = client.inbox.get_nowait()
        except queue.Empty:
            return scene
        if isinstance(candidate, BaseException):
            raise candidate
        if len(candidate) >= 19 and candidate[3] == 7 and \
                candidate[15] == BOT_COUNT:
            scene = candidate


def run_battle(port, duration=None, log_path=None):
    clients = []
    battle_log = None
    stop = threading.Event()
    try:
        geese = [Client(port, path="/session/goose") for _ in range(4)]
        clients.extend(geese)
        cats = [Client(port, path="/session/cat") for _ in range(4)]
        clients.extend(cats)
        spectator = Client(port, spectator=True)
        clients.append(spectator)
        for client in geese + cats:
            client.snapshot(expected_players=BOT_COUNT)
        first_scene = spectator.snapshot(expected_players=BOT_COUNT,
                                         expected_spectators=1)
        goose_ids = {client.player_id for client in geese}
        cat_ids = {client.player_id for client in cats}
        kinds = {first_scene[18 + index * 8]: first_scene[24 + index * 8]
                 for index in range(first_scene[17])}
        if any(kinds.get(player_id) != 1 for player_id in goose_ids):
            raise AssertionError("goose bot route did not spawn goose actors")
        if any(kinds.get(player_id) != 2 for player_id in cat_ids):
            raise AssertionError("cat bot route did not spawn cat actors")

        def drive(client, own_team):
            next_shot = time.monotonic()
            next_burst = next_shot + 1.8
            next_melee = next_shot
            next_special = next_shot + 4.0
            while not stop.is_set():
                try:
                    scene = latest_snapshot(client)
                    me = actor_record(scene, client.player_id)
                    enemies = [scene[18 + index * 8:26 + index * 8]
                               for index in range(scene[17])
                               if scene[18 + index * 8] not in own_team and
                               scene[22 + index * 8] > 0]
                    if not enemies or me[4] <= 0:
                        client.input()
                    else:
                        target = min(enemies, key=lambda actor:
                                     abs(actor[1] - me[1]) +
                                     abs(actor[2] - me[2]) +
                                     abs(actor[3] - me[3]))
                        dx, dz = target[1] - me[1], target[3] - me[3]
                        distance = max(1, math.hypot(dx, dz))
                        desired_yaw = round(math.degrees(math.atan2(dx, dz)))
                        yaw_delta = (desired_yaw - me[7] + 180) % 360 - 180
                        move_x = round(dx * 1000 / distance)
                        move_z = round(dz * 1000 / distance)
                        now = time.monotonic()
                        held = HELD_FIRE if now >= next_shot else 0
                        edge = 0
                        if now >= next_shot:
                            next_shot = now + 1.5
                        if now >= next_burst:
                            edge = (1, 2, 4)[int(now / 1.8) % 3]
                            next_burst = now + 1.8
                        if distance <= 5 and now >= next_melee:
                            edge |= 64
                            next_melee = now + 0.6
                        if now >= next_special:
                            edge |= 128 if int(now) % 2 == 0 else 256
                            next_special = now + 4.0
                        if client.player_id in goose_ids and int(now) % 6 == 0:
                            held |= 16
                        elif int(now) % 6 == 0:
                            held |= 8
                        client.input(move_x=move_x, move_z=move_z,
                                     look_yaw=max(-1800, min(1800, yaw_delta * 10)),
                                     held=held, edge=edge)
                    stop.wait(.045)
                except (OSError, EOFError, TimeoutError):
                    stop.set()
        goose_team = set(goose_ids)
        cat_team = set(cat_ids)
        drivers = [threading.Thread(target=drive, args=(client, goose_team),
                                    daemon=True) for client in geese]
        drivers.extend(threading.Thread(target=drive, args=(client, cat_team),
                                        daemon=True) for client in cats)
        for thread in drivers:
            thread.start()

        print("/b2teams4 LIVE: 4 geese (red) vs 4 cats (blue); server-authoritative combat")
        print(f"Spectator WebSocket: ws://127.0.0.1:{port}/spectate")
        print("Open the web client, select Spectator, set its server URL, and connect.")
        start = time.monotonic()
        battle_log = open(log_path, "w", encoding="utf-8") if log_path else None
        last_logged_tick = -1
        previous_positions = None
        samples = 0
        minimum_alive = BOT_COUNT
        last_report = 0.0
        winner = None
        while not stop.is_set() and (duration is None or
                                     time.monotonic() - start < duration):
            scene = latest_snapshot(spectator, expected_spectators=1)
            positions = [tuple(scene[19 + index * 8:22 + index * 8])
                         for index in range(scene[17])]
            if previous_positions is not None and positions != previous_positions:
                samples += 1
            previous_positions = positions
            if battle_log is not None and scene[4] > last_logged_tick:
                players = []
                for index in range(scene[17]):
                    offset = 18 + index * 8
                    player_id = scene[offset]
                    players.append({
                        "id": player_id,
                        "team": "red" if player_id in goose_ids else "blue",
                        "health": max(0, scene[offset + 4]),
                        "x": scene[offset + 1],
                        "y": scene[offset + 2],
                        "z": scene[offset + 3],
                    })
                battle_log.write(json.dumps({
                    "schema": "kookie-battle-v1", "type": "snapshot",
                    "tick": scene[4], "players": players,
                }, separators=(",", ":")) + "\n")
                battle_log.flush()
                last_logged_tick = scene[4]
            alive = sum(scene[22 + index * 8] > 0
                        for index in range(scene[17]))
            minimum_alive = min(minimum_alive, alive)
            goose_alive = sum(scene[22 + index * 8] > 0
                              for index in range(scene[17])
                              if scene[18 + index * 8] in goose_ids)
            cat_alive = alive - goose_alive
            if goose_alive == 0:
                winner = "blue cats"
            elif cat_alive == 0:
                winner = "red geese"
            if winner is not None:
                print(f"Round complete: {winner} win.")
                break
            now = time.monotonic()
            if now - last_report >= .8:
                print(f"tick={scene[4]} alive={alive}/8 moving-snapshots={samples}",
                      flush=True)
                last_report = now
            stop.wait(.05)
        if duration is not None:
            if samples == 0:
                raise AssertionError("bot positions did not change during smoke run")
            if minimum_alive == BOT_COUNT:
                raise AssertionError("teams did not exchange damage during smoke run")
            print(f"/b2teams4 smoke passed: {samples} moving snapshots; "
                  f"minimum alive={minimum_alive}/8")
        else:
            print(f"Battle finished: {winner} win." if winner else
                  "Battle timer elapsed.")
        stop.set()
    finally:
        stop.set()
        if battle_log is not None:
            battle_log.close()
        for client in clients:
            client.close()


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: scripts/b2teams4.py SERVER_BINARY PORT [--smoke] [--log PATH]")
    binary = os.path.abspath(sys.argv[1])
    if "--log" in sys.argv:
        log_index = sys.argv.index("--log")
        if log_index + 1 >= len(sys.argv):
            raise SystemExit("--log requires a path")
        log_path = sys.argv[log_index + 1]
        del sys.argv[log_index:log_index + 2]
    else:
        log_path = None
    port = int(sys.argv[2])
    if port == 0:
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
    smoke = "--smoke" in sys.argv[3:]
    if any(option != "--smoke" for option in sys.argv[3:]):
        raise SystemExit("usage: scripts/b2teams4.py SERVER_BINARY PORT [--smoke] [--log PATH]")
    env = dict(os.environ, KOOKIE_WEB_PORT=str(port))
    process = subprocess.Popen([binary], cwd=os.path.dirname(binary), env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        wait_healthy(port, process)
        if smoke:
            run_battle(port, duration=4, log_path=log_path)
            return
        print("KOOKIE server ready. Type /b2teams4 to launch the 4v4 battle; /quit exits.")
        while True:
            try:
                command = input("kookie> ").strip()
            except (EOFError, KeyboardInterrupt):
                break
            if command in ("/quit", "/exit"):
                break
            if command == "/b2teams4":
                try:
                    run_battle(port, duration=120, log_path=log_path)
                except KeyboardInterrupt:
                    print("\nBattle stopped.")
            elif command:
                print("Unknown command. Available: /b2teams4, /quit")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    main()
