#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in kof java javac zig wine; do
  command -v "$tool" >/dev/null || {
    echo "verify-pe-durable-save: $tool is required" >&2
    exit 2
  }
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-pe-durable-save.XXXXXX")"
WINE_PREFIX="$WORK_DIR/wine-prefix"
cleanup() {
  if command -v wineserver >/dev/null; then
    WINEPREFIX="$WINE_PREFIX" WINEDEBUG=-all \
      wineserver -k >/dev/null 2>&1 || true
  fi
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM

cp -- "$ROOT_DIR/probes/g7_pe_durable_save/main.kf" "$WORK_DIR/main.kf"
mkdir -p "$WORK_DIR"/{content,core,session,ui,lib,build}
for module in content core session ui; do
  for source in "$ROOT_DIR/src/$module/"*.kf; do
    ln -s -- "$source" "$WORK_DIR/$module/$(basename "$source")"
  done
done
cp -- "$ROOT_DIR/probes/shared/pe_durable_save_coordinator.kf" \
  "$WORK_DIR/session/pe_durable_save_coordinator.kf"

KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
  "$ROOT_DIR/scripts/kof_pe_build.sh" "$WORK_DIR" \
  --output "$WORK_DIR/pe" --library >/dev/null
zig cc -target x86_64-windows-gnu -std=c11 \
  -Wall -Wextra -Werror -O2 -fno-ident -I "$ROOT_DIR/native" \
  -c "$ROOT_DIR/native/kookie_persistence_adapter.c" \
  -o "$WORK_DIR/persistence.obj"
zig cc -target x86_64-windows-gnu -s -fno-ident \
  -Wl,/subsystem:console -Wl,/Brepro \
  "$ROOT_DIR/native/kookie_pe_entry.c" \
  "$WORK_DIR/pe/kof-module.obj" "$WORK_DIR/persistence.obj" \
  -o "$WORK_DIR/kookie.exe"

python3 - "$WORK_DIR/kookie.exe" <<'PY'
import pathlib
import struct
import sys

exe = pathlib.Path(sys.argv[1]).read_bytes()
if exe[:2] != b"MZ" or len(exe) < 0x40:
    raise SystemExit("verify-pe-durable-save: missing DOS header")
pe = struct.unpack_from("<I", exe, 0x3C)[0]
if exe[pe:pe + 4] != b"PE\0\0":
    raise SystemExit("verify-pe-durable-save: missing PE signature")
optional = pe + 24
if struct.unpack_from("<H", exe, optional)[0] != 0x20B:
    raise SystemExit("verify-pe-durable-save: not PE32+")
if struct.unpack_from("<H", exe, optional + 68)[0] != 3:
    raise SystemExit("verify-pe-durable-save: not a console image")
PY

output="$(
  cd "$WORK_DIR"
  WINEPREFIX="$WINE_PREFIX" WINEDEBUG=-all wine ./kookie.exe
)"
[[ "$output" == *"KOOKIE G7 PE durable save verified"* ]] || {
  printf '%s\n' "$output" >&2
  echo 'verify-pe-durable-save: marker missing' >&2
  exit 1
}
printf '%s\n' "$output"
