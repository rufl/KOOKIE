#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
VERSION=""
OUTPUT_DIR=""
BUILD_ID=""
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}"

usage() {
  cat <<'EOF'
Usage: scripts/build_demo_release.sh --target linux-x86_64|windows-x86_64 \
  --version VERSION --output DIRECTORY [--build-id ID] [--source-date-epoch EPOCH]

Builds two identical signed native presentation packages, verifies the complete
artifact set, extracts it outside the checkout, and runs the target package
smoke. The source tree must be clean. Target hardware presentation smoke is a
separate gate.
EOF
}

while (($#)); do
  case "$1" in
    --target) TARGET="${2:?missing target}"; shift 2 ;;
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?missing output directory}"; shift 2 ;;
    --build-id) BUILD_ID="${2:?missing build id}"; shift 2 ;;
    --source-date-epoch) SOURCE_DATE_EPOCH="${2:?missing source date epoch}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "build_demo_release: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$TARGET" in
  linux-x86_64|windows-x86_64) ;;
  *) echo 'build_demo_release: --target must be linux-x86_64 or windows-x86_64' >&2; usage >&2; exit 2 ;;
esac
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || {
  echo 'build_demo_release: version must be SemVer without a leading v' >&2
  exit 2
}
[[ -n "$OUTPUT_DIR" ]] || { echo 'build_demo_release: --output is required' >&2; exit 2; }
[[ -n "${KOOKIE_SIGNING_KEY:-}" ]] || {
  echo 'build_demo_release: KOOKIE_SIGNING_KEY is required for a release build' >&2
  exit 2
}
[[ -f "$KOOKIE_SIGNING_KEY" && ! -L "$KOOKIE_SIGNING_KEY" ]] || {
  echo 'build_demo_release: KOOKIE_SIGNING_KEY must name a regular file' >&2
  exit 2
}
[[ -n "${KOOKIE_KOF_ARCHIVE_SHA256:-}" ]] || {
  echo 'build_demo_release: KOOKIE_KOF_ARCHIVE_SHA256 is required' >&2
  exit 2
}
[[ -n "${KOOKIE_KOF_SOURCE_COMMIT:-}" ]] || {
  echo 'build_demo_release: KOOKIE_KOF_SOURCE_COMMIT is required' >&2
  exit 2
}
if [[ -z "$SOURCE_DATE_EPOCH" ]]; then
  SOURCE_DATE_EPOCH="$(git -C "$ROOT_DIR" show -s --format=%ct HEAD)"
fi
[[ "$SOURCE_DATE_EPOCH" =~ ^[0-9]+$ ]] || {
  echo 'build_demo_release: source date epoch must be a non-negative integer' >&2
  exit 2
}

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)" ]]; then
  echo 'build_demo_release: source tree is dirty; commit all release inputs first' >&2
  exit 2
fi

for command_name in cmp cp find git grep od openssl python3 sha256sum tar tr; do
  command -v "$command_name" >/dev/null || {
    echo "build_demo_release: $command_name is required" >&2
    exit 2
  }
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-demo-release.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

BUILD_ID="${BUILD_ID:-demo-${TARGET}-$VERSION}"
if [[ "${KOOKIE_CONTENT_PROFILE:-none}" != none ]]; then
  echo 'build_demo_release: first demo release is content-profile=none; prototype content is not distributable' >&2
  exit 2
fi
export KOOKIE_CONTENT_PROFILE=none
export KOOKIE_SIGNING_KEY KOOKIE_KOF_ARCHIVE_SHA256 KOOKIE_KOF_SOURCE_COMMIT
export KOOKIE_VERSION="$VERSION"
export KOOKIE_BUILD_ID="$BUILD_ID"
export SOURCE_DATE_EPOCH
unset KOOKIE_ALLOW_DIRTY_PACKAGE

for release in release-a release-b; do
  "$ROOT_DIR/scripts/package_kookie.sh" \
    --runtime presentation --target "$TARGET" \
    --output "$WORK_DIR/$release"
done

PACKAGE_NAME="kookie-$VERSION-$TARGET"
if [[ "$TARGET" == windows-x86_64 ]]; then
  ARCHIVE_NAME="$PACKAGE_NAME.zip"
else
  ARCHIVE_NAME="$PACKAGE_NAME.tar.gz"
fi
ARTIFACTS=(
  "$ARCHIVE_NAME"
  "$ARCHIVE_NAME.sig"
  "$PACKAGE_NAME.json"
  "$PACKAGE_NAME.json.sig"
  "$PACKAGE_NAME.pub.pem"
  SHA256SUMS
  SHA256SUMS.sig
)
for artifact in "${ARTIFACTS[@]}"; do
  cmp "$WORK_DIR/release-a/$artifact" "$WORK_DIR/release-b/$artifact"
done

mkdir -p "$OUTPUT_DIR"
if [[ -n "$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo 'build_demo_release: output directory must be empty' >&2
  exit 2
fi
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
for artifact in "${ARTIFACTS[@]}"; do
  cp -- "$WORK_DIR/release-a/$artifact" "$OUTPUT_DIR/$artifact"
done
(
  cd "$OUTPUT_DIR"
  sha256sum --check SHA256SUMS >/dev/null
)
PUBLIC_KEY="$OUTPUT_DIR/$PACKAGE_NAME.pub.pem"
ARCHIVE="$OUTPUT_DIR/$ARCHIVE_NAME"
MANIFEST="$OUTPUT_DIR/$PACKAGE_NAME.json"
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$ARCHIVE" -sigfile "$ARCHIVE.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$MANIFEST" -sigfile "$MANIFEST.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$OUTPUT_DIR/SHA256SUMS" -sigfile "$OUTPUT_DIR/SHA256SUMS.sig" >/dev/null

python3 - "$MANIFEST" "$ROOT_DIR" "$VERSION" "$TARGET" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
root = pathlib.Path(sys.argv[2])
version = sys.argv[3]
target = sys.argv[4]
assert manifest["schema"] == "kookie.package-provenance/v2"
assert manifest["application"] == "kookie"
assert manifest["channel"] == "dogfood"
assert manifest["version"] == version
assert manifest["target"] == target
assert manifest["runtime"] == "presentation"
assert manifest["source_tree_state"] == "clean"
assert manifest["source_commit"] == __import__("subprocess").run(
    ["git", "-C", str(root), "rev-parse", "HEAD"],
    check=True, text=True, capture_output=True).stdout.strip()
assert manifest["windows_presentation"] is (target == "windows-x86_64")
assert manifest["content_profile"] == "none"
PY

EXTRACTED="$WORK_DIR/extracted"
mkdir -p "$EXTRACTED"
if [[ "$TARGET" == windows-x86_64 ]]; then
  python3 - "$ARCHIVE" "$EXTRACTED" <<'PY'
import pathlib
import stat
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(archive) as source:
    for entry in source.infolist():
        relative = pathlib.PurePosixPath(entry.filename)
        mode = entry.external_attr >> 16
        if (not entry.filename or relative.is_absolute() or ".." in relative.parts
                or stat.S_ISLNK(mode)
                or (mode and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)))):
            raise SystemExit(f"unsafe archive entry: {entry.filename!r}")
    source.extractall(destination)
PY
  PACKAGE_ROOT="$EXTRACTED/$PACKAGE_NAME"
  for required in kookie.cmd kookie.exe kookie-launcher.exe kookie-launcher.cmd \
    SDL3.dll SDL3_mixer.dll \
    build/SDL3.dll build/SDL3_mixer.dll build/g0_triangle.vert.spv \
    build/g5_triangle_instance.vert.spv build/g6_world.vert.spv \
    build/g0_triangle.frag.spv build/g0_triangle.vert.dxil \
    build/g5_triangle_instance.vert.dxil build/g6_world.vert.dxil \
    build/g0_triangle.frag.dxil RELEASE_PUBLIC_KEY.pem \
    PROVENANCE.txt THIRD_PARTY_NOTICES.txt \
    fonts/OFL.txt fonts/readme.txt fonts/manifest.json; do
    [[ -f "$PACKAGE_ROOT/$required" ]] || {
      echo "build_demo_release: missing Windows package entry $required" >&2
      exit 1
    }
  done
  [[ "$(od -An -N2 -tx1 "$PACKAGE_ROOT/kookie.exe" | tr -d ' \n')" == 4d5a ]] || {
    echo 'build_demo_release: Windows package is not an MZ PE executable' >&2
    exit 1
  }
  [[ "$(od -An -N2 -tx1 "$PACKAGE_ROOT/kookie-launcher.exe" | tr -d ' \n')" == 4d5a ]] || {
    echo 'build_demo_release: Windows launcher is not an MZ PE executable' >&2
    exit 1
  }
else
  tar -xzf "$ARCHIVE" -C "$EXTRACTED"
  PACKAGE_ROOT="$EXTRACTED/$PACKAGE_NAME"
  for required in kookie kookie.bin kookie-launcher kookie-smoke.bin \
    build/libkookie_sdl_adapter.so build/g0_triangle.vert.spv \
    build/g5_triangle_instance.vert.spv build/g6_world.vert.spv \
    build/g0_triangle.frag.spv kookie-server kookie-server.bin LICENSE \
    THIRD_PARTY_NOTICES.txt DEMO_CONTROLS.txt PROVENANCE.txt \
    fonts/jared-lite.ttf fonts/pixand.ttf fonts/OFL.txt fonts/readme.txt \
    fonts/manifest.json; do
    [[ -e "$PACKAGE_ROOT/$required" ]] || {
      echo "build_demo_release: missing Linux package entry $required" >&2
      exit 1
    }
  done
  for library_pattern in 'libSDL3.so*' 'libSDL3_mixer.so*'; do
    [[ -n "$(find "$PACKAGE_ROOT/lib" -maxdepth 1 -name "$library_pattern" \
      -print -quit)" ]] || {
      echo "build_demo_release: missing Linux package library $library_pattern" >&2
      exit 1
    }
  done
  "$PACKAGE_ROOT/kookie-launcher" --self-test
  PACKAGE_SMOKE_OUTPUT="$(
    cd "$WORK_DIR"
    "$PACKAGE_ROOT/kookie" --package-smoke
  )"
  grep -Fq 'KOOKIE G1 authoritative shooter verified' <<<"$PACKAGE_SMOKE_OUTPUT"
fi

cat >"$OUTPUT_DIR/BUILD_SUMMARY.txt" <<EOF
application=kookie
release_version=$VERSION
target=$TARGET
runtime=presentation
source_commit=$(git -C "$ROOT_DIR" rev-parse HEAD)
kof_source_commit=$KOOKIE_KOF_SOURCE_COMMIT
source_date_epoch=$SOURCE_DATE_EPOCH
content_profile=none
artifact_status=deterministic-signed-clean-tree
hardware_presentation_status=not-run-by-builder
EOF

printf 'build_demo_release: deterministic signed %s package verified in %s\n' \
  "$TARGET" "$OUTPUT_DIR"
