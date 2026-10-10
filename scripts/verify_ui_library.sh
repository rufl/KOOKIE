#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-ui-library-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT INT TERM

cp "$root_dir/probes/g10_ui_library/main.kf" "$work_dir/main.kf"
mkdir "$work_dir/ui"
ln -s "$root_dir/src/ui/kookie_ui.kf" "$work_dir/ui/kookie_ui.kf"
ln -s "$root_dir/src/ui/kookie_ui_components.kf" "$work_dir/ui/kookie_ui_components.kf"
ln -s "$root_dir/src/ui/kookie_ui_audio.kf" "$work_dir/ui/kookie_ui_audio.kf"
mkdir "$work_dir/core"
ln -s "$root_dir/src/core/audio_queue.kf" "$work_dir/core/audio_queue.kf"
python3 "$root_dir/scripts/generate_ui_manifest_kf.py" \
  --check "$root_dir/assets/ui/manifest.json" "$root_dir/src/ui/published_assets.kf"
python3 "$root_dir/scripts/generate_ui_manifest_kf.py" \
  --format kofscript --check "$root_dir/assets/ui/manifest.json" \
  "$root_dir/src/ui/published_assets.ks"
ln -s "$root_dir/src/ui/published_assets.kf" \
  "$work_dir/ui/published_assets.kf"
cat "$root_dir/src/ui/kookie_ui.ks" \
  "$root_dir/src/ui/published_assets.ks" \
  "$root_dir/probes/g10_ui_library/main.ks" > "$work_dir/kofscript.ks"
kofscript_jvm_output="$(
  cd "$work_dir" && kof script kofscript.ks --target jvm
)"
kofscript_native_output="$(
  cd "$work_dir" && kof script kofscript.ks --target native
)"

jvm_output="$(cd "$work_dir" && kof run main.kf --target jvm)"
native_output="$(cd "$work_dir" && kof run main.kf --target native)"
js_check="$(cd "$work_dir" && kof check main.kf --target js)"
js_build_dir="$work_dir/js-build"
(
  cd "$work_dir"
  kof build main.kf --target js --output "$js_build_dir" >/dev/null
)
[[ "$js_check" == *"checked 1 file(s) — no errors"* ]]
[[ -f "$js_build_dir/Default.mjs" ]]
[[ -f "$js_build_dir/index.html" ]]
grep -Fq 'kofUiImageNew' "$js_build_dir/Default.mjs"
grep -Fq 'kofUiIconNew' "$js_build_dir/Default.mjs"

for output in "$jvm_output" "$native_output"; do
  [[ "$output" == *"KOOKIE G10 internal Kof/KofJS UI library verified"* ]]
done
[[ "$jvm_output" == *"KOOKIE G10 reusable layout and widget system verified"* ]]
[[ "$native_output" == *"KOOKIE G10 reusable layout and widget system verified"* ]]
for output in "$kofscript_jvm_output" "$kofscript_native_output"; do
  [[ "$output" == *"KOOKIE G10 KofScript UI library verified"* ]]
done
printf '%s\n%s\n%s\n%s\n%s\n' \
  "$jvm_output" "$native_output" \
  "$kofscript_jvm_output" "$kofscript_native_output" "$js_check"
