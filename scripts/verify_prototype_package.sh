#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-prototype-package-smoke.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

openssl genpkey -algorithm ED25519 -out "$WORK_DIR/signing.pem" 2>/dev/null
chmod 600 "$WORK_DIR/signing.pem"
RELEASE_DIR="$WORK_DIR/release"
KOOKIE_ALLOW_DIRTY_PACKAGE=1 \
KOOKIE_SIGNING_KEY="$WORK_DIR/signing.pem" \
KOOKIE_KOF_ARCHIVE_SHA256=f6fd41ed59c461dd968376e8e2dd3f0dc24ee712578d318a7fb3f707bc761bdc \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_VERSION=0.1.0-dogfood.prototype-smoke \
KOOKIE_BUILD_ID=prototype-package-smoke \
SOURCE_DATE_EPOCH=1700000000 \
  "$ROOT_DIR/scripts/package_kookie.sh" \
  --runtime native --target linux-x86_64 --content prototype \
  --output "$RELEASE_DIR" >/dev/null

(
  cd "$RELEASE_DIR"
  sha256sum --check SHA256SUMS >/dev/null
)

ARCHIVE="$RELEASE_DIR/kookie-0.1.0-dogfood.prototype-smoke-linux-x86_64.tar.gz"
MANIFEST="$RELEASE_DIR/kookie-0.1.0-dogfood.prototype-smoke-linux-x86_64.json"
PUBLIC_KEY="$RELEASE_DIR/kookie-0.1.0-dogfood.prototype-smoke-linux-x86_64.pub.pem"
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$ARCHIVE" -sigfile "$ARCHIVE.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$MANIFEST" -sigfile "$MANIFEST.sig" >/dev/null

mkdir "$WORK_DIR/extracted"
tar -xzf "$ARCHIVE" -C "$WORK_DIR/extracted"
PACKAGE_ROOT="$WORK_DIR/extracted/kookie-0.1.0-dogfood.prototype-smoke-linux-x86_64"

python3 - "$PACKAGE_ROOT" "$MANIFEST" <<'PY'
import hashlib
import json
import pathlib
import sys

package_root = pathlib.Path(sys.argv[1])
release_manifest = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
content = package_root / "content" / "prototype"
inner = json.loads((content / "manifest.json").read_text(encoding="utf-8"))
assert release_manifest["content_profile"] == "prototype"
assert release_manifest["prototype_content_asset_count"] == len(inner["assets"]) == 29
assert release_manifest["prototype_content_file_count"] == 66
assert (package_root / "PROVENANCE.txt").read_text(encoding="utf-8").count(
    "prototype_content_profile=prototype") == 1
provenance = {}
for line in (package_root / "PROVENANCE.txt").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        provenance[key] = value
assert provenance["prototype_content_profile"] == "prototype"
assert provenance["prototype_content_asset_count"] == "29"
assert provenance["prototype_content_file_count"] == "66"
digest = hashlib.sha256()
file_count = 0
for path in sorted(content.rglob("*")):
    assert not path.is_symlink()
    if path.is_file():
        digest.update(path.relative_to(content).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        file_count += 1
assert file_count == 66
assert digest.hexdigest() == release_manifest["prototype_content_sha256"]
assert provenance["prototype_content_sha256"] == digest.hexdigest()
for relative in (
    "models/goose/goose.glb",
    "runtime/vfx/particles/circle_01_a.png",
    "cooked/vfx/particles/circle_01_a.rgba.png",
    "licenses/goose-upstream-terms.txt",
):
    assert (content / relative).is_file(), relative
print("prototype package manifest/provenance/content=ok")
PY

"$PACKAGE_ROOT/kookie" --package-smoke \
  >"$WORK_DIR/runtime.log" 2>"$WORK_DIR/runtime.err"
python3 - "$WORK_DIR/runtime.log" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
assert "KOOKIE G1 authoritative shooter verified" in text
print("prototype package runtime=ok")
PY

"$PACKAGE_ROOT/kooker" cook png \
  "$PACKAGE_ROOT/content/prototype/runtime/vfx/particles/circle_01_a.png" \
  "$WORK_DIR/cooked-circle.rgba.png" >/dev/null
cmp -- "$WORK_DIR/cooked-circle.rgba.png" \
  "$PACKAGE_ROOT/content/prototype/cooked/vfx/particles/circle_01_a.rgba.png"
printf 'prototype package: signed archive, content provenance, runtime launch, and packaged kooker passed\n'
