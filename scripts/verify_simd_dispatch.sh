#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/kof_pin.sh"
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
    kookie_kof_observed simd-benchmark-jvm kof run main.kf --target jvm
) >"$tmp/benchmark-jvm.log"; then
    cat "$tmp/benchmark-jvm.log" >&2
    exit 1
fi
if ! (
    cd "$benchmark_root"
    kookie_kof_observed simd-benchmark-native kof run main.kf --target native
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
    grep -Fqx 'buffer-fixture-sum=809' "$log"
    grep -Fqx 'buffer-inout-sum=1231' "$log"
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

syntax_proof_clang() {
    local target="$1"
    clang --target="$target" -ffreestanding -nostdinc \
        -isystem "$clang_resource_dir/include" \
        "${common[@]}" -fsyntax-only "$source"
    echo "$target syntax proof: passed"
}

syntax_proof_gcc() {
    local compiler="$1"
    local target="$2"
    "$compiler" "${common[@]}" -fsyntax-only "$source"
    echo "$target syntax proof: passed"
}

if command -v clang >/dev/null 2>&1; then
    # The freestanding source uses only compiler-provided headers, so these
    # proofs cover target code generation without requiring foreign libc/SDKs.
    clang_resource_dir=$(clang -print-resource-dir)
    for target in \
        aarch64-linux-gnu \
        riscv64-linux-gnu \
        x86_64-apple-darwin \
        aarch64-apple-darwin; do
        syntax_proof_clang "$target"
    done
else
    if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        syntax_proof_gcc aarch64-linux-gnu-gcc aarch64-linux-gnu
    else
        echo "aarch64 syntax proof: unavailable (install clang or aarch64-linux-gnu-gcc)" >&2
        exit 1
    fi
    if command -v riscv64-linux-gnu-gcc >/dev/null 2>&1; then
        syntax_proof_gcc riscv64-linux-gnu-gcc riscv64-linux-gnu
    else
        echo "riscv64 syntax proof: unavailable (install clang or riscv64-linux-gnu-gcc)" >&2
    fi
    echo "macOS syntax proofs: unavailable (install clang)" >&2
fi
