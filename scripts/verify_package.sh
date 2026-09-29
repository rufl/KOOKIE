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
PACKAGE_ROOT="$WORK_DIR/extracted/kookie-0.1.0-dogfood.smoke-linux-x86_64"
SERVER="$PACKAGE_ROOT/kookie-server"
SERVER_BINARY="$PACKAGE_ROOT/kookie-server.bin"
test -x "$SERVER" -a -x "$SERVER_BINARY"
test -f "$PACKAGE_ROOT/LICENSE"
test -f "$PACKAGE_ROOT/THIRD_PARTY_NOTICES.txt"
grep -Fq 'MIT License' "$PACKAGE_ROOT/LICENSE"
grep -Fq 'SDL_mixer 3.2.4' "$PACKAGE_ROOT/THIRD_PARTY_NOTICES.txt"
grep -Fq 'license_status=MIT' "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'dependency_policy=permissive-distributed-only' "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'dedicated_server=bounded-headless-workload' "$PACKAGE_ROOT/PROVENANCE.txt"
SERVER_OUTPUT="$("$SERVER")"
grep -Fq 'KOOKIE G5 dedicated headless server' <<<"$SERVER_OUTPUT"
grep -Fq 'graphics=none' <<<"$SERVER_OUTPUT"
grep -Fq 'resource-plateau=true' <<<"$SERVER_OUTPUT"
if ldd "$SERVER_BINARY" 2>/dev/null | grep -Eq 'SDL|Vulkan|X11|Wayland'; then
  echo 'package smoke: dedicated server acquired a graphics dependency' >&2
  exit 1
fi
"$BINARY" --package-smoke 2>"$WORK_DIR/runtime.err" | grep -Fq 'KOOKIE G1 authoritative shooter verified'

if "$ROOT_DIR/scripts/package_kookie.sh" --runtime jvm \
   --output "$WORK_DIR/jvm-release" >"$WORK_DIR/jvm.out" 2>&1; then
  echo 'package smoke: non-permissive JVM runtime was accepted for distribution' >&2
  exit 1
fi
grep -Fq 'unsupported distributable runtime: jvm' "$WORK_DIR/jvm.out"

presentation_manifest_args=()
presentation_status="dependency fail-closed gate"
if command -v glslc >/dev/null &&
   command -v pkg-config >/dev/null &&
   pkg-config --exists sdl3 sdl3-mixer; then
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
  test -x "$PRESENTATION_ROOT/kookie-smoke.bin"
  test -x "$PRESENTATION_ROOT/kookie-server"
  test -x "$PRESENTATION_ROOT/kookie-server.bin"
  test -f "$PRESENTATION_ROOT/build/libkookie_sdl_adapter.so"
  test -f "$PRESENTATION_ROOT/build/g0_triangle.vert.spv"
  test -f "$PRESENTATION_ROOT/build/g0_triangle.frag.spv"
  test -f "$PRESENTATION_ROOT/THIRD_PARTY_NOTICES.txt"
  test -n "$(find "$PRESENTATION_ROOT/lib" -maxdepth 1 -name 'libSDL3.so*' -print -quit)"
  test -n "$(find "$PRESENTATION_ROOT/lib" -maxdepth 1 -name 'libSDL3_mixer.so*' -print -quit)"
  PRESENTATION_OUTPUT="$("$PRESENTATION_ROOT/kookie" --package-smoke \
    2>"$WORK_DIR/presentation-runtime.err")" || {
      cat "$WORK_DIR/presentation-runtime.err" >&2
      exit 1
    }
  grep -Fq 'KOOKIE G1 authoritative shooter verified' <<<"$PRESENTATION_OUTPUT"
  "$PRESENTATION_ROOT/kookie-server" |
    grep -Fq 'resource-plateau=true'
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
  grep -Eq 'glslc is required|pkg-config is required|SDL3 or SDL_mixer development files are required' \
    "$WORK_DIR/presentation-unavailable.out"
fi
python3 - "$MANIFEST" native \
  "${presentation_manifest_args[@]}" <<'PY'
import json, pathlib, sys
arguments = sys.argv[1:]
assert len(arguments) >= 2 and len(arguments) % 2 == 0
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
    assert manifest["dedicated_server"] is True
PY
if env -u KOOKIE_WINDOWS_SDL_PREFIX -u KOOKIE_WINDOWS_SDL_MIXER_PREFIX \
   "$ROOT_DIR/scripts/package_kookie.sh" --target windows-x86_64 \
   --output "$WORK_DIR/windows" >"$WORK_DIR/windows.out" 2>&1; then
  echo 'package smoke: Windows packaging ignored missing SDL dependencies' >&2
  exit 1
fi
grep -Fq 'KOOKIE_WINDOWS_SDL_PREFIX' "$WORK_DIR/windows.out"
windows_status="dependency fail-closed gate"
if [[ -n "${KOOKIE_WINDOWS_SDL_PREFIX:-}" &&
      -n "${KOOKIE_WINDOWS_SDL_MIXER_PREFIX:-}" ]]; then
  command -v unzip >/dev/null || {
    echo 'package smoke: unzip is required to inspect the Windows archive' >&2
    exit 2
  }
  KOOKIE_VERSION=0.1.0-dogfood.windows-smoke \
  KOOKIE_BUILD_ID=package-windows-smoke \
  "$ROOT_DIR/scripts/package_kookie.sh" --runtime native \
    --target windows-x86_64 --output "$WORK_DIR/windows-release"
  (
    cd "$WORK_DIR/windows-release"
    sha256sum --check SHA256SUMS >/dev/null
  )
  WINDOWS_ARCHIVE="$WORK_DIR/windows-release/kookie-0.1.0-dogfood.windows-smoke-windows-x86_64.zip"
  WINDOWS_MANIFEST="$WORK_DIR/windows-release/kookie-0.1.0-dogfood.windows-smoke-windows-x86_64.json"
  test -f "$WINDOWS_ARCHIVE" -a -f "$WINDOWS_MANIFEST"
  mkdir "$WORK_DIR/windows-extracted"
  unzip -q "$WINDOWS_ARCHIVE" -d "$WORK_DIR/windows-extracted"
  WINDOWS_ROOT="$WORK_DIR/windows-extracted/kookie-0.1.0-dogfood.windows-smoke-windows-x86_64"
  test -f "$WINDOWS_ROOT/kookie.exe"
  test -f "$WINDOWS_ROOT/SDL3.dll"
  test -f "$WINDOWS_ROOT/SDL3_mixer.dll"
  test -f "$WINDOWS_ROOT/LICENSE"
  test -f "$WINDOWS_ROOT/THIRD_PARTY_NOTICES.txt"
  grep -Fq 'windows_status=native-sdl-shell' "$WINDOWS_ROOT/PROVENANCE.txt"
  python3 - "$WINDOWS_MANIFEST" <<'PY'
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert manifest["schema"] == "kookie.package-provenance/v1"
assert manifest["application"] == "kookie"
assert manifest["target"] == "windows-x86_64"
assert manifest["runtime"] == "native"
assert manifest["signing"] == "unavailable"
assert manifest["proof"] == "unavailable"
PY
  windows_status="archive"
fi
printf 'KOOKIE package smoke passed: Linux native archive, presentation %s, Windows %s, permissive-license policy, checksums, provenance, and runtime\n' "$presentation_status" "$windows_status"
