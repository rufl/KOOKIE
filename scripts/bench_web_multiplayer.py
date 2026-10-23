#!/usr/bin/env python3
"""Measure loopback snapshot cadence and input-to-ACK latency.

This is a local WebSocket/TCP benchmark, not a WAN or browser-render benchmark.
"""
import importlib.util
import math
import os
import socket
import subprocess
import sys
import time
import urllib.error


CLIENT_MODULE_PATH = os.path.join(os.path.dirname(__file__), "verify_web_multiplayer.py")
spec = importlib.util.spec_from_file_location("verify_web_multiplayer", CLIENT_MODULE_PATH)
client_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(client_module)
Client = client_module.Client
health = client_module.health


def percentile(values, fraction):
    if not values:
        return float("nan")
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, math.ceil(fraction * len(ordered)) - 1)]


def main():
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        raise SystemExit("usage: bench_web_multiplayer.py SERVER_BINARY PORT [SECONDS]")
    binary = os.path.abspath(sys.argv[1])
    port_text = sys.argv[2]
    duration = float(sys.argv[3]) if len(sys.argv) == 4 else 8.0
    if duration < 2.0 or duration > 60.0:
        raise SystemExit("duration must be between 2 and 60 seconds")
    port = int(port_text)
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", port))
        if port == 0:
            port = probe.getsockname()[1]
            port_text = str(port)
    env = dict(os.environ, KOOKIE_WEB_PORT=port_text)
    process = subprocess.Popen([binary], cwd=os.path.dirname(binary), env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    clients = []
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError("server exited before benchmark: " +
                                   process.stderr.read().decode(errors="replace"))
            try:
                if health(port)["status"] == "ok":
                    break
            except (OSError, ValueError, urllib.error.URLError):
                time.sleep(0.05)
        else:
            raise TimeoutError("server did not become healthy")

        players = []
        for _ in range(8):
            players.append(Client(port))
            clients.append(players[-1])
        spectators = []
        for _ in range(4):
            spectators.append(Client(port, spectator=True))
            clients.append(spectators[-1])
        mover = players[0]
        spectators[0].snapshot(expected_players=8, expected_spectators=4)
        mover.snapshot(expected_players=8, expected_spectators=4)

        intervals_ms = []
        tick_gaps = []
        input_ack_ms = []
        previous_at = None
        previous_tick = None
        next_input_at = time.monotonic()
        pending_sequence = None
        pending_sent_at = None
        end_at = time.monotonic() + duration
        while time.monotonic() < end_at:
            now = time.monotonic()
            if pending_sequence is None and now >= next_input_at:
                pending_sequence = mover.input(
                    move_x=700 if len(input_ack_ms) % 2 == 0 else -700)
                pending_sent_at = now
                next_input_at = now + 0.1
            scene = mover.snapshot(expected_players=8, expected_spectators=4)
            arrived_at = time.monotonic()
            if previous_at is not None:
                intervals_ms.append((arrived_at - previous_at) * 1000)
                tick_gaps.append(scene[4] - previous_tick)
            previous_at, previous_tick = arrived_at, scene[4]
            trailer = 18 + scene[17] * 8
            if pending_sequence is not None and scene[trailer] >= pending_sequence:
                input_ack_ms.append((arrived_at - pending_sent_at) * 1000)
                pending_sequence = None

        def report(label, values):
            print(f"{label}: n={len(values)} p50={percentile(values, .50):.2f}ms "
                  f"p95={percentile(values, .95):.2f}ms "
                  f"max={max(values, default=float('nan')):.2f}ms")

        print("KOOKIE loopback benchmark (8 players, 4 spectators)")
        report("snapshot inter-arrival", intervals_ms)
        report("input-to-authoritative-ACK", input_ack_ms)
        if tick_gaps:
            print(f"snapshot tick gap: p50={percentile(tick_gaps, .50):.0f} "
                  f"p95={percentile(tick_gaps, .95):.0f} max={max(tick_gaps)}")
        print("Transport: local WebSocket/TCP; excludes browser rendering and WAN conditions.")
        if len(input_ack_ms) < max(5, int(duration * 3)):
            raise RuntimeError(f"too few acknowledged input samples: {len(input_ack_ms)}")
        if max(tick_gaps, default=0) > 6:
            raise RuntimeError(f"snapshot stream stalled: maximum tick gap {max(tick_gaps)}")
    finally:
        for client in clients:
            client.close()
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    main()
