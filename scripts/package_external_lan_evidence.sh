#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

if [[ "$#" -ne 7 ]]; then
  echo "usage: package_external_lan_evidence.sh MANIFEST HOST_LOG CLIENT_A_LOG CLIENT_B_LOG COMBINED_LOG EVIDENCE_JSON BUNDLE_TAR_GZ" >&2
  exit 64
fi

manifest="$1"
host_log="$2"
client_a_log="$3"
client_b_log="$4"
combined_log="$5"
evidence_json="$6"
bundle_path="$7"
for input_path in \
  "$manifest" "$host_log" "$client_a_log" "$client_b_log" \
  "$combined_log" "$evidence_json"; do
  if [[ ! -f "$input_path" ]]; then
    echo "external LAN evidence packager: missing input: $input_path" >&2
    exit 1
  fi
done
command -v sha256sum >/dev/null || {
  echo "external LAN evidence packager requires sha256sum" >&2
  exit 75
}
command -v tar >/dev/null || {
  echo "external LAN evidence packager requires tar" >&2
  exit 75
}

bundle_parent="$(dirname "$bundle_path")"
mkdir -p "$bundle_parent"
bundle_parent="$(cd "$bundle_parent" && pwd -P)"
bundle_path="$bundle_parent/$(basename "$bundle_path")"
case "$bundle_path" in
  "$root_dir"/*)
    echo "external LAN evidence packager refuses repository-local output" >&2
    exit 64
    ;;
esac
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kookie-external-lan-bundle.XXXXXX")"
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT INT TERM
bundle_root="$work_dir/evidence"
mkdir -p "$bundle_root"
cp -- "$manifest" "$bundle_root/run-manifest.json"
cp -- "$host_log" "$bundle_root/host.log"
cp -- "$client_a_log" "$bundle_root/client-a.log"
cp -- "$client_b_log" "$bundle_root/client-b.log"
cp -- "$combined_log" "$bundle_root/external-lan-combined.log"
cp -- "$evidence_json" "$bundle_root/evidence.json"
(
  cd "$bundle_root"
  sha256sum \
    run-manifest.json host.log client-a.log client-b.log \
    external-lan-combined.log evidence.json > SHA256SUMS
)
rm -f -- "$bundle_path"
tar --sort=name --mtime='UTC 1970-01-01' \
  --owner=0 --group=0 --numeric-owner \
  -C "$work_dir" -czf "$bundle_path" evidence
bundle_sha256="$(sha256sum "$bundle_path" | cut -d' ' -f1)"
printf 'external LAN evidence bundle: %s\n' "$bundle_path"
printf 'external LAN evidence bundle SHA256: %s\n' "$bundle_sha256"
