#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/sdl3_dependencies.sh"

SDL3_VERSION="${SDL3_VERSION:-3.4.18}"
SDL3_SOURCE_ARCHIVE_URL="${SDL3_SOURCE_ARCHIVE_URL:-https://github.com/libsdl-org/SDL/releases/download/release-${SDL3_VERSION}/SDL3-${SDL3_VERSION}.tar.gz}"
SDL3_SOURCE_ARCHIVE_SHA256="${SDL3_SOURCE_ARCHIVE_SHA256:-9c75cf16330322c217dedd2e0609f1124f1b54b8633e763467b4684d0f4334a3}"
CACHE_ROOT="${KOOKIE_SDL3_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/kookie/sdl3}"
PREFIX="${KOOKIE_SDL3_PREFIX:-$CACHE_ROOT/SDL3-$SDL3_VERSION}"
ARCHIVE="${KOOKIE_SDL3_SOURCE_ARCHIVE:-$CACHE_ROOT/SDL3-$SDL3_VERSION.tar.gz}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-sdl3.XXXXXX")"
BUILD_DIR="$WORK_DIR/build"
INSTALL_PREFIX="$WORK_DIR/prefix"
SOURCE_DIR="$WORK_DIR/source"

cleanup() {
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM

for command_name in cmake cc pkg-config curl sha256sum tar; do
  command -v "$command_name" >/dev/null || {
    echo "bootstrap_sdl3: $command_name is required" >&2
    exit 2
  }
done

export KOOKIE_SDL3_PREFIX="$PREFIX"
if kookie_prepare_sdl3_host "$ROOT_DIR" >/dev/null 2>&1; then
  printf 'SDL3 %s already prepared at %s\n' "$SDL3_VERSION" "$PREFIX"
  exit 0
fi

mkdir -p "$CACHE_ROOT"
if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --retry 3 --connect-timeout 15 --max-time 300 \
    --output "$ARCHIVE" "$SDL3_SOURCE_ARCHIVE_URL"
fi
printf '%s  %s\n' "$SDL3_SOURCE_ARCHIVE_SHA256" "$ARCHIVE" | sha256sum --check -

mkdir -p "$SOURCE_DIR"
tar -xzf "$ARCHIVE" -C "$SOURCE_DIR" --strip-components=1
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DSDL_SHARED=ON \
  -DSDL_STATIC=OFF \
  -DSDL_TESTS=OFF \
  -DSDL_EXAMPLES=OFF
cmake --build "$BUILD_DIR" --parallel "${KOOKIE_SDL3_JOBS:-2}"
cmake --install "$BUILD_DIR"

KOOKIE_SDL3_PREFIX="$INSTALL_PREFIX" kookie_prepare_sdl3_host "$ROOT_DIR" >/dev/null
rm -rf -- "$PREFIX"
mkdir -p "$(dirname "$PREFIX")"
mv -- "$INSTALL_PREFIX" "$PREFIX"
printf 'SDL3 %s prepared at %s\n' "$SDL3_VERSION" "$PREFIX"
