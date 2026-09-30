#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v kof >/dev/null || {
  echo 'kookie_cooker: kof is required' >&2
  exit 2
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-cooker.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

mkdir -p "$WORK_DIR/core" "$WORK_DIR/content"
for source_file in "$ROOT_DIR"/src/core/*.kf; do
  ln -s "$source_file" "$WORK_DIR/core/$(basename "$source_file")"
done
for source_file in "$ROOT_DIR"/src/content/*.kf; do
  ln -s "$source_file" "$WORK_DIR/content/$(basename "$source_file")"
done
ln -s "$ROOT_DIR/apps/creator_cooker/main.kf" "$WORK_DIR/main.kf"

kof run "$WORK_DIR/main.kf" --target jvm "$@"
