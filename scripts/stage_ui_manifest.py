#!/usr/bin/env python3
"""Stage published UI assets from authored paths to runtime paths."""

from __future__ import annotations

import argparse
from pathlib import Path, PurePosixPath
import shutil
import sys

from ui_manifest import load_ui_manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("source_root", type=Path)
    parser.add_argument("destination_root", type=Path)
    parser.add_argument("--profile", choices=("none", "prototype", "demo"), required=True)
    args = parser.parse_args()
    try:
        manifest, assets = load_ui_manifest(args.manifest)
        optional_ids = set(manifest["publication"]["optional_asset_ids"])
        staged = 0
        skipped = 0
        for asset in assets:
            if args.profile == "none" and asset["id"] in optional_ids:
                skipped += 1
                continue
            source = args.source_root / Path(asset["authored_path"])
            destination = args.destination_root.joinpath(
                *PurePosixPath(asset["runtime_path"]).parts
            )
            if not source.is_file() or source.is_symlink():
                raise ValueError(f"missing authored asset: {asset['id']}: {source}")
            if destination.is_symlink():
                raise ValueError(f"refusing symlink destination: {destination}")
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            staged += 1
    except (OSError, ValueError) as error:
        print(f"stage_ui_manifest: {error}", file=sys.stderr)
        return 1
    print(f"UI assets staged profile={args.profile} staged={staged} skipped={skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
