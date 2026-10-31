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
from pathlib import Path

from verify_web_multiplayer import (
    Client, actor_record, health, throwable_suffix,
)
from kookie_websocket_session import GAME_MAXIMUM_HEALTH


ACTION_JUMP = 1
ACTION_ROLL = 2
ACTION_DASH = 4
ACTION_GLIDE = 8
ACTION_FLY = 16
ACTION_SHOOT = 32
EDGE_MELEE = 64
EDGE_SPECIAL = 128
ACTION_THROWABLE = 256
BOT_COUNT = 8
POWERUP_CONFIG_DIR = (
    Path(__file__).resolve().parents[1] /
    "assets" / "prototype" / "runtime" / "power_ups"
)


def load_powerup_waypoints():
    waypoints = []
    for config_path in sorted(POWERUP_CONFIG_DIR.glob("*.json")):
        with config_path.open(encoding="utf-8") as config_file:
            config = json.load(config_file)
        if not all(isinstance(config.get(key), int)
                   for key in ("kind", "x", "y", "z")):
            raise ValueError(f"invalid bot pickup config: {config_path}")
        waypoints.append({key: config[key] for key in ("kind", "x", "y", "z")})
    if not waypoints:
        raise RuntimeError(f"no bot pickup definitions in {POWERUP_CONFIG_DIR}")
    return waypoints


def bot_can_use_powerup(animal, kind):
    return (kind not in (3, 5) or animal == 1) and (kind != 6 or animal == 2)




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
    drivers = []
    battle_log = None
    stop = threading.Event()
    action_usage = set()
    actions_by_player = {}
    powerups_acquired = set()
    animation_states_by_player = {}
    observed_animation_states = set()
    driver_errors = []
    try:
        geese = [Client(port, path="/session/goose") for _ in range(4)]
        clients.extend(geese)
        cats = [Client(port, path="/session/cat") for _ in range(4)]
        clients.extend(cats)
        spectator = Client(port, spectator=True)
        clients.append(spectator)
        for client in geese + cats:
            client.snapshot(expected_players=BOT_COUNT)
        first_scene = spectator.snapshot(expected_players=BOT_COUNT)
        goose_ids = {client.player_id for client in geese}
        cat_ids = {client.player_id for client in cats}
        kinds = {first_scene[18 + index * 8]: first_scene[24 + index * 8]
                 for index in range(first_scene[17])}
        if any(kinds.get(player_id) != 1 for player_id in goose_ids):
            raise AssertionError("goose bot route did not spawn goose actors")
        if any(kinds.get(player_id) != 2 for player_id in cat_ids):
            raise AssertionError("cat bot route did not spawn cat actors")

        powerup_waypoints = load_powerup_waypoints()

        def drive(client, own_team):
            action_start = time.monotonic()
            next_shot = action_start + 1.5
            next_burst = 0.0
            next_melee = action_start + 1.5
            next_special = action_start + .7
            throwable_phase = 0
            throwable_charge_started = 0.0
            next_jump = 0.0
            double_jump_due = None
            burst_action = ACTION_DASH
            tried_pickups = {}
            animal = 1 if client.player_id in goose_ids else 2
            actions_by_player[client.player_id] = set()
            animation_states_by_player[client.player_id] = set()
            opening_roll = True
            while not stop.is_set():
                try:
                    scene = latest_snapshot(client)
                    me = actor_record(scene, client.player_id)
                    animation_state = me[5] // 128
                    animation_states_by_player[client.player_id].add(animation_state)
                    observed_animation_states.add(animation_state)
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
                        dx, dy, dz = (target[1] - me[1],
                                      target[2] - me[2],
                                      target[3] - me[3])
                        distance = max(1, math.hypot(dx, dz))
                        combat_distance = abs(dx) + abs(dy) + abs(dz)
                        desired_yaw = round(math.degrees(math.atan2(dx, dz)))
                        yaw_delta = (desired_yaw - me[7] + 180) % 360 - 180
                        now = time.monotonic()
                        active_powerup = (me[5] // 8) % 16
                        (pickup_active, pickup_x, pickup_y, pickup_z,
                         carrying, _) = throwable_suffix(scene)[:6]
                        move_dx, move_dz = dx, dz
                        if active_powerup == 0:
                            pickup = min(
                                ((abs(item["x"] - me[1]) +
                                  abs(item["y"] - me[2]) +
                                  abs(item["z"] - me[3]), index, item)
                                 for index, item in enumerate(powerup_waypoints)
                                 if bot_can_use_powerup(animal, item["kind"]) and
                                 now >= tried_pickups.get(index, 0)),
                                default=None,
                            )
                            if pickup is not None:
                                _, pickup_index, item = pickup
                                pickup_dx = item["x"] - me[1]
                                pickup_dz = item["z"] - me[3]
                                pickup_distance = math.hypot(pickup_dx, pickup_dz)
                                if (pickup_distance <= 4 and
                                        abs(item["y"] - me[2]) <= 5):
                                    tried_pickups[pickup_index] = now + 30
                                elif pickup_distance < distance * 1.4:
                                    move_dx, move_dz = pickup_dx, pickup_dz
                        if throwable_phase == 0 and pickup_active:
                            move_dx = pickup_x - me[1]
                            move_dz = pickup_z - me[3]
                        elif throwable_phase in (1, 2, 3):
                            move_dx = 0
                            move_dz = 0
                        move_distance = max(1, math.hypot(move_dx, move_dz))
                        move_x = round(move_dx * 1000 / move_distance)
                        move_z = round(move_dz * 1000 / move_distance)
                        if opening_roll:
                            client.input(
                                move_x=move_x, move_z=move_z,
                                edge=ACTION_ROLL | ACTION_DASH)
                            actions_by_player[client.player_id].update(
                                ("roll", "dash"))
                            action_usage.update(("roll", "dash"))
                            opening_roll = False
                            next_burst = now + .05
                            continue
                        held = 0
                        edge = 0
                        if combat_distance <= 120 and now >= next_shot:
                            held |= ACTION_SHOOT
                            next_shot = now + (0.6 if combat_distance <= 12 else 2.0)
                        if combat_distance <= 5 and now >= next_melee:
                            edge |= EDGE_MELEE
                            next_melee = now + 0.45
                        if now >= next_special:
                            edge |= EDGE_SPECIAL
                            next_special = now + (1.8 if active_powerup == 5 else 1.1)
                        if now >= next_burst:
                            edge |= burst_action
                            burst_action = (ACTION_ROLL if burst_action == ACTION_DASH
                                            else ACTION_DASH)
                            next_burst = now + .7 + (client.player_id % 4) * .05
                        grounded = (me[5] & 1) != 0
                        if double_jump_due is not None:
                            if not grounded:
                                edge |= ACTION_JUMP
                                actions_by_player[client.player_id].add(
                                    "double_jump")
                                action_usage.add("double_jump")
                                double_jump_due = None
                                next_jump = now + 1.6
                            elif now >= double_jump_due + .5:
                                double_jump_due = None
                                next_jump = now + .5
                        elif grounded and now >= next_jump:
                            edge |= ACTION_JUMP
                            double_jump_due = now + .1
                            next_jump = now + 1.6
                        if throwable_phase == 1:
                            throwable_phase = 2 if carrying else 0
                        elif throwable_phase == 2:
                            held |= ACTION_THROWABLE
                            throwable_phase = 3
                            throwable_charge_started = now
                        elif throwable_phase == 3:
                            if not carrying:
                                throwable_phase = 0
                            elif now - throwable_charge_started < .5:
                                held |= ACTION_THROWABLE
                            else:
                                throwable_phase = 4
                        elif throwable_phase == 4 and pickup_active:
                            throwable_phase = 0
                        if throwable_phase == 0 and pickup_active:
                            throwable_dx = pickup_x - me[1]
                            throwable_dz = pickup_z - me[3]
                            if (throwable_dx * throwable_dx +
                                    (pickup_y - me[2]) * (pickup_y - me[2]) +
                                    throwable_dz * throwable_dz <= 36):
                                held |= ACTION_THROWABLE
                                throwable_phase = 1
                        held |= ACTION_FLY if animal == 1 else ACTION_GLIDE
                        client.input(
                            move_x=move_x, move_z=move_z,
                            look_yaw=max(-1800, min(1800, yaw_delta * 10)),
                            look_pitch=max(-1800, min(1800, -dy * 10)),
                            held=held, edge=edge,
                        )
                        for bit, name in (
                            (ACTION_GLIDE, "glide"), (ACTION_FLY, "fly"),
                            (ACTION_SHOOT, "shoot"),
                            (ACTION_THROWABLE, "throwable"),
                        ):
                            if held & bit:
                                action_usage.add(name)
                                actions_by_player[client.player_id].add(name)
                        for bit, name in (
                            (ACTION_JUMP, "jump"), (ACTION_ROLL, "roll"),
                            (ACTION_DASH, "dash"), (EDGE_MELEE, "melee"),
                            (EDGE_SPECIAL, "special"),
                        ):
                            if edge & bit:
                                action_usage.add(name)
                                actions_by_player[client.player_id].add(name)
                        powerup_kind = (me[5] // 8) % 16
                        if powerup_kind:
                            powerups_acquired.add(powerup_kind)
                    stop.wait(.045)
                except Exception as error:
                    if not stop.is_set():
                        driver_errors.append(
                            f"bot {client.player_id}: {type(error).__name__}: {error}")
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
        minimum_health = BOT_COUNT * GAME_MAXIMUM_HEALTH
        minimum_alive = BOT_COUNT
        last_report = 0.0
        winner = None
        while not stop.is_set() and (duration is None or
                                     time.monotonic() - start < duration):
            scene = latest_snapshot(spectator)
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
            health_total = sum(max(0, scene[22 + index * 8])
                               for index in range(scene[17]))
            minimum_health = min(minimum_health, health_total)
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
        stop.set()
        for client in clients:
            client.close()
        for thread in drivers:
            thread.join()
        if duration is not None:
            if driver_errors:
                raise RuntimeError("bot driver failed: " + "; ".join(driver_errors))

            if samples == 0:
                raise AssertionError("bot positions did not change during smoke run")
            if minimum_health == BOT_COUNT * GAME_MAXIMUM_HEALTH:
                raise AssertionError("teams did not exchange authoritative damage")
            if not powerups_acquired:
                raise AssertionError("bots did not acquire an authoritative powerup")
            for player_id in goose_ids | cat_ids:
                expected_actions = {
                    "jump", "double_jump", "roll", "dash", "shoot", "special",
                }
                missing = expected_actions - actions_by_player.get(player_id, set())
                if missing:
                    raise AssertionError(
                        f"bot {player_id} did not use actions: {', '.join(sorted(missing))}"
                    )
            if "melee" not in action_usage:
                raise AssertionError("battle bots did not use melee in range")
            required_animation_states = {2, 6, 7}
            missing_animation_states = required_animation_states - observed_animation_states
            if missing_animation_states:
                raise AssertionError(
                    "bot snapshots missed animation states: " +
                    ", ".join(map(str, sorted(missing_animation_states)))
                )
            per_bot = "; ".join(
                f"{player_id}:{','.join(sorted(actions)) or 'none'}"
                f"/anim={','.join(map(str, sorted(animation_states_by_player[player_id])))}"
                for player_id, actions in sorted(actions_by_player.items())
            )
            print(f"/b2teams4 smoke passed: {samples} moving snapshots; "
                  f"minimum alive={minimum_alive}/8; "
                  f"min health={minimum_health}/{BOT_COUNT * GAME_MAXIMUM_HEALTH}; "
                  f"actions={','.join(sorted(action_usage)) or 'none'}; "
                  f"animation states={','.join(map(str, sorted(observed_animation_states)))}; "
                  f"powerup kinds={','.join(map(str, sorted(powerups_acquired)))}; "
                  f"per-bot={per_bot}")
        else:
            print(f"Battle finished: {winner} win." if winner else
                  "Battle timer elapsed.")
    finally:
        stop.set()
        if battle_log is not None:
            battle_log.close()
        for client in clients:
            client.close()
        for thread in drivers:
            thread.join()


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
    library_dir = os.path.join(os.path.dirname(binary), "lib")
    library_path = os.environ.get("LD_LIBRARY_PATH", "")
    if library_path:
        library_dir += os.pathsep + library_path
    env = dict(os.environ, KOOKIE_WEB_PORT=str(port),
               LD_LIBRARY_PATH=library_dir)
    process = subprocess.Popen(
        [binary], cwd=os.path.dirname(binary), env=env,
        stdout=sys.stderr if smoke else subprocess.DEVNULL,
        stderr=sys.stderr if smoke else subprocess.PIPE,
    )
    try:
        wait_healthy(port, process)
        if smoke:
            run_battle(port, duration=12, log_path=log_path)
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
