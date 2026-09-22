#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

command -v kof >/dev/null || { echo "kof is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

python3 scripts/lint_kf.py src probes
python3 scripts/lsp_verify.py src
python3 scripts/lsp_verify.py probes

kof check src --target jvm
kof check src --target native

build_dir="$(mktemp -d -t kookie-build-XXXXXX)"
trap 'rm -rf "$build_dir"' EXIT
kof build src --target jvm --output "$build_dir/jvm"
kof build src --target native --output "$build_dir/native"

echo "KOOKIE verification passed: linter, LSP, JVM/native checks, and JVM/native builds"
