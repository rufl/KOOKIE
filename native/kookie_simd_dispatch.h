#ifndef KOOKIE_SIMD_DISPATCH_H
#define KOOKIE_SIMD_DISPATCH_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum KookieSimdPath {
    KOOKIE_SIMD_SCALAR = 1,
    KOOKIE_SIMD_SSE2 = 2,
    KOOKIE_SIMD_AVX2 = 3,
    KOOKIE_SIMD_NEON = 4
} KookieSimdPath;

/* Must be called once before the first operation. Safe to call repeatedly. */
void kookie_simd_initialize(void);
KookieSimdPath kookie_simd_path(void);

/* Returns 0 on success, -1 for invalid pointers or output. */
int kookie_simd_sum_i32(const int32_t *values, size_t count, int64_t *result);

#ifdef __cplusplus
}
#endif

#endif
