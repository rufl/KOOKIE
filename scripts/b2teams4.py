#!/usr/bin/env python3
"""Run a spectator-visible, server-authoritative goose-vs-cat bot battle."""
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
    Client, actor_record, health, projectile_records, throwable_suffix,
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

def latest_snapshot(client, expected_players=BOT_COUNT, expected_spectators=None):
    scene = client.snapshot(expected_players=expected_players,
                            expected_spectators=expected_spectators)
    while True:
        try:
            candidate = client.inbox.get_nowait()
        except queue.Empty:
            return scene
        if isinstance(candidate, BaseException):
            raise candidate
        if len(candidate) >= 19 and candidate[3] == 7 and \
                candidate[15] == expected_players:
            scene = candidate



def run_battle(port, duration=None, log_path=None,
               goose_count=4, cat_count=4, wait_for_spectator=False,
               spectator_url=None, ringout_only_deaths=False):
    bot_count = goose_count + cat_count
    if goose_count <= 0 or cat_count <= 0 or bot_count > 8:
        raise ValueError("team sizes must be positive and total at most 8")
    clients = []
    drivers = []
    battle_log = None
    stop = threading.Event()
    clients_lock = threading.Lock()
    roster_lock = threading.Lock()
    action_usage = set()
    actions_by_player = {}
    powerups_acquired = set()
    animation_states_by_player = {}
    observed_animation_states = set()
    driver_errors = []
    melee_range_observed = [False]
    throwable_launch_observed = [False]
    throwable_pickup_observed = [False]
    throwable_carry_observed = [False]
    try:
        if wait_for_spectator:
            url = spectator_url or f"ws://127.0.0.1:{port}/spectate"
            print(f"Spectator WebSocket: {url}", flush=True)
            print("Waiting for browser spectator before spawning bots.",
                  flush=True)
            readiness_client = Client(port, spectator=True)
            clients.append(readiness_client)
            while True:
                try:
                    readiness_client.snapshot(
                        expected_players=0, expected_spectators=2)
                    break
                except AssertionError:
                    print("Still waiting for browser spectator.", flush=True)
            readiness_client.close()
            clients.remove(readiness_client)

        geese = [Client(port, path="/session/goose")
                 for _ in range(goose_count)]
        clients.extend(geese)
        cats = [Client(port, path="/session/cat") for _ in range(cat_count)]
        clients.extend(cats)
        spectator = Client(port, spectator=True)
        clients.append(spectator)
        for client in geese + cats:
            client.snapshot(expected_players=bot_count)
        first_scene = spectator.snapshot(expected_players=bot_count)
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
            tried_pickups = {}
            burst_action = ACTION_DASH
            animal = 1 if client.player_id in goose_ids else 2
            actions_by_player[client.player_id] = set()
            animation_states_by_player[client.player_id] = set()
            opening_roll = True
            while not stop.is_set():
                try:
                    scene = latest_snapshot(client, bot_count)
                    me = actor_record(scene, client.player_id)
                    if me[4] <= 0:
                        stop.wait(.045)
                        continue
                    animation_state = me[5] // 128
                    animation_states_by_player[client.player_id].add(animation_state)
                    observed_animation_states.add(animation_state)
                    with roster_lock:
                        own_ids = set(own_team)
                    enemies = [scene[18 + index * 8:26 + index * 8]
                               for index in range(scene[17])
                               if scene[18 + index * 8] not in own_ids and
                               scene[22 + index * 8] > 0]
                    if not enemies:
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
                        throwable_state = throwable_suffix(scene)
                        pickup_active, pickup_x, pickup_y, pickup_z = \
                            throwable_state[:4]
                        carrying = len(throwable_state) > 5 and \
                            throwable_state[5] == 1
                        if pickup_active:
                            throwable_pickup_observed[0] = True
                        if carrying:
                            throwable_carry_observed[0] = True
                        move_dx, move_dz = dx, dz
                        if active_powerup == 0:
                            pickup = min(
                                ((math.dist((item["x"], item["y"], item["z"]),
                                            (me[1], me[2], me[3])),
                                  index, item)
                                 for index, item in enumerate(powerup_waypoints)
                                 if bot_can_use_powerup(animal, item["kind"]) and
                                 now >= tried_pickups.get(index, 0)),
                                default=None,
                            )
                            if pickup is not None:
                                pickup_distance, pickup_index, item = pickup
                                pickup_dx = item["x"] - me[1]
                                pickup_dz = item["z"] - me[3]
                                if pickup_distance <= 4 and abs(item["y"] - me[2]) <= 5:
                                    tried_pickups[pickup_index] = now + 30
                                elif pickup_distance < distance * 1.35:
                                    move_dx, move_dz = pickup_dx, pickup_dz
                        dodging = False
                        for projectile in projectile_records(scene):
                            if projectile[2] != client.player_id:
                                continue
                            px, py, pz = projectile[3], projectile[4], projectile[5]
                            if math.dist((px, py, pz),
                                         (me[1], me[2], me[3])) <= 30:
                                move_dx, move_dz = pz - me[3], me[1] - px
                                dodging = True
                                break
                        if not dodging and distance <= 24:
                            if distance < 11:
                                move_dx, move_dz = -dx, -dz
                            else:
                                side = -1 if client.player_id % 2 else 1
                                move_dx, move_dz = -dz * side, dx * side
                        if pickup_active and throwable_phase == 0 and distance > 10:
                            move_dx, move_dz = pickup_x - me[1], pickup_z - me[3]
                        if throwable_phase in (1, 2, 3):
                            move_dx = move_dz = 0
                        move_dx += (16 - me[1]) * 1.2 if me[1] < 16 else \
                            (304 - me[1]) * 1.2 if me[1] > 304 else 0
                        move_dz += (16 - me[3]) * 1.2 if me[3] < 16 else \
                            (264 - me[3]) * 1.2 if me[3] > 264 else 0
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
                        edge = ACTION_ROLL if dodging else 0
                        attacks_allowed = (
                            not ringout_only_deaths or target[4] > 200
                        )
                        if attacks_allowed and combat_distance <= 5:
                            melee_range_observed[0] = True
                        if attacks_allowed and combat_distance <= 120 and now >= next_shot:
                            held |= ACTION_SHOOT
                            next_shot = now + (0.6 if combat_distance <= 12 else 2.0)
                        if attacks_allowed and combat_distance <= 5 and now >= next_melee:
                            edge |= EDGE_MELEE
                            next_melee = now + .45
                        if (attacks_allowed and now >= next_special and
                                (combat_distance <= 80 or active_powerup in (3, 8))):
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
                        if ringout_only_deaths:
                            throwable_phase = 0
                        elif throwable_phase == 1:
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
                        elif throwable_phase == 4 and not carrying:
                            throwable_phase = 0
                        if not ringout_only_deaths and throwable_phase == 0 and pickup_active:
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

        print(f"/b2teams4 LIVE: {goose_count} geese (red) vs "
              f"{cat_count} cats (blue); server-authoritative combat")
        print(f"Spectator WebSocket: ws://127.0.0.1:{port}/spectate")
        print("Open the web client, select Spectator, set its server URL, and connect.")
        print("Eliminated bots respawn together on authoritative server waves; "
              "their player ID, species, and team are preserved.", flush=True)
        start = time.monotonic()
        if log_path:
            Path(log_path).parent.mkdir(parents=True, exist_ok=True)
        battle_log = open(log_path, "w", encoding="utf-8") if log_path else None
        last_logged_tick = -1
        previous_positions = None
        samples = 0
        minimum_health = bot_count * GAME_MAXIMUM_HEALTH
        minimum_alive = bot_count
        last_report = 0.0
        while not stop.is_set() and (duration is None or
                                     time.monotonic() - start < duration):
            scene = latest_snapshot(spectator, bot_count)
            positions = [tuple(scene[19 + index * 8:22 + index * 8])
                         for index in range(scene[17])]
            trailer = 18 + scene[17] * 8
            if scene[trailer + 2] > 0:
                throwable_launch_observed[0] = True
            if previous_positions is not None and positions != previous_positions:
                samples += 1
            previous_positions = positions
            if battle_log is not None and scene[4] > last_logged_tick:
                with roster_lock:
                    red_ids = set(goose_ids)
                players = []
                for index in range(scene[17]):
                    offset = 18 + index * 8
                    player_id = scene[offset]
                    players.append({
                        "id": player_id,
                        "team": "red" if player_id in red_ids else "blue",
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
            # A zero-alive team is temporary: eliminated bots respawn on
            # authoritative waves. Keep spectating until the requested timer.
            now = time.monotonic()
            if now - last_report >= .8:
                print(f"tick={scene[4]} alive={alive}/{bot_count} "
                      f"moving-snapshots={samples}",
                      flush=True)
                last_report = now
            stop.wait(.05)
        stop.set()
        with clients_lock:
            active_clients = tuple(clients)
        for client in active_clients:
            client.close()
        for thread in drivers:
            thread.join()
        if driver_errors:
            raise RuntimeError("bot driver failed: " + "; ".join(driver_errors))
        if duration is not None:

            if samples == 0:
                raise AssertionError("bot positions did not change during smoke run")
            if minimum_health == bot_count * GAME_MAXIMUM_HEALTH:
                raise AssertionError("teams did not exchange authoritative damage")
            if not ringout_only_deaths and not throwable_launch_observed[0]:
                raise AssertionError(
                    "bots never launched a throwable "
                    f"(pickup={throwable_pickup_observed[0]}, "
                    f"carried={throwable_carry_observed[0]})"
                )
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
            if melee_range_observed[0] and "melee" not in action_usage:
                raise AssertionError(
                    "battle bots entered melee range but did not use melee"
                )
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
            print(f"/b2teams4 checks passed: {samples} moving snapshots; "
                  f"minimum alive={minimum_alive}/{bot_count}; "
                  f"min health={minimum_health}/{bot_count * GAME_MAXIMUM_HEALTH}; "
                  f"actions={','.join(sorted(action_usage)) or 'none'}; "
                  f"animation states={','.join(map(str, sorted(observed_animation_states)))}; "
                  f"powerup kinds={','.join(map(str, sorted(powerups_acquired)))}; "
                  f"per-bot={per_bot}")
        else:
            print("Battle stopped.")
    finally:
        stop.set()
        if battle_log is not None:
            battle_log.close()
        for client in clients:
            client.close()
        for thread in drivers:
            thread.join()


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Run an authoritative goose-vs-cat battle with a spectator.")
    parser.add_argument("server_binary")
    parser.add_argument("port", type=int)
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--run", action="store_true",
                        help="start the battle immediately instead of prompting")
    parser.add_argument("--geese", type=int, default=4)
    parser.add_argument("--cats", type=int, default=4)
    parser.add_argument("--duration", type=float, default=120,
                        help="battle seconds; 0 enables endless bot respawns")
    parser.add_argument("--log", type=Path,
                        help="write per-tick kookie-battle-v1 JSONL snapshots")
    parser.add_argument("--server-log", type=Path,
                        help="persist server stdout/stderr separately")
    parser.add_argument("--wait-for-spectator", action="store_true",
                        help="wait until a browser spectator joins before spawning bots")
    parser.add_argument("--ringout-only-deaths", action="store_true",
                        help="bots stop damaging opponents below 200 health; ringouts still kill")
    parser.add_argument("--keep-server", action="store_true",
                        help="keep the server running after a --run battle")
    args = parser.parse_args()
    if args.geese <= 0 or args.cats <= 0 or args.geese + args.cats > 8:
        parser.error("team sizes must be positive and total at most 8")
    if args.duration < 0:
        parser.error("--duration must be non-negative (0 disables the timer)")
    if args.smoke and args.run:
        parser.error("--smoke and --run cannot be combined")

    binary = os.path.abspath(args.server_binary)
    port = args.port
    if port == 0:
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
    library_dir = os.path.join(os.path.dirname(binary), "lib")
    library_path = os.environ.get("LD_LIBRARY_PATH", "")
    if library_path:
        library_dir += os.pathsep + library_path
    env = dict(os.environ, KOOKIE_WEB_PORT=str(port),
               LD_LIBRARY_PATH=library_dir)

    server_log = None
    if args.server_log:
        args.server_log.parent.mkdir(parents=True, exist_ok=True)
        server_log = args.server_log.open("w", encoding="utf-8")
    process = subprocess.Popen(
        [binary], cwd=os.path.dirname(binary), env=env,
        stdout=(server_log if server_log else
                (sys.stderr if args.smoke else subprocess.DEVNULL)),
        stderr=(subprocess.STDOUT if server_log else
                (sys.stderr if args.smoke else subprocess.PIPE)),
    )
    try:
        wait_healthy(port, process)
        if args.smoke or args.run:
            run_battle(
                port,
                duration=(12 if args.smoke else
                          (args.duration or None)),
                log_path=args.log,
                goose_count=args.geese,
                cat_count=args.cats,
                wait_for_spectator=args.wait_for_spectator,
                ringout_only_deaths=args.ringout_only_deaths,
            )
            if args.keep_server and args.run and not args.smoke:
                print("Match complete; server remains available until Ctrl-C.",
                      flush=True)
                try:
                    while True:
                        time.sleep(3600)
                except KeyboardInterrupt:
                    pass
            return
        print(f"KOOKIE server ready. Type /b2teams4 to launch "
              f"{args.geese}v{args.cats}; /quit exits.")
        while True:
            try:
                command = input("kookie> ").strip()
            except (EOFError, KeyboardInterrupt):
                break
            if command in ("/quit", "/exit"):
                break
            if command == "/b2teams4":
                try:
                    run_battle(
                        port, duration=(args.duration or None),
                        log_path=args.log, goose_count=args.geese,
                        cat_count=args.cats,
                        wait_for_spectator=args.wait_for_spectator,
                        ringout_only_deaths=args.ringout_only_deaths)
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
        if server_log:
            server_log.close()

if __name__ == "__main__":
    main()
