#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"

command -v kof >/dev/null || { echo 'package preflight: kof is required' >&2; exit 2; }
command -v sha256sum >/dev/null || { echo 'package preflight: sha256sum is required' >&2; exit 2; }
command -v tar >/dev/null || { echo 'package preflight: tar is required' >&2; exit 2; }
command -v zig >/dev/null || { echo 'package preflight: zig is required' >&2; exit 2; }

[[ "$(kof version)" == "$KOF_PIN_CLI_VERSION" ]] || {
  printf 'package preflight: expected %s; found %s\n' \
    "$KOF_PIN_CLI_VERSION" "$(kof version)" >&2
  exit 2
}

archive="${KOOKIE_KOF_ARCHIVE:-}"
archive_sha256="${KOOKIE_KOF_ARCHIVE_SHA256:-}"
source_commit="${KOOKIE_KOF_SOURCE_COMMIT:-}"
[[ -n "$archive" && -f "$archive" && ! -L "$archive" ]] || {
  echo 'package preflight: KOOKIE_KOF_ARCHIVE must name the exact Kof distribution archive used by kof' >&2
  exit 2
}
[[ "$archive_sha256" =~ ^[0-9a-fA-F]{64}$ &&
   "$archive_sha256" =~ [1-9a-fA-F] ]] || {
  echo 'package preflight: KOOKIE_KOF_ARCHIVE_SHA256 must be a nonzero 64-character digest' >&2
  exit 2
}
actual_archive_sha256="$(sha256sum "$archive" | cut -d ' ' -f 1)"
[[ "$actual_archive_sha256" == "${archive_sha256,,}" ]] || {
  printf 'package preflight: Kof archive digest mismatch: expected %s; found %s\n' \
    "$archive_sha256" "$actual_archive_sha256" >&2
  exit 2
}
[[ "$source_commit" == "$KOF_PIN_SOURCE_COMMIT" ]] || {
  printf 'package preflight: expected Kof source commit %s; found %s\n' \
    "$KOF_PIN_SOURCE_COMMIT" "${source_commit:-unset}" >&2
  exit 2
}

kof_launcher="$(readlink -f "$(command -v kof)")"
kof_home="$(dirname "$(dirname "$kof_launcher")")"
kof_compiler_jar="$kof_home/lib/kof.jar"
[[ -f "$kof_compiler_jar" ]] || {
  echo "package preflight: installed Kof compiler jar missing: $kof_compiler_jar" >&2
  exit 2
}
installed_compiler_sha256="$(sha256sum "$kof_compiler_jar" | cut -d ' ' -f 1)"
archive_compiler_sha256="$(tar -xOzf "$archive" --wildcards '*/lib/kof.jar' | sha256sum | cut -d ' ' -f 1)"
[[ "$installed_compiler_sha256" == "$archive_compiler_sha256" ]] || {
  echo 'package preflight: installed Kof compiler differs from the configured archive' >&2
  exit 2
}

expected_zig_version="${KOOKIE_ZIG_VERSION:-}"
[[ -n "$expected_zig_version" ]] || {
  echo 'package preflight: KOOKIE_ZIG_VERSION is required for the Windows fail-closed package check' >&2
  exit 2
}
[[ "$(zig version)" == "$expected_zig_version" ]] || {
  printf 'package preflight: expected Zig %s; found %s\n' \
    "$expected_zig_version" "$(zig version)" >&2
  exit 2
}
zig_archive_sha256="${KOOKIE_ZIG_ARCHIVE_SHA256:-}"
[[ "$zig_archive_sha256" =~ ^[0-9a-fA-F]{64}$ &&
   "$zig_archive_sha256" =~ [1-9a-fA-F] ]] || {
  echo 'package preflight: KOOKIE_ZIG_ARCHIVE_SHA256 must be a nonzero 64-character digest' >&2
  exit 2
}

printf 'KOOKIE package preflight passed: kof=%s kof_source=%s zig=%s\n' \
  "$KOF_PIN_VERSION" "$source_commit" "$expected_zig_version"
