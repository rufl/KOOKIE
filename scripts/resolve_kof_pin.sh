#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"

version="${KOF_PIN_VERSION:?Kof pin version is missing}"
commit="${KOF_PIN_SOURCE_COMMIT:?Kof pin source commit is missing}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'version=%s\n' "$version" >>"$GITHUB_OUTPUT"
  printf 'commit=%s\n' "$commit" >>"$GITHUB_OUTPUT"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'KOF_VERSION=%s\n' "$version" >>"$GITHUB_ENV"
  printf 'KOF_SOURCE_COMMIT=%s\n' "$commit" >>"$GITHUB_ENV"
fi

printf 'Kof pin: version=%s commit=%s\n' "$version" "$commit"
