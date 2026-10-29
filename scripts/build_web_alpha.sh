#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${KOOKIE_WEB_ALPHA_OUTPUT:-$root_dir/../../LICHFORGEWEB/assets/kookie-alpha}"

while (($#)); do
  case "$1" in
    --output) output_dir="${2:?missing output directory}"; shift 2 ;;
    *) echo "usage: $0 [--output DIR]" >&2; exit 2 ;;
  esac
done

work_dir="$(mktemp -d -t kookie-web-alpha-XXXXXX)"
cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM


mkdir -p "$work_dir/build"
cp -R -- "$root_dir/assets/fonts" "$work_dir/build/fonts"
mkdir -p "$work_dir/build/assets/prototype"
cp -- "$root_dir/assets/prototype/manifest.json" \
  "$root_dir/assets/prototype/greybox_modules.json" \
  "$work_dir/build/assets/prototype/"
cp -R -- "$root_dir/assets/prototype/runtime" \
  "$work_dir/build/assets/prototype/"
while IFS= read -r -d '' asset; do
  relative="${asset#"$root_dir/assets/prototype/"}"
  destination="$work_dir/build/assets/prototype/$relative"
  mkdir -p "$(dirname "$destination")"
  cp -- "$asset" "$destination"
done < <(
  find "$root_dir/assets/prototype/models" -type f -name '*.glb' -print0 |
    sort -z
)
while IFS= read -r -d '' asset; do
  relative="${asset#"$root_dir/assets/prototype/"}"
  destination="$work_dir/build/assets/prototype/$relative"
  mkdir -p "$(dirname "$destination")"
  cp -- "$asset" "$destination"
done < <(
  find "$root_dir/assets/prototype/vfx" -type f -name '*.png' -print0 |
    sort -z
)
cp -- "$root_dir/assets/prototype/models/goose/goose_albedo.png" \
  "$work_dir/build/assets/prototype/models/goose/goose_albedo.png"
cp -- "$root_dir/apps/web_alpha/webgl_renderer.js" \
  "$work_dir/build/kookie-webgl-renderer.js"
cp -- "$root_dir/apps/web_alpha/session_transport.js" \
  "$work_dir/build/kookie-session.js"
cp -- "$root_dir/apps/web_alpha/kutter_editor.js" \
  "$work_dir/build/kutter-editor.js"
cp -- "$root_dir/apps/web_alpha/index.html" "$work_dir/build/index.html"
cp -- "$root_dir/apps/web_alpha/kutter.html" "$work_dir/build/kutter.html"

for required in \
  assets/prototype/manifest.json \
  assets/prototype/greybox_modules.json \
  assets/prototype/runtime/liquid_physics.json \
  assets/prototype/runtime/power_ups/watermelon.json \
  assets/prototype/models/goose/goose_albedo.png \
  assets/prototype/runtime/ui/hearts_0001.png \
  assets/prototype/runtime/water_bodies/pool.json \
  assets/prototype/runtime/floatables/crate.json \
  fonts/manifest.json \
  fonts/OFL.txt \
  fonts/readme.txt \
  fonts/pixand.ttf \
  fonts/jared-lite.ttf \
  fonts/ThaleahFat.ttf; do
  [[ -f "$work_dir/build/$required" ]] || {
    echo "build_web_alpha: missing generated asset: $required" >&2
    exit 1
  }
done
expected_model_count="$(
  find "$root_dir/assets/prototype/models" -type f -name '*.glb' | wc -l
)"
actual_model_count="$(
  find "$work_dir/build/assets/prototype/models" -type f -name '*.glb' | wc -l
)"
[[ "$actual_model_count" == "$expected_model_count" ]] || {
  echo "build_web_alpha: model closure mismatch: $actual_model_count/$expected_model_count" >&2
  exit 1
}
expected_vfx_count="$(
  find "$root_dir/assets/prototype/vfx" -type f -name '*.png' | wc -l
)"
actual_vfx_count="$(
  find "$work_dir/build/assets/prototype/vfx" -type f -name '*.png' | wc -l
)"
[[ "$actual_vfx_count" == "$expected_vfx_count" ]] || {
  echo "build_web_alpha: VFX closure mismatch: $actual_vfx_count/$expected_vfx_count" >&2
  exit 1
}
[[ ! -e "$work_dir/build/assets/prototype/models/cat/source" ]] || {
  echo "build_web_alpha: restricted cat sources leaked into output" >&2
  exit 1
}
grep -Fq '<title>GatoGanso — Play</title>' "$work_dir/build/index.html"
grep -Fq 'captureScreenshot' "$work_dir/build/kookie-webgl-renderer.js"
grep -Fq 'KookieBrowserCapture' "$work_dir/build/kookie-session.js"

mkdir -p "$(dirname "$output_dir")"
rm -rf -- "$output_dir"
mv -- "$work_dir/build" "$output_dir"
printf 'GatoGanso browser game published\noutput: %s\n' \
  "$output_dir"
