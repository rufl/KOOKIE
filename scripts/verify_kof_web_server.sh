#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-web-server-verify-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT INT TERM
output_dir="$work_dir/server"
bash "$root_dir/scripts/build_web_server.sh" --output "$output_dir"
port="${KOOKIE_WEB_TEST_PORT:-$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')}"
LD_LIBRARY_PATH="$output_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  python3 "$root_dir/scripts/verify_web_multiplayer.py" \
    "$output_dir/kookie-web-server" "$port"
LD_LIBRARY_PATH="$output_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  python3 "$root_dir/scripts/verify_kutter_shared_document.py" \
    "$output_dir/kookie-web-server" "$port"
printf 'KOOKIE Kof web server end-to-end gate passed\n'
