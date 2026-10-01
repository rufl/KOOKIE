#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v kof >/dev/null || {
  echo 'kookie-kofscript-builder: kof is required' >&2
  exit 2
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-kofscript-builder.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

SCRIPT_FILE="$WORK_DIR/main.ks"
: >"$SCRIPT_FILE"

append_script_body() {
  local input_file="$1"
  local line
  local record_line=''
  local joining_record=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == 'package core' ]]; then
      continue
    fi
    if (( joining_record )); then
      record_line+=" $line"
      if [[ "$line" == ')' ]]; then
        printf '%s\n' "$record_line" >>"$SCRIPT_FILE"
        record_line=''
        joining_record=0
      fi
    elif [[ "$line" == record\ *'(' ]]; then
      record_line="$line"
      joining_record=1
    else
      printf '%s\n' "$line" >>"$SCRIPT_FILE"
    fi
  done <"$input_file"
  (( joining_record == 0 )) || {
    echo "kookie-kofscript-builder: unterminated record in $input_file" >&2
    exit 2
  }
  printf '\n' >>"$SCRIPT_FILE"
}

for source_file in \
  "$ROOT_DIR/src/core/bounded_graph.kf" \
  "$ROOT_DIR/src/core/behavior_program.kf" \
  "$ROOT_DIR/src/core/animation_graph.kf" \
  "$ROOT_DIR/src/core/extension_registry.kf" \
  "$ROOT_DIR/src/core/trusted_module_registry.kf" \
  "$ROOT_DIR/src/core/trusted_hook_runtime.kf" \
  "$ROOT_DIR/src/core/kofscript_vm.kf" \
  "$ROOT_DIR/src/core/offline_artifact.kf"; do
  append_script_body "$source_file"
done
append_script_body "$ROOT_DIR/apps/kofscript_builders/main.ks"

kof script "$WORK_DIR/main.ks" "$@"
