#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-ui-sound-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT INT TERM

cp -- "$root_dir/probes/g10_ui_sound/main.kf" "$work_dir/main.kf"
mkdir -p "$work_dir/ui" "$work_dir/core"
ln -s -- "$root_dir/src/ui/kookie_ui.kf" "$work_dir/ui/kookie_ui.kf"
ln -s -- "$root_dir/src/ui/kookie_ui_audio.kf" "$work_dir/ui/kookie_ui_audio.kf"
ln -s -- "$root_dir/src/ui/kookie_ui_audio_catalog.kf" \
  "$work_dir/ui/kookie_ui_audio_catalog.kf"
ln -s -- "$root_dir/src/core/audio_queue.kf" "$work_dir/core/audio_queue.kf"

jvm_output="$(cd "$work_dir" && kof run main.kf --target jvm)"
native_output="$(cd "$work_dir" && kof run main.kf --target native)"
for output in "$jvm_output" "$native_output"; do
  [[ "$output" == *"KOOKIE G10 published UI sound catalog verified"* ]]
done
printf '%s\n%s\n' "$jvm_output" "$native_output"
