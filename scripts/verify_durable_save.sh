#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v cc >/dev/null || { echo "cc is required" >&2; exit 1; }
command -v kof >/dev/null || { echo "kof is required" >&2; exit 1; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-durable-save.XXXXXX")"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM
mkdir -p "$WORK_DIR/core" "$WORK_DIR/lib" "$WORK_DIR/native"
for source_file in "$ROOT_DIR/src/core/"*.kf; do
  ln -s "$source_file" "$WORK_DIR/core/$(basename "$source_file")"
done
cp -- "$ROOT_DIR/probes/g5_durable_save/main.kf" "$WORK_DIR/main.kf"
cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared \
  "$ROOT_DIR/native/kookie_persistence_adapter.c" \
  -o "$WORK_DIR/lib/libkookie_persistence_adapter.so"
(
  cd "$WORK_DIR"
  kof build main.kf --target native --output native
  env -u KOOKIE_DURABLE_FAULT ./native/Default/Main >baseline.log
  set +e
  KOOKIE_DURABLE_FAULT=before-file-sync ./native/Default/Main >before-file-sync.log 2>&1
  before_file_sync_status=$?
  set -e
  [[ "$before_file_sync_status" -eq 84 ]]
  KOOKIE_DURABLE_FAULT=recover-before-file-sync ./native/Default/Main >recover-before-file-sync.log
  set +e
  KOOKIE_DURABLE_FAULT=before-rename ./native/Default/Main >after-file-sync.log 2>&1
  after_file_sync_status=$?
  set -e
  [[ "$after_file_sync_status" -eq 85 ]]
  KOOKIE_DURABLE_FAULT=recover-after-file-sync ./native/Default/Main >recover-after-file-sync.log
  set +e
  KOOKIE_DURABLE_FAULT=after-rename ./native/Default/Main >after-rename.log 2>&1
  after_rename_status=$?
  set -e
  [[ "$after_rename_status" -eq 86 ]]
  KOOKIE_DURABLE_FAULT=recover ./native/Default/Main >recover.log
  set +e
  KOOKIE_DURABLE_FAULT=after-directory-sync ./native/Default/Main >after-directory-sync.log 2>&1
  after_directory_status=$?
  set -e
  [[ "$after_directory_status" -eq 87 ]]
  KOOKIE_DURABLE_FAULT=recover-after-directory ./native/Default/Main >recover-after-directory.log
  printf 'torn' >durable-save.dat.kookie-stage
  KOOKIE_DURABLE_FAULT=torn-stage ./native/Default/Main >torn.log
  [[ "$(cat baseline.log)" == "durable-baseline-ok" ]]
  [[ "$(cat recover-before-file-sync.log)" == "durable-before-file-sync-recovered" ]]
  [[ "$(cat recover-after-file-sync.log)" == "durable-after-file-sync-recovered" ]]
  [[ "$(cat recover.log)" == "durable-after-rename-recovered" ]]
  [[ "$(cat recover-after-directory.log)" == "durable-after-directory-sync-recovered" ]]
  [[ "$(cat torn.log)" == "durable-torn-stage-discarded" ]]
  [[ -s durable-save.dat ]]
  [[ ! -e durable-save.dat.kookie-stage ]]
)
echo "KOOKIE crash-durable save publication verified"
