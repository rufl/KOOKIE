#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-web-server-verify-XXXXXX)"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

output_dir="$work_dir/server"
bash "$root_dir/scripts/build_web_server.sh" --output "$output_dir"
port=8766
server_log="$work_dir/server.log"
(
  cd "$output_dir"
  KOOKIE_WEB_PORT="$port" KOOKIE_WEB_MAX_CONNECTIONS=5 ./kookie-web-server
) >"$server_log" 2>&1 &
server_pid=$!

for attempt in $(seq 1 80); do
  if curl --fail --silent "http://127.0.0.1:$port/healthz" >"$work_dir/health.json"; then
    break
  fi
  sleep 0.05
done
curl --fail --silent "http://127.0.0.1:$port/metrics" >"$work_dir/metrics.txt"
python3 - "$work_dir/health.json" "$work_dir/metrics.txt" "$port" <<'PY'
import base64
import hashlib
import json
import socket
import urllib.request
import struct
import sys

health_path, metrics_path, port_text = sys.argv[1:]
health = json.load(open(health_path, encoding="utf-8"))
assert health == {
    "status": "ok",
    "protocol": "kookie.v1",
    "transport": "tcp",
    "auth_required": False,
    "active_sessions": 0,
}
metrics = open(metrics_path, encoding="utf-8").read()
assert 'kookie_gateway_transport{name="tcp"} 1' in metrics
assert "kookie_gateway_active_sessions 0" in metrics

sock = socket.create_connection(("127.0.0.1", int(port_text)), timeout=3)
key = base64.b64encode(b"0123456789abcdef").decode()
sock.sendall((
    "GET /session HTTP/1.1\r\n"
    "Host: localhost\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\n"
    "Sec-WebSocket-Version: 13\r\n"
    "Sec-WebSocket-Protocol: kookie.v1\r\n\r\n"
).encode())
response = b""
while b"\r\n\r\n" not in response:
    response += sock.recv(4096)
headers, _ = response.split(b"\r\n\r\n", 1)
assert headers.startswith(b"HTTP/1.1 101 Switching Protocols")
expected_accept = base64.b64encode(hashlib.sha1(
    (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()
).digest())
assert b"Sec-WebSocket-Accept: " + expected_accept in headers
assert b"Sec-WebSocket-Protocol: kookie.v1" in headers

def wire_checksum(wire):
    return sum(
        (0 if index in (14, 15) else value) * (index + 1)
        for index, value in enumerate(wire)
    ) & 0xFFFF

def message_checksum(words):
    result = 53
    for value in words:
        result = (result * 31 + value % 1000003) % 1000003
    return result

def session_frame(kind, sequence, words):
    wire = bytearray(
        b"KWS1" + bytes((1, kind, 0, 0)) +
        struct.pack(">IHH", sequence, len(words), 0)
    )
    wire.extend(struct.pack(">" + "i" * len(words), *words))
    wire[14:16] = struct.pack(">H", wire_checksum(wire))
    return bytes(wire)

def send_websocket(payload, opcode=2):
    mask = b"\x01\x02\x03\x04"
    masked = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
    assert len(masked) < 126
    sock.sendall(bytes((0x80 | opcode, 0x80 | len(masked))) + mask + masked)

def receive_exact(length):
    result = b""
    while len(result) < length:
        result += sock.recv(length - len(result))
    return result

def receive_websocket():
    first, second = receive_exact(2)
    assert first & 0x80 and not (first & 0x70) and not (second & 0x80)
    length = second & 0x7F
    if length == 126:
        length = struct.unpack(">H", receive_exact(2))[0]
    assert length <= 1104
    return first & 0x0F, receive_exact(length)
def decode_session(wire):
    assert wire[:4] == b"KWS1" and wire[4] == 1
    sequence, word_count, expected = struct.unpack(">IHH", wire[8:16])
    assert len(wire) == 16 + word_count * 4
    assert wire_checksum(wire) == expected
    words = list(struct.unpack(">" + "i" * word_count, wire[16:]))
    assert words[0] == 2 and words[2] == sequence
    assert words[-1] == message_checksum(words[:-1])
    return words

hello = [2, 1, 1, 1, 1, 1, 1]
hello.append(message_checksum(hello))
send_websocket(session_frame(1, 1, hello))
opcode, ack_wire = receive_websocket()
assert opcode == 2
assert decode_session(ack_wire) == [2, 2, 1, 1, 1, 1, 689933]

scene_probe = [2, 6, 2, 1, 7, 0]
scene_probe.append(message_checksum(scene_probe))
send_websocket(session_frame(6, 2, scene_probe))
opcode, scene_wire = receive_websocket()
scene = decode_session(scene_wire)
assert opcode == 2
assert scene[:8] == [2, 6, 2, 4, 1, 32, 1, 52]
assert scene[20] == 4

move_right = [2, 6, 3, 1, 2, 8]
move_right.append(message_checksum(move_right))
send_websocket(session_frame(6, 3, move_right))
opcode, moved_wire = receive_websocket()
moved = decode_session(moved_wire)
assert opcode == 2
assert moved[:8] == [2, 6, 3, 4, 2, 40, 1, 52]

send_websocket(b"", opcode=8)
sock.close()
bad = socket.create_connection(("127.0.0.1", int(port_text)), timeout=3)
bad.sendall((
    "GET /session HTTP/1.1\r\n"
    "Host: localhost\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    "Sec-WebSocket-Protocol: kookie.v1\r\n\r\n"
).encode())
bad_response = bad.recv(1024)
assert bad_response.startswith(b"HTTP/1.1 400 Bad Request")
bad.close()

final_metrics = urllib.request.urlopen(
    f"http://127.0.0.1:{port_text}/metrics", timeout=3).read().decode()
assert "kookie_gateway_active_sessions 0\n" in final_metrics
assert "kookie_gateway_upgrades_total 1\n" in final_metrics
assert "kookie_gateway_rejections_total 1\n" in final_metrics
assert "kookie_gateway_frames_total 4\n" in final_metrics
assert "kookie_gateway_commands_total 2\n" in final_metrics
assert "kookie_gateway_health_requests_total 1\n" in final_metrics
assert "kookie_gateway_metrics_requests_total 2\n" in final_metrics

print("KOOKIE Kof web server HTTP/WebSocket/full-scene smoke passed")
PY
wait "$server_pid"
server_pid=""
grep -Fqx 'KOOKIE Kof web server qualification complete' "$server_log"
printf 'KOOKIE Kof web server end-to-end gate passed\n'
