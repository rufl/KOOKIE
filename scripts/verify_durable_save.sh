#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v cc >/dev/null || { echo "cc is required" >&2; exit 1; }
command -v kof >/dev/null || { echo "kof is required" >&2; exit 1; }

WORK_DIR="$(mktemp -d "$ROOT_DIR/build/g5-durable-save.XXXXXX")"
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
  ./native/Default/Main >baseline.log
  KOOKIE_DURABLE_FAULT=before-rename ./native/Default/Main >before.log
  set +e
  KOOKIE_DURABLE_FAULT=after-rename ./native/Default/Main >after.log 2>&1
  after_status=$?
  set -e
  [[ "$after_status" -eq 86 ]]
  KOOKIE_DURABLE_FAULT=recover ./native/Default/Main >recover.log
  printf 'torn' >durable-save.dat.kookie-stage
  KOOKIE_DURABLE_FAULT=torn-stage ./native/Default/Main >torn.log
  [[ "$(cat baseline.log)" == "durable-baseline-ok" ]]
  [[ "$(cat before.log)" == "durable-before-rename-recovered" ]]
  [[ "$(cat recover.log)" == "durable-after-rename-recovered" ]]
  [[ "$(cat torn.log)" == "durable-torn-stage-discarded" ]]
  [[ -s durable-save.dat ]]
  [[ ! -e durable-save.dat.kookie-stage ]]
)
echo "KOOKIE crash-durable save publication verified"
