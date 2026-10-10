#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
: "${KOOKIE_KOF_ARCHIVE_SHA256:?set KOOKIE_KOF_ARCHIVE_SHA256 to the pinned Kof distribution digest}"
: "${KOOKIE_KOF_SOURCE_COMMIT:?set KOOKIE_KOF_SOURCE_COMMIT to the pinned Kof source commit}"

for command_name in cp find grep mkdir openssl python3 rm sha256sum tar; do
  command -v "$command_name" >/dev/null || {
    echo "verify_linux_presentation_package: $command_name is required" >&2
    exit 2
  }
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-linux-presentation-package.XXXXXX")"
PRESENTATION_STAGE=""
PRESENTATION_EVIDENCE_DIR="${KOOKIE_PRESENTATION_EVIDENCE_DIR:-}"
cleanup() {
  if [[ -n "$PRESENTATION_STAGE" &&
        -n "$PRESENTATION_EVIDENCE_DIR" &&
        -d "$PRESENTATION_STAGE" ]]; then
    mkdir -p "$PRESENTATION_EVIDENCE_DIR"
    cp -a -- "$PRESENTATION_STAGE/." "$PRESENTATION_EVIDENCE_DIR/"
  fi
  rm -rf -- "$WORK_DIR"
  if [[ -n "$PRESENTATION_STAGE" ]]; then
    rm -rf -- "$PRESENTATION_STAGE"
  fi
}
trap cleanup EXIT INT TERM

if [[ "${KOOKIE_CONTENT_PROFILE:-none}" != none ]]; then
  echo 'verify_linux_presentation_package: first demo uses content-profile=none' >&2
  exit 2
fi
export KOOKIE_CONTENT_PROFILE=none

PACKAGE_DIR="${KOOKIE_PACKAGE_DIR:-}"
if [[ -n "$PACKAGE_DIR" ]]; then
  [[ -d "$PACKAGE_DIR" ]] || {
    echo 'verify_linux_presentation_package: KOOKIE_PACKAGE_DIR is not a directory' >&2
    exit 2
  }
  RELEASE_DIR="$(cd "$PACKAGE_DIR" && pwd)"
  PACKAGE_NAME="${KOOKIE_PACKAGE_NAME:?set KOOKIE_PACKAGE_NAME with KOOKIE_PACKAGE_DIR}"
else
  SIGNING_KEY="${KOOKIE_SIGNING_KEY:-}"
  if [[ -z "$SIGNING_KEY" ]]; then
    SIGNING_KEY="$WORK_DIR/release-signing.pem"
    openssl genpkey -algorithm ED25519 -out "$SIGNING_KEY" 2>/dev/null
    chmod 600 "$SIGNING_KEY"
    export KOOKIE_SIGNING_KEY="$SIGNING_KEY"
  fi

  export KOOKIE_VERSION="${KOOKIE_VERSION:-0.1.0-linux-presentation-smoke}"
  export KOOKIE_BUILD_ID="${KOOKIE_BUILD_ID:-linux-presentation-smoke}"
  export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1704067200}"
  RELEASE_DIR="$WORK_DIR/release"
  "$ROOT_DIR/scripts/package_kookie.sh" \
    --runtime presentation --target linux-x86_64 --output "$RELEASE_DIR"
  PACKAGE_NAME="kookie-$KOOKIE_VERSION-linux-x86_64"
fi
ARCHIVE="$RELEASE_DIR/$PACKAGE_NAME.tar.gz"
MANIFEST="$RELEASE_DIR/$PACKAGE_NAME.json"
PUBLIC_KEY="$RELEASE_DIR/$PACKAGE_NAME.pub.pem"
for artifact in "$ARCHIVE" "$ARCHIVE.sig" "$MANIFEST" "$MANIFEST.sig" \
  "$PUBLIC_KEY" "$RELEASE_DIR/SHA256SUMS" "$RELEASE_DIR/SHA256SUMS.sig"; do
  [[ -f "$artifact" ]] || {
    echo "verify_linux_presentation_package: missing artifact $artifact" >&2
    exit 1
  }
done
(
  cd "$RELEASE_DIR"
  sha256sum --check SHA256SUMS >/dev/null
)
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$ARCHIVE" -sigfile "$ARCHIVE.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$MANIFEST" -sigfile "$MANIFEST.sig" >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey "$PUBLIC_KEY" \
  -in "$RELEASE_DIR/SHA256SUMS" -sigfile "$RELEASE_DIR/SHA256SUMS.sig" >/dev/null

EXTRACTED="$WORK_DIR/extracted"
mkdir -p "$EXTRACTED"
python3 - "$ARCHIVE" "$EXTRACTED" <<'PY'
import pathlib
import stat
import sys
import tarfile

archive = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
with tarfile.open(archive, "r:gz") as source:
    for entry in source.getmembers():
        relative = pathlib.PurePosixPath(entry.name)
        mode = entry.mode
        if (not entry.name or relative.is_absolute() or ".." in relative.parts
                or entry.issym() or entry.islnk()
                or (entry.isdir() and stat.S_IFMT(mode) not in (0, stat.S_IFDIR))
                or (entry.isfile() and stat.S_IFMT(mode) not in (0, stat.S_IFREG))):
            raise SystemExit(f"unsafe archive entry: {entry.name!r}")
    source.extractall(destination)
PY
PACKAGE_ROOT="$EXTRACTED/$PACKAGE_NAME"
[[ -d "$PACKAGE_ROOT" ]] || {
  echo "verify_linux_presentation_package: missing extracted root" >&2
  exit 1
}
for required in kookie kookie.bin kookie-launcher kookie-smoke.bin \
  build/libkookie_sdl_adapter.so build/libkookie_persistence_adapter.so \
  build/g0_triangle.vert.spv build/g5_triangle_instance.vert.spv \
  build/g6_world.vert.spv build/g0_triangle.frag.spv kookie-server \
  kookie-server.bin LICENSE \
  THIRD_PARTY_NOTICES.txt DEMO_CONTROLS.txt PROVENANCE.txt \
  RELEASE_PUBLIC_KEY.pem; do
  [[ -e "$PACKAGE_ROOT/$required" ]] || {
    echo "verify_linux_presentation_package: missing package entry $required" >&2
    exit 1
  }
done
for library_pattern in 'libSDL3.so*' 'libSDL3_mixer.so*'; do
  [[ -n "$(find "$PACKAGE_ROOT/lib" -maxdepth 1 -name "$library_pattern" \
    -print -quit)" ]] || {
    echo "verify_linux_presentation_package: missing package library $library_pattern" >&2
    exit 1
  }
done
[[ -x "$PACKAGE_ROOT/kookie" && -x "$PACKAGE_ROOT/kookie.bin" &&
  -x "$PACKAGE_ROOT/kookie-launcher" ]] || {
  echo 'verify_linux_presentation_package: launchers are not executable' >&2
  exit 1
}
"$PACKAGE_ROOT/kookie-launcher" --self-test

python3 - "$MANIFEST" "$ARCHIVE" "$PACKAGE_ROOT" "${SOURCE_DATE_EPOCH:-}" <<'PY'
import hashlib
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
archive = pathlib.Path(sys.argv[2])
package_root = pathlib.Path(sys.argv[3])
expected_epoch = int(sys.argv[4]) if sys.argv[4] else None
assert manifest["schema"] == "kookie.package-provenance/v2"
assert manifest["target"] == "linux-x86_64"
assert manifest["runtime"] == "presentation"
assert manifest["source_tree_state"] in {"clean", "dirty-allowed"}
if expected_epoch is not None:
    assert manifest["source_date_epoch"] == expected_epoch
assert manifest["sha256"] == hashlib.sha256(archive.read_bytes()).hexdigest()
assert manifest["signing"] == "ed25519"
assert manifest["windows_presentation"] is False
assert (package_root / "PROVENANCE.txt").is_file()
PY

PACKAGE_SMOKE_LOG="$WORK_DIR/package-smoke.log"
PACKAGE_SMOKE_OUTPUT="$(
  cd "$WORK_DIR"
  "$PACKAGE_ROOT/kookie" --package-smoke 2>"$WORK_DIR/package-smoke.err"
)" || {
  cat "$WORK_DIR/package-smoke.err" >&2
  exit 1
}
printf '%s\n' "$PACKAGE_SMOKE_OUTPUT" >"$PACKAGE_SMOKE_LOG"
grep -Fq 'KOOKIE G1 authoritative shooter verified' "$PACKAGE_SMOKE_LOG"

if [[ "${KOOKIE_RUN_PRESENTATION:-0}" == 1 ]]; then
  : "${KOOKIE_PRESENTATION_HARDWARE_ID:?KOOKIE_RUN_PRESENTATION=1 requires KOOKIE_PRESENTATION_HARDWARE_ID}"
  : "${KOOKIE_PRESENTATION_GPU_DRIVER:?KOOKIE_RUN_PRESENTATION=1 requires KOOKIE_PRESENTATION_GPU_DRIVER}"

  isolation_wrapper="${KOOKIE_PRESENTATION_ISOLATION_WRAPPER:-}"
  [[ -n "$isolation_wrapper" ]] && command -v "$isolation_wrapper" >/dev/null || {
    echo 'verify_linux_presentation_package: KOOKIE_RUN_PRESENTATION=1 requires KOOKIE_PRESENTATION_ISOLATION_WRAPPER' >&2
    exit 75
  }
  render_node="${KOOKIE_RENDER_NODE:-}"
  if [[ -z "$render_node" ]]; then
    for candidate in /dev/dri/renderD*; do
      if [[ -c "$candidate" ]]; then
        render_node="$candidate"
        break
      fi
    done
  fi
  [[ -n "$render_node" && -c "$render_node" ]] || {
    echo 'verify_linux_presentation_package: render node unavailable' >&2
    exit 75
  }
  export KOOKIE_RENDER_NODE="$render_node"
  export KOOKIE_SDL_VIDEO_DRIVER="${KOOKIE_SDL_VIDEO_DRIVER:-x11}"
  PRESENTATION_STAGE="$(mktemp -d "$ROOT_DIR/.kookie-presentation-stage.XXXXXX")"
  cp -a -- "$PACKAGE_ROOT" "$PRESENTATION_STAGE/"
  STAGED_PACKAGE_ROOT="$PRESENTATION_STAGE/$PACKAGE_NAME"
  export KOOKIE_SCREENSHOT_PATH="$PRESENTATION_STAGE/presentation.ppm"
  export KOOKIE_PRESENTATION_EVIDENCE_JSON="$PRESENTATION_STAGE/evidence.json"
  export KOOKIE_PRESENTATION_ADAPTER_LOG="$PRESENTATION_STAGE/presentation.log"
  export KOOKIE_PRESENTATION_COMMAND="package:$STAGED_PACKAGE_ROOT/kookie"
  set +e
  (
    cd "$ROOT_DIR"
    "$isolation_wrapper" --timeout "${KOOKIE_PRESENTATION_TIMEOUT:-240}" --render-node "$render_node" -- \
      env KOOKIE_PRESENTATION_SMOKE=1 \
        KOOKIE_TRANSPORT_KEY_HEX=00000001000000020000000300000004 \
        KOOKIE_SHADER_DIR="$STAGED_PACKAGE_ROOT/build" \
        SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER="$KOOKIE_SDL_VIDEO_DRIVER" \
        "$STAGED_PACKAGE_ROOT/kookie"
  ) >"$KOOKIE_PRESENTATION_ADAPTER_LOG" 2>&1
  presentation_status=$?
  set -e
  cat "$KOOKIE_PRESENTATION_ADAPTER_LOG"
  if [[ "$presentation_status" -ne 0 ]]; then
    exit "$presentation_status"
  fi
  grep -Fq 'KOOKIE G7 native presentation durable save verified' \
    "$KOOKIE_PRESENTATION_ADAPTER_LOG"
  KOOKIE_RENDER_NODE="$render_node" \
    python3 "$ROOT_DIR/scripts/validate_presentation_evidence.py" \
      "$KOOKIE_PRESENTATION_ADAPTER_LOG" \
      "$KOOKIE_SCREENSHOT_PATH" \
      "$KOOKIE_PRESENTATION_EVIDENCE_JSON" \
      --require-hardware-metadata >/dev/null
fi

printf 'KOOKIE Linux presentation package passed: signed artifact, safe extraction, package smoke%s\n' \
  "$( [[ "${KOOKIE_RUN_PRESENTATION:-0}" == 1 ]] && printf ', isolated presentation smoke' )"
