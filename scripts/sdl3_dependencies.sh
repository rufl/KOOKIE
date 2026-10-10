#!/usr/bin/env bash
# Shared SDL3/SDL3_mixer discovery for Linux verification and packaging.
# This file is sourced by Bash scripts; it deliberately does not change shell options.

KOOKIE_SDL3_REQUIRED_VERSION=3.4.18
KOOKIE_SDL3_MIXER_REQUIRED_VERSION=3.2.4

_kookie_sdl_prepend_path() {
  local variable_name="$1"
  local value="$2"
  local current="${!variable_name:-}"
  case ":$current:" in
    *":$value:"*) ;;
    *)
      if [[ -n "$current" ]]; then
        printf -v "$variable_name" '%s:%s' "$value" "$current"
      else
        printf -v "$variable_name" '%s' "$value"
      fi
      export "$variable_name"
      ;;
  esac
}

_kookie_sdl_prepend_pkg_config_path() {
  _kookie_sdl_prepend_path PKG_CONFIG_PATH "$1"
}

_kookie_sdl_prepend_library_path() {
  _kookie_sdl_prepend_path LD_LIBRARY_PATH "$1"
}

_kookie_sdl_find_library() {
  local directory="$1"
  local stem="$2"
  local candidate
  for candidate in "$directory/$stem" "$directory/$stem".*; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

_kookie_sdl_link_argument() {
  local directory="$1"
  local stem="$2"
  local candidate
  if [[ -f "$directory/$stem" ]]; then
    local library_name="${stem#lib}"
    library_name="${library_name%.so}"
    printf '%s\n' "-l$library_name"
    return 0
  fi
  candidate="$(_kookie_sdl_find_library "$directory" "$stem")" || return 1
  printf '%s\n' "-l:$(basename "$candidate")"
}

_kookie_sdl_prefix_is_safe() {
  [[ "$1" != *[[:space:]]* ]]
}

_kookie_sdl_header_version() {
  local header="$1"
  local macro_prefix="$2"
  awk -v prefix="$macro_prefix" '
    $1 == "#define" && $2 == prefix "_MAJOR_VERSION" { major = $3 }
    $1 == "#define" && $2 == prefix "_MINOR_VERSION" { minor = $3 }
    $1 == "#define" && $2 == prefix "_MICRO_VERSION" { micro = $3 }
    END {
      if (major == "" || minor == "" || micro == "") exit 1
      print major "." minor "." micro
    }
  ' "$header"
}


_kookie_sdl_mixer_header_version() {
  _kookie_sdl_header_version "$1" SDL_MIXER
}

_kookie_sdl_write_prefix_pc() {
  local output_directory="$1"
  local package_name="$2"
  local description="$3"
  local version="$4"
  local include_directory="$5"
  local library_directory="$6"
  local link_argument="$7"
  local requires_line="${8:-}"
  mkdir -p "$output_directory"
  case "$package_name" in
    sdl3)
      cat >"$output_directory/sdl3.pc" <<EOF
prefix=$(_kookie_sdl_prefix_root "$include_directory" "$library_directory")
exec_prefix=\${prefix}
libdir=$library_directory
includedir=$include_directory

Name: SDL3
Description: $description
Version: $version
Libs: -L\${libdir} $link_argument
Cflags: -I\${includedir}
EOF
      ;;
    sdl3-mixer)
      cat >"$output_directory/sdl3-mixer.pc" <<EOF
prefix=$(_kookie_sdl_prefix_root "$include_directory" "$library_directory")
exec_prefix=\${prefix}
libdir=$library_directory
includedir=$include_directory

Name: SDL3_mixer
Description: $description
Version: $version
Requires: ${requires_line:-sdl3 >= 3.4.0}
Libs: -L\${libdir} $link_argument
Cflags: -I\${includedir}
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

_kookie_sdl_prefix_root() {
  local include_directory="$1"
  local library_directory="$2"
  local include_parent library_parent
  include_parent="${include_directory%/include*}"
  library_parent="${library_directory%/lib*}"
  if [[ -n "$include_parent" && "$include_parent" == "$library_parent" ]]; then
    printf '%s\n' "$include_parent"
  else
    printf '%s\n' /
  fi
}

_kookie_sdl_prepare_custom_sdl3() {
  local root_directory="$1"
  local prefix="${KOOKIE_SDL3_PREFIX:-}"
  [[ -n "$prefix" ]] || return 0
  _kookie_sdl_prefix_is_safe "$prefix" || return 1
  local include_directory="$prefix/include"
  local library_directory="$prefix/lib"
  [[ -f "$include_directory/SDL3/SDL.h" ]] || return 1
  [[ -f "$include_directory/SDL3/SDL_version.h" ]] || return 1
  if [[ "$(_kookie_sdl_header_version \
      "$include_directory/SDL3/SDL_version.h" SDL)" != "$KOOKIE_SDL3_REQUIRED_VERSION" ]]; then
    return 1
  fi
  local link_argument
  link_argument="$(_kookie_sdl_link_argument "$library_directory" libSDL3.so)" || return 1
  local metadata_directory="$root_directory/build/deps/pkgconfig"
  _kookie_sdl_write_prefix_pc \
    "$metadata_directory" sdl3 'Simple DirectMedia Layer' \
    "$KOOKIE_SDL3_REQUIRED_VERSION" "$include_directory" \
    "$library_directory" "$link_argument"
  _kookie_sdl_prepend_pkg_config_path "$metadata_directory"
  _kookie_sdl_prepend_library_path "$library_directory"
}

_kookie_sdl_prepare_custom_mixer() {
  local root_directory="$1"
  local prefix="${KOOKIE_SDL3_MIXER_PREFIX:-}"
  local include_directory="${KOOKIE_SDL3_MIXER_INCLUDE_DIR:-}"
  local library_directory="${KOOKIE_SDL3_MIXER_LIBRARY_DIR:-}"
  if [[ -z "$prefix" && -z "$include_directory" && -z "$library_directory" &&
        -d "$root_directory/.kookie-deps/sdl3-mixer-3.2.4" ]]; then
    prefix="$root_directory/.kookie-deps/sdl3-mixer-3.2.4"
  fi
  if [[ -n "$prefix" ]]; then
    _kookie_sdl_prefix_is_safe "$prefix" || return 1
    include_directory="$prefix/include"
    library_directory="$prefix/lib"
  fi
  if [[ -z "$include_directory" || -z "$library_directory" ]]; then
    return 0
  fi
  _kookie_sdl_prefix_is_safe "$include_directory" || return 1
  _kookie_sdl_prefix_is_safe "$library_directory" || return 1
  local header="$include_directory/SDL3_mixer/SDL_mixer.h"
  [[ -f "$header" ]] || return 1
  [[ "$(_kookie_sdl_mixer_header_version "$header")" == "$KOOKIE_SDL3_MIXER_REQUIRED_VERSION" ]] || return 1
  _kookie_sdl_find_library "$library_directory" libSDL3_mixer.so >/dev/null || return 1
  local link_argument
  link_argument="$(_kookie_sdl_link_argument "$library_directory" libSDL3_mixer.so)" || return 1
  local metadata_directory="$root_directory/build/deps/pkgconfig"
  _kookie_sdl_write_prefix_pc \
    "$metadata_directory" sdl3-mixer 'mixer library for Simple DirectMedia Layer' \
    "$KOOKIE_SDL3_MIXER_REQUIRED_VERSION" "$include_directory" \
    "$library_directory" "$link_argument" 'sdl3 >= 3.4.0'
  _kookie_sdl_prepend_pkg_config_path "$metadata_directory"
  _kookie_sdl_prepend_library_path "$library_directory"
}

_kookie_sdl_prepare_legacy_mixer_pc() {
  local root_directory="$1"
  if pkg-config --exists sdl3-mixer; then
    return 0
  fi
  pkg-config --exists sdl3_mixer || return 0
  local prefix include_directory library_directory
  prefix="$(pkg-config --variable=prefix sdl3_mixer 2>/dev/null || true)"
  include_directory="$(pkg-config --variable=includedir sdl3_mixer 2>/dev/null || true)"
  library_directory="$(pkg-config --variable=libdir sdl3_mixer 2>/dev/null || true)"
  if [[ "$include_directory" == "$prefix/include" &&
        "$library_directory" == "$prefix/lib" ]]; then
    KOOKIE_SDL3_MIXER_PREFIX="$prefix" \
      _kookie_sdl_prepare_custom_mixer "$root_directory"
  else
    KOOKIE_SDL3_MIXER_PREFIX= \
      KOOKIE_SDL3_MIXER_INCLUDE_DIR="$include_directory" \
      KOOKIE_SDL3_MIXER_LIBRARY_DIR="$library_directory" \
      _kookie_sdl_prepare_custom_mixer "$root_directory"
  fi
}

_kookie_sdl_validate_metadata() {
  pkg-config --exists sdl3 sdl3-mixer || return 1
  [[ "$(pkg-config --modversion sdl3)" == "$KOOKIE_SDL3_REQUIRED_VERSION" ]] || return 1
  [[ "$(pkg-config --modversion sdl3-mixer)" == "$KOOKIE_SDL3_MIXER_REQUIRED_VERSION" ]] || return 1
  local sdl_include_directory mixer_include_directory
  sdl_include_directory="$(pkg-config --variable=includedir sdl3 2>/dev/null || true)"
  mixer_include_directory="$(pkg-config --variable=includedir sdl3-mixer 2>/dev/null || true)"
  [[ -f "$sdl_include_directory/SDL3/SDL_version.h" ]] || return 1
  [[ -f "$mixer_include_directory/SDL3_mixer/SDL_mixer.h" ]] || return 1
  if [[ "$(_kookie_sdl_header_version \
      "$sdl_include_directory/SDL3/SDL_version.h" SDL)" != "$KOOKIE_SDL3_REQUIRED_VERSION" ]]; then
    return 1
  fi
  if [[ "$(_kookie_sdl_mixer_header_version \
      "$mixer_include_directory/SDL3_mixer/SDL_mixer.h")" != \
      "$KOOKIE_SDL3_MIXER_REQUIRED_VERSION" ]]; then
    return 1
  fi
  [[ -n "$(pkg-config --cflags sdl3 sdl3-mixer)" ]] || return 1
  [[ -n "$(pkg-config --libs sdl3 sdl3-mixer)" ]] || return 1
}

kookie_prepare_sdl3_host() {
  local root_directory="$1"
  command -v pkg-config >/dev/null 2>&1 || return 1
  _kookie_sdl_prepare_custom_sdl3 "$root_directory" || return 1
  pkg-config --exists sdl3 || return 1
  [[ "$(pkg-config --modversion sdl3)" == "$KOOKIE_SDL3_REQUIRED_VERSION" ]] || return 1
}

kookie_prepare_sdl3_dependencies() {
  local root_directory="$1"
  kookie_prepare_sdl3_host "$root_directory" || return 1
  _kookie_sdl_prepare_custom_mixer "$root_directory" || return 1
  if ! pkg-config --exists sdl3-mixer; then
    _kookie_sdl_prepare_legacy_mixer_pc "$root_directory" || return 1
  fi
  _kookie_sdl_validate_metadata
}

kookie_require_sdl3_dependencies() {
  local root_directory="$1"
  if kookie_prepare_sdl3_dependencies "$root_directory"; then
    return 0
  fi
  cat >&2 <<'EOF'
KOOKIE requires SDL3 3.4.18 and SDL_mixer 3.2.4 development metadata.
Install them through pkg-config, set KOOKIE_SDL3_PREFIX and/or
KOOKIE_SDL3_MIXER_PREFIX, or run:
  bash scripts/bootstrap_sdl3_mixer.sh
EOF
  return 1
}
