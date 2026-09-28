#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cc=${CC:-cc}
common=(-std=c11 -O2 -Wall -Wextra -Werror -I"$root/native")
source="$root/native/kookie_simd_dispatch.c"
probe="$root/probes/g0_simd_dispatch.c"

"$cc" "${common[@]}" "$source" "$probe" -o "$tmp/simd-host"
"$tmp/simd-host"

"$cc" "${common[@]}" -DKOOKIE_SIMD_FORCE_SCALAR "$source" "$probe" -o "$tmp/simd-scalar"
"$tmp/simd-scalar"

if command -v clang >/dev/null 2>&1; then
    # This is a syntax proof, not a libc/linking check. Never mix host libc
    # headers with the AArch64 target; the kernel uses only freestanding C11.
    clang_resource_dir=$(clang -print-resource-dir)
    clang --target=aarch64-linux-gnu -ffreestanding -nostdinc \
        -isystem "$clang_resource_dir/include" \
        "${common[@]}" -fsyntax-only "$source"
    echo "aarch64 syntax proof: passed"
elif command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    aarch64-linux-gnu-gcc "${common[@]}" -fsyntax-only "$source"
    echo "aarch64 syntax proof: passed"
else
    echo "aarch64 syntax proof: unavailable (install clang or aarch64-linux-gnu-gcc)" >&2
    exit 1
fi
