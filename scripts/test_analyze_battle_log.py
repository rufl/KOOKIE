#!/usr/bin/env python3
"""Focused tests for the standalone battle-log heuristic."""

from __future__ import annotations

import io
import json
import subprocess
import sys
import unittest
from pathlib import Path

from analyze_battle_log import BattleLogError, analyze, parse_log

SCRIPT = Path(__file__).with_name("analyze_battle_log.py")


def snapshot(tick: int, red_health: int, blue_health: int) -> str:
    players = []
    for team, start, health in (("red", 1, red_health), ("blue", 5, blue_health)):
        for offset in range(4):
            players.append({"id": start + offset, "team": team,
                            "health": health, "x": 0, "y": 0, "z": 0})
    return json.dumps({"schema": "kookie-battle-v1", "type": "snapshot",
                       "tick": tick, "players": players})


def log(red: list[int], blue: list[int]) -> str:
    return "\n".join(snapshot(i, rh, bh) for i, (rh, bh) in enumerate(zip(red, blue))) + "\n"


class BattleLogTests(unittest.TestCase):
    def test_detects_growing_advantage_across_late_windows(self) -> None:
        samples = parse_log(io.StringIO(log([50, 50, 50, 50, 50, 50, 50, 50, 50, 50],
                                          [50, 50, 40, 30, 20, 10, 5, 1, 0, 0])))
        result = analyze(samples)
        self.assertEqual(result["status"], "snowball")
        self.assertEqual(result["leading_team"], "red")
        self.assertTrue(result["heuristic"])
        self.assertFalse(result["causal_proof"])

    def test_rejects_no_snapshots_and_bad_lines(self) -> None:
        for contents, expected in (("", "no snapshots"), ("\n", "empty lines"),
                                   ("{", "malformed JSON")):
            with self.subTest(contents=contents), self.assertRaisesRegex(BattleLogError, expected):
                parse_log(io.StringIO(contents))

    def test_rejects_non_monotonic_ticks_and_invalid_roster(self) -> None:
        with self.assertRaisesRegex(BattleLogError, "not greater"):
            parse_log(io.StringIO(snapshot(4, 50, 50) + "\n" + snapshot(4, 50, 50)))
        bad = json.loads(snapshot(1, 50, 50))
        bad["players"].pop()
        with self.assertRaisesRegex(BattleLogError, "exactly 8"):
            parse_log(io.StringIO(json.dumps(bad)))

    def test_cli_supports_file_and_stdin_json_and_text(self) -> None:
        payload = log([50] * 8, [50, 50, 40, 30, 20, 10, 5, 1])
        from_stdin = subprocess.run([sys.executable, str(SCRIPT), "--format", "json"],
                                    input=payload, text=True, capture_output=True, check=False)
        self.assertEqual(from_stdin.returncode, 0, from_stdin.stderr)
        self.assertEqual(json.loads(from_stdin.stdout)["status"], "snowball")
        with subprocess.Popen([sys.executable, str(SCRIPT), "--format", "text", "-"],
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, text=True) as process:
            stdout, stderr = process.communicate(payload)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertIn("heuristic", stdout.lower())
            self.assertIn("not causal proof", stdout.lower())

    def test_cli_reports_malformed_input(self) -> None:
        result = subprocess.run([sys.executable, str(SCRIPT)], input="{\n", text=True,
                                capture_output=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("line 1: malformed JSON", result.stderr)


if __name__ == "__main__":
    unittest.main()
