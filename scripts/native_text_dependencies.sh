#!/usr/bin/env bash

# Shared native text dependency discovery for verification and packaging.
# Both libraries are mandatory for the native runtime renderer.

kookie_require_native_text_dependencies() {
  local root_directory="${1:-.}"
  if ! command -v pkg-config >/dev/null ||
     ! pkg-config --exists freetype2 harfbuzz; then
    echo "native text renderer requires pkg-config entries for freetype2 and harfbuzz" >&2
    return 1
  fi
  local cflags libs
  cflags="$(pkg-config --cflags freetype2 harfbuzz)"
  libs="$(pkg-config --libs freetype2 harfbuzz)"
  if [[ -z "$cflags" || -z "$libs" ]]; then
    echo "native text renderer dependency flags are incomplete" >&2
    return 1
  fi
  printf 'native text dependencies: freetype2=%s harfbuzz=%s\n' \
    "$(pkg-config --modversion freetype2)" \
    "$(pkg-config --modversion harfbuzz)" >&2
  [[ -d "$root_directory/native" ]]
}

kookie_native_text_pkg_config() {
  pkg-config --cflags --libs freetype2 harfbuzz
}
