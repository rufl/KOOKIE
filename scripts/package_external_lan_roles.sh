#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="windows-x86_64"
VERSION="${KOOKIE_VERSION:-0.1.0-dogfood.external-lan.1}"
BUILD_ID="${KOOKIE_BUILD_ID:-$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)}"
OUTPUT_DIR="${KOOKIE_OUTPUT_DIR:-$ROOT_DIR/release}"
JAVA_RELEASE="${KOOKIE_JVM_RELEASE:-21}"
PROVENANCE_SCHEMA="${KOOKIE_PACKAGE_PROVENANCE_SCHEMA:-kookie.package-provenance/v1}"

usage() {
  cat <<'EOF'
Usage: scripts/package_external_lan_roles.sh [options]

Builds host, client-a and client-b JVM role JARs with the direct Kof JVM
authenticated UDP backend and Windows .cmd launchers. The archive contains no
run key or manifest; provide those through the environment or an authorized run bundle.

Options:
  --version <semver>
  --build-id <id>
  --output <directory>
  --java-release <version>
EOF
}

while (($#)); do
  case "$1" in
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --build-id) BUILD_ID="${2:?missing build id}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?missing output directory}"; shift 2 ;;
    --java-release) JAVA_RELEASE="${2:?missing Java release}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "package_external_lan_roles: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || {
  echo 'package_external_lan_roles: version must be SemVer without a leading v' >&2
  exit 2
}
[[ "$BUILD_ID" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo 'package_external_lan_roles: build id contains unsafe characters' >&2
  exit 2
}
command -v kof >/dev/null || { echo 'package_external_lan_roles: kof is required' >&2; exit 2; }
command -v javac >/dev/null || { echo 'package_external_lan_roles: javac is required' >&2; exit 2; }
command -v jar >/dev/null || { echo 'package_external_lan_roles: jar is required' >&2; exit 2; }
command -v zip >/dev/null || { echo 'package_external_lan_roles: zip is required' >&2; exit 2; }
command -v sha256sum >/dev/null || { echo 'package_external_lan_roles: sha256sum is required' >&2; exit 2; }

if [[ -n "${KOOKIE_WINDOWS_JAVA_HOME:-}" &&
      ! -f "$KOOKIE_WINDOWS_JAVA_HOME/bin/java.exe" ]]; then
  echo 'package_external_lan_roles: KOOKIE_WINDOWS_JAVA_HOME must contain bin/java.exe' >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
case "$OUTPUT_DIR" in
  /|"$ROOT_DIR")
    echo 'package_external_lan_roles: refusing unsafe output directory' >&2
    exit 2
    ;;
esac

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-external-lan-package.XXXXXX")"
PACKAGE_NAME="kookie-external-lan-roles-$VERSION-$TARGET"
PACKAGE_ROOT="$WORK_DIR/$PACKAGE_NAME"
ARCHIVE="$OUTPUT_DIR/$PACKAGE_NAME.zip"
source_dir="$WORK_DIR/source"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$PACKAGE_ROOT" "$source_dir/content" "$source_dir/core" "$source_dir/session" "$source_dir/world" "$WORK_DIR/metadata-classes"
for content_file in "$ROOT_DIR"/src/content/*.kf; do
  ln -s "$content_file" "$source_dir/content/$(basename "$content_file")"
done
for core_file in "$ROOT_DIR"/src/core/*.kf; do
  ln -s "$core_file" "$source_dir/core/$(basename "$core_file")"
done
for session_file in "$ROOT_DIR"/src/session/*.kf; do
  ln -s "$session_file" "$source_dir/session/$(basename "$session_file")"
done
for world_file in "$ROOT_DIR"/src/world/*.kf; do
  ln -s "$world_file" "$source_dir/world/$(basename "$world_file")"
done
{
  sed -n '1,4p' "$ROOT_DIR/probes/g0_external_transport/main.kf"
  cat "$ROOT_DIR/probes/g0_external_transport_backends/transport_jvm.kf"
  sed -n '5,$p' "$ROOT_DIR/probes/g0_external_transport/main.kf"
} > "$source_dir/main.kf"

javac --release "$JAVA_RELEASE" \
  -d "$WORK_DIR/metadata-classes" \
  "$ROOT_DIR/jvm/src/dev/rufl/kookie/KookieExternalLanMetadata.java"

for role in host client-a client-b; do
  role_build="$WORK_DIR/build-$role"
  KOOKIE_EXTERNAL_LAN_ROLE="$role" kof build \
    "$source_dir/main.kf" \
    --target jvm --output "$role_build" >/dev/null
  jar --create --file "$PACKAGE_ROOT/kookie-external-lan-$role.jar" \
    --main-class Default.Main \
    -C "$role_build" . \
    -C "$WORK_DIR/metadata-classes" .
  cat > "$PACKAGE_ROOT/run-$role.cmd" <<EOF
@echo off
setlocal
set "ROOT=%~dp0"
set "ROLE=$role"
set "JAR=%ROOT%kookie-external-lan-$role.jar"
set "LOG=%KOOKIE_EXTERNAL_LAN_PROBE_LOG%"
if not defined LOG set "LOG=%ROOT%evidence-%ROLE%\\probe.log"
for %%I in ("%LOG%") do if not exist "%%~dpI" mkdir "%%~dpI"
set "JAVA_BIN="
if defined KOOKIE_JAVA_HOME if exist "%KOOKIE_JAVA_HOME%\\bin\\java.exe" set "JAVA_BIN=%KOOKIE_JAVA_HOME%\\bin\\java.exe"
if not defined JAVA_BIN if exist "%ROOT%jdk\\bin\\java.exe" set "JAVA_BIN=%ROOT%jdk\\bin\\java.exe"
if not defined JAVA_BIN if defined JAVA_HOME if exist "%JAVA_HOME%\\bin\\java.exe" set "JAVA_BIN=%JAVA_HOME%\\bin\\java.exe"
if not defined JAVA_BIN set "JAVA_BIN=java"
set "KOOKIE_EXTERNAL_LAN_ROLE=%role%"
if not defined KOOKIE_EXTERNAL_LAN_TIMEOUT_MILLISECONDS set "KOOKIE_EXTERNAL_LAN_TIMEOUT_MILLISECONDS=30000"
"%JAVA_BIN%" -cp "%JAR%" Default.Main >"%LOG%" 2>&1
set "STATUS=%ERRORLEVEL%"
"%JAVA_BIN%" -cp "%JAR%" dev.rufl.kookie.KookieExternalLanMetadata "%LOG%" "%ROLE%" "%STATUS%"
type "%LOG%"
exit /b %STATUS%
EOF
done

if [[ -n "${KOOKIE_WINDOWS_JAVA_HOME:-}" ]]; then
  cp -a "$KOOKIE_WINDOWS_JAVA_HOME" "$PACKAGE_ROOT/jdk"
fi

cat > "$PACKAGE_ROOT/README.txt" <<'EOF'
KOOKIE authenticated external LAN JVM roles

The authenticated transport is implemented in Kof and uses the JVM target's
JDK java.net UDP APIs; Java is used only for launcher evidence metadata.

Run one launcher on each separate host:
  run-host.cmd
  run-client-a.cmd
  run-client-b.cmd

Required environment on every host:
  KOOKIE_TRANSPORT_KEY_HEX
  KOOKIE_EXTERNAL_LAN_RUN_ID
  KOOKIE_EXTERNAL_LAN_RUN_MANIFEST
  KOOKIE_EXTERNAL_LAN_HOST_IPV4 on clients

The manifest sourceRevision must be non-empty and bind the qualification
evidence to the source revision that produced the role JARs.

The launcher records role identity, machine fingerprint, key fingerprint,
run ID, host IPv4 and process exit status in the role log. Keep the manifest
and raw key outside this archive and transfer them through an authorized
secure channel.
Optional environment:
  KOOKIE_EXTERNAL_LAN_TIMEOUT_MILLISECONDS (launcher default: 30000)
EOF
cat > "$PACKAGE_ROOT/PROVENANCE.txt" <<EOF
application=kookie-external-lan-roles
channel=dogfood
target=$TARGET
runtime=jvm
version=$VERSION
build_id=$BUILD_ID
source_commit=$(git -C "$ROOT_DIR" rev-parse HEAD)
kof_version=$(kof version 2>/dev/null | tr '\n' ' ')
license_status=internal-dogfood-only
EOF

rm -f "$ARCHIVE"
(cd "$WORK_DIR" && zip -qr "$ARCHIVE" "$PACKAGE_NAME")
(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$ARCHIVE")" > "${PACKAGE_NAME}.SHA256SUMS"
)
python3 - "$ARCHIVE" "$OUTPUT_DIR/$PACKAGE_NAME.json" "$VERSION" "$BUILD_ID" "$PROVENANCE_SCHEMA" <<'PY'
import hashlib, json, pathlib, subprocess, sys
archive = pathlib.Path(sys.argv[1])
version, build_id, schema = sys.argv[3:6]
manifest = {
    "schema": schema,
    "application": "kookie-external-lan-roles",
    "channel": "dogfood",
    "version": version,
    "target": "windows-x86_64",
    "runtime": "jvm",
    "build_id": build_id,
    "archive": archive.name,
    "size": archive.stat().st_size,
    "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    "signing": "unavailable",
    "proof": "unavailable",
    "run_material": "external-manifest-and-key-required",
}
pathlib.Path(sys.argv[2]).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

printf 'package_external_lan_roles: wrote %s, %s, and %s\n' \
  "$ARCHIVE" "$OUTPUT_DIR/${PACKAGE_NAME}.SHA256SUMS" "$OUTPUT_DIR/$PACKAGE_NAME.json"
