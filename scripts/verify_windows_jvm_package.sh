#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
: "${KOOKIE_KOF_ARCHIVE_SHA256:?set KOOKIE_KOF_ARCHIVE_SHA256 to the pinned Kof distribution digest}"
: "${KOOKIE_KOF_SOURCE_COMMIT:?set KOOKIE_KOF_SOURCE_COMMIT to the pinned Kof source commit}"
: "${KOOKIE_WINDOWS_JAVA_ARCHIVE:?set KOOKIE_WINDOWS_JAVA_ARCHIVE to a pinned Windows x64 OpenJDK ZIP}"
: "${KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256:?set KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256 to its digest}"
command -v java >/dev/null || { echo 'verify_windows_jvm_package: java is required' >&2; exit 2; }
command -v openssl >/dev/null || { echo 'verify_windows_jvm_package: openssl is required' >&2; exit 2; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-windows-jvm-smoke.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM
SIGNING_KEY="$WORK_DIR/release-signing.pem"
openssl genpkey -algorithm ED25519 -out "$SIGNING_KEY" 2>/dev/null
chmod 600 "$SIGNING_KEY"
export KOOKIE_SIGNING_KEY="$SIGNING_KEY"
export KOOKIE_ALLOW_DIRTY_PACKAGE=1
export KOOKIE_VERSION=0.1.0-windows-jvm-smoke
export KOOKIE_BUILD_ID=windows-jvm-smoke
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1704067200}"

for release in release-a release-b; do
  "$ROOT_DIR/scripts/package_kookie.sh" --runtime jvm \
    --target windows-x86_64 --output "$WORK_DIR/$release"
done

PACKAGE_NAME="kookie-$KOOKIE_VERSION-windows-x86_64"
ARCHIVE_NAME="$PACKAGE_NAME.zip"
for artifact in \
  "$ARCHIVE_NAME" "$ARCHIVE_NAME.sig" "$PACKAGE_NAME.json" \
  "$PACKAGE_NAME.json.sig" "$PACKAGE_NAME.pub.pem" SHA256SUMS SHA256SUMS.sig; do
  cmp "$WORK_DIR/release-a/$artifact" "$WORK_DIR/release-b/$artifact"
done
(
  cd "$WORK_DIR/release-a"
  sha256sum --check SHA256SUMS >/dev/null
)
PUBLIC_KEY="$WORK_DIR/release-a/$PACKAGE_NAME.pub.pem"
ARCHIVE="$WORK_DIR/release-a/$ARCHIVE_NAME"
MANIFEST="$WORK_DIR/release-a/$PACKAGE_NAME.json"
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$ARCHIVE" -sigfile "$ARCHIVE.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$MANIFEST" -sigfile "$MANIFEST.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$WORK_DIR/release-a/SHA256SUMS" \
  -sigfile "$WORK_DIR/release-a/SHA256SUMS.sig" >/dev/null

EXTRACTED="$WORK_DIR/extracted"
python3 - "$ARCHIVE" "$MANIFEST" "$EXTRACTED" \
  "$KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256" "$SOURCE_DATE_EPOCH" <<'PY'
import hashlib
import json
import pathlib
import stat
import sys
import zipfile

archive_path = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
destination = pathlib.Path(sys.argv[3])
expected_java_sha256 = sys.argv[4].lower()
expected_epoch = int(sys.argv[5])
with zipfile.ZipFile(archive_path) as archive:
    for entry in archive.infolist():
        relative = pathlib.PurePosixPath(entry.filename)
        mode = entry.external_attr >> 16
        assert not relative.is_absolute() and ".." not in relative.parts
        assert not stat.S_ISLNK(mode)
    archive.extractall(destination)
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest["schema"] == "kookie.package-provenance/v2"
assert manifest["target"] == "windows-x86_64"
assert manifest["runtime"] == "jvm"
assert manifest["windows_java_runtime"] is True
assert manifest["windows_java_archive_sha256"].lower() == expected_java_sha256
assert manifest["windows_java_version"] != "not-bundled"
assert manifest["windows_java_vendor"] != "not-bundled"
assert manifest["source_date_epoch"] == expected_epoch
assert manifest["sha256"] == hashlib.sha256(archive_path.read_bytes()).hexdigest()
root = destination / archive_path.stem
assert (root / "kookie.cmd").is_file()
assert (root / "kookie.jar").is_file()
assert (root / "runtime" / "bin" / "java.exe").read_bytes()[:2] == b"MZ"
assert (root / "runtime" / "release").is_file()
legal = root / "runtime" / "legal"
assert legal.is_dir() and any(path.is_file() for path in legal.rglob("*"))
assert "runtime\\bin\\java.exe" in (root / "kookie.cmd").read_text(encoding="utf-8")
assert "Windows JVM runtime" in (root / "THIRD_PARTY_NOTICES.txt").read_text(encoding="utf-8")
provenance = dict(
    line.split("=", 1)
    for line in (root / "PROVENANCE.txt").read_text(encoding="utf-8").splitlines()
    if "=" in line
)
assert provenance["windows_status"] == "kof-jvm-bundled-runtime"
assert provenance["dependency_policy"] == "bundled-runtime-license-files-retained"
assert provenance["runtime_dependencies"] == "OpenJDK-runtime"
assert provenance["windows_java_archive_sha256"].lower() == expected_java_sha256
with zipfile.ZipFile(root / "kookie.jar") as jar:
    assert "Default/Main.class" in jar.namelist()
    manifest_text = jar.read("META-INF/MANIFEST.MF")
    assert b"Main-Class: Default.Main\r\n" in manifest_text
PY
PACKAGE_ROOT="$EXTRACTED/$PACKAGE_NAME"
java -jar "$PACKAGE_ROOT/kookie.jar" | \
  grep -Fq 'KOOKIE G1 authoritative shooter verified'

BAD_DIGEST="$(printf '0%.0s' {1..64})"
if KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256="$BAD_DIGEST" \
   "$ROOT_DIR/scripts/package_kookie.sh" --runtime jvm \
   --target windows-x86_64 --output "$WORK_DIR/bad-digest" \
   >"$WORK_DIR/bad-digest.log" 2>&1; then
  echo 'verify_windows_jvm_package: mismatched runtime digest was accepted' >&2
  exit 1
fi
grep -Fq 'Windows Java archive SHA-256 mismatch' "$WORK_DIR/bad-digest.log"

printf 'KOOKIE Windows JVM package passed: reproducible archive, signatures, pinned runtime, retained legal files, and JVM smoke\n'
