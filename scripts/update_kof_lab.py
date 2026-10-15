#!/usr/bin/env python3
"""Resolve and apply the current Kof4j lab source pin.

The repository keeps builds reproducible by pinning an immutable commit. This
command checks that pin against the mutable upstream ``lab`` branch and, when
asked to apply, validates every active text target, then updates the source/CI
documentation.
It never changes historical changelogs or evidence snapshots.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
KOF_REPOSITORY = os.environ.get(
    "KOOKIE_KOF_REPOSITORY", "https://github.com/KofLang/Kof4j.git"
)
KOF_REF = "refs/heads/lab"
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
PIN_FILE = ROOT / "scripts/kof_pin.sh"

# These files describe the active build baseline. Historical changelogs,
# MEMORY.md, generated artifacts and dated research evidence stay immutable.
ACTIVE_PATHS = (
    Path(".github/workflows/release_demo.yml"),
    Path(".github/workflows/verify.yml"),
    Path("README.md"),
    Path("pt-BR/README.md"),
    Path("scripts/kof-as/as"),
    Path("docs"),
    Path("pt-BR/docs"),
)


def fail(message: str) -> int:
    print(f"update_kof_lab: {message}", file=sys.stderr)
    return 2


def read_pin() -> tuple[str, str]:
    text = PIN_FILE.read_text(encoding="utf-8")
    version_match = re.search(r"^KOF_PIN_VERSION='([^']+)'$", text, re.MULTILINE)
    commit_match = re.search(
        r"^KOF_PIN_SOURCE_COMMIT='([0-9a-f]{40})'$", text, re.MULTILINE
    )
    if version_match is None or commit_match is None:
        raise ValueError(f"cannot parse {PIN_FILE}")
    return version_match.group(1), commit_match.group(1)


def resolve_lab_commit() -> str:
    result = subprocess.run(
        ["git", "ls-remote", KOF_REPOSITORY, KOF_REF],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git ls-remote failed")
    fields = result.stdout.split()
    if not fields or COMMIT_PATTERN.fullmatch(fields[0]) is None:
        raise RuntimeError("upstream lab ref did not return a commit SHA")
    return fields[0]


def resolve_lab_version(commit: str) -> str:
    repository = KOF_REPOSITORY.removesuffix(".git")
    prefix = "https://github.com/"
    if not repository.startswith(prefix):
        raise RuntimeError("Kof repository must use an https://github.com URL")
    project = repository.removeprefix(prefix)
    url = f"https://raw.githubusercontent.com/{project}/{commit}/VERSION"
    with urlopen(url, timeout=20) as response:
        version = response.read().decode("utf-8").strip()
    if VERSION_PATTERN.fullmatch(version) is None:
        raise RuntimeError(f"upstream VERSION is invalid: {version!r}")
    return version


def active_files() -> list[Path]:
    paths: list[Path] = []
    for relative in ACTIVE_PATHS:
        path = ROOT / relative
        if path.is_dir():
            for child in sorted(path.rglob("*")):
                if not child.is_file():
                    continue
                try:
                    child.read_text(encoding="utf-8")
                except UnicodeDecodeError:
                    continue
                paths.append(child)
        elif path.is_file():
            paths.append(path)
    paths.append(PIN_FILE)
    return paths


def apply_pin(old_version: str, old_commit: str, new_version: str, new_commit: str) -> list[Path]:
    updates: list[tuple[Path, str]] = []
    for path in active_files():
        original = path.read_text(encoding="utf-8")
        updated = original.replace(old_commit, new_commit)
        if old_version != new_version:
            updated = updated.replace(old_version, new_version)
        if path == PIN_FILE:
            updated = re.sub(
                r"^KOF_PIN_VERSION='[^']+'$",
                f"KOF_PIN_VERSION='{new_version}'",
                updated,
                flags=re.MULTILINE,
            )
            updated = re.sub(
                r"^KOF_PIN_SOURCE_COMMIT='[0-9a-f]{40}'$",
                f"KOF_PIN_SOURCE_COMMIT='{new_commit}'",
                updated,
                flags=re.MULTILINE,
            )
        if updated != original:
            updates.append((path, updated))
    if not any(path == PIN_FILE for path, _ in updates):
        raise RuntimeError("pin file did not change; refusing a partial update")
    changed: list[Path] = []
    for path, updated in updates:
        path.write_text(updated, encoding="utf-8")
        changed.append(path.relative_to(ROOT))
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="only compare the repository pin with refs/heads/lab",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="update the immutable pin and active CI/documentation references",
    )
    parser.add_argument(
        "--expected-commit",
        help="require refs/heads/lab to still resolve to this commit before applying",
    )
    parser.add_argument(
        "--expected-version",
        help="require VERSION to still match before applying",
    )
    args = parser.parse_args()
    if args.check == args.apply:
        parser.error("choose exactly one of --check or --apply")
    if (args.expected_commit or args.expected_version) and not args.apply:
        parser.error("--expected-* requires --apply")
    if args.expected_commit and COMMIT_PATTERN.fullmatch(args.expected_commit) is None:
        parser.error("--expected-commit must be a 40-character lowercase SHA")
    if args.expected_version and VERSION_PATTERN.fullmatch(args.expected_version) is None:
        parser.error("--expected-version is not a valid Kof version")

    try:
        current_version, current_commit = read_pin()
        latest_commit = resolve_lab_commit()
        latest_version = resolve_lab_version(latest_commit)
    except (OSError, ValueError, RuntimeError, TimeoutError) as error:
        return fail(str(error))
    if args.expected_commit and latest_commit != args.expected_commit:
        return fail(
            "lab changed before the pinned update: "
            f"expected {args.expected_commit}, found {latest_commit}"
        )
    if args.expected_version and latest_version != args.expected_version:
        return fail(
            "lab VERSION changed before the pinned update: "
            f"expected {args.expected_version}, found {latest_version}"
        )

    print(f"Kof lab current: {current_version} {current_commit}")
    print(f"Kof lab latest:  {latest_version} {latest_commit}")
    if current_commit == latest_commit and current_version == latest_version:
        print("Kof lab pin is current")
        return 0
    if args.check:
        print("Kof lab pin is stale", file=sys.stderr)
        return 1

    try:
        changed = apply_pin(
            current_version, current_commit, latest_version, latest_commit
        )
    except (OSError, RuntimeError) as error:
        return fail(str(error))
    print("updated files:")
    for path in changed:
        print(f"- {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
