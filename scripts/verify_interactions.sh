#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
work_dir="$(mktemp -d -t kookie-interactions-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT

cp "$root_dir/probes/g2_interactions/main.kf" "$work_dir/main.kf"
mkdir "$work_dir/content" "$work_dir/core" "$work_dir/session"
for module in content core session; do
  for source in "$root_dir/src/$module/"*.kf; do
    ln -s "$source" "$work_dir/$module/$(basename "$source")"
  done
done
cd "$work_dir"
kookie_kof_observed interactions-jvm kof run main.kf --target jvm
kookie_kof_observed interactions-native kof run main.kf --target native
