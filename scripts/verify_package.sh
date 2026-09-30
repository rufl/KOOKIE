#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-package-smoke.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM
command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }
SIGNING_KEY="$WORK_DIR/release-signing.pem"
openssl genpkey -algorithm ED25519 -out "$SIGNING_KEY" 2>/dev/null
chmod 600 "$SIGNING_KEY"
export KOOKIE_SIGNING_KEY="$SIGNING_KEY"
export KOOKIE_ALLOW_DIRTY_PACKAGE=1
verify_signature_set() {
  local archive="$1"
  local manifest="$2"
  local release_dir
  release_dir="$(dirname "$manifest")"
  local public_key="${manifest%.json}.pub.pem"
  openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
    -in "$archive" -sigfile "$archive.sig" >/dev/null
  openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
    -in "$manifest" -sigfile "$manifest.sig" >/dev/null
  openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
    -in "$release_dir/SHA256SUMS" \
    -sigfile "$release_dir/SHA256SUMS.sig" >/dev/null
}


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
PUBLIC_KEY="$WORK_DIR/release/kookie-0.1.0-dogfood.smoke-linux-x86_64.pub.pem"
ARCHIVE_SIGNATURE="$ARCHIVE.sig"
MANIFEST_SIGNATURE="$MANIFEST.sig"
CHECKSUMS_SIGNATURE="$WORK_DIR/release/SHA256SUMS.sig"
test -f "$PUBLIC_KEY" -a -f "$ARCHIVE_SIGNATURE" -a \
  -f "$MANIFEST_SIGNATURE" -a -f "$CHECKSUMS_SIGNATURE"
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$ARCHIVE" -sigfile "$ARCHIVE_SIGNATURE" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$MANIFEST" -sigfile "$MANIFEST_SIGNATURE" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$WORK_DIR/release/SHA256SUMS" -sigfile "$CHECKSUMS_SIGNATURE" >/dev/null
WRONG_KEY="$WORK_DIR/wrong-signing.pem"
WRONG_PUBLIC_KEY="$WORK_DIR/wrong-signing.pub.pem"
openssl genpkey -algorithm ED25519 -out "$WRONG_KEY" 2>/dev/null
openssl pkey -in "$WRONG_KEY" -pubout -out "$WRONG_PUBLIC_KEY" 2>/dev/null
if openssl pkeyutl -verify -rawin -pubin -inkey "$WRONG_PUBLIC_KEY" \
   -in "$ARCHIVE" -sigfile "$ARCHIVE_SIGNATURE" >/dev/null 2>&1; then
  echo 'package smoke: archive signature accepted an unrelated key' >&2
  exit 1
fi
mkdir "$WORK_DIR/extracted"
tar -xzf "$ARCHIVE" -C "$WORK_DIR/extracted"
BINARY="$WORK_DIR/extracted/kookie-0.1.0-dogfood.smoke-linux-x86_64/kookie"
test -f "$BINARY"
PACKAGE_ROOT="$WORK_DIR/extracted/kookie-0.1.0-dogfood.smoke-linux-x86_64"
SERVER="$PACKAGE_ROOT/kookie-server"
SERVER_BINARY="$PACKAGE_ROOT/kookie-server.bin"
HEADLESS_ADAPTER="$PACKAGE_ROOT/lib/libkookie_headless_adapter.so"
PERSISTENCE_ADAPTER="$PACKAGE_ROOT/lib/libkookie_persistence_adapter.so"
SIMD_BENCHMARK="$PACKAGE_ROOT/kookie-simd-bench"
SIMD_BINARY="$PACKAGE_ROOT/kookie-simd-bench.bin"
SIMD_LIBRARY="$PACKAGE_ROOT/lib/libkookie_simd_dispatch.so"
COOKER="$PACKAGE_ROOT/kookie-cooker"
COOKER_BINARY="$PACKAGE_ROOT/kookie-cooker.bin"
test -x "$SERVER" -a -x "$SERVER_BINARY"
test -x "$COOKER" -a -x "$COOKER_BINARY"
test -x "$SIMD_BENCHMARK" -a -x "$SIMD_BINARY"
test -f "$HEADLESS_ADAPTER" -a -f "$PERSISTENCE_ADAPTER" -a \
  -f "$SIMD_LIBRARY"
test -f "$PACKAGE_ROOT/LICENSE"
test -f "$PACKAGE_ROOT/THIRD_PARTY_NOTICES.txt"
test -f "$PACKAGE_ROOT/RELEASE_PUBLIC_KEY.pem"
grep -Fq 'MIT License' "$PACKAGE_ROOT/LICENSE"
grep -Fq 'SDL_mixer 3.2.4' "$PACKAGE_ROOT/THIRD_PARTY_NOTICES.txt"
grep -Fq 'license_status=MIT' "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'dependency_policy=permissive-distributed-only' "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'dedicated_server=bounded-headless-workload-with-runtime-telemetry' \
  "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'kof_source_commit=bf17ac7e736471c8a04b4153e5b0f607be75e70c' \
  "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Eq '^kof_compiler_sha256=[0-9a-f]{64}$' \
  "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'release_signing=ed25519' "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'crash_durable_save=staged-validated-fsync-rename-directory-fsync' \
  "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'replay_admission=identity-bound-checksummed-v3' \
  "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'simd_benchmark=kof-buffer-u8-runtime-dispatch' \
  "$PACKAGE_ROOT/PROVENANCE.txt"
grep -Fq 'content_cooker=native-bounded-intake-cli' \
  "$PACKAGE_ROOT/PROVENANCE.txt"
SERVER_LOG="$WORK_DIR/server.log"
KOOKIE_SERVER_WARMUP_TICKS=64 \
KOOKIE_SERVER_TICKS=128 \
KOOKIE_SERVER_RSS_SAMPLE_TICKS=32 \
  "$SERVER" >"$SERVER_LOG"
grep -Fq 'KOOKIE G5 dedicated headless server' "$SERVER_LOG"
grep -Fq 'graphics=none' "$SERVER_LOG"
grep -Fq 'simulation-budget-pass' "$SERVER_LOG"
grep -Fq 'rss-plateau' "$SERVER_LOG"
grep -Fq 'resource-plateau=true' "$SERVER_LOG"
python3 - "$SERVER_LOG" <<'PY'
import pathlib
import sys

lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
def paired(label):
    index = lines.index(label)
    return lines[index + 1]

assert paired("warmup-ticks") == "64"
assert paired("measured-ticks") == "128"
assert paired("simulation-budget-pass") == "true"
assert paired("rss-samples") == "5"
assert paired("rss-plateau") == "true"
assert paired("realtime") == "false"
PY
SIMD_LOG="$WORK_DIR/simd.log"
"$SIMD_BENCHMARK" >"$SIMD_LOG"
grep -Fqx 'KOOKIE G6 Kof Buffer SIMD benchmark' "$SIMD_LOG"
grep -Fqx 'scalar-total=16844324864' "$SIMD_LOG"
grep -Fqx 'simd-total=16844324864' "$SIMD_LOG"
grep -Eq '^simd-path=[1-4]$' "$SIMD_LOG"
grep -Eq '^scalar-ns=[1-9][0-9]*$' "$SIMD_LOG"
grep -Eq '^simd-ns=[1-9][0-9]*$' "$SIMD_LOG"
grep -Eq '^selected-route=(scalar|simd)$' "$SIMD_LOG"
WAV_SOURCE="$WORK_DIR/source.wav"
WAV_COOKED="$WORK_DIR/cooked.wav"
WAV_REOPENED="$WORK_DIR/reopened.wav"
python3 - "$WAV_SOURCE" <<'PY'
import pathlib
import struct
import sys

samples = struct.pack("<hhhh", -32768, -1, 0, 32767)
fmt = struct.pack("<HHIIHH", 1, 2, 48000, 192000, 4, 16)
chunks = (
    b"JUNK" + struct.pack("<I", 3) + b"\x01\x02\x03\x00"
    + b"fmt " + struct.pack("<I", len(fmt)) + fmt
    + b"LIST" + struct.pack("<I", 4) + b"INFO"
    + b"data" + struct.pack("<I", len(samples)) + samples
)
body = b"WAVE" + chunks
pathlib.Path(sys.argv[1]).write_bytes(
    b"RIFF" + struct.pack("<I", len(body)) + body)
PY
COOKER_LOG="$WORK_DIR/cooker.log"
if ! "$COOKER" cook wav "$WAV_SOURCE" "$WAV_COOKED" \
   >"$COOKER_LOG" 2>&1; then
  cat "$COOKER_LOG" >&2
  echo 'package smoke: native cooker rejected valid PCM WAVE' >&2
  exit 1
fi
grep -Fq 'cooked kind=8' "$COOKER_LOG"
grep -Fq 'sample-rate=48000 channels=2 source-bits=16 frames=2' \
  "$COOKER_LOG"
if ! "$COOKER" cook wav "$WAV_COOKED" "$WAV_REOPENED" \
   >"$WORK_DIR/cooker-reopen.log" 2>&1; then
  cat "$WORK_DIR/cooker-reopen.log" >&2
  echo 'package smoke: native cooker rejected its canonical PCM WAVE' >&2
  exit 1
fi
cmp "$WAV_COOKED" "$WAV_REOPENED"
python3 - "$WAV_COOKED" <<'PY'
import pathlib
import struct
import sys

payload = pathlib.Path(sys.argv[1]).read_bytes()
assert len(payload) == 52
assert payload[:4] == b"RIFF" and payload[8:12] == b"WAVE"
assert payload[12:16] == b"fmt " and payload[36:40] == b"data"
assert struct.unpack_from("<HHIIHH", payload, 20) == (
    1, 2, 48000, 192000, 4, 16)
assert struct.unpack_from("<hhhh", payload, 44) == (-32768, -1, 0, 32767)
PY
printf 'RIFF' >"$WORK_DIR/invalid.wav"
if "$COOKER" cook wav "$WORK_DIR/invalid.wav" "$WORK_DIR/rejected.wav" \
   >"$WORK_DIR/cooker-invalid.log" 2>&1; then
  echo 'package smoke: native cooker accepted a truncated WAV' >&2
  exit 1
fi
grep -Fq 'cook-rejected diagnostic=3 source=1' \
  "$WORK_DIR/cooker-invalid.log"
for headless_binary in \
  "$SERVER_BINARY" "$HEADLESS_ADAPTER" "$PERSISTENCE_ADAPTER" "$COOKER_BINARY" \
  "$SIMD_BINARY" "$SIMD_LIBRARY"; do
  if ldd "$headless_binary" 2>/dev/null | grep -Eq 'SDL|Vulkan|X11|Wayland'; then
    echo 'package smoke: headless component acquired a graphics dependency' >&2
    exit 1
  fi
done
"$BINARY" --package-smoke 2>"$WORK_DIR/runtime.err" | grep -Fq 'KOOKIE G1 authoritative shooter verified'

if "$ROOT_DIR/scripts/package_kookie.sh" --runtime jvm \
   --output "$WORK_DIR/jvm-release" >"$WORK_DIR/jvm.out" 2>&1; then
  echo 'package smoke: non-permissive JVM runtime was accepted for distribution' >&2
  exit 1
fi
grep -Fq 'unsupported distributable runtime: jvm' "$WORK_DIR/jvm.out"
if env -u KOOKIE_SIGNING_KEY "$ROOT_DIR/scripts/package_kookie.sh" \
   --output "$WORK_DIR/unsigned-release" >"$WORK_DIR/unsigned.out" 2>&1; then
  echo 'package smoke: unsigned release was accepted' >&2
  exit 1
fi
grep -Fq 'KOOKIE_SIGNING_KEY must name a regular Ed25519 private key' \
  "$WORK_DIR/unsigned.out"

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
  verify_signature_set "$PRESENTATION_ARCHIVE" "$PRESENTATION_MANIFEST"
  mkdir "$WORK_DIR/presentation-extracted"
  tar -xzf "$PRESENTATION_ARCHIVE" -C "$WORK_DIR/presentation-extracted"
  PRESENTATION_ROOT="$WORK_DIR/presentation-extracted/kookie-0.1.0-dogfood.presentation-smoke-linux-x86_64"
  test -x "$PRESENTATION_ROOT/kookie"
  test -x "$PRESENTATION_ROOT/kookie.bin"
  test -x "$PRESENTATION_ROOT/kookie-smoke.bin"
  test -x "$PRESENTATION_ROOT/kookie-server"
  test -x "$PRESENTATION_ROOT/kookie-server.bin"
  test -f "$PRESENTATION_ROOT/build/libkookie_sdl_adapter.so"
  test -f "$PRESENTATION_ROOT/lib/libkookie_headless_adapter.so"
  test -x "$PRESENTATION_ROOT/kookie-simd-bench"
  test -x "$PRESENTATION_ROOT/kookie-simd-bench.bin"
  test -f "$PRESENTATION_ROOT/lib/libkookie_simd_dispatch.so"
  test -f "$PRESENTATION_ROOT/build/g0_triangle.vert.spv"
  test -f "$PRESENTATION_ROOT/build/g5_triangle_instance.vert.spv"
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
  KOOKIE_SERVER_WARMUP_TICKS=16 \
  KOOKIE_SERVER_TICKS=32 \
  KOOKIE_SERVER_RSS_SAMPLE_TICKS=16 \
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
    assert manifest["schema"] == "kookie.package-provenance/v2"
    assert manifest["application"] == "kookie"
    assert manifest["target"] == "linux-x86_64"
    assert manifest["channel"] == "dogfood"
    assert manifest["runtime"] == runtime
    assert manifest["signing"] == "ed25519"
    assert manifest["proof"] == "ed25519-signature-set"
    assert manifest["signature_encoding"] == "binary"
    assert len(manifest["source_commit"]) == 40
    assert manifest["source_tree_state"] in {"clean", "dirty-allowed"}
    assert manifest["kof_version"] == "kof 0.5.0-beta"
    assert len(manifest["kof_archive_sha256"]) == 64
    assert manifest["kof_source_commit"] == "bf17ac7e736471c8a04b4153e5b0f607be75e70c"
    assert len(manifest["kof_compiler_sha256"]) == 64
    assert len(manifest["public_key_sha256"]) == 64
    assert manifest["archive_signature"] == manifest["archive"] + ".sig"
    assert manifest["checksums_signature"] == "SHA256SUMS.sig"
    assert manifest["dedicated_server"] is True
    assert manifest["simd_benchmark"] is True
    assert manifest["content_cooker"] is True
    release_root = (
        "https://github.com/rufl/KOOKIE/releases/download/"
        + manifest["version"])
    assert manifest["url"] == release_root + "/" + manifest["archive"]
    assert manifest["manifest_url"] == release_root + "/" + pathlib.Path(raw_path).name
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
  verify_signature_set "$WINDOWS_ARCHIVE" "$WINDOWS_MANIFEST"
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
assert manifest["schema"] == "kookie.package-provenance/v2"
assert manifest["application"] == "kookie"
assert manifest["target"] == "windows-x86_64"
assert manifest["runtime"] == "native"
assert manifest["signing"] == "ed25519"
assert manifest["proof"] == "ed25519-signature-set"
PY
  windows_status="archive"
fi
printf 'KOOKIE package smoke passed: Linux native archive, presentation %s, Windows %s, permissive-license policy, checksums, provenance, and runtime\n' "$presentation_status" "$windows_status"
