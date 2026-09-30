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

benchmark_root="$tmp/benchmark"
mkdir -p "$benchmark_root/lib"
cp -- "$root/apps/simd_benchmark/main.kf" "$benchmark_root/main.kf"
"$cc" "${common[@]}" -fPIC -shared "$source" \
    -o "$benchmark_root/lib/libkookie_simd_dispatch.so"
"$cc" -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
    -I"$root/native" "$root/native/kookie_transport.c" \
    -o "$benchmark_root/lib/libkookie_headless_adapter.so"

if ! (
    cd "$benchmark_root"
    kof run main.kf --target jvm
) >"$tmp/benchmark-jvm.log"; then
    cat "$tmp/benchmark-jvm.log" >&2
    exit 1
fi
if ! (
    cd "$benchmark_root"
    kof run main.kf --target native
) >"$tmp/benchmark-native.log"; then
    cat "$tmp/benchmark-native.log" >&2
    exit 1
fi

expected_total=16844324864
for runtime in jvm native; do
    log="$tmp/benchmark-$runtime.log"
    grep -Fqx 'KOOKIE G6 Kof Buffer SIMD benchmark' "$log"
    grep -Eq '^simd-path=[1-4]$' "$log"
    grep -Fqx 'bytes=1048576' "$log"
    grep -Fqx 'rounds=64' "$log"
    grep -Fqx 'sum=263192576' "$log"
    grep -Fqx "scalar-total=$expected_total" "$log"
    grep -Fqx "simd-total=$expected_total" "$log"
    grep -Fqx "expected-total=$expected_total" "$log"
    grep -Eq '^scalar-ns=[1-9][0-9]*$' "$log"
    grep -Eq '^simd-ns=[1-9][0-9]*$' "$log"
    grep -Eq '^selected-route=(scalar|simd)$' "$log"
done
if [[ "${KOOKIE_SIMD_REQUIRE_SPEEDUP:-0}" == 1 ]]; then
    grep -Fqx 'selected-route=simd' "$tmp/benchmark-native.log"
fi
cat "$tmp/benchmark-jvm.log"
cat "$tmp/benchmark-native.log"

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
