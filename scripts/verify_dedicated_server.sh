#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-dedicated-server.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

mkdir -p "$WORK_DIR/core" "$WORK_DIR/content" "$WORK_DIR/session"
for module in core content session; do
  for source_file in "$ROOT_DIR/src/$module/"*.kf; do
    ln -s "$source_file" "$WORK_DIR/$module/$(basename "$source_file")"
  done
done
ln -s "$ROOT_DIR/probes/g5_dedicated_server/main.kf" "$WORK_DIR/main.kf"

jvm_output="$(kof run "$WORK_DIR/main.kf" --target jvm)"
native_output="$(kof run "$WORK_DIR/main.kf" --target native)"
[[ "$jvm_output" == "$native_output" ]]
grep -Fqx 'KOOKIE G5 dedicated headless workload verified' <<<"$jvm_output"
printf '%s\n' "$jvm_output"
