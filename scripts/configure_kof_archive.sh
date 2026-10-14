#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
archive="${1:?configure_kof_archive: archive path is required}"
archive_dir="$(cd "$(dirname "$archive")" && pwd)"
checksum_file="${2:-$archive_dir/SHA256SUMS}"
source_file="${3:-$archive_dir/SOURCE_COMMIT}"
install_root="${KOOKIE_KOF_INSTALL_ROOT:-${RUNNER_TEMP:-/tmp}/kof-dist}"

[[ -f "$archive" && ! -L "$archive" ]] || {
  echo 'configure_kof_archive: archive must be a regular file' >&2
  exit 2
}
[[ -f "$checksum_file" ]] || {
  echo "configure_kof_archive: checksum file missing: $checksum_file" >&2
  exit 2
}
[[ -f "$source_file" ]] || {
  echo "configure_kof_archive: source commit file missing: $source_file" >&2
  exit 2
}

expected_sha256="$(awk -v name="$(basename "$archive")" '$2 == name { print $1; exit }' "$checksum_file")"
[[ "$expected_sha256" =~ ^[0-9a-fA-F]{64}$ ]] || {
  echo 'configure_kof_archive: checksum file has no valid archive digest' >&2
  exit 2
}
actual_sha256="$(sha256sum "$archive" | cut -d ' ' -f 1)"
[[ "$actual_sha256" == "${expected_sha256,,}" ]] || {
  printf 'configure_kof_archive: archive digest mismatch: expected %s; found %s\n' \
    "$expected_sha256" "$actual_sha256" >&2
  exit 2
}
source_commit="$(tr -d '\r\n' <"$source_file")"
[[ "$source_commit" == "$KOF_PIN_SOURCE_COMMIT" ]] || {
  printf 'configure_kof_archive: source commit mismatch: expected %s; found %s\n' \
    "$KOF_PIN_SOURCE_COMMIT" "$source_commit" >&2
  exit 2
}

rm -rf -- "$install_root"
mkdir -p "$install_root"
tar -xzf "$archive" -C "$install_root"
kof_root="$install_root/kof-${KOF_PIN_VERSION}-linux-x86_64"
kof_bin="$kof_root/bin"
[[ -x "$kof_bin/kof" ]] || {
  echo "configure_kof_archive: Kof executable missing: $kof_bin/kof" >&2
  exit 2
}

export PATH="$kof_bin${PATH:+:$PATH}"
export KOOKIE_KOF_ARCHIVE="$archive"
export KOOKIE_KOF_ARCHIVE_SHA256="$actual_sha256"
export KOOKIE_KOF_SOURCE_COMMIT="$source_commit"
[[ "$(kof version)" == "$KOF_PIN_CLI_VERSION" ]] || {
  printf 'configure_kof_archive: expected %s; found %s\n' \
    "$KOF_PIN_CLI_VERSION" "$(kof version)" >&2
  exit 2
}

if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$kof_bin" >>"$GITHUB_PATH"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    printf 'KOOKIE_KOF_ARCHIVE=%s\n' "$archive"
    printf 'KOOKIE_KOF_ARCHIVE_SHA256=%s\n' "$actual_sha256"
    printf 'KOOKIE_KOF_SOURCE_COMMIT=%s\n' "$source_commit"
  } >>"$GITHUB_ENV"
fi
printf 'Kof archive configured: version=%s source=%s sha256=%s\n' \
  "$KOF_PIN_VERSION" "$source_commit" "$actual_sha256"
