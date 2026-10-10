#!/usr/bin/env python3
"""Report physical source-line composition for the current KOOKIE checkout."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

GROUPS = (
    ("Kof", (".kf",), ("src", "probes", "apps")),
    ("KofScript", (".ks",), ("src", "probes", "apps")),
    ("C/header", (".c", ".h"), ("native", "probes", "scripts")),
    ("Shell tooling", (".sh",), ("scripts",)),
    ("Python tooling", (".py",), ("scripts",)),
    ("PE bridge Java", (".java",), ("tooling",)),
    ("GPU shader", (".glsl", ".hlsl", ".vert", ".frag"), ("native",)),
)


def source_files() -> list[Path]:
    files: list[Path] = []
    for _, _, roots in GROUPS:
        for root in roots:
            directory = ROOT / root
            if not directory.is_dir():
                continue
            files.extend(
                path
                for path in directory.rglob("*")
                if path.is_file() and "__pycache__" not in path.parts
            )
    return sorted(set(files))


def line_count(path: Path) -> int:
    with path.open("rb") as source:
        return sum(1 for _ in source)


def collect() -> list[dict[str, object]]:
    by_path = {path: line_count(path) for path in source_files()}
    result: list[dict[str, object]] = []
    for name, extensions, roots in GROUPS:
        paths = [
            path
            for path in by_path
            if path.suffix.lower() in extensions
            and any(path.is_relative_to(ROOT / root) for root in roots)
        ]
        lines = sum(by_path[path] for path in paths)
        result.append({"name": name, "files": len(paths), "lines": lines})
    total = sum(int(row["lines"]) for row in result)
    for row in result:
        row["percent"] = 0.0 if total == 0 else 100.0 * int(row["lines"]) / total
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = parser.parse_args()
    rows = collect()
    total = sum(int(row["lines"]) for row in rows)
    payload = {"root": str(ROOT), "total_lines": total, "groups": rows}
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0
    print(f"KOOKIE source composition (physical lines, total={total})")
    for row in rows:
        print(
            f"{row['name']:22} files={int(row['files']):3d} "
            f"lines={int(row['lines']):6d} percent={float(row['percent']):6.2f}%"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
