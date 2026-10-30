#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
work_dir="$(mktemp -d -t kookie-font-ui-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT

cp "$root_dir/probes/g9_font_ui/main.kf" "$work_dir/main.kf"
for module in content core session ui world; do
  mkdir "$work_dir/$module"
  for source in "$root_dir/src/$module/"*.kf; do
    ln -s "$source" "$work_dir/$module/$(basename "$source")"
  done
done

read -r -a targets <<< "${KOOKIE_FONT_UI_TARGETS:-jvm native}"
(( ${#targets[@]} > 0 )) || {
  echo 'verify_font_ui: at least one target is required' >&2
  exit 2
}
for target in "${targets[@]}"; do
  case "$target" in
    jvm|native) ;;
    *) echo "verify_font_ui: unsupported target: $target" >&2; exit 2 ;;
  esac
  output="$(cd "$work_dir" && \
    kookie_kof_observed "font-ui-$target" \
      kof run main.kf --target "$target")"
  [[ "$output" == *"KOOKIE G9 GatoGanso font defaults verified"* ]] || {
    printf '%s\n' "$output" >&2
    echo "verify_font_ui: marker missing for $target" >&2
    exit 1
  }
  printf '%s\n' "$output"
done
