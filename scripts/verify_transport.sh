#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kookie-transport.XXXXXX")"
cleanup() { rm -rf -- "$work_dir"; }
trap cleanup EXIT INT TERM

cc="${CC:-cc}"
command -v "$cc" >/dev/null || {
  echo "verify_transport: C compiler is required" >&2
  exit 2
}

"$cc" -std=c11 -Wall -Wextra -Werror -I"$root_dir/native" \
  "$root_dir/native/kookie_transport.c" \
  "$root_dir/native/kookie_transport_test.c" \
  -o "$work_dir/kookie_transport_test"
"$work_dir/kookie_transport_test"
