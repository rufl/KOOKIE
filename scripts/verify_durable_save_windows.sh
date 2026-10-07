#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in python3 tr wine zig; do
  command -v "$tool" >/dev/null || {
    echo "verify-durable-save-windows: $tool is required" >&2
    exit 2
  }
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-durable-save-windows.XXXXXX")"
cleanup() {
  if [[ -d "$WORK_DIR/wine-prefix" ]] && command -v wineserver >/dev/null; then
    WINEPREFIX="$WORK_DIR/wine-prefix" WINEDEBUG=-all \
      wineserver -k >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

zig cc -target x86_64-windows-gnu -std=c11 -Wall -Wextra -Werror -O2 -s -fno-ident \
  -Wl,/subsystem:console -Wl,/Brepro \
  "$ROOT_DIR/native/kookie_persistence_adapter_test.c" \
  "$ROOT_DIR/native/kookie_persistence_adapter.c" \
  -o "$WORK_DIR/durable-save.exe"

python3 - "$WORK_DIR/durable-save.exe" <<'PY'
import pathlib
import struct
import sys

exe = pathlib.Path(sys.argv[1]).read_bytes()
if exe[:2] != b"MZ" or len(exe) < 0x40:
    raise SystemExit("verify-durable-save-windows: missing DOS header")
pe = struct.unpack_from("<I", exe, 0x3C)[0]
if exe[pe:pe + 4] != b"PE\0\0":
    raise SystemExit("verify-durable-save-windows: missing PE signature")
optional = pe + 24
if struct.unpack_from("<H", exe, optional)[0] != 0x20B:
    raise SystemExit("verify-durable-save-windows: not PE32+")
if struct.unpack_from("<H", exe, optional + 68)[0] != 3:
    raise SystemExit("verify-durable-save-windows: not a console image")
PY

cat >"$WORK_DIR/run-wine.sh" <<'EOF_RUN'
#!/usr/bin/env bash
set -euo pipefail

run_clean() {
  env -u KOOKIE_DURABLE_FAULT wine ./durable-save.exe
}
run_fault() {
  KOOKIE_DURABLE_FAULT="$1" wine ./durable-save.exe
}

run_clean >baseline.log
set +e
run_fault before-file-sync >before-file-sync.log 2>&1
before_file_sync_status=$?
set -e
[[ "$before_file_sync_status" -eq 84 ]]
run_fault recover-before-file-sync >recover-before-file-sync.log
set +e
run_fault before-rename >after-file-sync.log 2>&1
after_file_sync_status=$?
set -e
[[ "$after_file_sync_status" -eq 85 ]]
run_fault recover-after-file-sync >recover-after-file-sync.log
set +e
run_fault after-rename >after-rename.log 2>&1
after_rename_status=$?
set -e
[[ "$after_rename_status" -eq 86 ]]
run_fault recover >recover.log
set +e
run_fault after-directory-sync >after-directory-sync.log 2>&1
after_directory_status=$?
set -e
[[ "$after_directory_status" -eq 87 ]]
run_fault recover-after-directory >recover-after-directory.log
printf 'torn' >durable-save.dat.kookie-stage
run_fault torn-stage >torn.log

for log in baseline recover-before-file-sync recover-after-file-sync recover \
    recover-after-directory torn; do
  tr -d '\r' <"$log.log" >"$log.normalized"
done
mapfile -t baseline_lines <baseline.normalized
if [[ "${#baseline_lines[@]}" -eq 1 ]]; then
  [[ "${baseline_lines[0]}" == "durable-baseline-ok" ]]
elif [[ "${#baseline_lines[@]}" -eq 2 ]]; then
  [[ "${baseline_lines[0]}" == "durable-baseline-ok" && "${baseline_lines[1]}" == "durable-symlink-check-skipped" ]]
else
  false
fi
if [[ "${#baseline_lines[@]}" -eq 2 ]]; then
  echo "Windows symlink/reparse fixture skipped: Wine privilege unavailable" >&2
fi
[[ "$(cat recover-before-file-sync.normalized)" == "durable-before-file-sync-recovered" ]]
[[ "$(cat recover-after-file-sync.normalized)" == "durable-after-file-sync-recovered" ]]
[[ "$(cat recover.normalized)" == "durable-after-rename-recovered" ]]
[[ "$(cat recover-after-directory.normalized)" == "durable-after-directory-sync-recovered" ]]
[[ "$(cat torn.normalized)" == "durable-torn-stage-discarded" ]]
test -s durable-save.dat
test ! -e durable-save.dat.kookie-stage
EOF_RUN
chmod 755 "$WORK_DIR/run-wine.sh"
mkdir "$WORK_DIR/wine-prefix"
(
  cd "$WORK_DIR"
  WINEPREFIX="$WORK_DIR/wine-prefix" \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES='mscoree,mshtml=' \
    ./run-wine.sh
)
echo 'KOOKIE Windows native adapter crash-durable save publication verified'
