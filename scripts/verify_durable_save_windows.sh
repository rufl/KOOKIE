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
report_failure() {
  local phase="$1"
  local expected="$2"
  local actual="$3"
  local log="$4"
  local stderr_log="$5"
  printf 'verify-durable-save-windows: %s exited with status %s (expected %s)\n' \
    "$phase" "$actual" "$expected" >&2
  if [[ -f "$log" ]]; then
    printf '%s:\n' "$log" >&2
    cat "$log" >&2
  fi
  if [[ -f "$stderr_log" ]]; then
    printf '%s:\n' "$stderr_log" >&2
    cat "$stderr_log" >&2
  fi
  exit 1
}
report_output_failure() {
  local phase="$1"
  local log="$2"
  local stderr_log="$3"
  printf 'verify-durable-save-windows: %s output mismatch\n' "$phase" >&2
  if [[ -f "$log" ]]; then
    printf '%s:\n' "$log" >&2
    cat "$log" >&2
  fi
  if [[ -f "$stderr_log" ]]; then
    printf '%s:\n' "$stderr_log" >&2
    cat "$stderr_log" >&2
  fi
  exit 1
}
run_success() {
  local phase="$1"
  local log="$2"
  local stderr_log="$3"
  shift 3
  set +e
  "$@" >"$log" 2>"$stderr_log"
  local status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    report_failure "$phase" 0 "$status" "$log" "$stderr_log"
  fi
}
assert_status() {
  local phase="$1"
  local expected="$2"
  local actual="$3"
  local log="$4"
  local stderr_log="$5"
  if [[ "$actual" -ne "$expected" ]]; then
    report_failure "$phase" "$expected" "$actual" "$log" "$stderr_log"
  fi
}
assert_output() {
  local phase="$1"
  local log="$2"
  local stderr_log="$3"
  local expected="$4"
  if [[ "$(cat "$log")" != "$expected" ]]; then
    report_output_failure "$phase" "$log" "$stderr_log"
  fi
}

run_success baseline baseline.log baseline.stderr run_clean
set +e
run_fault before-file-sync >before-file-sync.log 2>before-file-sync.stderr
before_file_sync_status=$?
set -e
assert_status before-file-sync 84 "$before_file_sync_status" \
  before-file-sync.log before-file-sync.stderr
run_success recover-before-file-sync recover-before-file-sync.log \
  recover-before-file-sync.stderr run_fault recover-before-file-sync
set +e
run_fault before-rename >after-file-sync.log 2>after-file-sync.stderr
after_file_sync_status=$?
set -e
assert_status before-rename 85 "$after_file_sync_status" \
  after-file-sync.log after-file-sync.stderr
run_success recover-after-file-sync recover-after-file-sync.log \
  recover-after-file-sync.stderr run_fault recover-after-file-sync
set +e
run_fault after-rename >after-rename.log 2>after-rename.stderr
after_rename_status=$?
set -e
assert_status after-rename 86 "$after_rename_status" \
  after-rename.log after-rename.stderr
run_success recover recover.log recover.stderr run_fault recover
set +e
run_fault after-directory-sync >after-directory-sync.log \
  2>after-directory-sync.stderr
after_directory_status=$?
set -e
assert_status after-directory-sync 87 "$after_directory_status" \
  after-directory-sync.log after-directory-sync.stderr
run_success recover-after-directory recover-after-directory.log \
  recover-after-directory.stderr run_fault recover-after-directory
printf 'torn' >durable-save.dat.kookie-stage
run_success torn-stage torn.log torn.stderr run_fault torn-stage

for log in baseline recover-before-file-sync recover-after-file-sync recover \
    recover-after-directory torn; do
  tr -d '\r' <"$log.log" >"$log.normalized"
done
mapfile -t baseline_lines <baseline.normalized
if [[ "${#baseline_lines[@]}" -eq 1 &&
    "${baseline_lines[0]}" == "durable-baseline-ok" ]]; then
  :
elif [[ "${#baseline_lines[@]}" -eq 2 &&
    "${baseline_lines[0]}" == "durable-baseline-ok" &&
    "${baseline_lines[1]}" == "durable-symlink-check-skipped" ]]; then
  echo "Windows symlink/reparse fixture skipped: unavailable in this Wine environment" >&2
else
  report_output_failure baseline baseline.log baseline.stderr
fi
assert_output recover-before-file-sync recover-before-file-sync.normalized \
  recover-before-file-sync.stderr durable-before-file-sync-recovered
assert_output recover-after-file-sync recover-after-file-sync.normalized \
  recover-after-file-sync.stderr durable-after-file-sync-recovered
assert_output recover recover.normalized recover.stderr \
  durable-after-rename-recovered
assert_output recover-after-directory recover-after-directory.normalized \
  recover-after-directory.stderr durable-after-directory-sync-recovered
assert_output torn-stage torn.normalized torn.stderr \
  durable-torn-stage-discarded
test -s durable-save.dat
test ! -e durable-save.dat.kookie-stage
EOF_RUN
chmod 755 "$WORK_DIR/run-wine.sh"
mkdir "$WORK_DIR/wine-prefix"
set +e
WINEPREFIX="$WORK_DIR/wine-prefix" \
  WINEARCH=win64 \
  WINEDEBUG=-all \
  wineboot --init >/dev/null
wineboot_status=$?
set -e
if [[ "$wineboot_status" -ne 0 ]]; then
  printf 'verify-durable-save-windows: wineboot returned %s; validating the prefix with the executable\n' \
    "$wineboot_status" >&2
fi
(
  cd "$WORK_DIR"
  WINEPREFIX="$WORK_DIR/wine-prefix" \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES='mscoree,mshtml=' \
    ./run-wine.sh
)
echo 'KOOKIE Windows native adapter crash-durable save publication verified'
