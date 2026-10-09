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

mkdir -p "$work_dir/ui" "$work_dir/assets/ui" \
  "$work_dir/content/prototype/runtime/ui" "$work_dir/fonts"
cp -- "$root_dir/apps/ui_demo/main.kf" "$work_dir/main.kf"
ln -s -- "$root_dir/src/ui/kookie_ui.kf" "$work_dir/ui/kookie_ui.kf"
cp -- "$root_dir/assets/ui/manifest.json" \
  "$root_dir/assets/ui/kookie-ui.css" \
  "$root_dir/assets/ui/gatoganso-mark.svg" "$work_dir/assets/ui/"
cp -- "$root_dir/assets/prototype/runtime/ui/hearts_0001.png" \
  "$work_dir/content/prototype/runtime/ui/hearts_0001.png"
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
mkdir -p "$output_dir/assets/ui" "$output_dir/content/prototype/runtime/ui" \
  "$output_dir/fonts"
cp -- "$work_dir/assets/ui/manifest.json" \
  "$work_dir/assets/ui/kookie-ui.css" \
  "$work_dir/assets/ui/gatoganso-mark.svg" "$output_dir/assets/ui/"
cp -- "$work_dir/content/prototype/runtime/ui/hearts_0001.png" \
  "$output_dir/content/prototype/runtime/ui/hearts_0001.png"
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
  assets/ui/kookie-ui.css assets/ui/gatoganso-mark.svg \
  content/prototype/runtime/ui/hearts_0001.png fonts/jared-lite.ttf fonts/pixand.ttf; do
  [[ -f "$output_dir/$required" ]] || {
    echo "verify_ui_demo: missing generated asset: $required" >&2
    exit 1
  }
done

grep -Fq 'kofUiImageNew' "$output_dir/Default.mjs"
grep -Fq 'kofUiIconNew' "$output_dir/Default.mjs"
grep -Fq 'kofUiWindowNew' "$output_dir/Default.mjs"
grep -Fq 'assets/ui/kookie-ui.css' "$output_dir/index.html"
python3 - "$output_dir/assets/ui/manifest.json" "$output_dir" <<'PY'
import hashlib
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest["schema"] == "kookie.gatoganso-ui/v1"
assert manifest["publication"]["prototype_assets_are_optional"] is True
assert manifest["publication"]["demo_requires_prototype_assets"] is True
expected = {
    "ui.gatoganso-mark": {
        "kind": "svg",
        "alt": "GatoGanso mark",
        "authored_path": "assets/ui/gatoganso-mark.svg",
        "runtime_path": "assets/ui/gatoganso-mark.svg",
        "sha256": "b8a5fa320e49bf41d06969ae8d918a70a5525a9c7271fbe073c7878798b0f17e",
    },
    "ui.player-hearts": {
        "kind": "png",
        "alt": "Player health",
        "authored_path": "assets/prototype/runtime/ui/hearts_0001.png",
        "runtime_path": "content/prototype/runtime/ui/hearts_0001.png",
        "sha256": "c468c974f5c044012c0d84ef57c6e3941f8472ab841fc030ea98d865013576d3",
    },
}
assets = manifest["assets"]
assert {asset["id"] for asset in assets} == set(expected)
for asset in assets:
    expected_asset = expected[asset["id"]]
    assert asset == {"id": asset["id"], **expected_asset}
    runtime_path = pathlib.PurePosixPath(asset["runtime_path"])
    assert runtime_path.is_relative_to(".")
    assert ".." not in runtime_path.parts
    assert "" not in runtime_path.parts and "." not in runtime_path.parts
    assert all(ord(character) >= 32 for character in asset["runtime_path"])
    assert len(asset["sha256"]) == 64
    assert all(character in "0123456789abcdef" for character in asset["sha256"])
    path = root.joinpath(*runtime_path.parts)
    assert path.is_file()
    assert hashlib.sha256(path.read_bytes()).hexdigest() == asset["sha256"]
PY

printf 'KOOKIE UI demo verified\n%s\n' "$js_check"
if [[ "$serve" == 1 ]]; then
  printf 'KOOKIE UI demo serving at http://%s:%s/index.html\n' "$host" "$port"
  python3 -m http.server "$port" --bind "$host" --directory "$output_dir" &
  server_pid=$!
  wait "$server_pid"
fi
