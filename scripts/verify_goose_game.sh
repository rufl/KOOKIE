#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
work_dir="$(mktemp -d -t kookie-goose-game-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT

cp "$root_dir/probes/g7_goose_game/main.kf" "$work_dir/main.kf"
mkdir "$work_dir/lib"
ln -s lib "$work_dir/build"
for module in content core session ui world; do
  mkdir "$work_dir/$module"
  for source in "$root_dir/src/$module/"*.kf; do
    ln -s "$source" "$work_dir/$module/$(basename "$source")"
  done
done
cp "$root_dir/probes/shared/pe_durable_save_coordinator.kf" \
  "$work_dir/session/pe_durable_save_coordinator.kf"
cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared \
  "$root_dir/native/kookie_persistence_adapter.c" \
  -o "$work_dir/lib/libkookie_persistence_adapter.so"
zig_bin="${ZIG:-zig}"
(
  cd "$root_dir"
  "$zig_bin" build check-box3d-adapter
  "$zig_bin" build -Drelease=true --prefix "$work_dir/zig-prefix"
)
cp "$work_dir/zig-prefix/lib/libkookie_box3d.so" "$work_dir/lib/"


output="$(cd "$work_dir" && \
  export LD_LIBRARY_PATH="$work_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" && \
  kookie_kof_observed goose-game kof run main.kf --target native)"
[[ "$output" == *"KOOKIE G7 goose WAN gameplay verified"* ]] || {
  printf '%s\n' "$output" >&2
  echo "verify_goose_game: marker missing" >&2
  exit 1
}
printf '%s\n' "$output"
