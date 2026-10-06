#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for command_name in openssl python3 zig sha256sum; do
  command -v "$command_name" >/dev/null || {
    echo "verify_launcher: $command_name is required" >&2
    exit 2
  }
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-launcher-smoke.XXXXXX")"
SERVER_ROOT="$WORK_DIR/server"
SOURCE_ROOT="$WORK_DIR/source"
STATE_DIR="$WORK_DIR/state"
mkdir -p "$SERVER_ROOT" "$SOURCE_ROOT"
SERVER_PID=""
cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM

SIGNING_KEY="$WORK_DIR/signing.pem"
PUBLIC_KEY="$WORK_DIR/public.pem"
PUBLIC_KEY_DER="$WORK_DIR/public.der"
openssl genpkey -algorithm ED25519 -out "$SIGNING_KEY" 2>/dev/null
chmod 600 "$SIGNING_KEY"
openssl pkey -in "$SIGNING_KEY" -pubout -out "$PUBLIC_KEY" 2>/dev/null
openssl pkey -pubin -in "$PUBLIC_KEY" -outform DER -out "$PUBLIC_KEY_DER" 2>/dev/null
cp -- "$ROOT_DIR/launcher/kookie_launcher.zig" "$SOURCE_ROOT/kookie_launcher.zig"
cp -- "$PUBLIC_KEY" "$SOURCE_ROOT/RELEASE_PUBLIC_KEY.pem"
zig build-exe "$SOURCE_ROOT/kookie_launcher.zig" -O ReleaseSafe -fstrip \
  -femit-bin="$WORK_DIR/kookie-launcher"

VERSION=1.2.3
BUILD_ID=launcher-smoke
TARGET=linux-x86_64
PACKAGE_NAME="kookie-$VERSION-$TARGET"
ARCHIVE_NAME="$PACKAGE_NAME.tar.gz"
MANIFEST_NAME="$PACKAGE_NAME.json"
SIGNATURE_NAME="$MANIFEST_NAME.sig"
PACKAGE_ROOT="$SERVER_ROOT/$PACKAGE_NAME"
mkdir -p "$PACKAGE_ROOT"
cat > "$PACKAGE_ROOT/kookie" <<'EOF'
#!/usr/bin/env sh
set -eu
if [ "${1:-}" = "--package-smoke" ]; then
  printf '%s\n' 'KOOKIE launcher fixture package smoke passed'
  exit 0
fi
printf '%s\n' 'KOOKIE launcher fixture game launched'
EOF
chmod 755 "$PACKAGE_ROOT/kookie"
cp -- "$WORK_DIR/kookie-launcher" "$PACKAGE_ROOT/kookie-launcher"
chmod 755 "$PACKAGE_ROOT/kookie-launcher"
PACKAGE_SMOKE_OUTPUT="$("$PACKAGE_ROOT/kookie-launcher" --package-smoke 2>&1)"
grep -Fq 'KOOKIE launcher package smoke passed' <<<"$PACKAGE_SMOKE_OUTPUT"
python3 - "$SERVER_ROOT" "$PACKAGE_NAME" "$ARCHIVE_NAME" <<'PY'
import pathlib
import sys
import tarfile

server_root = pathlib.Path(sys.argv[1])
package_name = sys.argv[2]
archive_name = sys.argv[3]
package_root = server_root / package_name
with tarfile.open(server_root / archive_name, "w:gz") as archive:
    archive.add(package_root, arcname=package_name)
PY
ARCHIVE="$SERVER_ROOT/$ARCHIVE_NAME"
ARCHIVE_SIZE="$(stat -c '%s' "$ARCHIVE")"
ARCHIVE_SHA256="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
PUBLIC_KEY_SHA256="$(sha256sum "$PUBLIC_KEY_DER" | cut -d' ' -f1)"
MANIFEST="$SERVER_ROOT/$MANIFEST_NAME"
python3 - "$MANIFEST" "$ARCHIVE_NAME" "$ARCHIVE_SIZE" "$ARCHIVE_SHA256" "$PUBLIC_KEY_SHA256" <<'PY'
import json
import pathlib
import sys

manifest = {
    "schema": "kookie.package-provenance/v2",
    "application": "kookie",
    "channel": "dogfood",
    "version": "1.2.3",
    "target": "linux-x86_64",
    "build_id": "launcher-smoke",
    "runtime": "presentation",
    "archive": sys.argv[2],
    "size": int(sys.argv[3]),
    "sha256": sys.argv[4],
    "signing": "ed25519",
    "proof": "ed25519-signature-set",
    "public_key_sha256": sys.argv[5],
}
pathlib.Path(sys.argv[1]).write_text(
    json.dumps(manifest, separators=(",", ":")) + "\n", encoding="utf-8"
)
PY
openssl pkeyutl -sign -rawin -inkey "$SIGNING_KEY" -in "$MANIFEST" \
  -out "$SERVER_ROOT/$SIGNATURE_NAME" 2>/dev/null
python3 - "$SERVER_ROOT" "$ARCHIVE_NAME" "$MANIFEST_NAME" "$SIGNATURE_NAME" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
assets = []
for name in sys.argv[2:]:
    assets.append({
        "name": name,
        "size": (root / name).stat().st_size,
        "browser_download_url": f"http://127.0.0.1:PORT/{name}",
    })
(root / "releases.json").write_text(json.dumps([{
    "tag_name": "v1.2.3",
    "draft": False,
    "prerelease": True,
    "published_at": "2026-01-02T03:04:05Z",
    "assets": assets,
}]), encoding="utf-8")
PY
PORT="$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
python3 - "$SERVER_ROOT" "$PORT" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1]) / "releases.json"
text = path.read_text(encoding="utf-8").replace("PORT", sys.argv[2])
path.write_text(text, encoding="utf-8")
PY
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$SERVER_ROOT" \
  >"$WORK_DIR/http.log" 2>&1 &
SERVER_PID=$!
ready=0
for _ in $(seq 1 50); do
  if python3 - "http://127.0.0.1:$PORT/releases.json" 2>/dev/null <<'PY'
import sys
import urllib.request
with urllib.request.urlopen(sys.argv[1], timeout=1) as response:
    assert response.status == 200
PY
  then
    ready=1
    break
  fi
  sleep 0.1
done
[[ "$ready" == 1 ]]
kill -0 "$SERVER_PID"
API_URL="http://127.0.0.1:$PORT/releases.json"
BUNDLED_ROOT="$WORK_DIR/bundled"
BUNDLED_STATE="$WORK_DIR/bundled-state"
mkdir -p "$BUNDLED_ROOT"
cp -- "$PACKAGE_ROOT/kookie" "$BUNDLED_ROOT/kookie"
cp -- "$WORK_DIR/kookie-launcher" "$BUNDLED_ROOT/kookie-launcher"
chmod 755 "$BUNDLED_ROOT/kookie" "$BUNDLED_ROOT/kookie-launcher"
cat >"$BUNDLED_ROOT/PROVENANCE.txt" <<'EOF'
version=2.0.0
build_id=bundled-newer
EOF
"$BUNDLED_ROOT/kookie-launcher" --api-url "$API_URL" --state-dir "$BUNDLED_STATE" --no-launch \
  >"$WORK_DIR/bundled-newer.log" 2>&1
grep -Fq "active root=$BUNDLED_ROOT" "$WORK_DIR/bundled-newer.log"
test ! -e "$BUNDLED_STATE/active.json"

LAUNCHER="$WORK_DIR/kookie-launcher"

"$LAUNCHER" --api-url "$API_URL" --state-dir "$STATE_DIR" --no-launch \
  >"$WORK_DIR/first.log" 2>&1
grep -Fq 'active version=1.2.3 build=launcher-smoke' "$WORK_DIR/first.log"
ACTIVE_MARKER="$STATE_DIR/active.json"
test -s "$ACTIVE_MARKER"
cp -- "$ACTIVE_MARKER" "$WORK_DIR/active.before"
cp -- "$MANIFEST" "$WORK_DIR/manifest.original"
cp -- "$ARCHIVE" "$WORK_DIR/archive.original"

printf '\n' >>"$MANIFEST"
if "$LAUNCHER" --api-url "$API_URL" --state-dir "$STATE_DIR" --check --no-launch \
  >"$WORK_DIR/tampered-manifest.log" 2>&1; then
  echo 'verify_launcher: accepted a tampered manifest' >&2
  exit 1
fi
grep -Fq 'InvalidSignature' "$WORK_DIR/tampered-manifest.log"
cmp "$WORK_DIR/active.before" "$ACTIVE_MARKER"
cp -- "$WORK_DIR/manifest.original" "$MANIFEST"

rm -rf -- "$STATE_DIR/updates/$ARCHIVE_SHA256"
python3 - "$ARCHIVE" <<'PY'
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
data = bytearray(path.read_bytes())
data[0] ^= 1
path.write_bytes(data)
PY
if "$LAUNCHER" --api-url "$API_URL" --state-dir "$STATE_DIR" --check --no-launch \
  >"$WORK_DIR/tampered-archive.log" 2>&1; then
  echo 'verify_launcher: accepted an archive with the wrong digest' >&2
  exit 1
fi
grep -Fq 'ArtifactSha256Mismatch' "$WORK_DIR/tampered-archive.log"
cmp "$WORK_DIR/active.before" "$ACTIVE_MARKER"
cp -- "$WORK_DIR/archive.original" "$ARCHIVE"

"$LAUNCHER" --api-url "$API_URL" --state-dir "$STATE_DIR" --check --no-launch \
  >"$WORK_DIR/recovery.log" 2>&1
grep -Fq 'active version=1.2.3 build=launcher-smoke' "$WORK_DIR/recovery.log"
"$LAUNCHER" --offline --state-dir "$STATE_DIR" --no-launch \
  >"$WORK_DIR/offline.log" 2>&1
grep -Fq 'active root=' "$WORK_DIR/offline.log"

printf 'KOOKIE launcher updater smoke passed: signed discovery, atomic install, manifest rejection, archive digest rejection, offline fallback\n'
