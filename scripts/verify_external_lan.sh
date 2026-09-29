#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

target="${KOOKIE_EXTERNAL_LAN_TARGET:-native}"
case "$target" in
  native|jvm) ;;
  *)
    echo "external LAN gate requires KOOKIE_EXTERNAL_LAN_TARGET=native|jvm" >&2
    exit 64
    ;;
esac

command -v kof >/dev/null || { echo "external LAN gate requires kof" >&2; exit 75; }
command -v python3 >/dev/null || { echo "external LAN gate requires python3" >&2; exit 75; }
if [[ "$target" == native ]]; then
  command -v gcc >/dev/null || { echo "external LAN native gate requires gcc" >&2; exit 75; }
  command -v pkg-config >/dev/null || {
    echo "external LAN native gate requires pkg-config" >&2
    exit 75
  }
  pkg-config --exists sdl3 sdl3-mixer || {
    echo "external LAN native gate requires SDL3 and SDL_mixer" >&2
    exit 75
  }
else
  command -v java >/dev/null || { echo "external LAN JVM gate requires java" >&2; exit 75; }
fi

evidence_json="${KOOKIE_EXTERNAL_LAN_EVIDENCE_JSON:-/tmp/kookie-external-lan-$$/evidence.json}"
artifact_dir="${KOOKIE_EXTERNAL_LAN_EVIDENCE_DIR:-$(dirname "$evidence_json")}"
mkdir -p "$artifact_dir"
probe_log="${KOOKIE_EXTERNAL_LAN_PROBE_LOG:-$artifact_dir/probe.log}"
export KOOKIE_EXTERNAL_LAN_COMMAND="${KOOKIE_EXTERNAL_LAN_COMMAND:-KOOKIE_EXTERNAL_LAN_TARGET=$target bash scripts/verify_external_lan.sh}"
export KOOKIE_TRANSPORT_KEY_HEX="${KOOKIE_TRANSPORT_KEY_HEX:-00000001000000020000000300000004}"
lan_mode="${KOOKIE_EXTERNAL_LAN_MODE:-in-process}"
if [[ "$lan_mode" == "processes" && -z "${KOOKIE_EXTERNAL_LAN_RUN_ID:-}" ]]; then
  if [[ -n "${KOOKIE_EXTERNAL_LAN_RUN_MANIFEST:-}" ]]; then
    export KOOKIE_EXTERNAL_LAN_RUN_ID="$(
      python3 -c \
        'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["runId"])' \
        "$KOOKIE_EXTERNAL_LAN_RUN_MANIFEST"
    )"
  else
    export KOOKIE_EXTERNAL_LAN_RUN_ID="$(
      python3 -c 'import uuid; print(uuid.uuid4().hex)'
    )"
  fi
fi
build_dir="$(mktemp -d -t kookie-external-lan-XXXXXX)"
source_dir="$build_dir/source"
host_pid=""
client_a_pid=""
client_b_pid=""
cleanup() {
  for pid in "$host_pid" "$client_a_pid" "$client_b_pid"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  rm -rf "$build_dir" "$root_dir/build"
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
if [[ "$target" == native ]]; then
  gcc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
    native/kookie_sdl_adapter.c \
    -o "$root_dir/build/libkookie_sdl_adapter.so" \
    $(pkg-config --cflags --libs sdl3 sdl3-mixer)
fi
if [[ "$lan_mode" == "processes" ]]; then
  for role in host client-a client-b; do
    export KOOKIE_EXTERNAL_LAN_ROLE="$role"
    kof build "$source_dir/main.kf" \
      --target "$target" --output "$build_dir/$target-$role"
  done
else
  kof build "$source_dir/main.kf" \
    --target "$target" --output "$build_dir/$target"
fi
binary="$build_dir/$target/Default/Main"
if [[ "$lan_mode" == "processes" ]]; then
  export KOOKIE_EXTERNAL_LAN_TOPOLOGY="same-host-multi-process"
  export KOOKIE_EXTERNAL_LAN_HOST_IPV4="${KOOKIE_EXTERNAL_LAN_HOST_IPV4:-127.0.0.1}"
  host_log="$artifact_dir/host.log"
  client_a_log="$artifact_dir/client-a.log"
  client_b_log="$artifact_dir/client-b.log"
  launch_role() {
    local role="$1"
    local log="$2"
    export KOOKIE_EXTERNAL_LAN_ROLE="$role"
    if [[ "$target" == native ]]; then
      "$build_dir/$target-$role/Default/Main" >"$log" 2>&1 &
    else
      java -cp "$build_dir/$target-$role" Default.Main >"$log" 2>&1 &
    fi
    role_pid=$!
  }
  set +e
  launch_role host "$host_log"
  host_pid="$role_pid"
  sleep 0.25
  launch_role client-a "$client_a_log"
  client_a_pid="$role_pid"
  launch_role client-b "$client_b_log"
  client_b_pid="$role_pid"
  wait "$client_a_pid"
  client_a_status=$?
  wait "$client_b_pid"
  client_b_status=$?
  wait "$host_pid"
  host_status=$?
  set -e
  python3 scripts/record_external_lan_role_metadata.py \
    "$host_log" host "$host_status"
  python3 scripts/record_external_lan_role_metadata.py \
    "$client_a_log" client-a "$client_a_status"
  python3 scripts/record_external_lan_role_metadata.py \
    "$client_b_log" client-b "$client_b_status"
  cat "$host_log" "$client_a_log" "$client_b_log" >"$probe_log"
  cat "$probe_log"
  if [[ "$host_status" -ne 0 ]]; then
    exit "$host_status"
  fi
  if [[ "$client_a_status" -ne 0 ]]; then
    exit "$client_a_status"
  fi
  if [[ "$client_b_status" -ne 0 ]]; then
    exit "$client_b_status"
  fi
else
  set +e
  if [[ "$target" == native ]]; then
    "$binary" >"$probe_log" 2>&1
  else
    java -cp "$build_dir/$target" Default.Main >"$probe_log" 2>&1
  fi
  probe_status=$?
  set -e
  printf 'external-process-exit-status\n%s\n' "$probe_status" >>"$probe_log"
  cat "$probe_log"
  if [[ "$probe_status" -ne 0 ]]; then
    exit "$probe_status"
  fi
fi
python3 scripts/validate_external_lan_evidence.py \
  "$probe_log" "$evidence_json"
