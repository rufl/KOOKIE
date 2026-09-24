#include "kookie_simd_dispatch.h"

#include <stdint.h>
#include <stdio.h>

static int expected_sum(const int32_t *values, size_t count, int64_t *result) {
    size_t i;
    *result = 0;
    for (i = 0; i < count; ++i) {
        *result += values[i];
    }
    return 0;
}

int main(void) {
    static const int32_t values[] = {
        INT32_MIN, -1000003, -7, -1, 0, 1, 9, 1000003, INT32_MAX,
        -31, 47, 1024, -2048, 8192, -16384, 65536, -131072
    };
    int64_t expected;
    int64_t actual;
    KookieSimdPath path;

    expected_sum(values, sizeof(values) / sizeof(values[0]), &expected);
    path = kookie_simd_path();
    if (kookie_simd_sum_i32(values, sizeof(values) / sizeof(values[0]), &actual) != 0 || actual != expected) {
        fprintf(stderr, "SIMD sum mismatch: path=%d expected=%lld actual=%lld\n",
                (int)path, (long long)expected, (long long)actual);
        return 1;
    }
    if (kookie_simd_sum_i32(NULL, 0, &actual) != 0 || actual != 0) {
        fprintf(stderr, "empty input contract failed\n");
        return 1;
    }
    if (kookie_simd_sum_i32(NULL, 1, &actual) == 0) {
        fprintf(stderr, "invalid input contract failed\n");
        return 1;
    }
    printf("simd-path=%d sum=%lld\n", (int)path, (long long)actual);
    return 0;
}
