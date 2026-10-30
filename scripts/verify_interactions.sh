#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
work_dir="$(mktemp -d -t kookie-interactions-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT

cp "$root_dir/probes/g2_interactions/main.kf" "$work_dir/main.kf"
for module in content core session ui world; do
  mkdir "$work_dir/$module"
  for source in "$root_dir/src/$module/"*.kf; do
    ln -s "$source" "$work_dir/$module/$(basename "$source")"
  done
done
cd "$work_dir"
kookie_kof_observed interactions-jvm kof run main.kf --target jvm
mkdir -p "$work_dir/lib"
zig_bin="${ZIG:-zig}"
(
  cd "$root_dir"
  "$zig_bin" build check-box3d-adapter
  "$zig_bin" build -Drelease=true --prefix "$work_dir/zig-prefix"
)
cp "$work_dir/zig-prefix/lib/libkookie_box3d.so" "$work_dir/lib/"
cd "$work_dir"
LD_LIBRARY_PATH="$work_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  kookie_kof_observed interactions-native kof run main.kf --target native
