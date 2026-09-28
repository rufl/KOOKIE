#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

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
  command -v pkg-config >/dev/null || {
    echo "external LAN native role requires pkg-config" >&2
    exit 75
  }
  pkg-config --exists sdl3 || {
    echo "external LAN native role requires SDL3" >&2
    exit 75
  }
else
  command -v java >/dev/null || { echo "external LAN JVM role requires java" >&2; exit 75; }
  command -v javac >/dev/null || { echo "external LAN JVM role requires javac" >&2; exit 75; }
  command -v jar >/dev/null || { echo "external LAN JVM role requires jar" >&2; exit 75; }
fi

export KOOKIE_TRANSPORT_KEY_HEX="${KOOKIE_TRANSPORT_KEY_HEX:-00000001000000020000000300000004}"
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
probe_log="${KOOKIE_EXTERNAL_LAN_PROBE_LOG:-$artifact_dir/probe.log}"
mkdir -p "$artifact_dir"
build_dir="${KOOKIE_EXTERNAL_LAN_ROLE_BUILD_DIR:-$(mktemp -d -t kookie-external-lan-role-XXXXXX)}"
remove_build_dir=1
if [[ -n "${KOOKIE_EXTERNAL_LAN_ROLE_BUILD_DIR:-}" ]]; then
  remove_build_dir=0
fi
source_dir="$build_dir/source"
cleanup() {
  rm -rf "$root_dir/build"
  if [[ "$remove_build_dir" -eq 1 ]]; then
    rm -rf "$build_dir"
  fi
}
trap cleanup EXIT

mkdir -p "$root_dir/build" "$source_dir/core" "$source_dir/session" "$source_dir/world"
for core_file in "$root_dir"/src/core/*.kf; do
  ln -s "$core_file" "$source_dir/core/$(basename "$core_file")"
done
for session_file in "$root_dir"/src/session/*.kf; do
  ln -s "$session_file" "$source_dir/session/$(basename "$session_file")"
done
for world_file in "$root_dir"/src/world/*.kf; do
  ln -s "$world_file" "$source_dir/world/$(basename "$world_file")"
done
{
  sed -n '1,3p' "$root_dir/probes/g0_external_transport/main.kf"
  cat "$root_dir/probes/g0_external_transport_backends/transport_${target}.kf"
  sed -n '4,$p' "$root_dir/probes/g0_external_transport/main.kf"
} > "$source_dir/main.kf"

jvm_metadata_jar=""
if [[ "$target" == native ]]; then
  gcc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
    native/kookie_sdl_adapter.c \
    -o "$root_dir/build/libkookie_sdl_adapter.so" \
    $(pkg-config --cflags --libs sdl3)
  kof build "$source_dir/main.kf" \
    --target native --output "$build_dir/native-$role"
else
  jvm_metadata_classes="$build_dir/jvm-metadata-classes"
  jvm_metadata_jar="$build_dir/kookie-external-lan-metadata.jar"
  mkdir -p "$jvm_metadata_classes"
  javac --release "${KOOKIE_JVM_RELEASE:-21}" \
    -d "$jvm_metadata_classes" \
    "$root_dir/jvm/src/dev/rufl/kookie/KookieExternalLanMetadata.java"
  jar --create --file "$jvm_metadata_jar" -C "$jvm_metadata_classes" .
  kof build "$source_dir/main.kf" --target jvm \
    --output "$build_dir/jvm-$role"
fi

set +e
if [[ "$target" == native ]]; then
  "$build_dir/native-$role/Default/Main" >"$probe_log" 2>&1
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
