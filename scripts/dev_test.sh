#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
source "$root_dir/scripts/kof_pin.sh"
command -v kof >/dev/null || { echo 'dev_test: kof is required' >&2; exit 2; }

if (($# > 0)); then
  echo 'usage: KOOKIE_DEV_TARGET=jvm|native bash scripts/dev_test.sh' >&2
  exit 2
fi

target="${KOOKIE_DEV_TARGET:-jvm}"
case "$target" in
  jvm|native) ;;
  *)
    echo "dev_test: unsupported KOOKIE_DEV_TARGET: $target" >&2
    exit 2
    ;;
esac

kof test src/main.kf --target "$target"
