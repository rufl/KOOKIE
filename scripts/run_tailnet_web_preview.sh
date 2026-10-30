#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
kof_version="$(kof version 2>/dev/null || true)"
if [[ "$kof_version" != "$KOF_PIN_CLI_VERSION" ]]; then
  pinned_bin="$HOME/.local/share/kof4j/kof-${KOF_PIN_VERSION}-linux-x86_64/bin"
  if [[ -x "$pinned_bin/kof" ]]; then
    export KOOKIE_KOF_BIN_DIR="$pinned_bin"
    source "$root_dir/scripts/kof_pin.sh"
    hash -r
    kof_version="$(kof version)"
  fi
fi
if [[ "$kof_version" != "$KOF_PIN_CLI_VERSION" ]]; then
  printf 'run_tailnet_web_preview: expected %s; found %s; set KOOKIE_KOF_BIN_DIR\n' \
    "$KOF_PIN_CLI_VERSION" "${kof_version:-missing}" >&2
  exit 2
fi
command -v tailscale >/dev/null || {
  echo 'run_tailnet_web_preview: tailscale is required' >&2
  exit 2
}
command -v caddy >/dev/null || {
  echo 'run_tailnet_web_preview: caddy is required' >&2
  exit 2
}
command -v curl >/dev/null || {
  echo 'run_tailnet_web_preview: curl is required' >&2
  exit 2
}
command -v zig >/dev/null || {
  echo 'run_tailnet_web_preview: Zig 0.17.0 is required for Bugfeed storage' >&2
  exit 2
}
[[ "$(zig version)" == "0.17.0" ]] || {
  printf 'run_tailnet_web_preview: expected Zig 0.17.0; found %s\n' "$(zig version)" >&2
  exit 2
}

bugfeed_port="${KOOKIE_BUGFEED_PORT:-8767}"
bugfeed_dir="${KOOKIE_BUGFEED_DIR:-$HOME/.local/state/kookie/bugfeed}"
mkdir -p "$bugfeed_dir"
chmod 700 "$bugfeed_dir"

work_dir="$(mktemp -d -t kookie-tailnet-preview-XXXXXX)"
server_pid=""
kutter_pid=""
bugfeed_pid=""
caddy_pid=""
cleanup() {
  if [[ -n "$caddy_pid" ]]; then
    kill "$caddy_pid" 2>/dev/null || true
    wait "$caddy_pid" 2>/dev/null || true
  fi
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [[ -n "$kutter_pid" ]]; then
    kill "$kutter_pid" 2>/dev/null || true
    wait "$kutter_pid" 2>/dev/null || true
  fi
  if [[ -n "$bugfeed_pid" ]]; then
    kill "$bugfeed_pid" 2>/dev/null || true
    wait "$bugfeed_pid" 2>/dev/null || true
  fi
  rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

web_port="${KOOKIE_WEB_PORT:-8766}"
kutter_port="${KOOKIE_KUTTER_PORT:-8768}"
tailnet_port="${KOOKIE_TAILNET_PORT:-8504}"
tailnet_ip="$(tailscale ip -4)"
[[ "$tailnet_ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || {
  echo 'run_tailnet_web_preview: no IPv4 Tailscale address' >&2
  exit 2
}
serve_status="$(tailscale serve status)"
if [[ "$serve_status" != *"proxy http://$tailnet_ip:$tailnet_port"* ]]; then
  printf 'run_tailnet_web_preview: Tailscale Serve must proxy / to http://%s:%s\n' \
    "$tailnet_ip" "$tailnet_port" >&2
  exit 2
fi

tailscale_json="$(tailscale status --json)"
magic_dns="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' \
  <<<"$tailscale_json")"
[[ -n "$magic_dns" ]] || {
  echo 'run_tailnet_web_preview: Tailscale MagicDNS name unavailable' >&2
  exit 2
}

bash "$root_dir/scripts/build_web_server.sh" --output "$work_dir/server"
bash "$root_dir/scripts/build_bugfeed.sh" --output "$work_dir/bugfeed"
KOOKIE_WEB_ALPHA_OUTPUT="$work_dir/site" \
  bash "$root_dir/scripts/build_web_alpha.sh"
(
  KOOKIE_BUGFEED_PORT="$bugfeed_port" KOOKIE_BUGFEED_DIR="$bugfeed_dir" \
    "$work_dir/bugfeed"
) >"$work_dir/bugfeed.log" 2>&1 &
bugfeed_pid=$!
for attempt in $(seq 1 100); do
  if curl --fail --silent "http://127.0.0.1:$bugfeed_port/bugfeed/healthz" \
      >"$work_dir/bugfeed-health.json"; then
    break
  fi
  if ! kill -0 "$bugfeed_pid" 2>/dev/null; then
    cat "$work_dir/bugfeed.log" >&2
    echo 'run_tailnet_web_preview: Bugfeed exited before health check' >&2
    exit 1
  fi
  sleep 0.1
done
[[ -s "$work_dir/bugfeed-health.json" ]] || {
  cat "$work_dir/bugfeed.log" >&2
  echo 'run_tailnet_web_preview: Bugfeed health check timed out' >&2
  exit 1
}
server_supervisor() {
  local child_pid="" exit_status=0
  stop_server_supervisor() {
    trap - INT TERM
    if [[ -n "$child_pid" ]]; then
      kill "$child_pid" 2>/dev/null || true
      wait "$child_pid" 2>/dev/null || true
    fi
    exit 0
  }
  trap stop_server_supervisor INT TERM
  while true; do
    (
      cd "$work_dir/server"
      exec env \
        LD_LIBRARY_PATH="$work_dir/server/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        KOOKIE_WEB_PORT="$web_port" KOOKIE_WEB_MAX_CONNECTIONS=0 \
        ./kookie-web-server
    ) &
    child_pid=$!
    if wait "$child_pid"; then exit_status=0; else exit_status=$?; fi
    child_pid=""
    printf 'run_tailnet_web_preview: multiplayer backend exited status=%s; restarting in 1s\n' \
      "$exit_status" >&2
    sleep 1
  done
}
server_supervisor >"$work_dir/server.log" 2>&1 &
server_pid=$!
for attempt in $(seq 1 100); do
  if curl --fail --silent "http://127.0.0.1:$web_port/healthz" \
      >"$work_dir/health.json"; then
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$work_dir/server.log" >&2
    echo 'run_tailnet_web_preview: backend exited before health check' >&2
    exit 1
  fi
  sleep 0.1
done
[[ -s "$work_dir/health.json" ]] || {
  cat "$work_dir/server.log" >&2
  echo 'run_tailnet_web_preview: backend health check timed out' >&2
  exit 1
}
(
  cd "$work_dir/server"
  LD_LIBRARY_PATH="$work_dir/server/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    KOOKIE_WEB_PORT="$kutter_port" KOOKIE_WEB_MAX_CONNECTIONS=0 \
    ./kookie-web-server
) >"$work_dir/kutter-server.log" 2>&1 &
kutter_pid=$!
for attempt in $(seq 1 100); do
  if curl --fail --silent "http://127.0.0.1:$kutter_port/healthz" \
      >"$work_dir/kutter-health.json"; then
    break
  fi
  if ! kill -0 "$kutter_pid" 2>/dev/null; then
    cat "$work_dir/kutter-server.log" >&2
    echo 'run_tailnet_web_preview: Kutter backend exited before health check' >&2
    exit 1
  fi
  sleep 0.1
done
[[ -s "$work_dir/kutter-health.json" ]] || {
  cat "$work_dir/kutter-server.log" >&2
  echo 'run_tailnet_web_preview: Kutter backend health check timed out' >&2
  exit 1
}
export KOOKIE_TAILNET_IP="$tailnet_ip"
export KOOKIE_TAILNET_PORT="$tailnet_port"
export KOOKIE_BUGFEED_PORT="$bugfeed_port"
export KOOKIE_WEB_PORT="$web_port"
export KOOKIE_KUTTER_PORT="$kutter_port"
export KOOKIE_WEB_ALPHA_ROOT="$work_dir/site"
mkdir -p "$work_dir/caddy-config" "$work_dir/caddy-data"
export XDG_CONFIG_HOME="$work_dir/caddy-config"
export XDG_DATA_HOME="$work_dir/caddy-data"
caddy run --config "$root_dir/scripts/tailnet-dev.Caddyfile" --adapter caddyfile \
  >"$work_dir/caddy.log" 2>&1 &
caddy_pid=$!
for attempt in $(seq 1 100); do
  if curl --fail --silent "http://$tailnet_ip:$tailnet_port/" \
      >"$work_dir/index.html"; then
    break
  fi
  if ! kill -0 "$caddy_pid" 2>/dev/null; then
    cat "$work_dir/caddy.log" >&2
    echo 'run_tailnet_web_preview: gateway exited before HTTP check' >&2
    exit 1
  fi
  sleep 0.1
done
[[ -s "$work_dir/index.html" ]] || {
  cat "$work_dir/caddy.log" >&2
  echo 'run_tailnet_web_preview: gateway HTTP check timed out' >&2
  exit 1
}
curl --fail --silent "http://$tailnet_ip:$tailnet_port/bugfeed/healthz" \
  >"$work_dir/bugfeed-proxy-health.json" || {
  cat "$work_dir/caddy.log" >&2
  echo 'run_tailnet_web_preview: Bugfeed tailnet proxy check failed' >&2
  exit 1
}
printf 'KOOKIE Kof 0.6.8 tailnet preview: https://%s/?kookie_ws=wss%%3A%%2F%%2F%s%%2Fsession\n' \
  "$magic_dns" "$magic_dns"
wait "$caddy_pid"
