#!/usr/bin/env python3
"""Lint Kof sources for repository-safe style before compilation."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

MAX_LINE_LENGTH = 120


def source_files(roots: list[Path]) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix == ".kf":
            files.append(root)
        elif root.is_dir():
            files.extend(sorted(root.rglob("*.kf")))
    return sorted(set(files))


def lint(path: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    for number, line in enumerate(text.splitlines(), 1):
        if "\t" in line:
            errors.append(f"{path}:{number}: tabs are not allowed")
        if line.rstrip(" \r\n") != line:
            errors.append(f"{path}:{number}: trailing whitespace")
        if len(line) > MAX_LINE_LENGTH:
            errors.append(f"{path}:{number}: line exceeds {MAX_LINE_LENGTH} columns")
        if "TODO" in line or "FIXME" in line:
            errors.append(f"{path}:{number}: unfinished marker is not allowed")
    if not text.strip():
        errors.append(f"{path}:1: source file is empty")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint Kof .kf sources")
    parser.add_argument("roots", nargs="+", type=Path)
    args = parser.parse_args()
    files = source_files(args.roots)
    if not files:
        print("lint: no Kof source files found", file=sys.stderr)
        return 2
    errors = [error for path in files for error in lint(path)]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"linted {len(files)} Kof source file(s) — no errors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
