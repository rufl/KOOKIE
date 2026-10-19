#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
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

mkdir -p "$work_dir/ui" "$work_dir/assets/ui" "$work_dir/fonts" \
  "$work_dir/core" "$work_dir/session"
cp -- "$root_dir/apps/web_alpha/main.kf" "$work_dir/main.kf"
ln -s -- "$root_dir/src/ui/kookie_ui.kf" "$work_dir/ui/kookie_ui.kf"
ln -s -- "$root_dir/src/ui/kookie_ui_components.kf" \
  "$work_dir/ui/kookie_ui_components.kf"
ln -s -- "$root_dir/src/ui/kookie_ui_audio.kf" \
  "$work_dir/ui/kookie_ui_audio.kf"
ln -s -- "$root_dir/src/core/audio_queue.kf" \
  "$work_dir/core/audio_queue.kf"
ln -s -- "$root_dir/src/session/runtime_plan.kf" \
  "$work_dir/session/runtime_plan.kf"
ln -s -- "$root_dir/src/session/web_session_protocol.kf" \
  "$work_dir/session/web_session_protocol.kf"
python3 "$root_dir/scripts/generate_ui_manifest_kf.py" \
  --check "$root_dir/assets/ui/manifest.json" "$root_dir/src/ui/published_assets.kf"
ln -s -- "$root_dir/src/ui/published_assets.kf" \
  "$work_dir/ui/published_assets.kf"
cp -- "$root_dir/assets/ui/manifest.json" \
  "$root_dir/assets/ui/kookie-ui.css" "$work_dir/assets/ui/"
python3 "$root_dir/scripts/stage_ui_manifest.py" \
  "$work_dir/assets/ui/manifest.json" "$root_dir" "$work_dir" --profile demo
cp -- "$root_dir/assets/fonts/jared-lite.ttf" \
  "$root_dir/assets/fonts/pixand.ttf" "$work_dir/fonts/"

js_check="$(cd "$work_dir" && kof check main.kf --target js)"
[[ "$js_check" == *"checked 1 file(s) — no errors"* ]]
(
  cd "$work_dir"
  kookie_kof_observed web-alpha kof build main.kf \
    --target js --output "$work_dir/build"
)

mkdir -p "$work_dir/build/assets/ui" "$work_dir/build/assets/prototype/models/goose" \
  "$work_dir/build/assets/prototype/models/cat" \
  "$work_dir/build/assets/prototype/models/modular" "$work_dir/build/fonts"
cp -- "$work_dir/assets/ui/manifest.json" \
  "$work_dir/assets/ui/kookie-ui.css" "$work_dir/build/assets/ui/"
python3 "$root_dir/scripts/stage_ui_manifest.py" \
  "$work_dir/build/assets/ui/manifest.json" "$root_dir" "$work_dir/build" --profile demo
cp -- "$work_dir/fonts/jared-lite.ttf" "$work_dir/fonts/pixand.ttf" \
  "$work_dir/build/fonts/"
cp -- "$root_dir/assets/prototype/models/goose/goose.glb" \
  "$work_dir/build/assets/prototype/models/goose/goose.glb"
cp -- "$root_dir/assets/prototype/models/cat/cat.glb" \
  "$work_dir/build/assets/prototype/models/cat/cat.glb"
cp -- "$root_dir/assets/prototype/models/modular/ground.glb" \
  "$work_dir/build/assets/prototype/models/modular/ground.glb"
cp -- "$root_dir/assets/prototype/models/modular/wall.glb" \
  "$work_dir/build/assets/prototype/models/modular/wall.glb"
cp -- "$root_dir/apps/web_alpha/webgl_renderer.js" \
  "$work_dir/build/kookie-webgl-renderer.js"
cp -- "$root_dir/apps/web_alpha/session_transport.js" \
  "$work_dir/build/kookie-session.js"
python3 - "$work_dir/build/index.html" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
html = path.read_text(encoding="utf-8")
html = html.replace("<title>Default — Kof</title>",
                    "<title>GatoGanso — KOOKIE KofJS browser alpha</title>")
html = html.replace(
    '<span class="name">Default</span><span class="kind">Kof output</span>',
    '<span class="name">GATOGANSO</span><span class="kind">KofJS browser alpha</span>',
)
link = '<link rel="stylesheet" href="assets/ui/kookie-ui.css">'
if link not in html:
    html = html.replace("</head>", f"  {link}\n</head>", 1)
renderer_script = '<script src="kookie-webgl-renderer.js"></script>'
if renderer_script not in html:
    html = html.replace("</body>", f"  {renderer_script}\n</body>", 1)
script = '<script src="kookie-session.js"></script>'
if script not in html:
    html = html.replace("</body>", f"  {script}\n</body>", 1)
path.write_text(html, encoding="utf-8")
PY

for required in index.html Default.mjs kof-runtime.mjs kof-runtime-io.mjs \
  kookie-webgl-renderer.js kookie-session.js assets/ui/manifest.json \
  assets/ui/kookie-ui.css fonts/jared-lite.ttf fonts/pixand.ttf \
  assets/prototype/models/goose/goose.glb \
  assets/prototype/models/cat/cat.glb \
  assets/prototype/models/modular/ground.glb \
  assets/prototype/models/modular/wall.glb; do
  [[ -f "$work_dir/build/$required" ]] || {
    echo "build_web_alpha: missing generated asset: $required" >&2
    exit 1
  }
done
grep -Fq 'KofJS browser alpha' "$work_dir/build/index.html"
grep -Fq 'kofUiButtonNewAction' "$work_dir/build/Default.mjs"
python3 "$root_dir/scripts/verify_ui_manifest.py" \
  "$work_dir/build/assets/ui/manifest.json" "$work_dir/build" --profile demo

mkdir -p "$(dirname "$output_dir")"
rm -rf -- "$output_dir"
mv -- "$work_dir/build" "$output_dir"
printf 'KOOKIE KofJS browser alpha published\noutput: %s\n%s\n' \
  "$output_dir" "$js_check"
