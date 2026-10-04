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
CONTENT_PROFILE="${KOOKIE_CONTENT_PROFILE:-none}"
PROVENANCE_SCHEMA="${KOOKIE_PACKAGE_PROVENANCE_SCHEMA:-kookie.package-provenance/v2}"
SIGNING_KEY="${KOOKIE_SIGNING_KEY:-}"
KOF_ARCHIVE_SHA256="${KOOKIE_KOF_ARCHIVE_SHA256:-}"
KOF_SOURCE_COMMIT="${KOOKIE_KOF_SOURCE_COMMIT:-}"
EXPECTED_KOF_VERSION="${KOOKIE_EXPECTED_KOF_VERSION:-kof 0.5.0-beta}"
EXPECTED_KOF_SOURCE_COMMIT="${KOOKIE_EXPECTED_KOF_SOURCE_COMMIT:-bf17ac7e736471c8a04b4153e5b0f607be75e70c}"
WINDOWS_JAVA_ARCHIVE="${KOOKIE_WINDOWS_JAVA_ARCHIVE:-}"
WINDOWS_JAVA_ARCHIVE_SHA256="${KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256:-}"
WINDOWS_JAVA_VERSION="not-bundled"
WINDOWS_JAVA_VENDOR="not-bundled"
WINDOWS_JAVA_ACTUAL_SHA256="not-bundled"
KOOKIE_DXC="${KOOKIE_DXC:-}"
WINDOWS_DXC_VERSION="not-bundled"

usage() {
  cat <<'EOF'
Usage: scripts/package_kookie.sh [--runtime native|presentation|jvm] [--target linux-x86_64|windows-x86_64] [--content none|prototype]

Builds a signed immutable KOOKIE archive, provenance manifest, public key,
signature set, and SHA256SUMS.
Native Linux packages contain the Kof executable and use the host's system
runtime. Presentation packages contain the persistent native Kof SDL_GPU
application, SDL3, SDL_mixer, the adapter, and shaders.
Every Linux package also contains a graphics-free Kof dedicated workload server,
a native bounded content kooker, and a Kof `Buffer(U8)` SIMD benchmark with
native timing.
Windows native packages contain the native Kof PE gameplay linked to the SDL3/
SDL_mixer shell.
Windows JVM packages contain canonical Kof JVM classes and the exact
SHA-256-pinned OpenJDK runtime supplied through KOOKIE_WINDOWS_JAVA_ARCHIVE.
Windows presentation packages contain native Kof PE gameplay, SDL3, SDL_mixer,
the native adapter, and SPIR-V/DXIL shader binaries.
Set `KOOKIE_KOF_ARCHIVE_SHA256` and `KOOKIE_KOF_SOURCE_COMMIT` to the
verified distribution used for the build.
EOF
}

while (($#)); do
  case "$1" in
    --runtime) RUNTIME="${2:?missing runtime}"; shift 2 ;;
    --target) TARGET="${2:?missing target}"; shift 2 ;;
    --content|--content-profile) CONTENT_PROFILE="${2:?missing content profile}"; shift 2 ;;
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --build-id) BUILD_ID="${2:?missing build id}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?missing output directory}"; shift 2 ;;
    --signing-key) SIGNING_KEY="${2:?missing signing key}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "package_kookie: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$RUNTIME" in
  native|presentation|jvm) ;;
  *) echo "package_kookie: unsupported distributable runtime: $RUNTIME" >&2; exit 2 ;;
esac

case "$CONTENT_PROFILE" in
  none|prototype) ;;
  *) echo "package_kookie: unsupported content profile: $CONTENT_PROFILE" >&2; exit 2 ;;
esac

case "$TARGET" in
  linux-x86_64)
    if [[ "$RUNTIME" == jvm ]]; then
      echo 'package_kookie: JVM distribution is supported only for windows-x86_64' >&2
      exit 2
    fi
    ;;
  windows-x86_64)
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
command -v python3 >/dev/null || { echo 'package_kookie: python3 is required' >&2; exit 2; }
ACTUAL_KOF_VERSION="$(kof version 2>/dev/null)" || {
  echo 'package_kookie: unable to read the Kof toolchain version' >&2
  exit 2
}
[[ "$ACTUAL_KOF_VERSION" == "$EXPECTED_KOF_VERSION" ]] || {
  printf 'package_kookie: expected %s; found %s\n' \
    "$EXPECTED_KOF_VERSION" "$ACTUAL_KOF_VERSION" >&2
  exit 2
}
if [[ ! "$KOF_ARCHIVE_SHA256" =~ ^[0-9a-fA-F]{64}$ ||
      "$KOF_ARCHIVE_SHA256" =~ ^0{64}$ ]]; then
  echo 'package_kookie: KOOKIE_KOF_ARCHIVE_SHA256 must identify a nonzero verified Kof distribution' >&2
  exit 2
fi
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
if [[ "$TARGET" == windows-x86_64 &&
      ( "$RUNTIME" == native || "$RUNTIME" == presentation ) ]]; then
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
  command -v zig >/dev/null || { echo 'package_kookie: zig is required for Windows packaging' >&2; exit 2; }
fi
if [[ "$TARGET" == windows-x86_64 && "$RUNTIME" == jvm ]]; then
  command -v java >/dev/null || {
    echo 'package_kookie: host java is required to smoke the Windows JVM artifact' >&2
    exit 2
  }
  [[ -n "$WINDOWS_JAVA_ARCHIVE" && -f "$WINDOWS_JAVA_ARCHIVE" &&
    ! -L "$WINDOWS_JAVA_ARCHIVE" ]] || {
    echo 'package_kookie: KOOKIE_WINDOWS_JAVA_ARCHIVE must name a regular OpenJDK Windows ZIP' >&2
    exit 2
  }
  [[ "$WINDOWS_JAVA_ARCHIVE_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || {
    echo 'package_kookie: KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256 must be a SHA-256 digest' >&2
    exit 2
  }
  WINDOWS_JAVA_ACTUAL_SHA256="$(sha256sum "$WINDOWS_JAVA_ARCHIVE" | cut -d ' ' -f 1)"
  [[ "${WINDOWS_JAVA_ACTUAL_SHA256,,}" == "${WINDOWS_JAVA_ARCHIVE_SHA256,,}" ]] || {
    echo 'package_kookie: Windows Java archive SHA-256 mismatch' >&2
    exit 2
  }
fi
if [[ "$TARGET" == windows-x86_64 && "$RUNTIME" == presentation ]]; then
  if [[ -z "$KOOKIE_DXC" ]]; then
    KOOKIE_DXC="$(command -v dxc || true)"
  fi
  [[ -n "$KOOKIE_DXC" && -x "$KOOKIE_DXC" ]] || {
    echo 'package_kookie: Windows presentation packaging requires KOOKIE_DXC pointing to dxc' >&2
    exit 2
  }
  WINDOWS_DXC_VERSION="$("$KOOKIE_DXC" --version 2>/dev/null | tr '\n' ' ' || true)"
  [[ -n "$WINDOWS_DXC_VERSION" ]] || WINDOWS_DXC_VERSION=unreported
  command -v glslc >/dev/null || {
    echo 'package_kookie: glslc is required for Windows presentation packaging' >&2
    exit 2
  }
fi
SOURCE_TREE_STATE=clean
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)" ]]; then
  if [[ "${KOOKIE_ALLOW_DIRTY_PACKAGE:-0}" != 1 ]]; then
    echo 'package_kookie: source tree is dirty; commit or set KOOKIE_ALLOW_DIRTY_PACKAGE=1 for a non-release smoke package' >&2
    exit 2
  fi
  SOURCE_TREE_STATE=dirty-allowed
fi
PACKAGE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT_DIR" show -s --format=%ct HEAD)}"
[[ "$PACKAGE_EPOCH" =~ ^[0-9]+$ ]] || {
  echo 'package_kookie: SOURCE_DATE_EPOCH must be a non-negative integer' >&2
  exit 2
}

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
PROTOTYPE_CONTENT_TREE_SHA256=not-included
PROTOTYPE_CONTENT_ASSET_COUNT=0
PROTOTYPE_CONTENT_FILE_COUNT=0

bundle_prototype_content() {
  [[ "$CONTENT_PROFILE" == prototype ]] || return 0
  local source_root="$ROOT_DIR/assets/prototype"
  local destination_root="$PACKAGE_ROOT/content/prototype"
  [[ -f "$source_root/manifest.json" ]] || {
    echo "package_kookie: prototype content manifest missing: $source_root/manifest.json" >&2
    exit 1
  }
  read -r PROTOTYPE_CONTENT_TREE_SHA256 \
    PROTOTYPE_CONTENT_ASSET_COUNT PROTOTYPE_CONTENT_FILE_COUNT < <(
    python3 - "$source_root" "$destination_root" <<'PY'
import hashlib
import json
import pathlib
import shutil
import sys

source = pathlib.Path(sys.argv[1]).resolve()
destination = pathlib.Path(sys.argv[2]).resolve()
manifest_path = source / "manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
if manifest.get("schema") != "kookie.prototype-content/v1":
    raise SystemExit("package_kookie: unsupported prototype content manifest schema")
assets = manifest.get("assets")
if not isinstance(assets, list) or not assets:
    raise SystemExit("package_kookie: prototype content manifest has no assets")
declared_paths = []
for asset in assets:
    if not isinstance(asset, dict) or not asset.get("id"):
        raise SystemExit("package_kookie: prototype content asset entry is malformed")
    for field in ("authored_path", "runtime_path", "cooked_path"):
        value = asset.get(field)
        if value is None:
            continue
        relative = pathlib.PurePosixPath(value)
        if relative.is_absolute() or ".." in relative.parts:
            raise SystemExit(f"package_kookie: unsafe prototype content path: {value}")
        declared_paths.append(value)
declared_paths = sorted(set(declared_paths))
for relative_name in declared_paths:
    path = source.joinpath(*pathlib.PurePosixPath(relative_name).parts)
    if not path.is_file() or path.is_symlink():
        raise SystemExit(f"package_kookie: declared prototype content file missing: {relative_name}")
excluded_paths = {pathlib.PurePosixPath("models/cat/source")}
def is_excluded(relative):
    return any(relative == excluded or excluded in relative.parents
               for excluded in excluded_paths)
for path in source.rglob("*"):
    if path.is_symlink() or (not path.is_file() and not path.is_dir()):
        raise SystemExit(f"package_kookie: prototype content contains unsafe entry: {path}")
if destination.exists():
    shutil.rmtree(destination)
for path in sorted(source.rglob("*")):
    relative = path.relative_to(source)
    if is_excluded(relative):
        continue
    target = destination / relative
    if path.is_dir():
        target.mkdir(parents=True, exist_ok=True)
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)

digest = hashlib.sha256()
file_count = 0
for path in sorted(destination.rglob("*")):
    if path.is_symlink() or (not path.is_file() and not path.is_dir()):
        raise SystemExit(f"package_kookie: copied prototype content contains unsafe entry: {path}")
    if path.is_file():
        relative = path.relative_to(destination).as_posix().encode("utf-8")
        digest.update(relative)
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        file_count += 1
print(digest.hexdigest(), len(assets), file_count, sep="\t")
PY
  )
}

bundle_prototype_content
bundle_audio_assets() {
  if [[ "$RUNTIME" != presentation &&
        ! ( "$TARGET" == windows-x86_64 && "$RUNTIME" == native ) ]]; then
    return 0
  fi
  local source_root="$ROOT_DIR/assets/audio/ui"
  local destination_root="$PACKAGE_ROOT/assets/audio/ui"
  [[ -d "$source_root" ]] || {
    echo "package_kookie: UI audio asset directory missing: $source_root" >&2
    exit 1
  }
  mkdir -p "$destination_root"
  local count=0
  for source in "$source_root"/*.ogg; do
    [[ -f "$source" ]] || continue
    cp -- "$source" "$destination_root/$(basename "$source")"
    count=$((count + 1))
  done
  [[ "$count" == 14 ]] || {
    echo "package_kookie: expected 14 UI audio assets, found $count" >&2
    exit 1
  }
}

bundle_audio_assets


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
cd "$root"
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
  cp -- "$ROOT_DIR/scripts/kookie_rendezvous.py" \
    "$PACKAGE_ROOT/kookie-rendezvous.py"
  chmod 755 "$PACKAGE_ROOT/kookie-rendezvous.py"
}

bundle_linux_kooker() {
  local kooker_root="$WORK_DIR/kooker-source"
  local kooker_build="$WORK_DIR/kooker-build"
  mkdir -p "$kooker_root"/{core,content}
  cp -- "$ROOT_DIR/apps/kooker/main.kf" "$kooker_root/main.kf"
  for module in core content; do
    for source in "$ROOT_DIR/src/$module/"*.kf; do
      ln -s -- "$source" "$kooker_root/$module/$(basename "$source")"
    done
  done
  (cd "$kooker_root" && kof build main.kf --target native \
    --output "$kooker_build" >/dev/null)
  local kooker_binary="$kooker_build/Default/Main"
  test -x "$kooker_binary" || {
    echo "package_kookie: content kooker executable missing: $kooker_binary" >&2
    exit 1
  }
  cp -- "$kooker_binary" "$PACKAGE_ROOT/kooker.bin"
  chmod 755 "$PACKAGE_ROOT/kooker.bin"
  cat > "$PACKAGE_ROOT/kooker" <<'EOF'
#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
usage() {
  echo "Usage: kooker cook <glb|aseprite|vox|map|blockbench|png|wav> <input> <output>" >&2
  echo "       kooker cook dust3d <input.ds3> <export.glb> <output>" >&2
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
work=$(mktemp -d "${TMPDIR:-/tmp}/kooker.XXXXXX")
output_tmp=
cleanup() {
  rm -rf -- "$work"
  if [ -n "$output_tmp" ]; then rm -f -- "$output_tmp"; fi
}
trap cleanup EXIT INT TERM
cp -- "$input" "$work/source.input"
if [ -n "$paired" ]; then cp -- "$paired" "$work/paired.input"; fi
printf '%s' "$code" >"$work/.kooker-native-kind"
(cd "$work" && "$root/kooker.bin")
[ -s "$work/product.output" ] || {
  echo "kooker: native worker produced no output" >&2
  exit 1
}
output_dir=$(dirname -- "$output")
output_base=$(basename -- "$output")
output_tmp=$(mktemp "$output_dir/.${output_base}.tmp.XXXXXX")
cp -- "$work/product.output" "$output_tmp"
mv -f -- "$output_tmp" "$output"
output_tmp=
EOF
  chmod 755 "$PACKAGE_ROOT/kooker"
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
bundle_windows_native_shell() {
  local pe_build="$WORK_DIR/kof-pe-shell"
  KOOKIE_KOF_SOURCE_COMMIT="$KOF_SOURCE_COMMIT" \
    "$ROOT_DIR/scripts/kof_pe_build.sh" "$ROOT_DIR/src" \
    --output "$pe_build" --library >/dev/null
  zig cc -target x86_64-windows-gnu -std=c11 \
    -Wall -Wextra -Werror -O2 -s -fno-ident \
    -Wl,/subsystem:console -Wl,/Brepro \
    -I "$KOOKIE_WINDOWS_SDL_PREFIX/include" \
    -I "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/include" \
    "$ROOT_DIR/scripts/kookie_windows_shell.c" \
    "$pe_build/kof-module.obj" \
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
}

bundle_windows_native_presentation() {
  local presentation_root="$WORK_DIR/presentation-source"
  local pe_build="$WORK_DIR/kof-pe-presentation"
  local adapter_obj="$WORK_DIR/kookie-sdl-adapter.obj"
  local transport_obj="$WORK_DIR/kookie-transport.obj"
  mkdir -p "$presentation_root"/{core,content,session,world,ui,demo} "$PACKAGE_ROOT/build"
  cp -- "$ROOT_DIR/probes/g0_native_presentation/main.kf" \
    "$presentation_root/main.kf"
  for module in core content session world ui demo; do
    for source in "$ROOT_DIR/src/$module/"*.kf; do
      ln -s -- "$source" "$presentation_root/$module/$(basename "$source")"
    done
  done
  KOOKIE_KOF_SOURCE_COMMIT="$KOF_SOURCE_COMMIT" \
    "$ROOT_DIR/scripts/kof_pe_build.sh" "$presentation_root" \
    --output "$pe_build" --library >/dev/null
  zig cc -target x86_64-windows-gnu -std=c11 \
    -Wall -Wextra -Werror -O2 -fno-ident \
    -I "$KOOKIE_WINDOWS_SDL_PREFIX/include" \
    -I "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/include" \
    -I "$ROOT_DIR/native" \
    -c "$ROOT_DIR/native/kookie_sdl_adapter.c" -o "$adapter_obj"
  zig cc -target x86_64-windows-gnu -std=c11 \
    -Wall -Wextra -Werror -O2 -fno-ident \
    -I "$ROOT_DIR/native" \
    -c "$ROOT_DIR/native/kookie_transport.c" -o "$transport_obj"
  zig cc -target x86_64-windows-gnu -s -fno-ident \
    -Wl,/subsystem:console -Wl,/Brepro \
    "$ROOT_DIR/native/kookie_pe_entry.c" \
    "$pe_build/kof-module.obj" "$adapter_obj" "$transport_obj" \
    "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/lib/libSDL3_mixer.dll.a" \
    "$KOOKIE_WINDOWS_SDL_PREFIX/lib/libSDL3.dll.a" \
    -lws2_32 -lpsapi -o "$PACKAGE_ROOT/kookie.exe"
  cp -- "$PACKAGE_ROOT/kookie.exe" "$PACKAGE_ROOT/kookie-visual.exe"
  cp -- "$KOOKIE_WINDOWS_SDL_PREFIX/bin/SDL3.dll" "$PACKAGE_ROOT/SDL3.dll"
  cp -- "$KOOKIE_WINDOWS_SDL_MIXER_PREFIX/bin/SDL3_mixer.dll" \
    "$PACKAGE_ROOT/SDL3_mixer.dll"
  cp -- "$PACKAGE_ROOT/SDL3.dll" "$PACKAGE_ROOT/build/SDL3.dll"
  cp -- "$PACKAGE_ROOT/SDL3_mixer.dll" "$PACKAGE_ROOT/build/SDL3_mixer.dll"
  glslc -fshader-stage=vert \
    "$ROOT_DIR/native/shaders/g0_triangle.vert" \
    -o "$PACKAGE_ROOT/build/g0_triangle.vert.spv"
  glslc -fshader-stage=vert \
    "$ROOT_DIR/native/shaders/g5_triangle_instance.vert" \
    -o "$PACKAGE_ROOT/build/g5_triangle_instance.vert.spv"
  glslc -fshader-stage=vert \
    "$ROOT_DIR/native/shaders/g6_world.vert" \
    -o "$PACKAGE_ROOT/build/g6_world.vert.spv"
  glslc -fshader-stage=frag \
    "$ROOT_DIR/native/shaders/g0_triangle.frag" \
    -o "$PACKAGE_ROOT/build/g0_triangle.frag.spv"
  "$KOOKIE_DXC" -T vs_6_0 -E main \
    -Fo "$PACKAGE_ROOT/build/g0_triangle.vert.dxil" \
    "$ROOT_DIR/native/shaders/g0_triangle.vert.hlsl"
  "$KOOKIE_DXC" -T vs_6_0 -E main \
    -Fo "$PACKAGE_ROOT/build/g5_triangle_instance.vert.dxil" \
    "$ROOT_DIR/native/shaders/g5_triangle_instance.vert.hlsl"
  "$KOOKIE_DXC" -T vs_6_0 -E main \
    -Fo "$PACKAGE_ROOT/build/g6_world.vert.dxil" \
    "$ROOT_DIR/native/shaders/g6_world.vert.hlsl"
  "$KOOKIE_DXC" -T ps_6_0 -E main \
    -Fo "$PACKAGE_ROOT/build/g0_triangle.frag.dxil" \
    "$ROOT_DIR/native/shaders/g0_triangle.frag.hlsl"
  cat > "$PACKAGE_ROOT/kookie.cmd" <<'EOF'
@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"
"%ROOT%kookie.exe" %*
exit /b %ERRORLEVEL%
EOF
}

bundle_windows_jvm() {
  local extract_root="$WORK_DIR/windows-java"
  local jvm_build="$WORK_DIR/jvm-build"
  local runtime_root
  mkdir -p "$extract_root" "$jvm_build"
  python3 - "$WINDOWS_JAVA_ARCHIVE" "$extract_root" <<'PY'
import pathlib
import shutil
import stat
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2]).resolve()
with zipfile.ZipFile(archive) as source:
    entries = source.infolist()
    if len(entries) > 100_000:
        raise SystemExit("package_kookie: Windows Java archive has too many entries")
    if sum(entry.file_size for entry in entries) > 1_073_741_824:
        raise SystemExit("package_kookie: Windows Java archive exceeds the 1 GiB extraction limit")
    for entry in entries:
        name = entry.filename.replace("\\", "/")
        relative = pathlib.PurePosixPath(name)
        mode = entry.external_attr >> 16
        if (not name or relative.is_absolute() or ".." in relative.parts
                or stat.S_ISLNK(mode)
                or (mode and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)))):
            raise SystemExit(f"package_kookie: unsafe Windows Java archive entry: {entry.filename!r}")
        target = destination.joinpath(*relative.parts)
        if entry.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with source.open(entry) as incoming, target.open("wb") as outgoing:
            shutil.copyfileobj(incoming, outgoing)
PY
  mapfile -t java_roots < <(python3 - "$extract_root" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
candidates = sorted({
    executable.parent.parent.resolve()
    for executable in root.rglob("java.exe")
    if executable.parent.name.lower() == "bin"
       and (executable.parent.parent / "release").is_file()
})
for candidate in candidates:
    print(candidate)
PY
)
  [[ "${#java_roots[@]}" == 1 ]] || {
    echo 'package_kookie: Windows Java archive must contain exactly one runtime root with bin/java.exe and release' >&2
    exit 1
  }
  runtime_root="${java_roots[0]}"
  python3 - "$runtime_root" <<'PY' > "$WORK_DIR/windows-java-metadata"
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
java = root / "bin" / "java.exe"
if java.read_bytes()[:2] != b"MZ":
    raise SystemExit("package_kookie: bundled bin/java.exe is not a Windows PE executable")
legal = root / "legal"
if not legal.is_dir() or not any(path.is_file() for path in legal.rglob("*")):
    raise SystemExit("package_kookie: Windows Java runtime must retain its legal directory")
values = {}
for line in (root / "release").read_text(encoding="utf-8").splitlines():
    if "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key] = value.strip().strip('"')
os_name = values.get("OS_NAME", "")
os_arch = values.get("OS_ARCH", "")
if "windows" not in os_name.lower():
    raise SystemExit("package_kookie: Java runtime release metadata is not Windows")
if os_arch.lower() not in {"amd64", "x86_64"}:
    raise SystemExit("package_kookie: Java runtime release metadata is not x86_64")
for key in ("JAVA_VERSION", "IMPLEMENTOR"):
    value = values.get(key, "")
    if not value or "\n" in value or "\r" in value:
        raise SystemExit(f"package_kookie: Java runtime release metadata lacks {key}")
    print(value)
PY
  mapfile -t java_metadata < "$WORK_DIR/windows-java-metadata"
  [[ "${#java_metadata[@]}" == 2 ]] || {
    echo 'package_kookie: invalid Windows Java runtime metadata' >&2
    exit 1
  }
  WINDOWS_JAVA_VERSION="${java_metadata[0]}"
  WINDOWS_JAVA_VENDOR="${java_metadata[1]}"
  mkdir "$PACKAGE_ROOT/runtime"
  cp -a -- "$runtime_root/." "$PACKAGE_ROOT/runtime/"

  kof build "$ROOT_DIR/src" --target jvm --output "$jvm_build" >/dev/null
  test -f "$jvm_build/Default/Main.class" || {
    echo 'package_kookie: Kof JVM main class is missing' >&2
    exit 1
  }
  python3 - "$jvm_build" "$PACKAGE_ROOT/kookie.jar" "$PACKAGE_EPOCH" <<'PY'
import pathlib
import sys
import time
import zipfile

source = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
epoch = min(max(int(sys.argv[3]), 315_532_800), 4_354_819_199)
stamp = time.gmtime(epoch)[:6]

def entry(name):
    info = zipfile.ZipInfo(name, stamp)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    return info

with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED,
                     compresslevel=9, strict_timestamps=True) as jar:
    jar.writestr(entry("META-INF/MANIFEST.MF"),
                 b"Manifest-Version: 1.0\r\nMain-Class: Default.Main\r\n\r\n")
    for path in sorted(item for item in source.rglob("*") if item.is_file()):
        name = path.relative_to(source).as_posix()
        if name.upper() == "META-INF/MANIFEST.MF":
            continue
        jar.writestr(entry(name), path.read_bytes())
PY
  java --enable-native-access=ALL-UNNAMED \
    -jar "$PACKAGE_ROOT/kookie.jar" > "$WORK_DIR/jvm-smoke.log"
  cat > "$PACKAGE_ROOT/kookie.cmd" <<'EOF'
@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"
"%ROOT%runtime\bin\java.exe" --enable-native-access=ALL-UNNAMED -jar "%ROOT%kookie.jar" %*
exit /b %ERRORLEVEL%
EOF
  cat > "$PACKAGE_ROOT/JAVA_RUNTIME.txt" <<EOF
vendor=$WINDOWS_JAVA_VENDOR
version=$WINDOWS_JAVA_VERSION
archive_sha256=$WINDOWS_JAVA_ACTUAL_SHA256
license_files=runtime/legal
EOF
}


if [[ "$TARGET" == windows-x86_64 && "$RUNTIME" == native ]]; then
  bundle_windows_native_shell
elif [[ "$TARGET" == windows-x86_64 && "$RUNTIME" == presentation ]]; then
  bundle_windows_native_presentation
elif [[ "$TARGET" == windows-x86_64 ]]; then
  bundle_windows_jvm
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
    "${SDL_FLAGS[@]}" -lm
  glslc -fshader-stage=vert "$ROOT_DIR/native/shaders/g0_triangle.vert" \
    -o "$PACKAGE_ROOT/build/g0_triangle.vert.spv"
  glslc -fshader-stage=vert \
    "$ROOT_DIR/native/shaders/g5_triangle_instance.vert" \
    -o "$PACKAGE_ROOT/build/g5_triangle_instance.vert.spv"
  glslc -fshader-stage=vert \
    "$ROOT_DIR/native/shaders/g6_world.vert" \
    -o "$PACKAGE_ROOT/build/g6_world.vert.spv"
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
  bundle_linux_kooker
  bundle_linux_simd_benchmark
fi
cp -- "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.md"
if [[ "$TARGET" == windows-x86_64 ]]; then
  cp -- "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.txt"
fi
if [[ "$RUNTIME" == presentation ]]; then
  cat > "$PACKAGE_ROOT/DEMO_CONTROLS.txt" <<'EOF'
KOOKIE bounded first demo

Launch:
  Linux:   ./kookie
  Windows: kookie.cmd

Menu:
  Arrow keys or WASD  navigate
  Enter, Space, click  select
  Escape               back

Local playable slice:
  W / S                move forward / backward
  A / D                strafe left / right
  Mouse                look
  Mouse wheel          zoom camera
  F / Left mouse       fire
  Ctrl                 jump
  Select Play to start the authoritative goose encounter.
  Escape returns to the menu; select Play again for a fresh encounter.

Two-player dogfood:
  Select Multiplayer > Host on one client and Join on the other.
  After both peers connect, select READY on both clients.
  Press Tab during gameplay for the player screen.

The multiplayer path is direct-IPv4 dogfood networking. It has no relay,
public identity service, encryption or production DDoS protection.
This package contains no prototype content profile.
EOF
fi
cp -- "$ROOT_DIR/LICENSE" "$PACKAGE_ROOT/LICENSE"
cp -- "$ROOT_DIR/THIRD_PARTY_NOTICES.txt" "$PACKAGE_ROOT/THIRD_PARTY_NOTICES.txt"
SOURCE_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
KOF_TOOLCHAIN_VERSION="$ACTUAL_KOF_VERSION"
WINDOWS_STATUS=not-applicable
DEPENDENCY_POLICY=permissive-distributed-only
SDL_VERSION=not-bundled
SDL_MIXER_VERSION=not-bundled
RUNTIME_DEPENDENCIES=system-only
if [[ "$TARGET" == windows-x86_64 && "$RUNTIME" == jvm ]]; then
  WINDOWS_STATUS=kof-jvm-bundled-runtime
  DEPENDENCY_POLICY=bundled-runtime-license-files-retained
  RUNTIME_DEPENDENCIES=OpenJDK-runtime
elif [[ "$TARGET" == windows-x86_64 && "$RUNTIME" == presentation ]]; then
  WINDOWS_STATUS=kof-native-pe-sdl-gpu-bundled-runtime
  DEPENDENCY_POLICY=bundled-sdl-and-shader-assets-license-files-retained
  SDL_VERSION=3.4.16
  SDL_MIXER_VERSION=3.2.4
  RUNTIME_DEPENDENCIES=Kof-PE+SDL3+SDL_mixer+SPIR-V+DXIL
elif [[ "$TARGET" == windows-x86_64 ]]; then
  WINDOWS_STATUS=kof-native-pe-sdl-shell-runtime
  DEPENDENCY_POLICY=bundled-sdl-license-files-retained
  SDL_VERSION=3.4.16
  SDL_MIXER_VERSION=3.2.4
  RUNTIME_DEPENDENCIES=Kof-PE+SDL3+SDL_mixer
elif [[ "$RUNTIME" == presentation ]]; then
  SDL_VERSION=3.4.16
  SDL_MIXER_VERSION=3.2.4
  RUNTIME_DEPENDENCIES=SDL3+SDL_mixer
fi
PYTHON_VERSION="$(python3 --version 2>&1)"
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
license_status=MIT-application
windows_status=$WINDOWS_STATUS
dependency_policy=$DEPENDENCY_POLICY
sdl_version=$SDL_VERSION
sdl_mixer_version=$SDL_MIXER_VERSION
runtime_dependencies=$RUNTIME_DEPENDENCIES
windows_java_archive_sha256=$WINDOWS_JAVA_ACTUAL_SHA256
windows_java_version=$WINDOWS_JAVA_VERSION
windows_java_vendor=$WINDOWS_JAVA_VENDOR
windows_dxc_version=$WINDOWS_DXC_VERSION
source_date_epoch=$PACKAGE_EPOCH
archive_builder=$PYTHON_VERSION-zipfile
dedicated_server=$([[ "$TARGET" == linux-x86_64 ]] && echo bounded-headless-workload-with-runtime-telemetry || echo unavailable)
simd_benchmark=$([[ "$TARGET" == linux-x86_64 ]] && echo kof-buffer-u8-runtime-dispatch || echo unavailable)
content_kooker=$([[ "$TARGET" == linux-x86_64 ]] && echo native-bounded-intake-cli || echo unavailable)
prototype_content_profile=$CONTENT_PROFILE
prototype_content_sha256=$PROTOTYPE_CONTENT_TREE_SHA256
prototype_content_asset_count=$PROTOTYPE_CONTENT_ASSET_COUNT
prototype_content_file_count=$PROTOTYPE_CONTENT_FILE_COUNT
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
  python3 - "$PACKAGE_ROOT" "$ARCHIVE" "$PACKAGE_EPOCH" <<'PY'
import pathlib
import sys
import time
import zipfile

root = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
epoch = min(max(int(sys.argv[3]), 315_532_800), 4_354_819_199)
stamp = time.gmtime(epoch)[:6]
def info(name, directory):
    entry = zipfile.ZipInfo(name + ("/" if directory else ""), stamp)
    entry.compress_type = zipfile.ZIP_DEFLATED
    entry.create_system = 3
    entry.external_attr = ((0o40755 if directory else 0o100644) << 16)
    if directory:
        entry.external_attr |= 0x10
    return entry

with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED,
                     compresslevel=9, strict_timestamps=True) as archive:
    archive.writestr(info(root.name, True), b"")
    paths = sorted(root.rglob("*"),
                   key=lambda path: path.relative_to(root).as_posix())
    for path in paths:
        if path.is_symlink():
            raise SystemExit(f"package_kookie: package contains a symlink: {path}")
        name = f"{root.name}/{path.relative_to(root).as_posix()}"
        if path.is_dir():
            archive.writestr(info(name, True), b"")
        elif path.is_file():
            archive.writestr(info(name, False), path.read_bytes())
        else:
            raise SystemExit(f"package_kookie: package contains a special file: {path}")
PY
else
  tar -C "$WORK_DIR" --sort=name --mtime="@${PACKAGE_EPOCH}" \
    --owner=0 --group=0 --numeric-owner -czf "$ARCHIVE" "$PACKAGE_NAME"
fi
cp -- "$PUBLIC_KEY_WORK" "$PUBLIC_KEY"
python3 - "$ARCHIVE" "$MANIFEST" "$TARGET" "$VERSION" "$BUILD_ID" \
  "$BASE_URL" "$PROVENANCE_SCHEMA" "$RUNTIME" "$SOURCE_COMMIT" \
  "$SOURCE_TREE_STATE" "$KOF_TOOLCHAIN_VERSION" "$KOF_ARCHIVE_SHA256" \
  "$KOF_SOURCE_COMMIT" "$KOF_COMPILER_SHA256" \
  "$PUBLIC_KEY_SHA256" "$(basename "$PUBLIC_KEY")" \
  "$WINDOWS_JAVA_ACTUAL_SHA256" "$WINDOWS_JAVA_VERSION" \
  "$WINDOWS_JAVA_VENDOR" "$WINDOWS_DXC_VERSION" "$PACKAGE_EPOCH" \
  "$CONTENT_PROFILE" "$PROTOTYPE_CONTENT_TREE_SHA256" \
  "$PROTOTYPE_CONTENT_ASSET_COUNT" "$PROTOTYPE_CONTENT_FILE_COUNT" <<'PY'
import hashlib, json, pathlib, sys
archive = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
(target, version, build_id, base_url, schema, runtime, source_commit,
 source_tree_state, kof_version, kof_archive_sha256, kof_source_commit,
 kof_compiler_sha256, public_key_sha256, public_key_name,
 windows_java_archive_sha256, windows_java_version, windows_java_vendor,
 windows_dxc_version, source_date_epoch, content_profile,
 prototype_content_sha256, prototype_content_asset_count,
 prototype_content_file_count) = sys.argv[3:26]
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
    "source_date_epoch": int(source_date_epoch),
    "windows_java_runtime": target == "windows-x86_64" and runtime == "jvm",
    "windows_java_archive_sha256": windows_java_archive_sha256,
    "windows_java_version": windows_java_version,
    "windows_java_vendor": windows_java_vendor,
    "windows_dxc_version": windows_dxc_version,
    "windows_presentation": target == "windows-x86_64" and runtime == "presentation",
    "archive": archive.name,
    "size": archive.stat().st_size,
    "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    "dedicated_server": target == "linux-x86_64",
    "simd_benchmark": target == "linux-x86_64",
    "content_kooker": target == "linux-x86_64",
    "content_profile": content_profile,
    "prototype_content_sha256": prototype_content_sha256,
    "prototype_content_asset_count": int(prototype_content_asset_count),
    "prototype_content_file_count": int(prototype_content_file_count),
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
