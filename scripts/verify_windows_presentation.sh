#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
: "${KOOKIE_KOF_ARCHIVE_SHA256:?set KOOKIE_KOF_ARCHIVE_SHA256 to the pinned Kof distribution digest}"
: "${KOOKIE_KOF_SOURCE_COMMIT:?set KOOKIE_KOF_SOURCE_COMMIT to the pinned Kof source commit}"
: "${KOOKIE_WINDOWS_SDL_PREFIX:?set KOOKIE_WINDOWS_SDL_PREFIX to the SDL3 MinGW prefix}"
: "${KOOKIE_WINDOWS_SDL_MIXER_PREFIX:?set KOOKIE_WINDOWS_SDL_MIXER_PREFIX to the SDL_mixer MinGW prefix}"
: "${KOOKIE_DXC:?set KOOKIE_DXC to the pinned dxc executable}"
command -v openssl >/dev/null || { echo 'verify_windows_presentation: openssl is required' >&2; exit 2; }
command -v python3 >/dev/null || { echo 'verify_windows_presentation: python3 is required' >&2; exit 2; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-windows-presentation-smoke.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM
SIGNING_KEY="$WORK_DIR/release-signing.pem"
openssl genpkey -algorithm ED25519 -out "$SIGNING_KEY" 2>/dev/null
chmod 600 "$SIGNING_KEY"
export KOOKIE_SIGNING_KEY="$SIGNING_KEY"
export KOOKIE_ALLOW_DIRTY_PACKAGE=1
export KOOKIE_VERSION="${KOOKIE_VERSION:-0.1.0-windows-presentation-smoke}"
export KOOKIE_BUILD_ID="${KOOKIE_BUILD_ID:-windows-presentation-smoke}"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1704067200}"

for release in release-a release-b; do
  "$ROOT_DIR/scripts/package_kookie.sh" --runtime presentation \
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
python3 - "$ARCHIVE" "$MANIFEST" "$EXTRACTED" "$SOURCE_DATE_EPOCH" <<'PY'
import hashlib
import json
import pathlib
import stat
import sys
import zipfile

archive_path = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
destination = pathlib.Path(sys.argv[3])
expected_epoch = int(sys.argv[4])
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
assert manifest["runtime"] == "presentation"
assert manifest["windows_presentation"] is True
assert manifest["windows_java_runtime"] is False
assert manifest["windows_java_version"] == "not-bundled"
assert manifest["windows_dxc_version"] != "not-bundled"
assert manifest["source_date_epoch"] == expected_epoch
assert manifest["sha256"] == hashlib.sha256(archive_path.read_bytes()).hexdigest()
root = destination / archive_path.stem
for relative in (
    "kookie.cmd",
    "kookie.exe",
    "build/SDL3.dll",
    "build/SDL3_mixer.dll",
    "SDL3.dll",
    "SDL3_mixer.dll",
    "build/g0_triangle.vert.spv",
    "build/g5_triangle_instance.vert.spv",
    "build/g0_triangle.frag.spv",
    "build/g0_triangle.vert.dxil",
    "build/g5_triangle_instance.vert.dxil",
    "build/g0_triangle.frag.dxil",
):
    assert (root / relative).is_file(), relative
assert (root / "kookie.exe").read_bytes()[:2] == b"MZ"
assert not (root / "kookie.jar").exists()
assert not (root / "runtime").exists()
launcher = (root / "kookie.cmd").read_text(encoding="utf-8")
assert '"%ROOT%kookie.exe" %*' in launcher
assert "cd /d \"%ROOT%\"" in launcher
provenance = dict(
    line.split("=", 1)
    for line in (root / "PROVENANCE.txt").read_text(encoding="utf-8").splitlines()
    if "=" in line
)
assert provenance["windows_status"] == "kof-native-pe-sdl-gpu-bundled-runtime"
assert provenance["dependency_policy"] == "bundled-sdl-and-shader-assets-license-files-retained"
assert provenance["runtime_dependencies"] == "Kof-PE+SDL3+SDL_mixer+SPIR-V+DXIL"
PY

if [[ "${KOOKIE_RUN_WINE:-0}" == 1 ]]; then
  command -v wine >/dev/null || {
    echo 'verify_windows_presentation: KOOKIE_RUN_WINE=1 requires wine' >&2
    exit 2
  }
  command -v overzeer-isolated-display >/dev/null || {
    echo 'verify_windows_presentation: KOOKIE_RUN_WINE=1 requires overzeer-isolated-display' >&2
    exit 2
  }
  WINE_ROOT="$ROOT_DIR/build/g6-wine"
  WINE_PACKAGE="$WINE_ROOT/presentation"
  WINE_PREFIX="$WINE_ROOT/prefix"
  rm -rf -- "$WINE_PACKAGE"
  mkdir -p "$WINE_ROOT"
  cp -a -- "$EXTRACTED/$PACKAGE_NAME" "$WINE_PACKAGE"
  export WINEPREFIX="$WINE_PREFIX"
  export WINEARCH=win64
  export WINEDLLOVERRIDES='mscoree,mshtml='
  export WINEDEBUG=-all
  export SDL_AUDIODRIVER=dummy
  export KOOKIE_PRESENTATION_SMOKE=1
  export KOOKIE_SCREENSHOT_PATH="$WINE_PACKAGE/smoke.ppm"
  overzeer-isolated-display --timeout 240 -- bash -c '
    cd "$1"
    exec wine kookie.exe
  ' verify_windows_presentation "$WINE_PACKAGE" >"$WORK_DIR/wine.log" 2>&1
  python3 - "$WORK_DIR/wine.log" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
for marker in (
    "KOOKIE G1 native arena HUD verified",
    "KOOKIE G2 native 3D door verified",
    "KOOKIE G4 GPU-safe kutter reload verified",
    "KOOKIE native kutter screen verified",
    "KOOKIE native SDL adapter verified",
):
    assert marker in text, marker
PY
fi

printf 'KOOKIE Windows presentation package passed: reproducible signed artifact, native Kof PE gameplay, native SDL3/SDL_mixer adapter, SPIR-V/DXIL shaders%s\n' \
  "$( [[ "${KOOKIE_RUN_WINE:-0}" == 1 ]] && printf ', isolated Wine smoke' )"
