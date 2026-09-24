#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

command -v kof >/dev/null || { echo "kof is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

python3 scripts/lint_kf.py src probes
python3 scripts/lsp_verify.py src
python3 scripts/lsp_verify.py probes

kof check src --target jvm
kof check src --target native
kof test src --target jvm
kof test src --target native
bash scripts/verify_exception.sh
bash scripts/verify_simd_dispatch.sh

expected_output=$'KOOKIE G0 session foundation\n60\ntrue\nKOOKIE G0 resource tokens verified\nKOOKIE G0 scalar adapter contracts verified\nKOOKIE G0 frame staging verified\nKOOKIE G1 loopback foundation verified'
[[ "$(kof run src/main.kf --target jvm)" == "$expected_output" ]]
[[ "$(kof run src/main.kf --target native 2>/dev/null)" == "$expected_output" ]]

if [[ -f /usr/lib/libSDL3.so ]]; then
  platform_output=$'KOOKIE G0 scalar platform probe\n3004016\ntrue'
  [[ "$(kof run probes/g0_platform/main.kf --target jvm)" == "$platform_output" ]]
  [[ "$(kof run probes/g0_platform/main.kf --target native 2>/dev/null)" == "$platform_output" ]]
else
  echo "SDL3 scalar platform probe skipped: /usr/lib/libSDL3.so is unavailable"
fi

build_dir="$(mktemp -d -t kookie-build-XXXXXX)"
adapter_build_dir="$root_dir/build"
rm -rf "$adapter_build_dir"
mkdir -p "$adapter_build_dir"
transport_key_file="$adapter_build_dir/transport.key"
printf '%s' '00000001000000020000000300000004' >"$transport_key_file"
chmod 600 "$transport_key_file"
probe_core_dir="$root_dir/probes/g0_native_adapter/core"
probe_session_dir="$root_dir/probes/g0_native_adapter/session"
rm -rf "$probe_core_dir" "$probe_session_dir"
trap 'rm -rf "$build_dir" "$adapter_build_dir" "$probe_core_dir" "$probe_session_dir"' EXIT
render_node="${KOOKIE_RENDER_NODE:-}"
if [[ -z "$render_node" ]]; then
  for candidate in /dev/dri/renderD*; do
    if [[ -c "$candidate" ]]; then
      render_node="$candidate"
      break
    fi
  done
fi
render_node_args=()
if [[ -n "$render_node" ]]; then
  render_node_args=(--render-node "$render_node")
  echo "isolated SDL adapter render node: $render_node"
fi


if command -v gcc >/dev/null && command -v glslc >/dev/null && command -v pkg-config >/dev/null && command -v overzeer-isolated-display >/dev/null &&
   pkg-config --exists sdl3 && [[ -f /usr/include/SDL3/SDL.h ]]; then
  mkdir -p "$probe_core_dir" "$probe_session_dir"
  for core_file in "$root_dir"/src/core/*.kf; do
    ln -s "$core_file" "$probe_core_dir/$(basename "$core_file")"
  done
  for session_file in "$root_dir"/src/session/*.kf; do
    ln -s "$session_file" "$probe_session_dir/$(basename "$session_file")"
  done
  gcc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
    native/kookie_sdl_adapter.c \
    -o "$adapter_build_dir/libkookie_sdl_adapter.so" \
    $(pkg-config --cflags --libs sdl3)
  glslc -fshader-stage=vert native/shaders/g0_triangle.vert \
    -o "$adapter_build_dir/g0_triangle.vert.spv"
  glslc -fshader-stage=frag native/shaders/g0_triangle.frag \
    -o "$adapter_build_dir/g0_triangle.frag.spv"
  SDL_AUDIODRIVER=dummy kof build probes/g0_native_adapter/main.kf \
    --target native --output "$adapter_build_dir/native-adapter"
  overzeer-isolated-display --timeout 90 "${render_node_args[@]}" -- \
    env KOOKIE_TRANSPORT_KEY_FILE="$transport_key_file" \
    KOOKIE_TRANSPORT_KEY_HEX=00000001000000020000000300000004 \
    KOOKIE_SCREENSHOT_PATH="${KOOKIE_SCREENSHOT_PATH:-}" \
    KOOKIE_SHADER_DIR="$adapter_build_dir" SDL_AUDIODRIVER=dummy \
    SDL_VIDEODRIVER="${KOOKIE_SDL_VIDEO_DRIVER:-offscreen}" \
    "$adapter_build_dir/native-adapter/Default/Main"
else
  echo "native SDL adapter smoke skipped: SDL3 development headers, gcc, glslc, pkg-config, or isolated-display wrapper unavailable"
fi

kof build src --target jvm --output "$build_dir/jvm"
kof build src --target native --output "$build_dir/native"

echo "KOOKIE verification passed: linter, LSP, JVM/native checks, tests, runtime smoke, adapter smoke when available, and JVM/native builds"
