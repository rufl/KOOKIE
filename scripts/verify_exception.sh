#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
command -v kof >/dev/null || { echo "kof is required" >&2; exit 1; }

work_dir="$(mktemp -d -t kookie-exception-XXXXXX)"
trap 'rm -rf "$work_dir"' EXIT

run_case() {
  local target="$1"
  local expected_status="$2"
  local expected_output="$3"
  local output_file="$work_dir/$target.out"
  local status

  set +e
  kof run probes/g0_exception/main.kf --target "$target" >"$output_file" 2>"$work_dir/$target.err"
  status=$?
  set -e

  if [[ "$status" -ne "$expected_status" ]]; then
    echo "exception reproducer: $target exited $status, expected $expected_status" >&2
    return 1
  fi
  if [[ "$(<"$output_file")" != "$expected_output" ]]; then
    echo "exception reproducer: $target output changed" >&2
    printf 'expected:\n%s\nactual:\n%s\n' "$expected_output" "$(<"$output_file")" >&2
    return 1
  fi
}

run_case jvm 1 $'no-throw\nfalse'
run_case native 0 $'no-throw\nfalse\ntrue\nunreachable'
echo "KOOKIE native exception lifetime reproducer remains observed"
