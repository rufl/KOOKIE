#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-dedicated-soak.XXXXXX")"
cleanup() {
  if [[ "${KOOKIE_KEEP_DEDICATED_SOAK_WORK_DIR:-0}" == 1 ]]; then
    printf 'preserved-work-dir=%s\n' "$WORK_DIR"
  else
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT INT TERM

SOURCE_DIR="$WORK_DIR/source"
BUILD_DIR="$WORK_DIR/build"
mkdir -p "$SOURCE_DIR"/{core,content,session,lib}
for module in core content session; do
  for source_file in "$ROOT_DIR/src/$module/"*.kf; do
    ln -s "$source_file" "$SOURCE_DIR/$module/$(basename "$source_file")"
  done
done
cp -- "$ROOT_DIR/apps/server/main.kf" "$SOURCE_DIR/main.kf"
cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared \
  "$ROOT_DIR/native/kookie_transport.c" \
  -o "$SOURCE_DIR/lib/libkookie_headless_adapter.so"
(cd "$SOURCE_DIR" && kof build main.kf --target native \
  --output "$BUILD_DIR" >/dev/null)

warmup_ticks="${KOOKIE_SOAK_WARMUP_TICKS:-600}"
measured_ticks="${KOOKIE_SOAK_TICKS:-108000}"
sample_ticks="${KOOKIE_SOAK_RSS_SAMPLE_TICKS:-600}"
p95_budget_us="${KOOKIE_SERVER_P95_BUDGET_US:-4000}"
server_log="$WORK_DIR/server.log"
server_status=0
(
  cd "$SOURCE_DIR"
  KOOKIE_SERVER_WARMUP_TICKS="$warmup_ticks" \
  KOOKIE_SERVER_TICKS="$measured_ticks" \
  KOOKIE_SERVER_RSS_SAMPLE_TICKS="$sample_ticks" \
  KOOKIE_SERVER_P95_BUDGET_US="$p95_budget_us" \
  KOOKIE_SERVER_REALTIME=1 \
    "$BUILD_DIR/Default/Main"
) >"$server_log" 2>&1 || server_status=$?
cat "$server_log"
if [[ "$server_status" -ne 0 ]]; then
  printf 'dedicated-soak-status=%s\n' "$server_status" >&2
  exit "$server_status"
fi

python3 - "$server_log" "$warmup_ticks" "$measured_ticks" "$sample_ticks" "$p95_budget_us" <<'PY'
import pathlib
import sys

lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
warmup = int(sys.argv[2])
measured = int(sys.argv[3])
sample_interval = int(sys.argv[4])
p95_budget = int(sys.argv[5])
fields = {}
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

assert fields["graphics"] == "none"
assert int(fields["warmup-ticks"]) == warmup
assert int(fields["measured-ticks"]) == measured
assert int(fields["ticks"]) == warmup + measured
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
expected_samples = 1 + measured // sample_interval
if measured % sample_interval:
    expected_samples += 1
assert int(fields["rss-samples"]) == expected_samples
assert fields["rss-plateau"] == "true"
assert fields["realtime"] == "true"
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

printf 'KOOKIE G5 real-time dedicated soak gate passed\n'
printf 'soak-kernel=%s\n' "$(uname -srm)"
printf 'soak-logical-cpus=%s\n' "$(nproc)"
