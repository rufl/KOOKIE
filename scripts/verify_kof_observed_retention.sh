#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d -t kookie-log-retention-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT INT TERM
log_dir="$work_dir/logs"
mkdir -p "$log_dir"

for index in 1 2 3; do
  touch -d "$((4 - index)) days ago" \
    "$log_dir/retention-20260101T00000${index}Z-${index}.log"
done
touch -d '60 days ago' "$log_dir/retention-20250101T000000Z-99.log"
touch "$log_dir/user-not-managed.log"
KOOKIE_BUILD_LOG_DIR="$log_dir" \
KOOKIE_BUILD_LOG_MAX_FILES=2 \
KOOKIE_BUILD_LOG_MAX_AGE_DAYS=30 \
KOOKIE_BUILD_HISTORY_FILE="$work_dir/history/build-times.tsv" \
  bash "$root_dir/scripts/kof_observed.sh" \
    --name retention --heartbeat 1 --timeout 5 -- \
    printf 'retention smoke\n' >/dev/null

managed_count="$(find "$log_dir" -maxdepth 1 -type f \
  -name 'retention-????????T??????Z-*.log' | wc -l)"
[[ "$managed_count" -eq 2 ]] || {
  printf 'expected 2 retained managed logs, found %s\n' "$managed_count" >&2
  exit 1
}
[[ -f "$log_dir/retention-20260101T000003Z-3.log" ]]
[[ -f "$log_dir/user-not-managed.log" ]]
[[ ! -e "$log_dir/retention-20250101T000000Z-99.log" ]]

explicit_log="$work_dir/explicit.log"
KOOKIE_BUILD_LOG_DIR="$log_dir" \
KOOKIE_BUILD_LOG_MAX_FILES=1 \
KOOKIE_BUILD_LOG_MAX_AGE_DAYS=0 \
KOOKIE_BUILD_HISTORY_FILE="$work_dir/history/build-times.tsv" \
  bash "$root_dir/scripts/kof_observed.sh" \
    --name explicit --log "$explicit_log" --heartbeat 1 --timeout 5 -- \
    printf 'explicit log smoke\n' >/dev/null
[[ -f "$log_dir/retention-20260101T000003Z-3.log" ]]
[[ -f "$explicit_log" ]]

printf 'KOOKIE build log retention verified\n'
