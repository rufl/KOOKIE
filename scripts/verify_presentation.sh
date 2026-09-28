#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

artifact_dir="${KOOKIE_PRESENTATION_EVIDENCE_DIR:-/tmp/kookie-presentation-$$}"
mkdir -p "$artifact_dir"
export KOOKIE_REQUIRE_PRESENTATION=1
export KOOKIE_SDL_VIDEO_DRIVER="${KOOKIE_SDL_VIDEO_DRIVER:-x11}"
export KOOKIE_SCREENSHOT_PATH="${KOOKIE_SCREENSHOT_PATH:-$artifact_dir/presentation.ppm}"
export KOOKIE_PRESENTATION_EVIDENCE_JSON="${KOOKIE_PRESENTATION_EVIDENCE_JSON:-$artifact_dir/evidence.json}"
export KOOKIE_PRESENTATION_BLOCKER_JSON="${KOOKIE_PRESENTATION_BLOCKER_JSON:-$artifact_dir/blocker.json}"
export KOOKIE_PRESENTATION_ADAPTER_LOG="${KOOKIE_PRESENTATION_ADAPTER_LOG:-$artifact_dir/adapter.log}"
export KOOKIE_PRESENTATION_COMMAND="${KOOKIE_PRESENTATION_COMMAND:-bash scripts/verify_presentation.sh}"
export KOOKIE_PRESENTATION_ISOLATION_WRAPPER="${KOOKIE_PRESENTATION_ISOLATION_WRAPPER:-}"

record_blocker() {
  local status="$1"
  local reason="$2"
  if command -v python3 >/dev/null; then
    python3 scripts/record_presentation_blocker.py \
      "$KOOKIE_PRESENTATION_ADAPTER_LOG" \
      "$KOOKIE_PRESENTATION_BLOCKER_JSON" \
      "$status" "$reason" || true
  fi
  echo "presentation gate blocked: $reason" >&2
  exit "$status"
}

if [[ -z "$KOOKIE_PRESENTATION_ISOLATION_WRAPPER" ]]; then
  record_blocker 75 "isolation-wrapper-not-configured"
fi
for command_name in kof python3 gcc glslc pkg-config; do
  command -v "$command_name" >/dev/null || \
    record_blocker 75 "missing-$command_name"
done
command -v "$KOOKIE_PRESENTATION_ISOLATION_WRAPPER" >/dev/null || \
  record_blocker 75 "isolation-wrapper-unavailable"
if ! pkg-config --exists sdl3 || [[ ! -f /usr/include/SDL3/SDL.h ]]; then
  record_blocker 75 "sdl3-development-files-unavailable"
fi
if [[ "$KOOKIE_SDL_VIDEO_DRIVER" == "offscreen" ]]; then
  record_blocker 75 "offscreen-video-driver"
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
if [[ -z "$render_node" || ! -c "$render_node" ]]; then
  record_blocker 75 "render-node-unavailable"
fi
export KOOKIE_RENDER_NODE="$render_node"
presentation_compositor_bin="${KOOKIE_PRESENTATION_COMPOSITOR_BIN:-}"
presentation_compositor_libdir="${KOOKIE_PRESENTATION_COMPOSITOR_LIBDIR:-}"
if [[ -n "$presentation_compositor_bin" && ! -x "$presentation_compositor_bin" ]]; then
  record_blocker 75 "presentation-compositor-unavailable"
fi
if [[ -n "$presentation_compositor_libdir" && ! -d "$presentation_compositor_libdir" ]]; then
  record_blocker 75 "presentation-compositor-libdir-unavailable"
fi

set +e
bash scripts/verify.sh
verification_status=$?
set -e
if [[ "$verification_status" -ne 0 ]]; then
  python3 scripts/record_presentation_blocker.py \
    "$KOOKIE_PRESENTATION_ADAPTER_LOG" \
    "$KOOKIE_PRESENTATION_BLOCKER_JSON" \
    "$verification_status" "" || true
  exit "$verification_status"
fi
printf 'presentation evidence: %s\n' "$KOOKIE_PRESENTATION_EVIDENCE_JSON"
