#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-interactions-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT

cp "$root_dir/probes/g2_interactions/main.kf" "$work_dir/main.kf"
mkdir "$work_dir/core" "$work_dir/session"
for module in core session; do
  for source in "$root_dir/src/$module/"*.kf; do
    ln -s "$source" "$work_dir/$module/$(basename "$source")"
  done
done
cd "$work_dir"
kof run main.kf --target jvm
kof run main.kf --target native
