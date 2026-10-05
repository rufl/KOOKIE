#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-font-ui-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT

cp "$root_dir/probes/g9_font_ui/main.kf" "$work_dir/main.kf"
for module in content core session ui; do
  mkdir "$work_dir/$module"
  for source in "$root_dir/src/$module/"*.kf; do
    ln -s "$source" "$work_dir/$module/$(basename "$source")"
  done
done

jvm_output="$(cd "$work_dir" && kof run main.kf --target jvm)"
native_output="$(cd "$work_dir" && kof run main.kf --target native)"
[[ "$jvm_output" == *"KOOKIE G9 GatoGanso font defaults verified"* ]]
[[ "$native_output" == *"KOOKIE G9 GatoGanso font defaults verified"* ]]
printf '%s\n%s\n' "$jvm_output" "$native_output"
