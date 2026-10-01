#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-verify-kof-pe.XXXXXX")"
WINE_WORK_DIR=''
cleanup() {
  rm -rf -- "$WORK_DIR"
  if [[ -n "$WINE_WORK_DIR" ]]; then rm -rf -- "$WINE_WORK_DIR"; fi
}
trap cleanup EXIT INT TERM

for tool in cc cmp file kof python3 zig; do
  command -v "$tool" >/dev/null || {
    echo "verify-kof-pe: $tool is required" >&2
    exit 2
  }
done

cat >"$WORK_DIR/main.kf" <<'KOF'
Int compute(Int start) {
    var value = start + 2
    var index = 0
    while (index < 3) {
        value = value + index
        index = index + 1
    }
    if (value == 47) {
        return value
    }
    return -1
}

Bool accepted(Int value) {
    return value >= 47
}

main() {
    var message = "kof-pe-ok"
    var result = compute(42)
    println(message)
    println(result)
    println(accepted(result))
}
KOF
cat >"$WORK_DIR/expected.txt" <<'EOF_EXPECTED'
kof-pe-ok
47
true
EOF_EXPECTED

"$ROOT_DIR/scripts/kof_pe_build.sh" "$WORK_DIR/main.kf" \
  --output "$WORK_DIR/build-a" >"$WORK_DIR/build-a.log"
"$ROOT_DIR/scripts/kof_pe_build.sh" "$WORK_DIR/main.kf" \
  --output "$WORK_DIR/build-b" >"$WORK_DIR/build-b.log"
for artifact in kof-module.c kof-module.obj kof-module.exe; do
  cmp "$WORK_DIR/build-a/$artifact" "$WORK_DIR/build-b/$artifact"
done

python3 - "$WORK_DIR/build-a/kof-module.obj" "$WORK_DIR/build-a/kof-module.exe" <<'PY'
import pathlib
import struct
import sys

obj = pathlib.Path(sys.argv[1]).read_bytes()
exe = pathlib.Path(sys.argv[2]).read_bytes()
if len(obj) < 20 or struct.unpack_from("<H", obj, 0)[0] != 0x8664:
    raise SystemExit("verify-kof-pe: object is not AMD64 COFF")
if exe[:2] != b"MZ" or len(exe) < 0x40:
    raise SystemExit("verify-kof-pe: executable is missing the DOS header")
pe = struct.unpack_from("<I", exe, 0x3C)[0]
if exe[pe:pe + 4] != b"PE\0\0":
    raise SystemExit("verify-kof-pe: executable is missing the PE signature")
if struct.unpack_from("<H", exe, pe + 4)[0] != 0x8664:
    raise SystemExit("verify-kof-pe: executable is not AMD64")
if struct.unpack_from("<I", exe, pe + 8)[0] != 0:
    raise SystemExit("verify-kof-pe: PE timestamp is not reproducible")
optional = pe + 24
if struct.unpack_from("<H", exe, optional)[0] != 0x20B:
    raise SystemExit("verify-kof-pe: executable is not PE32+")
if struct.unpack_from("<H", exe, optional + 68)[0] != 3:
    raise SystemExit("verify-kof-pe: executable is not a console subsystem image")
PY

obj_description="$(file "$WORK_DIR/build-a/kof-module.obj")"
exe_description="$(file "$WORK_DIR/build-a/kof-module.exe")"
[[ "$obj_description" == *'x86-64 COFF object'* ]] || {
  echo "verify-kof-pe: unexpected object description: $obj_description" >&2
  exit 1
}
[[ "$exe_description" == *'PE32+ executable'*'console'*'x86-64'* ]] || {
  echo "verify-kof-pe: unexpected executable description: $exe_description" >&2
  exit 1
}

cc -std=c11 -O2 -Wall -Wextra -Werror \
  "$WORK_DIR/build-a/kof-module.c" -o "$WORK_DIR/kof-module-host"
"$WORK_DIR/kof-module-host" >"$WORK_DIR/host-output.txt"
kof run "$WORK_DIR/main.kf" --target jvm >"$WORK_DIR/jvm-output.txt"
cmp "$WORK_DIR/expected.txt" "$WORK_DIR/host-output.txt"
cmp "$WORK_DIR/expected.txt" "$WORK_DIR/jvm-output.txt"

cat >"$WORK_DIR/unsupported.kf" <<'KOF_UNSUPPORTED'
class Box {
    Int value() {
        return 1
    }
}

main() {
    println("unsupported")
}
KOF_UNSUPPORTED
if "$ROOT_DIR/scripts/kof_pe_build.sh" "$WORK_DIR/unsupported.kf" \
    --output "$WORK_DIR/unsupported" >"$WORK_DIR/unsupported.out" \
    2>"$WORK_DIR/unsupported.err"; then
  echo 'verify-kof-pe: unsupported class unexpectedly produced PE output' >&2
  exit 1
fi
unsupported_error="$(<"$WORK_DIR/unsupported.err")"
[[ "$unsupported_error" == *'PE001: bounded target accepts only the generated top-level Main class'* ]] || {
  echo "verify-kof-pe: missing fail-closed PE001 diagnostic: $unsupported_error" >&2
  exit 1
}

if [[ "${KOOKIE_PE_WINE_SMOKE:-0}" == 1 ]]; then
  for tool in overzeer-isolated-display wine; do
    command -v "$tool" >/dev/null || {
      echo "verify-kof-pe: $tool is required for KOOKIE_PE_WINE_SMOKE=1" >&2
      exit 2
    }
  done
  mkdir -p "$ROOT_DIR/build"
  WINE_WORK_DIR="$(mktemp -d "$ROOT_DIR/build/kof-pe-wine.XXXXXX")"
  cp -- "$WORK_DIR/build-a/kof-module.exe" "$WINE_WORK_DIR/kof-module.exe"
  mkdir "$WINE_WORK_DIR/prefix"
  cat >"$WINE_WORK_DIR/run.sh" <<EOF_WINE
#!/bin/sh
set -u
export WINEDEBUG=-all
export WINEPREFIX='$WINE_WORK_DIR/prefix'
export WINEARCH=win64
export WINEDLLOVERRIDES='mscoree,mshtml='
cleanup_wine() { wineserver -k >/dev/null 2>&1 || true; }
trap cleanup_wine EXIT INT TERM
wine '$WINE_WORK_DIR/kof-module.exe'
EOF_WINE
  chmod +x "$WINE_WORK_DIR/run.sh"
  overzeer-isolated-display --timeout 180 -- \
    "$WINE_WORK_DIR/run.sh" >"$WORK_DIR/wine-output.txt"
  tr -d '\r' <"$WORK_DIR/wine-output.txt" >"$WORK_DIR/wine-output-normalized.txt"
  cmp "$WORK_DIR/expected.txt" "$WORK_DIR/wine-output-normalized.txt"
fi

echo 'Kof PE/COFF backend passed: deterministic AMD64 artifacts, JVM/host semantic parity, and PE001 rejection'
