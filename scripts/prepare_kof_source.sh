#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
  echo "usage: $0 KOF_SOURCE_DIR KOF_VERSION" >&2
  exit 2
fi

source_dir=$1
expected_version=$2
version_file="$source_dir/VERSION"
resource="$source_dir/kof-compiler/src/main/resources/dev/kof/version.properties"

[[ -f "$version_file" ]] || {
  echo "prepare_kof_source: missing $version_file" >&2
  exit 2
}
[[ -f "$resource" ]] || {
  echo "prepare_kof_source: missing $resource" >&2
  exit 2
}
actual_version=$(tr -d '\r\n' <"$version_file")
[[ "$actual_version" == "$expected_version" ]] || {
  printf 'prepare_kof_source: VERSION mismatch: expected %s; found %s\n' \
    "$expected_version" "$actual_version" >&2
  exit 2
}

tooling_api=$(awk -F= '$1 == "kof.tooling.api" { print $2; exit }' "$resource")
[[ "$tooling_api" =~ ^[0-9]+$ ]] || {
  echo "prepare_kof_source: missing or invalid kof.tooling.api" >&2
  exit 2
}
runtime_gc="$source_dir/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeGc.java"
[[ -f "$runtime_gc" ]] || {
  echo "prepare_kof_source: missing $runtime_gc" >&2
  exit 2
}
old_gc_branch_count=$(grep -Fxc '                jne .Ltry_done' "$runtime_gc" || true)
new_gc_branch_count=$(grep -Fxc '                jne .Ltry_done_pop' "$runtime_gc" || true)
if ((old_gc_branch_count != 0 || new_gc_branch_count != 3)); then
  echo 'prepare_kof_source: Kof source lacks the upstream native GC cycle guard' >&2
  exit 2
fi
printf '%s\n' 'prepare_kof_source: verified upstream native GC cycle guard'

# Keep the generated CLI/compiler/runtime identity aligned with VERSION before
# Maven packages the distribution.
printf 'kof.version=%s\nkof.compiler.version=%s\nkof.runtime.version=%s\nkof.stdlib.version=%s\nkof.tooling.api=%s\n' \
  "$expected_version" "$expected_version" "$expected_version" \
  "$expected_version" "$tooling_api" >"$resource"

for key in kof.version kof.compiler.version kof.runtime.version kof.stdlib.version; do
  grep -Fqx "$key=$expected_version" "$resource" || {
    echo "prepare_kof_source: failed to set $key" >&2
    exit 2
  }
done
printf 'prepare_kof_source: normalized Kof metadata to %s (tooling API %s)\n' \
  "$expected_version" "$tooling_api"
