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
    static const size_t u8_counts[] = {
        0, 1, 15, 16, 17, 31, 32, 33, 63, 64, 65, 97
    };
    uint8_t bytes[97];
    int64_t expected;
    int64_t actual;
    int64_t i32_sum;
    int64_t u8_sum = 0;
    KookieSimdPath path;

    for (size_t i = 0; i < sizeof(bytes); ++i) {
        bytes[i] = (uint8_t)((i * 37U + 251U) & 255U);
    }
    expected_sum(values, sizeof(values) / sizeof(values[0]), &expected);
    path = kookie_simd_path();
    if (kookie_simd_sum_i32(
            values, sizeof(values) / sizeof(values[0]), &actual) != 0 ||
        actual != expected) {
        fprintf(stderr, "SIMD i32 sum mismatch: path=%d expected=%lld actual=%lld\n",
                (int)path, (long long)expected, (long long)actual);
        return 1;
    }
    i32_sum = actual;
    if (kookie_simd_sum_i32(NULL, 0, &actual) != 0 || actual != 0) {
        fprintf(stderr, "empty i32 input contract failed\n");
        return 1;
    }
    if (kookie_simd_sum_i32(NULL, 1, &actual) == 0) {
        fprintf(stderr, "invalid i32 input contract failed\n");
        return 1;
    }
    for (size_t count_index = 0;
         count_index < sizeof(u8_counts) / sizeof(u8_counts[0]);
         ++count_index) {
        size_t count = u8_counts[count_index];
        expected = 0;
        for (size_t i = 0; i < count; ++i) {
            expected += bytes[i];
        }
        if (kookie_simd_sum_u8(bytes, count, &actual) != 0 ||
            actual != expected ||
            kookie_simd_sum_u8_buffer(bytes, (int32_t)count) != expected) {
            fprintf(stderr,
                    "SIMD u8 sum mismatch: path=%d count=%zu expected=%lld actual=%lld\n",
                    (int)path, count, (long long)expected, (long long)actual);
            return 1;
        }
        u8_sum = actual;
    }
    if (kookie_simd_sum_u8(NULL, 0, &actual) != 0 || actual != 0 ||
        kookie_simd_sum_u8(NULL, 1, &actual) == 0 ||
        kookie_simd_sum_u8_buffer(NULL, -1) != -1 ||
        kookie_simd_sum_u8_buffer(NULL, 1) != -1) {
        fprintf(stderr, "u8 pointer/count contract failed\n");
        return 1;
    }
    printf("simd-path=%d i32-sum=%lld u8-sum=%lld\n",
           (int)path, (long long)i32_sum, (long long)u8_sum);
    return 0;
}
