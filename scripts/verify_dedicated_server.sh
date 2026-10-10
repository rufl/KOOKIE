#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-dedicated-server.XXXXXX")"
cleanup() {
  if [[ "${KOOKIE_KEEP_DEDICATED_WORK_DIR:-0}" == 1 ]]; then
    printf 'preserved-work-dir=%s\n' "$WORK_DIR"
  else
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$WORK_DIR/core" "$WORK_DIR/content" "$WORK_DIR/session"
for module in core content session; do
  for source_file in "$ROOT_DIR/src/$module/"*.kf; do
    ln -s "$source_file" "$WORK_DIR/$module/$(basename "$source_file")"
  done
done
ln -s "$ROOT_DIR/probes/g5_dedicated_server/main.kf" "$WORK_DIR/main.kf"

jvm_output="$(kof run "$WORK_DIR/main.kf" --target jvm)"
native_output="$(kof run "$WORK_DIR/main.kf" --target native)"
[[ "$jvm_output" == "$native_output" ]]

SERVER_ROOT="$WORK_DIR/server"
mkdir -p "$SERVER_ROOT/core" "$SERVER_ROOT/content" \
  "$SERVER_ROOT/session" "$SERVER_ROOT/lib"
for module in core content session; do
  for source_file in "$ROOT_DIR/src/$module/"*.kf; do
    ln -s "$source_file" "$SERVER_ROOT/$module/$(basename "$source_file")"
  done
done
cp -- "$ROOT_DIR/apps/server/main.kf" "$SERVER_ROOT/main.kf"
cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared \
  "$ROOT_DIR/native/kookie_transport.c" \
  -o "$SERVER_ROOT/lib/libkookie_headless_adapter.so"
SERVER_BUILD="$WORK_DIR/server-build"
(cd "$SERVER_ROOT" && kof build main.kf --target native \
  --output "$SERVER_BUILD" >/dev/null)
server_status=0
p95_budget_us="${KOOKIE_SERVER_P95_BUDGET_US:-4000}"
server_output="$(
  cd "$SERVER_ROOT"
  KOOKIE_SERVER_WARMUP_TICKS=128 \
  KOOKIE_SERVER_TICKS=512 \
  KOOKIE_SERVER_RSS_SAMPLE_TICKS=32 \
  KOOKIE_SERVER_P95_BUDGET_US="$p95_budget_us" \
    "$SERVER_BUILD/Default/Main"
)" || server_status=$?
if [[ "$server_status" -ne 0 ]]; then
  printf '%s\nserver-status=%s\n' "$server_output" "$server_status" >&2
  exit "$server_status"
fi
server_log="$WORK_DIR/server.log"
printf '%s\n' "$server_output" >"$server_log"
python3 - "$server_log" "$p95_budget_us" <<'PY'
import pathlib
import sys

lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
fields = {}
p95_budget = int(sys.argv[2])
paired = {
    "warmup-ticks", "measured-ticks",
    "simulation-p50-us", "simulation-p95-us", "simulation-p99-us",
    "simulation-max-us", "simulation-budget-us", "simulation-budget-pass",
    "rss-first-kib", "rss-last-kib", "rss-growth-kib",
    "rss-range-kib", "rss-samples", "rss-plateau", "realtime",
}
index = 0
while index < len(lines):
    line = lines[index]
    if "=" in line:
        key, value = line.split("=", 1)
        fields[key] = value
    elif line in paired and index + 1 < len(lines):
        fields[line] = lines[index + 1]
        index += 1
    index += 1

assert lines[0] == "KOOKIE G5 dedicated headless server"
assert fields["graphics"] == "none"
assert int(fields["warmup-ticks"]) == 128
assert int(fields["measured-ticks"]) == 512
assert int(fields["ticks"]) == 640
assert fields["enemies"] == "64"
assert fields["projectiles"] == "256"
assert fields["pickups"] == "512"
assert fields["work-budgets"] == "16,64,128"
assert fields["peak-work"] == "16,64,128"
p50 = int(fields["simulation-p50-us"])
p95 = int(fields["simulation-p95-us"])
p99 = int(fields["simulation-p99-us"])
maximum = int(fields["simulation-max-us"])
assert 0 <= p50 <= p95 <= p99 <= maximum
assert p95 <= p95_budget, (
    f"simulation p95 {p95}us exceeds budget {p95_budget}us")
assert int(fields["simulation-budget-us"]) == p95_budget
assert fields["simulation-budget-pass"] == "true"
assert int(fields["rss-growth-kib"]) <= 1024
assert int(fields["rss-range-kib"]) <= 4096
assert int(fields["rss-samples"]) == 17
assert fields["rss-plateau"] == "true"
assert fields["realtime"] == "false"
assert fields["resource-plateau"] == "true"
assert fields["phase-telemetry"] == "true"
assert fields["phase-profile"] == "isolated-phased-diagnostic"
phase_samples = int(fields["phase-samples"])
assert 0 < phase_samples <= int(fields["measured-ticks"])
for phase in ("clock", "collision", "ai", "projectile", "pickup", "finalize"):
    prefix = f"phase-{phase}-"
    assert int(fields[prefix + "samples"]) == phase_samples
    phase_p50 = int(fields[prefix + "p50-us"])
    phase_p95 = int(fields[prefix + "p95-us"])
    phase_p99 = int(fields[prefix + "p99-us"])
    phase_max = int(fields[prefix + "max-us"])
    assert 0 <= phase_p50 <= phase_p95 <= phase_p99 <= phase_max
PY
grep -Fqx 'KOOKIE G5 dedicated headless workload verified' <<<"$jvm_output"
printf '%s\n%s\n' "$jvm_output" "$server_output"
