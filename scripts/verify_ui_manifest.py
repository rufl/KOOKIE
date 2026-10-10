#!/usr/bin/env python3
"""Validate a published UI manifest and its staged runtime assets."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from ui_manifest import verify_staged_ui_assets


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("root", type=Path)
    parser.add_argument("--profile", choices=("none", "prototype", "demo"), required=True)
    args = parser.parse_args()
    try:
        _, assets = verify_staged_ui_assets(
            args.manifest, args.root, args.profile
        )
    except (OSError, ValueError) as error:
        print(f"verify_ui_manifest: {error}", file=sys.stderr)
        return 1
    print(
        f"UI manifest verified profile={args.profile} assets={len(assets)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
