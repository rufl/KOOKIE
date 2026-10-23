#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$root_dir/build/kookie-bugfeed"
while (($#)); do
  case "$1" in
    --output) output="${2:?missing output binary}"; shift 2 ;;
    *) echo "usage: $0 [--output BINARY]" >&2; exit 2 ;;
  esac
done
zig_bin="${ZIG:-zig}"
version="$("$zig_bin" version)"
[[ "$version" == "0.17.0" ]] || { echo "build_bugfeed: expected Zig 0.17.0, found $version" >&2; exit 1; }
mkdir -p "$(dirname "$output")"
"$zig_bin" build-exe "$root_dir/apps/web_server/bugfeed.zig" -O ReleaseFast -lc -fstrip -femit-bin="$output"
chmod 0755 "$output"
printf 'KOOKIE Bugfeed built\noutput: %s\n' "$output"
