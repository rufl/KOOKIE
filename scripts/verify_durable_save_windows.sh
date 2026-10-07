#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in tr wine zig; do
  command -v "$tool" >/dev/null || {
    echo "verify-durable-save-windows: $tool is required" >&2
    exit 2
  }
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-durable-save-windows.XXXXXX")"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

zig cc -target x86_64-windows-gnu -std=c11 -Wall -Wextra -Werror -O2 -s -fno-ident \
  "$ROOT_DIR/native/kookie_persistence_adapter_test.c" \
  "$ROOT_DIR/native/kookie_persistence_adapter.c" \
  -o "$WORK_DIR/durable-save.exe"

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
grep -Fxq durable-baseline-ok baseline.normalized
grep -Fxq durable-before-file-sync-recovered recover-before-file-sync.normalized
grep -Fxq durable-after-file-sync-recovered recover-after-file-sync.normalized
grep -Fxq durable-after-rename-recovered recover.normalized
grep -Fxq durable-after-directory-sync-recovered recover-after-directory.normalized
grep -Fxq durable-torn-stage-discarded torn.normalized
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
