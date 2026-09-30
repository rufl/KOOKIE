#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

command -v kof >/dev/null || { echo "kof is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

expected_kof_version="kof 0.5.0-beta"
actual_kof_version="$(kof version)"
if [[ "$actual_kof_version" != "$expected_kof_version" ]]; then
  printf 'KOOKIE requires %s; found %s\n' \
    "$expected_kof_version" "$actual_kof_version" >&2
  exit 1
fi

python3 scripts/lint_kf.py src probes apps
python3 scripts/lsp_verify.py src
python3 scripts/lsp_verify.py probes

kof check src --target jvm
kof check src --target native
kof test src/main.kf --target jvm
kof test src/main.kf --target native
bash scripts/verify_exception.sh
bash scripts/verify_simd_dispatch.sh
bash scripts/verify_interactions.sh
bash scripts/verify_durable_save.sh
bash scripts/verify_dedicated_server.sh
bash scripts/verify_dedicated_network.sh
bash scripts/verify_package.sh

expected_output=$'KOOKIE G0 session foundation\n60\ntrue\nKOOKIE G0 resource tokens verified\nKOOKIE G0 scalar adapter contracts verified\nKOOKIE G0 frame staging verified\nKOOKIE G1 authoritative shooter verified'
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
probe_content_dir="$root_dir/probes/g0_native_adapter/content"
probe_session_dir="$root_dir/probes/g0_native_adapter/session"
probe_world_dir="$root_dir/probes/g0_native_adapter/world"
probe_ui_dir="$root_dir/probes/g0_native_adapter/ui"
probe_demo_dir="$root_dir/probes/g0_native_adapter/demo"
presentation_probe_core_dir="$root_dir/probes/g0_native_presentation/core"
presentation_probe_content_dir="$root_dir/probes/g0_native_presentation/content"
presentation_probe_session_dir="$root_dir/probes/g0_native_presentation/session"
presentation_probe_world_dir="$root_dir/probes/g0_native_presentation/world"
presentation_probe_ui_dir="$root_dir/probes/g0_native_presentation/ui"
presentation_probe_demo_dir="$root_dir/probes/g0_native_presentation/demo"
rm -rf "$probe_core_dir" "$probe_content_dir" "$probe_session_dir" \
  "$probe_world_dir" "$probe_ui_dir" "$probe_demo_dir" \
  "$presentation_probe_core_dir" "$presentation_probe_content_dir" \
  "$presentation_probe_session_dir" "$presentation_probe_world_dir" \
  "$presentation_probe_ui_dir" "$presentation_probe_demo_dir"
trap 'rm -rf "$build_dir" "$adapter_build_dir" "$probe_core_dir" "$probe_content_dir" "$probe_session_dir" "$probe_world_dir" "$probe_ui_dir" "$probe_demo_dir" "$presentation_probe_core_dir" "$presentation_probe_content_dir" "$presentation_probe_session_dir" "$presentation_probe_world_dir" "$presentation_probe_ui_dir" "$presentation_probe_demo_dir"' EXIT
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

isolation_wrapper="${KOOKIE_PRESENTATION_ISOLATION_WRAPPER:-}"
if command -v gcc >/dev/null && command -v glslc >/dev/null && command -v pkg-config >/dev/null &&
   [[ -n "$isolation_wrapper" ]] && command -v "$isolation_wrapper" >/dev/null &&
   pkg-config --exists sdl3 sdl3-mixer; then
  mkdir -p "$probe_core_dir" "$probe_content_dir" "$probe_session_dir" \
    "$probe_world_dir" "$probe_ui_dir" "$probe_demo_dir" \
    "$presentation_probe_core_dir" "$presentation_probe_content_dir" \
    "$presentation_probe_session_dir" "$presentation_probe_world_dir" \
    "$presentation_probe_ui_dir" "$presentation_probe_demo_dir"
  for core_file in "$root_dir"/src/core/*.kf; do
    ln -s "$core_file" "$probe_core_dir/$(basename "$core_file")"
    ln -s "$core_file" "$presentation_probe_core_dir/$(basename "$core_file")"
  done
  for content_file in "$root_dir"/src/content/*.kf; do
    ln -s "$content_file" "$probe_content_dir/$(basename "$content_file")"
    ln -s "$content_file" \
      "$presentation_probe_content_dir/$(basename "$content_file")"
  done
  for session_file in "$root_dir"/src/session/*.kf; do
    ln -s "$session_file" "$probe_session_dir/$(basename "$session_file")"
    ln -s "$session_file" "$presentation_probe_session_dir/$(basename "$session_file")"
  done
  for world_file in "$root_dir"/src/world/*.kf; do
    ln -s "$world_file" "$probe_world_dir/$(basename "$world_file")"
    ln -s "$world_file" "$presentation_probe_world_dir/$(basename "$world_file")"
  done
  for ui_file in "$root_dir"/src/ui/*.kf; do
    ln -s "$ui_file" "$probe_ui_dir/$(basename "$ui_file")"
    ln -s "$ui_file" "$presentation_probe_ui_dir/$(basename "$ui_file")"
  done
  for demo_file in "$root_dir"/src/demo/*.kf; do
    ln -s "$demo_file" "$probe_demo_dir/$(basename "$demo_file")"
    ln -s "$demo_file" "$presentation_probe_demo_dir/$(basename "$demo_file")"
  done
  gcc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
    native/kookie_sdl_adapter.c \
    native/kookie_transport.c \
    -o "$adapter_build_dir/libkookie_sdl_adapter.so" \
    $(pkg-config --cflags --libs sdl3 sdl3-mixer)
  glslc -fshader-stage=vert native/shaders/g0_triangle.vert \
    -o "$adapter_build_dir/g0_triangle.vert.spv"
  glslc -fshader-stage=vert native/shaders/g5_triangle_instance.vert \
    -o "$adapter_build_dir/g5_triangle_instance.vert.spv"
  glslc -fshader-stage=frag native/shaders/g0_triangle.frag \
    -o "$adapter_build_dir/g0_triangle.frag.spv"
  SDL_AUDIODRIVER=dummy kof build probes/g0_native_adapter/main.kf \
    --target native --output "$adapter_build_dir/native-adapter"
  if [[ "${KOOKIE_REQUIRE_PRESENTATION:-0}" == "1" ]]; then
    SDL_AUDIODRIVER=dummy kof build probes/g0_native_presentation/main.kf \
      --target native --output "$adapter_build_dir/native-presentation"
  fi
  adapter_log="${KOOKIE_PRESENTATION_ADAPTER_LOG:-$build_dir/native-adapter.log}"
  mkdir -p "$(dirname "$adapter_log")"
  presentation_compositor_bin="${KOOKIE_PRESENTATION_COMPOSITOR_BIN:-}"
  presentation_compositor_libdir="${KOOKIE_PRESENTATION_COMPOSITOR_LIBDIR:-}"
  presentation_env=()
  if [[ "${KOOKIE_REQUIRE_PRESENTATION:-0}" == "1" ]]; then
    presentation_command=("$adapter_build_dir/native-presentation/Default/Main")
  else
    presentation_command=("$adapter_build_dir/native-adapter/Default/Main")
  fi
  if [[ -n "$presentation_compositor_bin" ]]; then
    [[ -x "$presentation_compositor_bin" ]] || {
      echo "presentation compositor is not executable: $presentation_compositor_bin" >&2
      exit 75
    }
    if [[ -n "$presentation_compositor_libdir" ]]; then
      [[ -d "$presentation_compositor_libdir" ]] || {
        echo "presentation compositor library directory is unavailable: $presentation_compositor_libdir" >&2
        exit 75
      }
      existing_ld_library_path="${LD_LIBRARY_PATH:-}"
      presentation_env+=(
        "LD_LIBRARY_PATH=$presentation_compositor_libdir${existing_ld_library_path:+:$existing_ld_library_path}"
      )
    fi
    presentation_env+=(
      "WLR_BACKENDS=${KOOKIE_PRESENTATION_WLR_BACKENDS:-headless}"
      "WLR_RENDERER=${KOOKIE_PRESENTATION_WLR_RENDERER:-gles2}"
      "WLR_HEADLESS_OUTPUTS=${KOOKIE_PRESENTATION_WLR_HEADLESS_OUTPUTS:-1}"
      "WLR_LIBINPUT_NO_DEVICES=${KOOKIE_PRESENTATION_WLR_LIBINPUT_NO_DEVICES:-1}"
      "WLR_LOG=${KOOKIE_PRESENTATION_WLR_LOG:-error}"
      "DISABLE_LSFGVK=${DISABLE_LSFGVK:-1}"
    )
    presentation_command=("$presentation_compositor_bin" -- "${presentation_command[@]}")
    echo "isolated SDL adapter compositor: $presentation_compositor_bin"
  fi
  set +e
  "$isolation_wrapper" --timeout 90 "${render_node_args[@]}" -- \
    env "${presentation_env[@]}" \
    KOOKIE_TRANSPORT_KEY_FILE="$transport_key_file" \
    KOOKIE_TRANSPORT_KEY_HEX=00000001000000020000000300000004 \
    KOOKIE_PRESENTATION_SMOKE="${KOOKIE_REQUIRE_PRESENTATION:-0}" \
    KOOKIE_SCREENSHOT_PATH="${KOOKIE_SCREENSHOT_PATH:-}" \
    KOOKIE_SHADER_DIR="$adapter_build_dir" SDL_AUDIODRIVER=dummy \
    SDL_VIDEODRIVER="${KOOKIE_SDL_VIDEO_DRIVER:-offscreen}" \
    "${presentation_command[@]}" \
    >"$adapter_log" 2>&1
  adapter_status=$?
  set -e
  cat "$adapter_log"
  if [[ "$adapter_status" -eq 75 ]]; then
    echo "native SDL adapter smoke deferred: isolated display safety gate unavailable"
    if [[ "${KOOKIE_REQUIRE_PRESENTATION:-0}" == "1" ]]; then
      exit 75
    fi
  elif [[ "$adapter_status" -ne 0 ]]; then
    exit "$adapter_status"
  fi
  if [[ "$adapter_status" -eq 0 ]]; then
    KOOKIE_PRESENTATION_ISOLATION_WRAPPER="$isolation_wrapper" \
      bash scripts/verify_g5_renderer.sh
  fi
  if [[ "${KOOKIE_REQUIRE_PRESENTATION:-0}" == "1" ]]; then
    KOOKIE_RENDER_NODE="$render_node" \
      python3 scripts/validate_presentation_evidence.py \
        "$adapter_log" "${KOOKIE_SCREENSHOT_PATH:-}" \
        "${KOOKIE_PRESENTATION_EVIDENCE_JSON:-}"
  fi
else
  echo "native SDL adapter smoke skipped: SDL3/SDL_mixer development files, gcc, glslc, pkg-config, or isolated-display wrapper unavailable"
fi

kof build src --target jvm --output "$build_dir/jvm"
kof build src --target native --output "$build_dir/native"

echo "KOOKIE verification passed: linter, LSP, JVM/native checks, tests, runtime smoke, durable save, adapter/reference renderer smoke when available, packages, and JVM/native builds"
