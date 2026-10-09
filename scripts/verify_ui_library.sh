#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-ui-library-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT INT TERM

cp "$root_dir/probes/g10_ui_library/main.kf" "$work_dir/main.kf"
mkdir "$work_dir/ui"
ln -s "$root_dir/src/ui/kookie_ui.kf" "$work_dir/ui/kookie_ui.kf"

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
printf '%s\n%s\n%s\n' "$jvm_output" "$native_output" "$js_check"
