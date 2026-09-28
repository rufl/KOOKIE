#include "kookie_simd_dispatch.h"

#include <limits.h>
#include <stdatomic.h>

#if defined(__x86_64__) || defined(__i386__)
#include <immintrin.h>
#define KOOKIE_SIMD_X86 1
#elif defined(__aarch64__) || defined(__arm__)
#include <arm_neon.h>
#define KOOKIE_SIMD_ARM 1
#endif

#if defined(__GNUC__) || defined(__clang__)
#define KOOKIE_TARGET(x) __attribute__((target(x)))
#else
#define KOOKIE_TARGET(x)
#endif
static atomic_int initialization_state;
static KookieSimdPath selected_path = KOOKIE_SIMD_SCALAR;

static int finish_sum(__int128 total, int64_t *result) {
    if (total > INT64_MAX || total < INT64_MIN || result == NULL) {
        return -1;
    }
    *result = (int64_t)total;
    return 0;
}

static int scalar_sum(const int32_t *values, size_t count, int64_t *result) {
    size_t i;
    __int128 total = 0;

    if ((values == NULL && count != 0) || result == NULL) {
        return -1;
    }
    for (i = 0; i < count; ++i) {
        total += values[i];
    }
    return finish_sum(total, result);
}

#if defined(KOOKIE_SIMD_X86)
static KOOKIE_TARGET("sse2") int sse2_sum(const int32_t *values, size_t count, int64_t *result) {
    size_t i = 0;
    __int128 total = 0;
    int64_t lanes[2];

    if ((values == NULL && count != 0) || result == NULL) {
        return -1;
    }
    for (; i + 4 <= count; i += 4) {
        __m128i value = _mm_loadu_si128((const __m128i *)(values + i));
        __m128i sign = _mm_srai_epi32(value, 31);
        __m128i low = _mm_unpacklo_epi32(value, sign);
        __m128i high = _mm_unpackhi_epi32(value, sign);
        _mm_storeu_si128((__m128i *)lanes, low);
        total += lanes[0] + lanes[1];
        _mm_storeu_si128((__m128i *)lanes, high);
        total += lanes[0] + lanes[1];
    }
    for (; i < count; ++i) {
        total += values[i];
    }
    return finish_sum(total, result);
}

static KOOKIE_TARGET("avx2") int avx2_sum(const int32_t *values, size_t count, int64_t *result) {
    size_t i = 0;
    __int128 total = 0;
    int64_t lanes[4];

    if ((values == NULL && count != 0) || result == NULL) {
        return -1;
    }
    for (; i + 8 <= count; i += 8) {
        __m256i value = _mm256_loadu_si256((const __m256i *)(values + i));
        __m128i low = _mm256_castsi256_si128(value);
        __m128i high = _mm256_extracti128_si256(value, 1);
        __m256i low64 = _mm256_cvtepi32_epi64(low);
        __m256i high64 = _mm256_cvtepi32_epi64(high);
        _mm256_storeu_si256((__m256i *)lanes, low64);
        total += lanes[0] + lanes[1] + lanes[2] + lanes[3];
        _mm256_storeu_si256((__m256i *)lanes, high64);
        total += lanes[0] + lanes[1] + lanes[2] + lanes[3];
    }
    for (; i < count; ++i) {
        total += values[i];
    }
    return finish_sum(total, result);
}
#endif

#if defined(KOOKIE_SIMD_ARM) && defined(__aarch64__)
static int neon_sum(const int32_t *values, size_t count, int64_t *result) {
    size_t i = 0;
    __int128 total = 0;

    if ((values == NULL && count != 0) || result == NULL) {
        return -1;
    }
    for (; i + 4 <= count; i += 4) {
        int32x4_t value = vld1q_s32(values + i);
        int64x2_t low = vmovl_s32(vget_low_s32(value));
        int64x2_t high = vmovl_s32(vget_high_s32(value));
        total += (int64_t)vgetq_lane_s64(low, 0) + (int64_t)vgetq_lane_s64(low, 1);
        total += (int64_t)vgetq_lane_s64(high, 0) + (int64_t)vgetq_lane_s64(high, 1);
    }
    for (; i < count; ++i) {
        total += values[i];
    }
    return finish_sum(total, result);
}
#endif

void kookie_simd_initialize(void) {
    int expected = 0;

    if (atomic_load_explicit(&initialization_state, memory_order_acquire) == 2) {
        return;
    }
    if (!atomic_compare_exchange_strong_explicit(
            &initialization_state, &expected, 1,
            memory_order_acq_rel, memory_order_acquire)) {
        while (atomic_load_explicit(&initialization_state, memory_order_acquire) != 2) {
        }
        return;
    }
    selected_path = KOOKIE_SIMD_SCALAR;
#if !defined(KOOKIE_SIMD_FORCE_SCALAR) && defined(KOOKIE_SIMD_X86) && (defined(__GNUC__) || defined(__clang__))
    __builtin_cpu_init();
    if (__builtin_cpu_supports("avx2")) {
        selected_path = KOOKIE_SIMD_AVX2;
    } else if (__builtin_cpu_supports("sse2")) {
        selected_path = KOOKIE_SIMD_SSE2;
    }
#elif !defined(KOOKIE_SIMD_FORCE_SCALAR) && defined(KOOKIE_SIMD_ARM) && defined(__aarch64__)
    selected_path = KOOKIE_SIMD_NEON;
#endif
    atomic_store_explicit(&initialization_state, 2, memory_order_release);
}

KookieSimdPath kookie_simd_path(void) {
    kookie_simd_initialize();
    return selected_path;
}

int kookie_simd_sum_i32(const int32_t *values, size_t count, int64_t *result) {
    kookie_simd_initialize();
    switch (selected_path) {
#if defined(KOOKIE_SIMD_X86)
    case KOOKIE_SIMD_AVX2:
        return avx2_sum(values, count, result);
    case KOOKIE_SIMD_SSE2:
        return sse2_sum(values, count, result);
#endif
#if defined(KOOKIE_SIMD_ARM) && defined(__aarch64__)
    case KOOKIE_SIMD_NEON:
        return neon_sum(values, count, result);
#endif
    case KOOKIE_SIMD_SCALAR:
    default:
        return scalar_sum(values, count, result);
    }
}
