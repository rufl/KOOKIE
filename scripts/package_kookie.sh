#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="linux-x86_64"
VERSION="${KOOKIE_VERSION:-0.1.0-dogfood.1}"
BUILD_ID="${KOOKIE_BUILD_ID:-$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)}"
OUTPUT_DIR="${KOOKIE_OUTPUT_DIR:-$ROOT_DIR/release}"

usage() {
  cat <<'EOF'
Usage: scripts/package_kookie.sh [--target linux-x86_64|windows-x86_64]

Builds an immutable internal dogfood archive and SHA256SUMS. Linux is the only
native target currently supported by the Kof compiler. Windows fails closed
until a real PE build, runtime proof and signing inputs exist.
EOF
}

while (($#)); do
  case "$1" in
    --target) TARGET="${2:?missing target}"; shift 2 ;;
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --build-id) BUILD_ID="${2:?missing build id}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?missing output directory}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "package_kookie: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$TARGET" in
  linux-x86_64) ;;
  windows-x86_64)
    echo 'package_kookie: Windows packaging is blocked: Kof exposes no Windows native target, PE proof, runtime closure, or signing inputs' >&2
    exit 2
    ;;
  *) echo "package_kookie: unsupported target: $TARGET" >&2; exit 2 ;;
esac

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || {
  echo 'package_kookie: version must be SemVer without a leading v' >&2
  exit 2
}
[[ "$BUILD_ID" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo 'package_kookie: build id contains unsafe characters' >&2
  exit 2
}
command -v kof >/dev/null || { echo 'package_kookie: kof is required' >&2; exit 2; }
command -v sha256sum >/dev/null || { echo 'package_kookie: sha256sum is required' >&2; exit 2; }

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
ARCHIVE="$OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
mkdir -p "$PACKAGE_ROOT"

kof build "$ROOT_DIR/src" --target native --output "$WORK_DIR/build" >/dev/null
BINARY="$WORK_DIR/build/Default/Main"
test -x "$BINARY" || { echo "package_kookie: native executable missing: $BINARY" >&2; exit 1; }
cp -- "$BINARY" "$PACKAGE_ROOT/kookie"
chmod 755 "$PACKAGE_ROOT/kookie"
cp -- "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.md"
cat > "$PACKAGE_ROOT/PROVENANCE.txt" <<EOF
application=kookie
channel=dogfood
target=$TARGET
version=$VERSION
build_id=$BUILD_ID
source_commit=$(git -C "$ROOT_DIR" rev-parse HEAD)
kof_version=$(kof version 2>/dev/null | tr '\n' ' ')
license_status=unlicensed-internal-only
windows_status=blocked-no-native-target
EOF

rm -f -- "$ARCHIVE"
tar -C "$WORK_DIR" -czf "$ARCHIVE" "$PACKAGE_NAME"
(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$ARCHIVE")" > SHA256SUMS
)
python3 - "$ARCHIVE" "$OUTPUT_DIR/$PACKAGE_NAME.json" "$TARGET" "$VERSION" "$BUILD_ID" <<'PY'
import hashlib, json, pathlib, sys
archive = pathlib.Path(sys.argv[1])
manifest = {
    "schema": "kookie.dogfood-package/v1",
    "application": "kookie",
    "channel": "dogfood",
    "target": sys.argv[3],
    "version": sys.argv[4],
    "build_id": sys.argv[5],
    "archive": archive.name,
    "bytes": archive.stat().st_size,
    "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    "license_status": "unlicensed-internal-only",
    "windows_status": "blocked-no-native-target",
}
pathlib.Path(sys.argv[2]).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

printf 'package_kookie: wrote %s, %s, and %s\n' "$ARCHIVE" "$OUTPUT_DIR/SHA256SUMS" "$OUTPUT_DIR/$PACKAGE_NAME.json"
