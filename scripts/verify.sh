#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
source "$root_dir/scripts/kof_pin.sh"
source "$root_dir/scripts/sdl3_dependencies.sh"
source "$root_dir/scripts/native_text_dependencies.sh"
command -v kof >/dev/null || { echo "kof is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

expected_kof_version="$KOF_PIN_CLI_VERSION"
actual_kof_version="$(kof version)"
if [[ "$actual_kof_version" != "$expected_kof_version" ]]; then
  printf 'KOOKIE requires %s; found %s\n' \
    "$expected_kof_version" "$actual_kof_version" >&2
  exit 1
fi

bash scripts/verify_package_preflight.sh

if [[ "${KOOKIE_VERIFY_SKIP_STATIC:-0}" != 1 ]]; then
  bash scripts/verify_static.sh
else
  KOOKIE_FONT_UI_TARGETS=native bash scripts/verify_font_ui.sh
  KOOKIE_UI_LIBRARY_TARGETS=native \
    KOOKIE_UI_LIBRARY_SKIP_JS=1 \
    bash scripts/verify_ui_library.sh
  KOOKIE_UI_SOUND_TARGETS=native bash scripts/verify_ui_sound_catalog.sh
fi

# The JVM test keeps the per-file Kof test-runner contract; native `src` is
# compiled and executed once by the final build/smoke below instead of being
# recompiled through the same harness.
bash scripts/verify_exception.sh
bash scripts/verify_simd_dispatch.sh
bash scripts/verify_transport.sh
python3 scripts/verify_external_lan_metadata.py
bash scripts/verify_external_lan_parity.sh
python3 scripts/verify_model_loader_sanitizer.py
bash scripts/verify_interactions.sh
bash scripts/verify_durable_save.sh
bash scripts/verify_goose_game.sh
bash scripts/verify_pe_durable_save.sh
bash scripts/verify_dedicated_server.sh
bash scripts/verify_dedicated_network.sh


if [[ -f /usr/lib/libSDL3.so ]]; then
  platform_output=$'KOOKIE G0 scalar platform probe\n3004018\ntrue'
  [[ "$(kookie_kof_observed platform-jvm kof run \
    probes/g0_platform/main.kf --target jvm)" == "$platform_output" ]]
  [[ "$(kookie_kof_observed platform-native kof run \
    probes/g0_platform/main.kf --target native 2>/dev/null)" == \
    "$platform_output" ]]
else
  echo "SDL3 scalar platform probe skipped: /usr/lib/libSDL3.so is unavailable"
fi
canonical_build_cache_dir="${KOOKIE_CANONICAL_BUILD_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/kookie/canonical}"
canonical_build_cleanup=1
if [[ -n "$canonical_build_cache_dir" ]]; then
  canonical_build_dir="$canonical_build_cache_dir"
  mkdir -p "$canonical_build_dir"
  canonical_build_cleanup=0
else
  canonical_build_dir="$(mktemp -d -t kookie-canonical-build-XXXXXX)"
fi
canonical_jvm_build="$canonical_build_dir/jvm"
canonical_jvm_manifest="$canonical_build_dir/jvm.identity"
canonical_native_build="$canonical_build_dir/native"
canonical_native_manifest="$canonical_build_dir/native.identity"
canonical_cache_valid=0
if (( canonical_build_cleanup == 0 )) &&
   bash scripts/write_build_identity.sh --check jvm \
     "$canonical_jvm_build" "$canonical_jvm_manifest" &&
   bash scripts/write_build_identity.sh --check native \
     "$canonical_native_build" "$canonical_native_manifest"; then
  canonical_cache_valid=1
fi
if (( canonical_cache_valid == 0 )); then
  rm -rf -- "$canonical_build_dir"
  mkdir -p "$canonical_jvm_build" "$canonical_native_build"
  kookie_kof_observed canonical-jvm kof build src --target jvm \
    --output "$canonical_jvm_build"
  kookie_kof_observed canonical-native kof build src --target native \
    --output "$canonical_native_build"
  bash scripts/write_build_identity.sh jvm \
    "$canonical_jvm_build" "$canonical_jvm_manifest"
  bash scripts/write_build_identity.sh native \
    "$canonical_native_build" "$canonical_native_manifest"
else
  echo "Reusing canonical JVM/native builds from $canonical_build_dir"
fi
export KOOKIE_PREBUILT_NATIVE_BUILD="$canonical_native_build"
export KOOKIE_PREBUILT_NATIVE_MANIFEST="$canonical_native_manifest"
bash scripts/verify_package.sh
bash scripts/verify_prototype_package.sh


build_dir="$(mktemp -d -t kookie-build-XXXXXX)"
adapter_build_dir="$build_dir/adapter"
mkdir -p "$adapter_build_dir/build"
mkdir -p "$adapter_build_dir"/assets/{fonts,ui,prototype/runtime,audio}
cp -- "$root_dir/assets/fonts/jared-lite.ttf" \
  "$adapter_build_dir/assets/fonts/jared-lite.ttf"
cp -- "$root_dir/assets/fonts/pixand.ttf" \
  "$adapter_build_dir/assets/fonts/pixand.ttf"
cp -- "$root_dir/assets/ui/gatoganso-mark.svg" \
  "$adapter_build_dir/assets/ui/gatoganso-mark.svg"
cp -a -- "$root_dir/assets/prototype/runtime/vfx" \
  "$adapter_build_dir/assets/prototype/runtime/"
cp -a -- "$root_dir/assets/audio/ui" \
  "$adapter_build_dir/assets/audio/"
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
if (( canonical_build_cleanup == 1 )); then
  trap 'rm -rf "$canonical_build_dir" "$build_dir" "$adapter_build_dir" "$probe_core_dir" "$probe_content_dir" "$probe_session_dir" "$probe_world_dir" "$probe_ui_dir" "$probe_demo_dir" "$presentation_probe_core_dir" "$presentation_probe_content_dir" "$presentation_probe_session_dir" "$presentation_probe_world_dir" "$presentation_probe_ui_dir" "$presentation_probe_demo_dir"' EXIT
else
  trap 'rm -rf "$build_dir" "$adapter_build_dir" "$probe_core_dir" "$probe_content_dir" "$probe_session_dir" "$probe_world_dir" "$probe_ui_dir" "$probe_demo_dir" "$presentation_probe_core_dir" "$presentation_probe_content_dir" "$presentation_probe_session_dir" "$presentation_probe_world_dir" "$presentation_probe_ui_dir" "$presentation_probe_demo_dir"' EXIT
fi
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

isolation_wrapper="${KOOKIE_PRESENTATION_ISOLATION_WRAPPER:-$root_dir/scripts/linux_gamescope_isolated_display}"
presentation_dependencies_available=0
if kookie_prepare_sdl3_dependencies "$root_dir" &&
   kookie_require_native_text_dependencies "$root_dir"; then
  presentation_dependencies_available=1
fi
if command -v gcc >/dev/null && command -v glslc >/dev/null &&
   command -v spirv-val >/dev/null &&
   [[ "$presentation_dependencies_available" == 1 ]] &&
   [[ -n "$isolation_wrapper" ]] && command -v "$isolation_wrapper" >/dev/null; then
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
  cp "$root_dir/probes/shared/gpu_scene_batch.kf" \
    "$probe_core_dir/gpu_scene_batch.kf"
  cp "$root_dir/probes/shared/gpu_scene_batch.kf" \
    "$presentation_probe_core_dir/gpu_scene_batch.kf"
  cp "$root_dir/probes/shared/pe_durable_save_coordinator.kf" \
    "$presentation_probe_session_dir/pe_durable_save_coordinator.kf"
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
    kookie_kof_observed g0-native-adapter kof build \
      "$root_dir/probes/g0_native_adapter/main.kf" \
      --target native --output "$adapter_build_dir/native-adapter"
  )
  if [[ "${KOOKIE_REQUIRE_PRESENTATION:-0}" == "1" ]]; then
    (
      cd "$adapter_build_dir"
      kookie_kof_observed g0-native-presentation kof build \
        "$root_dir/probes/g0_native_presentation/main.kf" \
        --target native --output "$adapter_build_dir/native-presentation"
    )
  fi
  adapter_log="${KOOKIE_PRESENTATION_ADAPTER_LOG:-$build_dir/native-adapter.log}"
  mkdir -p "$(dirname "$adapter_log")"
  presentation_compositor_bin="${KOOKIE_PRESENTATION_COMPOSITOR_BIN:-}"
  presentation_compositor_libdir="${KOOKIE_PRESENTATION_COMPOSITOR_LIBDIR:-}"
  presentation_env=()
  presentation_binary="$adapter_build_dir/native-adapter/Default/Main"
  if [[ "${KOOKIE_REQUIRE_PRESENTATION:-0}" == "1" ]]; then
    presentation_binary="$adapter_build_dir/native-presentation/Default/Main"
  fi
  presentation_command=(
    bash -c 'cd "$1" && exec "$2"'
    --
    "$adapter_build_dir"
    "$presentation_binary"
  )
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
    KOOKIE_ASSET_DIR="$adapter_build_dir/assets" \
    KOOKIE_CONTENT_DIR="$adapter_build_dir/assets/prototype" \
    KOOKIE_TRANSPORT_KEY_FILE="$transport_key_file" \
    KOOKIE_TRANSPORT_KEY_HEX=00000001000000020000000300000004 \
    KOOKIE_PRESENTATION_SMOKE="${KOOKIE_REQUIRE_PRESENTATION:-0}" \
    KOOKIE_SCREENSHOT_PATH="${KOOKIE_SCREENSHOT_PATH:-}" \
    KOOKIE_AUDIO_MUSIC_OGG="$adapter_build_dir/assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg" \
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
  echo "native SDL adapter smoke skipped: SDL3/SDL_mixer development files, gcc, glslc, spirv-val, pkg-config, or isolated-display wrapper unavailable"
fi

# The canonical JVM/native builds were produced before package gates and are
# reused here as direct runtime smoke artifacts.
expected_output=$'KOOKIE G0 session foundation\n60\ntrue\nKOOKIE G0 resource tokens verified\nKOOKIE G0 scalar adapter contracts verified\nKOOKIE G0 frame staging verified\nKOOKIE G1 authoritative shooter verified'
jvm_output="$(
  cd "$root_dir"
  java --enable-native-access=ALL-UNNAMED -cp "$canonical_jvm_build" Default.Main
)"
[[ "$jvm_output" == "$expected_output" ]]
native_output="$(
  cd "$root_dir"
  "$canonical_native_build/Default/Main" 2>/dev/null
)"
[[ "$native_output" == "$expected_output" ]]

if [[ "${KOOKIE_VERIFY_SKIP_STATIC:-0}" == 1 ]]; then
  echo "KOOKIE native verification passed: native UI/runtime smoke, durable save, adapter/reference renderer smoke when available, packages, and JVM/native builds"
else
  echo "KOOKIE verification passed: linter, LSP, JVM checks/test, native build/runtime smoke, durable save, adapter/reference renderer smoke when available, packages, and JVM/native builds"
fi
