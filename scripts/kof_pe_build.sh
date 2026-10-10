#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/kof_pin.sh"
EXPECTED_KOF_VERSION="$KOF_PIN_CLI_VERSION"
EXPECTED_KOF_SOURCE_COMMIT="$KOF_PIN_SOURCE_COMMIT"
EXPECTED_ZIG_VERSION='0.17.0'
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}"
[[ "$SOURCE_DATE_EPOCH" =~ ^[0-9]+$ ]] || {
  echo 'kof-pe-build: SOURCE_DATE_EPOCH must be a non-negative integer' >&2
  exit 2
}
export SOURCE_DATE_EPOCH

usage() {
  echo 'Usage: scripts/kof_pe_build.sh <source.kf|directory> --output <directory> [--library]' >&2
}

[[ "$#" == 3 || "$#" == 4 ]] || {
  usage
  exit 2
}
[[ "$2" == '--output' ]] || {
  usage
  exit 2
}
LIBRARY=0
if [[ "$#" == 4 ]]; then
  [[ "$4" == '--library' ]] || {
    usage
    exit 2
  }
  LIBRARY=1
fi
SOURCE="$1"
OUTPUT_DIR="$3"
[[ -f "$SOURCE" || -d "$SOURCE" ]] || {
  echo "kof-pe-build: source does not exist: $SOURCE" >&2
  exit 2
}
for tool in cc cmp kof objcopy python3 zig readlink; do
  command -v "$tool" >/dev/null || {
    echo "kof-pe-build: $tool is required" >&2
    exit 2
  }
done
actual_zig_version="$(zig version)"
[[ "$actual_zig_version" == "$EXPECTED_ZIG_VERSION" ]] || {
  echo "kof-pe-build: expected Zig $EXPECTED_ZIG_VERSION; found $actual_zig_version" >&2
  exit 2
}


actual_kof_version="$(kof version)"
[[ "$actual_kof_version" == "$EXPECTED_KOF_VERSION" ]] || {
  echo "kof-pe-build: expected $EXPECTED_KOF_VERSION; found $actual_kof_version" >&2
  exit 2
}
kof_launcher="$(readlink -f "$(command -v kof)")"
kof_root="$(cd -- "$(dirname -- "$kof_launcher")/.." && pwd)"
kof_jar="$kof_root/lib/kof.jar"
[[ -f "$kof_jar" ]] || {
  echo "kof-pe-build: pinned Kof compiler jar is missing: $kof_jar" >&2
  exit 2
}
source_commit="${KOOKIE_KOF_SOURCE_COMMIT:-}"
if [[ -z "$source_commit" &&
  "$(basename -- "$kof_root")" == *"-${EXPECTED_KOF_SOURCE_COMMIT:0:8}" ]]; then
  source_commit="$EXPECTED_KOF_SOURCE_COMMIT"
fi
[[ "$source_commit" == "$EXPECTED_KOF_SOURCE_COMMIT" ]] || {
  echo "kof-pe-build: expected Kof source commit $EXPECTED_KOF_SOURCE_COMMIT; found ${source_commit:-unverified}" >&2
  exit 2
}

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kookie-kof-pe.XXXXXX")"
cleanup() { rm -rf -- "$work_dir"; }
trap cleanup EXIT INT TERM
classes="$work_dir/classes"
generated_c="$work_dir/kof-module.c"
generated_obj="$work_dir/kof-module.obj"
generated_exe="$work_dir/kof-module.exe"
mkdir -p "$classes"

javac --release 21 -Xlint:all -Werror -cp "$kof_jar" -d "$classes" \
  "$ROOT_DIR/tooling/kof-pe-backend/src/dev/kof/compiler/KofPeBackendMain.java"
backend_args=("$SOURCE" "$generated_c")
if [[ "$LIBRARY" == 1 ]]; then
  backend_args+=(--library)
fi
java_classpath_separator=':'
case "${OSTYPE:-}" in
  msys*|cygwin*|win32*) java_classpath_separator=';' ;;
esac
java -cp "$classes${java_classpath_separator}$kof_jar" dev.kof.compiler.KofPeBackendMain \
  "${backend_args[@]}"
(
  cd "$work_dir"
  zig cc -target x86_64-windows-gnu -g0 -std=c11 -O2 \
    -Wall -Wextra -Werror -fno-ident -c kof-module.c -o kof-module.obj
  objcopy --strip-debug kof-module.obj kof-module.stripped.obj
  mv -- kof-module.stripped.obj kof-module.obj
  if [[ "$LIBRARY" == 0 ]]; then
    zig cc -target x86_64-windows-gnu -g0 -s -fno-ident \
      -Wl,--build-id=none kof-module.obj -o kof-module.exe
  fi
)

mkdir -p "$OUTPUT_DIR"
cp -- "$generated_c" "$OUTPUT_DIR/kof-module.c"
cp -- "$generated_obj" "$OUTPUT_DIR/kof-module.obj"
if [[ "$LIBRARY" == 0 ]]; then
  cp -- "$generated_exe" "$OUTPUT_DIR/kof-module.exe"
  printf 'kof-pe-built source=%s object=%s executable=%s\n' \
    "$SOURCE" "$OUTPUT_DIR/kof-module.obj" "$OUTPUT_DIR/kof-module.exe"
else
  printf 'kof-pe-built source=%s object=%s library=1\n' \
    "$SOURCE" "$OUTPUT_DIR/kof-module.obj"
fi
