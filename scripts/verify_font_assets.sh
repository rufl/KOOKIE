#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
font_dir="$root_dir/assets/fonts"
manifest="$font_dir/manifest.json"

python3 - "$font_dir" "$manifest" <<'PY'
import hashlib
import json
import pathlib
import sys

font_dir = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest["schema"] == "kookie.gatoganso-font-catalog/v1"
assert manifest["game"] == "GatoGanso"
assert manifest["defaults"]["body"] == {
    "family": "Jared Lite",
    "file": "jared-lite.ttf",
    "atlas": "JARED_LITE",
}
assert manifest["defaults"]["display"] == {
    "family": "Pixand",
    "file": "pixand.ttf",
    "atlas": "PIXAND",
}
for entry in manifest["files"]:
    path = font_dir / entry["path"]
    assert path.is_file(), path
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"], path
for name in ("jared-lite.ttf", "pixand.ttf"):
    assert (font_dir / name).read_bytes()[:4] == b"\x00\x01\x00\x00"
print("GatoGanso font assets verified: Jared Lite body, Pixand display")
PY
