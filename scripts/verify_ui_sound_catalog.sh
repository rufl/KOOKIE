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

IFS=' ' read -r -a targets <<< "${KOOKIE_UI_SOUND_TARGETS:-jvm native}"
(( ${#targets[@]} > 0 )) || {
  echo 'verify_ui_sound_catalog: at least one target is required' >&2
  exit 2
}
for target in "${targets[@]}"; do
  case "$target" in
    jvm|native) ;;
    *) echo "verify_ui_sound_catalog: unsupported target: $target" >&2; exit 2 ;;
  esac
  output="$(cd "$work_dir" && kof run main.kf --target "$target")"
  [[ "$output" == *"KOOKIE G10 published UI sound catalog verified"* ]] || {
    printf '%s\n' "$output" >&2
    echo "verify_ui_sound_catalog: marker missing for $target" >&2
    exit 1
  }
  printf '%s\n' "$output"
done
