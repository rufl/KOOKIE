#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTENT_ROOT="$ROOT_DIR/assets/prototype"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-prototype-content.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

command -v python3 >/dev/null || { echo 'prototype content: python3 is required' >&2; exit 2; }
command -v kof >/dev/null || { echo 'prototype content: kof is required' >&2; exit 2; }

python3 - "$CONTENT_ROOT" <<'PY'
import hashlib
import json
import pathlib
import struct
import sys

root = pathlib.Path(sys.argv[1]).resolve()
manifest_path = root / "manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest["schema"] == "kookie.prototype-content/v1"
assert manifest["asset_policy"]["all_sources_claimed_cc0"] is False
assert "model.goose" in manifest["asset_policy"]["restricted_assets"]
assert "model.prildarill-cat" in manifest["asset_policy"]["restricted_assets"]
assert "ui.player-hearts" in manifest["asset_policy"]["restricted_assets"]
assets = manifest["assets"]
assert len(assets) == 31
catalog_path = root / manifest["editor_catalog"]
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
assert catalog["schema"] == "kookie.greybox-module-catalog/v1"
assert catalog["pack_id"] == "rgsdev-modular-prototyping"
assert catalog["license"] == "CC0"
assert catalog["editor_policy"]["texture_override"] == "free"
modules = catalog["modules"]
assert len(modules) == 75
module_runtime_paths = set()
for module in modules:
    assert module["license"] == "CC0"
    assert module["texture_override"] == "free"
    assert module["runtime_ready"] is True
    runtime_path = pathlib.PurePosixPath(module["runtime_path"])
    assert not runtime_path.is_absolute() and ".." not in runtime_path.parts
    assert runtime_path not in module_runtime_paths
    module_runtime_paths.add(runtime_path)
    model = root.joinpath(*runtime_path.parts)
    assert model.is_file() and not model.is_symlink()
    data = model.read_bytes()
    assert len(data) >= 12
    magic, version, length = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2 and length == len(data)
assert len(module_runtime_paths) == 75
cat_source = next(
    source for source in manifest["direct_sources"]
    if source["id"] == "prildarill-low-poly-cat"
)
for source_file in cat_source["source_files"]:
    relative = pathlib.PurePosixPath(source_file["path"])
    assert not relative.is_absolute() and ".." not in relative.parts
    path = root.joinpath(*relative.parts)
    assert path.is_file() and not path.is_symlink()
    assert hashlib.sha256(path.read_bytes()).hexdigest() == source_file["sha256"]
heart_source = next(
    source for source in manifest["direct_sources"]
    if source["id"] == "echo-studios-heart-assets"
)
heart_asset = next(asset for asset in assets if asset["id"] == "ui.player-hearts")
heart_authored = root / heart_asset["authored_path"]
assert heart_authored.is_file() and not heart_authored.is_symlink()
assert hashlib.sha256(heart_authored.read_bytes()).hexdigest() == heart_source["source_sha256"]
seen = set()
for asset in assets:
    assert asset["id"] and asset["kind"] and asset["license"]
    for field in ("authored_path", "runtime_path", "cooked_path"):
        relative_name = asset.get(field)
        if relative_name is None:
            continue
        relative = pathlib.PurePosixPath(relative_name)
        assert not relative.is_absolute() and ".." not in relative.parts
        seen.add(relative_name)
        path = root.joinpath(*relative.parts)
        assert path.is_file() and not path.is_symlink(), relative_name
        assert path.stat().st_size > 0, relative_name
    if asset["kind"] == "model":
        model = root / asset["runtime_path"]
        data = model.read_bytes()
        assert len(data) >= 12
        magic, version, length = struct.unpack_from("<III", data)
        assert magic == 0x46546C67 and version == 2 and length == len(data)
    if asset["kind"] in {"particle-texture", "flipbook", "predrawn-spritesheet", "ui-spritesheet"}:
        runtime = root / asset["runtime_path"]
        data = runtime.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        assert runtime.stat().st_size <= 1_048_576
        offset = 8
        width = height = None
        while offset < len(data):
            chunk_length = struct.unpack_from(">I", data, offset)[0]
            kind = data[offset + 4:offset + 8]
            payload = data[offset + 8:offset + 8 + chunk_length]
            if kind == b"IHDR":
                width, height = struct.unpack_from(">II", payload)
            offset += 12 + chunk_length
        assert width is not None and height is not None
        assert width <= 256 and height <= 256 and width * height <= 65_536
for license_file in (
    "licenses/modular-cc0.txt",
    "licenses/brackeys-vfx-cc0-credits.txt",
    "licenses/classic64-cc0-readme.txt",
):
    assert "CC0" in (root / license_file).read_text(encoding="utf-8")
goose_terms = (root / "licenses/goose-upstream-terms.txt").read_text(encoding="utf-8")
assert "Do not resell" in goose_terms
assert "prototype request" in goose_terms
cat_terms = (root / "licenses/prildarill-meow-terms.txt").read_text(encoding="utf-8")
assert "No credit" in cat_terms
assert "prototype-only" in cat_terms
heart_terms = (root / "licenses/echo-studios-heart-terms.txt").read_text(encoding="utf-8")
assert "No SPDX license" in heart_terms
assert "prototype-only" in heart_terms
print(f"manifest assets={len(assets)} declared-files={len(seen)}")
PY

while IFS=$'\t' read -r runtime_path cooked_path; do
  cooked_output="$WORK_DIR/$(basename -- "$cooked_path")"
  "$ROOT_DIR/scripts/kooker.sh" cook png \
    "$CONTENT_ROOT/$runtime_path" "$cooked_output" >/dev/null
done < <(
  python3 - "$CONTENT_ROOT/manifest.json" <<'PY'
import json
import sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
for asset in manifest["assets"]:
    if "cooked_path" in asset:
        print(asset["runtime_path"] + "\t" + asset["cooked_path"])
PY
)

python3 - "$CONTENT_ROOT" <<'PY'
import hashlib
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
digest = hashlib.sha256()
count = 0
for path in sorted(root.rglob("*")):
    if path.is_symlink() or (not path.is_file() and not path.is_dir()):
        raise SystemExit(f"prototype content: unsafe entry: {path}")
    if path.is_file():
        digest.update(path.relative_to(root).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        count += 1
print(f"tree-sha256={digest.hexdigest()} files={count}")
PY
printf 'prototype content: verified GLB headers, bounded PNGs, kooker outputs, notices, and tree integrity\n'
