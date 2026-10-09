#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v kof >/dev/null || { echo 'verify_svg_intake: kof is required' >&2; exit 75; }
command -v gzip >/dev/null || { echo 'verify_svg_intake: gzip is required' >&2; exit 75; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-svg-intake.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

cat > "$WORK_DIR/valid.svg" <<'EOF'
<?xml version="1.0"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 100 80">
  <g>
    <rect x="2" y="3" width="20" height="10" fill="#f00"/>
    <circle cx="50" cy="40" r="8" fill="none" stroke="#00ff0080" stroke-width="2"/>
    <path d="M 5 5 L 20 5 l 0 10 H 5 V 5 Z" fill="blue"/>
    <polygon points="10,20 20,30 0,30" fill="white"/>
  </g>
</svg>
EOF

SVG_LOG="$WORK_DIR/svg.log"
SVG_OUTPUT="$WORK_DIR/valid.svgc"
"$ROOT_DIR/scripts/kooker.sh" cook svg "$WORK_DIR/valid.svg" "$SVG_OUTPUT" >"$SVG_LOG"
grep -Fq 'cooked kind=10' "$SVG_LOG"
grep -Fq 'shapes=4' "$SVG_LOG"
grep -Fq 'parameters=35' "$SVG_LOG"
grep -Fq 'material=927741' "$SVG_LOG"
"$ROOT_DIR/scripts/kooker.sh" cook svg "$SVG_OUTPUT" "$WORK_DIR/reopened.svgc" \
  >"$WORK_DIR/reopen.log"
cmp -- "$SVG_OUTPUT" "$WORK_DIR/reopened.svgc"

gzip -n -c "$WORK_DIR/valid.svg" >"$WORK_DIR/valid.svgz"
SVGZ_LOG="$WORK_DIR/svgz.log"
"$ROOT_DIR/scripts/kooker.sh" cook svgz "$WORK_DIR/valid.svgz" "$WORK_DIR/valid.svgzc" \
  >"$SVGZ_LOG"
grep -Fq 'cooked kind=11' "$SVGZ_LOG"
grep -Fq 'shapes=4' "$SVGZ_LOG"
grep -Fq 'parameters=35' "$SVGZ_LOG"

cat > "$WORK_DIR/invalid.svg" <<'EOF'
<svg viewBox="0 0 10 10"><script>alert(1)</script></svg>
EOF
if "$ROOT_DIR/scripts/kooker.sh" cook svg "$WORK_DIR/invalid.svg" "$WORK_DIR/invalid.out" \
    >"$WORK_DIR/invalid.log" 2>&1; then
  echo 'verify_svg_intake: unsupported SVG script was accepted' >&2
  exit 1
fi
grep -Fq 'cook-rejected diagnostic=3 source=6' "$WORK_DIR/invalid.log"

printf 'KOOKIE SVG/SVGZ intake verified: canonical reopen, gzip decode, and unsupported-element rejection\n'
