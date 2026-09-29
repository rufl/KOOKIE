#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-dedicated-network.XXXXXX")"
SOURCE_DIR="$WORK_DIR/source"
BUILD_DIR="$WORK_DIR/build"
host_pid=""
client_a_pid=""
client_b_pid=""
cleanup() {
  for pid in "$host_pid" "$client_a_pid" "$client_b_pid"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  if [[ "${KOOKIE_KEEP_DEDICATED_NETWORK_WORK_DIR:-0}" == 1 ]]; then
    printf 'preserved-work-dir=%s\n' "$WORK_DIR"
  else
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$SOURCE_DIR"/{core,content,session,lib}
for module in core content session; do
  for source_file in "$ROOT_DIR/src/$module/"*.kf; do
    ln -s "$source_file" "$SOURCE_DIR/$module/$(basename "$source_file")"
  done
done
cp -- "$ROOT_DIR/probes/g5_dedicated_network/main.kf" "$SOURCE_DIR/main.kf"
cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared \
  "$ROOT_DIR/native/kookie_transport.c" \
  -o "$SOURCE_DIR/lib/libkookie_headless_adapter.so"
(cd "$SOURCE_DIR" && kof build main.kf --target native \
  --output "$BUILD_DIR" >/dev/null)
BINARY="$BUILD_DIR/Default/Main"
test -x "$BINARY"
if ldd "$SOURCE_DIR/lib/libkookie_headless_adapter.so" 2>/dev/null | \
   grep -Eq 'SDL|Vulkan|X11|Wayland'; then
  echo 'dedicated network: headless adapter acquired a graphics dependency' >&2
  exit 1
fi

export KOOKIE_TRANSPORT_KEY_HEX=00000001000000020000000300000004
export KOOKIE_EXTERNAL_LAN_HOST_IPV4=127.0.0.1
export KOOKIE_EXTERNAL_LAN_TIMEOUT_MILLISECONDS=10000
host_log="$WORK_DIR/host.log"
client_a_log="$WORK_DIR/client-a.log"
client_b_log="$WORK_DIR/client-b.log"

(
  cd "$SOURCE_DIR"
  KOOKIE_EXTERNAL_LAN_ROLE=host "$BINARY"
) >"$host_log" 2>&1 &
host_pid=$!
sleep 0.25
(
  cd "$SOURCE_DIR"
  KOOKIE_EXTERNAL_LAN_ROLE=client-a "$BINARY"
) >"$client_a_log" 2>&1 &
client_a_pid=$!
(
  cd "$SOURCE_DIR"
  KOOKIE_EXTERNAL_LAN_ROLE=client-b "$BINARY"
) >"$client_b_log" 2>&1 &
client_b_pid=$!

set +e
wait "$client_a_pid"
client_a_status=$?
client_a_pid=""
wait "$client_b_pid"
client_b_status=$?
client_b_pid=""
wait "$host_pid"
host_status=$?
host_pid=""
set -e
cat "$host_log" "$client_a_log" "$client_b_log"
if [[ "$host_status" -ne 0 || "$client_a_status" -ne 0 ||
      "$client_b_status" -ne 0 ]]; then
  printf 'dedicated network statuses: host=%s client-a=%s client-b=%s\n' \
    "$host_status" "$client_a_status" "$client_b_status" >&2
  exit 1
fi

python3 - "$host_log" "$client_a_log" "$client_b_log" <<'PY'
import pathlib
import sys


def read_lines(path):
    return pathlib.Path(path).read_text(encoding="utf-8").splitlines()


def value(lines, label):
    index = lines.index(label)
    assert index + 1 < len(lines)
    return lines[index + 1]


host = read_lines(sys.argv[1])
client_a = read_lines(sys.argv[2])
client_b = read_lines(sys.argv[3])
assert "g5-scale-role-host" in host
assert value(host, "g5-scale-ticks") == "256"
assert value(host, "g5-scale-checksum") == "797255"
assert value(host, "g5-scale-resource-signature") == "675172"
assert value(host, "g5-scale-client-b-generation") == "2"
assert host[-1] == "KOOKIE G5 authenticated host/two-client workload verified"
assert "g5-scale-role-client-a" in client_a
assert value(client_a, "g5-scale-final-tick") == "256"
assert value(client_a, "g5-scale-final-generation") == "1"
assert value(client_a, "g5-scale-updates") == "4"
assert value(client_a, "g5-scale-resource-signature") == "675172"
assert "g5-scale-role-client-b" in client_b
assert value(client_b, "g5-scale-final-tick") == "256"
assert value(client_b, "g5-scale-final-generation") == "2"
assert value(client_b, "g5-scale-updates") == "5"
assert value(client_b, "g5-scale-resource-signature") == "675172"
PY

printf 'KOOKIE G5 native headless host/two-client scale gate passed\n'
