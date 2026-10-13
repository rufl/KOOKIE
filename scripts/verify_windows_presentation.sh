#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v openssl >/dev/null || { echo 'verify_windows_presentation: openssl is required' >&2; exit 2; }
command -v python3 >/dev/null || { echo 'verify_windows_presentation: python3 is required' >&2; exit 2; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-windows-presentation-smoke.XXXXXX")"
PRESENTATION_EVIDENCE_DIR="${KOOKIE_PRESENTATION_EVIDENCE_DIR:-}"
cleanup() {
  if [[ -n "$PRESENTATION_EVIDENCE_DIR" ]]; then
    mkdir -p "$PRESENTATION_EVIDENCE_DIR"
    for evidence_file in native.log native-presentation.ppm native-evidence.json wine.log; do
      if [[ -f "$WORK_DIR/$evidence_file" ]]; then
        cp -- "$WORK_DIR/$evidence_file" "$PRESENTATION_EVIDENCE_DIR/"
      fi
    done
    if [[ -f "$WORK_DIR/native-evidence.json" ]]; then
      cp -- "$WORK_DIR/native-evidence.json" \
        "$PRESENTATION_EVIDENCE_DIR/evidence.json"
    fi
  fi
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM
PACKAGE_DIR="${KOOKIE_PACKAGE_DIR:-}"
if [[ -n "$PACKAGE_DIR" ]]; then
  [[ -d "$PACKAGE_DIR" ]] || {
    echo 'verify_windows_presentation: KOOKIE_PACKAGE_DIR is not a directory' >&2
    exit 2
  }
  RELEASE_DIR="$(cd "$PACKAGE_DIR" && pwd)"
  PACKAGE_NAME="${KOOKIE_PACKAGE_NAME:?set KOOKIE_PACKAGE_NAME with KOOKIE_PACKAGE_DIR}"
  EXPECTED_SOURCE_DATE_EPOCH=""
else
  : "${KOOKIE_KOF_ARCHIVE_SHA256:?set KOOKIE_KOF_ARCHIVE_SHA256 to the pinned Kof distribution digest}"
  : "${KOOKIE_KOF_SOURCE_COMMIT:?set KOOKIE_KOF_SOURCE_COMMIT to the pinned Kof source commit}"
  : "${KOOKIE_WINDOWS_SDL_PREFIX:?set KOOKIE_WINDOWS_SDL_PREFIX to the SDL3 MinGW prefix}"
  : "${KOOKIE_WINDOWS_SDL_MIXER_PREFIX:?set KOOKIE_WINDOWS_SDL_MIXER_PREFIX to the SDL_mixer MinGW prefix}"
  : "${KOOKIE_DXC:?set KOOKIE_DXC to the pinned dxc executable}"
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
  RELEASE_DIR="$WORK_DIR/release-a"
  EXPECTED_SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH"
fi
export KOOKIE_CONTENT_PROFILE=none

ARCHIVE_NAME="$PACKAGE_NAME.zip"
for artifact in \
  "$ARCHIVE_NAME" "$ARCHIVE_NAME.sig" "$PACKAGE_NAME.json" \
  "$PACKAGE_NAME.json.sig" "$PACKAGE_NAME.pub.pem" SHA256SUMS SHA256SUMS.sig; do
  [[ -f "$RELEASE_DIR/$artifact" ]] || {
    echo "verify_windows_presentation: missing artifact $RELEASE_DIR/$artifact" >&2
    exit 1
  }
  if [[ -z "$PACKAGE_DIR" ]]; then
    cmp "$RELEASE_DIR/$artifact" "$WORK_DIR/release-b/$artifact"
  fi
done
(
  cd "$RELEASE_DIR"
  sha256sum --check SHA256SUMS >/dev/null
)
PUBLIC_KEY="$RELEASE_DIR/$PACKAGE_NAME.pub.pem"
ARCHIVE="$RELEASE_DIR/$ARCHIVE_NAME"
MANIFEST="$RELEASE_DIR/$PACKAGE_NAME.json"
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$ARCHIVE" -sigfile "$ARCHIVE.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$MANIFEST" -sigfile "$MANIFEST.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$RELEASE_DIR/SHA256SUMS" -sigfile "$RELEASE_DIR/SHA256SUMS.sig" >/dev/null

EXTRACTED="$WORK_DIR/extracted"
python3 - "$ARCHIVE" "$MANIFEST" "$EXTRACTED" "$EXPECTED_SOURCE_DATE_EPOCH" <<'PY'
import hashlib
import json
import pathlib
import stat
import sys
import zipfile

archive_path = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
destination = pathlib.Path(sys.argv[3])
expected_epoch = int(sys.argv[4]) if sys.argv[4] else None
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
assert manifest["content_profile"] == "none"
assert manifest["windows_dxc_version"] != "not-bundled"
if expected_epoch is not None:
    assert manifest["source_date_epoch"] == expected_epoch
assert manifest["sha256"] == hashlib.sha256(archive_path.read_bytes()).hexdigest()
root = destination / archive_path.stem
for relative in (
    "kookie.cmd",
    "kookie.exe",
    "kookie-launcher.exe",
    "kookie-launcher.cmd",
    "kookie-visual.exe",
    "build/SDL3.dll",
    "SDL3.dll",
    "SDL3_mixer.dll",
    "build/g0_triangle.vert.spv",
    "build/g5_triangle_instance.vert.spv",
    "build/g6_world.vert.spv",
    "build/g0_triangle.frag.spv",
    "build/g0_triangle.vert.dxil",
    "build/g5_triangle_instance.vert.dxil",
    "build/g6_world.vert.dxil",
    "build/g0_triangle.frag.dxil",
    "RELEASE_PUBLIC_KEY.pem",
    "fonts/jared-lite.ttf",
    "fonts/pixand.ttf",
    "fonts/OFL.txt",
    "fonts/readme.txt",
    "fonts/manifest.json",
):
    assert (root / relative).is_file(), relative
assert (root / "kookie.exe").read_bytes()[:2] == b"MZ"
assert (root / "kookie-launcher.exe").read_bytes()[:2] == b"MZ"
assert not (root / "kookie.jar").exists()
assert not (root / "runtime").exists()
launcher = (root / "kookie.cmd").read_text(encoding="utf-8")
assert '"%ROOT%kookie.exe" %*' in launcher
assert "cd /d \"%ROOT%\"" in launcher
update_launcher = (root / "kookie-launcher.cmd").read_text(encoding="utf-8")
assert '"%ROOT%kookie-launcher.exe" %*' in update_launcher
assert "cd /d \"%ROOT%\"" not in update_launcher
provenance = dict(
    line.split("=", 1)
    for line in (root / "PROVENANCE.txt").read_text(encoding="utf-8").splitlines()
    if "=" in line
)
assert provenance["windows_status"] == "kof-native-pe-sdl-gpu-bundled-runtime"
assert provenance["dependency_policy"] == "bundled-sdl-and-shader-assets-license-files-retained"
assert provenance["runtime_dependencies"] == "Kof-PE+SDL3+SDL_mixer+SPIR-V+DXIL"
assert provenance["game_display_name"] == "GatoGanso"
assert provenance["font_default_body"] == "Jared-Lite"
assert provenance["font_default_display"] == "Pixand"
assert provenance["update_launcher"] == "kookie-launcher"
PY
PACKAGE_SMOKE_LOG="$WORK_DIR/windows-package-smoke.log"
set +e
"$EXTRACTED/$PACKAGE_NAME/kookie.exe" --package-smoke \
  >"$PACKAGE_SMOKE_LOG" 2>&1
package_smoke_status=$?
set -e
cat "$PACKAGE_SMOKE_LOG"
if [[ "$package_smoke_status" != 0 ]]; then
  echo "verify_windows_presentation: Windows PE package smoke failed with status $package_smoke_status" >&2
  exit "$package_smoke_status"
fi

package_source_commit="$(
  python3 - "$MANIFEST" <<'PY'
import json
import pathlib
import sys

value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")).get(
    "source_commit")
if not isinstance(value, str) or len(value) != 40 or any(
        character not in "0123456789abcdef" for character in value):
    raise SystemExit("package manifest has an invalid source commit")
print(value)
PY
)"
export KOOKIE_PRESENTATION_SOURCE_COMMIT="$package_source_commit"
export KOOKIE_PRESENTATION_PACKAGE_ARCHIVE_SHA256="$(
  sha256sum "$ARCHIVE" | cut -d ' ' -f 1
)"
export KOOKIE_PRESENTATION_PACKAGE_MANIFEST_SHA256="$(
  sha256sum "$MANIFEST" | cut -d ' ' -f 1
)"

if [[ "${KOOKIE_RUN_NATIVE_PRESENTATION:-0}" == 1 ]]; then
  : "${KOOKIE_PRESENTATION_HARDWARE_ID:?KOOKIE_RUN_NATIVE_PRESENTATION=1 requires KOOKIE_PRESENTATION_HARDWARE_ID}"
  : "${KOOKIE_PRESENTATION_GPU_DRIVER:?KOOKIE_RUN_NATIVE_PRESENTATION=1 requires KOOKIE_PRESENTATION_GPU_DRIVER}"

  native_wrapper="${KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER:-}"
  [[ -n "$native_wrapper" ]] && command -v "$native_wrapper" >/dev/null || {
    echo 'verify_windows_presentation: KOOKIE_RUN_NATIVE_PRESENTATION=1 requires KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER' >&2
    exit 75
  }
  native_command_shell="${KOOKIE_WINDOWS_NATIVE_COMMAND_SHELL:-C:\Windows\System32\cmd.exe}"
  NATIVE_ROOT="$WORK_DIR/native-presentation"
  mkdir -p "$NATIVE_ROOT"
  NATIVE_PACKAGE="$NATIVE_ROOT/$PACKAGE_NAME"
  cp -a -- "$EXTRACTED/$PACKAGE_NAME" "$NATIVE_ROOT"
  native_screenshot="$WORK_DIR/native-presentation.ppm"
  native_evidence="$WORK_DIR/native-evidence.json"
  command -v cygpath >/dev/null || {
    echo 'verify_windows_presentation: cygpath is required for native Windows isolation' >&2
    exit 2
  }
  native_package_path="$(cygpath -w "$NATIVE_PACKAGE")"
  native_screenshot_path="$(cygpath -w "$native_screenshot")"
  native_evidence_path="$(cygpath -w "$native_evidence")"
  native_runtime_log="$WORK_DIR/native-wrapper-runtime.log"
  native_runtime_log_path="$(cygpath -w "$native_runtime_log")"
  export KOOKIE_PRESENTATION_ISOLATION_WRAPPER="$native_wrapper"
  export KOOKIE_PRESENTATION_SMOKE=1
  export KOOKIE_SHADER_DIR="$native_package_path/build"
  export KOOKIE_SCREENSHOT_PATH="$native_screenshot_path"
  export KOOKIE_PRESENTATION_EVIDENCE_JSON="$native_evidence_path"
  export KOOKIE_NATIVE_PACKAGE="$NATIVE_PACKAGE"
  unset SDL_AUDIODRIVER || true
  runtime_command="$WORK_DIR/native-runtime.cmd"
  cat >"$runtime_command" <<EOF
@echo off
echo KOOKIE Windows isolated desktop runtime probe > "$native_runtime_log_path"
exit /b 0
EOF
  runtime_command_path="$(cygpath -w "$runtime_command")"
  set +e
  KOOKIE_WINDOWS_BASH="$native_command_shell" \
    KOOKIE_WINDOWS_ISOLATED_DEBUG=1 \
    KOOKIE_WINDOWS_ISOLATED_NO_STD_HANDLES=1 "$native_wrapper" \
    --timeout "${KOOKIE_PRESENTATION_TIMEOUT:-240}" -- \
    /c call "$runtime_command_path" \
    >"$WORK_DIR/native-wrapper-runtime-host.log" 2>&1
  runtime_probe_status=$?
  set -e
  cat "$WORK_DIR/native-wrapper-runtime-host.log"
  if [[ ! -f "$native_runtime_log" ]]; then
    echo "verify_windows_presentation: isolated runtime script did not create $native_runtime_log" >&2
    cat "$runtime_command"
    exit 1
  fi
  cat "$native_runtime_log"
  if [[ "$runtime_probe_status" != 0 ]]; then
    echo "verify_windows_presentation: Windows isolated runtime probe failed with status $runtime_probe_status" >&2
    exit "$runtime_probe_status"
  fi
  wrapper_probe="$WORK_DIR/native-wrapper-probe.cmd"
  wrapper_probe_log="$WORK_DIR/native-wrapper.log"
  wrapper_probe_log_path="$(cygpath -w "$wrapper_probe_log")"
  cat >"$wrapper_probe" <<EOF
@echo off
echo KOOKIE Windows isolated desktop wrapper probe > "$wrapper_probe_log_path"
echo KOOKIE_NATIVE_PACKAGE=$native_package_path >> "$wrapper_probe_log_path"
if not exist "$native_package_path\kookie.exe" (
  echo missing kookie.exe >> "$wrapper_probe_log_path"
  exit /b 1
)
exit /b 0
EOF
  wrapper_probe_command="$(cygpath -w "$wrapper_probe")"
  set +e
  KOOKIE_WINDOWS_BASH="$native_command_shell" \
    KOOKIE_WINDOWS_ISOLATED_NO_STD_HANDLES=1 "$native_wrapper" \
    --timeout "${KOOKIE_PRESENTATION_TIMEOUT:-240}" -- \
    /c call "$wrapper_probe_command" \
    >"$WORK_DIR/native-wrapper-host.log" 2>&1
  wrapper_status=$?
  set -e
  cat "$wrapper_probe_log"
  if [[ "$wrapper_status" != 0 ]]; then
    echo "verify_windows_presentation: Windows wrapper probe failed with status $wrapper_status" >&2
    exit "$wrapper_status"
  fi

  native_command="$WORK_DIR/native-run.cmd"
  native_log="$WORK_DIR/native.log"
  native_log_path="$(cygpath -w "$native_log")"
  cat >"$native_command" <<EOF
@echo off
cd /d "$native_package_path"
"$native_package_path\kookie.exe" > "$native_log_path" 2>&1
exit /b %ERRORLEVEL%
EOF
  native_command_path="$(cygpath -w "$native_command")"
  set +e
  KOOKIE_WINDOWS_BASH="$native_command_shell" \
    KOOKIE_WINDOWS_ISOLATED_NO_STD_HANDLES=1 "$native_wrapper" \
    --timeout "${KOOKIE_PRESENTATION_TIMEOUT:-240}" -- \
    /c call "$native_command_path" \
    >"$WORK_DIR/native-host.log" 2>&1
  native_status=$?
  set -e
  cat "$native_log"
  python3 "$ROOT_DIR/scripts/validate_presentation_evidence.py" \
    "$WORK_DIR/native.log" "$native_screenshot" "$native_evidence" \
    --require-hardware-metadata >/dev/null
fi

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
    "KOOKIE D1 authoritative gameplay verified",
    "KOOKIE D1 Play restart exit verified",
    "KOOKIE G2 native 3D door verified",
    "KOOKIE G4 GPU-safe kutter reload verified",
    "KOOKIE G7 native presentation durable save verified",
    "KOOKIE native kutter screen verified",
    "KOOKIE native SDL adapter verified",
    assert marker in text, marker
PY
fi

presentation_suffix=""
if [[ "${KOOKIE_RUN_NATIVE_PRESENTATION:-0}" == 1 ]]; then
  presentation_suffix="${presentation_suffix}, isolated native presentation smoke"
fi
if [[ "${KOOKIE_RUN_WINE:-0}" == 1 ]]; then
  presentation_suffix="${presentation_suffix}, isolated Wine smoke"
fi
printf 'KOOKIE Windows presentation package passed: reproducible signed artifact, native Kof PE gameplay, native SDL3/SDL_mixer adapter, SPIR-V/DXIL shaders%s\n' \
  "$presentation_suffix"
