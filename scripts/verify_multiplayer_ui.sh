#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/kof_pin.sh"
work_dir="$(mktemp -d -t kookie-multiplayer-ui-XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT

cp "$root_dir/probes/g8_multiplayer_ui/main.kf" "$work_dir/main.kf"
for module in content core session ui world; do
  mkdir "$work_dir/$module"
  for source in "$root_dir/src/$module/"*.kf; do
    ln -s "$source" "$work_dir/$module/$(basename "$source")"
  done
done

jvm_status=0
jvm_output="$(cd "$work_dir" && \
  kookie_kof_observed multiplayer-ui-jvm kof run main.kf --target jvm)" || jvm_status=$?
if (( jvm_status != 0 )); then
  printf '%s\n' "$jvm_output" >&2
  exit "$jvm_status"
fi
mkdir -p "$work_dir/lib"
zig_bin="${ZIG:-zig}"
(
  cd "$root_dir"
  "$zig_bin" build check-box3d-adapter
  "$zig_bin" build -Drelease=true --prefix "$work_dir/zig-prefix"
)
cp "$work_dir/zig-prefix/lib/libkookie_box3d.so" "$work_dir/lib/"
native_status=0
native_output="$(cd "$work_dir" && \
  LD_LIBRARY_PATH="$work_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    kookie_kof_observed multiplayer-ui-native kof run main.kf --target native)" || native_status=$?
if (( native_status != 0 )); then
  printf '%s\n' "$native_output" >&2
  exit "$native_status"
fi
[[ "$jvm_output" == *"KOOKIE G8 multiplayer lobby scoreboard verified"* ]] || {
  printf '%s\n' "$jvm_output" >&2
  echo "verify_multiplayer_ui: JVM marker missing" >&2
  exit 1
}
[[ "$native_output" == *"KOOKIE G8 multiplayer lobby scoreboard verified"* ]] || {
  printf '%s\n' "$native_output" >&2
  echo "verify_multiplayer_ui: native marker missing" >&2
  exit 1
}
printf '%s\n%s\n' "$jvm_output" "$native_output"
