#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/sdl3_dependencies.sh"

SOURCE_ARCHIVE_URL='https://github.com/libsdl-org/SDL_mixer/releases/download/release-3.2.4/SDL3_mixer-3.2.4.tar.gz'
SOURCE_ARCHIVE_SHA256='182a07c745375e113dc740d43964ff21b0be29f29f59876c4dbc4db3d32f6901'
CACHE_PREFIX="$ROOT_DIR/.kookie-deps/sdl3-mixer-3.2.4"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-sdl3-mixer.XXXXXX")"
build_root=""
install_prefix=""
cleanup() {
  rm -rf -- "$WORK_DIR"
  [[ -z "$build_root" ]] || rm -rf -- "$build_root"
  [[ -z "$install_prefix" ]] || rm -rf -- "$install_prefix"
}
trap cleanup EXIT INT TERM

for command_name in cmake cc pkg-config sha256sum tar; do
  command -v "$command_name" >/dev/null || {
    echo "bootstrap_sdl3_mixer: $command_name is required" >&2
    exit 2
  }
done

kookie_prepare_sdl3_host "$ROOT_DIR" || {
  echo 'bootstrap_sdl3_mixer: SDL3 3.4.18 development files are unavailable' >&2
  exit 2
}

if KOOKIE_SDL3_MIXER_PREFIX="$CACHE_PREFIX" \
    kookie_prepare_sdl3_dependencies "$ROOT_DIR"; then
  printf 'SDL3_mixer 3.2.4 already prepared at %s\n' "$CACHE_PREFIX"
  exit 0
fi

source_root="${KOOKIE_SDL3_MIXER_SOURCE:-}"
archive="${KOOKIE_SDL3_MIXER_ARCHIVE:-}"
if [[ -n "$source_root" ]]; then
  [[ -d "$source_root" ]] || {
    echo "bootstrap_sdl3_mixer: source directory is unavailable: $source_root" >&2
    exit 2
  }
  source_root="$(cd -- "$source_root" && pwd)"
elif [[ -z "$archive" ]]; then
  archive="$WORK_DIR/SDL3_mixer-3.2.4.tar.gz"
  if command -v curl >/dev/null; then
    curl --fail --location --retry 3 --output "$archive" "$SOURCE_ARCHIVE_URL"
  elif command -v wget >/dev/null; then
    wget --https-only --output-document="$archive" "$SOURCE_ARCHIVE_URL"
  else
    echo 'bootstrap_sdl3_mixer: curl or wget is required to download SDL_mixer 3.2.4' >&2
    exit 2
  fi
fi

if [[ -n "$archive" ]]; then
  [[ -f "$archive" && ! -L "$archive" ]] || {
    echo "bootstrap_sdl3_mixer: archive must be a regular file: $archive" >&2
    exit 2
  }
  printf '%s  %s\n' "$SOURCE_ARCHIVE_SHA256" "$archive" | sha256sum --check -
  source_root="$WORK_DIR/source"
  mkdir -p "$source_root"
  tar -xzf "$archive" -C "$source_root" --strip-components=1
fi

source_header="$source_root/include/SDL3_mixer/SDL_mixer.h"
[[ -f "$source_header" ]] || {
  echo "bootstrap_sdl3_mixer: SDL_mixer.h is missing from $source_root" >&2
  exit 2
}
[[ "$(_kookie_sdl_mixer_header_version "$source_header")" == "$KOOKIE_SDL3_MIXER_REQUIRED_VERSION" ]] || {
  echo 'bootstrap_sdl3_mixer: source headers are not SDL_mixer 3.2.4' >&2
  exit 2
}

build_root="$ROOT_DIR/build/deps/.sdl3-mixer-3.2.4-build.$$"
install_prefix="$ROOT_DIR/build/deps/.sdl3-mixer-3.2.4-prefix.$$"
rm -rf -- "$build_root" "$install_prefix"
mkdir -p "$ROOT_DIR/build/deps" "$ROOT_DIR/.kookie-deps"
cmake_args=(
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX="$install_prefix"
  -DCMAKE_INSTALL_LIBDIR=lib
  -DBUILD_SHARED_LIBS=ON
  -DSDLMIXER_INSTALL=ON
  -DSDLMIXER_VENDORED=ON
  -DSDLMIXER_AIFF=OFF
  -DSDLMIXER_WAVE=ON
  -DSDLMIXER_VOC=OFF
  -DSDLMIXER_AU=OFF
  -DSDLMIXER_FLAC=OFF
  -DSDLMIXER_GME=OFF
  -DSDLMIXER_MOD=OFF
  -DSDLMIXER_MP3=OFF
  -DSDLMIXER_MIDI=OFF
  -DSDLMIXER_OPUS=OFF
  -DSDLMIXER_VORBIS_STB=ON
  -DSDLMIXER_VORBIS_VORBISFILE=OFF
  -DSDLMIXER_VORBIS_TREMOR=OFF
  -DSDLMIXER_WAVPACK=OFF
  -DSDLMIXER_EXAMPLES=OFF
  -DSDLMIXER_TESTS=OFF
)
if [[ -n "${KOOKIE_SDL3_PREFIX:-}" ]]; then
  cmake_args+=("-DCMAKE_PREFIX_PATH=$KOOKIE_SDL3_PREFIX")
fi
cmake -S "$source_root" -B "$build_root" "${cmake_args[@]}"
cmake --build "$build_root" --parallel "${KOOKIE_SDL3_MIXER_JOBS:-2}"
cmake --install "$build_root"
rm -rf -- "$CACHE_PREFIX"
mv -- "$install_prefix" "$CACHE_PREFIX"
rm -rf -- "$build_root"

KOOKIE_SDL3_MIXER_PREFIX="$CACHE_PREFIX" \
  kookie_require_sdl3_dependencies "$ROOT_DIR"
printf 'SDL3_mixer 3.2.4 prepared at %s\n' "$CACHE_PREFIX"
