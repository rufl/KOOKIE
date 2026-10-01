#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${KOOKIE_KOFSCRIPT_RUNTIME_TARGET:-jvm}"
case "$TARGET" in
  jvm|native) ;;
  *) echo 'kookie-kofscript-runtime: KOOKIE_KOFSCRIPT_RUNTIME_TARGET must be jvm or native' >&2; exit 2 ;;
esac
command -v kof >/dev/null || {
  echo 'kookie-kofscript-runtime: kof is required' >&2
  exit 2
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-kofscript-runtime.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM
mkdir "$WORK_DIR/core"
for source_file in "$ROOT_DIR"/src/core/*.kf; do
  ln -s "$source_file" "$WORK_DIR/core/$(basename "$source_file")"
done
ln -s "$ROOT_DIR/apps/kofscript_runtime/main.kf" "$WORK_DIR/main.kf"

if [[ "$TARGET" == native ]]; then
  [[ "$#" == 8 && -f "$1" && ! -L "$1" ]] || {
    echo 'Usage: kookie-kofscript-runtime <artifact> <tick> <sequence> <event-kind> <player> <subject> <subject-kind> <value>' >&2
    exit 2
  }
  cp -- "$1" "$WORK_DIR/artifact.kofart"
  printf '%s\n' "$2" "$3" "$4" "$5" "$6" "$7" "$8" \
    >"$WORK_DIR/.kookie-kofscript-request"
  (cd "$WORK_DIR" && kof run main.kf --target native)
else
  kof run "$WORK_DIR/main.kf" --target jvm "$@"
fi
