#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kookie-external-lan-parity.XXXXXX")"
cleanup() { rm -rf -- "$work_dir"; }
trap cleanup EXIT INT TERM

run_target() {
  local target="$1"
  local evidence_dir="$work_dir/$target"
  mkdir -p "$evidence_dir"
  KOOKIE_EXTERNAL_LAN_TARGET="$target" \
    KOOKIE_EXTERNAL_LAN_EVIDENCE_DIR="$evidence_dir" \
    KOOKIE_EXTERNAL_LAN_EVIDENCE_JSON="$evidence_dir/evidence.json" \
    bash scripts/verify_external_lan.sh >"$evidence_dir/run.log"
}

run_target jvm
run_target native

python3 - "$work_dir/jvm/evidence.json" "$work_dir/native/evidence.json" <<'PY'
import json
import sys


def canonical(path):
    with open(path, encoding="utf-8") as handle:
        value = json.load(handle)
    value.pop("command", None)
    value.pop("probeOutputSha256", None)
    value.pop("probeLog", None)
    return value

jvm = canonical(sys.argv[1])
native = canonical(sys.argv[2])
if jvm != native:
    print("external-lan-parity-mismatch", file=sys.stderr)
    print(json.dumps({"jvm": jvm, "native": native}, sort_keys=True), file=sys.stderr)
    raise SystemExit(1)
print("external-lan-parity=ok")
print("external-lan-codec=ok")
print("external-lan-mac-and-key-ownership=unchanged")
PY
