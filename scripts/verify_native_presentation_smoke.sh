#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
source "$root_dir/scripts/kof_pin.sh"
source "$root_dir/scripts/sdl3_dependencies.sh"
source "$root_dir/scripts/native_text_dependencies.sh"

command -v kof >/dev/null || { echo 'native presentation: kof is required' >&2; exit 2; }
command -v python3 >/dev/null || { echo 'native presentation: python3 is required' >&2; exit 2; }
command -v gcc >/dev/null || { echo 'native presentation: gcc is required' >&2; exit 75; }
command -v glslc >/dev/null || { echo 'native presentation: glslc is required' >&2; exit 75; }
command -v spirv-val >/dev/null || { echo 'native presentation: spirv-val is required' >&2; exit 75; }

bash scripts/verify_package_preflight.sh
kookie_prepare_sdl3_dependencies "$root_dir" || {
  echo 'native presentation: SDL3 dependencies unavailable' >&2
  exit 75
}
kookie_require_native_text_dependencies "$root_dir" || {
  echo 'native presentation: native text dependencies unavailable' >&2
  exit 75
}

isolation_wrapper="${KOOKIE_PRESENTATION_ISOLATION_WRAPPER:-$root_dir/scripts/linux_gamescope_isolated_display}"
command -v "$isolation_wrapper" >/dev/null || {
  echo "native presentation: isolation wrapper unavailable: $isolation_wrapper" >&2
  exit 75
}

mkdir -p "$root_dir/build"
build_dir="$(mktemp -d "$root_dir/build/kookie-presentation-XXXXXX")"
adapter_build_dir="$build_dir/adapter"
mkdir -p "$adapter_build_dir/build"
mkdir -p "$adapter_build_dir"/assets/{fonts,ui,prototype/runtime,prototype/models,audio}
cp -- "$root_dir/assets/fonts/jared-lite.ttf" \
  "$adapter_build_dir/assets/fonts/jared-lite.ttf"
cp -- "$root_dir/assets/fonts/pixand.ttf" \
  "$adapter_build_dir/assets/fonts/pixand.ttf"
cp -- "$root_dir/assets/ui/gatoganso-mark.svg" \
  "$adapter_build_dir/assets/ui/gatoganso-mark.svg"
cp -a -- "$root_dir/assets/prototype/runtime/." \
  "$adapter_build_dir/assets/prototype/runtime/"
cp -- "$root_dir/assets/prototype/manifest.json" \
  "$adapter_build_dir/assets/prototype/manifest.json"
mkdir -p "$adapter_build_dir/assets/prototype/models/goose" \
  "$adapter_build_dir/assets/prototype/models/cat"
cp -- "$root_dir/assets/prototype/models/goose/goose.glb" \
  "$adapter_build_dir/assets/prototype/models/goose/goose.glb"
cp -- "$root_dir/assets/prototype/models/cat/cat.glb" \
  "$adapter_build_dir/assets/prototype/models/cat/cat.glb"
cp -a -- "$root_dir/assets/audio/ui" \
  "$adapter_build_dir/assets/audio/"
transport_key_file="$adapter_build_dir/transport.key"
printf '%s' '00000001000000020000000300000004' >"$transport_key_file"
chmod 600 "$transport_key_file"

probe_root="$root_dir/probes/g0_native_presentation"
for module in core content session world ui demo; do
  mkdir -p "$probe_root/$module"
  for source_file in "$root_dir/src/$module"/*.kf; do
    ln -sfn "$source_file" "$probe_root/$module/$(basename "$source_file")"
  done
done
cp -- "$root_dir/probes/shared/gpu_scene_batch.kf" \
  "$probe_root/core/gpu_scene_batch.kf"
cp -- "$root_dir/probes/shared/pe_durable_save_coordinator.kf" \
  "$probe_root/session/pe_durable_save_coordinator.kf"

cleanup() {
  rm -rf -- "$build_dir"
  for module in core content session world ui demo; do
    find "$probe_root/$module" -maxdepth 1 -type l -delete
  done
  rm -f -- "$probe_root/core/gpu_scene_batch.kf" \
    "$probe_root/session/pe_durable_save_coordinator.kf"
}
trap cleanup EXIT

python3 scripts/shader_pipeline.py \
  --root "$root_dir" --output "$adapter_build_dir" --target linux
gcc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
  -I"$adapter_build_dir" \
  native/kookie_sdl_adapter.c \
  native/kookie_ui_renderer.c \
  native/kookie_transport.c \
  -o "$adapter_build_dir/build/libkookie_sdl_adapter.so" \
  $(pkg-config --cflags --libs sdl3 sdl3-mixer freetype2 harfbuzz) -lm
gcc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
  native/kookie_persistence_adapter.c \
  -o "$adapter_build_dir/build/libkookie_persistence_adapter.so"
(
  cd "$adapter_build_dir"
  kookie_kof_observed native-presentation-focused kof build \
    "$probe_root/main.kf" --target native \
    --output "$adapter_build_dir/native-presentation"
)

render_node="${KOOKIE_RENDER_NODE:-}"
if [[ -z "$render_node" ]]; then
  for candidate in /dev/dri/renderD*; do
    if [[ -c "$candidate" ]]; then
      render_node="$candidate"
      break
    fi
  done
fi
[[ -n "$render_node" && -c "$render_node" ]] || {
  echo 'native presentation: render node unavailable' >&2
  exit 75
}

adapter_log="${KOOKIE_PRESENTATION_ADAPTER_LOG:-$root_dir/build/kookie-native-presentation.log}"
mkdir -p "$(dirname "$adapter_log")"
requested_screenshot_path="${KOOKIE_SCREENSHOT_PATH:-}"
presentation_screenshot_path="$build_dir/presentation.ppm"
evidence_path="${KOOKIE_PRESENTATION_EVIDENCE_JSON:-$root_dir/build/kookie-native-presentation.json}"
presentation_binary="$adapter_build_dir/native-presentation/Default/Main"
presentation_command=(
  bash -c 'cd "$1" && exec "$2"'
  --
  "$adapter_build_dir"
  "$presentation_binary"
)

set +e
"$isolation_wrapper" --timeout "${KOOKIE_PRESENTATION_TIMEOUT:-90}" \
  --render-node "$render_node" -- \
  env \
    KOOKIE_ASSET_DIR="$adapter_build_dir/assets" \
    KOOKIE_CONTENT_DIR="$adapter_build_dir/assets/prototype" \
    KOOKIE_TRANSPORT_KEY_FILE="$transport_key_file" \
    KOOKIE_TRANSPORT_KEY_HEX=00000001000000020000000300000004 \
    KOOKIE_PRESENTATION_SMOKE=1 \
    KOOKIE_SCREENSHOT_PATH="$presentation_screenshot_path" \
    KOOKIE_AUDIO_MUSIC_OGG="$adapter_build_dir/assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg" \
    KOOKIE_SHADER_DIR="$adapter_build_dir" \
    SDL_AUDIODRIVER=dummy \
    SDL_VIDEODRIVER="${KOOKIE_SDL_VIDEO_DRIVER:-x11}" \
    "${presentation_command[@]}" \
    >"$adapter_log" 2>&1
adapter_status=$?
set -e
cat "$adapter_log"
if [[ "$adapter_status" -ne 0 ]]; then
  echo "native presentation: isolated process exited with $adapter_status" >&2
  exit "$adapter_status"
fi

if [[ -n "$requested_screenshot_path" &&
      "$requested_screenshot_path" != "$presentation_screenshot_path" ]]; then
  mkdir -p "$(dirname "$requested_screenshot_path")"
  cp -- "$presentation_screenshot_path" "$requested_screenshot_path"
fi
KOOKIE_RENDER_NODE="$render_node" \
  python3 scripts/validate_presentation_evidence.py \
    "$adapter_log" "$presentation_screenshot_path" "$evidence_path"
