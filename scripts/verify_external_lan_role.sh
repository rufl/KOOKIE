#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
source "$root_dir/scripts/kof_pin.sh"
source "$root_dir/scripts/sdl3_dependencies.sh"
source "$root_dir/scripts/native_text_dependencies.sh"
role="${KOOKIE_EXTERNAL_LAN_ROLE:-}"
case "$role" in
  host|client-a|client-b) ;;
  *)
    echo "external LAN role runner requires KOOKIE_EXTERNAL_LAN_ROLE=host|client-a|client-b" >&2
    exit 64
    ;;
esac

target="${KOOKIE_EXTERNAL_LAN_TARGET:-native}"
case "$target" in
  native|jvm) ;;
  *)
    echo "external LAN role runner requires KOOKIE_EXTERNAL_LAN_TARGET=native|jvm" >&2
    exit 64
    ;;
esac

command -v kof >/dev/null || { echo "external LAN role requires kof" >&2; exit 75; }
command -v python3 >/dev/null || { echo "external LAN role requires python3" >&2; exit 75; }
if [[ "$target" == native ]]; then
  command -v gcc >/dev/null || { echo "external LAN native role requires gcc" >&2; exit 75; }
  command -v glslc >/dev/null || { echo "external LAN native role requires glslc" >&2; exit 75; }
  command -v spirv-val >/dev/null || { echo "external LAN native role requires spirv-val" >&2; exit 75; }
  command -v pkg-config >/dev/null || {
    echo "external LAN native role requires pkg-config" >&2
    exit 75
  }
  kookie_require_sdl3_dependencies "$root_dir" || {
    echo "external LAN native role requires SDL3 and SDL_mixer" >&2
    exit 75
  }
  kookie_require_native_text_dependencies "$root_dir" || {
    echo "external LAN native role requires FreeType and HarfBuzz" >&2
    exit 75
  }
else
  command -v java >/dev/null || { echo "external LAN JVM role requires java" >&2; exit 75; }
  command -v javac >/dev/null || { echo "external LAN JVM role requires javac" >&2; exit 75; }
  command -v jar >/dev/null || { echo "external LAN JVM role requires jar" >&2; exit 75; }
fi

transport_key="${KOOKIE_TRANSPORT_KEY_HEX:-}"
if [[ ! "$transport_key" =~ ^[0-9a-fA-F]{32}$ ||
      "$transport_key" =~ ^0+$ ]]; then
  echo "external LAN role requires a non-zero 32-character hexadecimal KOOKIE_TRANSPORT_KEY_HEX" >&2
  exit 64
fi
export KOOKIE_TRANSPORT_KEY_HEX="$transport_key"
export KOOKIE_EXTERNAL_LAN_HOST_IPV4="${KOOKIE_EXTERNAL_LAN_HOST_IPV4:-127.0.0.1}"
export KOOKIE_EXTERNAL_LAN_TIMEOUT_MILLISECONDS="${KOOKIE_EXTERNAL_LAN_TIMEOUT_MILLISECONDS:-30000}"
run_id="${KOOKIE_EXTERNAL_LAN_RUN_ID:-}"
if [[ ! "$run_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{7,127}$ ]]; then
  echo "external LAN role requires shared KOOKIE_EXTERNAL_LAN_RUN_ID" >&2
  exit 64
fi
run_manifest="${KOOKIE_EXTERNAL_LAN_RUN_MANIFEST:-}"
if [[ -z "$run_manifest" || ! -f "$run_manifest" ]]; then
  echo "external LAN role requires KOOKIE_EXTERNAL_LAN_RUN_MANIFEST" >&2
  exit 64
fi
export KOOKIE_EXTERNAL_LAN_RUN_ID="$run_id"
export KOOKIE_EXTERNAL_LAN_RUN_MANIFEST="$run_manifest"

artifact_dir="${KOOKIE_EXTERNAL_LAN_EVIDENCE_DIR:-/tmp/kookie-external-lan-role-${role}-$$}"
mkdir -p "$artifact_dir"
artifact_dir="$(cd "$artifact_dir" && pwd)"
probe_log="${KOOKIE_EXTERNAL_LAN_PROBE_LOG:-$artifact_dir/probe.log}"
if [[ "$probe_log" != /* ]]; then
  probe_log="$root_dir/$probe_log"
fi
build_dir="${KOOKIE_EXTERNAL_LAN_ROLE_BUILD_DIR:-$(mktemp -d -t kookie-external-lan-role-XXXXXX)}"
remove_build_dir=1
if [[ -n "${KOOKIE_EXTERNAL_LAN_ROLE_BUILD_DIR:-}" ]]; then
  remove_build_dir=0
fi
source_dir="$build_dir/source"
runtime_dir="$build_dir/runtime"
cleanup() {
  if [[ "$remove_build_dir" -eq 1 ]]; then
    rm -rf "$build_dir"
  fi
}
trap cleanup EXIT

mkdir -p "$runtime_dir/build" "$runtime_dir/lib" \
  "$source_dir/content" "$source_dir/core" "$source_dir/session" \
  "$source_dir/world" "$source_dir/ui"
mkdir -p "$runtime_dir/config/g3"
cp "$root_dir/config/g3/external_lan.json" "$runtime_dir/config/g3/external_lan.json"
cp "$root_dir/config/g3/demo.json" "$runtime_dir/config/g3/demo.json"
for content_file in "$root_dir"/src/content/*.kf; do
  ln -s "$content_file" "$source_dir/content/$(basename "$content_file")"
done
for core_file in "$root_dir"/src/core/*.kf; do
  ln -s "$core_file" "$source_dir/core/$(basename "$core_file")"
done
for session_file in "$root_dir"/src/session/*.kf; do
  ln -s "$session_file" "$source_dir/session/$(basename "$session_file")"
done
for world_file in "$root_dir"/src/world/*.kf; do
  ln -s "$world_file" "$source_dir/world/$(basename "$world_file")"
done
for ui_file in "$root_dir"/src/ui/*.kf; do
  ln -s "$ui_file" "$source_dir/ui/$(basename "$ui_file")"
done
{
  sed -n '1,4p' "$root_dir/probes/g0_external_transport/main.kf"
  cat "$root_dir/probes/g0_external_transport_backends/transport_${target}.kf"
  sed -n '5,$p' "$root_dir/probes/g0_external_transport/main.kf"
} > "$source_dir/main.kf"

jvm_metadata_jar=""
if [[ "$target" == native ]]; then
  python3 "$root_dir/scripts/shader_pipeline.py" \
    --root "$root_dir" --output "$runtime_dir/build" --target linux
  zig_bin="${ZIG:-zig}"
  (
    cd "$root_dir"
    "$zig_bin" build check-box3d-adapter
    "$zig_bin" build -Drelease=true --prefix "$build_dir/zig-prefix"
  )
  cp "$build_dir/zig-prefix/lib/libkookie_box3d.so" \
    "$runtime_dir/lib/libkookie_box3d.so"
  gcc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
    -I"$runtime_dir/build" \
    native/kookie_sdl_adapter.c \
    native/kookie_ui_renderer.c \
    native/kookie_transport.c \
    native/kookie_kutter_sync.c \
    -o "$runtime_dir/build/libkookie_sdl_adapter.so" \
    $(pkg-config --cflags --libs sdl3 sdl3-mixer freetype2 harfbuzz libcurl) -lm -pthread
  gcc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
    native/kookie_persistence_adapter.c \
    -o "$runtime_dir/build/libkookie_persistence_adapter.so"
  (
    cd "$runtime_dir"
    kookie_kof_observed "external-lan-role-${target}-${role}" \
      kof build "$source_dir/main.kf" \
      --target native --output "$build_dir/native-$role"
  )
else
  jvm_metadata_classes="$build_dir/jvm-metadata-classes"
  jvm_metadata_jar="$build_dir/kookie-external-lan-metadata.jar"
  mkdir -p "$jvm_metadata_classes"
  javac --release "${KOOKIE_JVM_RELEASE:-21}" \
    -d "$jvm_metadata_classes" \
    "$root_dir/jvm/src/dev/rufl/kookie/KookieExternalLanMetadata.java"
  jar --create --file "$jvm_metadata_jar" -C "$jvm_metadata_classes" .
  kookie_kof_observed "external-lan-role-${target}-${role}" \
    kof build "$source_dir/main.kf" --target jvm \
    --output "$build_dir/jvm-$role"
fi

set +e
if [[ "$target" == native ]]; then
  (
    LD_LIBRARY_PATH="$runtime_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
      "$build_dir/native-$role/Default/Main"
  ) >"$probe_log" 2>&1
else
  java -cp "$build_dir/jvm-$role" \
    Default.Main >"$probe_log" 2>&1
fi
probe_status=$?
set -e
if [[ "$target" == native ]]; then
  python3 scripts/record_external_lan_role_metadata.py \
    "$probe_log" "$role" "$probe_status"
else
  java -cp "$jvm_metadata_jar" \
    dev.rufl.kookie.KookieExternalLanMetadata \
    "$probe_log" "$role" "$probe_status"
fi
cat "$probe_log"
if [[ "$probe_status" -ne 0 ]]; then
  exit "$probe_status"
fi
printf 'target=%s\nrole=%s\nlog=%s\n' "$target" "$role" "$probe_log"
