#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-prototype-package-smoke.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

openssl genpkey -algorithm ED25519 -out "$WORK_DIR/signing.pem" 2>/dev/null
chmod 600 "$WORK_DIR/signing.pem"
: "${KOOKIE_KOF_ARCHIVE:?set KOOKIE_KOF_ARCHIVE to the exact Kof distribution archive}"
[[ -f "$KOOKIE_KOF_ARCHIVE" && ! -L "$KOOKIE_KOF_ARCHIVE" ]] || {
  echo 'verify_prototype_package: KOOKIE_KOF_ARCHIVE must be a regular file' >&2
  exit 2
}
kof_archive_sha256="$(sha256sum "$KOOKIE_KOF_ARCHIVE" | cut -d ' ' -f 1)"
[[ "$kof_archive_sha256" != 0000000000000000000000000000000000000000000000000000000000000000 ]] || {
  echo 'verify_prototype_package: Kof archive digest cannot be all zeroes' >&2
  exit 2
}
RELEASE_DIR="$WORK_DIR/release"
source "$ROOT_DIR/scripts/kof_pin.sh"
KOOKIE_ALLOW_DIRTY_PACKAGE=1 \
KOOKIE_SIGNING_KEY="$WORK_DIR/signing.pem" \
KOOKIE_KOF_ARCHIVE="$KOOKIE_KOF_ARCHIVE" \
KOOKIE_KOF_ARCHIVE_SHA256="$kof_archive_sha256" \
KOOKIE_KOF_SOURCE_COMMIT="$KOF_PIN_SOURCE_COMMIT" \
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
python3 "$ROOT_DIR/scripts/verify_ui_manifest.py" \
  "$PACKAGE_ROOT/assets/ui/manifest.json" "$PACKAGE_ROOT" --profile prototype

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
assert release_manifest["prototype_models_policy"] == "strict-native-required"
assert release_manifest["prototype_content_asset_count"] == len(inner["assets"]) == 31
assert release_manifest["prototype_content_file_count"] == 141
assert (package_root / "PROVENANCE.txt").read_text(encoding="utf-8").count(
    "prototype_content_profile=prototype") == 1
provenance = {}
for line in (package_root / "PROVENANCE.txt").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        provenance[key] = value
assert provenance["prototype_content_profile"] == "prototype"
assert provenance["prototype_models_policy"] == "strict-native-required"
assert provenance["prototype_content_asset_count"] == "31"
assert provenance["prototype_content_file_count"] == "141"
digest = hashlib.sha256()
file_count = 0
for path in sorted(content.rglob("*")):
    assert not path.is_symlink()
    if path.is_file():
        digest.update(path.relative_to(content).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        file_count += 1
assert file_count == 141
assert digest.hexdigest() == release_manifest["prototype_content_sha256"]
assert provenance["prototype_content_sha256"] == digest.hexdigest()
for relative in (
    "manifest.json",
    "greybox_modules.json",
    "models/modular/wall.glb",
    "models/modular/wall_window.glb",
    "models/goose/goose.glb",
    "models/cat/cat.glb",
    "runtime/vfx/particles/circle_01_a.png",
    "cooked/vfx/particles/circle_01_a.rgba.png",
    "runtime/ui/hearts_0001.png",
    "cooked/ui/hearts_0001.rgba.png",
    "licenses/goose-upstream-terms.txt",
    "licenses/prildarill-meow-terms.txt",
    "licenses/echo-studios-heart-terms.txt",
):
    assert (content / relative).is_file(), relative
assert not (content / "models/cat/source").exists()
print("prototype package manifest/provenance/content=ok")
PY
cat >"$WORK_DIR/model_assets_probe.c" <<'EOF'
#define _POSIX_C_SOURCE 200809L
#include "kookie_model_assets.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc != 3) {
        return 2;
    }
    bool expected = strcmp(argv[1], "present") == 0;
    if (setenv("KOOKIE_PROTOTYPE_CONTENT_ROOT", argv[2], 1) != 0) {
        return 3;
    }
    unsetenv("KOOKIE_REQUIRE_NATIVE_ANIMAL_MODELS");
    unsetenv("KOOKIE_CONTENT_PROFILE");
    if (kookie_model_assets_required() != expected) {
        return 4;
    }
    if (expected) {
        if (!kookie_model_assets_available(KOOKIE_MODEL_GOOSE) ||
            !kookie_model_assets_available(KOOKIE_MODEL_CAT) ||
            kookie_model_assets_vertex_count(KOOKIE_MODEL_GOOSE) != 708 ||
            kookie_model_assets_vertex_count(KOOKIE_MODEL_CAT) != 2400) {
            return 5;
        }
    } else if (kookie_model_assets_available(KOOKIE_MODEL_GOOSE) ||
               kookie_model_assets_available(KOOKIE_MODEL_CAT)) {
        return 6;
    }
    if (setenv("KOOKIE_CONTENT_PROFILE", "prototype", 1) != 0 ||
        !kookie_model_assets_required()) {
        return 7;
    }
    puts("prototype model policy=ok");
    return 0;
}
EOF
cc -std=c11 -Wall -Wextra -Werror -I"$ROOT_DIR/native" \
  "$ROOT_DIR/native/kookie_model_assets.c" \
  "$WORK_DIR/model_assets_probe.c" -lm \
  -o "$WORK_DIR/model_assets_probe"
mkdir "$WORK_DIR/empty-content"
(cd "$WORK_DIR" && "$WORK_DIR/model_assets_probe" present "$PACKAGE_ROOT/content/prototype")
(cd "$WORK_DIR" && "$WORK_DIR/model_assets_probe" missing "$WORK_DIR/empty-content")


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
