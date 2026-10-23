#!/usr/bin/env python3
"""Heuristically detect growing team advantage in a 4v4 battle log.

Strength per team is alive-player count plus remaining health divided by 100.
The normalized share is team strength / combined team strength. This is a
heuristic description of observed advantage, not evidence of causation.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import TextIO

SCHEMA = "kookie-battle-v1"
FORMULA = (
    "team_strength = alive_player_count + sum(health / 100 for all team players); "
    "team_share = team_strength / (red_strength + blue_strength)"
)


class BattleLogError(ValueError):
    """Invalid or insufficient battle log input."""


def _positive_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def parse_log(stream: TextIO) -> list[dict[str, object]]:
    samples: list[dict[str, object]] = []
    previous_tick: int | None = None
    expected_players: dict[int, str] | None = None
    for line_number, raw_line in enumerate(stream, 1):
        if not raw_line.strip():
            raise BattleLogError(f"line {line_number}: empty lines are not allowed")
        try:
            item = json.loads(raw_line)
        except json.JSONDecodeError as exc:
            raise BattleLogError(f"line {line_number}: malformed JSON: {exc.msg}") from exc
        if not isinstance(item, dict):
            raise BattleLogError(f"line {line_number}: snapshot must be a JSON object")
        if item.get("schema") != SCHEMA or item.get("type") != "snapshot":
            raise BattleLogError(f"line {line_number}: expected schema {SCHEMA!r} and type 'snapshot'")
        tick = item.get("tick")
        if not isinstance(tick, int) or isinstance(tick, bool) or tick < 0:
            raise BattleLogError(f"line {line_number}: tick must be a non-negative integer")
        if previous_tick is not None and tick <= previous_tick:
            raise BattleLogError(f"line {line_number}: tick {tick} is not greater than previous tick {previous_tick}")
        previous_tick = tick
        players = item.get("players")
        if not isinstance(players, list) or len(players) != 8:
            raise BattleLogError(f"line {line_number}: players must contain exactly 8 players for a 4v4 match")
        identities: dict[int, str] = {}
        teams = {"red": 0, "blue": 0}
        red_strength = blue_strength = 0.0
        for index, player in enumerate(players, 1):
            if not isinstance(player, dict):
                raise BattleLogError(f"line {line_number}: player {index} must be an object")
            player_id = player.get("id")
            if not _positive_int(player_id):
                raise BattleLogError(f"line {line_number}: player {index} id must be a positive integer")
            team = player.get("team")
            if team not in teams:
                raise BattleLogError(f"line {line_number}: player {player_id} team must be 'red' or 'blue'")
            health = player.get("health")
            if isinstance(health, bool) or not isinstance(health, (int, float)) or not math.isfinite(health) or not 0 <= health <= 100:
                raise BattleLogError(f"line {line_number}: player {player_id} health must be a finite number from 0 to 100")
            for coordinate in ("x", "y", "z"):
                if not isinstance(player.get(coordinate), int) or isinstance(player.get(coordinate), bool):
                    raise BattleLogError(f"line {line_number}: player {player_id} {coordinate} must be an integer")
            if player_id in identities:
                raise BattleLogError(f"line {line_number}: duplicate player id {player_id}")
            identities[player_id] = team
            teams[team] += 1
            if team == "red":
                red_strength += (1 + health / 100) if health > 0 else 0
            else:
                blue_strength += (1 + health / 100) if health > 0 else 0
        if teams != {"red": 4, "blue": 4}:
            raise BattleLogError(f"line {line_number}: expected four players on each team")
        if expected_players is None:
            expected_players = identities
        elif identities != expected_players:
            raise BattleLogError(f"line {line_number}: player IDs and team assignments must remain stable")
        total = red_strength + blue_strength
        red_share = red_strength / total if total else 0.5
        samples.append({"tick": tick, "red_share": red_share, "blue_share": 1 - red_share})
    if not samples:
        raise BattleLogError("input contains no snapshots")
    return samples


def analyze(samples: list[dict[str, object]], *, early_fraction: float = 0.3,
            late_windows: int = 3, min_growth: float = 0.1) -> dict[str, object]:
    if not 0 < early_fraction < 1:
        raise BattleLogError("early_fraction must be greater than 0 and less than 1")
    if not isinstance(late_windows, int) or isinstance(late_windows, bool) or late_windows < 2:
        raise BattleLogError("late_windows must be an integer of at least 2")
    if not math.isfinite(min_growth) or min_growth <= 0 or min_growth > 1:
        raise BattleLogError("min_growth must be greater than 0 and at most 1")
    if not samples:
        raise BattleLogError("input contains no snapshots")

    n = len(samples)
    early_count = max(1, math.ceil(n * early_fraction))
    # Divide the remaining timeline into nonempty, contiguous late windows.
    tail_count = n - early_count
    if tail_count < late_windows:
        return _result("insufficient_evidence", samples, early_fraction, late_windows, min_growth,
                       None, [], "Not enough snapshots to compare early data with all late windows.")
    early = samples[:early_count]
    late = samples[early_count:]
    windows: list[dict[str, object]] = []
    for window_index in range(late_windows):
        start = window_index * tail_count // late_windows
        end = (window_index + 1) * tail_count // late_windows
        subset = late[start:end]
        windows.append({"first_tick": subset[0]["tick"], "last_tick": subset[-1]["tick"],
                        "red_share": _mean(subset, "red_share"),
                        "blue_share": _mean(subset, "blue_share")})
    early_red = _mean(early, "red_share")
    early_blue = 1 - early_red
    red_deltas = [float(w["red_share"]) - float(w["blue_share"]) for w in windows]
    blue_deltas = [-delta for delta in red_deltas]
    team: str | None = None
    growth = 0.0
    if all(delta > 0 for delta in red_deltas):
        team = "red"
        growth = sum(red_deltas) / len(red_deltas) - (early_red - early_blue)
    elif all(delta < 0 for delta in red_deltas):
        team = "blue"
        growth = sum(blue_deltas) / len(blue_deltas) - (early_blue - early_red)
    status = "snowball" if team is not None and growth >= min_growth else "no_snowball"
    summary = (f"Heuristic snowball detected for {team}: lead grew by {growth:.3f} share points."
               if status == "snowball" else
               "No growing team advantage met the configured heuristic thresholds.")
    return _result(status, samples, early_fraction, late_windows, min_growth,
                   {"red_share": early_red, "blue_share": early_blue}, windows, summary,
                   leading_team=team, lead_growth=growth)


def _mean(samples: list[dict[str, object]], key: str) -> float:
    return sum(float(sample[key]) for sample in samples) / len(samples)


def _result(status: str, samples: list[dict[str, object]], early_fraction: float,
            late_windows: int, min_growth: float, early: dict[str, float] | None,
            windows: list[dict[str, object]], summary: str, **extra: object) -> dict[str, object]:
    result: dict[str, object] = {
        "schema": "kookie-battle-analysis-v1", "heuristic": True,
        "causal_proof": False, "status": status, "summary": summary,
        "formula": FORMULA,
        "thresholds": {"early_fraction": early_fraction, "late_windows": late_windows,
                       "min_growth": min_growth},
        "snapshot_count": len(samples), "early_average_share": early,
        "late_windows": windows,
    }
    result.update(extra)
    return result


def _positive_float(text: str) -> float:
    try:
        value = float(text)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError("must be a finite number greater than 0")
    return value


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Analyze newline-delimited kookie-battle-v1 snapshots for heuristic snowballing.",
        epilog=("Formula: team strength = alive-player count + sum(remaining health / 100); "
                "team share = team strength / combined strength. A snowball requires one team to "
                "lead in every late window, and its average late lead must exceed its early lead "
                "by at least --min-growth. This is heuristic, not causal proof."))
    parser.add_argument("path", nargs="?", help="NDJSON file (default: stdin; use - for stdin)")
    parser.add_argument("--early-fraction", type=float, default=0.3,
                        help="fraction of snapshots assigned to early baseline (default: 0.3)")
    parser.add_argument("--late-windows", type=int, default=3,
                        help="number of contiguous late windows, at least 2 (default: 3)")
    parser.add_argument("--min-growth", type=_positive_float, default=0.1,
                        help="minimum normalized-share lead and early-to-late growth (default: 0.1)")
    parser.add_argument("--format", choices=("json", "text"), default="json",
                        help="output format (default: json)")
    args = parser.parse_args(argv)
    try:
        if args.path and args.path != "-":
            with Path(args.path).open(encoding="utf-8") as stream:
                samples = parse_log(stream)
        else:
            samples = parse_log(sys.stdin)
        result = analyze(samples, early_fraction=args.early_fraction,
                         late_windows=args.late_windows, min_growth=args.min_growth)
    except (OSError, UnicodeError, BattleLogError) as exc:
        print(f"analyze_battle_log: {exc}", file=sys.stderr)
        return 2
    if args.format == "json":
        print(json.dumps(result, sort_keys=True))
    else:
        print(result["summary"])
        print(f"Status: {result['status']} (heuristic; not causal proof)")
        print(f"Formula: {FORMULA}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
