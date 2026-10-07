#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-goose-game-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT

cp "$root_dir/probes/g7_goose_game/main.kf" "$work_dir/main.kf"
mkdir "$work_dir/lib"
ln -s lib "$work_dir/build"
for module in content core session ui; do
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

output="$(cd "$work_dir" && kof run main.kf --target native)"
[[ "$output" == *"KOOKIE G7 goose WAN gameplay verified"* ]] || {
  printf '%s\n' "$output" >&2
  echo "verify_goose_game: marker missing" >&2
  exit 1
}
printf '%s\n' "$output"
