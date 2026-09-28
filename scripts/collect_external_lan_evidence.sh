#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

command -v python3 >/dev/null || {
  echo "external LAN evidence collector requires python3" >&2
  exit 75
}

if [[ "$#" -ne 4 ]]; then
  echo "usage: collect_external_lan_evidence.sh HOST_LOG CLIENT_A_LOG CLIENT_B_LOG EVIDENCE_JSON" >&2
  exit 64
fi

host_log="$1"
client_a_log="$2"
client_b_log="$3"
evidence_json="$4"
for log_path in "$host_log" "$client_a_log" "$client_b_log"; do
  if [[ ! -f "$log_path" ]]; then
    echo "external LAN evidence collector: missing log: $log_path" >&2
    exit 1
  fi
done
if [[ -z "${KOOKIE_TRANSPORT_KEY_HEX:-}" ]]; then
  echo "external LAN evidence collector: KOOKIE_TRANSPORT_KEY_HEX is required" >&2
  exit 64
fi

run_manifest="${KOOKIE_EXTERNAL_LAN_RUN_MANIFEST:-}"
if [[ -z "$run_manifest" || ! -f "$run_manifest" ]]; then
  echo "external LAN evidence collector: KOOKIE_EXTERNAL_LAN_RUN_MANIFEST must point to a run manifest" >&2
  exit 64
fi
export KOOKIE_EXTERNAL_LAN_RUN_MANIFEST="$run_manifest"

artifact_dir="$(dirname "$evidence_json")"
mkdir -p "$artifact_dir"
combined_log="${KOOKIE_EXTERNAL_LAN_COMBINED_LOG:-$artifact_dir/external-lan-combined.log}"
cat "$host_log" "$client_a_log" "$client_b_log" >"$combined_log"
export KOOKIE_EXTERNAL_LAN_TOPOLOGY=separate-hosts
export KOOKIE_EXTERNAL_LAN_COMMAND="${KOOKIE_EXTERNAL_LAN_COMMAND:-scripts/collect_external_lan_evidence.sh $*}"
bundle_path="${KOOKIE_EXTERNAL_LAN_BUNDLE:-$artifact_dir/external-lan-evidence.tar.gz}"
python3 scripts/validate_external_lan_evidence.py \
  "$combined_log" "$evidence_json"
scripts/package_external_lan_evidence.sh \
  "$run_manifest" "$host_log" "$client_a_log" "$client_b_log" \
  "$combined_log" "$evidence_json" "$bundle_path"
python3 scripts/verify_external_lan_evidence_bundle.py "$bundle_path"
