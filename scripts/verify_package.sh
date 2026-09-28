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
"$BINARY" --package-smoke 2>"$WORK_DIR/runtime.err" | grep -Fq 'KOOKIE G1 authoritative shooter verified'

KOOKIE_VERSION=0.1.0-dogfood.jvm-smoke \
KOOKIE_BUILD_ID=package-jvm-smoke \
"$ROOT_DIR/scripts/package_kookie.sh" --runtime jvm --output "$WORK_DIR/jvm-release"
(
  cd "$WORK_DIR/jvm-release"
  sha256sum --check SHA256SUMS >/dev/null
)
JVM_ARCHIVE="$WORK_DIR/jvm-release/kookie-0.1.0-dogfood.jvm-smoke-linux-x86_64.tar.gz"
JVM_MANIFEST="$WORK_DIR/jvm-release/kookie-0.1.0-dogfood.jvm-smoke-linux-x86_64.json"
test -f "$JVM_ARCHIVE" -a -f "$JVM_MANIFEST"
mkdir "$WORK_DIR/jvm-extracted"
tar -xzf "$JVM_ARCHIVE" -C "$WORK_DIR/jvm-extracted"
JVM_ROOT="$WORK_DIR/jvm-extracted/kookie-0.1.0-dogfood.jvm-smoke-linux-x86_64"
JVM_OUTPUT="$("$JVM_ROOT/kookie" 2>"$WORK_DIR/jvm-runtime.err")" || {
  cat "$WORK_DIR/jvm-runtime.err" >&2
  exit 1
}
grep -Fq 'KOOKIE G1 authoritative shooter verified' <<<"$JVM_OUTPUT"

presentation_manifest_args=()
presentation_status="dependency fail-closed gate"
if command -v glslc >/dev/null &&
   command -v pkg-config >/dev/null &&
   pkg-config --exists sdl3; then
  KOOKIE_VERSION=0.1.0-dogfood.presentation-smoke \
  KOOKIE_BUILD_ID=package-presentation-smoke \
  "$ROOT_DIR/scripts/package_kookie.sh" --runtime presentation \
    --output "$WORK_DIR/presentation-release"
  (
    cd "$WORK_DIR/presentation-release"
    sha256sum --check SHA256SUMS >/dev/null
  )
  PRESENTATION_ARCHIVE="$WORK_DIR/presentation-release/kookie-0.1.0-dogfood.presentation-smoke-linux-x86_64.tar.gz"
  PRESENTATION_MANIFEST="$WORK_DIR/presentation-release/kookie-0.1.0-dogfood.presentation-smoke-linux-x86_64.json"
  test -f "$PRESENTATION_ARCHIVE" -a -f "$PRESENTATION_MANIFEST"
  mkdir "$WORK_DIR/presentation-extracted"
  tar -xzf "$PRESENTATION_ARCHIVE" -C "$WORK_DIR/presentation-extracted"
  PRESENTATION_ROOT="$WORK_DIR/presentation-extracted/kookie-0.1.0-dogfood.presentation-smoke-linux-x86_64"
  test -x "$PRESENTATION_ROOT/kookie"
  test -x "$PRESENTATION_ROOT/kookie.bin"
  test -f "$PRESENTATION_ROOT/build/libkookie_sdl_adapter.so"
  test -f "$PRESENTATION_ROOT/build/g0_triangle.vert.spv"
  test -f "$PRESENTATION_ROOT/build/g0_triangle.frag.spv"
  presentation_manifest_args=("$PRESENTATION_MANIFEST" presentation)
  presentation_status="archive"
else
  if KOOKIE_VERSION=0.1.0-dogfood.presentation-smoke \
     KOOKIE_BUILD_ID=package-presentation-smoke \
     "$ROOT_DIR/scripts/package_kookie.sh" --runtime presentation \
       --output "$WORK_DIR/presentation-unavailable" \
       >"$WORK_DIR/presentation-unavailable.out" 2>&1; then
    echo 'package smoke: presentation packaging unexpectedly ignored missing dependencies' >&2
    exit 1
  fi
  grep -Eq 'glslc is required|pkg-config is required|SDL3 development files are required' \
    "$WORK_DIR/presentation-unavailable.out"
fi
python3 - "$MANIFEST" native "$JVM_MANIFEST" jvm \
  "${presentation_manifest_args[@]}" <<'PY'
import json, pathlib, sys
arguments = sys.argv[1:]
assert len(arguments) >= 4 and len(arguments) % 2 == 0
for index in range(0, len(arguments), 2):
    raw_path, runtime = arguments[index:index + 2]
    manifest = json.loads(pathlib.Path(raw_path).read_text(encoding="utf-8"))
    assert manifest["schema"] == "kookie.package-provenance/v1"
    assert manifest["application"] == "kookie"
    assert manifest["target"] == "linux-x86_64"
    assert manifest["channel"] == "dogfood"
    assert manifest["runtime"] == runtime
    assert manifest["signing"] == "unavailable"
    assert manifest["proof"] == "unavailable"
PY
if "$ROOT_DIR/scripts/package_kookie.sh" --target windows-x86_64 --output "$WORK_DIR/windows" >"$WORK_DIR/windows.out" 2>&1; then
  echo 'package smoke: Windows native packaging unexpectedly succeeded' >&2
  exit 1
fi
grep -Fq 'Windows native packaging is blocked' "$WORK_DIR/windows.out"
printf 'KOOKIE package smoke passed: Linux native/JVM archives, presentation %s, checksums, provenance, runtime, and Windows fail-closed gate\n' "$presentation_status"
