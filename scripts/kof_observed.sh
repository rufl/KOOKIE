#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat >&2 <<'EOF'
usage: kof_observed.sh --name NAME [options] -- COMMAND [ARG...]

Options:
  --name NAME                 Human-readable build stage name (required).
  --key KEY                   History key (default: NAME).
  --timeout SECONDS           Hard timeout (default: 1800).
  --heartbeat SECONDS         Progress interval (default: 30).
  --kill-after SECONDS       Grace after timeout/signal (default: 30).
  --estimate-seconds SECONDS  Override the historical ETA for this run.
  --log PATH                  Exact command log path.
  --history PATH              Duration history TSV path.
EOF
}

name=""
history_key=""
timeout_seconds="${KOOKIE_KOF_BUILD_TIMEOUT_SECONDS:-1800}"
heartbeat_seconds="${KOOKIE_KOF_BUILD_HEARTBEAT_SECONDS:-30}"
kill_after_seconds="${KOOKIE_KOF_BUILD_KILL_AFTER_SECONDS:-30}"
estimate_override="${KOOKIE_KOF_BUILD_ESTIMATE_SECONDS:-}"
log_file=""
history_file="${KOOKIE_KOF_BUILD_HISTORY_FILE:-}"
command=()
saw_command=0

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_nonnegative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

while (($# > 0)); do
  case "$1" in
    --name)
      (($# >= 2)) || { echo 'kof_observed: --name requires a value' >&2; exit 2; }
      name="$2"
      shift 2
      ;;
    --key)
      (($# >= 2)) || { echo 'kof_observed: --key requires a value' >&2; exit 2; }
      history_key="$2"
      shift 2
      ;;
    --timeout)
      (($# >= 2)) || { echo 'kof_observed: --timeout requires a value' >&2; exit 2; }
      timeout_seconds="$2"
      shift 2
      ;;
    --heartbeat)
      (($# >= 2)) || { echo 'kof_observed: --heartbeat requires a value' >&2; exit 2; }
      heartbeat_seconds="$2"
      shift 2
      ;;
    --kill-after)
      (($# >= 2)) || { echo 'kof_observed: --kill-after requires a value' >&2; exit 2; }
      kill_after_seconds="$2"
      shift 2
      ;;
    --estimate-seconds)
      (($# >= 2)) || { echo 'kof_observed: --estimate-seconds requires a value' >&2; exit 2; }
      estimate_override="$2"
      shift 2
      ;;
    --log)
      (($# >= 2)) || { echo 'kof_observed: --log requires a value' >&2; exit 2; }
      log_file="$2"
      shift 2
      ;;
    --history)
      (($# >= 2)) || { echo 'kof_observed: --history requires a value' >&2; exit 2; }
      history_file="$2"
      shift 2
      ;;
    --)
      shift
      command=("$@")
      saw_command=1
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "kof_observed: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "$name" ]] || { echo 'kof_observed: --name is required' >&2; exit 2; }
((saw_command == 1)) || { echo 'kof_observed: command must follow --' >&2; exit 2; }
(( ${#command[@]} > 0 )) || { echo 'kof_observed: command is required' >&2; exit 2; }

is_positive_integer "$timeout_seconds" || {
  echo 'kof_observed: --timeout must be a positive integer' >&2
  exit 2
}
is_positive_integer "$heartbeat_seconds" || {
  echo 'kof_observed: --heartbeat must be a positive integer' >&2
  exit 2
}
is_positive_integer "$kill_after_seconds" || {
  echo 'kof_observed: --kill-after must be a positive integer' >&2
  exit 2
}
if [[ -n "$estimate_override" ]] && ! is_nonnegative_integer "$estimate_override"; then
  echo 'kof_observed: --estimate-seconds must be a non-negative integer' >&2
  exit 2
fi
if [[ -z "$history_key" ]]; then
  history_key="$name"
fi
if [[ "$history_key" == *$'\t'* || "$history_key" == *$'\n'* ]]; then
  echo 'kof_observed: --key cannot contain tabs or newlines' >&2
  exit 2
fi

for required_command in awk date tee timeout; do
  command -v "$required_command" >/dev/null || {
    echo "kof_observed: required command missing: $required_command" >&2
    exit 75
  }
done

if [[ -z "$history_file" ]]; then
  history_root="${KOOKIE_BUILD_HISTORY_DIR:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/kookie}"
  history_file="$history_root/build-times.tsv"
fi
if [[ -z "$log_file" ]]; then
  log_root="${KOOKIE_BUILD_LOG_DIR:-${TMPDIR:-/tmp}/kookie-build-logs}"
  safe_name="${name//[^a-zA-Z0-9_.-]/_}"
  log_file="$log_root/${safe_name}-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
fi

history_enabled=1
if ! mkdir -p "$(dirname "$history_file")" 2>/dev/null ||
   ! touch "$history_file" 2>/dev/null; then
  history_enabled=0
  echo "kof_observed: history disabled path=$history_file" >&2
fi
if ! mkdir -p "$(dirname "$log_file")" 2>/dev/null; then
  echo "kof_observed: cannot create log directory for $log_file" >&2
  exit 2
fi
: >"$log_file"

version_key="${KOF_PIN_SOURCE_COMMIT:-unversioned}"
history_key="$version_key|$history_key"
history_estimate=""
history_samples=0
if ((history_enabled == 1)); then
  history_info="$(awk -F '\t' -v key="$history_key" '
    $1 == key {
      count += 1
      values[count] = $2
    }
    END {
      start = count - 4
      if (start < 1) start = 1
      total = 0
      samples = 0
      for (position = start; position <= count; position += 1) {
        total += values[position]
        samples += 1
      }
      if (samples > 0) printf "%d\t%d\n", int((total / samples) + 0.5), samples
    }
  ' "$history_file")"
  if [[ -n "$history_info" ]]; then
    IFS=$'\t' read -r history_estimate history_samples <<<"$history_info"
  fi
fi

estimate_seconds="${estimate_override:-$history_estimate}"
if [[ -z "$estimate_seconds" ]]; then
  estimate_display=unknown
  estimate_basis=none
else
  estimate_display="${estimate_seconds}s"
  if [[ -n "$estimate_override" ]]; then
    estimate_basis=override
  else
    estimate_basis="history:$history_samples"
  fi
fi

format_duration() {
  local total_seconds="$1"
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds"
}

print_command() {
  local rendered=""
  local argument
  for argument in "${command[@]}"; do
    printf -v rendered '%s %q' "$rendered" "$argument"
  done
  printf '%s' "${rendered# }"
}

record_success() {
  local duration="$1"
  if ((history_enabled == 1)); then
    printf '%s\t%s\t%s\n' \
      "$history_key" "$duration" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      >>"$history_file" || {
        echo "kof_observed: could not record history path=$history_file" >&2
      }
  fi
}

child_pid=""
forward_signal() {
  local signal="$1"
  if [[ -n "$child_pid" ]] && kill -0 "$child_pid" 2>/dev/null; then
    kill "-$signal" "$child_pid" 2>/dev/null || true
  fi
  exit 128
}
trap 'forward_signal TERM' TERM
trap 'forward_signal INT' INT

start_seconds=$SECONDS
printf 'kof-observed: name=%s state=start timeout=%ss heartbeat=%ss estimate=%s basis=%s log=%s\n' \
  "$name" "$timeout_seconds" "$heartbeat_seconds" "$estimate_display" \
  "$estimate_basis" "$log_file" >&2
printf 'kof-observed: name=%s command=%s\n' "$name" "$(print_command)" >&2

set +e
timeout --foreground --kill-after="${kill_after_seconds}s" "$timeout_seconds" \
  "${command[@]}" \
  > >(tee -a "$log_file") \
  2> >(tee -a "$log_file" >&2) &
child_pid=$!
set -e

while kill -0 "$child_pid" 2>/dev/null; do
  sleep "$heartbeat_seconds"
  if ! kill -0 "$child_pid" 2>/dev/null; then
    break
  fi
  elapsed=$((SECONDS - start_seconds))
  if [[ -n "$estimate_seconds" ]]; then
    remaining=$((estimate_seconds - elapsed))
    if ((remaining >= 0)); then
      eta="${remaining}s"
    else
      eta="overdue+$((-remaining))s"
    fi
  else
    eta=unknown
  fi
  deadline_remaining=$((timeout_seconds - elapsed))
  if ((deadline_remaining < 0)); then
    deadline_remaining=0
  fi
  printf 'kof-observed: name=%s state=running elapsed=%ss eta=%s timeout-in=%ss\n' \
    "$name" "$elapsed" "$eta" "$deadline_remaining" >&2
done

set +e
wait "$child_pid"
status=$?
set -e
child_pid=""
duration=$((SECONDS - start_seconds))
timed_out=0
if ((duration >= timeout_seconds)) || ((status == 124)); then
  timed_out=1
fi
if ((status == 0)); then
  record_success "$duration"
  printf 'kof-observed: name=%s state=passed duration=%ss duration_human=%s log=%s\n' \
    "$name" "$duration" "$(format_duration "$duration")" "$log_file" >&2
else
  if ((timed_out == 1)); then
    printf 'kof-observed: name=%s state=timeout duration=%ss limit=%ss log=%s\n' \
      "$name" "$duration" "$timeout_seconds" "$log_file" >&2
  else
    printf 'kof-observed: name=%s state=failed exit=%s duration=%ss log=%s\n' \
      "$name" "$status" "$duration" "$log_file" >&2
  fi
fi
exit "$status"
