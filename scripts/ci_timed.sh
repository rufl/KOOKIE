#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

name="${1:?ci_timed: gate name is required}"
shift
(($# > 0)) || { echo 'ci_timed: command is required' >&2; exit 2; }
summary_file="${GITHUB_STEP_SUMMARY:-}"
if [[ -n "$summary_file" ]] && ! grep -Fq '| gate | duration (s) | status |' "$summary_file" 2>/dev/null; then
  {
    printf '\n### KOOKIE gate timings\n'
    printf '| gate | duration (s) | status |\n'
    printf '|---|---:|---|\n'
  } >>"$summary_file"
fi

start_seconds=$SECONDS
set +e
"$@"
status=$?
set -e
duration=$((SECONDS - start_seconds))
status_label=passed
if (( status != 0 )); then
  status_label=failed
fi
if [[ -n "$summary_file" ]]; then
  printf '| `%s` | %s | %s |\n' "$name" "$duration" "$status_label" >>"$summary_file"
fi
printf 'ci_timed: %s %ss %s\n' "$name" "$duration" "$status_label"
exit "$status"
