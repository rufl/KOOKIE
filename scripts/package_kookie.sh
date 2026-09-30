#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BASE_URL="${KOOKIE_PACKAGE_BASE_URL:-}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="linux-x86_64"
RUNTIME="${KOOKIE_RUNTIME:-native}"
VERSION="${KOOKIE_VERSION:-0.1.0-dogfood.1}"
BUILD_ID="${KOOKIE_BUILD_ID:-$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)}"
OUTPUT_DIR="${KOOKIE_OUTPUT_DIR:-$ROOT_DIR/release}"
PROVENANCE_SCHEMA="${KOOKIE_PACKAGE_PROVENANCE_SCHEMA:-kookie.package-provenance/v2}"
SIGNING_KEY="${KOOKIE_SIGNING_KEY:-}"
KOF_ARCHIVE_SHA256="${KOOKIE_KOF_ARCHIVE_SHA256:-}"
KOF_SOURCE_COMMIT="${KOOKIE_KOF_SOURCE_COMMIT:-}"
EXPECTED_KOF_VERSION="${KOOKIE_EXPECTED_KOF_VERSION:-kof 0.5.0-beta}"
EXPECTED_KOF_SOURCE_COMMIT="${KOOKIE_EXPECTED_KOF_SOURCE_COMMIT:-bf17ac7e736471c8a04b4153e5b0f607be75e70c}"

usage() {
  cat <<'EOF'
Usage: scripts/package_kookie.sh [--runtime native|presentation] [--target linux-x86_64|windows-x86_64]

Builds a signed immutable KOOKIE archive, provenance manifest, public key,
signature set, and SHA256SUMS. Native Linux packages contain the Kof executable
and use the host's system runtime. Presentation packages contain the persistent
native Kof SDL_GPU application, SDL3, SDL_mixer, the adapter, and shaders.
Every Linux package also contains a graphics-free Kof dedicated workload server,
a native bounded content cooker, and a Kof `Buffer(U8)` SIMD benchmark with
native timing. Windows packages contain the native SDL3 and SDL_mixer game shell.
Java runtimes are deliberately excluded.
Set `KOOKIE_KOF_ARCHIVE_SHA256` and `KOOKIE_KOF_SOURCE_COMMIT` to the
verified distribution used for the build.
EOF
}

while (($#)); do
  case "$1" in
    --runtime) RUNTIME="${2:?missing runtime}"; shift 2 ;;
    --target) TARGET="${2:?missing target}"; shift 2 ;;
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --build-id) BUILD_ID="${2:?missing build id}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?missing output directory}"; shift 2 ;;
    --signing-key) SIGNING_KEY="${2:?missing signing key}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "package_kookie: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$RUNTIME" in
  native|presentation) ;;
  *) echo "package_kookie: unsupported distributable runtime: $RUNTIME" >&2; exit 2 ;;
esac

case "$TARGET" in
  linux-x86_64) ;;
  windows-x86_64)
    if [[ "$RUNTIME" != native ]]; then
      echo 'package_kookie: Windows packaging requires --runtime native' >&2
      exit 2
    fi
    ;;
  *) echo "package_kookie: unsupported target: $TARGET" >&2; exit 2 ;;
esac

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || {
  echo 'package_kookie: version must be SemVer without a leading v' >&2
  exit 2
}
if [[ -z "$BASE_URL" ]]; then
  BASE_URL="https://github.com/rufl/KOOKIE/releases/download/$VERSION"
fi
[[ "$BASE_URL" == https://* ]] || {
  echo 'package_kookie: KOOKIE_PACKAGE_BASE_URL must be an HTTPS artifact directory' >&2
  exit 2
}
[[ "$BUILD_ID" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo 'package_kookie: build id contains unsafe characters' >&2
  exit 2
}
command -v sha256sum >/dev/null || { echo 'package_kookie: sha256sum is required' >&2; exit 2; }
command -v openssl >/dev/null || { echo 'package_kookie: openssl is required' >&2; exit 2; }
command -v stat >/dev/null || { echo 'package_kookie: stat is required' >&2; exit 2; }
command -v git >/dev/null || { echo 'package_kookie: git is required' >&2; exit 2; }
command -v readlink >/dev/null || { echo 'package_kookie: readlink is required' >&2; exit 2; }
command -v kof >/dev/null || { echo 'package_kookie: kof is required' >&2; exit 2; }
ACTUAL_KOF_VERSION="$(kof version 2>/dev/null)" || {
  echo 'package_kookie: unable to read the Kof toolchain version' >&2
  exit 2
}
[[ "$ACTUAL_KOF_VERSION" == "$EXPECTED_KOF_VERSION" ]] || {
  printf 'package_kookie: expected %s; found %s\n' \
    "$EXPECTED_KOF_VERSION" "$ACTUAL_KOF_VERSION" >&2
  exit 2
}
[[ "$KOF_ARCHIVE_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || {
  echo 'package_kookie: KOOKIE_KOF_ARCHIVE_SHA256 must identify the verified Kof distribution' >&2
  exit 2
}
[[ "$KOF_SOURCE_COMMIT" == "$EXPECTED_KOF_SOURCE_COMMIT" ]] || {
  printf 'package_kookie: expected Kof source commit %s; found %s\n' \
    "$EXPECTED_KOF_SOURCE_COMMIT" "${KOF_SOURCE_COMMIT:-unset}" >&2
  exit 2
}
KOF_LAUNCHER="$(readlink -f "$(command -v kof)")"
KOF_HOME="$(dirname "$(dirname "$KOF_LAUNCHER")")"
KOF_COMPILER_JAR="$KOF_HOME/lib/kof.jar"
[[ -f "$KOF_COMPILER_JAR" ]] || {
  echo "package_kookie: installed compiler jar missing: $KOF_COMPILER_JAR" >&2
  exit 2
}
KOF_COMPILER_SHA256="$(sha256sum "$KOF_COMPILER_JAR" | cut -d ' ' -f 1)"
[[ -n "$SIGNING_KEY" && -f "$SIGNING_KEY" && ! -L "$SIGNING_KEY" ]] || {
  echo 'package_kookie: KOOKIE_SIGNING_KEY must name a regular Ed25519 private key' >&2
  exit 2
}
signing_key_mode="$(stat -c '%a' "$SIGNING_KEY")"
if (( (8#$signing_key_mode & 077) != 0 )); then
  echo 'package_kookie: signing key must not be group/world accessible' >&2
  exit 2
fi
signing_key_description="$(openssl pkey -in "$SIGNING_KEY" -text -noout 2>/dev/null)" || {
  echo 'package_kookie: signing key is unreadable' >&2
  exit 2
}
[[ "$signing_key_description" == *ED25519* ]] || {
  echo 'package_kookie: signing key must use Ed25519' >&2
  exit 2
}
if [[ "$TARGET" == linux-x86_64 ]]; then
  command -v cc >/dev/null || {
    echo 'package_kookie: cc is required for the headless server adapter' >&2
    exit 2
  }
fi
if [[ "$RUNTIME" == presentation && "$TARGET" == linux-x86_64 ]]; then
  command -v ldd >/dev/null || { echo 'package_kookie: ldd is required for presentation packaging' >&2; exit 2; }
  command -v cc >/dev/null || { echo 'package_kookie: cc is required for presentation packaging' >&2; exit 2; }
  command -v glslc >/dev/null || { echo 'package_kookie: glslc is required for presentation packaging' >&2; exit 2; }
  command -v pkg-config >/dev/null || { echo 'package_kookie: pkg-config is required for presentation packaging' >&2; exit 2; }
  pkg-config --exists sdl3 sdl3-mixer || {
    echo 'package_kookie: SDL3 or SDL_mixer development files are required for presentation packaging' >&2
    exit 2
  }
fi
if [[ "$TARGET" == windows-x86_64 ]]; then
  [[ -n "${KOOKIE_WINDOWS_SDL_PREFIX:-}" &&
    -f "$KOOKIE_WINDOWS_SDL_PREFIX/include/SDL3/SDL.h" &&
    -f "$KOOKIE_WINDOWS_SDL_PREFIX/lib/libSDL3.dll.a" &&
    -f "$KOOKIE_WINDOWS_SDL_PREFIX/bin/SDL3.dll" ]] || {
    echo 'package_kookie: Windows packaging requires KOOKIE_WINDOWS_SDL_PREFIX containing the SDL3 MinGW package' >&2
    exit 2
  }
  [[ -n "${KOOKIE_WINDOWS_SDL_MIXER_PREFIX:-}" &&
    -f "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/include/SDL3_mixer/SDL_mixer.h" &&
    -f "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/lib/libSDL3_mixer.dll.a" &&
    -f "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/bin/SDL3_mixer.dll" ]] || {
    echo 'package_kookie: Windows packaging requires KOOKIE_WINDOWS_SDL_MIXER_PREFIX containing the SDL_mixer MinGW package' >&2
    exit 2
  }
  command -v zip >/dev/null || { echo 'package_kookie: zip is required for Windows packaging' >&2; exit 2; }
  command -v zig >/dev/null || { echo 'package_kookie: zig is required for Windows packaging' >&2; exit 2; }
fi
SOURCE_TREE_STATE=clean
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)" ]]; then
  if [[ "${KOOKIE_ALLOW_DIRTY_PACKAGE:-0}" != 1 ]]; then
    echo 'package_kookie: source tree is dirty; commit or set KOOKIE_ALLOW_DIRTY_PACKAGE=1 for a non-release smoke package' >&2
    exit 2
  fi
  SOURCE_TREE_STATE=dirty-allowed
fi

if [[ -e "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
  echo 'package_kookie: output path exists and is not a directory' >&2
  exit 2
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
case "$OUTPUT_DIR" in
  /|"$ROOT_DIR") echo 'package_kookie: refusing unsafe output directory' >&2; exit 2 ;;
esac

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-package.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

PACKAGE_NAME="kookie-$VERSION-$TARGET"
PACKAGE_ROOT="$WORK_DIR/$PACKAGE_NAME"
ARCHIVE="$OUTPUT_DIR/$PACKAGE_NAME.$([[ "$TARGET" == windows-x86_64 ]] && echo zip || echo tar.gz)"
mkdir -p "$PACKAGE_ROOT"
PUBLIC_KEY_WORK="$WORK_DIR/RELEASE_PUBLIC_KEY.pem"
PUBLIC_KEY_DER="$WORK_DIR/release-public-key.der"
openssl pkey -in "$SIGNING_KEY" -pubout -out "$PUBLIC_KEY_WORK" 2>/dev/null
openssl pkey -in "$SIGNING_KEY" -pubout -outform DER \
  -out "$PUBLIC_KEY_DER" 2>/dev/null
PUBLIC_KEY_SHA256="$(sha256sum "$PUBLIC_KEY_DER" | cut -d ' ' -f 1)"
cp -- "$PUBLIC_KEY_WORK" "$PACKAGE_ROOT/RELEASE_PUBLIC_KEY.pem"

bundle_linux_native() {
  local binary="$1"
  local presentation_package="$2"
  shift 2
  cp -- "$binary" "$PACKAGE_ROOT/kookie.bin"
  chmod 755 "$PACKAGE_ROOT/kookie.bin"
  if [[ "$presentation_package" == 1 ]]; then
    mkdir "$PACKAGE_ROOT/lib"
    local found_sdl=0
    local found_mixer=0
    for dependency in "$binary" "$@"; do
      while IFS= read -r library; do
        case "$(basename "$library")" in
          libSDL3_mixer.so*)
            cp -L -- "$library" "$PACKAGE_ROOT/lib/$(basename "$library")"
            found_mixer=1
            ;;
          libSDL3.so*)
            cp -L -- "$library" "$PACKAGE_ROOT/lib/$(basename "$library")"
            found_sdl=1
            ;;
          ld-linux-x86-64.so*|libc.so*|libm.so*|libdl.so*|libpthread.so*|librt.so*|libgcc_s.so*|libz.so*)
            ;;
          *)
            echo "package_kookie: unreviewed Linux runtime dependency: $(basename "$library")" >&2
            exit 1
            ;;
        esac
      done < <(ldd "$dependency" | sed -n -E 's/.*=> (\/[^ ]+) .*/\1/p')
    done
    [[ "$found_sdl" == 1 && "$found_mixer" == 1 ]] || {
      echo 'package_kookie: SDL3 and SDL_mixer runtime libraries must resolve' >&2
      exit 1
    }
    cat > "$PACKAGE_ROOT/kookie" <<'EOF'
#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export LD_LIBRARY_PATH="$root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [ "${1:-}" = "--package-smoke" ]; then
  exec "$root/kookie-smoke.bin"
fi
exec "$root/kookie.bin" "$@"
EOF
  else
    cat > "$PACKAGE_ROOT/kookie" <<'EOF'
#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$root/kookie.bin" "$@"
EOF
  fi
  chmod 755 "$PACKAGE_ROOT/kookie"
}

bundle_linux_server() {
  local server_root="$WORK_DIR/server-source"
  local server_build="$WORK_DIR/server-build"
  mkdir -p "$server_root"/{core,content,session,lib} "$PACKAGE_ROOT/lib"
  cp -- "$ROOT_DIR/apps/server/main.kf" "$server_root/main.kf"
  for module in core content session; do
    for source in "$ROOT_DIR/src/$module/"*.kf; do
      ln -s -- "$source" "$server_root/$module/$(basename "$source")"
    done
  done
  cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared \
    "$ROOT_DIR/native/kookie_transport.c" \
    -o "$server_root/lib/libkookie_headless_adapter.so"
  cc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared \
    "$ROOT_DIR/native/kookie_persistence_adapter.c" \
    -o "$server_root/lib/libkookie_persistence_adapter.so"
  (cd "$server_root" && kof build main.kf --target native \
    --output "$server_build" >/dev/null)
  local server_binary="$server_build/Default/Main"
  test -x "$server_binary" || {
    echo "package_kookie: dedicated server executable missing: $server_binary" >&2
    exit 1
  }
  cp -- "$server_binary" "$PACKAGE_ROOT/kookie-server.bin"
  chmod 755 "$PACKAGE_ROOT/kookie-server.bin"
  cp -- "$server_root/lib/libkookie_headless_adapter.so" \
    "$PACKAGE_ROOT/lib/libkookie_headless_adapter.so"
  cp -- "$server_root/lib/libkookie_persistence_adapter.so" \
    "$PACKAGE_ROOT/lib/libkookie_persistence_adapter.so"
  cat > "$PACKAGE_ROOT/kookie-server" <<'EOF'
#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$#" -ne 0 ]; then
  echo "Usage: kookie-server" >&2
  exit 2
fi
cd "$root"
exec ./kookie-server.bin
EOF
  chmod 755 "$PACKAGE_ROOT/kookie-server"
}

bundle_linux_cooker() {
  local cooker_root="$WORK_DIR/cooker-source"
  local cooker_build="$WORK_DIR/cooker-build"
  mkdir -p "$cooker_root"/{core,content}
  cp -- "$ROOT_DIR/apps/creator_cooker/main.kf" "$cooker_root/main.kf"
  for module in core content; do
    for source in "$ROOT_DIR/src/$module/"*.kf; do
      ln -s -- "$source" "$cooker_root/$module/$(basename "$source")"
    done
  done
  (cd "$cooker_root" && kof build main.kf --target native \
    --output "$cooker_build" >/dev/null)
  local cooker_binary="$cooker_build/Default/Main"
  test -x "$cooker_binary" || {
    echo "package_kookie: content cooker executable missing: $cooker_binary" >&2
    exit 1
  }
  cp -- "$cooker_binary" "$PACKAGE_ROOT/kookie-cooker.bin"
  chmod 755 "$PACKAGE_ROOT/kookie-cooker.bin"
  cat > "$PACKAGE_ROOT/kookie-cooker" <<'EOF'
#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
usage() {
  echo "Usage: kookie-cooker cook <glb|aseprite|vox|map|blockbench|png|wav> <input> <output>" >&2
  echo "       kookie-cooker cook dust3d <input.ds3> <export.glb> <output>" >&2
  exit 2
}
[ "${1:-}" = "cook" ] || usage
kind="${2:-}"
case "$kind" in
  glb) code=1 ;;
  dust3d) code=2 ;;
  aseprite) code=3 ;;
  vox) code=4 ;;
  map) code=5 ;;
  blockbench) code=6 ;;
  png) code=7 ;;
  wav) code=8 ;;
  *) usage ;;
esac
if [ "$kind" = "dust3d" ]; then
  [ "$#" -eq 5 ] || usage
  input=$3
  paired=$4
  output=$5
else
  [ "$#" -eq 4 ] || usage
  input=$3
  paired=
  output=$4
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/kookie-cooker.XXXXXX")
output_tmp=
cleanup() {
  rm -rf -- "$work"
  if [ -n "$output_tmp" ]; then rm -f -- "$output_tmp"; fi
}
trap cleanup EXIT INT TERM
cp -- "$input" "$work/source.input"
if [ -n "$paired" ]; then cp -- "$paired" "$work/paired.input"; fi
printf '%s' "$code" >"$work/.kookie-cooker-native-kind"
(cd "$work" && "$root/kookie-cooker.bin")
[ -s "$work/product.output" ] || {
  echo "kookie-cooker: native worker produced no output" >&2
  exit 1
}
output_dir=$(dirname -- "$output")
output_base=$(basename -- "$output")
output_tmp=$(mktemp "$output_dir/.${output_base}.tmp.XXXXXX")
cp -- "$work/product.output" "$output_tmp"
mv -f -- "$output_tmp" "$output"
output_tmp=
EOF
  chmod 755 "$PACKAGE_ROOT/kookie-cooker"
}

bundle_linux_simd_benchmark() {
  local benchmark_root="$WORK_DIR/simd-benchmark-source"
  local benchmark_build="$WORK_DIR/simd-benchmark-build"
  mkdir -p "$benchmark_root/lib"
  cp -- "$ROOT_DIR/apps/simd_benchmark/main.kf" "$benchmark_root/main.kf"
  cc -std=c11 -Wall -Wextra -Werror -O3 -fPIC -shared \
    -I"$ROOT_DIR/native" "$ROOT_DIR/native/kookie_simd_dispatch.c" \
    -o "$benchmark_root/lib/libkookie_simd_dispatch.so"
  cp -- "$PACKAGE_ROOT/lib/libkookie_headless_adapter.so" \
    "$benchmark_root/lib/libkookie_headless_adapter.so"
  (cd "$benchmark_root" && kof build main.kf --target native \
    --output "$benchmark_build" >/dev/null)
  local benchmark_binary="$benchmark_build/Default/Main"
  test -x "$benchmark_binary" || {
    echo "package_kookie: SIMD benchmark executable missing: $benchmark_binary" >&2
    exit 1
  }
  cp -- "$benchmark_binary" "$PACKAGE_ROOT/kookie-simd-bench.bin"
  cp -- "$benchmark_root/lib/libkookie_simd_dispatch.so" \
    "$PACKAGE_ROOT/lib/libkookie_simd_dispatch.so"
  chmod 755 "$PACKAGE_ROOT/kookie-simd-bench.bin"
  cat > "$PACKAGE_ROOT/kookie-simd-bench" <<'EOF'
#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$#" -ne 0 ]; then
  echo "Usage: kookie-simd-bench" >&2
  exit 2
fi
cd "$root"
exec ./kookie-simd-bench.bin
EOF
  chmod 755 "$PACKAGE_ROOT/kookie-simd-bench"
}

if [[ "$TARGET" == windows-x86_64 ]]; then
  zig cc -target x86_64-windows-gnu -std=c11 \
    -Wall -Wextra -Werror -O2 -s -Wl,/subsystem:windows \
    -I "$KOOKIE_WINDOWS_SDL_PREFIX/include" \
    -I "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/include" \
    "$ROOT_DIR/scripts/kookie_windows_shell.c" \
    "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/lib/libSDL3_mixer.dll.a" \
    "$KOOKIE_WINDOWS_SDL_PREFIX/lib/libSDL3.dll.a" \
    -lws2_32 -o "$PACKAGE_ROOT/kookie.exe"
  cp -- "$KOOKIE_WINDOWS_SDL_PREFIX/bin/SDL3.dll" "$PACKAGE_ROOT/SDL3.dll"
  cp -- "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/bin/SDL3_mixer.dll" \
    "$PACKAGE_ROOT/SDL3_mixer.dll"
  cat > "$PACKAGE_ROOT/kookie.cmd" <<'EOF'
@echo off
setlocal
set "ROOT=%~dp0"
"%ROOT%kookie.exe" %*
exit /b %ERRORLEVEL%
EOF
elif [[ "$RUNTIME" == native ]]; then
  kof build "$ROOT_DIR/src" --target native --output "$WORK_DIR/build" >/dev/null
  BINARY="$WORK_DIR/build/Default/Main"
  test -x "$BINARY" || { echo "package_kookie: native executable missing: $BINARY" >&2; exit 1; }
  bundle_linux_native "$BINARY" 0
else
  PRESENTATION_ROOT="$WORK_DIR/presentation"
  mkdir -p "$PRESENTATION_ROOT"/{core,content,session,world,ui,demo} "$PACKAGE_ROOT/build"
  cp -- "$ROOT_DIR/probes/g0_native_presentation/main.kf" "$PRESENTATION_ROOT/main.kf"
  for module in core content session world ui demo; do
    for source in "$ROOT_DIR/src/$module/"*.kf; do
      ln -s -- "$source" "$PRESENTATION_ROOT/$module/$(basename "$source")"
    done
  done
  IFS=' ' read -r -a SDL_FLAGS <<<"$(pkg-config --cflags --libs sdl3 sdl3-mixer)"
  cc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
    "$ROOT_DIR/native/kookie_sdl_adapter.c" \
    "$ROOT_DIR/native/kookie_transport.c" \
    -o "$PACKAGE_ROOT/build/libkookie_sdl_adapter.so" \
    "${SDL_FLAGS[@]}"
  glslc -fshader-stage=vert "$ROOT_DIR/native/shaders/g0_triangle.vert" \
    -o "$PACKAGE_ROOT/build/g0_triangle.vert.spv"
  glslc -fshader-stage=vert \
    "$ROOT_DIR/native/shaders/g5_triangle_instance.vert" \
    -o "$PACKAGE_ROOT/build/g5_triangle_instance.vert.spv"
  glslc -fshader-stage=frag "$ROOT_DIR/native/shaders/g0_triangle.frag" \
    -o "$PACKAGE_ROOT/build/g0_triangle.frag.spv"
  (cd "$PACKAGE_ROOT" && kof build "$PRESENTATION_ROOT/main.kf" --target native --output "$WORK_DIR/build" >/dev/null)
  BINARY="$WORK_DIR/build/Default/Main"
  test -x "$BINARY" || { echo "package_kookie: presentation executable missing: $BINARY" >&2; exit 1; }
  bundle_linux_native "$BINARY" 1 "$PACKAGE_ROOT/build/libkookie_sdl_adapter.so"
  kof build "$ROOT_DIR/src" --target native \
    --output "$WORK_DIR/smoke-build" >/dev/null
  SMOKE_BINARY="$WORK_DIR/smoke-build/Default/Main"
  test -x "$SMOKE_BINARY" || {
    echo "package_kookie: presentation smoke executable missing: $SMOKE_BINARY" >&2
    exit 1
  }
  cp -- "$SMOKE_BINARY" "$PACKAGE_ROOT/kookie-smoke.bin"
  chmod 755 "$PACKAGE_ROOT/kookie-smoke.bin"
fi
if [[ "$TARGET" == linux-x86_64 ]]; then
  bundle_linux_server
  bundle_linux_cooker
  bundle_linux_simd_benchmark
fi
cp -- "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.md"
if [[ "$TARGET" == windows-x86_64 ]]; then
  cp -- "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.txt"
fi
cp -- "$ROOT_DIR/LICENSE" "$PACKAGE_ROOT/LICENSE"
cp -- "$ROOT_DIR/THIRD_PARTY_NOTICES.txt" "$PACKAGE_ROOT/THIRD_PARTY_NOTICES.txt"
SOURCE_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
KOF_TOOLCHAIN_VERSION="$ACTUAL_KOF_VERSION"
cat > "$PACKAGE_ROOT/PROVENANCE.txt" <<EOF
application=kookie
channel=dogfood
target=$TARGET
runtime=$RUNTIME
native_linux_launcher=$([[ "$TARGET" == linux-x86_64 ]] && echo system-loader || echo direct)
version=$VERSION
build_id=$BUILD_ID
source_commit=$SOURCE_COMMIT
source_tree_state=$SOURCE_TREE_STATE
kof_version=$KOF_TOOLCHAIN_VERSION
kof_archive_sha256=$KOF_ARCHIVE_SHA256
kof_source_commit=$KOF_SOURCE_COMMIT
kof_compiler_sha256=$KOF_COMPILER_SHA256
release_signing=ed25519
release_public_key_sha256=$PUBLIC_KEY_SHA256
license_status=MIT
windows_status=$([[ "$TARGET" == windows-x86_64 ]] && echo native-sdl-shell || echo not-applicable)
dependency_policy=permissive-distributed-only
sdl_version=$([[ "$RUNTIME" == presentation || "$TARGET" == windows-x86_64 ]] && echo 3.4.16 || echo not-bundled)
sdl_mixer_version=$([[ "$RUNTIME" == presentation || "$TARGET" == windows-x86_64 ]] && echo 3.2.4 || echo not-bundled)
runtime_dependencies=$([[ "$RUNTIME" == presentation || "$TARGET" == windows-x86_64 ]] && echo SDL3+SDL_mixer || echo system-only)
dedicated_server=$([[ "$TARGET" == linux-x86_64 ]] && echo bounded-headless-workload-with-runtime-telemetry || echo unavailable)
simd_benchmark=$([[ "$TARGET" == linux-x86_64 ]] && echo kof-buffer-u8-runtime-dispatch || echo unavailable)
content_cooker=$([[ "$TARGET" == linux-x86_64 ]] && echo native-bounded-intake-cli || echo unavailable)
crash_durable_save=staged-validated-fsync-rename-directory-fsync
replay_admission=identity-bound-checksummed-v3
EOF
MANIFEST="$OUTPUT_DIR/$PACKAGE_NAME.json"
PUBLIC_KEY="$OUTPUT_DIR/$PACKAGE_NAME.pub.pem"
ARCHIVE_SIGNATURE="$ARCHIVE.sig"
MANIFEST_SIGNATURE="$MANIFEST.sig"
CHECKSUMS="$OUTPUT_DIR/SHA256SUMS"
CHECKSUMS_SIGNATURE="$OUTPUT_DIR/SHA256SUMS.sig"
rm -f -- "$ARCHIVE" "$MANIFEST" "$PUBLIC_KEY" "$ARCHIVE_SIGNATURE" \
  "$MANIFEST_SIGNATURE" "$CHECKSUMS" "$CHECKSUMS_SIGNATURE"
if [[ "$TARGET" == windows-x86_64 ]]; then
  (cd "$WORK_DIR" && zip -qr "$ARCHIVE" "$PACKAGE_NAME")
else
  tar -C "$WORK_DIR" -czf "$ARCHIVE" "$PACKAGE_NAME"
fi
cp -- "$PUBLIC_KEY_WORK" "$PUBLIC_KEY"
python3 - "$ARCHIVE" "$MANIFEST" "$TARGET" "$VERSION" "$BUILD_ID" \
  "$BASE_URL" "$PROVENANCE_SCHEMA" "$RUNTIME" "$SOURCE_COMMIT" \
  "$SOURCE_TREE_STATE" "$KOF_TOOLCHAIN_VERSION" "$KOF_ARCHIVE_SHA256" \
  "$KOF_SOURCE_COMMIT" "$KOF_COMPILER_SHA256" \
  "$PUBLIC_KEY_SHA256" "$(basename "$PUBLIC_KEY")" <<'PY'
import hashlib, json, pathlib, sys
archive = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
(target, version, build_id, base_url, schema, runtime, source_commit,
 source_tree_state, kof_version, kof_archive_sha256, kof_source_commit,
 kof_compiler_sha256, public_key_sha256, public_key_name) = sys.argv[3:17]
encoded = base_url.rstrip("/")
manifest = {
    "schema": schema,
    "application": "kookie",
    "channel": "dogfood",
    "version": version,
    "target": target,
    "runtime": runtime,
    "build_id": build_id,
    "source_commit": source_commit,
    "source_tree_state": source_tree_state,
    "kof_version": kof_version,
    "kof_archive_sha256": kof_archive_sha256,
    "kof_source_commit": kof_source_commit,
    "kof_compiler_sha256": kof_compiler_sha256,
    "archive": archive.name,
    "size": archive.stat().st_size,
    "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    "dedicated_server": target == "linux-x86_64",
    "simd_benchmark": target == "linux-x86_64",
    "content_cooker": target == "linux-x86_64",
    "signing": "ed25519",
    "proof": "ed25519-signature-set",
    "signature_encoding": "binary",
    "public_key": public_key_name,
    "public_key_sha256": public_key_sha256,
    "archive_signature": archive.name + ".sig",
    "manifest_signature": manifest_path.name + ".sig",
    "checksums": "SHA256SUMS",
    "checksums_signature": "SHA256SUMS.sig",
    "url": f"{encoded}/{archive.name}",
    "manifest_url": f"{encoded}/{manifest_path.name}",
}
manifest_path.write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8")
PY
openssl pkeyutl -sign -rawin -inkey "$SIGNING_KEY" \
  -in "$ARCHIVE" -out "$ARCHIVE_SIGNATURE"
openssl pkeyutl -sign -rawin -inkey "$SIGNING_KEY" \
  -in "$MANIFEST" -out "$MANIFEST_SIGNATURE"
(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$ARCHIVE")" "$(basename "$MANIFEST")" \
    "$(basename "$PUBLIC_KEY")" "$(basename "$ARCHIVE_SIGNATURE")" \
    "$(basename "$MANIFEST_SIGNATURE")" > SHA256SUMS
)
openssl pkeyutl -sign -rawin -inkey "$SIGNING_KEY" \
  -in "$CHECKSUMS" -out "$CHECKSUMS_SIGNATURE"
for signed_file in "$ARCHIVE" "$MANIFEST" "$CHECKSUMS"; do
  signature="$signed_file.sig"
  openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
    -in "$signed_file" -sigfile "$signature" >/dev/null
done

printf 'package_kookie: wrote signed %s, %s, %s, and signature set\n' \
  "$ARCHIVE" "$CHECKSUMS" "$MANIFEST"
