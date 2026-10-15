#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${1:-generic}"
case "$profile" in
  static|native|release-linux|release-windows) ;;
  *) echo "runner_preflight: unsupported profile: $profile" >&2; exit 2 ;;
esac

require_command() {
  command -v "$1" >/dev/null || {
    echo "runner_preflight: required command missing: $1" >&2
    exit 2
  }
}

printf 'runner profile: %s\n' "$profile"
printf 'runner OS: %s\n' "$(uname -srm)"
printf 'runner CPU: %s\n' "$(nproc 2>/dev/null || printf unknown)"
printf 'runner memory: %s\n' "$(free -h 2>/dev/null | awk '/^Mem:/ { print $2; exit }' || printf unknown)"
printf 'runner workspace disk: %s\n' "$(df -h . | awk 'NR == 2 { print $4 " free"; exit }')"

for command_name in bash git python3 sha256sum tar openssl; do
  require_command "$command_name"
done

if [[ "$profile" == static || "$profile" == native ]]; then
  for command_name in java kof; do
    require_command "$command_name"
  done
  printf 'Kof: %s\n' "$(kof version)"
  printf 'Java: '
  java -version 2>&1 | head -n 1
fi

if [[ "$profile" == native ]]; then
  for command_name in clang gcc glslc spirv-val pkg-config wine zig; do
    require_command "$command_name"
  done
  pkg-config --exists freetype2 harfbuzz || {
    echo 'runner_preflight: freetype2 and harfbuzz pkg-config entries are required' >&2
    exit 2
  }
  printf 'Clang: %s\n' "$(clang --version | head -n 1)"
  printf 'GCC: %s\n' "$(gcc --version | head -n 1)"
  printf 'GLSLC: %s\n' "$(glslc --version 2>&1 | head -n 1)"
  printf 'SPIRV-VAL: %s\n' "$(spirv-val --version 2>&1 | head -n 1)"
  printf 'pkg-config: %s\n' "$(pkg-config --version)"
  printf 'Wine: %s\n' "$(wine --version 2>&1 | head -n 1)"
  printf 'Zig: %s\n' "$(zig version)"
fi

if [[ "$profile" == release-linux ]]; then
  for command_name in cc pkg-config glslc spirv-val; do
    require_command "$command_name"
  done
  : "${KOOKIE_KOF_ARCHIVE:?runner_preflight: KOOKIE_KOF_ARCHIVE is required}"
  : "${KOOKIE_SDL3_PREFIX:?runner_preflight: KOOKIE_SDL3_PREFIX is required}"
  [[ -f "$KOOKIE_KOF_ARCHIVE" ]] || exit 2
  [[ -f "$KOOKIE_SDL3_PREFIX/include/SDL3/SDL_version.h" ]] || exit 2
  source "$root_dir/scripts/sdl3_dependencies.sh"
  kookie_prepare_sdl3_dependencies "$root_dir" || {
    echo 'runner_preflight: Linux release SDL dependency preparation failed' >&2
    exit 2
  }
  pkg-config --exists sdl3 sdl3-mixer freetype2 harfbuzz || {
    echo 'runner_preflight: Linux release SDL/text pkg-config entries are required' >&2
    exit 2
  }
  printf 'CC: %s\n' "$(cc --version | head -n 1)"
  printf 'GLSLC: %s\n' "$(glslc --version 2>&1 | head -n 1)"
  printf 'SPIRV-VAL: %s\n' "$(spirv-val --version 2>&1 | head -n 1)"
  printf 'SDL3: %s\n' "$(pkg-config --modversion sdl3)"
  printf 'SDL3_mixer: %s\n' "$(pkg-config --modversion sdl3-mixer)"
fi

if [[ "$profile" == release-windows ]]; then
  for command_name in python3 pkg-config zig glslc spirv-val; do
    require_command "$command_name"
  done
  for variable_name in KOOKIE_KOF_ARCHIVE KOOKIE_WINDOWS_SDL_PREFIX \
      KOOKIE_WINDOWS_SDL_MIXER_PREFIX KOOKIE_WINDOWS_FREETYPE_PREFIX \
      KOOKIE_WINDOWS_HARFBUZZ_PREFIX KOOKIE_DXC; do
    [[ -n "${!variable_name:-}" ]] || {
      echo "runner_preflight: $variable_name is required" >&2
      exit 2
    }
  done
  for required_path in "$KOOKIE_KOF_ARCHIVE" \
      "$KOOKIE_WINDOWS_SDL_PREFIX/include/SDL3/SDL_version.h" \
      "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/include/SDL3_mixer/SDL_mixer.h"; do
    [[ -e "$required_path" ]] || {
      echo "runner_preflight: required runner path missing: $required_path" >&2
      exit 2
    }
  done
  printf 'Zig: %s\n' "$(zig version)"
  printf 'DXC: %s\n' "$("$KOOKIE_DXC" --version 2>&1 | head -n 1)"
  printf 'pkg-config: %s\n' "$(pkg-config --version)"
  printf 'GLSLC: %s\n' "$(glslc --version 2>&1 | head -n 1)"
  printf 'SPIRV-VAL: %s\n' "$(spirv-val --version 2>&1 | head -n 1)"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    printf '\n### Runner preflight: `%s`\n' "$profile"
    printf -- '- OS: `%s`\n' "$(uname -srm)"
    printf -- '- CPU: `%s`\n' "$(nproc 2>/dev/null || printf unknown)"
    printf -- '- Memory: `%s`\n' "$(free -h 2>/dev/null | awk '/^Mem:/ { print $2; exit }' || printf unknown)"
    printf -- '- Disk free: `%s`\n' "$(df -h . | awk 'NR == 2 { print $4; exit }')"
  } >>"$GITHUB_STEP_SUMMARY"
fi
