#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-package-smoke.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

KOOKIE_VERSION=0.1.0-dogfood.smoke \
KOOKIE_BUILD_ID=package-smoke \
"$ROOT_DIR/scripts/package_kookie.sh" --output "$WORK_DIR/release"

(
  cd "$WORK_DIR/release"
  sha256sum --check SHA256SUMS >/dev/null
)
ARCHIVE="$WORK_DIR/release/kookie-0.1.0-dogfood.smoke-linux-x86_64.tar.gz"
MANIFEST="$WORK_DIR/release/kookie-0.1.0-dogfood.smoke-linux-x86_64.json"
test -f "$ARCHIVE" -a -f "$MANIFEST"
mkdir "$WORK_DIR/extracted"
tar -xzf "$ARCHIVE" -C "$WORK_DIR/extracted"
BINARY="$WORK_DIR/extracted/kookie-0.1.0-dogfood.smoke-linux-x86_64/kookie"
test -f "$BINARY"
test -f "$WORK_DIR/extracted/kookie-0.1.0-dogfood.smoke-linux-x86_64/LICENSE"
"$BINARY" 2>"$WORK_DIR/runtime.err" | grep -Fq 'KOOKIE G1 loopback foundation verified'
python3 - "$MANIFEST" <<'PY'
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert manifest["schema"] == "overzeer.package-provenance/v1"
assert manifest["application"] == "kookie"
assert manifest["target"] == "linux-x86_64"
assert manifest["channel"] == "dogfood"
assert manifest["signing"] == "unavailable"
assert manifest["proof"] == "unavailable"
PY
if "$ROOT_DIR/scripts/package_kookie.sh" --target windows-x86_64 --output "$WORK_DIR/windows" >"$WORK_DIR/windows.out" 2>&1; then
  echo 'package smoke: Windows packaging unexpectedly succeeded' >&2
  exit 1
fi
grep -Fq 'Windows packaging is blocked' "$WORK_DIR/windows.out"
printf 'KOOKIE package smoke passed: Linux archive, checksum, provenance, runtime, and Windows fail-closed gate\n'
