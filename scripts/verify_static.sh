#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
source "$root_dir/scripts/kof_pin.sh"
command -v kof >/dev/null || { echo 'verify_static: kof is required' >&2; exit 2; }
command -v python3 >/dev/null || { echo 'verify_static: python3 is required' >&2; exit 2; }

expected_kof_version="$KOF_PIN_CLI_VERSION"
actual_kof_version="$(kof version)"
[[ "$actual_kof_version" == "$expected_kof_version" ]] || {
  printf 'verify_static: expected %s; found %s\n' \
    "$expected_kof_version" "$actual_kof_version" >&2
  exit 2
}

python3 scripts/lint_kf.py src probes apps
python3 scripts/lsp_verify.py src
bash scripts/verify_font_assets.sh
KOOKIE_FONT_UI_TARGETS=jvm bash scripts/verify_font_ui.sh
KOOKIE_UI_LIBRARY_TARGETS=jvm bash scripts/verify_ui_library.sh
KOOKIE_UI_SOUND_TARGETS=jvm bash scripts/verify_ui_sound_catalog.sh
bash scripts/verify_ui_demo.sh
python3 scripts/lsp_verify.py probes
kof check src --target jvm
kof test src/main.kf --target jvm

printf 'KOOKIE static/JVM verification passed\n'
