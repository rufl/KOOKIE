#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BASE_URL="${KOOKIE_PACKAGE_BASE_URL:-https://github.com/rufl/KOOKIE/releases/download}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="linux-x86_64"
RUNTIME="${KOOKIE_RUNTIME:-native}"
VERSION="${KOOKIE_VERSION:-0.1.0-dogfood.1}"
BUILD_ID="${KOOKIE_BUILD_ID:-$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)}"
OUTPUT_DIR="${KOOKIE_OUTPUT_DIR:-$ROOT_DIR/release}"

usage() {
  cat <<'EOF'
Usage: scripts/package_kookie.sh [--runtime native|jvm] [--target linux-x86_64|windows-x86_64]

Builds an immutable internal dogfood archive and SHA256SUMS. Native Linux
packages contain the Kof executable. JVM packages contain an executable
launcher plus an executable JAR; Windows JVM packages also embed the supplied
Windows Java runtime. Windows native packaging fails closed until a real PE
build exists.
EOF
}

while (($#)); do
  case "$1" in
    --runtime) RUNTIME="${2:?missing runtime}"; shift 2 ;;
    --target) TARGET="${2:?missing target}"; shift 2 ;;
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --build-id) BUILD_ID="${2:?missing build id}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?missing output directory}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "package_kookie: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$RUNTIME" in
  native|jvm) ;;
  *) echo "package_kookie: unsupported runtime: $RUNTIME" >&2; exit 2 ;;
esac

case "$TARGET" in
  linux-x86_64) ;;
  windows-x86_64)
    if [[ "$RUNTIME" != jvm ]]; then
      echo 'package_kookie: Windows native packaging is blocked: Kof exposes no Windows PE target' >&2
      exit 2
    fi
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
if [[ "$RUNTIME" == jvm ]]; then
  command -v jar >/dev/null || { echo 'package_kookie: jar is required for JVM packaging' >&2; exit 2; }
  command -v java >/dev/null || { echo 'package_kookie: java is required for JVM packaging' >&2; exit 2; }
fi
if [[ "$TARGET" == windows-x86_64 ]]; then
  [[ -n "${KOOKIE_WINDOWS_JAVA_HOME:-}" &&
    -f "$KOOKIE_WINDOWS_JAVA_HOME/bin/java.exe" ]] || {
    echo 'package_kookie: Windows JVM packaging requires KOOKIE_WINDOWS_JAVA_HOME containing bin/java.exe' >&2
    exit 2
  }
  command -v zip >/dev/null || { echo 'package_kookie: zip is required for Windows JVM packaging' >&2; exit 2; }
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

if [[ "$RUNTIME" == native ]]; then
  kof build "$ROOT_DIR/src" --target native --output "$WORK_DIR/build" >/dev/null
  BINARY="$WORK_DIR/build/Default/Main"
  test -x "$BINARY" || { echo "package_kookie: native executable missing: $BINARY" >&2; exit 1; }
  cp -- "$BINARY" "$PACKAGE_ROOT/kookie"
  chmod 755 "$PACKAGE_ROOT/kookie"
else
  kof build "$ROOT_DIR/src" --target jvm --output "$WORK_DIR/build" >/dev/null
  jar --create --file "$PACKAGE_ROOT/kookie.jar" --main-class Default.Main -C "$WORK_DIR/build" .
  if [[ "$TARGET" == windows-x86_64 ]]; then
    cp -a -- "$KOOKIE_WINDOWS_JAVA_HOME" "$PACKAGE_ROOT/jdk"
    cat > "$PACKAGE_ROOT/kookie.cmd" <<'EOF'
@echo off
setlocal
set "ROOT=%~dp0"
"%ROOT%jdk\bin\java.exe" -jar "%ROOT%kookie.jar" %*
exit /b %ERRORLEVEL%
EOF
  else
    cat > "$PACKAGE_ROOT/kookie" <<'EOF'
#!/usr/bin/env sh
set -eu
exec java -jar "$(dirname "$0")/kookie.jar" "$@"
EOF
    chmod 755 "$PACKAGE_ROOT/kookie"
  fi
fi
cp -- "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.md"
cat > "$PACKAGE_ROOT/LICENSE" <<'EOF'
KOOKIE INTERNAL DOGFOOD NOTICE

This package is supplied only for private qualification on authorized
OVERZEER endpoints. No public redistribution or sublicensing grant is made.
Contact the project owner before using this package outside those endpoints.
EOF
cat > "$PACKAGE_ROOT/PROVENANCE.txt" <<EOF
application=kookie
channel=dogfood
target=$TARGET
runtime=$RUNTIME
version=$VERSION
build_id=$BUILD_ID
source_commit=$(git -C "$ROOT_DIR" rev-parse HEAD)
kof_version=$(kof version 2>/dev/null | tr '\n' ' ')
license_status=internal-dogfood-only
windows_status=$([[ "$TARGET" == windows-x86_64 ]] && echo jvm-runtime-embedded-no-native-pe || echo blocked-no-native-target)
EOF
rm -f -- "$ARCHIVE"
if [[ "$TARGET" == windows-x86_64 ]]; then
  (cd "$WORK_DIR" && zip -qr "$ARCHIVE" "$PACKAGE_NAME")
else
  tar -C "$WORK_DIR" -czf "$ARCHIVE" "$PACKAGE_NAME"
fi
(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$ARCHIVE")" > SHA256SUMS
)
python3 - "$ARCHIVE" "$OUTPUT_DIR/$PACKAGE_NAME.json" "$TARGET" "$VERSION" "$BUILD_ID" "$BASE_URL" <<'PY'
import hashlib, json, pathlib, sys
archive = pathlib.Path(sys.argv[1])
target, version, build_id, base_url = sys.argv[3:7]
encoded = f"{base_url.rstrip('/')}/dogfood/{version}/{target}/{build_id}"
manifest = {
    "schema": "overzeer.package-provenance/v1",
    "application": "kookie",
    "channel": "dogfood",
    "version": version,
    "target": target,
    "build_id": build_id,
    "archive": archive.name,
    "size": archive.stat().st_size,
    "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    "signing": "unavailable",
    "proof": "unavailable",
    "url": f"{encoded}/{archive.name}",
    "manifest_url": f"{encoded}/metadata.json",
}
pathlib.Path(sys.argv[2]).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

printf 'package_kookie: wrote %s, %s, and %s\n' "$ARCHIVE" "$OUTPUT_DIR/SHA256SUMS" "$OUTPUT_DIR/$PACKAGE_NAME.json"
