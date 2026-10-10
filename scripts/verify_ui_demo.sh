#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
serve=0
port=8767
host=127.0.0.1
output_dir=""
while (($#)); do
  case "$1" in
    --serve) serve=1; shift ;;
    --host) host="${2:?missing host}"; shift 2 ;;
    --port) port="${2:?missing port}"; shift 2 ;;
    --output) output_dir="${2:?missing output directory}"; shift 2 ;;
    *) echo "usage: $0 [--serve] [--host HOST] [--port PORT] [--output DIR]" >&2; exit 2 ;;
  esac
done

work_dir="$(mktemp -d -t kookie-ui-demo-XXXXXX)"
cleanup() {
  if [[ -n "${server_pid:-}" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

mkdir -p "$work_dir/ui" "$work_dir/assets/ui" "$work_dir/fonts"
cp -- "$root_dir/apps/ui_demo/main.kf" "$work_dir/main.kf"
ln -s -- "$root_dir/src/ui/kookie_ui.kf" "$work_dir/ui/kookie_ui.kf"
ln -s -- "$root_dir/src/ui/kookie_ui_components.kf" \
  "$work_dir/ui/kookie_ui_components.kf"
ln -s -- "$root_dir/src/ui/kookie_ui_audio.kf" \
  "$work_dir/ui/kookie_ui_audio.kf"
mkdir -p "$work_dir/core"
ln -s -- "$root_dir/src/core/audio_queue.kf" \
  "$work_dir/core/audio_queue.kf"
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

if [[ -z "$output_dir" ]]; then
  output_dir="$work_dir/build"
else
  mkdir -p "$output_dir"
fi

js_check="$(cd "$work_dir" && kof check main.kf --target js)"
[[ "$js_check" == *"checked 1 file(s)"* ]]
(
  cd "$work_dir"
  kof build main.kf --target js --output "$output_dir" >/dev/null
)
mkdir -p "$output_dir/assets/ui" "$output_dir/fonts"
cp -- "$work_dir/assets/ui/manifest.json" \
  "$work_dir/assets/ui/kookie-ui.css" "$output_dir/assets/ui/"
python3 "$root_dir/scripts/stage_ui_manifest.py" \
  "$output_dir/assets/ui/manifest.json" "$root_dir" "$output_dir" --profile demo
cp -- "$work_dir/fonts/jared-lite.ttf" "$work_dir/fonts/pixand.ttf" \
  "$output_dir/fonts/"
python3 - "$output_dir/index.html" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
html = path.read_text(encoding="utf-8")
link = '<link rel="stylesheet" href="assets/ui/kookie-ui.css">'
assert "</head>" in html
if link not in html:
    html = html.replace("</head>", f"  {link}\n</head>", 1)
path.write_text(html, encoding="utf-8")
PY
for required in index.html Default.mjs assets/ui/manifest.json \
  assets/ui/kookie-ui.css fonts/jared-lite.ttf fonts/pixand.ttf; do
  [[ -f "$output_dir/$required" ]] || {
    echo "verify_ui_demo: missing generated asset: $required" >&2
    exit 1
  }
done

grep -Fq 'kofUiImageNew' "$output_dir/Default.mjs"
grep -Fq 'kofUiIconNew' "$output_dir/Default.mjs"
grep -Fq 'kofUiWindowNew' "$output_dir/Default.mjs"
grep -Fq 'assets/ui/kookie-ui.css' "$output_dir/index.html"
python3 "$root_dir/scripts/verify_ui_manifest.py" \
  "$output_dir/assets/ui/manifest.json" "$output_dir" --profile demo

printf 'KOOKIE UI demo verified\n%s\n' "$js_check"
if [[ "$serve" == 1 ]]; then
  printf 'KOOKIE UI demo serving at http://%s:%s/index.html\n' "$host" "$port"
  python3 -m http.server "$port" --bind "$host" --directory "$output_dir" &
  server_pid=$!
  wait "$server_pid"
fi
