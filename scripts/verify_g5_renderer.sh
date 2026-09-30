#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for command_name in kof cc glslc ldd pkg-config python3; do
  command -v "$command_name" >/dev/null || {
    printf 'G5 renderer gate requires %s\n' "$command_name" >&2
    exit 75
  }
done
ISOLATION_WRAPPER="${KOOKIE_PRESENTATION_ISOLATION_WRAPPER:-}"
RENDER_TIMEOUT_SECONDS="${KOOKIE_G5_RENDER_TIMEOUT_SECONDS:-120}"
[[ "$RENDER_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  echo 'KOOKIE_G5_RENDER_TIMEOUT_SECONDS must be a positive integer' >&2
  exit 2
}
if [[ -z "$ISOLATION_WRAPPER" ]] || ! command -v "$ISOLATION_WRAPPER" >/dev/null; then
  echo 'G5 renderer gate requires KOOKIE_PRESENTATION_ISOLATION_WRAPPER' >&2
  exit 75
fi
pkg-config --exists sdl3 sdl3-mixer || {
  echo 'G5 renderer gate requires SDL3 and SDL_mixer development files' >&2
  exit 75
}

mkdir -p "$ROOT_DIR/build"
WORK_DIR="$(mktemp -d "$ROOT_DIR/build/g5-renderer.XXXXXX")"
EVIDENCE_DIR="${KOOKIE_G5_RENDER_EVIDENCE_DIR:-$ROOT_DIR/build/g5-renderer-evidence}"
SOURCE_DIR="$WORK_DIR/source"
BINARY_DIR="$WORK_DIR/native"
LOG_PATH="$EVIDENCE_DIR/renderer.log"
SCREENSHOT_PATH="$EVIDENCE_DIR/reference.ppm"
INNER_SCREENSHOT_PATH="$SOURCE_DIR/reference.ppm"
cleanup() {
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM
mkdir -p "$SOURCE_DIR"/{core,content,session,build} "$EVIDENCE_DIR"
for source_file in "$ROOT_DIR/src/core/"*.kf; do
  ln -s "$source_file" "$SOURCE_DIR/core/$(basename "$source_file")"
done
for source_file in "$ROOT_DIR/src/content/"*.kf; do
  ln -s "$source_file" "$SOURCE_DIR/content/$(basename "$source_file")"
done
for source_file in "$ROOT_DIR/src/session/"*.kf; do
  ln -s "$source_file" "$SOURCE_DIR/session/$(basename "$source_file")"
done
cp -- "$ROOT_DIR/probes/g5_reference_renderer/main.kf" "$SOURCE_DIR/main.kf"

IFS=' ' read -r -a SDL_FLAGS <<<"$(pkg-config --cflags --libs sdl3 sdl3-mixer)"
cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared \
  "$ROOT_DIR/native/kookie_sdl_adapter.c" \
  "$ROOT_DIR/native/kookie_transport.c" \
  -o "$SOURCE_DIR/build/libkookie_sdl_adapter.so" \
  "${SDL_FLAGS[@]}"
while IFS= read -r library; do
  case "$(basename "$library")" in
    libSDL3.so*|libSDL3_mixer.so*)
      cp -L -- "$library" "$SOURCE_DIR/build/$(basename "$library")"
      ;;
  esac
done < <(ldd "$SOURCE_DIR/build/libkookie_sdl_adapter.so" |
  sed -n -E 's/.*=> (\/[^ ]+) .*/\1/p')
glslc -fshader-stage=vert "$ROOT_DIR/native/shaders/g0_triangle.vert" \
  -o "$SOURCE_DIR/build/g0_triangle.vert.spv"
glslc -fshader-stage=vert "$ROOT_DIR/native/shaders/g5_triangle_instance.vert" \
  -o "$SOURCE_DIR/build/g5_triangle_instance.vert.spv"
glslc -fshader-stage=frag "$ROOT_DIR/native/shaders/g0_triangle.frag" \
  -o "$SOURCE_DIR/build/g0_triangle.frag.spv"
(
  cd "$SOURCE_DIR"
  kof build main.kf --target native --output "$BINARY_DIR"
)
BINARY="$BINARY_DIR/Default/Main"
test -x "$BINARY"
cp -- "$BINARY" "$SOURCE_DIR/kookie-g5-renderer"
BINARY="$SOURCE_DIR/kookie-g5-renderer"

render_node="${KOOKIE_RENDER_NODE:-}"
if [[ -z "$render_node" ]]; then
  for candidate in /dev/dri/renderD*; do
    if [[ -c "$candidate" ]]; then
      render_node="$candidate"
      break
    fi
  done
fi
if [[ -z "$render_node" ]]; then
  echo 'G5 renderer gate: a hardware render-only DRM node is required' >&2
  exit 1
fi
render_args=(--render-node "$render_node")
render_status=75
for attempt in 1 2 3; do
  set +e
  (
    cd "$SOURCE_DIR"
    LIBGL_ALWAYS_SOFTWARE=0 "$ISOLATION_WRAPPER" \
      --timeout "$RENDER_TIMEOUT_SECONDS" --screen 1920x1080x24 \
      "${render_args[@]}" -- \
      env KOOKIE_SHADER_DIR="$SOURCE_DIR/build" \
      KOOKIE_SCREENSHOT_PATH="$INNER_SCREENSHOT_PATH" \
      LD_LIBRARY_PATH="$SOURCE_DIR/build" \
      SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=offscreen \
      "$BINARY"
  ) >"$LOG_PATH" 2>&1
  render_status=$?
  set -e
  if [[ "$render_status" -ne 75 ]]; then
    break
  fi
  sleep 15
done
cat "$LOG_PATH"
if [[ "$render_status" -ne 0 ]]; then
  exit "$render_status"
fi
cp -- "$INNER_SCREENSHOT_PATH" "$SCREENSHOT_PATH"

python3 - "$LOG_PATH" "$SCREENSHOT_PATH" <<'PY'
import pathlib
import sys

log = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
assert "KOOKIE G5 native reference renderer verified" in log
fields = {}
for line in log:
    if line.startswith("KOOKIE G5 renderer-") and "=" in line:
        key, value = line.split("=", 1)
        fields[key.removeprefix("KOOKIE G5 renderer-")] = value
assert fields["resolution"] == "1920x1080"
assert fields["driver"] == "vulkan"
device_name = fields["device"].lower()
assert device_name != "unknown"
assert all(marker not in device_name for marker in ("llvmpipe", "lavapipe", "software"))
assert int(fields["frames"]) == 600
assert int(fields["vertices"]) == 2952
assert int(fields["draw-calls"]) == 1
assert int(fields["instances"]) == 984
p50 = int(fields["p50-us"])
p95 = int(fields["p95-us"])
p99 = int(fields["p99-us"])
maximum = int(fields["max-us"])
assert 0 < p50 <= p95 <= p99 <= maximum
assert p95 <= 8333
screenshot = pathlib.Path(sys.argv[2])
assert screenshot.is_file() and screenshot.stat().st_size > 32
PY

printf 'KOOKIE G5 renderer gate passed: evidence=%s\n' "$EVIDENCE_DIR"
