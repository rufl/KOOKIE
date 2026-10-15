#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

mode=write
if [[ "${1:-}" == "--check" ]]; then
  mode=check
  shift
fi
target="${1:?write_build_identity: target is required}"
build_dir="${2:?write_build_identity: build directory is required}"
manifest="${3:?write_build_identity: manifest path is required}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"

case "$target" in
  jvm) [[ -f "$build_dir/Default/Main.class" ]] || {
    echo "write_build_identity: JVM main class missing: $build_dir/Default/Main.class" >&2
    exit 2
  } ;;
  native) [[ -x "$build_dir/Default/Main" ]] || {
    echo "write_build_identity: native executable missing: $build_dir/Default/Main" >&2
    exit 2
  } ;;
  *) echo "write_build_identity: unsupported target: $target" >&2; exit 2 ;;
esac

kof_launcher="$(readlink -f "$(command -v kof)")"
kof_compiler_jar="$(dirname "$(dirname "$kof_launcher")")/lib/kof.jar"
[[ -f "$kof_compiler_jar" ]] || {
  echo "write_build_identity: compiler JAR missing: $kof_compiler_jar" >&2
  exit 2
}
source_tree_sha256="$(
  git -C "$root_dir" ls-files -z -- src |
    while IFS= read -r -d '' source_path; do
      printf '%s\0' "$source_path"
      sha256sum "$root_dir/$source_path" | cut -d ' ' -f 1
    done | sha256sum | cut -d ' ' -f 1
)"
source_commit="$(git -C "$root_dir" rev-parse HEAD)"
kof_version="$(kof version)"
kof_source_commit="${KOOKIE_KOF_SOURCE_COMMIT:-$KOF_PIN_SOURCE_COMMIT}"
kof_compiler_sha256="$(sha256sum "$kof_compiler_jar" | cut -d ' ' -f 1)"
if [[ "$mode" == check ]]; then
  [[ -f "$manifest" && ! -L "$manifest" ]] || {
    echo "write_build_identity: identity manifest missing: $manifest" >&2
    exit 2
  }
  grep -Fxq "target=$target" "$manifest" &&
    grep -Fxq "source_commit=$source_commit" "$manifest" &&
    grep -Fxq "source_tree_sha256=$source_tree_sha256" "$manifest" &&
    grep -Fxq "kof_version=$kof_version" "$manifest" &&
    grep -Fxq "kof_source_commit=$kof_source_commit" "$manifest" &&
    grep -Fxq "kof_compiler_sha256=$kof_compiler_sha256" "$manifest" || {
      echo "write_build_identity: identity mismatch: $manifest" >&2
      exit 2
    }
  printf 'Build identity verified: target=%s manifest=%s\n' "$target" "$manifest"
  exit 0
fi
mkdir -p "$(dirname "$manifest")"
{
  printf 'target=%s\n' "$target"
  printf 'source_commit=%s\n' "$source_commit"
  printf 'source_tree_sha256=%s\n' "$source_tree_sha256"
  printf 'kof_version=%s\n' "$kof_version"
  printf 'kof_source_commit=%s\n' "$kof_source_commit"
  printf 'kof_compiler_sha256=%s\n' "$kof_compiler_sha256"
} >"$manifest"
printf 'Build identity written: target=%s manifest=%s\n' "$target" "$manifest"
