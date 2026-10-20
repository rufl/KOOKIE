#!/usr/bin/env python3
"""Run one profiling child and record its own resource usage."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import resource
import subprocess
import sys
import time


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command or args.command[0] != "--":
        parser.error("a command after -- is required")
    command = args.command[1:]
    started = time.monotonic()
    completed = subprocess.run(command, check=False)
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    result = {
        "status": completed.returncode,
        "wall_ms": round((time.monotonic() - started) * 1000.0),
        "user_seconds": round(usage.ru_utime, 6),
        "system_seconds": round(usage.ru_stime, 6),
        "max_rss_kib": int(usage.ru_maxrss),
        "minor_faults": int(usage.ru_minflt),
        "major_faults": int(usage.ru_majflt),
        "voluntary_context_switches": int(usage.ru_nvcsw),
        "involuntary_context_switches": int(usage.ru_nivcsw),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True) + "\n", encoding="utf-8")
    if completed.returncode < 0:
        return 128 - completed.returncode
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
