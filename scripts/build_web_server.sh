#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
output_dir="${KOOKIE_WEB_SERVER_OUTPUT:-$root_dir/build/kookie-web-server}"

while (($#)); do
  case "$1" in
    --output) output_dir="${2:?missing output directory}"; shift 2 ;;
    *) echo "usage: $0 [--output DIR]" >&2; exit 2 ;;
  esac
done

work_dir="$(mktemp -d -t kookie-web-server-XXXXXX)"
cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

source_dir="$work_dir/source"
mkdir -p "$source_dir"/{core,content,session,ui,world,lib}
cp -- "$root_dir/apps/web_server/main.kf" "$source_dir/main.kf"
ln -s -- "$root_dir/src/ui/kutter_studio.kf" "$source_dir/ui/kutter_studio.kf"
ln -s -- "$root_dir/src/ui/kutter_level_editor.kf" "$source_dir/ui/kutter_level_editor.kf"
ln -s -- "$root_dir/src/ui/kutter.kf" "$source_dir/ui/kutter.kf"
ln -s -- "$root_dir/src/ui/kutter_workspace.kf" "$source_dir/ui/kutter_workspace.kf"
for module in core content session world; do
  for source_file in "$root_dir/src/$module/"*.kf; do
    ln -s -- "$source_file" "$source_dir/$module/$(basename "$source_file")"
  done
done
cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -pthread -shared \
  "$root_dir/native/kookie_web_server.c" \
  -o "$source_dir/lib/libkookie_web_server.so"
(
  cd "$source_dir"
  kookie_kof_observed web-server kof build main.kf \
    --target native --output "$work_dir/build"
)
[[ -x "$work_dir/build/Default/Main" ]] || {
  echo 'build_web_server: missing native server binary' >&2
  exit 1
}
mkdir -p "$output_dir"
rm -rf -- "$output_dir"/*
cp -- "$work_dir/build/Default/Main" "$output_dir/kookie-web-server"
mkdir -p "$output_dir/lib"
cp -- "$source_dir/lib/libkookie_web_server.so" \
  "$output_dir/lib/libkookie_web_server.so"
mkdir -p "$output_dir/config/runtime/power_ups"
cp -- "$root_dir"/assets/prototype/runtime/power_ups/*.json \
  "$output_dir/config/runtime/power_ups/"
chmod +x "$output_dir/kookie-web-server"
mkdir -p "$output_dir/config/runtime/water_bodies"
cp -- "$root_dir/assets/prototype/runtime/liquid_physics.json" \
  "$output_dir/config/runtime/liquid_physics.json"
cp -- "$root_dir"/assets/prototype/runtime/water_bodies/*.json \
  "$output_dir/config/runtime/water_bodies/"
printf 'KOOKIE native Kof web server built\noutput: %s\n' "$output_dir"
