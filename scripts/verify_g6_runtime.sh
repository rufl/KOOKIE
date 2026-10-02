#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v kof >/dev/null || { echo 'verify_g6_runtime: kof is required' >&2; exit 2; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kookie-g6-runtime.XXXXXX")"
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT INT TERM

stage_package() {
  local probe="$1"
  shift
  local package
  mkdir -p "$WORK_DIR/$probe"
  cp -- "$ROOT_DIR/probes/$probe/main.kf" "$WORK_DIR/$probe/main.kf"
  for package in "$@"; do
    mkdir -p "$WORK_DIR/$probe/$package"
    local source
    for source in "$ROOT_DIR/src/$package"/*.kf; do
      ln -s -- "$source" "$WORK_DIR/$probe/$package/$(basename "$source")"
    done
  done
}

run_probe() {
  local probe="$1"
  local marker="$2"
  local output
  output="$(cd "$WORK_DIR/$probe" &&
    kof build main.kf --target native --output build/native >/dev/null &&
    ./build/native/Default/Main)"
  [[ "$output" == *"$marker"* ]] || {
    printf '%s\n' "$output" >&2
    echo "verify_g6_runtime: marker missing for $probe: $marker" >&2
    exit 1
  }
  printf '%s\n' "$output"
}

stage_package g6_kofscript_package core content session
stage_package g6_kutter core content session ui
stage_package g6_wan core content session
stage_package g6_jobs core
mkdir -p "$WORK_DIR/g6_jobs/build"
cc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
  "$ROOT_DIR/native/kookie_jobs.c" -pthread \
  -o "$WORK_DIR/g6_jobs/build/libkookie_jobs.so"

run_probe g6_jobs 'KOOKIE G6 safe jobs verified'
run_probe g6_kofscript_package 'KOOKIE G6 KofScript package verified'
run_probe g6_kutter 'KOOKIE G6 persistent Kutter verified'
run_probe g6_wan 'KOOKIE G6 limited WAN verified'
python3 "$ROOT_DIR/scripts/verify_wan_rendezvous.py"

printf 'KOOKIE G6 runtime probes passed: jobs, KofScript package/session, persistent Kutter, limited WAN, and rendezvous punchthrough\n'
