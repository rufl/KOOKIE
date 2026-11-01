#!/usr/bin/env python3
"""Measure loopback cadence, input ACKs, and server timing distributions.

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
import urllib.request


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
    library_dir = os.path.join(os.path.dirname(binary), "lib")
    library_path = os.environ.get("LD_LIBRARY_PATH", "")
    if library_path:
        library_dir += os.pathsep + library_path
    env = dict(os.environ, KOOKIE_WEB_PORT=port_text,
               LD_LIBRARY_PATH=library_dir)
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
        # The server has 12 connection slots; release a spectator to scrape
        # metrics after measuring the full 8-player/4-spectator workload.
        spectators[-1].close()
        clients.remove(spectators[-1])
        metrics_deadline = time.monotonic() + 3
        while True:
            try:
                with urllib.request.urlopen(
                        f"http://127.0.0.1:{port}/metrics", timeout=2) as response:
                    metric_lines = response.read().decode("ascii").splitlines()
                break
            except (OSError, urllib.error.URLError):
                if time.monotonic() >= metrics_deadline:
                    raise
                time.sleep(.05)
        server_metrics = {
            fields[0]: int(fields[1])
            for line in metric_lines if line and not line.startswith("#")
            if len(fields := line.split()) == 2
        }
        timing_metrics = (
            "kookie_gateway_tick_work_max_nanoseconds",
            "kookie_gateway_snapshot_build_max_nanoseconds",
            "kookie_gateway_snapshot_send_max_nanoseconds",
            "kookie_gateway_tick_lateness_max_nanoseconds",
            "kookie_gateway_map_teardown_max_nanoseconds",
            "kookie_gateway_map_selection_max_nanoseconds",
            "kookie_gateway_map_configure_max_nanoseconds",
            "kookie_gateway_map_player_restore_max_nanoseconds",
            "kookie_gateway_tick_schedule_overruns_total",
        )
        histogram_names = (
            "kookie_gateway_tick_work_nanoseconds",
            "kookie_gateway_tick_lateness_nanoseconds",
            "kookie_gateway_simulation_work_nanoseconds",
            "kookie_gateway_snapshot_build_work_nanoseconds",
            "kookie_gateway_snapshot_send_work_nanoseconds",
        )
        slowest_tick_metrics = (
            "kookie_gateway_slowest_tick_number",
            "kookie_gateway_slowest_tick_lateness_nanoseconds",
            "kookie_gateway_slowest_tick_simulation_nanoseconds",
            "kookie_gateway_slowest_tick_snapshot_build_nanoseconds",
            "kookie_gateway_slowest_tick_snapshot_send_nanoseconds",
            "kookie_gateway_slowest_tick_simulation_construction_nanoseconds",
            "kookie_gateway_slowest_tick_input_application_nanoseconds",
            "kookie_gateway_slowest_tick_advance_nanoseconds",
            "kookie_gateway_slowest_tick_map_teardown_nanoseconds",
            "kookie_gateway_slowest_tick_map_selection_nanoseconds",
            "kookie_gateway_slowest_tick_map_configure_nanoseconds",
            "kookie_gateway_slowest_tick_map_player_restore_nanoseconds",
        )
        if any(name not in server_metrics for name in
               timing_metrics + slowest_tick_metrics):
            raise RuntimeError("server timing metrics are missing")
        bucket_bounds_ns = (
            1_000_000, 2_000_000, 4_000_000, 8_000_000, 16_000_000,
            20_000_000, 33_000_000, 50_000_000, 100_000_000,
            500_000_000, "+Inf",
        )
        for name in histogram_names:
            if name + "_count" not in server_metrics:
                raise RuntimeError(f"server timing histogram is missing: {name}")

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
        print("Server timing histograms (cumulative buckets):")
        for name in histogram_names:
            count = server_metrics[name + "_count"]
            total_ms = server_metrics[name + "_sum"] / 1_000_000
            buckets = [
                server_metrics[
                    f'{name}_bucket{{le="{bound}"}}'
                ]
                for bound in bucket_bounds_ns
            ]
            bucket_text = ", ".join(
                f'{"+Inf" if bound == "+Inf" else "≤" + str(bound // 1_000_000) + "ms"}:'
                f"{value}"
                for bound, value in zip(bucket_bounds_ns, buckets)
            )
            if (buckets[-1] != count or
                    any(left > right for left, right in
                        zip(buckets, buckets[1:]))):
                raise RuntimeError(
                    f"invalid server timing histogram: {name}")
            mean_ms = total_ms / count if count else 0.0
            print(f"  {name}: n={count} mean={mean_ms:.3f}ms; {bucket_text}")
        print("Slowest tick breakdown (tick work includes all phases):")
        print("  tick={}; lateness={:.3f}ms; simulation={:.3f}ms; "
              "snapshot_build={:.3f}ms; snapshot_send={:.3f}ms; "
              "sim_construct={:.3f}ms; input_apply={:.3f}ms; "
              "advance={:.3f}ms; map_teardown={:.3f}ms; "
              "map_selection={:.3f}ms; map_configure={:.3f}ms; "
              "player_restore={:.3f}ms".format(
                  server_metrics[slowest_tick_metrics[0]],
                  server_metrics[slowest_tick_metrics[1]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[2]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[3]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[4]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[5]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[6]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[7]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[8]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[9]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[10]] / 1_000_000,
                  server_metrics[slowest_tick_metrics[11]] / 1_000_000,
              ))
        print("Server maximum durations:")
        for name in timing_metrics[:-1]:
            print(f"  {name}: {server_metrics[name] / 1_000_000:.3f}ms")
        print("  kookie_gateway_tick_schedule_overruns_total: " +
              str(server_metrics["kookie_gateway_tick_schedule_overruns_total"]))
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
