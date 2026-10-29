const __root = @This();
pub const __builtin = @import("c_builtins");
pub const __helpers = @import("helpers");

pub const __u_char = u8;
pub const __u_short = c_ushort;
pub const __u_int = c_uint;
pub const __u_long = c_ulong;
pub const __int8_t = i8;
pub const __uint8_t = u8;
pub const __int16_t = c_short;
pub const __uint16_t = c_ushort;
pub const __int32_t = c_int;
pub const __uint32_t = c_uint;
pub const __int64_t = c_long;
pub const __uint64_t = c_ulong;
pub const __int_least8_t = __int8_t;
pub const __uint_least8_t = __uint8_t;
pub const __int_least16_t = __int16_t;
pub const __uint_least16_t = __uint16_t;
pub const __int_least32_t = __int32_t;
pub const __uint_least32_t = __uint32_t;
pub const __int_least64_t = __int64_t;
pub const __uint_least64_t = __uint64_t;
pub const __quad_t = c_long;
pub const __u_quad_t = c_ulong;
pub const __intmax_t = c_long;
pub const __uintmax_t = c_ulong;
pub const __dev_t = c_ulong;
pub const __uid_t = c_uint;
pub const __gid_t = c_uint;
pub const __ino_t = c_ulong;
pub const __ino64_t = c_ulong;
pub const __mode_t = c_uint;
pub const __nlink_t = c_ulong;
pub const __off_t = c_long;
pub const __off64_t = c_long;
pub const __pid_t = c_int;
pub const __fsid_t = extern struct {
    __val: [2]c_int,
};
pub const __clock_t = c_long;
pub const __rlim_t = c_ulong;
pub const __rlim64_t = c_ulong;
pub const __id_t = c_uint;
pub const __time_t = c_long;
pub const __useconds_t = c_uint;
pub const __suseconds_t = c_long;
pub const __suseconds64_t = c_long;
pub const __daddr_t = c_int;
pub const __key_t = c_int;
pub const __clockid_t = c_int;
pub const __timer_t = ?*anyopaque;
pub const __blksize_t = c_long;
pub const __blkcnt_t = c_long;
pub const __blkcnt64_t = c_long;
pub const __fsblkcnt_t = c_ulong;
pub const __fsblkcnt64_t = c_ulong;
pub const __fsfilcnt_t = c_ulong;
pub const __fsfilcnt64_t = c_ulong;
pub const __fsword_t = c_long;
pub const __ssize_t = c_long;
pub const __syscall_slong_t = c_long;
pub const __syscall_ulong_t = c_ulong;
pub const __loff_t = __off64_t;
pub const __caddr_t = [*c]u8;
pub const __intptr_t = c_long;
pub const __socklen_t = c_uint;
pub const __sig_atomic_t = c_int;
pub const int_least8_t = __int_least8_t;
pub const int_least16_t = __int_least16_t;
pub const int_least32_t = __int_least32_t;
pub const int_least64_t = __int_least64_t;
pub const uint_least8_t = __uint_least8_t;
pub const uint_least16_t = __uint_least16_t;
pub const uint_least32_t = __uint_least32_t;
pub const uint_least64_t = __uint_least64_t;
pub const int_fast8_t = i8;
pub const int_fast16_t = c_long;
pub const int_fast32_t = c_long;
pub const int_fast64_t = c_long;
pub const uint_fast8_t = u8;
pub const uint_fast16_t = c_ulong;
pub const uint_fast32_t = c_ulong;
pub const uint_fast64_t = c_ulong;
pub const intmax_t = __intmax_t;
pub const uintmax_t = __uintmax_t;
pub const b3AllocFcn = fn (size: i32, alignment: i32) callconv(.c) ?*anyopaque;
pub const b3FreeFcn = fn (mem: ?*anyopaque) callconv(.c) void;
pub const b3AssertFcn = fn (condition: [*c]const u8, fileName: [*c]const u8, lineNumber: c_int) callconv(.c) c_int;
pub const b3LogFcn = fn (message: [*c]const u8) callconv(.c) void;
pub extern fn b3SetAllocator(allocFcn: ?*const b3AllocFcn, freeFcn: ?*const b3FreeFcn) void;
pub extern fn b3GetByteCount() i32;
pub extern fn b3SetAssertFcn(assertFcn: ?*const b3AssertFcn) void;
pub extern fn b3InternalAssert(condition: [*c]const u8, fileName: [*c]const u8, lineNumber: c_int) c_int;
pub extern fn b3SetLogFcn(logFcn: ?*const b3LogFcn) void;
pub const struct_b3Version = extern struct {
    major: c_int,
    minor: c_int,
    revision: c_int,
};
pub const b3Version = struct_b3Version;
pub extern fn b3GetVersion() b3Version;
pub extern fn b3IsDoublePrecision() bool;
pub extern fn b3GetTicks() u64;
pub extern fn b3GetMilliseconds(ticks: u64) f32;
pub extern fn b3GetMillisecondsAndReset(ticks: [*c]u64) f32;
pub extern fn b3Yield() void;
pub extern fn b3Sleep(milliseconds: c_int) void;
pub extern fn b3Hash(hash: u32, data: [*c]const u8, count: c_int) u32;
pub extern fn b3WriteBinaryFile(data: ?*anyopaque, size: c_int, fileName: [*c]const u8) void;
pub extern fn b3ReadBinaryFile(prefix: [*c]const u8, fileName: [*c]const u8, memSize: [*c]c_int) ?*anyopaque;
pub const float_t = f32;
pub const double_t = f64;
pub extern fn __fpclassify(__value: f64) c_int;
pub extern fn __signbit(__value: f64) c_int;
pub extern fn __isinf(__value: f64) c_int;
pub extern fn __finite(__value: f64) c_int;
pub extern fn __isnan(__value: f64) c_int;
pub extern fn __iseqsig(__x: f64, __y: f64) c_int;
pub extern fn __issignaling(__value: f64) c_int;
pub extern fn acos(__x: f64) f64;
pub extern fn __acos(__x: f64) f64;
pub extern fn asin(__x: f64) f64;
pub extern fn __asin(__x: f64) f64;
pub extern fn atan(__x: f64) f64;
pub extern fn __atan(__x: f64) f64;
pub extern fn atan2(__y: f64, __x: f64) f64;
pub extern fn __atan2(__y: f64, __x: f64) f64;
pub extern fn cos(__x: f64) f64;
pub extern fn __cos(__x: f64) f64;
pub extern fn sin(__x: f64) f64;
pub extern fn __sin(__x: f64) f64;
pub extern fn tan(__x: f64) f64;
pub extern fn __tan(__x: f64) f64;
pub extern fn cosh(__x: f64) f64;
pub extern fn __cosh(__x: f64) f64;
pub extern fn sinh(__x: f64) f64;
pub extern fn __sinh(__x: f64) f64;
pub extern fn tanh(__x: f64) f64;
pub extern fn __tanh(__x: f64) f64;
pub extern fn acosh(__x: f64) f64;
pub extern fn __acosh(__x: f64) f64;
pub extern fn asinh(__x: f64) f64;
pub extern fn __asinh(__x: f64) f64;
pub extern fn atanh(__x: f64) f64;
pub extern fn __atanh(__x: f64) f64;
pub extern fn exp(__x: f64) f64;
pub extern fn __exp(__x: f64) f64;
pub extern fn frexp(__x: f64, __exponent: [*c]c_int) f64;
pub extern fn __frexp(__x: f64, __exponent: [*c]c_int) f64;
pub extern fn ldexp(__x: f64, __exponent: c_int) f64;
pub extern fn __ldexp(__x: f64, __exponent: c_int) f64;
pub extern fn log(__x: f64) f64;
pub extern fn __log(__x: f64) f64;
pub extern fn log10(__x: f64) f64;
pub extern fn __log10(__x: f64) f64;
pub extern fn modf(__x: f64, __iptr: [*c]f64) f64;
pub extern fn __modf(__x: f64, __iptr: [*c]f64) f64;
pub extern fn expm1(__x: f64) f64;
pub extern fn __expm1(__x: f64) f64;
pub extern fn log1p(__x: f64) f64;
pub extern fn __log1p(__x: f64) f64;
pub extern fn logb(__x: f64) f64;
pub extern fn __logb(__x: f64) f64;
pub extern fn exp2(__x: f64) f64;
pub extern fn __exp2(__x: f64) f64;
pub extern fn log2(__x: f64) f64;
pub extern fn __log2(__x: f64) f64;
pub extern fn pow(__x: f64, __y: f64) f64;
pub extern fn __pow(__x: f64, __y: f64) f64;
pub extern fn sqrt(__x: f64) f64;
pub extern fn __sqrt(__x: f64) f64;
pub extern fn hypot(__x: f64, __y: f64) f64;
pub extern fn __hypot(__x: f64, __y: f64) f64;
pub extern fn cbrt(__x: f64) f64;
pub extern fn __cbrt(__x: f64) f64;
pub extern fn ceil(__x: f64) f64;
pub extern fn fabs(__x: f64) f64;
pub extern fn floor(__x: f64) f64;
pub extern fn fmod(__x: f64, __y: f64) f64;
pub extern fn __fmod(__x: f64, __y: f64) f64;
pub extern fn isinf(__value: f64) c_int;
pub extern fn finite(__value: f64) c_int;
pub extern fn drem(__x: f64, __y: f64) f64;
pub extern fn __drem(__x: f64, __y: f64) f64;
pub extern fn significand(__x: f64) f64;
pub extern fn __significand(__x: f64) f64;
pub extern fn copysign(__x: f64, __y: f64) f64;
pub extern fn nan(__tagb: [*c]const u8) f64;
pub extern fn __nan(__tagb: [*c]const u8) f64;
pub extern fn isnan(__value: f64) c_int;
pub extern fn j0(f64) f64;
pub extern fn __j0(f64) f64;
pub extern fn j1(f64) f64;
pub extern fn __j1(f64) f64;
pub extern fn jn(c_int, f64) f64;
pub extern fn __jn(c_int, f64) f64;
pub extern fn y0(f64) f64;
pub extern fn __y0(f64) f64;
pub extern fn y1(f64) f64;
pub extern fn __y1(f64) f64;
pub extern fn yn(c_int, f64) f64;
pub extern fn __yn(c_int, f64) f64;
pub extern fn erf(f64) f64;
pub extern fn __erf(f64) f64;
pub extern fn erfc(f64) f64;
pub extern fn __erfc(f64) f64;
pub extern fn lgamma(f64) f64;
pub extern fn __lgamma(f64) f64;
pub extern fn tgamma(f64) f64;
pub extern fn __tgamma(f64) f64;
pub extern fn gamma(f64) f64;
pub extern fn __gamma(f64) f64;
pub extern fn lgamma_r(f64, __signgamp: [*c]c_int) f64;
pub extern fn __lgamma_r(f64, __signgamp: [*c]c_int) f64;
pub extern fn rint(__x: f64) f64;
pub extern fn __rint(__x: f64) f64;
pub extern fn nextafter(__x: f64, __y: f64) f64;
pub extern fn __nextafter(__x: f64, __y: f64) f64;
pub extern fn nexttoward(__x: f64, __y: c_longdouble) f64;
pub extern fn __nexttoward(__x: f64, __y: c_longdouble) f64;
pub extern fn remainder(__x: f64, __y: f64) f64;
pub extern fn __remainder(__x: f64, __y: f64) f64;
pub extern fn scalbn(__x: f64, __n: c_int) f64;
pub extern fn __scalbn(__x: f64, __n: c_int) f64;
pub extern fn ilogb(__x: f64) c_int;
pub extern fn __ilogb(__x: f64) c_int;
pub extern fn scalbln(__x: f64, __n: c_long) f64;
pub extern fn __scalbln(__x: f64, __n: c_long) f64;
pub extern fn nearbyint(__x: f64) f64;
pub extern fn __nearbyint(__x: f64) f64;
pub extern fn round(__x: f64) f64;
pub extern fn trunc(__x: f64) f64;
pub extern fn remquo(__x: f64, __y: f64, __quo: [*c]c_int) f64;
pub extern fn __remquo(__x: f64, __y: f64, __quo: [*c]c_int) f64;
pub extern fn lrint(__x: f64) c_long;
pub extern fn __lrint(__x: f64) c_long;
pub extern fn llrint(__x: f64) c_longlong;
pub extern fn __llrint(__x: f64) c_longlong;
pub extern fn lround(__x: f64) c_long;
pub extern fn __lround(__x: f64) c_long;
pub extern fn llround(__x: f64) c_longlong;
pub extern fn __llround(__x: f64) c_longlong;
pub extern fn fdim(__x: f64, __y: f64) f64;
pub extern fn __fdim(__x: f64, __y: f64) f64;
pub extern fn fmax(__x: f64, __y: f64) f64;
pub extern fn fmin(__x: f64, __y: f64) f64;
pub extern fn fma(__x: f64, __y: f64, __z: f64) f64;
pub extern fn __fma(__x: f64, __y: f64, __z: f64) f64;
pub extern fn scalb(__x: f64, __n: f64) f64;
pub extern fn __scalb(__x: f64, __n: f64) f64;
pub extern fn __fpclassifyf(__value: f32) c_int;
pub extern fn __signbitf(__value: f32) c_int;
pub extern fn __isinff(__value: f32) c_int;
pub extern fn __finitef(__value: f32) c_int;
pub extern fn __isnanf(__value: f32) c_int;
pub extern fn __iseqsigf(__x: f32, __y: f32) c_int;
pub extern fn __issignalingf(__value: f32) c_int;
pub extern fn acosf(__x: f32) f32;
pub extern fn __acosf(__x: f32) f32;
pub extern fn asinf(__x: f32) f32;
pub extern fn __asinf(__x: f32) f32;
pub extern fn atanf(__x: f32) f32;
pub extern fn __atanf(__x: f32) f32;
pub extern fn atan2f(__y: f32, __x: f32) f32;
pub extern fn __atan2f(__y: f32, __x: f32) f32;
pub extern fn cosf(__x: f32) f32;
pub extern fn __cosf(__x: f32) f32;
pub extern fn sinf(__x: f32) f32;
pub extern fn __sinf(__x: f32) f32;
pub extern fn tanf(__x: f32) f32;
pub extern fn __tanf(__x: f32) f32;
pub extern fn coshf(__x: f32) f32;
pub extern fn __coshf(__x: f32) f32;
pub extern fn sinhf(__x: f32) f32;
pub extern fn __sinhf(__x: f32) f32;
pub extern fn tanhf(__x: f32) f32;
pub extern fn __tanhf(__x: f32) f32;
pub extern fn acoshf(__x: f32) f32;
pub extern fn __acoshf(__x: f32) f32;
pub extern fn asinhf(__x: f32) f32;
pub extern fn __asinhf(__x: f32) f32;
pub extern fn atanhf(__x: f32) f32;
pub extern fn __atanhf(__x: f32) f32;
pub extern fn expf(__x: f32) f32;
pub extern fn __expf(__x: f32) f32;
pub extern fn frexpf(__x: f32, __exponent: [*c]c_int) f32;
pub extern fn __frexpf(__x: f32, __exponent: [*c]c_int) f32;
pub extern fn ldexpf(__x: f32, __exponent: c_int) f32;
pub extern fn __ldexpf(__x: f32, __exponent: c_int) f32;
pub extern fn logf(__x: f32) f32;
pub extern fn __logf(__x: f32) f32;
pub extern fn log10f(__x: f32) f32;
pub extern fn __log10f(__x: f32) f32;
pub extern fn modff(__x: f32, __iptr: [*c]f32) f32;
pub extern fn __modff(__x: f32, __iptr: [*c]f32) f32;
pub extern fn expm1f(__x: f32) f32;
pub extern fn __expm1f(__x: f32) f32;
pub extern fn log1pf(__x: f32) f32;
pub extern fn __log1pf(__x: f32) f32;
pub extern fn logbf(__x: f32) f32;
pub extern fn __logbf(__x: f32) f32;
pub extern fn exp2f(__x: f32) f32;
pub extern fn __exp2f(__x: f32) f32;
pub extern fn log2f(__x: f32) f32;
pub extern fn __log2f(__x: f32) f32;
pub extern fn powf(__x: f32, __y: f32) f32;
pub extern fn __powf(__x: f32, __y: f32) f32;
pub extern fn sqrtf(__x: f32) f32;
pub extern fn __sqrtf(__x: f32) f32;
pub extern fn hypotf(__x: f32, __y: f32) f32;
pub extern fn __hypotf(__x: f32, __y: f32) f32;
pub extern fn cbrtf(__x: f32) f32;
pub extern fn __cbrtf(__x: f32) f32;
pub extern fn ceilf(__x: f32) f32;
pub extern fn fabsf(__x: f32) f32;
pub extern fn floorf(__x: f32) f32;
pub extern fn fmodf(__x: f32, __y: f32) f32;
pub extern fn __fmodf(__x: f32, __y: f32) f32;
pub extern fn isinff(__value: f32) c_int;
pub extern fn finitef(__value: f32) c_int;
pub extern fn dremf(__x: f32, __y: f32) f32;
pub extern fn __dremf(__x: f32, __y: f32) f32;
pub extern fn significandf(__x: f32) f32;
pub extern fn __significandf(__x: f32) f32;
pub extern fn copysignf(__x: f32, __y: f32) f32;
pub extern fn nanf(__tagb: [*c]const u8) f32;
pub extern fn __nanf(__tagb: [*c]const u8) f32;
pub extern fn isnanf(__value: f32) c_int;
pub extern fn j0f(f32) f32;
pub extern fn __j0f(f32) f32;
pub extern fn j1f(f32) f32;
pub extern fn __j1f(f32) f32;
pub extern fn jnf(c_int, f32) f32;
pub extern fn __jnf(c_int, f32) f32;
pub extern fn y0f(f32) f32;
pub extern fn __y0f(f32) f32;
pub extern fn y1f(f32) f32;
pub extern fn __y1f(f32) f32;
pub extern fn ynf(c_int, f32) f32;
pub extern fn __ynf(c_int, f32) f32;
pub extern fn erff(f32) f32;
pub extern fn __erff(f32) f32;
pub extern fn erfcf(f32) f32;
pub extern fn __erfcf(f32) f32;
pub extern fn lgammaf(f32) f32;
pub extern fn __lgammaf(f32) f32;
pub extern fn tgammaf(f32) f32;
pub extern fn __tgammaf(f32) f32;
pub extern fn gammaf(f32) f32;
pub extern fn __gammaf(f32) f32;
pub extern fn lgammaf_r(f32, __signgamp: [*c]c_int) f32;
pub extern fn __lgammaf_r(f32, __signgamp: [*c]c_int) f32;
pub extern fn rintf(__x: f32) f32;
pub extern fn __rintf(__x: f32) f32;
pub extern fn nextafterf(__x: f32, __y: f32) f32;
pub extern fn __nextafterf(__x: f32, __y: f32) f32;
pub extern fn nexttowardf(__x: f32, __y: c_longdouble) f32;
pub extern fn __nexttowardf(__x: f32, __y: c_longdouble) f32;
pub extern fn remainderf(__x: f32, __y: f32) f32;
pub extern fn __remainderf(__x: f32, __y: f32) f32;
pub extern fn scalbnf(__x: f32, __n: c_int) f32;
pub extern fn __scalbnf(__x: f32, __n: c_int) f32;
pub extern fn ilogbf(__x: f32) c_int;
pub extern fn __ilogbf(__x: f32) c_int;
pub extern fn scalblnf(__x: f32, __n: c_long) f32;
pub extern fn __scalblnf(__x: f32, __n: c_long) f32;
pub extern fn nearbyintf(__x: f32) f32;
pub extern fn __nearbyintf(__x: f32) f32;
pub extern fn roundf(__x: f32) f32;
pub extern fn truncf(__x: f32) f32;
pub extern fn remquof(__x: f32, __y: f32, __quo: [*c]c_int) f32;
pub extern fn __remquof(__x: f32, __y: f32, __quo: [*c]c_int) f32;
pub extern fn lrintf(__x: f32) c_long;
pub extern fn __lrintf(__x: f32) c_long;
pub extern fn llrintf(__x: f32) c_longlong;
pub extern fn __llrintf(__x: f32) c_longlong;
pub extern fn lroundf(__x: f32) c_long;
pub extern fn __lroundf(__x: f32) c_long;
pub extern fn llroundf(__x: f32) c_longlong;
pub extern fn __llroundf(__x: f32) c_longlong;
pub extern fn fdimf(__x: f32, __y: f32) f32;
pub extern fn __fdimf(__x: f32, __y: f32) f32;
pub extern fn fmaxf(__x: f32, __y: f32) f32;
pub extern fn fminf(__x: f32, __y: f32) f32;
pub extern fn fmaf(__x: f32, __y: f32, __z: f32) f32;
pub extern fn __fmaf(__x: f32, __y: f32, __z: f32) f32;
pub extern fn scalbf(__x: f32, __n: f32) f32;
pub extern fn __scalbf(__x: f32, __n: f32) f32;
pub extern fn __fpclassifyl(__value: c_longdouble) c_int;
pub extern fn __signbitl(__value: c_longdouble) c_int;
pub extern fn __isinfl(__value: c_longdouble) c_int;
pub extern fn __finitel(__value: c_longdouble) c_int;
pub extern fn __isnanl(__value: c_longdouble) c_int;
pub extern fn __iseqsigl(__x: c_longdouble, __y: c_longdouble) c_int;
pub extern fn __issignalingl(__value: c_longdouble) c_int;
pub extern fn acosl(__x: c_longdouble) c_longdouble;
pub extern fn __acosl(__x: c_longdouble) c_longdouble;
pub extern fn asinl(__x: c_longdouble) c_longdouble;
pub extern fn __asinl(__x: c_longdouble) c_longdouble;
pub extern fn atanl(__x: c_longdouble) c_longdouble;
pub extern fn __atanl(__x: c_longdouble) c_longdouble;
pub extern fn atan2l(__y: c_longdouble, __x: c_longdouble) c_longdouble;
pub extern fn __atan2l(__y: c_longdouble, __x: c_longdouble) c_longdouble;
pub extern fn cosl(__x: c_longdouble) c_longdouble;
pub extern fn __cosl(__x: c_longdouble) c_longdouble;
pub extern fn sinl(__x: c_longdouble) c_longdouble;
pub extern fn __sinl(__x: c_longdouble) c_longdouble;
pub extern fn tanl(__x: c_longdouble) c_longdouble;
pub extern fn __tanl(__x: c_longdouble) c_longdouble;
pub extern fn coshl(__x: c_longdouble) c_longdouble;
pub extern fn __coshl(__x: c_longdouble) c_longdouble;
pub extern fn sinhl(__x: c_longdouble) c_longdouble;
pub extern fn __sinhl(__x: c_longdouble) c_longdouble;
pub extern fn tanhl(__x: c_longdouble) c_longdouble;
pub extern fn __tanhl(__x: c_longdouble) c_longdouble;
pub extern fn acoshl(__x: c_longdouble) c_longdouble;
pub extern fn __acoshl(__x: c_longdouble) c_longdouble;
pub extern fn asinhl(__x: c_longdouble) c_longdouble;
pub extern fn __asinhl(__x: c_longdouble) c_longdouble;
pub extern fn atanhl(__x: c_longdouble) c_longdouble;
pub extern fn __atanhl(__x: c_longdouble) c_longdouble;
pub extern fn expl(__x: c_longdouble) c_longdouble;
pub extern fn __expl(__x: c_longdouble) c_longdouble;
pub extern fn frexpl(__x: c_longdouble, __exponent: [*c]c_int) c_longdouble;
pub extern fn __frexpl(__x: c_longdouble, __exponent: [*c]c_int) c_longdouble;
pub extern fn ldexpl(__x: c_longdouble, __exponent: c_int) c_longdouble;
pub extern fn __ldexpl(__x: c_longdouble, __exponent: c_int) c_longdouble;
pub extern fn logl(__x: c_longdouble) c_longdouble;
pub extern fn __logl(__x: c_longdouble) c_longdouble;
pub extern fn log10l(__x: c_longdouble) c_longdouble;
pub extern fn __log10l(__x: c_longdouble) c_longdouble;
pub extern fn modfl(__x: c_longdouble, __iptr: [*c]c_longdouble) c_longdouble;
pub extern fn __modfl(__x: c_longdouble, __iptr: [*c]c_longdouble) c_longdouble;
pub extern fn expm1l(__x: c_longdouble) c_longdouble;
pub extern fn __expm1l(__x: c_longdouble) c_longdouble;
pub extern fn log1pl(__x: c_longdouble) c_longdouble;
pub extern fn __log1pl(__x: c_longdouble) c_longdouble;
pub extern fn logbl(__x: c_longdouble) c_longdouble;
pub extern fn __logbl(__x: c_longdouble) c_longdouble;
pub extern fn exp2l(__x: c_longdouble) c_longdouble;
pub extern fn __exp2l(__x: c_longdouble) c_longdouble;
pub extern fn log2l(__x: c_longdouble) c_longdouble;
pub extern fn __log2l(__x: c_longdouble) c_longdouble;
pub extern fn powl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __powl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn sqrtl(__x: c_longdouble) c_longdouble;
pub extern fn __sqrtl(__x: c_longdouble) c_longdouble;
pub extern fn hypotl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __hypotl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn cbrtl(__x: c_longdouble) c_longdouble;
pub extern fn __cbrtl(__x: c_longdouble) c_longdouble;
pub extern fn ceill(__x: c_longdouble) c_longdouble;
pub extern fn fabsl(__x: c_longdouble) c_longdouble;
pub extern fn floorl(__x: c_longdouble) c_longdouble;
pub extern fn fmodl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmodl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn isinfl(__value: c_longdouble) c_int;
pub extern fn finitel(__value: c_longdouble) c_int;
pub extern fn dreml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __dreml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn significandl(__x: c_longdouble) c_longdouble;
pub extern fn __significandl(__x: c_longdouble) c_longdouble;
pub extern fn copysignl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn nanl(__tagb: [*c]const u8) c_longdouble;
pub extern fn __nanl(__tagb: [*c]const u8) c_longdouble;
pub extern fn isnanl(__value: c_longdouble) c_int;
pub extern fn j0l(c_longdouble) c_longdouble;
pub extern fn __j0l(c_longdouble) c_longdouble;
pub extern fn j1l(c_longdouble) c_longdouble;
pub extern fn __j1l(c_longdouble) c_longdouble;
pub extern fn jnl(c_int, c_longdouble) c_longdouble;
pub extern fn __jnl(c_int, c_longdouble) c_longdouble;
pub extern fn y0l(c_longdouble) c_longdouble;
pub extern fn __y0l(c_longdouble) c_longdouble;
pub extern fn y1l(c_longdouble) c_longdouble;
pub extern fn __y1l(c_longdouble) c_longdouble;
pub extern fn ynl(c_int, c_longdouble) c_longdouble;
pub extern fn __ynl(c_int, c_longdouble) c_longdouble;
pub extern fn erfl(c_longdouble) c_longdouble;
pub extern fn __erfl(c_longdouble) c_longdouble;
pub extern fn erfcl(c_longdouble) c_longdouble;
pub extern fn __erfcl(c_longdouble) c_longdouble;
pub extern fn lgammal(c_longdouble) c_longdouble;
pub extern fn __lgammal(c_longdouble) c_longdouble;
pub extern fn tgammal(c_longdouble) c_longdouble;
pub extern fn __tgammal(c_longdouble) c_longdouble;
pub extern fn gammal(c_longdouble) c_longdouble;
pub extern fn __gammal(c_longdouble) c_longdouble;
pub extern fn lgammal_r(c_longdouble, __signgamp: [*c]c_int) c_longdouble;
pub extern fn __lgammal_r(c_longdouble, __signgamp: [*c]c_int) c_longdouble;
pub extern fn rintl(__x: c_longdouble) c_longdouble;
pub extern fn __rintl(__x: c_longdouble) c_longdouble;
pub extern fn nextafterl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __nextafterl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn nexttowardl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __nexttowardl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn remainderl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __remainderl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn scalbnl(__x: c_longdouble, __n: c_int) c_longdouble;
pub extern fn __scalbnl(__x: c_longdouble, __n: c_int) c_longdouble;
pub extern fn ilogbl(__x: c_longdouble) c_int;
pub extern fn __ilogbl(__x: c_longdouble) c_int;
pub extern fn scalblnl(__x: c_longdouble, __n: c_long) c_longdouble;
pub extern fn __scalblnl(__x: c_longdouble, __n: c_long) c_longdouble;
pub extern fn nearbyintl(__x: c_longdouble) c_longdouble;
pub extern fn __nearbyintl(__x: c_longdouble) c_longdouble;
pub extern fn roundl(__x: c_longdouble) c_longdouble;
pub extern fn truncl(__x: c_longdouble) c_longdouble;
pub extern fn remquol(__x: c_longdouble, __y: c_longdouble, __quo: [*c]c_int) c_longdouble;
pub extern fn __remquol(__x: c_longdouble, __y: c_longdouble, __quo: [*c]c_int) c_longdouble;
pub extern fn lrintl(__x: c_longdouble) c_long;
pub extern fn __lrintl(__x: c_longdouble) c_long;
pub extern fn llrintl(__x: c_longdouble) c_longlong;
pub extern fn __llrintl(__x: c_longdouble) c_longlong;
pub extern fn lroundl(__x: c_longdouble) c_long;
pub extern fn __lroundl(__x: c_longdouble) c_long;
pub extern fn llroundl(__x: c_longdouble) c_longlong;
pub extern fn __llroundl(__x: c_longdouble) c_longlong;
pub extern fn fdiml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fdiml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaxl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmal(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) c_longdouble;
pub extern fn __fmal(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) c_longdouble;
pub extern fn scalbl(__x: c_longdouble, __n: c_longdouble) c_longdouble;
pub extern fn __scalbl(__x: c_longdouble, __n: c_longdouble) c_longdouble;
pub extern fn __fpclassifyf128(__value: f128) c_int;
pub extern fn __signbitf128(__value: f128) c_int;
pub extern fn __isinff128(__value: f128) c_int;
pub extern fn __finitef128(__value: f128) c_int;
pub extern fn __isnanf128(__value: f128) c_int;
pub extern fn __iseqsigf128(__x: f128, __y: f128) c_int;
pub extern fn __issignalingf128(__value: f128) c_int;
pub extern var signgam: c_int;
pub const FP_NAN: c_int = 0;
pub const FP_INFINITE: c_int = 1;
pub const FP_ZERO: c_int = 2;
pub const FP_SUBNORMAL: c_int = 3;
pub const FP_NORMAL: c_int = 4;
const enum_unnamed_1 = c_uint;
pub const struct_b3Vec2 = extern struct {
    x: f32,
    y: f32,
};
pub const b3Vec2 = struct_b3Vec2;
pub const struct_b3Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    pub const b3Add = __root.b3Add;
    pub const b3Sub = __root.b3Sub;
    pub const b3Mul = __root.b3Mul;
    pub const b3Neg = __root.b3Neg;
    pub const b3Dot = __root.b3Dot;
    pub const b3Length = __root.b3Length;
    pub const b3LengthSquared = __root.b3LengthSquared;
    pub const b3Distance = __root.b3Distance;
    pub const b3DistanceSquared = __root.b3DistanceSquared;
    pub const b3Normalize = __root.b3Normalize;
    pub const b3Perp = __root.b3Perp;
    pub const b3IsNormalized = __root.b3IsNormalized;
    pub const b3MulAdd = __root.b3MulAdd;
    pub const b3MulSub = __root.b3MulSub;
    pub const b3Cross = __root.b3Cross;
    pub const b3Lerp = __root.b3Lerp;
    pub const b3Abs = __root.b3Abs;
    pub const b3Sign = __root.b3Sign;
    pub const b3Min = __root.b3Min;
    pub const b3Max = __root.b3Max;
    pub const b3Clamp = __root.b3Clamp;
    pub const b3SafeScale = __root.b3SafeScale;
    pub const b3MakeQuatFromAxisAngle = __root.b3MakeQuatFromAxisAngle;
    pub const b3ComputeQuatBetweenUnitVectors = __root.b3ComputeQuatBetweenUnitVectors;
    pub const b3ToPos = __root.b3ToPos;
    pub const b3ToVec3 = __root.b3ToVec3;
    pub const b3SubPos = __root.b3SubPos;
    pub const b3OffsetPos = __root.b3OffsetPos;
    pub const b3LerpPosition = __root.b3LerpPosition;
    pub const b3MakeAABB = __root.b3MakeAABB;
    pub const b3ClosestPointToAABB = __root.b3ClosestPointToAABB;
    pub const b3PointToSegmentDistance = __root.b3PointToSegmentDistance;
    pub const b3LineDistance = __root.b3LineDistance;
    pub const b3SegmentDistance = __root.b3SegmentDistance;
    pub const b3IsValidVec3 = __root.b3IsValidVec3;
    pub const b3IsValidPosition = __root.b3IsValidPosition;
    pub const b3CreateHull = __root.b3CreateHull;
    pub const b3MakeScaledBoxHull = __root.b3MakeScaledBoxHull;
    pub const b3ScaleBox = __root.b3ScaleBox;
    pub const b3CreateBoxMesh = __root.b3CreateBoxMesh;
    pub const b3CreateHollowBoxMesh = __root.b3CreateHollowBoxMesh;
    pub const b3CreatePlatformMesh = __root.b3CreatePlatformMesh;
    pub const b3SolvePlanes = __root.b3SolvePlanes;
    pub const b3ClipVector = __root.b3ClipVector;
};
pub const b3Vec3 = struct_b3Vec3;
pub const struct_b3CosSin = extern struct {
    cosine: f32,
    sine: f32,
};
pub const b3CosSin = struct_b3CosSin;
pub const struct_b3Quat = extern struct {
    v: b3Vec3,
    s: f32,
    pub const b3IsNormalizedQuat = __root.b3IsNormalizedQuat;
    pub const b3RotateVector = __root.b3RotateVector;
    pub const b3InvRotateVector = __root.b3InvRotateVector;
    pub const b3DotQuat = __root.b3DotQuat;
    pub const b3MulQuat = __root.b3MulQuat;
    pub const b3InvMulQuat = __root.b3InvMulQuat;
    pub const b3Conjugate = __root.b3Conjugate;
    pub const b3NegateQuat = __root.b3NegateQuat;
    pub const b3NormalizeQuat = __root.b3NormalizeQuat;
    pub const b3GetQuatAngle = __root.b3GetQuatAngle;
    pub const b3GetTwistAngle = __root.b3GetTwistAngle;
    pub const b3GetSwingAngle = __root.b3GetSwingAngle;
    pub const b3NLerp = __root.b3NLerp;
    pub const b3MakeMatrixFromQuat = __root.b3MakeMatrixFromQuat;
    pub const b3IsValidQuat = __root.b3IsValidQuat;
};
pub const b3Quat = struct_b3Quat;
pub const struct_b3Transform = extern struct {
    p: b3Vec3,
    q: b3Quat,
    pub const b3MulTransforms = __root.b3MulTransforms;
    pub const b3InvMulTransforms = __root.b3InvMulTransforms;
    pub const b3InvertTransform = __root.b3InvertTransform;
    pub const b3TransformPoint = __root.b3TransformPoint;
    pub const b3InvTransformPoint = __root.b3InvTransformPoint;
    pub const b3TransformWorldPoint = __root.b3TransformWorldPoint;
    pub const b3InvTransformWorldPoint = __root.b3InvTransformWorldPoint;
    pub const b3InvMulWorldTransforms = __root.b3InvMulWorldTransforms;
    pub const b3MulWorldTransforms = __root.b3MulWorldTransforms;
    pub const b3ToRelativeTransform = __root.b3ToRelativeTransform;
    pub const b3MakeWorldTransform = __root.b3MakeWorldTransform;
    pub const b3AABB_Transform = __root.b3AABB_Transform;
    pub const b3IsValidTransform = __root.b3IsValidTransform;
    pub const b3IsValidWorldTransform = __root.b3IsValidWorldTransform;
    pub const Transform = __root.b3AABB_Transform;
};
pub const b3Transform = struct_b3Transform;
pub const b3Pos = b3Vec3;
pub const b3WorldTransform = b3Transform;
pub const struct_b3Matrix3 = extern struct {
    cx: b3Vec3,
    cy: b3Vec3,
    cz: b3Vec3,
    pub const b3MakeQuatFromMatrix = __root.b3MakeQuatFromMatrix;
    pub const b3Det = __root.b3Det;
    pub const b3MulMV = __root.b3MulMV;
    pub const b3NegateMat3 = __root.b3NegateMat3;
    pub const b3AddMM = __root.b3AddMM;
    pub const b3SubMM = __root.b3SubMM;
    pub const b3MulMM = __root.b3MulMM;
    pub const b3Transpose = __root.b3Transpose;
    pub const b3InvertMatrix = __root.b3InvertMatrix;
    pub const b3Solve3 = __root.b3Solve3;
    pub const b3InvertT = __root.b3InvertT;
    pub const b3AbsMatrix3 = __root.b3AbsMatrix3;
    pub const b3IsValidMatrix3 = __root.b3IsValidMatrix3;
};
pub const b3Matrix3 = struct_b3Matrix3;
pub const struct_b3AABB = extern struct {
    lowerBound: b3Vec3,
    upperBound: b3Vec3,
    pub const b3OffsetAABB = __root.b3OffsetAABB;
    pub const b3AABB_Contains = __root.b3AABB_Contains;
    pub const b3AABB_Area = __root.b3AABB_Area;
    pub const b3AABB_Center = __root.b3AABB_Center;
    pub const b3AABB_Extents = __root.b3AABB_Extents;
    pub const b3AABB_Union = __root.b3AABB_Union;
    pub const b3AABB_Inflate = __root.b3AABB_Inflate;
    pub const b3AABB_Overlaps = __root.b3AABB_Overlaps;
    pub const b3IsValidAABB = __root.b3IsValidAABB;
    pub const b3IsBoundedAABB = __root.b3IsBoundedAABB;
    pub const b3IsSaneAABB = __root.b3IsSaneAABB;
    pub const Contains = __root.b3AABB_Contains;
    pub const Area = __root.b3AABB_Area;
    pub const Center = __root.b3AABB_Center;
    pub const Extents = __root.b3AABB_Extents;
    pub const Union = __root.b3AABB_Union;
    pub const Inflate = __root.b3AABB_Inflate;
    pub const Overlaps = __root.b3AABB_Overlaps;
};
pub const b3AABB = struct_b3AABB;
pub const struct_b3Plane = extern struct {
    normal: b3Vec3,
    offset: f32,
    pub const b3IsValidPlane = __root.b3IsValidPlane;
};
pub const b3Plane = struct_b3Plane;
pub const b3Vec3_zero: b3Vec3 = b3Vec3{
    .x = 0.0,
    .y = 0.0,
    .z = 0.0,
};
pub const b3Vec3_one: b3Vec3 = b3Vec3{
    .x = 1.0,
    .y = 1.0,
    .z = 1.0,
};
pub const b3Vec3_axisX: b3Vec3 = b3Vec3{
    .x = 1.0,
    .y = 0.0,
    .z = 0.0,
};
pub const b3Vec3_axisY: b3Vec3 = b3Vec3{
    .x = 0.0,
    .y = 1.0,
    .z = 0.0,
};
pub const b3Vec3_axisZ: b3Vec3 = b3Vec3{
    .x = 0.0,
    .y = 0.0,
    .z = 1.0,
};
pub const b3Quat_identity: b3Quat = b3Quat{
    .v = b3Vec3{
        .x = 0.0,
        .y = 0.0,
        .z = 0.0,
    },
    .s = 1.0,
};
pub const b3Transform_identity: b3Transform = b3Transform{
    .p = b3Vec3{
        .x = 0.0,
        .y = 0.0,
        .z = 0.0,
    },
    .q = b3Quat{
        .v = b3Vec3{
            .x = 0.0,
            .y = 0.0,
            .z = 0.0,
        },
        .s = 1.0,
    },
};
pub const b3Mat3_zero: b3Matrix3 = b3Matrix3{
    .cx = b3Vec3{
        .x = 0.0,
        .y = 0.0,
        .z = 0.0,
    },
    .cy = b3Vec3{
        .x = 0.0,
        .y = 0.0,
        .z = 0.0,
    },
    .cz = b3Vec3{
        .x = 0.0,
        .y = 0.0,
        .z = 0.0,
    },
};
pub const b3Mat3_identity: b3Matrix3 = b3Matrix3{
    .cx = b3Vec3{
        .x = 1.0,
        .y = 0.0,
        .z = 0.0,
    },
    .cy = b3Vec3{
        .x = 0.0,
        .y = 1.0,
        .z = 0.0,
    },
    .cz = b3Vec3{
        .x = 0.0,
        .y = 0.0,
        .z = 1.0,
    },
};
pub const b3Pos_zero: b3Pos = b3Pos{
    .x = 0.0,
    .y = 0.0,
    .z = 0.0,
};
pub const b3WorldTransform_identity: b3WorldTransform = b3WorldTransform{
    .p = b3Vec3{
        .x = 0.0,
        .y = 0.0,
        .z = 0.0,
    },
    .q = b3Quat{
        .v = b3Vec3{
            .x = 0.0,
            .y = 0.0,
            .z = 0.0,
        },
        .s = 1.0,
    },
};
pub fn b3MinInt(arg_a: c_int, arg_b: c_int) callconv(.c) c_int {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return if (a < b) a else b;
}
pub fn b3MaxInt(arg_a: c_int, arg_b: c_int) callconv(.c) c_int {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return if (a > b) a else b;
}
pub fn b3ClampInt(arg_a: c_int, arg_lower: c_int, arg_upper: c_int) callconv(.c) c_int {
    var a = arg_a;
    _ = &a;
    var lower = arg_lower;
    _ = &lower;
    var upper = arg_upper;
    _ = &upper;
    return if (a < lower) lower else if (upper < a) upper else a;
}
pub extern fn b3IsValidFloat(a: f32) bool;
pub fn b3AbsFloat(arg_a: f32) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    return if (a < @as(f32, @floatFromInt(@as(c_int, 0)))) -a else a;
}
pub fn b3MinFloat(arg_a: f32, arg_b: f32) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return if (a < b) a else b;
}
pub fn b3MaxFloat(arg_a: f32, arg_b: f32) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return if (a > b) a else b;
}
pub fn b3ClampFloat(arg_a: f32, arg_lower: f32, arg_upper: f32) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var lower = arg_lower;
    _ = &lower;
    var upper = arg_upper;
    _ = &upper;
    return if (a < lower) lower else if (upper < a) upper else a;
}
pub fn b3LerpFloat(arg_a: f32, arg_b: f32, arg_alpha: f32) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var alpha = arg_alpha;
    _ = &alpha;
    return ((@as(f32, 1.0) - alpha) * a) + (alpha * b);
}
pub extern fn b3Atan2(y: f32, x: f32) f32;
pub extern fn b3ComputeCosSin(radians: f32) b3CosSin;
pub fn b3Sin(arg_radians: f32) callconv(.c) f32 {
    var radians = arg_radians;
    _ = &radians;
    var cs: b3CosSin = b3ComputeCosSin(radians);
    _ = &cs;
    return cs.sine;
}
pub fn b3Cos(arg_radians: f32) callconv(.c) f32 {
    var radians = arg_radians;
    _ = &radians;
    var cs: b3CosSin = b3ComputeCosSin(radians);
    _ = &cs;
    return cs.cosine;
}
pub fn b3UnwindAngle(arg_radians: f32) callconv(.c) f32 {
    var radians = arg_radians;
    _ = &radians;
    return remainderf(radians, @as(f32, 2.0) * B3_PI);
}
pub fn b3Add(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return b3Vec3{
        .x = a.x + b.x,
        .y = a.y + b.y,
        .z = a.z + b.z,
    };
}
pub fn b3Sub(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return b3Vec3{
        .x = a.x - b.x,
        .y = a.y - b.y,
        .z = a.z - b.z,
    };
}
pub fn b3Mul(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return b3Vec3{
        .x = a.x * b.x,
        .y = a.y * b.y,
        .z = a.z * b.z,
    };
}
pub fn b3Neg(arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    return b3Vec3{
        .x = -a.x,
        .y = -a.y,
        .z = -a.z,
    };
}
pub fn b3Dot(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return ((a.x * b.x) + (a.y * b.y)) + (a.z * b.z);
}
pub fn b3Length(arg_v: b3Vec3) callconv(.c) f32 {
    var v = arg_v;
    _ = &v;
    return sqrtf(b3Dot(v, v));
}
pub fn b3LengthSquared(arg_a: b3Vec3) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    return ((a.x * a.x) + (a.y * a.y)) + (a.z * a.z);
}
pub fn b3Distance(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var dv: b3Vec3 = b3Vec3{
        .x = b.x - a.x,
        .y = b.y - a.y,
        .z = b.z - a.z,
    };
    _ = &dv;
    return b3Length(dv);
}
pub fn b3DistanceSquared(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var dv: b3Vec3 = b3Vec3{
        .x = b.x - a.x,
        .y = b.y - a.y,
        .z = b.z - a.z,
    };
    _ = &dv;
    return ((dv.x * dv.x) + (dv.y * dv.y)) + (dv.z * dv.z);
}
pub fn b3Normalize(arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var lengthSquared: f32 = ((a.x * a.x) + (a.y * a.y)) + (a.z * a.z);
    _ = &lengthSquared;
    if (lengthSquared > (@as(f32, 1000.0) * __FLT_MIN__)) {
        var s: f32 = @as(f32, 1.0) / sqrtf(lengthSquared);
        _ = &s;
        var u: b3Vec3 = b3Vec3{
            .x = s * a.x,
            .y = s * a.y,
            .z = s * a.z,
        };
        _ = &u;
        return u;
    }
    return b3Vec3{
        .x = 0.0,
        .y = 0.0,
        .z = 0.0,
    };
}
pub fn b3GetLengthAndNormalize(arg_length: [*c]f32, arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var length = arg_length;
    _ = &length;
    var a = arg_a;
    _ = &a;
    length.* = b3Length(a);
    if (length.* < __FLT_EPSILON__) {
        return b3Vec3_zero;
    }
    var invLength: f32 = @as(f32, 1.0) / length.*;
    _ = &invLength;
    var n: b3Vec3 = b3Vec3{
        .x = invLength * a.x,
        .y = invLength * a.y,
        .z = invLength * a.z,
    };
    _ = &n;
    return n;
}
pub fn b3Perp(arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var p: b3Vec3 = undefined;
    _ = &p;
    if ((a.x < -@as(f32, 0.5)) or (@as(f32, 0.5) < a.x)) {
        p = b3Vec3{
            .x = a.y,
            .y = -a.x,
            .z = 0.0,
        };
    } else {
        p = b3Vec3{
            .x = 0.0,
            .y = a.z,
            .z = -a.y,
        };
    }
    return b3Normalize(p);
}
pub fn b3IsNormalized(arg_a: b3Vec3) callconv(.c) bool {
    var a = arg_a;
    _ = &a;
    var aa: f32 = b3Dot(a, a);
    _ = &aa;
    return b3AbsFloat(@as(f32, 1.0) - aa) < (@as(f32, 100.0) * __FLT_EPSILON__);
}
pub fn b3MulAdd(arg_a: b3Vec3, arg_s: f32, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var s = arg_s;
    _ = &s;
    var b = arg_b;
    _ = &b;
    return b3Vec3{
        .x = a.x + (s * b.x),
        .y = a.y + (s * b.y),
        .z = a.z + (s * b.z),
    };
}
pub fn b3MulSub(arg_a: b3Vec3, arg_s: f32, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var s = arg_s;
    _ = &s;
    var b = arg_b;
    _ = &b;
    return b3Vec3{
        .x = a.x - (s * b.x),
        .y = a.y - (s * b.y),
        .z = a.z - (s * b.z),
    };
}
pub fn b3MulSV(arg_s: f32, arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var s = arg_s;
    _ = &s;
    var a = arg_a;
    _ = &a;
    return b3Vec3{
        .x = s * a.x,
        .y = s * a.y,
        .z = s * a.z,
    };
}
pub fn b3Cross(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var c: b3Vec3 = undefined;
    _ = &c;
    c.x = (a.y * b.z) - (a.z * b.y);
    c.y = (a.z * b.x) - (a.x * b.z);
    c.z = (a.x * b.y) - (a.y * b.x);
    return c;
}
pub fn b3Lerp(arg_a: b3Vec3, arg_b: b3Vec3, arg_alpha: f32) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var alpha = arg_alpha;
    _ = &alpha;
    _ = !!((@as(f32, 0.0) <= alpha) and (alpha <= @as(f32, 1.0))) or ((blk: {
        _ = b3InternalAssert("0.0f <= alpha && alpha <= 1.0f", "../DINX/vendor/box3d-0.1.0/include/box3d/math_functions.h", @as(c_int, 365));
        break :blk 0;
    }) != 0);
    var c: b3Vec3 = b3Vec3{
        .x = ((@as(f32, 1.0) - alpha) * a.x) + (alpha * b.x),
        .y = ((@as(f32, 1.0) - alpha) * a.y) + (alpha * b.y),
        .z = ((@as(f32, 1.0) - alpha) * a.z) + (alpha * b.z),
    };
    _ = &c;
    return c;
}
pub fn b3Blend2(arg_s: f32, arg_a: b3Vec3, arg_t: f32, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var s = arg_s;
    _ = &s;
    var a = arg_a;
    _ = &a;
    var t = arg_t;
    _ = &t;
    var b = arg_b;
    _ = &b;
    var d: b3Vec3 = b3Vec3{
        .x = (s * a.x) + (t * b.x),
        .y = (s * a.y) + (t * b.y),
        .z = (s * a.z) + (t * b.z),
    };
    _ = &d;
    return d;
}
pub fn b3Abs(arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    return b3Vec3{
        .x = b3AbsFloat(a.x),
        .y = b3AbsFloat(a.y),
        .z = b3AbsFloat(a.z),
    };
}
pub fn b3Sign(arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    return b3Vec3{
        .x = if (a.x >= @as(f32, 0.0)) @as(f32, 1.0) else -@as(f32, 1.0),
        .y = if (a.y >= @as(f32, 0.0)) @as(f32, 1.0) else -@as(f32, 1.0),
        .z = if (a.z >= @as(f32, 0.0)) @as(f32, 1.0) else -@as(f32, 1.0),
    };
}
pub fn b3Min(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return b3Vec3{
        .x = b3MinFloat(a.x, b.x),
        .y = b3MinFloat(a.y, b.y),
        .z = b3MinFloat(a.z, b.z),
    };
}
pub fn b3Max(arg_a: b3Vec3, arg_b: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return b3Vec3{
        .x = b3MaxFloat(a.x, b.x),
        .y = b3MaxFloat(a.y, b.y),
        .z = b3MaxFloat(a.z, b.z),
    };
}
pub fn b3Clamp(arg_a: b3Vec3, arg_lower: b3Vec3, arg_upper: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var lower = arg_lower;
    _ = &lower;
    var upper = arg_upper;
    _ = &upper;
    var b: b3Vec3 = undefined;
    _ = &b;
    b.x = b3ClampFloat(a.x, lower.x, upper.x);
    b.y = b3ClampFloat(a.y, lower.y, upper.y);
    b.z = b3ClampFloat(a.z, lower.z, upper.z);
    return b;
}
pub fn b3SafeScale(arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var absScale: b3Vec3 = b3Abs(a);
    _ = &absScale;
    var minScale: b3Vec3 = b3Vec3{
        .x = B3_MIN_SCALE,
        .y = B3_MIN_SCALE,
        .z = B3_MIN_SCALE,
    };
    _ = &minScale;
    var safeScale: b3Vec3 = b3Mul(b3Sign(a), b3Max(absScale, minScale));
    _ = &safeScale;
    return safeScale;
}
pub fn b3IsNormalizedQuat(arg_q: b3Quat) callconv(.c) bool {
    var q = arg_q;
    _ = &q;
    var qq: f32 = (((q.v.x * q.v.x) + (q.v.y * q.v.y)) + (q.v.z * q.v.z)) + (q.s * q.s);
    _ = &qq;
    return ((@as(f32, 1.0) - (@as(f32, 20.0) * __FLT_EPSILON__)) < qq) and (qq < (@as(f32, 1.0) + (@as(f32, 20.0) * __FLT_EPSILON__)));
}
pub fn b3RotateVector(arg_q: b3Quat, arg_v: b3Vec3) callconv(.c) b3Vec3 {
    var q = arg_q;
    _ = &q;
    var v = arg_v;
    _ = &v;
    var t1: b3Vec3 = b3Cross(q.v, v);
    _ = &t1;
    var t2: b3Vec3 = b3MulAdd(t1, q.s, v);
    _ = &t2;
    var t3: b3Vec3 = b3Cross(q.v, t2);
    _ = &t3;
    return b3MulAdd(v, 2.0, t3);
}
pub fn b3InvRotateVector(arg_q: b3Quat, arg_v: b3Vec3) callconv(.c) b3Vec3 {
    var q = arg_q;
    _ = &q;
    var v = arg_v;
    _ = &v;
    var t1: b3Vec3 = b3Cross(q.v, v);
    _ = &t1;
    var t2: b3Vec3 = b3MulSub(t1, q.s, v);
    _ = &t2;
    var t3: b3Vec3 = b3Cross(q.v, t2);
    _ = &t3;
    return b3MulAdd(v, 2.0, t3);
}
pub fn b3DotQuat(arg_a: b3Quat, arg_b: b3Quat) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return (((a.v.x * b.v.x) + (a.v.y * b.v.y)) + (a.v.z * b.v.z)) + (a.s * b.s);
}
pub fn b3MulQuat(arg_q1: b3Quat, arg_q2: b3Quat) callconv(.c) b3Quat {
    var q1 = arg_q1;
    _ = &q1;
    var q2 = arg_q2;
    _ = &q2;
    var t1: b3Vec3 = b3Cross(q1.v, q2.v);
    _ = &t1;
    var t2: b3Vec3 = b3MulAdd(t1, q1.s, q2.v);
    _ = &t2;
    var t3: b3Vec3 = b3MulAdd(t2, q2.s, q1.v);
    _ = &t3;
    var q: b3Quat = b3Quat{
        .v = t3,
        .s = (q1.s * q2.s) - b3Dot(q1.v, q2.v),
    };
    _ = &q;
    return q;
}
pub fn b3InvMulQuat(arg_q1: b3Quat, arg_q2: b3Quat) callconv(.c) b3Quat {
    var q1 = arg_q1;
    _ = &q1;
    var q2 = arg_q2;
    _ = &q2;
    var t1: b3Vec3 = b3Cross(q2.v, q1.v);
    _ = &t1;
    var t2: b3Vec3 = b3MulAdd(t1, q1.s, q2.v);
    _ = &t2;
    var t3: b3Vec3 = b3MulSub(t2, q2.s, q1.v);
    _ = &t3;
    var q: b3Quat = b3Quat{
        .v = t3,
        .s = (q1.s * q2.s) + b3Dot(q1.v, q2.v),
    };
    _ = &q;
    return q;
}
pub fn b3Conjugate(arg_q: b3Quat) callconv(.c) b3Quat {
    var q = arg_q;
    _ = &q;
    return b3Quat{
        .v = b3Vec3{
            .x = -q.v.x,
            .y = -q.v.y,
            .z = -q.v.z,
        },
        .s = q.s,
    };
}
pub fn b3NegateQuat(arg_q: b3Quat) callconv(.c) b3Quat {
    var q = arg_q;
    _ = &q;
    return b3Quat{
        .v = b3Vec3{
            .x = -q.v.x,
            .y = -q.v.y,
            .z = -q.v.z,
        },
        .s = -q.s,
    };
}
pub fn b3NormalizeQuat(arg_q: b3Quat) callconv(.c) b3Quat {
    var q = arg_q;
    _ = &q;
    var lengthSq: f32 = b3DotQuat(q, q);
    _ = &lengthSq;
    if (lengthSq > (@as(f32, 1000.0) * __FLT_MIN__)) {
        var s: f32 = @as(f32, 1.0) / sqrtf(lengthSq);
        _ = &s;
        var qn: b3Quat = b3Quat{
            .v = b3Vec3{
                .x = s * q.v.x,
                .y = s * q.v.y,
                .z = s * q.v.z,
            },
            .s = s * q.s,
        };
        _ = &qn;
        return qn;
    }
    return b3Quat_identity;
}
pub fn b3MakeQuatFromAxisAngle(arg_axis: b3Vec3, arg_radians: f32) callconv(.c) b3Quat {
    var axis = arg_axis;
    _ = &axis;
    var radians = arg_radians;
    _ = &radians;
    _ = !!b3IsNormalized(axis) or ((blk: {
        _ = b3InternalAssert("b3IsNormalized( axis )", "../DINX/vendor/box3d-0.1.0/include/box3d/math_functions.h", @as(c_int, 531));
        break :blk 0;
    }) != 0);
    var cs: b3CosSin = b3ComputeCosSin(@as(f32, 0.5) * radians);
    _ = &cs;
    var q: b3Quat = b3Quat{
        .v = b3Vec3{
            .x = cs.sine * axis.x,
            .y = cs.sine * axis.y,
            .z = cs.sine * axis.z,
        },
        .s = cs.cosine,
    };
    _ = &q;
    return q;
}
pub fn b3GetAxisAngle(arg_radians: [*c]f32, arg_q: b3Quat) callconv(.c) b3Vec3 {
    var radians = arg_radians;
    _ = &radians;
    var q = arg_q;
    _ = &q;
    var length: f32 = sqrtf(((q.v.x * q.v.x) + (q.v.y * q.v.y)) + (q.v.z * q.v.z));
    _ = &length;
    radians.* = @as(f32, 2.0) * b3Atan2(length, q.s);
    if (length > @as(f32, 0.0)) {
        var invLength: f32 = @as(f32, 1.0) / length;
        _ = &invLength;
        var axis: b3Vec3 = b3Vec3{
            .x = invLength * q.v.x,
            .y = invLength * q.v.y,
            .z = invLength * q.v.z,
        };
        _ = &axis;
        return axis;
    }
    return b3Vec3_zero;
}
pub fn b3GetQuatAngle(arg_q: b3Quat) callconv(.c) f32 {
    var q = arg_q;
    _ = &q;
    var length: f32 = sqrtf(((q.v.x * q.v.x) + (q.v.y * q.v.y)) + (q.v.z * q.v.z));
    _ = &length;
    return @as(f32, 2.0) * b3Atan2(length, q.s);
}
pub extern fn b3MakeQuatFromMatrix(m: [*c]const b3Matrix3) b3Quat;
pub extern fn b3ComputeQuatBetweenUnitVectors(v1: b3Vec3, v2: b3Vec3) b3Quat;
pub fn b3GetTwistAngle(arg_q: b3Quat) callconv(.c) f32 {
    var q = arg_q;
    _ = &q;
    var twist: f32 = if (q.s < @as(f32, 0.0)) b3Atan2(-q.v.z, -q.s) else b3Atan2(q.v.z, q.s);
    _ = &twist;
    twist *= 2.0;
    _ = !!((-B3_PI <= twist) and (twist <= B3_PI)) or ((blk: {
        _ = b3InternalAssert("-B3_PI <= twist && twist <= B3_PI", "../DINX/vendor/box3d-0.1.0/include/box3d/math_functions.h", @as(c_int, 572));
        break :blk 0;
    }) != 0);
    return twist;
}
pub fn b3GetSwingAngle(arg_q: b3Quat) callconv(.c) f32 {
    var q = arg_q;
    _ = &q;
    var x: f32 = sqrtf((q.v.z * q.v.z) + (q.s * q.s));
    _ = &x;
    var y: f32 = sqrtf((q.v.x * q.v.x) + (q.v.y * q.v.y));
    _ = &y;
    var swing: f32 = @as(f32, 2.0) * b3Atan2(y, x);
    _ = &swing;
    _ = !!((@as(f32, 0.0) <= swing) and (swing <= B3_PI)) or ((blk: {
        _ = b3InternalAssert("0.0f <= swing && swing <= B3_PI", "../DINX/vendor/box3d-0.1.0/include/box3d/math_functions.h", @as(c_int, 583));
        break :blk 0;
    }) != 0);
    return swing;
}
pub fn b3NLerp(arg_q1: b3Quat, arg_q2: b3Quat, arg_alpha: f32) callconv(.c) b3Quat {
    var q1 = arg_q1;
    _ = &q1;
    var q2 = arg_q2;
    _ = &q2;
    var alpha = arg_alpha;
    _ = &alpha;
    _ = @as(c_int, 0);
    if (b3DotQuat(q1, q2) < @as(f32, 0.0)) {
        q1 = b3Quat{
            .v = b3Vec3{
                .x = -q1.v.x,
                .y = -q1.v.y,
                .z = -q1.v.z,
            },
            .s = -q1.s,
        };
    }
    var q: b3Quat = undefined;
    _ = &q;
    q.v = b3Lerp(q1.v, q2.v, alpha);
    q.s = ((@as(f32, 1.0) - alpha) * q1.s) + (alpha * q2.s);
    return b3NormalizeQuat(q);
}
pub fn b3MulTransforms(arg_a: b3Transform, arg_b: b3Transform) callconv(.c) b3Transform {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var out: b3Transform = undefined;
    _ = &out;
    out.p = b3Add(b3RotateVector(a.q, b.p), a.p);
    out.q = b3MulQuat(a.q, b.q);
    return out;
}
pub inline fn b3InvMulTransforms(arg_a: b3Transform, arg_b: b3Transform) b3Transform {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var out: b3Transform = undefined;
    _ = &out;
    out.p = b3InvRotateVector(a.q, b3Sub(b.p, a.p));
    out.q = b3InvMulQuat(a.q, b.q);
    return out;
}
pub fn b3InvertTransform(arg_t: b3Transform) callconv(.c) b3Transform {
    var t = arg_t;
    _ = &t;
    var out: b3Transform = undefined;
    _ = &out;
    out.p = b3InvRotateVector(t.q, b3Neg(t.p));
    out.q = b3Conjugate(t.q);
    return out;
}
pub fn b3TransformPoint(arg_t: b3Transform, arg_v: b3Vec3) callconv(.c) b3Vec3 {
    var t = arg_t;
    _ = &t;
    var v = arg_v;
    _ = &v;
    var rv: b3Vec3 = b3RotateVector(t.q, v);
    _ = &rv;
    return b3Add(rv, t.p);
}
pub fn b3InvTransformPoint(arg_t: b3Transform, arg_v: b3Vec3) callconv(.c) b3Vec3 {
    var t = arg_t;
    _ = &t;
    var v = arg_v;
    _ = &v;
    return b3InvRotateVector(t.q, b3Sub(v, t.p));
}
pub fn b3ToPos(arg_v: b3Vec3) callconv(.c) b3Pos {
    var v = arg_v;
    _ = &v;
    return b3Pos{
        .x = v.x,
        .y = v.y,
        .z = v.z,
    };
}
pub fn b3ToVec3(arg_p: b3Pos) callconv(.c) b3Vec3 {
    var p = arg_p;
    _ = &p;
    return b3Vec3{
        .x = p.x,
        .y = p.y,
        .z = p.z,
    };
}
pub fn b3RoundDownFloat(arg_x: f64) callconv(.c) f32 {
    var x = arg_x;
    _ = &x;
    return @floatCast(x);
}
pub fn b3RoundUpFloat(arg_x: f64) callconv(.c) f32 {
    var x = arg_x;
    _ = &x;
    return @floatCast(x);
}
pub fn b3SubPos(arg_a: b3Pos, arg_b: b3Pos) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return b3Vec3{
        .x = a.x - b.x,
        .y = a.y - b.y,
        .z = a.z - b.z,
    };
}
pub fn b3OffsetPos(arg_p: b3Pos, arg_d: b3Vec3) callconv(.c) b3Pos {
    var p = arg_p;
    _ = &p;
    var d = arg_d;
    _ = &d;
    return b3Pos{
        .x = p.x + d.x,
        .y = p.y + d.y,
        .z = p.z + d.z,
    };
}
pub fn b3LerpPosition(arg_a: b3Pos, arg_b: b3Pos, arg_t: f32) callconv(.c) b3Pos {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var t = arg_t;
    _ = &t;
    return b3Pos{
        .x = ((@as(f32, 1.0) - t) * a.x) + (t * b.x),
        .y = ((@as(f32, 1.0) - t) * a.y) + (t * b.y),
        .z = ((@as(f32, 1.0) - t) * a.z) + (t * b.z),
    };
}
pub fn b3TransformWorldPoint(arg_t: b3WorldTransform, arg_p: b3Vec3) callconv(.c) b3Pos {
    var t = arg_t;
    _ = &t;
    var p = arg_p;
    _ = &p;
    var r: b3Vec3 = b3RotateVector(t.q, p);
    _ = &r;
    return b3Pos{
        .x = t.p.x + r.x,
        .y = t.p.y + r.y,
        .z = t.p.z + r.z,
    };
}
pub fn b3InvTransformWorldPoint(arg_t: b3WorldTransform, arg_p: b3Pos) callconv(.c) b3Vec3 {
    var t = arg_t;
    _ = &t;
    var p = arg_p;
    _ = &p;
    var d: b3Vec3 = b3Vec3{
        .x = p.x - t.p.x,
        .y = p.y - t.p.y,
        .z = p.z - t.p.z,
    };
    _ = &d;
    return b3InvRotateVector(t.q, d);
}
pub fn b3InvMulWorldTransforms(arg_A: b3WorldTransform, arg_B: b3WorldTransform) callconv(.c) b3Transform {
    var A = arg_A;
    _ = &A;
    var B = arg_B;
    _ = &B;
    var C: b3Transform = undefined;
    _ = &C;
    C.q = b3InvMulQuat(A.q, B.q);
    var d: b3Vec3 = b3Vec3{
        .x = B.p.x - A.p.x,
        .y = B.p.y - A.p.y,
        .z = B.p.z - A.p.z,
    };
    _ = &d;
    C.p = b3InvRotateVector(A.q, d);
    return C;
}
pub fn b3MulWorldTransforms(arg_A: b3WorldTransform, arg_B: b3Transform) callconv(.c) b3WorldTransform {
    var A = arg_A;
    _ = &A;
    var B = arg_B;
    _ = &B;
    var C: b3WorldTransform = undefined;
    _ = &C;
    C.q = b3MulQuat(A.q, B.q);
    var r: b3Vec3 = b3RotateVector(A.q, B.p);
    _ = &r;
    C.p = b3Pos{
        .x = A.p.x + r.x,
        .y = A.p.y + r.y,
        .z = A.p.z + r.z,
    };
    return C;
}
pub fn b3ToRelativeTransform(arg_t: b3WorldTransform, arg_base: b3Pos) callconv(.c) b3Transform {
    var t = arg_t;
    _ = &t;
    var base = arg_base;
    _ = &base;
    var r: b3Transform = undefined;
    _ = &r;
    r.q = t.q;
    r.p = b3Vec3{
        .x = t.p.x - base.x,
        .y = t.p.y - base.y,
        .z = t.p.z - base.z,
    };
    return r;
}
pub fn b3MakeWorldTransform(arg_t: b3Transform) callconv(.c) b3WorldTransform {
    var t = arg_t;
    _ = &t;
    var w: b3WorldTransform = undefined;
    _ = &w;
    w.p = b3ToPos(t.p);
    w.q = t.q;
    return w;
}
pub fn b3OffsetAABB(arg_localBox: b3AABB, arg_origin: b3Pos) callconv(.c) b3AABB {
    var localBox = arg_localBox;
    _ = &localBox;
    var origin = arg_origin;
    _ = &origin;
    var out: b3AABB = undefined;
    _ = &out;
    out.lowerBound.x = b3RoundDownFloat(@floatCast(origin.x + localBox.lowerBound.x));
    out.lowerBound.y = b3RoundDownFloat(@floatCast(origin.y + localBox.lowerBound.y));
    out.lowerBound.z = b3RoundDownFloat(@floatCast(origin.z + localBox.lowerBound.z));
    out.upperBound.x = b3RoundUpFloat(@floatCast(origin.x + localBox.upperBound.x));
    out.upperBound.y = b3RoundUpFloat(@floatCast(origin.y + localBox.upperBound.y));
    out.upperBound.z = b3RoundUpFloat(@floatCast(origin.z + localBox.upperBound.z));
    return out;
}
pub fn b3Det(arg_m: b3Matrix3) callconv(.c) f32 {
    var m = arg_m;
    _ = &m;
    return b3Dot(m.cx, b3Cross(m.cy, m.cz));
}
pub fn b3MulMV(arg_m: b3Matrix3, arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var m = arg_m;
    _ = &m;
    var a = arg_a;
    _ = &a;
    var b: b3Vec3 = b3Vec3{
        .x = ((m.cx.x * a.x) + (m.cy.x * a.y)) + (m.cz.x * a.z),
        .y = ((m.cx.y * a.x) + (m.cy.y * a.y)) + (m.cz.y * a.z),
        .z = ((m.cx.z * a.x) + (m.cy.z * a.y)) + (m.cz.z * a.z),
    };
    _ = &b;
    return b;
}
pub fn b3NegateMat3(arg_a: b3Matrix3) callconv(.c) b3Matrix3 {
    var a = arg_a;
    _ = &a;
    return b3Matrix3{
        .cx = b3Vec3{
            .x = -a.cx.x,
            .y = -a.cx.y,
            .z = -a.cx.z,
        },
        .cy = b3Vec3{
            .x = -a.cy.x,
            .y = -a.cy.y,
            .z = -a.cy.z,
        },
        .cz = b3Vec3{
            .x = -a.cz.x,
            .y = -a.cz.y,
            .z = -a.cz.z,
        },
    };
}
pub fn b3AddMM(arg_a: b3Matrix3, arg_b: b3Matrix3) callconv(.c) b3Matrix3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return b3Matrix3{
        .cx = b3Vec3{
            .x = a.cx.x + b.cx.x,
            .y = a.cx.y + b.cx.y,
            .z = a.cx.z + b.cx.z,
        },
        .cy = b3Vec3{
            .x = a.cy.x + b.cy.x,
            .y = a.cy.y + b.cy.y,
            .z = a.cy.z + b.cy.z,
        },
        .cz = b3Vec3{
            .x = a.cz.x + b.cz.x,
            .y = a.cz.y + b.cz.y,
            .z = a.cz.z + b.cz.z,
        },
    };
}
pub fn b3SubMM(arg_a: b3Matrix3, arg_b: b3Matrix3) callconv(.c) b3Matrix3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return b3Matrix3{
        .cx = b3Vec3{
            .x = a.cx.x - b.cx.x,
            .y = a.cx.y - b.cx.y,
            .z = a.cx.z - b.cx.z,
        },
        .cy = b3Vec3{
            .x = a.cy.x - b.cy.x,
            .y = a.cy.y - b.cy.y,
            .z = a.cy.z - b.cy.z,
        },
        .cz = b3Vec3{
            .x = a.cz.x - b.cz.x,
            .y = a.cz.y - b.cz.y,
            .z = a.cz.z - b.cz.z,
        },
    };
}
pub fn b3MulSM(arg_s: f32, arg_a: b3Matrix3) callconv(.c) b3Matrix3 {
    var s = arg_s;
    _ = &s;
    var a = arg_a;
    _ = &a;
    return b3Matrix3{
        .cx = b3Vec3{
            .x = s * a.cx.x,
            .y = s * a.cx.y,
            .z = s * a.cx.z,
        },
        .cy = b3Vec3{
            .x = s * a.cy.x,
            .y = s * a.cy.y,
            .z = s * a.cy.z,
        },
        .cz = b3Vec3{
            .x = s * a.cz.x,
            .y = s * a.cz.y,
            .z = s * a.cz.z,
        },
    };
}
pub fn b3MulMM(arg_a: b3Matrix3, arg_b: b3Matrix3) callconv(.c) b3Matrix3 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var out: b3Matrix3 = undefined;
    _ = &out;
    out.cx = b3MulMV(a, b.cx);
    out.cy = b3MulMV(a, b.cy);
    out.cz = b3MulMV(a, b.cz);
    return out;
}
pub fn b3Transpose(arg_m: b3Matrix3) callconv(.c) b3Matrix3 {
    var m = arg_m;
    _ = &m;
    var out: b3Matrix3 = undefined;
    _ = &out;
    out.cx = b3Vec3{
        .x = m.cx.x,
        .y = m.cy.x,
        .z = m.cz.x,
    };
    out.cy = b3Vec3{
        .x = m.cx.y,
        .y = m.cy.y,
        .z = m.cz.y,
    };
    out.cz = b3Vec3{
        .x = m.cx.z,
        .y = m.cy.z,
        .z = m.cz.z,
    };
    return out;
}
pub fn b3InvertMatrix(arg_m: b3Matrix3) callconv(.c) b3Matrix3 {
    var m = arg_m;
    _ = &m;
    var det: f32 = b3Det(m);
    _ = &det;
    if (b3AbsFloat(det) > (@as(f32, 1000.0) * __FLT_MIN__)) {
        var invDet: f32 = @as(f32, 1.0) / det;
        _ = &invDet;
        var out: b3Matrix3 = undefined;
        _ = &out;
        out.cx = b3MulSV(invDet, b3Cross(m.cy, m.cz));
        out.cy = b3MulSV(invDet, b3Cross(m.cz, m.cx));
        out.cz = b3MulSV(invDet, b3Cross(m.cx, m.cy));
        return b3Transpose(out);
    }
    return b3Mat3_zero;
}
pub fn b3Solve3(arg_m: b3Matrix3, arg_a: b3Vec3) callconv(.c) b3Vec3 {
    var m = arg_m;
    _ = &m;
    var a = arg_a;
    _ = &a;
    var det: f32 = b3Det(m);
    _ = &det;
    if (b3AbsFloat(det) > (@as(f32, 1000.0) * __FLT_MIN__)) {
        var invDet: f32 = @as(f32, 1.0) / det;
        _ = &invDet;
        var s: b3Matrix3 = undefined;
        _ = &s;
        s.cx = b3Cross(m.cy, m.cz);
        s.cy = b3Cross(m.cz, m.cx);
        s.cz = b3Cross(m.cx, m.cy);
        var b: b3Vec3 = b3Vec3{
            .x = invDet * b3Dot(s.cx, a),
            .y = invDet * b3Dot(s.cy, a),
            .z = invDet * b3Dot(s.cz, a),
        };
        _ = &b;
        return b;
    }
    return b3Vec3_zero;
}
pub fn b3InvertT(arg_m: b3Matrix3) callconv(.c) b3Matrix3 {
    var m = arg_m;
    _ = &m;
    var det: f32 = b3Det(m);
    _ = &det;
    if (b3AbsFloat(det) > (@as(f32, 1000.0) * __FLT_MIN__)) {
        var invDet: f32 = @as(f32, 1.0) / det;
        _ = &invDet;
        var out: b3Matrix3 = undefined;
        _ = &out;
        out.cx = b3MulSV(invDet, b3Cross(m.cy, m.cz));
        out.cy = b3MulSV(invDet, b3Cross(m.cz, m.cx));
        out.cz = b3MulSV(invDet, b3Cross(m.cx, m.cy));
        return out;
    }
    return b3Mat3_zero;
}
pub fn b3AbsMatrix3(arg_m: b3Matrix3) callconv(.c) b3Matrix3 {
    var m = arg_m;
    _ = &m;
    var out: b3Matrix3 = undefined;
    _ = &out;
    out.cx = b3Abs(m.cx);
    out.cy = b3Abs(m.cy);
    out.cz = b3Abs(m.cz);
    return out;
}
pub inline fn b3MakeMatrixFromQuat(arg_q: b3Quat) b3Matrix3 {
    var q = arg_q;
    _ = &q;
    var xx: f32 = q.v.x * q.v.x;
    _ = &xx;
    var yy: f32 = q.v.y * q.v.y;
    _ = &yy;
    var zz: f32 = q.v.z * q.v.z;
    _ = &zz;
    var xy: f32 = q.v.x * q.v.y;
    _ = &xy;
    var xz: f32 = q.v.x * q.v.z;
    _ = &xz;
    var xw: f32 = q.v.x * q.s;
    _ = &xw;
    var yz: f32 = q.v.y * q.v.z;
    _ = &yz;
    var yw: f32 = q.v.y * q.s;
    _ = &yw;
    var zw: f32 = q.v.z * q.s;
    _ = &zw;
    return b3Matrix3{
        .cx = b3Vec3{
            .x = @as(f32, 1.0) - (@as(f32, 2.0) * (yy + zz)),
            .y = @as(f32, 2.0) * (xy + zw),
            .z = @as(f32, 2.0) * (xz - yw),
        },
        .cy = b3Vec3{
            .x = @as(f32, 2.0) * (xy - zw),
            .y = @as(f32, 1.0) - (@as(f32, 2.0) * (xx + zz)),
            .z = @as(f32, 2.0) * (yz + xw),
        },
        .cz = b3Vec3{
            .x = @as(f32, 2.0) * (xz + yw),
            .y = @as(f32, 2.0) * (yz - xw),
            .z = @as(f32, 1.0) - (@as(f32, 2.0) * (xx + yy)),
        },
    };
}
pub extern fn b3Steiner(mass: f32, origin: b3Vec3) b3Matrix3;
pub fn b3MakeAABB(arg_points: [*c]const b3Vec3, arg_count: c_int, arg_radius: f32) callconv(.c) b3AABB {
    var points = arg_points;
    _ = &points;
    var count = arg_count;
    _ = &count;
    var radius = arg_radius;
    _ = &radius;
    _ = !!(count > @as(c_int, 0)) or ((blk: {
        _ = b3InternalAssert("count > 0", "../DINX/vendor/box3d-0.1.0/include/box3d/math_functions.h", @as(c_int, 958));
        break :blk 0;
    }) != 0);
    var a: b3AABB = b3AABB{
        .lowerBound = points[@as(c_int, 0)],
        .upperBound = points[@as(c_int, 0)],
    };
    _ = &a;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < count) : (i += 1) {
            a.lowerBound = b3Min(a.lowerBound, points[@bitCast(@as(isize, @intCast(i)))]);
            a.upperBound = b3Max(a.upperBound, points[@bitCast(@as(isize, @intCast(i)))]);
        }
    }
    var r: b3Vec3 = b3Vec3{
        .x = radius,
        .y = radius,
        .z = radius,
    };
    _ = &r;
    a.lowerBound = b3Sub(a.lowerBound, r);
    a.upperBound = b3Add(a.upperBound, r);
    return a;
}
pub fn b3AABB_Contains(arg_a: b3AABB, arg_b: b3AABB) callconv(.c) bool {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.lowerBound.x > b.lowerBound.x) or (b.upperBound.x > a.upperBound.x)) return @"false" != 0;
    if ((a.lowerBound.y > b.lowerBound.y) or (b.upperBound.y > a.upperBound.y)) return @"false" != 0;
    if ((a.lowerBound.z > b.lowerBound.z) or (b.upperBound.z > a.upperBound.z)) return @"false" != 0;
    return @"true" != 0;
}
pub fn b3AABB_Area(arg_a: b3AABB) callconv(.c) f32 {
    var a = arg_a;
    _ = &a;
    var delta: b3Vec3 = b3Sub(a.upperBound, a.lowerBound);
    _ = &delta;
    return @as(f32, 2.0) * (((delta.x * delta.y) + (delta.y * delta.z)) + (delta.z * delta.x));
}
pub fn b3AABB_Center(arg_a: b3AABB) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    return b3MulSV(0.5, b3Add(a.upperBound, a.lowerBound));
}
pub fn b3AABB_Extents(arg_a: b3AABB) callconv(.c) b3Vec3 {
    var a = arg_a;
    _ = &a;
    return b3MulSV(0.5, b3Sub(a.upperBound, a.lowerBound));
}
pub fn b3AABB_Union(arg_a: b3AABB, arg_b: b3AABB) callconv(.c) b3AABB {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var out: b3AABB = undefined;
    _ = &out;
    out.lowerBound = b3Min(a.lowerBound, b.lowerBound);
    out.upperBound = b3Max(a.upperBound, b.upperBound);
    return out;
}
pub fn b3AABB_Inflate(arg_a: b3AABB, arg_extension: f32) callconv(.c) b3AABB {
    var a = arg_a;
    _ = &a;
    var extension = arg_extension;
    _ = &extension;
    var radius: b3Vec3 = b3Vec3{
        .x = extension,
        .y = extension,
        .z = extension,
    };
    _ = &radius;
    var out: b3AABB = undefined;
    _ = &out;
    out.lowerBound = b3Sub(a.lowerBound, radius);
    out.upperBound = b3Add(a.upperBound, radius);
    return out;
}
pub fn b3AABB_Overlaps(arg_a: b3AABB, arg_b: b3AABB) callconv(.c) bool {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.upperBound.x < b.lowerBound.x) or (a.lowerBound.x > b.upperBound.x)) return @"false" != 0;
    if ((a.upperBound.y < b.lowerBound.y) or (a.lowerBound.y > b.upperBound.y)) return @"false" != 0;
    if ((a.upperBound.z < b.lowerBound.z) or (a.lowerBound.z > b.upperBound.z)) return @"false" != 0;
    return @"true" != 0;
}
pub fn b3AABB_Transform(arg_transform: b3Transform, arg_a: b3AABB) callconv(.c) b3AABB {
    var transform = arg_transform;
    _ = &transform;
    var a = arg_a;
    _ = &a;
    var center: b3Vec3 = b3TransformPoint(transform, b3AABB_Center(a));
    _ = &center;
    var m: b3Matrix3 = b3MakeMatrixFromQuat(transform.q);
    _ = &m;
    var extent: b3Vec3 = b3MulMV(b3AbsMatrix3(m), b3AABB_Extents(a));
    _ = &extent;
    var out: b3AABB = b3AABB{
        .lowerBound = b3Sub(center, extent),
        .upperBound = b3Add(center, extent),
    };
    _ = &out;
    return out;
}
pub fn b3ClosestPointToAABB(arg_point: b3Vec3, arg_a: b3AABB) callconv(.c) b3Vec3 {
    var point = arg_point;
    _ = &point;
    var a = arg_a;
    _ = &a;
    return b3Clamp(point, a.lowerBound, a.upperBound);
}
pub const struct_b3SegmentDistanceResult = extern struct {
    point1: b3Vec3,
    fraction1: f32,
    point2: b3Vec3,
    fraction2: f32,
};
pub const b3SegmentDistanceResult = struct_b3SegmentDistanceResult;
pub extern fn b3PointToSegmentDistance(a: b3Vec3, b: b3Vec3, q: b3Vec3) b3Vec3;
pub extern fn b3LineDistance(p1: b3Vec3, d1: b3Vec3, p2: b3Vec3, d2: b3Vec3) b3SegmentDistanceResult;
pub extern fn b3SegmentDistance(p1: b3Vec3, q1: b3Vec3, p2: b3Vec3, q2: b3Vec3) b3SegmentDistanceResult;
pub extern fn b3IsValidVec3(a: b3Vec3) bool;
pub extern fn b3IsValidQuat(q: b3Quat) bool;
pub extern fn b3IsValidTransform(a: b3Transform) bool;
pub extern fn b3IsValidMatrix3(a: b3Matrix3) bool;
pub extern fn b3IsValidAABB(a: b3AABB) bool;
pub extern fn b3IsBoundedAABB(a: b3AABB) bool;
pub extern fn b3IsSaneAABB(a: b3AABB) bool;
pub extern fn b3IsValidPlane(a: b3Plane) bool;
pub extern fn b3IsValidPosition(p: b3Pos) bool;
pub extern fn b3IsValidWorldTransform(t: b3WorldTransform) bool;
pub extern fn b3SetLengthUnitsPerMeter(lengthUnits: f32) void;
pub extern fn b3GetLengthUnitsPerMeter() f32;
pub extern fn b3SetStallThreshold(seconds: f32) void;
pub extern fn b3GetStallThreshold() f32;
pub const struct_b3WorldId = extern struct {
    index1: u16,
    generation: u16,
    pub const b3StoreWorldId = __root.b3StoreWorldId;
    pub const b3DestroyWorld = __root.b3DestroyWorld;
    pub const b3World_IsValid = __root.b3World_IsValid;
    pub const b3World_Step = __root.b3World_Step;
    pub const b3World_Draw = __root.b3World_Draw;
    pub const b3World_GetBounds = __root.b3World_GetBounds;
    pub const b3World_GetBodyEvents = __root.b3World_GetBodyEvents;
    pub const b3World_GetSensorEvents = __root.b3World_GetSensorEvents;
    pub const b3World_GetContactEvents = __root.b3World_GetContactEvents;
    pub const b3World_GetJointEvents = __root.b3World_GetJointEvents;
    pub const b3World_OverlapAABB = __root.b3World_OverlapAABB;
    pub const b3World_OverlapShape = __root.b3World_OverlapShape;
    pub const b3World_CastRay = __root.b3World_CastRay;
    pub const b3World_CastRayClosest = __root.b3World_CastRayClosest;
    pub const b3World_CastShape = __root.b3World_CastShape;
    pub const b3World_CastMover = __root.b3World_CastMover;
    pub const b3World_CollideMover = __root.b3World_CollideMover;
    pub const b3World_EnableSleeping = __root.b3World_EnableSleeping;
    pub const b3World_IsSleepingEnabled = __root.b3World_IsSleepingEnabled;
    pub const b3World_EnableContinuous = __root.b3World_EnableContinuous;
    pub const b3World_IsContinuousEnabled = __root.b3World_IsContinuousEnabled;
    pub const b3World_SetRestitutionThreshold = __root.b3World_SetRestitutionThreshold;
    pub const b3World_GetRestitutionThreshold = __root.b3World_GetRestitutionThreshold;
    pub const b3World_SetHitEventThreshold = __root.b3World_SetHitEventThreshold;
    pub const b3World_GetHitEventThreshold = __root.b3World_GetHitEventThreshold;
    pub const b3World_SetCustomFilterCallback = __root.b3World_SetCustomFilterCallback;
    pub const b3World_SetPreSolveCallback = __root.b3World_SetPreSolveCallback;
    pub const b3World_SetGravity = __root.b3World_SetGravity;
    pub const b3World_GetGravity = __root.b3World_GetGravity;
    pub const b3World_Explode = __root.b3World_Explode;
    pub const b3World_SetContactTuning = __root.b3World_SetContactTuning;
    pub const b3World_SetContactRecycleDistance = __root.b3World_SetContactRecycleDistance;
    pub const b3World_GetContactRecycleDistance = __root.b3World_GetContactRecycleDistance;
    pub const b3World_SetMaximumLinearSpeed = __root.b3World_SetMaximumLinearSpeed;
    pub const b3World_GetMaximumLinearSpeed = __root.b3World_GetMaximumLinearSpeed;
    pub const b3World_EnableWarmStarting = __root.b3World_EnableWarmStarting;
    pub const b3World_IsWarmStartingEnabled = __root.b3World_IsWarmStartingEnabled;
    pub const b3World_GetAwakeBodyCount = __root.b3World_GetAwakeBodyCount;
    pub const b3World_GetProfile = __root.b3World_GetProfile;
    pub const b3World_GetCounters = __root.b3World_GetCounters;
    pub const b3World_GetMaxCapacity = __root.b3World_GetMaxCapacity;
    pub const b3World_SetUserData = __root.b3World_SetUserData;
    pub const b3World_GetUserData = __root.b3World_GetUserData;
    pub const b3World_SetFrictionCallback = __root.b3World_SetFrictionCallback;
    pub const b3World_SetRestitutionCallback = __root.b3World_SetRestitutionCallback;
    pub const b3World_SetWorkerCount = __root.b3World_SetWorkerCount;
    pub const b3World_GetWorkerCount = __root.b3World_GetWorkerCount;
    pub const b3World_DumpMemoryStats = __root.b3World_DumpMemoryStats;
    pub const b3World_DumpShapeBounds = __root.b3World_DumpShapeBounds;
    pub const b3World_RebuildStaticTree = __root.b3World_RebuildStaticTree;
    pub const b3World_EnableSpeculative = __root.b3World_EnableSpeculative;
    pub const b3World_DumpAwake = __root.b3World_DumpAwake;
    pub const b3World_Dump = __root.b3World_Dump;
    pub const b3World_StartRecording = __root.b3World_StartRecording;
    pub const b3World_StopRecording = __root.b3World_StopRecording;
    pub const b3CreateBody = __root.b3CreateBody;
    pub const b3CreateParallelJoint = __root.b3CreateParallelJoint;
    pub const b3CreateDistanceJoint = __root.b3CreateDistanceJoint;
    pub const b3CreateMotorJoint = __root.b3CreateMotorJoint;
    pub const b3CreateFilterJoint = __root.b3CreateFilterJoint;
    pub const b3CreatePrismaticJoint = __root.b3CreatePrismaticJoint;
    pub const b3CreateRevoluteJoint = __root.b3CreateRevoluteJoint;
    pub const b3CreateSphericalJoint = __root.b3CreateSphericalJoint;
    pub const b3CreateWeldJoint = __root.b3CreateWeldJoint;
    pub const b3CreateWheelJoint = __root.b3CreateWheelJoint;
    pub const IsValid = __root.b3World_IsValid;
    pub const Step = __root.b3World_Step;
    pub const Draw = __root.b3World_Draw;
    pub const GetBounds = __root.b3World_GetBounds;
    pub const GetBodyEvents = __root.b3World_GetBodyEvents;
    pub const GetSensorEvents = __root.b3World_GetSensorEvents;
    pub const GetContactEvents = __root.b3World_GetContactEvents;
    pub const GetJointEvents = __root.b3World_GetJointEvents;
    pub const OverlapAABB = __root.b3World_OverlapAABB;
    pub const OverlapShape = __root.b3World_OverlapShape;
    pub const CastRay = __root.b3World_CastRay;
    pub const CastRayClosest = __root.b3World_CastRayClosest;
    pub const CastShape = __root.b3World_CastShape;
    pub const CastMover = __root.b3World_CastMover;
    pub const CollideMover = __root.b3World_CollideMover;
    pub const EnableSleeping = __root.b3World_EnableSleeping;
    pub const IsSleepingEnabled = __root.b3World_IsSleepingEnabled;
    pub const EnableContinuous = __root.b3World_EnableContinuous;
    pub const IsContinuousEnabled = __root.b3World_IsContinuousEnabled;
    pub const SetRestitutionThreshold = __root.b3World_SetRestitutionThreshold;
    pub const GetRestitutionThreshold = __root.b3World_GetRestitutionThreshold;
    pub const SetHitEventThreshold = __root.b3World_SetHitEventThreshold;
    pub const GetHitEventThreshold = __root.b3World_GetHitEventThreshold;
    pub const SetCustomFilterCallback = __root.b3World_SetCustomFilterCallback;
    pub const SetPreSolveCallback = __root.b3World_SetPreSolveCallback;
    pub const SetGravity = __root.b3World_SetGravity;
    pub const GetGravity = __root.b3World_GetGravity;
    pub const Explode = __root.b3World_Explode;
    pub const SetContactTuning = __root.b3World_SetContactTuning;
    pub const SetContactRecycleDistance = __root.b3World_SetContactRecycleDistance;
    pub const GetContactRecycleDistance = __root.b3World_GetContactRecycleDistance;
    pub const SetMaximumLinearSpeed = __root.b3World_SetMaximumLinearSpeed;
    pub const GetMaximumLinearSpeed = __root.b3World_GetMaximumLinearSpeed;
    pub const EnableWarmStarting = __root.b3World_EnableWarmStarting;
    pub const IsWarmStartingEnabled = __root.b3World_IsWarmStartingEnabled;
    pub const GetAwakeBodyCount = __root.b3World_GetAwakeBodyCount;
    pub const GetProfile = __root.b3World_GetProfile;
    pub const GetCounters = __root.b3World_GetCounters;
    pub const GetMaxCapacity = __root.b3World_GetMaxCapacity;
    pub const SetUserData = __root.b3World_SetUserData;
    pub const GetUserData = __root.b3World_GetUserData;
    pub const SetFrictionCallback = __root.b3World_SetFrictionCallback;
    pub const SetRestitutionCallback = __root.b3World_SetRestitutionCallback;
    pub const SetWorkerCount = __root.b3World_SetWorkerCount;
    pub const GetWorkerCount = __root.b3World_GetWorkerCount;
    pub const DumpMemoryStats = __root.b3World_DumpMemoryStats;
    pub const DumpShapeBounds = __root.b3World_DumpShapeBounds;
    pub const RebuildStaticTree = __root.b3World_RebuildStaticTree;
    pub const EnableSpeculative = __root.b3World_EnableSpeculative;
    pub const DumpAwake = __root.b3World_DumpAwake;
    pub const Dump = __root.b3World_Dump;
    pub const StartRecording = __root.b3World_StartRecording;
    pub const StopRecording = __root.b3World_StopRecording;
};
pub const b3WorldId = struct_b3WorldId;
pub const struct_b3BodyId = extern struct {
    index1: i32,
    world0: u16,
    generation: u16,
    pub const b3StoreBodyId = __root.b3StoreBodyId;
    pub const b3DestroyBody = __root.b3DestroyBody;
    pub const b3Body_IsValid = __root.b3Body_IsValid;
    pub const b3Body_GetType = __root.b3Body_GetType;
    pub const b3Body_SetType = __root.b3Body_SetType;
    pub const b3Body_SetName = __root.b3Body_SetName;
    pub const b3Body_GetName = __root.b3Body_GetName;
    pub const b3Body_SetUserData = __root.b3Body_SetUserData;
    pub const b3Body_GetUserData = __root.b3Body_GetUserData;
    pub const b3Body_GetPosition = __root.b3Body_GetPosition;
    pub const b3Body_GetRotation = __root.b3Body_GetRotation;
    pub const b3Body_GetTransform = __root.b3Body_GetTransform;
    pub const b3Body_SetTransform = __root.b3Body_SetTransform;
    pub const b3Body_GetLocalPoint = __root.b3Body_GetLocalPoint;
    pub const b3Body_GetWorldPoint = __root.b3Body_GetWorldPoint;
    pub const b3Body_GetLocalVector = __root.b3Body_GetLocalVector;
    pub const b3Body_GetWorldVector = __root.b3Body_GetWorldVector;
    pub const b3Body_GetLinearVelocity = __root.b3Body_GetLinearVelocity;
    pub const b3Body_GetAngularVelocity = __root.b3Body_GetAngularVelocity;
    pub const b3Body_SetLinearVelocity = __root.b3Body_SetLinearVelocity;
    pub const b3Body_SetAngularVelocity = __root.b3Body_SetAngularVelocity;
    pub const b3Body_SetTargetTransform = __root.b3Body_SetTargetTransform;
    pub const b3Body_GetLocalPointVelocity = __root.b3Body_GetLocalPointVelocity;
    pub const b3Body_GetWorldPointVelocity = __root.b3Body_GetWorldPointVelocity;
    pub const b3Body_ApplyForce = __root.b3Body_ApplyForce;
    pub const b3Body_ApplyForceToCenter = __root.b3Body_ApplyForceToCenter;
    pub const b3Body_ApplyTorque = __root.b3Body_ApplyTorque;
    pub const b3Body_ApplyLinearImpulse = __root.b3Body_ApplyLinearImpulse;
    pub const b3Body_ApplyLinearImpulseToCenter = __root.b3Body_ApplyLinearImpulseToCenter;
    pub const b3Body_ApplyAngularImpulse = __root.b3Body_ApplyAngularImpulse;
    pub const b3Body_GetMass = __root.b3Body_GetMass;
    pub const b3Body_GetLocalRotationalInertia = __root.b3Body_GetLocalRotationalInertia;
    pub const b3Body_GetInverseMass = __root.b3Body_GetInverseMass;
    pub const b3Body_GetWorldInverseRotationalInertia = __root.b3Body_GetWorldInverseRotationalInertia;
    pub const b3Body_GetLocalCenterOfMass = __root.b3Body_GetLocalCenterOfMass;
    pub const b3Body_GetWorldCenterOfMass = __root.b3Body_GetWorldCenterOfMass;
    pub const b3Body_SetMassData = __root.b3Body_SetMassData;
    pub const b3Body_GetMassData = __root.b3Body_GetMassData;
    pub const b3Body_ApplyMassFromShapes = __root.b3Body_ApplyMassFromShapes;
    pub const b3Body_SetLinearDamping = __root.b3Body_SetLinearDamping;
    pub const b3Body_GetLinearDamping = __root.b3Body_GetLinearDamping;
    pub const b3Body_SetAngularDamping = __root.b3Body_SetAngularDamping;
    pub const b3Body_GetAngularDamping = __root.b3Body_GetAngularDamping;
    pub const b3Body_SetGravityScale = __root.b3Body_SetGravityScale;
    pub const b3Body_GetGravityScale = __root.b3Body_GetGravityScale;
    pub const b3Body_IsAwake = __root.b3Body_IsAwake;
    pub const b3Body_SetAwake = __root.b3Body_SetAwake;
    pub const b3Body_EnableSleep = __root.b3Body_EnableSleep;
    pub const b3Body_IsSleepEnabled = __root.b3Body_IsSleepEnabled;
    pub const b3Body_SetSleepThreshold = __root.b3Body_SetSleepThreshold;
    pub const b3Body_GetSleepThreshold = __root.b3Body_GetSleepThreshold;
    pub const b3Body_IsEnabled = __root.b3Body_IsEnabled;
    pub const b3Body_Disable = __root.b3Body_Disable;
    pub const b3Body_Enable = __root.b3Body_Enable;
    pub const b3Body_SetMotionLocks = __root.b3Body_SetMotionLocks;
    pub const b3Body_GetMotionLocks = __root.b3Body_GetMotionLocks;
    pub const b3Body_SetBullet = __root.b3Body_SetBullet;
    pub const b3Body_IsBullet = __root.b3Body_IsBullet;
    pub const b3Body_EnableContactRecycling = __root.b3Body_EnableContactRecycling;
    pub const b3Body_IsContactRecyclingEnabled = __root.b3Body_IsContactRecyclingEnabled;
    pub const b3Body_EnableHitEvents = __root.b3Body_EnableHitEvents;
    pub const b3Body_GetWorld = __root.b3Body_GetWorld;
    pub const b3Body_GetShapeCount = __root.b3Body_GetShapeCount;
    pub const b3Body_GetShapes = __root.b3Body_GetShapes;
    pub const b3Body_GetJointCount = __root.b3Body_GetJointCount;
    pub const b3Body_GetJoints = __root.b3Body_GetJoints;
    pub const b3Body_GetContactCapacity = __root.b3Body_GetContactCapacity;
    pub const b3Body_GetContactData = __root.b3Body_GetContactData;
    pub const b3Body_ComputeAABB = __root.b3Body_ComputeAABB;
    pub const b3Body_GetClosestPoint = __root.b3Body_GetClosestPoint;
    pub const b3Body_CastRay = __root.b3Body_CastRay;
    pub const b3Body_CastShape = __root.b3Body_CastShape;
    pub const b3Body_OverlapShape = __root.b3Body_OverlapShape;
    pub const b3Body_CollideMover = __root.b3Body_CollideMover;
    pub const b3CreateSphereShape = __root.b3CreateSphereShape;
    pub const b3CreateCapsuleShape = __root.b3CreateCapsuleShape;
    pub const b3CreateHullShape = __root.b3CreateHullShape;
    pub const b3CreateTransformedHullShape = __root.b3CreateTransformedHullShape;
    pub const b3CreateMeshShape = __root.b3CreateMeshShape;
    pub const b3CreateHeightFieldShape = __root.b3CreateHeightFieldShape;
    pub const b3CreateCompoundShape = __root.b3CreateCompoundShape;
    pub const IsValid = __root.b3Body_IsValid;
    pub const GetType = __root.b3Body_GetType;
    pub const SetType = __root.b3Body_SetType;
    pub const SetName = __root.b3Body_SetName;
    pub const GetName = __root.b3Body_GetName;
    pub const SetUserData = __root.b3Body_SetUserData;
    pub const GetUserData = __root.b3Body_GetUserData;
    pub const GetPosition = __root.b3Body_GetPosition;
    pub const GetRotation = __root.b3Body_GetRotation;
    pub const GetTransform = __root.b3Body_GetTransform;
    pub const SetTransform = __root.b3Body_SetTransform;
    pub const GetLocalPoint = __root.b3Body_GetLocalPoint;
    pub const GetWorldPoint = __root.b3Body_GetWorldPoint;
    pub const GetLocalVector = __root.b3Body_GetLocalVector;
    pub const GetWorldVector = __root.b3Body_GetWorldVector;
    pub const GetLinearVelocity = __root.b3Body_GetLinearVelocity;
    pub const GetAngularVelocity = __root.b3Body_GetAngularVelocity;
    pub const SetLinearVelocity = __root.b3Body_SetLinearVelocity;
    pub const SetAngularVelocity = __root.b3Body_SetAngularVelocity;
    pub const SetTargetTransform = __root.b3Body_SetTargetTransform;
    pub const GetLocalPointVelocity = __root.b3Body_GetLocalPointVelocity;
    pub const GetWorldPointVelocity = __root.b3Body_GetWorldPointVelocity;
    pub const ApplyForce = __root.b3Body_ApplyForce;
    pub const ApplyForceToCenter = __root.b3Body_ApplyForceToCenter;
    pub const ApplyTorque = __root.b3Body_ApplyTorque;
    pub const ApplyLinearImpulse = __root.b3Body_ApplyLinearImpulse;
    pub const ApplyLinearImpulseToCenter = __root.b3Body_ApplyLinearImpulseToCenter;
    pub const ApplyAngularImpulse = __root.b3Body_ApplyAngularImpulse;
    pub const GetMass = __root.b3Body_GetMass;
    pub const GetLocalRotationalInertia = __root.b3Body_GetLocalRotationalInertia;
    pub const GetInverseMass = __root.b3Body_GetInverseMass;
    pub const GetWorldInverseRotationalInertia = __root.b3Body_GetWorldInverseRotationalInertia;
    pub const GetLocalCenterOfMass = __root.b3Body_GetLocalCenterOfMass;
    pub const GetWorldCenterOfMass = __root.b3Body_GetWorldCenterOfMass;
    pub const SetMassData = __root.b3Body_SetMassData;
    pub const GetMassData = __root.b3Body_GetMassData;
    pub const ApplyMassFromShapes = __root.b3Body_ApplyMassFromShapes;
    pub const SetLinearDamping = __root.b3Body_SetLinearDamping;
    pub const GetLinearDamping = __root.b3Body_GetLinearDamping;
    pub const SetAngularDamping = __root.b3Body_SetAngularDamping;
    pub const GetAngularDamping = __root.b3Body_GetAngularDamping;
    pub const SetGravityScale = __root.b3Body_SetGravityScale;
    pub const GetGravityScale = __root.b3Body_GetGravityScale;
    pub const IsAwake = __root.b3Body_IsAwake;
    pub const SetAwake = __root.b3Body_SetAwake;
    pub const EnableSleep = __root.b3Body_EnableSleep;
    pub const IsSleepEnabled = __root.b3Body_IsSleepEnabled;
    pub const SetSleepThreshold = __root.b3Body_SetSleepThreshold;
    pub const GetSleepThreshold = __root.b3Body_GetSleepThreshold;
    pub const IsEnabled = __root.b3Body_IsEnabled;
    pub const Disable = __root.b3Body_Disable;
    pub const Enable = __root.b3Body_Enable;
    pub const SetMotionLocks = __root.b3Body_SetMotionLocks;
    pub const GetMotionLocks = __root.b3Body_GetMotionLocks;
    pub const SetBullet = __root.b3Body_SetBullet;
    pub const IsBullet = __root.b3Body_IsBullet;
    pub const EnableContactRecycling = __root.b3Body_EnableContactRecycling;
    pub const IsContactRecyclingEnabled = __root.b3Body_IsContactRecyclingEnabled;
    pub const EnableHitEvents = __root.b3Body_EnableHitEvents;
    pub const GetWorld = __root.b3Body_GetWorld;
    pub const GetShapeCount = __root.b3Body_GetShapeCount;
    pub const GetShapes = __root.b3Body_GetShapes;
    pub const GetJointCount = __root.b3Body_GetJointCount;
    pub const GetJoints = __root.b3Body_GetJoints;
    pub const GetContactCapacity = __root.b3Body_GetContactCapacity;
    pub const GetContactData = __root.b3Body_GetContactData;
    pub const ComputeAABB = __root.b3Body_ComputeAABB;
    pub const GetClosestPoint = __root.b3Body_GetClosestPoint;
    pub const CastRay = __root.b3Body_CastRay;
    pub const CastShape = __root.b3Body_CastShape;
    pub const OverlapShape = __root.b3Body_OverlapShape;
    pub const CollideMover = __root.b3Body_CollideMover;
};
pub const b3BodyId = struct_b3BodyId;
pub const struct_b3ShapeId = extern struct {
    index1: i32,
    world0: u16,
    generation: u16,
    pub const b3StoreShapeId = __root.b3StoreShapeId;
    pub const b3DestroyShape = __root.b3DestroyShape;
    pub const b3Shape_IsValid = __root.b3Shape_IsValid;
    pub const b3Shape_GetType = __root.b3Shape_GetType;
    pub const b3Shape_GetBody = __root.b3Shape_GetBody;
    pub const b3Shape_GetWorld = __root.b3Shape_GetWorld;
    pub const b3Shape_IsSensor = __root.b3Shape_IsSensor;
    pub const b3Shape_SetUserData = __root.b3Shape_SetUserData;
    pub const b3Shape_GetUserData = __root.b3Shape_GetUserData;
    pub const b3Shape_SetDensity = __root.b3Shape_SetDensity;
    pub const b3Shape_GetDensity = __root.b3Shape_GetDensity;
    pub const b3Shape_SetFriction = __root.b3Shape_SetFriction;
    pub const b3Shape_GetFriction = __root.b3Shape_GetFriction;
    pub const b3Shape_SetRestitution = __root.b3Shape_SetRestitution;
    pub const b3Shape_GetRestitution = __root.b3Shape_GetRestitution;
    pub const b3Shape_SetSurfaceMaterial = __root.b3Shape_SetSurfaceMaterial;
    pub const b3Shape_GetSurfaceMaterial = __root.b3Shape_GetSurfaceMaterial;
    pub const b3Shape_GetMeshMaterialCount = __root.b3Shape_GetMeshMaterialCount;
    pub const b3Shape_SetMeshMaterial = __root.b3Shape_SetMeshMaterial;
    pub const b3Shape_GetMeshSurfaceMaterial = __root.b3Shape_GetMeshSurfaceMaterial;
    pub const b3Shape_GetFilter = __root.b3Shape_GetFilter;
    pub const b3Shape_SetFilter = __root.b3Shape_SetFilter;
    pub const b3Shape_EnableSensorEvents = __root.b3Shape_EnableSensorEvents;
    pub const b3Shape_AreSensorEventsEnabled = __root.b3Shape_AreSensorEventsEnabled;
    pub const b3Shape_EnableContactEvents = __root.b3Shape_EnableContactEvents;
    pub const b3Shape_AreContactEventsEnabled = __root.b3Shape_AreContactEventsEnabled;
    pub const b3Shape_EnablePreSolveEvents = __root.b3Shape_EnablePreSolveEvents;
    pub const b3Shape_ArePreSolveEventsEnabled = __root.b3Shape_ArePreSolveEventsEnabled;
    pub const b3Shape_EnableHitEvents = __root.b3Shape_EnableHitEvents;
    pub const b3Shape_AreHitEventsEnabled = __root.b3Shape_AreHitEventsEnabled;
    pub const b3Shape_RayCast = __root.b3Shape_RayCast;
    pub const b3Shape_GetSphere = __root.b3Shape_GetSphere;
    pub const b3Shape_GetCapsule = __root.b3Shape_GetCapsule;
    pub const b3Shape_GetHull = __root.b3Shape_GetHull;
    pub const b3Shape_GetMesh = __root.b3Shape_GetMesh;
    pub const b3Shape_GetHeightField = __root.b3Shape_GetHeightField;
    pub const b3Shape_SetSphere = __root.b3Shape_SetSphere;
    pub const b3Shape_SetCapsule = __root.b3Shape_SetCapsule;
    pub const b3Shape_SetHull = __root.b3Shape_SetHull;
    pub const b3Shape_SetMesh = __root.b3Shape_SetMesh;
    pub const b3Shape_GetContactCapacity = __root.b3Shape_GetContactCapacity;
    pub const b3Shape_GetContactData = __root.b3Shape_GetContactData;
    pub const b3Shape_GetSensorCapacity = __root.b3Shape_GetSensorCapacity;
    pub const b3Shape_GetSensorData = __root.b3Shape_GetSensorData;
    pub const b3Shape_GetAABB = __root.b3Shape_GetAABB;
    pub const b3Shape_ComputeMassData = __root.b3Shape_ComputeMassData;
    pub const b3Shape_GetClosestPoint = __root.b3Shape_GetClosestPoint;
    pub const b3Shape_ApplyWind = __root.b3Shape_ApplyWind;
    pub const IsValid = __root.b3Shape_IsValid;
    pub const GetType = __root.b3Shape_GetType;
    pub const GetBody = __root.b3Shape_GetBody;
    pub const GetWorld = __root.b3Shape_GetWorld;
    pub const IsSensor = __root.b3Shape_IsSensor;
    pub const SetUserData = __root.b3Shape_SetUserData;
    pub const GetUserData = __root.b3Shape_GetUserData;
    pub const SetDensity = __root.b3Shape_SetDensity;
    pub const GetDensity = __root.b3Shape_GetDensity;
    pub const SetFriction = __root.b3Shape_SetFriction;
    pub const GetFriction = __root.b3Shape_GetFriction;
    pub const SetRestitution = __root.b3Shape_SetRestitution;
    pub const GetRestitution = __root.b3Shape_GetRestitution;
    pub const SetSurfaceMaterial = __root.b3Shape_SetSurfaceMaterial;
    pub const GetSurfaceMaterial = __root.b3Shape_GetSurfaceMaterial;
    pub const GetMeshMaterialCount = __root.b3Shape_GetMeshMaterialCount;
    pub const SetMeshMaterial = __root.b3Shape_SetMeshMaterial;
    pub const GetMeshSurfaceMaterial = __root.b3Shape_GetMeshSurfaceMaterial;
    pub const GetFilter = __root.b3Shape_GetFilter;
    pub const SetFilter = __root.b3Shape_SetFilter;
    pub const EnableSensorEvents = __root.b3Shape_EnableSensorEvents;
    pub const AreSensorEventsEnabled = __root.b3Shape_AreSensorEventsEnabled;
    pub const EnableContactEvents = __root.b3Shape_EnableContactEvents;
    pub const AreContactEventsEnabled = __root.b3Shape_AreContactEventsEnabled;
    pub const EnablePreSolveEvents = __root.b3Shape_EnablePreSolveEvents;
    pub const ArePreSolveEventsEnabled = __root.b3Shape_ArePreSolveEventsEnabled;
    pub const EnableHitEvents = __root.b3Shape_EnableHitEvents;
    pub const AreHitEventsEnabled = __root.b3Shape_AreHitEventsEnabled;
    pub const RayCast = __root.b3Shape_RayCast;
    pub const GetSphere = __root.b3Shape_GetSphere;
    pub const GetCapsule = __root.b3Shape_GetCapsule;
    pub const GetHull = __root.b3Shape_GetHull;
    pub const GetMesh = __root.b3Shape_GetMesh;
    pub const GetHeightField = __root.b3Shape_GetHeightField;
    pub const SetSphere = __root.b3Shape_SetSphere;
    pub const SetCapsule = __root.b3Shape_SetCapsule;
    pub const SetHull = __root.b3Shape_SetHull;
    pub const SetMesh = __root.b3Shape_SetMesh;
    pub const GetContactCapacity = __root.b3Shape_GetContactCapacity;
    pub const GetContactData = __root.b3Shape_GetContactData;
    pub const GetSensorCapacity = __root.b3Shape_GetSensorCapacity;
    pub const GetSensorData = __root.b3Shape_GetSensorData;
    pub const GetAABB = __root.b3Shape_GetAABB;
    pub const ComputeMassData = __root.b3Shape_ComputeMassData;
    pub const GetClosestPoint = __root.b3Shape_GetClosestPoint;
    pub const ApplyWind = __root.b3Shape_ApplyWind;
};
pub const b3ShapeId = struct_b3ShapeId;
pub const struct_b3JointId = extern struct {
    index1: i32,
    world0: u16,
    generation: u16,
    pub const b3StoreJointId = __root.b3StoreJointId;
    pub const b3DestroyJoint = __root.b3DestroyJoint;
    pub const b3Joint_IsValid = __root.b3Joint_IsValid;
    pub const b3Joint_GetType = __root.b3Joint_GetType;
    pub const b3Joint_GetBodyA = __root.b3Joint_GetBodyA;
    pub const b3Joint_GetBodyB = __root.b3Joint_GetBodyB;
    pub const b3Joint_GetWorld = __root.b3Joint_GetWorld;
    pub const b3Joint_SetLocalFrameA = __root.b3Joint_SetLocalFrameA;
    pub const b3Joint_GetLocalFrameA = __root.b3Joint_GetLocalFrameA;
    pub const b3Joint_SetLocalFrameB = __root.b3Joint_SetLocalFrameB;
    pub const b3Joint_GetLocalFrameB = __root.b3Joint_GetLocalFrameB;
    pub const b3Joint_SetCollideConnected = __root.b3Joint_SetCollideConnected;
    pub const b3Joint_GetCollideConnected = __root.b3Joint_GetCollideConnected;
    pub const b3Joint_SetUserData = __root.b3Joint_SetUserData;
    pub const b3Joint_GetUserData = __root.b3Joint_GetUserData;
    pub const b3Joint_WakeBodies = __root.b3Joint_WakeBodies;
    pub const b3Joint_GetConstraintForce = __root.b3Joint_GetConstraintForce;
    pub const b3Joint_GetConstraintTorque = __root.b3Joint_GetConstraintTorque;
    pub const b3Joint_GetLinearSeparation = __root.b3Joint_GetLinearSeparation;
    pub const b3Joint_GetAngularSeparation = __root.b3Joint_GetAngularSeparation;
    pub const b3Joint_SetConstraintTuning = __root.b3Joint_SetConstraintTuning;
    pub const b3Joint_GetConstraintTuning = __root.b3Joint_GetConstraintTuning;
    pub const b3Joint_SetForceThreshold = __root.b3Joint_SetForceThreshold;
    pub const b3Joint_GetForceThreshold = __root.b3Joint_GetForceThreshold;
    pub const b3Joint_SetTorqueThreshold = __root.b3Joint_SetTorqueThreshold;
    pub const b3Joint_GetTorqueThreshold = __root.b3Joint_GetTorqueThreshold;
    pub const b3ParallelJoint_SetSpringHertz = __root.b3ParallelJoint_SetSpringHertz;
    pub const b3ParallelJoint_SetSpringDampingRatio = __root.b3ParallelJoint_SetSpringDampingRatio;
    pub const b3ParallelJoint_GetSpringHertz = __root.b3ParallelJoint_GetSpringHertz;
    pub const b3ParallelJoint_GetSpringDampingRatio = __root.b3ParallelJoint_GetSpringDampingRatio;
    pub const b3ParallelJoint_SetMaxTorque = __root.b3ParallelJoint_SetMaxTorque;
    pub const b3ParallelJoint_GetMaxTorque = __root.b3ParallelJoint_GetMaxTorque;
    pub const b3DistanceJoint_SetLength = __root.b3DistanceJoint_SetLength;
    pub const b3DistanceJoint_GetLength = __root.b3DistanceJoint_GetLength;
    pub const b3DistanceJoint_EnableSpring = __root.b3DistanceJoint_EnableSpring;
    pub const b3DistanceJoint_IsSpringEnabled = __root.b3DistanceJoint_IsSpringEnabled;
    pub const b3DistanceJoint_SetSpringForceRange = __root.b3DistanceJoint_SetSpringForceRange;
    pub const b3DistanceJoint_GetSpringForceRange = __root.b3DistanceJoint_GetSpringForceRange;
    pub const b3DistanceJoint_SetSpringHertz = __root.b3DistanceJoint_SetSpringHertz;
    pub const b3DistanceJoint_SetSpringDampingRatio = __root.b3DistanceJoint_SetSpringDampingRatio;
    pub const b3DistanceJoint_GetSpringHertz = __root.b3DistanceJoint_GetSpringHertz;
    pub const b3DistanceJoint_GetSpringDampingRatio = __root.b3DistanceJoint_GetSpringDampingRatio;
    pub const b3DistanceJoint_EnableLimit = __root.b3DistanceJoint_EnableLimit;
    pub const b3DistanceJoint_IsLimitEnabled = __root.b3DistanceJoint_IsLimitEnabled;
    pub const b3DistanceJoint_SetLengthRange = __root.b3DistanceJoint_SetLengthRange;
    pub const b3DistanceJoint_GetMinLength = __root.b3DistanceJoint_GetMinLength;
    pub const b3DistanceJoint_GetMaxLength = __root.b3DistanceJoint_GetMaxLength;
    pub const b3DistanceJoint_GetCurrentLength = __root.b3DistanceJoint_GetCurrentLength;
    pub const b3DistanceJoint_EnableMotor = __root.b3DistanceJoint_EnableMotor;
    pub const b3DistanceJoint_IsMotorEnabled = __root.b3DistanceJoint_IsMotorEnabled;
    pub const b3DistanceJoint_SetMotorSpeed = __root.b3DistanceJoint_SetMotorSpeed;
    pub const b3DistanceJoint_GetMotorSpeed = __root.b3DistanceJoint_GetMotorSpeed;
    pub const b3DistanceJoint_SetMaxMotorForce = __root.b3DistanceJoint_SetMaxMotorForce;
    pub const b3DistanceJoint_GetMaxMotorForce = __root.b3DistanceJoint_GetMaxMotorForce;
    pub const b3DistanceJoint_GetMotorForce = __root.b3DistanceJoint_GetMotorForce;
    pub const b3MotorJoint_SetLinearVelocity = __root.b3MotorJoint_SetLinearVelocity;
    pub const b3MotorJoint_GetLinearVelocity = __root.b3MotorJoint_GetLinearVelocity;
    pub const b3MotorJoint_SetAngularVelocity = __root.b3MotorJoint_SetAngularVelocity;
    pub const b3MotorJoint_GetAngularVelocity = __root.b3MotorJoint_GetAngularVelocity;
    pub const b3MotorJoint_SetMaxVelocityForce = __root.b3MotorJoint_SetMaxVelocityForce;
    pub const b3MotorJoint_GetMaxVelocityForce = __root.b3MotorJoint_GetMaxVelocityForce;
    pub const b3MotorJoint_SetMaxVelocityTorque = __root.b3MotorJoint_SetMaxVelocityTorque;
    pub const b3MotorJoint_GetMaxVelocityTorque = __root.b3MotorJoint_GetMaxVelocityTorque;
    pub const b3MotorJoint_SetLinearHertz = __root.b3MotorJoint_SetLinearHertz;
    pub const b3MotorJoint_GetLinearHertz = __root.b3MotorJoint_GetLinearHertz;
    pub const b3MotorJoint_SetLinearDampingRatio = __root.b3MotorJoint_SetLinearDampingRatio;
    pub const b3MotorJoint_GetLinearDampingRatio = __root.b3MotorJoint_GetLinearDampingRatio;
    pub const b3MotorJoint_SetAngularHertz = __root.b3MotorJoint_SetAngularHertz;
    pub const b3MotorJoint_GetAngularHertz = __root.b3MotorJoint_GetAngularHertz;
    pub const b3MotorJoint_SetAngularDampingRatio = __root.b3MotorJoint_SetAngularDampingRatio;
    pub const b3MotorJoint_GetAngularDampingRatio = __root.b3MotorJoint_GetAngularDampingRatio;
    pub const b3MotorJoint_SetMaxSpringForce = __root.b3MotorJoint_SetMaxSpringForce;
    pub const b3MotorJoint_GetMaxSpringForce = __root.b3MotorJoint_GetMaxSpringForce;
    pub const b3MotorJoint_SetMaxSpringTorque = __root.b3MotorJoint_SetMaxSpringTorque;
    pub const b3MotorJoint_GetMaxSpringTorque = __root.b3MotorJoint_GetMaxSpringTorque;
    pub const b3PrismaticJoint_EnableSpring = __root.b3PrismaticJoint_EnableSpring;
    pub const b3PrismaticJoint_IsSpringEnabled = __root.b3PrismaticJoint_IsSpringEnabled;
    pub const b3PrismaticJoint_SetSpringHertz = __root.b3PrismaticJoint_SetSpringHertz;
    pub const b3PrismaticJoint_GetSpringHertz = __root.b3PrismaticJoint_GetSpringHertz;
    pub const b3PrismaticJoint_SetSpringDampingRatio = __root.b3PrismaticJoint_SetSpringDampingRatio;
    pub const b3PrismaticJoint_GetSpringDampingRatio = __root.b3PrismaticJoint_GetSpringDampingRatio;
    pub const b3PrismaticJoint_SetTargetTranslation = __root.b3PrismaticJoint_SetTargetTranslation;
    pub const b3PrismaticJoint_GetTargetTranslation = __root.b3PrismaticJoint_GetTargetTranslation;
    pub const b3PrismaticJoint_EnableLimit = __root.b3PrismaticJoint_EnableLimit;
    pub const b3PrismaticJoint_IsLimitEnabled = __root.b3PrismaticJoint_IsLimitEnabled;
    pub const b3PrismaticJoint_GetLowerLimit = __root.b3PrismaticJoint_GetLowerLimit;
    pub const b3PrismaticJoint_GetUpperLimit = __root.b3PrismaticJoint_GetUpperLimit;
    pub const b3PrismaticJoint_SetLimits = __root.b3PrismaticJoint_SetLimits;
    pub const b3PrismaticJoint_EnableMotor = __root.b3PrismaticJoint_EnableMotor;
    pub const b3PrismaticJoint_IsMotorEnabled = __root.b3PrismaticJoint_IsMotorEnabled;
    pub const b3PrismaticJoint_SetMotorSpeed = __root.b3PrismaticJoint_SetMotorSpeed;
    pub const b3PrismaticJoint_GetMotorSpeed = __root.b3PrismaticJoint_GetMotorSpeed;
    pub const b3PrismaticJoint_SetMaxMotorForce = __root.b3PrismaticJoint_SetMaxMotorForce;
    pub const b3PrismaticJoint_GetMaxMotorForce = __root.b3PrismaticJoint_GetMaxMotorForce;
    pub const b3PrismaticJoint_GetMotorForce = __root.b3PrismaticJoint_GetMotorForce;
    pub const b3PrismaticJoint_GetTranslation = __root.b3PrismaticJoint_GetTranslation;
    pub const b3PrismaticJoint_GetSpeed = __root.b3PrismaticJoint_GetSpeed;
    pub const b3RevoluteJoint_EnableSpring = __root.b3RevoluteJoint_EnableSpring;
    pub const b3RevoluteJoint_IsSpringEnabled = __root.b3RevoluteJoint_IsSpringEnabled;
    pub const b3RevoluteJoint_SetSpringHertz = __root.b3RevoluteJoint_SetSpringHertz;
    pub const b3RevoluteJoint_GetSpringHertz = __root.b3RevoluteJoint_GetSpringHertz;
    pub const b3RevoluteJoint_SetSpringDampingRatio = __root.b3RevoluteJoint_SetSpringDampingRatio;
    pub const b3RevoluteJoint_GetSpringDampingRatio = __root.b3RevoluteJoint_GetSpringDampingRatio;
    pub const b3RevoluteJoint_SetTargetAngle = __root.b3RevoluteJoint_SetTargetAngle;
    pub const b3RevoluteJoint_GetTargetAngle = __root.b3RevoluteJoint_GetTargetAngle;
    pub const b3RevoluteJoint_GetAngle = __root.b3RevoluteJoint_GetAngle;
    pub const b3RevoluteJoint_EnableLimit = __root.b3RevoluteJoint_EnableLimit;
    pub const b3RevoluteJoint_IsLimitEnabled = __root.b3RevoluteJoint_IsLimitEnabled;
    pub const b3RevoluteJoint_GetLowerLimit = __root.b3RevoluteJoint_GetLowerLimit;
    pub const b3RevoluteJoint_GetUpperLimit = __root.b3RevoluteJoint_GetUpperLimit;
    pub const b3RevoluteJoint_SetLimits = __root.b3RevoluteJoint_SetLimits;
    pub const b3RevoluteJoint_EnableMotor = __root.b3RevoluteJoint_EnableMotor;
    pub const b3RevoluteJoint_IsMotorEnabled = __root.b3RevoluteJoint_IsMotorEnabled;
    pub const b3RevoluteJoint_SetMotorSpeed = __root.b3RevoluteJoint_SetMotorSpeed;
    pub const b3RevoluteJoint_GetMotorSpeed = __root.b3RevoluteJoint_GetMotorSpeed;
    pub const b3RevoluteJoint_GetMotorTorque = __root.b3RevoluteJoint_GetMotorTorque;
    pub const b3RevoluteJoint_SetMaxMotorTorque = __root.b3RevoluteJoint_SetMaxMotorTorque;
    pub const b3RevoluteJoint_GetMaxMotorTorque = __root.b3RevoluteJoint_GetMaxMotorTorque;
    pub const b3SphericalJoint_EnableConeLimit = __root.b3SphericalJoint_EnableConeLimit;
    pub const b3SphericalJoint_IsConeLimitEnabled = __root.b3SphericalJoint_IsConeLimitEnabled;
    pub const b3SphericalJoint_GetConeLimit = __root.b3SphericalJoint_GetConeLimit;
    pub const b3SphericalJoint_SetConeLimit = __root.b3SphericalJoint_SetConeLimit;
    pub const b3SphericalJoint_GetConeAngle = __root.b3SphericalJoint_GetConeAngle;
    pub const b3SphericalJoint_EnableTwistLimit = __root.b3SphericalJoint_EnableTwistLimit;
    pub const b3SphericalJoint_IsTwistLimitEnabled = __root.b3SphericalJoint_IsTwistLimitEnabled;
    pub const b3SphericalJoint_GetLowerTwistLimit = __root.b3SphericalJoint_GetLowerTwistLimit;
    pub const b3SphericalJoint_GetUpperTwistLimit = __root.b3SphericalJoint_GetUpperTwistLimit;
    pub const b3SphericalJoint_SetTwistLimits = __root.b3SphericalJoint_SetTwistLimits;
    pub const b3SphericalJoint_GetTwistAngle = __root.b3SphericalJoint_GetTwistAngle;
    pub const b3SphericalJoint_EnableSpring = __root.b3SphericalJoint_EnableSpring;
    pub const b3SphericalJoint_IsSpringEnabled = __root.b3SphericalJoint_IsSpringEnabled;
    pub const b3SphericalJoint_SetSpringHertz = __root.b3SphericalJoint_SetSpringHertz;
    pub const b3SphericalJoint_GetSpringHertz = __root.b3SphericalJoint_GetSpringHertz;
    pub const b3SphericalJoint_SetSpringDampingRatio = __root.b3SphericalJoint_SetSpringDampingRatio;
    pub const b3SphericalJoint_GetSpringDampingRatio = __root.b3SphericalJoint_GetSpringDampingRatio;
    pub const b3SphericalJoint_SetTargetRotation = __root.b3SphericalJoint_SetTargetRotation;
    pub const b3SphericalJoint_GetTargetRotation = __root.b3SphericalJoint_GetTargetRotation;
    pub const b3SphericalJoint_EnableMotor = __root.b3SphericalJoint_EnableMotor;
    pub const b3SphericalJoint_IsMotorEnabled = __root.b3SphericalJoint_IsMotorEnabled;
    pub const b3SphericalJoint_SetMotorVelocity = __root.b3SphericalJoint_SetMotorVelocity;
    pub const b3SphericalJoint_GetMotorVelocity = __root.b3SphericalJoint_GetMotorVelocity;
    pub const b3SphericalJoint_GetMotorTorque = __root.b3SphericalJoint_GetMotorTorque;
    pub const b3SphericalJoint_SetMaxMotorTorque = __root.b3SphericalJoint_SetMaxMotorTorque;
    pub const b3SphericalJoint_GetMaxMotorTorque = __root.b3SphericalJoint_GetMaxMotorTorque;
    pub const b3WeldJoint_SetLinearHertz = __root.b3WeldJoint_SetLinearHertz;
    pub const b3WeldJoint_GetLinearHertz = __root.b3WeldJoint_GetLinearHertz;
    pub const b3WeldJoint_SetLinearDampingRatio = __root.b3WeldJoint_SetLinearDampingRatio;
    pub const b3WeldJoint_GetLinearDampingRatio = __root.b3WeldJoint_GetLinearDampingRatio;
    pub const b3WeldJoint_SetAngularHertz = __root.b3WeldJoint_SetAngularHertz;
    pub const b3WeldJoint_GetAngularHertz = __root.b3WeldJoint_GetAngularHertz;
    pub const b3WeldJoint_SetAngularDampingRatio = __root.b3WeldJoint_SetAngularDampingRatio;
    pub const b3WeldJoint_GetAngularDampingRatio = __root.b3WeldJoint_GetAngularDampingRatio;
    pub const b3WheelJoint_EnableSuspension = __root.b3WheelJoint_EnableSuspension;
    pub const b3WheelJoint_IsSuspensionEnabled = __root.b3WheelJoint_IsSuspensionEnabled;
    pub const b3WheelJoint_SetSuspensionHertz = __root.b3WheelJoint_SetSuspensionHertz;
    pub const b3WheelJoint_GetSuspensionHertz = __root.b3WheelJoint_GetSuspensionHertz;
    pub const b3WheelJoint_SetSuspensionDampingRatio = __root.b3WheelJoint_SetSuspensionDampingRatio;
    pub const b3WheelJoint_GetSuspensionDampingRatio = __root.b3WheelJoint_GetSuspensionDampingRatio;
    pub const b3WheelJoint_EnableSuspensionLimit = __root.b3WheelJoint_EnableSuspensionLimit;
    pub const b3WheelJoint_IsSuspensionLimitEnabled = __root.b3WheelJoint_IsSuspensionLimitEnabled;
    pub const b3WheelJoint_GetLowerSuspensionLimit = __root.b3WheelJoint_GetLowerSuspensionLimit;
    pub const b3WheelJoint_GetUpperSuspensionLimit = __root.b3WheelJoint_GetUpperSuspensionLimit;
    pub const b3WheelJoint_SetSuspensionLimits = __root.b3WheelJoint_SetSuspensionLimits;
    pub const b3WheelJoint_EnableSpinMotor = __root.b3WheelJoint_EnableSpinMotor;
    pub const b3WheelJoint_IsSpinMotorEnabled = __root.b3WheelJoint_IsSpinMotorEnabled;
    pub const b3WheelJoint_SetSpinMotorSpeed = __root.b3WheelJoint_SetSpinMotorSpeed;
    pub const b3WheelJoint_GetSpinMotorSpeed = __root.b3WheelJoint_GetSpinMotorSpeed;
    pub const b3WheelJoint_SetMaxSpinTorque = __root.b3WheelJoint_SetMaxSpinTorque;
    pub const b3WheelJoint_GetMaxSpinTorque = __root.b3WheelJoint_GetMaxSpinTorque;
    pub const b3WheelJoint_GetSpinSpeed = __root.b3WheelJoint_GetSpinSpeed;
    pub const b3WheelJoint_GetSpinTorque = __root.b3WheelJoint_GetSpinTorque;
    pub const b3WheelJoint_EnableSteering = __root.b3WheelJoint_EnableSteering;
    pub const b3WheelJoint_IsSteeringEnabled = __root.b3WheelJoint_IsSteeringEnabled;
    pub const b3WheelJoint_SetSteeringHertz = __root.b3WheelJoint_SetSteeringHertz;
    pub const b3WheelJoint_GetSteeringHertz = __root.b3WheelJoint_GetSteeringHertz;
    pub const b3WheelJoint_SetSteeringDampingRatio = __root.b3WheelJoint_SetSteeringDampingRatio;
    pub const b3WheelJoint_GetSteeringDampingRatio = __root.b3WheelJoint_GetSteeringDampingRatio;
    pub const b3WheelJoint_SetMaxSteeringTorque = __root.b3WheelJoint_SetMaxSteeringTorque;
    pub const b3WheelJoint_GetMaxSteeringTorque = __root.b3WheelJoint_GetMaxSteeringTorque;
    pub const b3WheelJoint_EnableSteeringLimit = __root.b3WheelJoint_EnableSteeringLimit;
    pub const b3WheelJoint_IsSteeringLimitEnabled = __root.b3WheelJoint_IsSteeringLimitEnabled;
    pub const b3WheelJoint_GetLowerSteeringLimit = __root.b3WheelJoint_GetLowerSteeringLimit;
    pub const b3WheelJoint_GetUpperSteeringLimit = __root.b3WheelJoint_GetUpperSteeringLimit;
    pub const b3WheelJoint_SetSteeringLimits = __root.b3WheelJoint_SetSteeringLimits;
    pub const b3WheelJoint_SetTargetSteeringAngle = __root.b3WheelJoint_SetTargetSteeringAngle;
    pub const b3WheelJoint_GetTargetSteeringAngle = __root.b3WheelJoint_GetTargetSteeringAngle;
    pub const b3WheelJoint_GetSteeringAngle = __root.b3WheelJoint_GetSteeringAngle;
    pub const b3WheelJoint_GetSteeringTorque = __root.b3WheelJoint_GetSteeringTorque;
    pub const IsValid = __root.b3Joint_IsValid;
    pub const GetType = __root.b3Joint_GetType;
    pub const GetBodyA = __root.b3Joint_GetBodyA;
    pub const GetBodyB = __root.b3Joint_GetBodyB;
    pub const GetWorld = __root.b3Joint_GetWorld;
    pub const SetLocalFrameA = __root.b3Joint_SetLocalFrameA;
    pub const GetLocalFrameA = __root.b3Joint_GetLocalFrameA;
    pub const SetLocalFrameB = __root.b3Joint_SetLocalFrameB;
    pub const GetLocalFrameB = __root.b3Joint_GetLocalFrameB;
    pub const SetCollideConnected = __root.b3Joint_SetCollideConnected;
    pub const GetCollideConnected = __root.b3Joint_GetCollideConnected;
    pub const SetUserData = __root.b3Joint_SetUserData;
    pub const GetUserData = __root.b3Joint_GetUserData;
    pub const WakeBodies = __root.b3Joint_WakeBodies;
    pub const GetConstraintForce = __root.b3Joint_GetConstraintForce;
    pub const GetConstraintTorque = __root.b3Joint_GetConstraintTorque;
    pub const GetLinearSeparation = __root.b3Joint_GetLinearSeparation;
    pub const GetAngularSeparation = __root.b3Joint_GetAngularSeparation;
    pub const SetConstraintTuning = __root.b3Joint_SetConstraintTuning;
    pub const GetConstraintTuning = __root.b3Joint_GetConstraintTuning;
    pub const SetForceThreshold = __root.b3Joint_SetForceThreshold;
    pub const GetForceThreshold = __root.b3Joint_GetForceThreshold;
    pub const SetTorqueThreshold = __root.b3Joint_SetTorqueThreshold;
    pub const GetTorqueThreshold = __root.b3Joint_GetTorqueThreshold;
    pub const SetSpringHertz = __root.b3ParallelJoint_SetSpringHertz;
    pub const SetSpringDampingRatio = __root.b3ParallelJoint_SetSpringDampingRatio;
    pub const GetSpringHertz = __root.b3ParallelJoint_GetSpringHertz;
    pub const GetSpringDampingRatio = __root.b3ParallelJoint_GetSpringDampingRatio;
    pub const SetMaxTorque = __root.b3ParallelJoint_SetMaxTorque;
    pub const GetMaxTorque = __root.b3ParallelJoint_GetMaxTorque;
    pub const SetLength = __root.b3DistanceJoint_SetLength;
    pub const GetLength = __root.b3DistanceJoint_GetLength;
    pub const EnableSpring = __root.b3DistanceJoint_EnableSpring;
    pub const IsSpringEnabled = __root.b3DistanceJoint_IsSpringEnabled;
    pub const SetSpringForceRange = __root.b3DistanceJoint_SetSpringForceRange;
    pub const GetSpringForceRange = __root.b3DistanceJoint_GetSpringForceRange;
    pub const EnableLimit = __root.b3DistanceJoint_EnableLimit;
    pub const IsLimitEnabled = __root.b3DistanceJoint_IsLimitEnabled;
    pub const SetLengthRange = __root.b3DistanceJoint_SetLengthRange;
    pub const GetMinLength = __root.b3DistanceJoint_GetMinLength;
    pub const GetMaxLength = __root.b3DistanceJoint_GetMaxLength;
    pub const GetCurrentLength = __root.b3DistanceJoint_GetCurrentLength;
    pub const EnableMotor = __root.b3DistanceJoint_EnableMotor;
    pub const IsMotorEnabled = __root.b3DistanceJoint_IsMotorEnabled;
    pub const SetMotorSpeed = __root.b3DistanceJoint_SetMotorSpeed;
    pub const GetMotorSpeed = __root.b3DistanceJoint_GetMotorSpeed;
    pub const SetMaxMotorForce = __root.b3DistanceJoint_SetMaxMotorForce;
    pub const GetMaxMotorForce = __root.b3DistanceJoint_GetMaxMotorForce;
    pub const GetMotorForce = __root.b3DistanceJoint_GetMotorForce;
    pub const SetLinearVelocity = __root.b3MotorJoint_SetLinearVelocity;
    pub const GetLinearVelocity = __root.b3MotorJoint_GetLinearVelocity;
    pub const SetAngularVelocity = __root.b3MotorJoint_SetAngularVelocity;
    pub const GetAngularVelocity = __root.b3MotorJoint_GetAngularVelocity;
    pub const SetMaxVelocityForce = __root.b3MotorJoint_SetMaxVelocityForce;
    pub const GetMaxVelocityForce = __root.b3MotorJoint_GetMaxVelocityForce;
    pub const SetMaxVelocityTorque = __root.b3MotorJoint_SetMaxVelocityTorque;
    pub const GetMaxVelocityTorque = __root.b3MotorJoint_GetMaxVelocityTorque;
    pub const SetLinearHertz = __root.b3MotorJoint_SetLinearHertz;
    pub const GetLinearHertz = __root.b3MotorJoint_GetLinearHertz;
    pub const SetLinearDampingRatio = __root.b3MotorJoint_SetLinearDampingRatio;
    pub const GetLinearDampingRatio = __root.b3MotorJoint_GetLinearDampingRatio;
    pub const SetAngularHertz = __root.b3MotorJoint_SetAngularHertz;
    pub const GetAngularHertz = __root.b3MotorJoint_GetAngularHertz;
    pub const SetAngularDampingRatio = __root.b3MotorJoint_SetAngularDampingRatio;
    pub const GetAngularDampingRatio = __root.b3MotorJoint_GetAngularDampingRatio;
    pub const SetMaxSpringForce = __root.b3MotorJoint_SetMaxSpringForce;
    pub const GetMaxSpringForce = __root.b3MotorJoint_GetMaxSpringForce;
    pub const SetMaxSpringTorque = __root.b3MotorJoint_SetMaxSpringTorque;
    pub const GetMaxSpringTorque = __root.b3MotorJoint_GetMaxSpringTorque;
    pub const SetTargetTranslation = __root.b3PrismaticJoint_SetTargetTranslation;
    pub const GetTargetTranslation = __root.b3PrismaticJoint_GetTargetTranslation;
    pub const GetLowerLimit = __root.b3PrismaticJoint_GetLowerLimit;
    pub const GetUpperLimit = __root.b3PrismaticJoint_GetUpperLimit;
    pub const SetLimits = __root.b3PrismaticJoint_SetLimits;
    pub const GetTranslation = __root.b3PrismaticJoint_GetTranslation;
    pub const GetSpeed = __root.b3PrismaticJoint_GetSpeed;
    pub const SetTargetAngle = __root.b3RevoluteJoint_SetTargetAngle;
    pub const GetTargetAngle = __root.b3RevoluteJoint_GetTargetAngle;
    pub const GetAngle = __root.b3RevoluteJoint_GetAngle;
    pub const GetMotorTorque = __root.b3RevoluteJoint_GetMotorTorque;
    pub const SetMaxMotorTorque = __root.b3RevoluteJoint_SetMaxMotorTorque;
    pub const GetMaxMotorTorque = __root.b3RevoluteJoint_GetMaxMotorTorque;
    pub const EnableConeLimit = __root.b3SphericalJoint_EnableConeLimit;
    pub const IsConeLimitEnabled = __root.b3SphericalJoint_IsConeLimitEnabled;
    pub const GetConeLimit = __root.b3SphericalJoint_GetConeLimit;
    pub const SetConeLimit = __root.b3SphericalJoint_SetConeLimit;
    pub const GetConeAngle = __root.b3SphericalJoint_GetConeAngle;
    pub const EnableTwistLimit = __root.b3SphericalJoint_EnableTwistLimit;
    pub const IsTwistLimitEnabled = __root.b3SphericalJoint_IsTwistLimitEnabled;
    pub const GetLowerTwistLimit = __root.b3SphericalJoint_GetLowerTwistLimit;
    pub const GetUpperTwistLimit = __root.b3SphericalJoint_GetUpperTwistLimit;
    pub const SetTwistLimits = __root.b3SphericalJoint_SetTwistLimits;
    pub const GetTwistAngle = __root.b3SphericalJoint_GetTwistAngle;
    pub const SetTargetRotation = __root.b3SphericalJoint_SetTargetRotation;
    pub const GetTargetRotation = __root.b3SphericalJoint_GetTargetRotation;
    pub const SetMotorVelocity = __root.b3SphericalJoint_SetMotorVelocity;
    pub const GetMotorVelocity = __root.b3SphericalJoint_GetMotorVelocity;
    pub const EnableSuspension = __root.b3WheelJoint_EnableSuspension;
    pub const IsSuspensionEnabled = __root.b3WheelJoint_IsSuspensionEnabled;
    pub const SetSuspensionHertz = __root.b3WheelJoint_SetSuspensionHertz;
    pub const GetSuspensionHertz = __root.b3WheelJoint_GetSuspensionHertz;
    pub const SetSuspensionDampingRatio = __root.b3WheelJoint_SetSuspensionDampingRatio;
    pub const GetSuspensionDampingRatio = __root.b3WheelJoint_GetSuspensionDampingRatio;
    pub const EnableSuspensionLimit = __root.b3WheelJoint_EnableSuspensionLimit;
    pub const IsSuspensionLimitEnabled = __root.b3WheelJoint_IsSuspensionLimitEnabled;
    pub const GetLowerSuspensionLimit = __root.b3WheelJoint_GetLowerSuspensionLimit;
    pub const GetUpperSuspensionLimit = __root.b3WheelJoint_GetUpperSuspensionLimit;
    pub const SetSuspensionLimits = __root.b3WheelJoint_SetSuspensionLimits;
    pub const EnableSpinMotor = __root.b3WheelJoint_EnableSpinMotor;
    pub const IsSpinMotorEnabled = __root.b3WheelJoint_IsSpinMotorEnabled;
    pub const SetSpinMotorSpeed = __root.b3WheelJoint_SetSpinMotorSpeed;
    pub const GetSpinMotorSpeed = __root.b3WheelJoint_GetSpinMotorSpeed;
    pub const SetMaxSpinTorque = __root.b3WheelJoint_SetMaxSpinTorque;
    pub const GetMaxSpinTorque = __root.b3WheelJoint_GetMaxSpinTorque;
    pub const GetSpinSpeed = __root.b3WheelJoint_GetSpinSpeed;
    pub const GetSpinTorque = __root.b3WheelJoint_GetSpinTorque;
    pub const EnableSteering = __root.b3WheelJoint_EnableSteering;
    pub const IsSteeringEnabled = __root.b3WheelJoint_IsSteeringEnabled;
    pub const SetSteeringHertz = __root.b3WheelJoint_SetSteeringHertz;
    pub const GetSteeringHertz = __root.b3WheelJoint_GetSteeringHertz;
    pub const SetSteeringDampingRatio = __root.b3WheelJoint_SetSteeringDampingRatio;
    pub const GetSteeringDampingRatio = __root.b3WheelJoint_GetSteeringDampingRatio;
    pub const SetMaxSteeringTorque = __root.b3WheelJoint_SetMaxSteeringTorque;
    pub const GetMaxSteeringTorque = __root.b3WheelJoint_GetMaxSteeringTorque;
    pub const EnableSteeringLimit = __root.b3WheelJoint_EnableSteeringLimit;
    pub const IsSteeringLimitEnabled = __root.b3WheelJoint_IsSteeringLimitEnabled;
    pub const GetLowerSteeringLimit = __root.b3WheelJoint_GetLowerSteeringLimit;
    pub const GetUpperSteeringLimit = __root.b3WheelJoint_GetUpperSteeringLimit;
    pub const SetSteeringLimits = __root.b3WheelJoint_SetSteeringLimits;
    pub const SetTargetSteeringAngle = __root.b3WheelJoint_SetTargetSteeringAngle;
    pub const GetTargetSteeringAngle = __root.b3WheelJoint_GetTargetSteeringAngle;
    pub const GetSteeringAngle = __root.b3WheelJoint_GetSteeringAngle;
    pub const GetSteeringTorque = __root.b3WheelJoint_GetSteeringTorque;
};
pub const b3JointId = struct_b3JointId;
pub const struct_b3ContactId = extern struct {
    index1: i32,
    world0: u16,
    padding: i16,
    generation: u32,
    pub const b3StoreContactId = __root.b3StoreContactId;
    pub const b3Contact_IsValid = __root.b3Contact_IsValid;
    pub const b3Contact_GetData = __root.b3Contact_GetData;
    pub const IsValid = __root.b3Contact_IsValid;
    pub const GetData = __root.b3Contact_GetData;
};
pub const b3ContactId = struct_b3ContactId;
pub const b3_nullWorldId: b3WorldId = b3WorldId{
    .index1 = 0,
    .generation = 0,
};
pub const b3_nullBodyId: b3BodyId = b3BodyId{
    .index1 = 0,
    .world0 = 0,
    .generation = 0,
};
pub const b3_nullShapeId: b3ShapeId = b3ShapeId{
    .index1 = 0,
    .world0 = 0,
    .generation = 0,
};
pub const b3_nullJointId: b3JointId = b3JointId{
    .index1 = 0,
    .world0 = 0,
    .generation = 0,
};
pub const b3_nullContactId: b3ContactId = b3ContactId{
    .index1 = 0,
    .world0 = 0,
    .padding = 0,
    .generation = 0,
};
pub fn b3StoreWorldId(arg_id: b3WorldId) callconv(.c) u32 {
    var id = arg_id;
    _ = &id;
    return (@as(u32, id.index1) << @intCast(@as(u32, 16))) | @as(u32, id.generation);
}
pub fn b3LoadWorldId(arg_x: u32) callconv(.c) b3WorldId {
    var x = arg_x;
    _ = &x;
    var id: b3WorldId = b3WorldId{
        .index1 = @truncate(x >> @intCast(@as(u32, 16))),
        .generation = @truncate(x),
    };
    _ = &id;
    return id;
}
pub fn b3StoreBodyId(arg_id: b3BodyId) callconv(.c) u64 {
    var id = arg_id;
    _ = &id;
    return ((@as(u64, @bitCast(@as(c_long, id.index1))) << @intCast(@as(u64, 32))) | (@as(u64, id.world0) << @intCast(@as(u64, 16)))) | @as(u64, id.generation);
}
pub fn b3LoadBodyId(arg_x: u64) callconv(.c) b3BodyId {
    var x = arg_x;
    _ = &x;
    var id: b3BodyId = b3BodyId{
        .index1 = @bitCast(@as(c_uint, @truncate(x >> @intCast(@as(u64, 32))))),
        .world0 = @truncate(x >> @intCast(@as(u64, 16))),
        .generation = @truncate(x),
    };
    _ = &id;
    return id;
}
pub fn b3StoreShapeId(arg_id: b3ShapeId) callconv(.c) u64 {
    var id = arg_id;
    _ = &id;
    return ((@as(u64, @bitCast(@as(c_long, id.index1))) << @intCast(@as(u64, 32))) | (@as(u64, id.world0) << @intCast(@as(u64, 16)))) | @as(u64, id.generation);
}
pub fn b3LoadShapeId(arg_x: u64) callconv(.c) b3ShapeId {
    var x = arg_x;
    _ = &x;
    var id: b3ShapeId = b3ShapeId{
        .index1 = @bitCast(@as(c_uint, @truncate(x >> @intCast(@as(u64, 32))))),
        .world0 = @truncate(x >> @intCast(@as(u64, 16))),
        .generation = @truncate(x),
    };
    _ = &id;
    return id;
}
pub fn b3StoreJointId(arg_id: b3JointId) callconv(.c) u64 {
    var id = arg_id;
    _ = &id;
    return ((@as(u64, @bitCast(@as(c_long, id.index1))) << @intCast(@as(u64, 32))) | (@as(u64, id.world0) << @intCast(@as(u64, 16)))) | @as(u64, id.generation);
}
pub fn b3LoadJointId(arg_x: u64) callconv(.c) b3JointId {
    var x = arg_x;
    _ = &x;
    var id: b3JointId = b3JointId{
        .index1 = @bitCast(@as(c_uint, @truncate(x >> @intCast(@as(u64, 32))))),
        .world0 = @truncate(x >> @intCast(@as(u64, 16))),
        .generation = @truncate(x),
    };
    _ = &id;
    return id;
}
pub fn b3StoreContactId(arg_id: b3ContactId, arg_values: [*c]u32) callconv(.c) void {
    var id = arg_id;
    _ = &id;
    var values = arg_values;
    _ = &values;
    values[@as(c_int, 0)] = @bitCast(@as(c_int, id.index1));
    values[@as(c_int, 1)] = id.world0;
    values[@as(c_int, 2)] = id.generation;
}
pub fn b3LoadContactId(arg_values: [*c]u32) callconv(.c) b3ContactId {
    var values = arg_values;
    _ = &values;
    var id: b3ContactId = undefined;
    _ = &id;
    id.index1 = @bitCast(@as(c_uint, @truncate(values[@as(c_int, 0)])));
    id.world0 = @truncate(values[@as(c_int, 1)]);
    id.padding = 0;
    id.generation = values[@as(c_int, 2)];
    return id;
}
pub const b3TaskCallback = fn (taskContext: ?*anyopaque) callconv(.c) void;
pub const b3EnqueueTaskCallback = fn (task: ?*const b3TaskCallback, taskContext: ?*anyopaque, userContext: ?*anyopaque, taskName: [*c]const u8) callconv(.c) ?*anyopaque;
pub const b3FinishTaskCallback = fn (userTask: ?*anyopaque, userContext: ?*anyopaque) callconv(.c) void;
pub const b3_capsuleShape: c_int = 0;
pub const b3_compoundShape: c_int = 1;
pub const b3_heightShape: c_int = 2;
pub const b3_hullShape: c_int = 3;
pub const b3_meshShape: c_int = 4;
pub const b3_sphereShape: c_int = 5;
pub const b3_shapeTypeCount: c_int = 6;
pub const enum_b3ShapeType = c_uint;
pub const b3ShapeType = enum_b3ShapeType;
pub const struct_b3Capsule = extern struct {
    center1: b3Vec3,
    center2: b3Vec3,
    radius: f32,
    pub const b3ComputeCapsuleMass = __root.b3ComputeCapsuleMass;
    pub const b3ComputeCapsuleAABB = __root.b3ComputeCapsuleAABB;
    pub const b3OverlapCapsule = __root.b3OverlapCapsule;
    pub const b3RayCastCapsule = __root.b3RayCastCapsule;
    pub const b3ShapeCastCapsule = __root.b3ShapeCastCapsule;
};
pub const b3Capsule = struct_b3Capsule;
pub const struct_b3TreeNodeChildren = extern struct {
    child1: c_int,
    child2: c_int,
};
pub const b3TreeNodeChildren = struct_b3TreeNodeChildren;
const union_unnamed_3 = extern union {
    children: b3TreeNodeChildren,
    userData: u64,
};
const union_unnamed_4 = extern union {
    parent: c_int,
    next: c_int,
};
pub const struct_b3TreeNode = extern struct {
    aabb: b3AABB,
    categoryBits: u64,
    unnamed_0: union_unnamed_3,
    unnamed_1: union_unnamed_4,
    height: u16,
    flags: u16,
};
pub const b3TreeNode = struct_b3TreeNode;
pub const struct_b3DynamicTree = extern struct {
    version: u64,
    nodes: [*c]b3TreeNode,
    root: c_int,
    nodeCount: c_int,
    nodeCapacity: c_int,
    proxyCount: c_int,
    freeList: c_int,
    leafIndices: [*c]c_int,
    leafBoxes: [*c]b3AABB,
    leafCenters: [*c]b3Vec3,
    binIndices: [*c]c_int,
    rebuildCapacity: c_int,
    pub const b3DynamicTree_Destroy = __root.b3DynamicTree_Destroy;
    pub const b3DynamicTree_CreateProxy = __root.b3DynamicTree_CreateProxy;
    pub const b3DynamicTree_DestroyProxy = __root.b3DynamicTree_DestroyProxy;
    pub const b3DynamicTree_MoveProxy = __root.b3DynamicTree_MoveProxy;
    pub const b3DynamicTree_EnlargeProxy = __root.b3DynamicTree_EnlargeProxy;
    pub const b3DynamicTree_SetCategoryBits = __root.b3DynamicTree_SetCategoryBits;
    pub const b3DynamicTree_GetCategoryBits = __root.b3DynamicTree_GetCategoryBits;
    pub const b3DynamicTree_Query = __root.b3DynamicTree_Query;
    pub const b3DynamicTree_QueryClosest = __root.b3DynamicTree_QueryClosest;
    pub const b3DynamicTree_RayCast = __root.b3DynamicTree_RayCast;
    pub const b3DynamicTree_BoxCast = __root.b3DynamicTree_BoxCast;
    pub const b3DynamicTree_Validate = __root.b3DynamicTree_Validate;
    pub const b3DynamicTree_GetHeight = __root.b3DynamicTree_GetHeight;
    pub const b3DynamicTree_GetAreaRatio = __root.b3DynamicTree_GetAreaRatio;
    pub const b3DynamicTree_GetRootBounds = __root.b3DynamicTree_GetRootBounds;
    pub const b3DynamicTree_GetProxyCount = __root.b3DynamicTree_GetProxyCount;
    pub const b3DynamicTree_Rebuild = __root.b3DynamicTree_Rebuild;
    pub const b3DynamicTree_GetByteCount = __root.b3DynamicTree_GetByteCount;
    pub const b3DynamicTree_ValidateNoEnlarged = __root.b3DynamicTree_ValidateNoEnlarged;
    pub const b3DynamicTree_Save = __root.b3DynamicTree_Save;
    pub const b3DynamicTree_GetUserData = __root.b3DynamicTree_GetUserData;
    pub const b3DynamicTree_GetAABB = __root.b3DynamicTree_GetAABB;
    pub const Destroy = __root.b3DynamicTree_Destroy;
    pub const CreateProxy = __root.b3DynamicTree_CreateProxy;
    pub const DestroyProxy = __root.b3DynamicTree_DestroyProxy;
    pub const MoveProxy = __root.b3DynamicTree_MoveProxy;
    pub const EnlargeProxy = __root.b3DynamicTree_EnlargeProxy;
    pub const SetCategoryBits = __root.b3DynamicTree_SetCategoryBits;
    pub const GetCategoryBits = __root.b3DynamicTree_GetCategoryBits;
    pub const Query = __root.b3DynamicTree_Query;
    pub const QueryClosest = __root.b3DynamicTree_QueryClosest;
    pub const RayCast = __root.b3DynamicTree_RayCast;
    pub const BoxCast = __root.b3DynamicTree_BoxCast;
    pub const Validate = __root.b3DynamicTree_Validate;
    pub const GetHeight = __root.b3DynamicTree_GetHeight;
    pub const GetAreaRatio = __root.b3DynamicTree_GetAreaRatio;
    pub const GetRootBounds = __root.b3DynamicTree_GetRootBounds;
    pub const GetProxyCount = __root.b3DynamicTree_GetProxyCount;
    pub const Rebuild = __root.b3DynamicTree_Rebuild;
    pub const GetByteCount = __root.b3DynamicTree_GetByteCount;
    pub const ValidateNoEnlarged = __root.b3DynamicTree_ValidateNoEnlarged;
    pub const Save = __root.b3DynamicTree_Save;
    pub const GetUserData = __root.b3DynamicTree_GetUserData;
    pub const GetAABB = __root.b3DynamicTree_GetAABB;
};
pub const b3DynamicTree = struct_b3DynamicTree;
pub const struct_b3CompoundData = extern struct {
    version: u64,
    byteCount: c_int,
    nodeOffset: c_int,
    tree: b3DynamicTree,
    materialOffset: c_int,
    materialCount: c_int,
    capsuleOffset: c_int,
    capsuleCount: c_int,
    hullOffset: c_int,
    hullCount: c_int,
    sharedHullCount: c_int,
    meshOffset: c_int,
    meshCount: c_int,
    sharedMeshCount: c_int,
    sphereOffset: c_int,
    sphereCount: c_int,
    pub const b3GetCompoundChild = __root.b3GetCompoundChild;
    pub const b3QueryCompound = __root.b3QueryCompound;
    pub const b3GetCompoundCapsule = __root.b3GetCompoundCapsule;
    pub const b3GetCompoundHull = __root.b3GetCompoundHull;
    pub const b3GetCompoundMesh = __root.b3GetCompoundMesh;
    pub const b3GetCompoundSphere = __root.b3GetCompoundSphere;
    pub const b3GetCompoundMaterials = __root.b3GetCompoundMaterials;
    pub const b3DestroyCompound = __root.b3DestroyCompound;
    pub const b3ConvertCompoundToBytes = __root.b3ConvertCompoundToBytes;
    pub const b3ComputeCompoundAABB = __root.b3ComputeCompoundAABB;
    pub const b3OverlapCompound = __root.b3OverlapCompound;
    pub const b3RayCastCompound = __root.b3RayCastCompound;
    pub const b3ShapeCastCompound = __root.b3ShapeCastCompound;
};
pub const b3CompoundData = struct_b3CompoundData;
pub const struct_b3HeightFieldData = extern struct {
    version: u64,
    byteCount: c_int,
    hash: u32,
    aabb: b3AABB,
    minHeight: f32,
    maxHeight: f32,
    heightScale: f32,
    scale: b3Vec3,
    columnCount: c_int,
    rowCount: c_int,
    heightsOffset: c_int,
    materialOffset: c_int,
    flagsOffset: c_int,
    clockwise: bool,
    padding: [3]u8,
    pub const b3GetHeightFieldCompressedHeights = __root.b3GetHeightFieldCompressedHeights;
    pub const b3GetHeightFieldMaterialIndices = __root.b3GetHeightFieldMaterialIndices;
    pub const b3GetHeightFieldFlags = __root.b3GetHeightFieldFlags;
    pub const b3DestroyHeightField = __root.b3DestroyHeightField;
    pub const b3ComputeHeightFieldAABB = __root.b3ComputeHeightFieldAABB;
    pub const b3OverlapHeightField = __root.b3OverlapHeightField;
    pub const b3RayCastHeightField = __root.b3RayCastHeightField;
    pub const b3ShapeCastHeightField = __root.b3ShapeCastHeightField;
    pub const b3QueryHeightField = __root.b3QueryHeightField;
};
pub const b3HeightFieldData = struct_b3HeightFieldData;
pub const struct_b3HullData = extern struct {
    version: u64,
    byteCount: c_int,
    hash: u32,
    aabb: b3AABB,
    surfaceArea: f32,
    volume: f32,
    innerRadius: f32,
    center: b3Vec3,
    centralInertia: b3Matrix3,
    vertexCount: c_int,
    vertexOffset: c_int,
    pointOffset: c_int,
    edgeCount: c_int,
    edgeOffset: c_int,
    faceCount: c_int,
    faceOffset: c_int,
    planeOffset: c_int,
    padding: c_int,
    pub const b3GetHullVertices = __root.b3GetHullVertices;
    pub const b3GetHullPoints = __root.b3GetHullPoints;
    pub const b3GetHullEdges = __root.b3GetHullEdges;
    pub const b3GetHullFaces = __root.b3GetHullFaces;
    pub const b3GetHullPlanes = __root.b3GetHullPlanes;
    pub const b3CloneHull = __root.b3CloneHull;
    pub const b3CloneAndTransformHull = __root.b3CloneAndTransformHull;
    pub const b3DestroyHull = __root.b3DestroyHull;
    pub const b3ComputeHullMass = __root.b3ComputeHullMass;
    pub const b3ComputeHullAABB = __root.b3ComputeHullAABB;
    pub const b3OverlapHull = __root.b3OverlapHull;
    pub const b3RayCastHull = __root.b3RayCastHull;
    pub const b3ShapeCastHull = __root.b3ShapeCastHull;
};
pub const b3HullData = struct_b3HullData;
pub const struct_b3MeshData = extern struct {
    version: u64,
    byteCount: c_int,
    hash: u32,
    bounds: b3AABB,
    surfaceArea: f32,
    treeHeight: c_int,
    degenerateCount: c_int,
    nodeOffset: c_int,
    nodeCount: c_int,
    vertexOffset: c_int,
    vertexCount: c_int,
    triangleOffset: c_int,
    triangleCount: c_int,
    materialOffset: c_int,
    materialCount: c_int,
    flagsOffset: c_int,
    pub const b3GetMeshNodes = __root.b3GetMeshNodes;
    pub const b3GetMeshVertices = __root.b3GetMeshVertices;
    pub const b3GetMeshTriangles = __root.b3GetMeshTriangles;
    pub const b3GetMeshMaterialIndices = __root.b3GetMeshMaterialIndices;
    pub const b3GetMeshFlags = __root.b3GetMeshFlags;
    pub const b3DestroyMesh = __root.b3DestroyMesh;
    pub const b3GetHeight = __root.b3GetHeight;
    pub const b3ComputeMeshAABB = __root.b3ComputeMeshAABB;
};
pub const b3MeshData = struct_b3MeshData;
pub const struct_b3Mesh = extern struct {
    data: [*c]const b3MeshData,
    scale: b3Vec3,
    pub const b3OverlapMesh = __root.b3OverlapMesh;
    pub const b3RayCastMesh = __root.b3RayCastMesh;
    pub const b3ShapeCastMesh = __root.b3ShapeCastMesh;
    pub const b3QueryMesh = __root.b3QueryMesh;
};
pub const b3Mesh = struct_b3Mesh;
pub const struct_b3Sphere = extern struct {
    center: b3Vec3,
    radius: f32,
    pub const b3ComputeSphereMass = __root.b3ComputeSphereMass;
    pub const b3ComputeSphereAABB = __root.b3ComputeSphereAABB;
    pub const b3OverlapSphere = __root.b3OverlapSphere;
    pub const b3RayCastSphere = __root.b3RayCastSphere;
    pub const b3RayCastHollowSphere = __root.b3RayCastHollowSphere;
    pub const b3ShapeCastSphere = __root.b3ShapeCastSphere;
};
pub const b3Sphere = struct_b3Sphere;
const union_unnamed_2 = extern union {
    capsule: [*c]const b3Capsule,
    compound: [*c]const b3CompoundData,
    heightField: [*c]const b3HeightFieldData,
    hull: [*c]const b3HullData,
    mesh: [*c]const b3Mesh,
    sphere: [*c]const b3Sphere,
};
pub const struct_b3DebugShape = extern struct {
    shapeId: b3ShapeId,
    type: b3ShapeType,
    unnamed_0: union_unnamed_2,
};
pub const b3DebugShape = struct_b3DebugShape;
pub const b3CreateDebugShapeCallback = fn (debugShape: [*c]const b3DebugShape, userContext: ?*anyopaque) callconv(.c) ?*anyopaque;
pub const b3DestroyDebugShapeCallback = fn (userShape: ?*anyopaque, userContext: ?*anyopaque) callconv(.c) void;
pub const b3FrictionCallback = fn (frictionA: f32, userMaterialIdA: u64, frictionB: f32, userMaterialIdB: u64) callconv(.c) f32;
pub const b3RestitutionCallback = fn (restitutionA: f32, userMaterialIdA: u64, restitutionB: f32, userMaterialIdB: u64) callconv(.c) f32;
pub const b3CustomFilterFcn = fn (shapeIdA: b3ShapeId, shapeIdB: b3ShapeId, context: ?*anyopaque) callconv(.c) bool;
pub const b3PreSolveFcn = fn (shapeIdA: b3ShapeId, shapeIdB: b3ShapeId, point: b3Pos, normal: b3Vec3, context: ?*anyopaque) callconv(.c) bool;
pub const b3OverlapResultFcn = fn (shapeId: b3ShapeId, context: ?*anyopaque) callconv(.c) bool;
pub const b3CastResultFcn = fn (shapeId: b3ShapeId, point: b3Pos, normal: b3Vec3, fraction: f32, userMaterialId: u64, triangleIndex: c_int, childIndex: c_int, context: ?*anyopaque) callconv(.c) f32;
pub const struct_b3Capacity = extern struct {
    staticShapeCount: c_int,
    dynamicShapeCount: c_int,
    staticBodyCount: c_int,
    dynamicBodyCount: c_int,
    contactCount: c_int,
};
pub const b3Capacity = struct_b3Capacity;
pub const struct_b3WorldDef = extern struct {
    gravity: b3Vec3,
    restitutionThreshold: f32,
    hitEventThreshold: f32,
    contactHertz: f32,
    contactDampingRatio: f32,
    contactSpeed: f32,
    maximumLinearSpeed: f32,
    frictionCallback: ?*const b3FrictionCallback,
    restitutionCallback: ?*const b3RestitutionCallback,
    enableSleep: bool,
    enableContinuous: bool,
    workerCount: u32,
    enqueueTask: ?*const b3EnqueueTaskCallback,
    finishTask: ?*const b3FinishTaskCallback,
    userTaskContext: ?*anyopaque,
    userData: ?*anyopaque,
    createDebugShape: ?*const b3CreateDebugShapeCallback,
    destroyDebugShape: ?*const b3DestroyDebugShapeCallback,
    userDebugShapeContext: ?*anyopaque,
    capacity: b3Capacity,
    internalValue: c_int,
    pub const b3CreateWorld = __root.b3CreateWorld;
};
pub const b3WorldDef = struct_b3WorldDef;
pub extern fn b3DefaultWorldDef() b3WorldDef;
pub const b3_staticBody: c_int = 0;
pub const b3_kinematicBody: c_int = 1;
pub const b3_dynamicBody: c_int = 2;
pub const b3_bodyTypeCount: c_int = 3;
pub const enum_b3BodyType = c_uint;
pub const b3BodyType = enum_b3BodyType;
pub const struct_b3MotionLocks = extern struct {
    linearX: bool,
    linearY: bool,
    linearZ: bool,
    angularX: bool,
    angularY: bool,
    angularZ: bool,
};
pub const b3MotionLocks = struct_b3MotionLocks;
pub const struct_b3BodyDef = extern struct {
    type: b3BodyType,
    position: b3Pos,
    rotation: b3Quat,
    linearVelocity: b3Vec3,
    angularVelocity: b3Vec3,
    linearDamping: f32,
    angularDamping: f32,
    gravityScale: f32,
    sleepThreshold: f32,
    name: [*c]const u8,
    userData: ?*anyopaque,
    motionLocks: b3MotionLocks,
    enableSleep: bool,
    isAwake: bool,
    isBullet: bool,
    isEnabled: bool,
    allowFastRotation: bool,
    enableContactRecycling: bool,
    internalValue: c_int,
};
pub const b3BodyDef = struct_b3BodyDef;
pub extern fn b3DefaultBodyDef() b3BodyDef;
pub const struct_b3Filter = extern struct {
    categoryBits: u64,
    maskBits: u64,
    groupIndex: c_int,
};
pub const b3Filter = struct_b3Filter;
pub extern fn b3DefaultFilter() b3Filter;
pub const struct_b3SurfaceMaterial = extern struct {
    friction: f32,
    restitution: f32,
    rollingResistance: f32,
    tangentVelocity: b3Vec3,
    userMaterialId: u64,
    customColor: u32,
};
pub const b3SurfaceMaterial = struct_b3SurfaceMaterial;
pub extern fn b3DefaultSurfaceMaterial() b3SurfaceMaterial;
pub const struct_b3ShapeDef = extern struct {
    userData: ?*anyopaque,
    materials: [*c]b3SurfaceMaterial,
    materialCount: c_int,
    baseMaterial: b3SurfaceMaterial,
    density: f32,
    explosionScale: f32,
    filter: b3Filter,
    enableCustomFiltering: bool,
    isSensor: bool,
    enableSensorEvents: bool,
    enableContactEvents: bool,
    enableHitEvents: bool,
    enablePreSolveEvents: bool,
    invokeContactCreation: bool,
    updateBodyMass: bool,
    internalValue: c_int,
};
pub const b3ShapeDef = struct_b3ShapeDef;
pub extern fn b3DefaultShapeDef() b3ShapeDef;
pub const struct_b3Profile = extern struct {
    step: f32,
    pairs: f32,
    collide: f32,
    solve: f32,
    solverSetup: f32,
    constraints: f32,
    prepareConstraints: f32,
    integrateVelocities: f32,
    warmStart: f32,
    solveImpulses: f32,
    integratePositions: f32,
    relaxImpulses: f32,
    applyRestitution: f32,
    storeImpulses: f32,
    splitIslands: f32,
    transforms: f32,
    sensorHits: f32,
    jointEvents: f32,
    hitEvents: f32,
    refit: f32,
    bullets: f32,
    sleepIslands: f32,
    sensors: f32,
};
pub const b3Profile = struct_b3Profile;
pub const struct_b3Counters = extern struct {
    bodyCount: c_int,
    shapeCount: c_int,
    contactCount: c_int,
    jointCount: c_int,
    islandCount: c_int,
    stackUsed: c_int,
    arenaCapacity: c_int,
    staticTreeHeight: c_int,
    treeHeight: c_int,
    satCallCount: c_int,
    satCacheHitCount: c_int,
    byteCount: c_int,
    taskCount: c_int,
    colorCounts: [24]c_int,
    manifoldCounts: [8]c_int,
    awakeContactCount: c_int,
    recycledContactCount: c_int,
    distanceIterations: c_int,
    pushBackIterations: c_int,
    rootIterations: c_int,
};
pub const b3Counters = struct_b3Counters;
pub const b3_parallelJoint: c_int = 0;
pub const b3_distanceJoint: c_int = 1;
pub const b3_filterJoint: c_int = 2;
pub const b3_motorJoint: c_int = 3;
pub const b3_prismaticJoint: c_int = 4;
pub const b3_revoluteJoint: c_int = 5;
pub const b3_sphericalJoint: c_int = 6;
pub const b3_weldJoint: c_int = 7;
pub const b3_wheelJoint: c_int = 8;
pub const enum_b3JointType = c_uint;
pub const b3JointType = enum_b3JointType;
pub const struct_b3JointDef = extern struct {
    userData: ?*anyopaque,
    bodyIdA: b3BodyId,
    bodyIdB: b3BodyId,
    localFrameA: b3Transform,
    localFrameB: b3Transform,
    forceThreshold: f32,
    torqueThreshold: f32,
    constraintHertz: f32,
    constraintDampingRatio: f32,
    drawScale: f32,
    collideConnected: bool,
    internalValue: c_int,
};
pub const b3JointDef = struct_b3JointDef;
pub const struct_b3DistanceJointDef = extern struct {
    base: b3JointDef,
    length: f32,
    enableSpring: bool,
    lowerSpringForce: f32,
    upperSpringForce: f32,
    hertz: f32,
    dampingRatio: f32,
    enableLimit: bool,
    minLength: f32,
    maxLength: f32,
    enableMotor: bool,
    maxMotorForce: f32,
    motorSpeed: f32,
};
pub const b3DistanceJointDef = struct_b3DistanceJointDef;
pub extern fn b3DefaultDistanceJointDef() b3DistanceJointDef;
pub const struct_b3MotorJointDef = extern struct {
    base: b3JointDef,
    linearVelocity: b3Vec3,
    maxVelocityForce: f32,
    angularVelocity: b3Vec3,
    maxVelocityTorque: f32,
    linearHertz: f32,
    linearDampingRatio: f32,
    maxSpringForce: f32,
    angularHertz: f32,
    angularDampingRatio: f32,
    maxSpringTorque: f32,
};
pub const b3MotorJointDef = struct_b3MotorJointDef;
pub extern fn b3DefaultMotorJointDef() b3MotorJointDef;
pub const struct_b3FilterJointDef = extern struct {
    base: b3JointDef,
};
pub const b3FilterJointDef = struct_b3FilterJointDef;
pub extern fn b3DefaultFilterJointDef() b3FilterJointDef;
pub const struct_b3ParallelJointDef = extern struct {
    base: b3JointDef,
    hertz: f32,
    dampingRatio: f32,
    maxTorque: f32,
};
pub const b3ParallelJointDef = struct_b3ParallelJointDef;
pub extern fn b3DefaultParallelJointDef() b3ParallelJointDef;
pub const struct_b3PrismaticJointDef = extern struct {
    base: b3JointDef,
    enableSpring: bool,
    hertz: f32,
    dampingRatio: f32,
    targetTranslation: f32,
    enableLimit: bool,
    lowerTranslation: f32,
    upperTranslation: f32,
    enableMotor: bool,
    maxMotorForce: f32,
    motorSpeed: f32,
};
pub const b3PrismaticJointDef = struct_b3PrismaticJointDef;
pub extern fn b3DefaultPrismaticJointDef() b3PrismaticJointDef;
pub const struct_b3RevoluteJointDef = extern struct {
    base: b3JointDef,
    targetAngle: f32,
    enableSpring: bool,
    hertz: f32,
    dampingRatio: f32,
    enableLimit: bool,
    lowerAngle: f32,
    upperAngle: f32,
    enableMotor: bool,
    maxMotorTorque: f32,
    motorSpeed: f32,
};
pub const b3RevoluteJointDef = struct_b3RevoluteJointDef;
pub extern fn b3DefaultRevoluteJointDef() b3RevoluteJointDef;
pub const struct_b3SphericalJointDef = extern struct {
    base: b3JointDef,
    enableSpring: bool,
    hertz: f32,
    dampingRatio: f32,
    targetRotation: b3Quat,
    enableConeLimit: bool,
    coneAngle: f32,
    enableTwistLimit: bool,
    lowerTwistAngle: f32,
    upperTwistAngle: f32,
    enableMotor: bool,
    maxMotorTorque: f32,
    motorVelocity: b3Vec3,
};
pub const b3SphericalJointDef = struct_b3SphericalJointDef;
pub extern fn b3DefaultSphericalJointDef() b3SphericalJointDef;
pub const struct_b3WeldJointDef = extern struct {
    base: b3JointDef,
    linearHertz: f32,
    angularHertz: f32,
    linearDampingRatio: f32,
    angularDampingRatio: f32,
};
pub const b3WeldJointDef = struct_b3WeldJointDef;
pub extern fn b3DefaultWeldJointDef() b3WeldJointDef;
pub const struct_b3WheelJointDef = extern struct {
    base: b3JointDef,
    enableSuspensionSpring: bool,
    suspensionHertz: f32,
    suspensionDampingRatio: f32,
    enableSuspensionLimit: bool,
    lowerSuspensionLimit: f32,
    upperSuspensionLimit: f32,
    enableSpinMotor: bool,
    maxSpinTorque: f32,
    spinSpeed: f32,
    enableSteering: bool,
    steeringHertz: f32,
    steeringDampingRatio: f32,
    targetSteeringAngle: f32,
    maxSteeringTorque: f32,
    enableSteeringLimit: bool,
    lowerSteeringLimit: f32,
    upperSteeringLimit: f32,
};
pub const b3WheelJointDef = struct_b3WheelJointDef;
pub extern fn b3DefaultWheelJointDef() b3WheelJointDef;
pub const struct_b3ExplosionDef = extern struct {
    maskBits: u64,
    position: b3Pos,
    radius: f32,
    falloff: f32,
    impulsePerArea: f32,
};
pub const b3ExplosionDef = struct_b3ExplosionDef;
pub extern fn b3DefaultExplosionDef() b3ExplosionDef;
pub const struct_b3SensorBeginTouchEvent = extern struct {
    sensorShapeId: b3ShapeId,
    visitorShapeId: b3ShapeId,
};
pub const b3SensorBeginTouchEvent = struct_b3SensorBeginTouchEvent;
pub const struct_b3SensorEndTouchEvent = extern struct {
    sensorShapeId: b3ShapeId,
    visitorShapeId: b3ShapeId,
};
pub const b3SensorEndTouchEvent = struct_b3SensorEndTouchEvent;
pub const struct_b3SensorEvents = extern struct {
    beginEvents: [*c]b3SensorBeginTouchEvent,
    endEvents: [*c]b3SensorEndTouchEvent,
    beginCount: c_int,
    endCount: c_int,
};
pub const b3SensorEvents = struct_b3SensorEvents;
pub const struct_b3ContactBeginTouchEvent = extern struct {
    shapeIdA: b3ShapeId,
    shapeIdB: b3ShapeId,
    contactId: b3ContactId,
};
pub const b3ContactBeginTouchEvent = struct_b3ContactBeginTouchEvent;
pub const struct_b3ContactEndTouchEvent = extern struct {
    shapeIdA: b3ShapeId,
    shapeIdB: b3ShapeId,
    contactId: b3ContactId,
};
pub const b3ContactEndTouchEvent = struct_b3ContactEndTouchEvent;
pub const struct_b3ContactHitEvent = extern struct {
    shapeIdA: b3ShapeId,
    shapeIdB: b3ShapeId,
    contactId: b3ContactId,
    point: b3Pos,
    normal: b3Vec3,
    approachSpeed: f32,
    userMaterialIdA: u64,
    userMaterialIdB: u64,
};
pub const b3ContactHitEvent = struct_b3ContactHitEvent;
pub const struct_b3ContactEvents = extern struct {
    beginEvents: [*c]b3ContactBeginTouchEvent,
    endEvents: [*c]b3ContactEndTouchEvent,
    hitEvents: [*c]b3ContactHitEvent,
    beginCount: c_int,
    endCount: c_int,
    hitCount: c_int,
};
pub const b3ContactEvents = struct_b3ContactEvents;
pub const struct_b3BodyMoveEvent = extern struct {
    userData: ?*anyopaque,
    transform: b3WorldTransform,
    bodyId: b3BodyId,
    fellAsleep: bool,
};
pub const b3BodyMoveEvent = struct_b3BodyMoveEvent;
pub const struct_b3BodyEvents = extern struct {
    moveEvents: [*c]b3BodyMoveEvent,
    moveCount: c_int,
};
pub const b3BodyEvents = struct_b3BodyEvents;
pub const struct_b3JointEvent = extern struct {
    jointId: b3JointId,
    userData: ?*anyopaque,
};
pub const b3JointEvent = struct_b3JointEvent;
pub const struct_b3JointEvents = extern struct {
    jointEvents: [*c]b3JointEvent,
    count: c_int,
};
pub const b3JointEvents = struct_b3JointEvents;
pub const struct_b3ManifoldPoint = extern struct {
    anchorA: b3Vec3,
    anchorB: b3Vec3,
    separation: f32,
    baseSeparation: f32,
    normalImpulse: f32,
    totalNormalImpulse: f32,
    normalVelocity: f32,
    featureId: u32,
    triangleIndex: c_int,
    persisted: bool,
};
pub const b3ManifoldPoint = struct_b3ManifoldPoint;
pub const struct_b3Manifold = extern struct {
    points: [4]b3ManifoldPoint,
    normal: b3Vec3,
    twistImpulse: f32,
    frictionImpulse: b3Vec3,
    rollingImpulse: b3Vec3,
    pointCount: c_int,
};
pub const struct_b3ContactData = extern struct {
    contactId: b3ContactId,
    shapeIdA: b3ShapeId,
    shapeIdB: b3ShapeId,
    manifolds: [*c]const struct_b3Manifold,
    manifoldCount: c_int,
};
pub const b3ContactData = struct_b3ContactData;
pub const struct_b3QueryFilter = extern struct {
    categoryBits: u64,
    maskBits: u64,
    id: u64,
    name: [*c]const u8,
};
pub const b3QueryFilter = struct_b3QueryFilter;
pub extern fn b3DefaultQueryFilter() b3QueryFilter;
pub const struct_b3RayCastInput = extern struct {
    origin: b3Vec3,
    translation: b3Vec3,
    maxFraction: f32,
    pub const b3IsValidRay = __root.b3IsValidRay;
};
pub const b3RayCastInput = struct_b3RayCastInput;
pub const struct_b3RayResult = extern struct {
    shapeId: b3ShapeId,
    point: b3Pos,
    normal: b3Vec3,
    userMaterialId: u64,
    fraction: f32,
    triangleIndex: c_int,
    childIndex: c_int,
    nodeVisits: c_int,
    leafVisits: c_int,
    hit: bool,
};
pub const b3RayResult = struct_b3RayResult;
pub const struct_b3ShapeProxy = extern struct {
    points: [*c]const b3Vec3,
    count: c_int,
    radius: f32,
};
pub const b3ShapeProxy = struct_b3ShapeProxy;
pub const struct_b3ShapeCastInput = extern struct {
    proxy: b3ShapeProxy,
    translation: b3Vec3,
    maxFraction: f32,
    canEncroach: bool,
};
pub const b3ShapeCastInput = struct_b3ShapeCastInput;
pub const struct_b3BoxCastInput = extern struct {
    box: b3AABB,
    translation: b3Vec3,
    maxFraction: f32,
};
pub const b3BoxCastInput = struct_b3BoxCastInput;
pub const struct_b3CastOutput = extern struct {
    normal: b3Vec3,
    point: b3Vec3,
    fraction: f32,
    iterations: c_int,
    triangleIndex: c_int,
    childIndex: c_int,
    materialIndex: c_int,
    hit: bool,
};
pub const b3CastOutput = struct_b3CastOutput;
pub const b3WorldCastOutput = b3CastOutput;
pub const struct_b3BodyCastResult = extern struct {
    shapeId: b3ShapeId,
    point: b3Pos,
    normal: b3Vec3,
    fraction: f32,
    triangleIndex: c_int,
    userMaterialId: u64,
    iterations: c_int,
    hit: bool,
};
pub const b3BodyCastResult = struct_b3BodyCastResult;
pub const struct_b3SimplexCache = extern struct {
    metric: f32,
    count: u16,
    indexA: [4]u8,
    indexB: [4]u8,
};
pub const b3SimplexCache = struct_b3SimplexCache;
pub const b3_emptyDistanceCache: b3SimplexCache = b3SimplexCache{
    .metric = @floatFromInt(@as(c_int, 0)),
    .count = 0,
    .indexA = @import("std").mem.zeroes([4]u8),
    .indexB = @import("std").mem.zeroes([4]u8),
};
pub const struct_b3ShapeCastPairInput = extern struct {
    proxyA: b3ShapeProxy,
    proxyB: b3ShapeProxy,
    transform: b3Transform,
    translationB: b3Vec3,
    maxFraction: f32,
    canEncroach: bool,
    pub const b3ShapeCast = __root.b3ShapeCast;
};
pub const b3ShapeCastPairInput = struct_b3ShapeCastPairInput;
pub const struct_b3DistanceInput = extern struct {
    proxyA: b3ShapeProxy,
    proxyB: b3ShapeProxy,
    transform: b3Transform,
    useRadii: bool,
    pub const b3ShapeDistance = __root.b3ShapeDistance;
};
pub const b3DistanceInput = struct_b3DistanceInput;
pub const struct_b3DistanceOutput = extern struct {
    pointA: b3Vec3,
    pointB: b3Vec3,
    normal: b3Vec3,
    distance: f32,
    iterations: c_int,
    simplexCount: c_int,
};
pub const b3DistanceOutput = struct_b3DistanceOutput;
pub const struct_b3SimplexVertex = extern struct {
    wA: b3Vec3,
    wB: b3Vec3,
    w: b3Vec3,
    a: f32,
    indexA: c_int,
    indexB: c_int,
};
pub const b3SimplexVertex = struct_b3SimplexVertex;
pub const struct_b3Simplex = extern struct {
    vertices: [4]b3SimplexVertex,
    count: c_int,
};
pub const b3Simplex = struct_b3Simplex;
pub const struct_b3Sweep = extern struct {
    localCenter: b3Vec3,
    c1: b3Vec3,
    c2: b3Vec3,
    q1: b3Quat,
    q2: b3Quat,
    pub const b3GetSweepTransform = __root.b3GetSweepTransform;
};
pub const b3Sweep = struct_b3Sweep;
pub const struct_b3TOIInput = extern struct {
    proxyA: b3ShapeProxy,
    proxyB: b3ShapeProxy,
    sweepA: b3Sweep,
    sweepB: b3Sweep,
    maxFraction: f32,
    pub const b3TimeOfImpact = __root.b3TimeOfImpact;
};
pub const b3TOIInput = struct_b3TOIInput;
pub const b3_toiStateUnknown: c_int = 0;
pub const b3_toiStateFailed: c_int = 1;
pub const b3_toiStateOverlapped: c_int = 2;
pub const b3_toiStateHit: c_int = 3;
pub const b3_toiStateSeparated: c_int = 4;
pub const enum_b3TOIState = c_uint;
pub const b3TOIState = enum_b3TOIState;
pub const struct_b3TOIOutput = extern struct {
    state: b3TOIState,
    point: b3Vec3,
    normal: b3Vec3,
    fraction: f32,
    distance: f32,
    distanceIterations: c_int,
    pushBackIterations: c_int,
    rootIterations: c_int,
    usedFallback: bool,
};
pub const b3TOIOutput = struct_b3TOIOutput;
pub const b3_allocatedNode: c_int = 1;
pub const b3_enlargedNode: c_int = 2;
pub const b3_leafNode: c_int = 4;
pub const enum_b3TreeNodeFlags = c_uint;
pub const b3TreeNodeFlags = enum_b3TreeNodeFlags;
pub const struct_b3TreeStats = extern struct {
    nodeVisits: c_int,
    leafVisits: c_int,
};
pub const b3TreeStats = struct_b3TreeStats;
pub const b3TreeQueryCallbackFcn = fn (proxyId: c_int, userData: u64, context: ?*anyopaque) callconv(.c) bool;
pub const b3TreeQueryClosestCallbackFcn = fn (distanceSqrMin: f32, proxyId: c_int, userData: u64, context: ?*anyopaque) callconv(.c) f32;
pub const b3TreeBoxCastCallbackFcn = fn (input: [*c]const b3BoxCastInput, proxyId: c_int, userData: u64, context: ?*anyopaque) callconv(.c) f32;
pub const b3TreeRayCastCallbackFcn = fn (input: [*c]const b3RayCastInput, proxyId: c_int, userData: u64, context: ?*anyopaque) callconv(.c) f32;
pub const struct_b3PlaneResult = extern struct {
    plane: b3Plane,
    point: b3Vec3,
};
pub const b3PlaneResult = struct_b3PlaneResult;
pub const struct_b3CollisionPlane = extern struct {
    plane: b3Plane,
    pushLimit: f32,
    push: f32,
    clipVelocity: bool,
};
pub const b3CollisionPlane = struct_b3CollisionPlane;
pub const struct_b3PlaneSolverResult = extern struct {
    delta: b3Vec3,
    iterationCount: c_int,
};
pub const b3PlaneSolverResult = struct_b3PlaneSolverResult;
pub const struct_b3BodyPlaneResult = extern struct {
    shapeId: b3ShapeId,
    result: b3PlaneResult,
};
pub const b3BodyPlaneResult = struct_b3BodyPlaneResult;
pub const b3PlaneResultFcn = fn (shapeId: b3ShapeId, plane: [*c]const b3PlaneResult, planeCount: c_int, context: ?*anyopaque) callconv(.c) bool;
pub const b3MoverFilterFcn = fn (shapeId: b3ShapeId, context: ?*anyopaque) callconv(.c) bool;
pub const struct_b3MassData = extern struct {
    mass: f32,
    center: b3Vec3,
    inertia: b3Matrix3,
};
pub const b3MassData = struct_b3MassData;
pub const struct_b3HullVertex = extern struct {
    edge: u8,
};
pub const b3HullVertex = struct_b3HullVertex;
pub const struct_b3HullHalfEdge = extern struct {
    next: u8,
    twin: u8,
    origin: u8,
    face: u8,
};
pub const b3HullHalfEdge = struct_b3HullHalfEdge;
pub const struct_b3HullFace = extern struct {
    edge: u8,
};
pub const b3HullFace = struct_b3HullFace;
pub const struct_b3BoxHull = extern struct {
    base: b3HullData,
    boxVertices: [8]b3HullVertex,
    boxPoints: [8]b3Vec3,
    boxEdges: [24]b3HullHalfEdge,
    boxFaces: [6]b3HullFace,
    padding: [2]u8,
    boxPlanes: [6]b3Plane,
};
pub const b3BoxHull = struct_b3BoxHull;
pub const struct_b3MeshDef = extern struct {
    vertices: [*c]b3Vec3,
    indices: [*c]i32,
    materialIndices: [*c]u8,
    weldTolerance: f32,
    vertexCount: c_int,
    triangleCount: c_int,
    weldVertices: bool,
    useMedianSplit: bool,
    identifyEdges: bool,
    pub const b3CreateMesh = __root.b3CreateMesh;
};
pub const b3MeshDef = struct_b3MeshDef;
pub const b3_concaveEdge1: c_int = 1;
pub const b3_concaveEdge2: c_int = 2;
pub const b3_concaveEdge3: c_int = 4;
pub const b3_inverseConcaveEdge1: c_int = 16;
pub const b3_inverseConcaveEdge2: c_int = 32;
pub const b3_inverseConcaveEdge3: c_int = 64;
pub const b3_allConcaveEdges: c_int = 7;
pub const b3_flatEdge1: c_int = 17;
pub const b3_flatEdge2: c_int = 34;
pub const b3_flatEdge3: c_int = 68;
pub const b3_allFlatEdges: c_int = 119;
pub const enum_b3MeshEdgeFlags = c_uint;
pub const b3MeshEdgeFlags = enum_b3MeshEdgeFlags;
pub const struct_b3MeshTriangle = extern struct {
    index1: i32,
    index2: i32,
    index3: i32,
};
pub const b3MeshTriangle = struct_b3MeshTriangle;
// ../DINX/vendor/box3d-0.1.0/include/box3d/types.h:2121:13: warning: struct demoted to opaque type - has bitfield
const struct_unnamed_6 = opaque {};
// ../DINX/vendor/box3d-0.1.0/include/box3d/types.h:2124:5: warning: union demoted to opaque type - has opaque field
const union_unnamed_5 = opaque {};
// ../DINX/vendor/box3d-0.1.0/include/box3d/types.h:2135:4: warning: struct demoted to opaque type - has opaque field
pub const struct_b3MeshNode = opaque {};
pub const b3MeshNode = struct_b3MeshNode;
pub const struct_b3HeightFieldDef = extern struct {
    heights: [*c]f32,
    materialIndices: [*c]u8,
    scale: b3Vec3,
    countX: c_int,
    countZ: c_int,
    globalMinimumHeight: f32,
    globalMaximumHeight: f32,
    clockwiseWinding: bool,
    pub const b3CreateHeightField = __root.b3CreateHeightField;
    pub const b3DumpHeightData = __root.b3DumpHeightData;
};
pub const b3HeightFieldDef = struct_b3HeightFieldDef;
pub const struct_b3CompoundCapsuleDef = extern struct {
    capsule: b3Capsule,
    material: b3SurfaceMaterial,
};
pub const b3CompoundCapsuleDef = struct_b3CompoundCapsuleDef;
pub const struct_b3CompoundHullDef = extern struct {
    hull: [*c]const b3HullData,
    transform: b3Transform,
    material: b3SurfaceMaterial,
};
pub const b3CompoundHullDef = struct_b3CompoundHullDef;
pub const struct_b3CompoundMeshDef = extern struct {
    meshData: [*c]const b3MeshData,
    transform: b3Transform,
    scale: b3Vec3,
    materials: [*c]const b3SurfaceMaterial,
    materialCount: c_int,
};
pub const b3CompoundMeshDef = struct_b3CompoundMeshDef;
pub const struct_b3CompoundSphereDef = extern struct {
    sphere: b3Sphere,
    material: b3SurfaceMaterial,
};
pub const b3CompoundSphereDef = struct_b3CompoundSphereDef;
pub const struct_b3CompoundDef = extern struct {
    capsules: [*c]b3CompoundCapsuleDef,
    capsuleCount: c_int,
    hulls: [*c]b3CompoundHullDef,
    hullCount: c_int,
    meshes: [*c]b3CompoundMeshDef,
    meshCount: c_int,
    spheres: [*c]b3CompoundSphereDef,
    sphereCount: c_int,
    pub const b3CreateCompound = __root.b3CreateCompound;
};
pub const b3CompoundDef = struct_b3CompoundDef;
pub const struct_b3CompoundCapsule = extern struct {
    capsule: b3Capsule,
    materialIndex: c_int,
};
pub const b3CompoundCapsule = struct_b3CompoundCapsule;
pub const struct_b3CompoundHull = extern struct {
    hull: [*c]const b3HullData,
    transform: b3Transform,
    materialIndex: c_int,
};
pub const b3CompoundHull = struct_b3CompoundHull;
pub const struct_b3CompoundMesh = extern struct {
    meshData: [*c]const b3MeshData,
    transform: b3Transform,
    scale: b3Vec3,
    materialIndices: [4]c_int,
};
pub const b3CompoundMesh = struct_b3CompoundMesh;
pub const struct_b3CompoundSphere = extern struct {
    sphere: b3Sphere,
    materialIndex: c_int,
};
pub const b3CompoundSphere = struct_b3CompoundSphere;
const union_unnamed_7 = extern union {
    capsule: b3Capsule,
    hull: [*c]const b3HullData,
    mesh: b3Mesh,
    sphere: b3Sphere,
};
pub const struct_b3ChildShape = extern struct {
    unnamed_0: union_unnamed_7,
    transform: b3Transform,
    materialIndices: [4]c_int,
    type: b3ShapeType,
};
pub const b3ChildShape = struct_b3ChildShape;
pub const b3CompoundQueryFcn = fn (compound: [*c]const b3CompoundData, childIndex: c_int, context: ?*anyopaque) callconv(.c) bool;
pub const b3Manifold = struct_b3Manifold;
pub const b3_invalidAxis: c_int = 0;
pub const b3_backsideAxis: c_int = 1;
pub const b3_faceAxisA: c_int = 2;
pub const b3_faceAxisB: c_int = 3;
pub const b3_edgePairAxis: c_int = 4;
pub const b3_closestPointsAxis: c_int = 5;
pub const b3_manualFaceAxisA: c_int = 6;
pub const b3_manualFaceAxisB: c_int = 7;
pub const b3_manualEdgePairAxis: c_int = 8;
pub const b3SeparatingFeature = c_uint;
pub const b3_featureNone: c_int = 0;
pub const b3_featureTriangleFace: c_int = 1;
pub const b3_featureHullFace: c_int = 2;
pub const b3_featureEdge1: c_int = 3;
pub const b3_featureEdge2: c_int = 4;
pub const b3_featureEdge3: c_int = 5;
pub const b3_featureVertex1: c_int = 6;
pub const b3_featureVertex2: c_int = 7;
pub const b3_featureVertex3: c_int = 8;
pub const b3TriangleFeature = c_uint;
pub const b3SATCache = extern struct {
    separation: f32,
    type: u8,
    indexA: u8,
    indexB: u8,
    hit: u8,
};
pub const struct_b3FeaturePair = extern struct {
    owner1: u8,
    index1: u8,
    owner2: u8,
    index2: u8,
};
pub const b3FeaturePair = struct_b3FeaturePair;
pub const struct_b3LocalManifoldPoint = extern struct {
    point: b3Vec3,
    separation: f32,
    pair: b3FeaturePair,
    triangleIndex: c_int,
};
pub const b3LocalManifoldPoint = struct_b3LocalManifoldPoint;
pub const struct_b3LocalManifold = extern struct {
    normal: b3Vec3,
    triangleNormal: b3Vec3,
    points: [*c]b3LocalManifoldPoint,
    pointCount: c_int,
    triangleIndex: c_int,
    i1: c_int,
    i2: c_int,
    i3: c_int,
    squaredDistance: f32,
    feature: b3TriangleFeature,
    triangleFlags: c_int,
    pub const b3CollideSpheres = __root.b3CollideSpheres;
    pub const b3CollideCapsuleAndSphere = __root.b3CollideCapsuleAndSphere;
    pub const b3CollideHullAndSphere = __root.b3CollideHullAndSphere;
    pub const b3CollideCapsules = __root.b3CollideCapsules;
    pub const b3CollideHullAndCapsule = __root.b3CollideHullAndCapsule;
    pub const b3CollideHulls = __root.b3CollideHulls;
    pub const b3CollideCapsuleAndTriangle = __root.b3CollideCapsuleAndTriangle;
    pub const b3CollideHullAndTriangle = __root.b3CollideHullAndTriangle;
    pub const b3CollideSphereAndTriangle = __root.b3CollideSphereAndTriangle;
};
pub const b3LocalManifold = struct_b3LocalManifold;
pub const b3_colorAliceBlue: c_int = 15792383;
pub const b3_colorAntiqueWhite: c_int = 16444375;
pub const b3_colorAqua: c_int = 65535;
pub const b3_colorAquamarine: c_int = 8388564;
pub const b3_colorAzure: c_int = 15794175;
pub const b3_colorBeige: c_int = 16119260;
pub const b3_colorBisque: c_int = 16770244;
pub const b3_colorBlack: c_int = 0;
pub const b3_colorBlanchedAlmond: c_int = 16772045;
pub const b3_colorBlue: c_int = 255;
pub const b3_colorBlueViolet: c_int = 9055202;
pub const b3_colorBrown: c_int = 10824234;
pub const b3_colorBurlywood: c_int = 14596231;
pub const b3_colorCadetBlue: c_int = 6266528;
pub const b3_colorChartreuse: c_int = 8388352;
pub const b3_colorChocolate: c_int = 13789470;
pub const b3_colorCoral: c_int = 16744272;
pub const b3_colorCornflowerBlue: c_int = 6591981;
pub const b3_colorCornsilk: c_int = 16775388;
pub const b3_colorCrimson: c_int = 14423100;
pub const b3_colorCyan: c_int = 65535;
pub const b3_colorDarkBlue: c_int = 139;
pub const b3_colorDarkCyan: c_int = 35723;
pub const b3_colorDarkGoldenRod: c_int = 12092939;
pub const b3_colorDarkGray: c_int = 11119017;
pub const b3_colorDarkGreen: c_int = 25600;
pub const b3_colorDarkKhaki: c_int = 12433259;
pub const b3_colorDarkMagenta: c_int = 9109643;
pub const b3_colorDarkOliveGreen: c_int = 5597999;
pub const b3_colorDarkOrange: c_int = 16747520;
pub const b3_colorDarkOrchid: c_int = 10040012;
pub const b3_colorDarkRed: c_int = 9109504;
pub const b3_colorDarkSalmon: c_int = 15308410;
pub const b3_colorDarkSeaGreen: c_int = 9419919;
pub const b3_colorDarkSlateBlue: c_int = 4734347;
pub const b3_colorDarkSlateGray: c_int = 3100495;
pub const b3_colorDarkTurquoise: c_int = 52945;
pub const b3_colorDarkViolet: c_int = 9699539;
pub const b3_colorDeepPink: c_int = 16716947;
pub const b3_colorDeepSkyBlue: c_int = 49151;
pub const b3_colorDimGray: c_int = 6908265;
pub const b3_colorDodgerBlue: c_int = 2003199;
pub const b3_colorFireBrick: c_int = 11674146;
pub const b3_colorFloralWhite: c_int = 16775920;
pub const b3_colorForestGreen: c_int = 2263842;
pub const b3_colorFuchsia: c_int = 16711935;
pub const b3_colorGainsboro: c_int = 14474460;
pub const b3_colorGhostWhite: c_int = 16316671;
pub const b3_colorGold: c_int = 16766720;
pub const b3_colorGoldenRod: c_int = 14329120;
pub const b3_colorGray: c_int = 8421504;
pub const b3_colorGreen: c_int = 32768;
pub const b3_colorGreenYellow: c_int = 11403055;
pub const b3_colorHoneyDew: c_int = 15794160;
pub const b3_colorHotPink: c_int = 16738740;
pub const b3_colorIndianRed: c_int = 13458524;
pub const b3_colorIndigo: c_int = 4915330;
pub const b3_colorIvory: c_int = 16777200;
pub const b3_colorKhaki: c_int = 15787660;
pub const b3_colorLavender: c_int = 15132410;
pub const b3_colorLavenderBlush: c_int = 16773365;
pub const b3_colorLawnGreen: c_int = 8190976;
pub const b3_colorLemonChiffon: c_int = 16775885;
pub const b3_colorLightBlue: c_int = 11393254;
pub const b3_colorLightCoral: c_int = 15761536;
pub const b3_colorLightCyan: c_int = 14745599;
pub const b3_colorLightGoldenRodYellow: c_int = 16448210;
pub const b3_colorLightGray: c_int = 13882323;
pub const b3_colorLightGreen: c_int = 9498256;
pub const b3_colorLightPink: c_int = 16758465;
pub const b3_colorLightSalmon: c_int = 16752762;
pub const b3_colorLightSeaGreen: c_int = 2142890;
pub const b3_colorLightSkyBlue: c_int = 8900346;
pub const b3_colorLightSlateGray: c_int = 7833753;
pub const b3_colorLightSteelBlue: c_int = 11584734;
pub const b3_colorLightYellow: c_int = 16777184;
pub const b3_colorLime: c_int = 65280;
pub const b3_colorLimeGreen: c_int = 3329330;
pub const b3_colorLinen: c_int = 16445670;
pub const b3_colorMagenta: c_int = 16711935;
pub const b3_colorMaroon: c_int = 8388608;
pub const b3_colorMediumAquaMarine: c_int = 6737322;
pub const b3_colorMediumBlue: c_int = 205;
pub const b3_colorMediumOrchid: c_int = 12211667;
pub const b3_colorMediumPurple: c_int = 9662683;
pub const b3_colorMediumSeaGreen: c_int = 3978097;
pub const b3_colorMediumSlateBlue: c_int = 8087790;
pub const b3_colorMediumSpringGreen: c_int = 64154;
pub const b3_colorMediumTurquoise: c_int = 4772300;
pub const b3_colorMediumVioletRed: c_int = 13047173;
pub const b3_colorMidnightBlue: c_int = 1644912;
pub const b3_colorMintCream: c_int = 16121850;
pub const b3_colorMistyRose: c_int = 16770273;
pub const b3_colorMoccasin: c_int = 16770229;
pub const b3_colorNavajoWhite: c_int = 16768685;
pub const b3_colorNavy: c_int = 128;
pub const b3_colorOldLace: c_int = 16643558;
pub const b3_colorOlive: c_int = 8421376;
pub const b3_colorOliveDrab: c_int = 7048739;
pub const b3_colorOrange: c_int = 16753920;
pub const b3_colorOrangeRed: c_int = 16729344;
pub const b3_colorOrchid: c_int = 14315734;
pub const b3_colorPaleGoldenRod: c_int = 15657130;
pub const b3_colorPaleGreen: c_int = 10025880;
pub const b3_colorPaleTurquoise: c_int = 11529966;
pub const b3_colorPaleVioletRed: c_int = 14381203;
pub const b3_colorPapayaWhip: c_int = 16773077;
pub const b3_colorPeachPuff: c_int = 16767673;
pub const b3_colorPeru: c_int = 13468991;
pub const b3_colorPink: c_int = 16761035;
pub const b3_colorPlum: c_int = 14524637;
pub const b3_colorPowderBlue: c_int = 11591910;
pub const b3_colorPurple: c_int = 8388736;
pub const b3_colorRebeccaPurple: c_int = 6697881;
pub const b3_colorRed: c_int = 16711680;
pub const b3_colorRosyBrown: c_int = 12357519;
pub const b3_colorRoyalBlue: c_int = 4286945;
pub const b3_colorSaddleBrown: c_int = 9127187;
pub const b3_colorSalmon: c_int = 16416882;
pub const b3_colorSandyBrown: c_int = 16032864;
pub const b3_colorSeaGreen: c_int = 3050327;
pub const b3_colorSeaShell: c_int = 16774638;
pub const b3_colorSienna: c_int = 10506797;
pub const b3_colorSilver: c_int = 12632256;
pub const b3_colorSkyBlue: c_int = 8900331;
pub const b3_colorSlateBlue: c_int = 6970061;
pub const b3_colorSlateGray: c_int = 7372944;
pub const b3_colorSnow: c_int = 16775930;
pub const b3_colorSpringGreen: c_int = 65407;
pub const b3_colorSteelBlue: c_int = 4620980;
pub const b3_colorTan: c_int = 13808780;
pub const b3_colorTeal: c_int = 32896;
pub const b3_colorThistle: c_int = 14204888;
pub const b3_colorTomato: c_int = 16737095;
pub const b3_colorTurquoise: c_int = 4251856;
pub const b3_colorViolet: c_int = 15631086;
pub const b3_colorWheat: c_int = 16113331;
pub const b3_colorWhite: c_int = 16777215;
pub const b3_colorWhiteSmoke: c_int = 16119285;
pub const b3_colorYellow: c_int = 16776960;
pub const b3_colorYellowGreen: c_int = 10145074;
pub const b3_colorBox2DRed: c_int = 14430514;
pub const b3_colorBox2DBlue: c_int = 3190463;
pub const b3_colorBox2DGreen: c_int = 9226532;
pub const b3_colorBox2DYellow: c_int = 16772748;
pub const enum_b3HexColor = c_uint;
pub const b3HexColor = enum_b3HexColor;
pub const b3_debugMaterialDefault: c_int = 0;
pub const b3_debugMaterialMatte: c_int = 1;
pub const b3_debugMaterialSoft: c_int = 2;
pub const b3_debugMaterialDead: c_int = 3;
pub const b3_debugMaterialGlossy: c_int = 4;
pub const b3_debugMaterialMetallic: c_int = 5;
pub const enum_b3DebugMaterial = c_uint;
pub const b3DebugMaterial = enum_b3DebugMaterial;
pub fn b3MakeDebugColor(arg_rgb: b3HexColor, arg_material: b3DebugMaterial) callconv(.c) u32 {
    var rgb = arg_rgb;
    _ = &rgb;
    var material = arg_material;
    _ = &material;
    return (rgb & @as(c_uint, 16777215)) | (material << @intCast(@as(u32, 24)));
}
pub extern fn b3GetGraphColor(index: c_int) b3HexColor;
pub const struct_b3DebugDraw = extern struct {
    DrawShapeFcn: ?*const fn (userShape: ?*anyopaque, transform: b3WorldTransform, color: b3HexColor, context: ?*anyopaque) callconv(.c) bool,
    DrawSegmentFcn: ?*const fn (p1: b3Pos, p2: b3Pos, color: b3HexColor, context: ?*anyopaque) callconv(.c) void,
    DrawTransformFcn: ?*const fn (transform: b3WorldTransform, context: ?*anyopaque) callconv(.c) void,
    DrawPointFcn: ?*const fn (p: b3Pos, size: f32, color: b3HexColor, context: ?*anyopaque) callconv(.c) void,
    DrawSphereFcn: ?*const fn (p: b3Pos, radius: f32, color: b3HexColor, alpha: f32, context: ?*anyopaque) callconv(.c) void,
    DrawCapsuleFcn: ?*const fn (p1: b3Pos, p2: b3Pos, radius: f32, color: b3HexColor, alpha: f32, context: ?*anyopaque) callconv(.c) void,
    DrawBoundsFcn: ?*const fn (aabb: b3AABB, color: b3HexColor, context: ?*anyopaque) callconv(.c) void,
    DrawBoxFcn: ?*const fn (extents: b3Vec3, transform: b3WorldTransform, color: b3HexColor, context: ?*anyopaque) callconv(.c) void,
    DrawStringFcn: ?*const fn (p: b3Pos, s: [*c]const u8, color: b3HexColor, context: ?*anyopaque) callconv(.c) void,
    drawingBounds: b3AABB,
    forceScale: f32,
    jointScale: f32,
    drawShapes: bool,
    drawJoints: bool,
    drawJointExtras: bool,
    drawBounds: bool,
    drawMass: bool,
    drawBodyNames: bool,
    drawContacts: bool,
    drawAnchorA: c_int,
    drawGraphColors: bool,
    drawContactFeatures: bool,
    drawContactNormals: bool,
    drawContactForces: bool,
    drawFrictionForces: bool,
    drawIslands: bool,
    context: ?*anyopaque,
};
pub const b3DebugDraw = struct_b3DebugDraw;
pub extern fn b3DefaultDebugDraw() b3DebugDraw;
pub const ptrdiff_t = c_long;
pub const wchar_t = c_int;
pub const max_align_t = extern struct {
    __aro_max_align_ll: c_longlong,
    __aro_max_align_ld: c_longdouble,
};
pub extern fn b3DynamicTree_Create(proxyCapacity: c_int) b3DynamicTree;
pub extern fn b3DynamicTree_Destroy(tree: [*c]b3DynamicTree) void;
pub extern fn b3DynamicTree_CreateProxy(tree: [*c]b3DynamicTree, aabb: b3AABB, categoryBits: u64, userData: u64) c_int;
pub extern fn b3DynamicTree_DestroyProxy(tree: [*c]b3DynamicTree, proxyId: c_int) void;
pub extern fn b3DynamicTree_MoveProxy(tree: [*c]b3DynamicTree, proxyId: c_int, aabb: b3AABB) void;
pub extern fn b3DynamicTree_EnlargeProxy(tree: [*c]b3DynamicTree, proxyId: c_int, aabb: b3AABB) void;
pub extern fn b3DynamicTree_SetCategoryBits(tree: [*c]b3DynamicTree, proxyId: c_int, categoryBits: u64) void;
pub extern fn b3DynamicTree_GetCategoryBits(tree: [*c]b3DynamicTree, proxyId: c_int) u64;
pub extern fn b3DynamicTree_Query(tree: [*c]const b3DynamicTree, aabb: b3AABB, maskBits: u64, requireAllBits: bool, callback: ?*const b3TreeQueryCallbackFcn, context: ?*anyopaque) b3TreeStats;
pub extern fn b3DynamicTree_QueryClosest(tree: [*c]const b3DynamicTree, point: b3Vec3, maskBits: u64, requireAllBits: bool, callback: ?*const b3TreeQueryClosestCallbackFcn, context: ?*anyopaque, minDistanceSqr: [*c]f32) b3TreeStats;
pub extern fn b3DynamicTree_RayCast(tree: [*c]const b3DynamicTree, input: [*c]const b3RayCastInput, maskBits: u64, requireAllBits: bool, callback: ?*const b3TreeRayCastCallbackFcn, context: ?*anyopaque) b3TreeStats;
pub extern fn b3DynamicTree_BoxCast(tree: [*c]const b3DynamicTree, input: [*c]const b3BoxCastInput, maskBits: u64, requireAllBits: bool, callback: ?*const b3TreeBoxCastCallbackFcn, context: ?*anyopaque) b3TreeStats;
pub extern fn b3DynamicTree_Validate(tree: [*c]const b3DynamicTree) void;
pub extern fn b3DynamicTree_GetHeight(tree: [*c]const b3DynamicTree) c_int;
pub extern fn b3DynamicTree_GetAreaRatio(tree: [*c]const b3DynamicTree) f32;
pub extern fn b3DynamicTree_GetRootBounds(tree: [*c]const b3DynamicTree) b3AABB;
pub extern fn b3DynamicTree_GetProxyCount(tree: [*c]const b3DynamicTree) c_int;
pub extern fn b3DynamicTree_Rebuild(tree: [*c]b3DynamicTree, fullBuild: bool) c_int;
pub extern fn b3DynamicTree_GetByteCount(tree: [*c]const b3DynamicTree) c_int;
pub extern fn b3DynamicTree_ValidateNoEnlarged(tree: [*c]const b3DynamicTree) void;
pub extern fn b3DynamicTree_Save(tree: [*c]const b3DynamicTree, fileName: [*c]const u8) void;
pub extern fn b3DynamicTree_Load(fileName: [*c]const u8, scale: f32) b3DynamicTree;
pub fn b3DynamicTree_GetUserData(arg_tree: [*c]const b3DynamicTree, arg_proxyId: c_int) callconv(.c) u64 {
    var tree = arg_tree;
    _ = &tree;
    var proxyId = arg_proxyId;
    _ = &proxyId;
    return tree.*.nodes[@bitCast(@as(isize, @intCast(proxyId)))].unnamed_0.userData;
}
pub fn b3DynamicTree_GetAABB(arg_tree: [*c]const b3DynamicTree, arg_proxyId: c_int) callconv(.c) b3AABB {
    var tree = arg_tree;
    _ = &tree;
    var proxyId = arg_proxyId;
    _ = &proxyId;
    return tree.*.nodes[@bitCast(@as(isize, @intCast(proxyId)))].aabb;
}
pub fn b3GetHullVertices(arg_hull: [*c]const b3HullData) callconv(.c) [*c]const b3HullVertex {
    var hull = arg_hull;
    _ = &hull;
    if (hull.*.vertexOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(hull))) + @as(isize, hull.*.vertexOffset))));
}
pub fn b3GetHullPoints(arg_hull: [*c]const b3HullData) callconv(.c) [*c]const b3Vec3 {
    var hull = arg_hull;
    _ = &hull;
    if (hull.*.pointOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(hull))) + @as(isize, hull.*.pointOffset))));
}
pub fn b3GetHullEdges(arg_hull: [*c]const b3HullData) callconv(.c) [*c]const b3HullHalfEdge {
    var hull = arg_hull;
    _ = &hull;
    if (hull.*.edgeOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(hull))) + @as(isize, hull.*.edgeOffset))));
}
pub fn b3GetHullFaces(arg_hull: [*c]const b3HullData) callconv(.c) [*c]const b3HullFace {
    var hull = arg_hull;
    _ = &hull;
    if (hull.*.faceOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(hull))) + @as(isize, hull.*.faceOffset))));
}
pub fn b3GetHullPlanes(arg_hull: [*c]const b3HullData) callconv(.c) [*c]const b3Plane {
    var hull = arg_hull;
    _ = &hull;
    if (hull.*.planeOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(hull))) + @as(isize, hull.*.planeOffset))));
}
pub extern fn b3CreateCylinder(height: f32, radius: f32, yOffset: f32, sides: c_int) [*c]b3HullData;
pub extern fn b3CreateCone(height: f32, radius1: f32, radius2: f32, slices: c_int) [*c]b3HullData;
pub extern fn b3CreateRock(radius: f32) [*c]b3HullData;
pub extern fn b3CreateHull(points: [*c]const b3Vec3, pointCount: c_int, maxVertexCount: c_int) [*c]b3HullData;
pub extern fn b3CloneHull(hull: [*c]const b3HullData) [*c]b3HullData;
pub extern fn b3CloneAndTransformHull(original: [*c]const b3HullData, transform: b3Transform, scale: b3Vec3) [*c]b3HullData;
pub extern fn b3DestroyHull(hull: [*c]b3HullData) void;
pub extern fn b3MakeCubeHull(halfWidth: f32) b3BoxHull;
pub extern fn b3MakeBoxHull(hx: f32, hy: f32, hz: f32) b3BoxHull;
pub extern fn b3MakeOffsetBoxHull(hx: f32, hy: f32, hz: f32, offset: b3Vec3) b3BoxHull;
pub extern fn b3MakeTransformedBoxHull(hx: f32, hy: f32, hz: f32, transform: b3Transform) b3BoxHull;
pub extern fn b3MakeScaledBoxHull(halfWidths: b3Vec3, transform: b3Transform, postScale: b3Vec3) b3BoxHull;
pub extern fn b3ScaleBox(halfWidths: [*c]b3Vec3, transform: [*c]b3Transform, postScale: b3Vec3, minHalfWidth: f32) void;
pub fn b3GetMeshNodes(arg_mesh: [*c]const b3MeshData) callconv(.c) ?*const b3MeshNode {
    var mesh = arg_mesh;
    _ = &mesh;
    if (mesh.*.nodeOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(mesh))) + @as(isize, mesh.*.nodeOffset))));
}
pub fn b3GetMeshVertices(arg_mesh: [*c]const b3MeshData) callconv(.c) [*c]const b3Vec3 {
    var mesh = arg_mesh;
    _ = &mesh;
    if (mesh.*.vertexOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(mesh))) + @as(isize, mesh.*.vertexOffset))));
}
pub fn b3GetMeshTriangles(arg_mesh: [*c]const b3MeshData) callconv(.c) [*c]const b3MeshTriangle {
    var mesh = arg_mesh;
    _ = &mesh;
    if (mesh.*.triangleOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(mesh))) + @as(isize, mesh.*.triangleOffset))));
}
pub fn b3GetMeshMaterialIndices(arg_mesh: [*c]const b3MeshData) callconv(.c) [*c]const u8 {
    var mesh = arg_mesh;
    _ = &mesh;
    if (mesh.*.materialOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(mesh))) + @as(isize, mesh.*.materialOffset))));
}
pub fn b3GetMeshFlags(arg_mesh: [*c]const b3MeshData) callconv(.c) [*c]const u8 {
    var mesh = arg_mesh;
    _ = &mesh;
    if (mesh.*.flagsOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(mesh))) + @as(isize, mesh.*.flagsOffset))));
}
pub extern fn b3CreateGridMesh(xCount: c_int, zCount: c_int, cellWidth: f32, materialCount: c_int, identifyEdges: bool) [*c]b3MeshData;
pub extern fn b3CreateWaveMesh(xCount: c_int, zCount: c_int, cellWidth: f32, amplitude: f32, rowFrequency: f32, columnFrequency: f32) [*c]b3MeshData;
pub extern fn b3CreateTorusMesh(radialResolution: c_int, tubularResolution: c_int, radius: f32, thickness: f32) [*c]b3MeshData;
pub extern fn b3CreateBoxMesh(center: b3Vec3, extent: b3Vec3, identifyEdges: bool) [*c]b3MeshData;
pub extern fn b3CreateHollowBoxMesh(center: b3Vec3, extent: b3Vec3) [*c]b3MeshData;
pub extern fn b3CreatePlatformMesh(center: b3Vec3, height: f32, topWidth: f32, bottomWidth: f32) [*c]b3MeshData;
pub extern fn b3CreateMesh(def: [*c]const b3MeshDef, degenerateTriangleIndices: [*c]c_int, degenerateCapacity: c_int) [*c]b3MeshData;
pub extern fn b3DestroyMesh(mesh: [*c]b3MeshData) void;
pub extern fn b3GetHeight(mesh: [*c]const b3MeshData) c_int;
pub fn b3GetHeightFieldCompressedHeights(arg_hf: [*c]const b3HeightFieldData) callconv(.c) [*c]const u16 {
    var hf = arg_hf;
    _ = &hf;
    if (hf.*.heightsOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(hf))) + @as(isize, hf.*.heightsOffset))));
}
pub fn b3GetHeightFieldMaterialIndices(arg_hf: [*c]const b3HeightFieldData) callconv(.c) [*c]const u8 {
    var hf = arg_hf;
    _ = &hf;
    if (hf.*.materialOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(hf))) + @as(isize, hf.*.materialOffset))));
}
pub fn b3GetHeightFieldFlags(arg_hf: [*c]const b3HeightFieldData) callconv(.c) [*c]const u8 {
    var hf = arg_hf;
    _ = &hf;
    if (hf.*.flagsOffset == @as(c_int, 0)) {
        return null;
    }
    return @ptrFromInt(@as(usize, @intCast(@as(isize, @intCast(@intFromPtr(hf))) + @as(isize, hf.*.flagsOffset))));
}
pub extern fn b3CreateHeightField(data: [*c]const b3HeightFieldDef) [*c]b3HeightFieldData;
pub extern fn b3CreateGrid(rowCount: c_int, columnCount: c_int, scale: b3Vec3, makeHoles: bool) [*c]b3HeightFieldData;
pub extern fn b3CreateWave(rowCount: c_int, columnCount: c_int, scale: b3Vec3, rowFrequency: f32, columnFrequency: f32, makeHoles: bool) [*c]b3HeightFieldData;
pub extern fn b3DestroyHeightField(heightField: [*c]b3HeightFieldData) void;
pub extern fn b3DumpHeightData(data: [*c]const b3HeightFieldDef, fileName: [*c]const u8) void;
pub extern fn b3LoadHeightField(fileName: [*c]const u8) [*c]b3HeightFieldData;
pub extern fn b3GetCompoundChild(compound: [*c]const b3CompoundData, childIndex: c_int) b3ChildShape;
pub extern fn b3QueryCompound(compound: [*c]const b3CompoundData, aabb: b3AABB, fcn: ?*const b3CompoundQueryFcn, context: ?*anyopaque) void;
pub extern fn b3GetCompoundCapsule(compound: [*c]const b3CompoundData, index: c_int) b3CompoundCapsule;
pub extern fn b3GetCompoundHull(compound: [*c]const b3CompoundData, index: c_int) b3CompoundHull;
pub extern fn b3GetCompoundMesh(compound: [*c]const b3CompoundData, index: c_int) b3CompoundMesh;
pub extern fn b3GetCompoundSphere(compound: [*c]const b3CompoundData, index: c_int) b3CompoundSphere;
pub extern fn b3GetCompoundMaterials(compound: [*c]const b3CompoundData) [*c]const b3SurfaceMaterial;
pub extern fn b3CreateCompound(def: [*c]const b3CompoundDef) [*c]b3CompoundData;
pub extern fn b3DestroyCompound(compound: [*c]b3CompoundData) void;
pub extern fn b3ConvertCompoundToBytes(compound: [*c]b3CompoundData) [*c]u8;
pub extern fn b3ConvertBytesToCompound(bytes: [*c]u8, byteCount: c_int) [*c]b3CompoundData;
pub extern fn b3ComputeSphereMass(shape: [*c]const b3Sphere, density: f32) b3MassData;
pub extern fn b3ComputeCapsuleMass(shape: [*c]const b3Capsule, density: f32) b3MassData;
pub extern fn b3ComputeHullMass(shape: [*c]const b3HullData, density: f32) b3MassData;
pub extern fn b3ComputeSphereAABB(shape: [*c]const b3Sphere, transform: b3Transform) b3AABB;
pub extern fn b3ComputeCapsuleAABB(shape: [*c]const b3Capsule, transform: b3Transform) b3AABB;
pub extern fn b3ComputeHullAABB(shape: [*c]const b3HullData, transform: b3Transform) b3AABB;
pub extern fn b3ComputeMeshAABB(shape: [*c]const b3MeshData, transform: b3Transform, scale: b3Vec3) b3AABB;
pub extern fn b3ComputeHeightFieldAABB(shape: [*c]const b3HeightFieldData, transform: b3Transform) b3AABB;
pub extern fn b3ComputeCompoundAABB(shape: [*c]const b3CompoundData, transform: b3Transform) b3AABB;
pub extern fn b3IsValidRay(input: [*c]const b3RayCastInput) bool;
pub extern fn b3OverlapCapsule(shape: [*c]const b3Capsule, shapeTransform: b3Transform, proxy: [*c]const b3ShapeProxy) bool;
pub extern fn b3OverlapCompound(shape: [*c]const b3CompoundData, shapeTransform: b3Transform, proxy: [*c]const b3ShapeProxy) bool;
pub extern fn b3OverlapHeightField(shape: [*c]const b3HeightFieldData, shapeTransform: b3Transform, proxy: [*c]const b3ShapeProxy) bool;
pub extern fn b3OverlapHull(shape: [*c]const b3HullData, shapeTransform: b3Transform, proxy: [*c]const b3ShapeProxy) bool;
pub extern fn b3OverlapMesh(shape: [*c]const b3Mesh, shapeTransform: b3Transform, proxy: [*c]const b3ShapeProxy) bool;
pub extern fn b3OverlapSphere(shape: [*c]const b3Sphere, shapeTransform: b3Transform, proxy: [*c]const b3ShapeProxy) bool;
pub extern fn b3RayCastSphere(shape: [*c]const b3Sphere, input: [*c]const b3RayCastInput) b3CastOutput;
pub extern fn b3RayCastHollowSphere(shape: [*c]const b3Sphere, input: [*c]const b3RayCastInput) b3CastOutput;
pub extern fn b3RayCastCapsule(shape: [*c]const b3Capsule, input: [*c]const b3RayCastInput) b3CastOutput;
pub extern fn b3RayCastCompound(shape: [*c]const b3CompoundData, input: [*c]const b3RayCastInput) b3CastOutput;
pub extern fn b3RayCastHull(shape: [*c]const b3HullData, input: [*c]const b3RayCastInput) b3CastOutput;
pub extern fn b3RayCastMesh(shape: [*c]const b3Mesh, input: [*c]const b3RayCastInput) b3CastOutput;
pub extern fn b3RayCastHeightField(shape: [*c]const b3HeightFieldData, input: [*c]const b3RayCastInput) b3CastOutput;
pub extern fn b3ShapeCastSphere(shape: [*c]const b3Sphere, input: [*c]const b3ShapeCastInput) b3CastOutput;
pub extern fn b3ShapeCastCapsule(shape: [*c]const b3Capsule, input: [*c]const b3ShapeCastInput) b3CastOutput;
pub extern fn b3ShapeCastCompound(shape: [*c]const b3CompoundData, input: [*c]const b3ShapeCastInput) b3CastOutput;
pub extern fn b3ShapeCastHull(shape: [*c]const b3HullData, input: [*c]const b3ShapeCastInput) b3CastOutput;
pub extern fn b3ShapeCastMesh(shape: [*c]const b3Mesh, input: [*c]const b3ShapeCastInput) b3CastOutput;
pub extern fn b3ShapeCastHeightField(shape: [*c]const b3HeightFieldData, input: [*c]const b3ShapeCastInput) b3CastOutput;
pub const b3MeshQueryFcn = fn (a: b3Vec3, b: b3Vec3, c: b3Vec3, triangleIndex: c_int, context: ?*anyopaque) callconv(.c) bool;
pub extern fn b3QueryMesh(mesh: [*c]const b3Mesh, bounds: b3AABB, fcn: ?*const b3MeshQueryFcn, context: ?*anyopaque) void;
pub extern fn b3QueryHeightField(heightField: [*c]const b3HeightFieldData, bounds: b3AABB, fcn: ?*const b3MeshQueryFcn, context: ?*anyopaque) void;
pub extern fn b3ShapeDistance(input: [*c]const b3DistanceInput, cache: [*c]b3SimplexCache, simplexes: [*c]b3Simplex, simplexCapacity: c_int) b3DistanceOutput;
pub extern fn b3ShapeCast(input: [*c]const b3ShapeCastPairInput) b3CastOutput;
pub extern fn b3GetSweepTransform(sweep: [*c]const b3Sweep, time: f32) b3Transform;
pub extern fn b3TimeOfImpact(input: [*c]const b3TOIInput) b3TOIOutput;
pub extern fn b3CollideSpheres(manifold: [*c]b3LocalManifold, capacity: c_int, sphereA: [*c]const b3Sphere, sphereB: [*c]const b3Sphere, transformBtoA: b3Transform) void;
pub extern fn b3CollideCapsuleAndSphere(manifold: [*c]b3LocalManifold, capacity: c_int, capsuleA: [*c]const b3Capsule, sphereB: [*c]const b3Sphere, transformBtoA: b3Transform) void;
pub extern fn b3CollideHullAndSphere(manifold: [*c]b3LocalManifold, capacity: c_int, hullA: [*c]const b3HullData, sphereB: [*c]const b3Sphere, transformBtoA: b3Transform, cache: [*c]b3SimplexCache) void;
pub extern fn b3CollideCapsules(manifold: [*c]b3LocalManifold, capacity: c_int, capsuleA: [*c]const b3Capsule, capsuleB: [*c]const b3Capsule, transformBtoA: b3Transform) void;
pub extern fn b3CollideHullAndCapsule(manifold: [*c]b3LocalManifold, capacity: c_int, hullA: [*c]const b3HullData, capsuleB: [*c]const b3Capsule, transformBtoA: b3Transform, cache: [*c]b3SimplexCache) void;
pub extern fn b3CollideHulls(manifold: [*c]b3LocalManifold, capacity: c_int, hullA: [*c]const b3HullData, hullB: [*c]const b3HullData, transformBtoA: b3Transform, cache: [*c]b3SATCache) void;
pub extern fn b3CollideCapsuleAndTriangle(manifold: [*c]b3LocalManifold, capacity: c_int, capsuleA: [*c]const b3Capsule, triangleB: [*c]const b3Vec3, cache: [*c]b3SimplexCache) void;
pub extern fn b3CollideHullAndTriangle(manifold: [*c]b3LocalManifold, capacity: c_int, hullA: [*c]const b3HullData, v1: b3Vec3, v2: b3Vec3, v3: b3Vec3, triangleFlags: c_int, cache: [*c]b3SATCache) void;
pub extern fn b3CollideSphereAndTriangle(manifold: [*c]b3LocalManifold, capacity: c_int, sphereA: [*c]const b3Sphere, triangleB: [*c]const b3Vec3) void;
pub extern fn b3SolvePlanes(targetDelta: b3Vec3, planes: [*c]b3CollisionPlane, count: c_int) b3PlaneSolverResult;
pub extern fn b3ClipVector(vector: b3Vec3, planes: [*c]const b3CollisionPlane, count: c_int) b3Vec3;
pub extern fn b3CreateWorld(def: [*c]const b3WorldDef) b3WorldId;
pub extern fn b3DestroyWorld(worldId: b3WorldId) void;
pub extern fn b3GetWorldCount() c_int;
pub extern fn b3GetMaxWorldCount() c_int;
pub extern fn b3World_IsValid(id: b3WorldId) bool;
pub extern fn b3World_Step(worldId: b3WorldId, timeStep: f32, subStepCount: c_int) void;
pub extern fn b3World_Draw(worldId: b3WorldId, draw: [*c]b3DebugDraw, maskBits: u64) void;
pub extern fn b3World_GetBounds(worldId: b3WorldId) b3AABB;
pub extern fn b3World_GetBodyEvents(worldId: b3WorldId) b3BodyEvents;
pub extern fn b3World_GetSensorEvents(worldId: b3WorldId) b3SensorEvents;
pub extern fn b3World_GetContactEvents(worldId: b3WorldId) b3ContactEvents;
pub extern fn b3World_GetJointEvents(worldId: b3WorldId) b3JointEvents;
pub extern fn b3World_OverlapAABB(worldId: b3WorldId, aabb: b3AABB, filter: b3QueryFilter, fcn: ?*const b3OverlapResultFcn, context: ?*anyopaque) b3TreeStats;
pub extern fn b3World_OverlapShape(worldId: b3WorldId, origin: b3Pos, proxy: [*c]const b3ShapeProxy, filter: b3QueryFilter, fcn: ?*const b3OverlapResultFcn, context: ?*anyopaque) b3TreeStats;
pub extern fn b3World_CastRay(worldId: b3WorldId, origin: b3Pos, translation: b3Vec3, filter: b3QueryFilter, fcn: ?*const b3CastResultFcn, context: ?*anyopaque) b3TreeStats;
pub extern fn b3World_CastRayClosest(worldId: b3WorldId, origin: b3Pos, translation: b3Vec3, filter: b3QueryFilter) b3RayResult;
pub extern fn b3World_CastShape(worldId: b3WorldId, origin: b3Pos, proxy: [*c]const b3ShapeProxy, translation: b3Vec3, filter: b3QueryFilter, fcn: ?*const b3CastResultFcn, context: ?*anyopaque) b3TreeStats;
pub extern fn b3World_CastMover(worldId: b3WorldId, origin: b3Pos, mover: [*c]const b3Capsule, translation: b3Vec3, filter: b3QueryFilter, fcn: ?*const b3MoverFilterFcn, context: ?*anyopaque) f32;
pub extern fn b3World_CollideMover(worldId: b3WorldId, origin: b3Pos, mover: [*c]const b3Capsule, filter: b3QueryFilter, fcn: ?*const b3PlaneResultFcn, context: ?*anyopaque) void;
pub extern fn b3World_EnableSleeping(worldId: b3WorldId, flag: bool) void;
pub extern fn b3World_IsSleepingEnabled(worldId: b3WorldId) bool;
pub extern fn b3World_EnableContinuous(worldId: b3WorldId, flag: bool) void;
pub extern fn b3World_IsContinuousEnabled(worldId: b3WorldId) bool;
pub extern fn b3World_SetRestitutionThreshold(worldId: b3WorldId, value: f32) void;
pub extern fn b3World_GetRestitutionThreshold(worldId: b3WorldId) f32;
pub extern fn b3World_SetHitEventThreshold(worldId: b3WorldId, value: f32) void;
pub extern fn b3World_GetHitEventThreshold(worldId: b3WorldId) f32;
pub extern fn b3World_SetCustomFilterCallback(worldId: b3WorldId, fcn: ?*const b3CustomFilterFcn, context: ?*anyopaque) void;
pub extern fn b3World_SetPreSolveCallback(worldId: b3WorldId, fcn: ?*const b3PreSolveFcn, context: ?*anyopaque) void;
pub extern fn b3World_SetGravity(worldId: b3WorldId, gravity: b3Vec3) void;
pub extern fn b3World_GetGravity(worldId: b3WorldId) b3Vec3;
pub extern fn b3World_Explode(worldId: b3WorldId, explosionDef: [*c]const b3ExplosionDef) void;
pub extern fn b3World_SetContactTuning(worldId: b3WorldId, hertz: f32, dampingRatio: f32, contactSpeed: f32) void;
pub extern fn b3World_SetContactRecycleDistance(worldId: b3WorldId, recycleDistance: f32) void;
pub extern fn b3World_GetContactRecycleDistance(worldId: b3WorldId) f32;
pub extern fn b3World_SetMaximumLinearSpeed(worldId: b3WorldId, maximumLinearSpeed: f32) void;
pub extern fn b3World_GetMaximumLinearSpeed(worldId: b3WorldId) f32;
pub extern fn b3World_EnableWarmStarting(worldId: b3WorldId, flag: bool) void;
pub extern fn b3World_IsWarmStartingEnabled(worldId: b3WorldId) bool;
pub extern fn b3World_GetAwakeBodyCount(worldId: b3WorldId) c_int;
pub extern fn b3World_GetProfile(worldId: b3WorldId) b3Profile;
pub extern fn b3World_GetCounters(worldId: b3WorldId) b3Counters;
pub extern fn b3World_GetMaxCapacity(worldId: b3WorldId) b3Capacity;
pub extern fn b3World_SetUserData(worldId: b3WorldId, userData: ?*anyopaque) void;
pub extern fn b3World_GetUserData(worldId: b3WorldId) ?*anyopaque;
pub extern fn b3World_SetFrictionCallback(worldId: b3WorldId, callback: ?*const b3FrictionCallback) void;
pub extern fn b3World_SetRestitutionCallback(worldId: b3WorldId, callback: ?*const b3RestitutionCallback) void;
pub extern fn b3World_SetWorkerCount(worldId: b3WorldId, count: c_int) void;
pub extern fn b3World_GetWorkerCount(worldId: b3WorldId) c_int;
pub extern fn b3World_DumpMemoryStats(worldId: b3WorldId) void;
pub extern fn b3World_DumpShapeBounds(worldId: b3WorldId, @"type": b3BodyType) void;
pub extern fn b3World_RebuildStaticTree(worldId: b3WorldId) void;
pub extern fn b3World_EnableSpeculative(worldId: b3WorldId, flag: bool) void;
pub extern fn b3World_DumpAwake(worldId: b3WorldId) void;
pub extern fn b3World_Dump(worldId: b3WorldId) void;
pub const struct_b3Recording = opaque {
    pub const b3DestroyRecording = __root.b3DestroyRecording;
    pub const b3Recording_GetData = __root.b3Recording_GetData;
    pub const b3Recording_GetSize = __root.b3Recording_GetSize;
    pub const b3SaveRecordingToFile = __root.b3SaveRecordingToFile;
    pub const GetData = __root.b3Recording_GetData;
    pub const GetSize = __root.b3Recording_GetSize;
};
pub const b3Recording = struct_b3Recording;
pub extern fn b3CreateRecording(byteCapacity: c_int) ?*b3Recording;
pub extern fn b3DestroyRecording(recording: ?*b3Recording) void;
pub extern fn b3Recording_GetData(recording: ?*const b3Recording) [*c]const u8;
pub extern fn b3Recording_GetSize(recording: ?*const b3Recording) c_int;
pub extern fn b3World_StartRecording(worldId: b3WorldId, recording: ?*b3Recording) void;
pub extern fn b3World_StopRecording(worldId: b3WorldId) void;
pub extern fn b3SaveRecordingToFile(recording: ?*const b3Recording, path: [*c]const u8) bool;
pub extern fn b3LoadRecordingFromFile(path: [*c]const u8) ?*b3Recording;
pub extern fn b3ValidateReplay(data: ?*const anyopaque, size: c_int, workerCount: c_int) bool;
pub const struct_b3RecPlayer = opaque {
    pub const b3RecPlayer_Destroy = __root.b3RecPlayer_Destroy;
    pub const b3RecPlayer_StepFrame = __root.b3RecPlayer_StepFrame;
    pub const b3RecPlayer_Restart = __root.b3RecPlayer_Restart;
    pub const b3RecPlayer_SeekFrame = __root.b3RecPlayer_SeekFrame;
    pub const b3RecPlayer_GetWorldId = __root.b3RecPlayer_GetWorldId;
    pub const b3RecPlayer_GetFrame = __root.b3RecPlayer_GetFrame;
    pub const b3RecPlayer_GetFrameCount = __root.b3RecPlayer_GetFrameCount;
    pub const b3RecPlayer_IsAtEnd = __root.b3RecPlayer_IsAtEnd;
    pub const b3RecPlayer_HasDiverged = __root.b3RecPlayer_HasDiverged;
    pub const b3RecPlayer_GetInfo = __root.b3RecPlayer_GetInfo;
    pub const b3RecPlayer_GetDivergeFrame = __root.b3RecPlayer_GetDivergeFrame;
    pub const b3RecPlayer_SetWorkerCount = __root.b3RecPlayer_SetWorkerCount;
    pub const b3RecPlayer_SetKeyframePolicy = __root.b3RecPlayer_SetKeyframePolicy;
    pub const b3RecPlayer_GetKeyframeBudget = __root.b3RecPlayer_GetKeyframeBudget;
    pub const b3RecPlayer_GetKeyframeMinInterval = __root.b3RecPlayer_GetKeyframeMinInterval;
    pub const b3RecPlayer_GetKeyframeInterval = __root.b3RecPlayer_GetKeyframeInterval;
    pub const b3RecPlayer_GetKeyframeBytes = __root.b3RecPlayer_GetKeyframeBytes;
    pub const b3RecPlayer_GetBodyCount = __root.b3RecPlayer_GetBodyCount;
    pub const b3RecPlayer_GetBodyId = __root.b3RecPlayer_GetBodyId;
    pub const b3RecPlayer_SetDebugShapeCallbacks = __root.b3RecPlayer_SetDebugShapeCallbacks;
    pub const b3RecPlayer_DrawFrameQueries = __root.b3RecPlayer_DrawFrameQueries;
    pub const b3RecPlayer_GetFrameQueryCount = __root.b3RecPlayer_GetFrameQueryCount;
    pub const b3RecPlayer_GetFrameQuery = __root.b3RecPlayer_GetFrameQuery;
    pub const b3RecPlayer_GetFrameQueryHit = __root.b3RecPlayer_GetFrameQueryHit;
    pub const Destroy = __root.b3RecPlayer_Destroy;
    pub const StepFrame = __root.b3RecPlayer_StepFrame;
    pub const Restart = __root.b3RecPlayer_Restart;
    pub const SeekFrame = __root.b3RecPlayer_SeekFrame;
    pub const GetWorldId = __root.b3RecPlayer_GetWorldId;
    pub const GetFrame = __root.b3RecPlayer_GetFrame;
    pub const GetFrameCount = __root.b3RecPlayer_GetFrameCount;
    pub const IsAtEnd = __root.b3RecPlayer_IsAtEnd;
    pub const HasDiverged = __root.b3RecPlayer_HasDiverged;
    pub const GetInfo = __root.b3RecPlayer_GetInfo;
    pub const GetDivergeFrame = __root.b3RecPlayer_GetDivergeFrame;
    pub const SetWorkerCount = __root.b3RecPlayer_SetWorkerCount;
    pub const SetKeyframePolicy = __root.b3RecPlayer_SetKeyframePolicy;
    pub const GetKeyframeBudget = __root.b3RecPlayer_GetKeyframeBudget;
    pub const GetKeyframeMinInterval = __root.b3RecPlayer_GetKeyframeMinInterval;
    pub const GetKeyframeInterval = __root.b3RecPlayer_GetKeyframeInterval;
    pub const GetKeyframeBytes = __root.b3RecPlayer_GetKeyframeBytes;
    pub const GetBodyCount = __root.b3RecPlayer_GetBodyCount;
    pub const GetBodyId = __root.b3RecPlayer_GetBodyId;
    pub const SetDebugShapeCallbacks = __root.b3RecPlayer_SetDebugShapeCallbacks;
    pub const DrawFrameQueries = __root.b3RecPlayer_DrawFrameQueries;
    pub const GetFrameQueryCount = __root.b3RecPlayer_GetFrameQueryCount;
    pub const GetFrameQuery = __root.b3RecPlayer_GetFrameQuery;
    pub const GetFrameQueryHit = __root.b3RecPlayer_GetFrameQueryHit;
};
pub const b3RecPlayer = struct_b3RecPlayer;
pub const struct_b3RecPlayerInfo = extern struct {
    frameCount: c_int,
    workerCount: c_int,
    timeStep: f32,
    subStepCount: c_int,
    lengthScale: f32,
    bounds: b3AABB,
};
pub const b3RecPlayerInfo = struct_b3RecPlayerInfo;
pub extern fn b3RecPlayer_Create(data: ?*const anyopaque, size: c_int, workerCount: c_int) ?*b3RecPlayer;
pub extern fn b3RecPlayer_Destroy(player: ?*b3RecPlayer) void;
pub extern fn b3RecPlayer_StepFrame(player: ?*b3RecPlayer) bool;
pub extern fn b3RecPlayer_Restart(player: ?*b3RecPlayer) void;
pub extern fn b3RecPlayer_SeekFrame(player: ?*b3RecPlayer, targetFrame: c_int) void;
pub extern fn b3RecPlayer_GetWorldId(player: ?*const b3RecPlayer) b3WorldId;
pub extern fn b3RecPlayer_GetFrame(player: ?*const b3RecPlayer) c_int;
pub extern fn b3RecPlayer_GetFrameCount(player: ?*const b3RecPlayer) c_int;
pub extern fn b3RecPlayer_IsAtEnd(player: ?*const b3RecPlayer) bool;
pub extern fn b3RecPlayer_HasDiverged(player: ?*const b3RecPlayer) bool;
pub extern fn b3RecPlayer_GetInfo(player: ?*const b3RecPlayer) b3RecPlayerInfo;
pub extern fn b3RecPlayer_GetDivergeFrame(player: ?*const b3RecPlayer) c_int;
pub extern fn b3RecPlayer_SetWorkerCount(player: ?*b3RecPlayer, count: c_int) void;
pub extern fn b3RecPlayer_SetKeyframePolicy(player: ?*b3RecPlayer, budgetBytes: usize, minIntervalFrames: c_int) void;
pub extern fn b3RecPlayer_GetKeyframeBudget(player: ?*const b3RecPlayer) usize;
pub extern fn b3RecPlayer_GetKeyframeMinInterval(player: ?*const b3RecPlayer) c_int;
pub extern fn b3RecPlayer_GetKeyframeInterval(player: ?*const b3RecPlayer) c_int;
pub extern fn b3RecPlayer_GetKeyframeBytes(player: ?*const b3RecPlayer) usize;
pub extern fn b3RecPlayer_GetBodyCount(player: ?*const b3RecPlayer) c_int;
pub extern fn b3RecPlayer_GetBodyId(player: ?*const b3RecPlayer, index: c_int) b3BodyId;
pub extern fn b3RecPlayer_SetDebugShapeCallbacks(player: ?*b3RecPlayer, createDebugShape: ?*const b3CreateDebugShapeCallback, destroyDebugShape: ?*const b3DestroyDebugShapeCallback, context: ?*anyopaque) void;
pub extern fn b3RecPlayer_DrawFrameQueries(player: ?*b3RecPlayer, draw: [*c]b3DebugDraw, queryIndex: c_int, selectedIndex: c_int) void;
pub const b3_recQueryOverlapAABB: c_int = 0;
pub const b3_recQueryOverlapShape: c_int = 1;
pub const b3_recQueryCastRay: c_int = 2;
pub const b3_recQueryCastShape: c_int = 3;
pub const b3_recQueryCastRayClosest: c_int = 4;
pub const b3_recQueryCastMover: c_int = 5;
pub const b3_recQueryCollideMover: c_int = 6;
pub const enum_b3RecQueryType = c_uint;
pub const b3RecQueryType = enum_b3RecQueryType;
pub const struct_b3RecQueryInfo = extern struct {
    type: b3RecQueryType,
    filter: b3QueryFilter,
    aabb: b3AABB,
    origin: b3Pos,
    translation: b3Vec3,
    hitCount: c_int,
    key: u64,
    id: u64,
    name: [*c]const u8,
};
pub const b3RecQueryInfo = struct_b3RecQueryInfo;
pub const struct_b3RecQueryHit = extern struct {
    shape: b3ShapeId,
    point: b3Pos,
    normal: b3Vec3,
    fraction: f32,
};
pub const b3RecQueryHit = struct_b3RecQueryHit;
pub extern fn b3RecPlayer_GetFrameQueryCount(player: ?*const b3RecPlayer) c_int;
pub extern fn b3RecPlayer_GetFrameQuery(player: ?*const b3RecPlayer, index: c_int) b3RecQueryInfo;
pub extern fn b3RecPlayer_GetFrameQueryHit(player: ?*const b3RecPlayer, queryIndex: c_int, hitIndex: c_int) b3RecQueryHit;
pub extern fn b3CreateBody(worldId: b3WorldId, def: [*c]const b3BodyDef) b3BodyId;
pub extern fn b3DestroyBody(bodyId: b3BodyId) void;
pub extern fn b3Body_IsValid(id: b3BodyId) bool;
pub extern fn b3Body_GetType(bodyId: b3BodyId) b3BodyType;
pub extern fn b3Body_SetType(bodyId: b3BodyId, @"type": b3BodyType) void;
pub extern fn b3Body_SetName(bodyId: b3BodyId, name: [*c]const u8) void;
pub extern fn b3Body_GetName(bodyId: b3BodyId) [*c]const u8;
pub extern fn b3Body_SetUserData(bodyId: b3BodyId, userData: ?*anyopaque) void;
pub extern fn b3Body_GetUserData(bodyId: b3BodyId) ?*anyopaque;
pub extern fn b3Body_GetPosition(bodyId: b3BodyId) b3Pos;
pub extern fn b3Body_GetRotation(bodyId: b3BodyId) b3Quat;
pub extern fn b3Body_GetTransform(bodyId: b3BodyId) b3WorldTransform;
pub extern fn b3Body_SetTransform(bodyId: b3BodyId, position: b3Pos, rotation: b3Quat) void;
pub extern fn b3Body_GetLocalPoint(bodyId: b3BodyId, worldPoint: b3Pos) b3Vec3;
pub extern fn b3Body_GetWorldPoint(bodyId: b3BodyId, localPoint: b3Vec3) b3Pos;
pub extern fn b3Body_GetLocalVector(bodyId: b3BodyId, worldVector: b3Vec3) b3Vec3;
pub extern fn b3Body_GetWorldVector(bodyId: b3BodyId, localVector: b3Vec3) b3Vec3;
pub extern fn b3Body_GetLinearVelocity(bodyId: b3BodyId) b3Vec3;
pub extern fn b3Body_GetAngularVelocity(bodyId: b3BodyId) b3Vec3;
pub extern fn b3Body_SetLinearVelocity(bodyId: b3BodyId, linearVelocity: b3Vec3) void;
pub extern fn b3Body_SetAngularVelocity(bodyId: b3BodyId, angularVelocity: b3Vec3) void;
pub extern fn b3Body_SetTargetTransform(bodyId: b3BodyId, target: b3WorldTransform, timeStep: f32, wake: bool) void;
pub extern fn b3Body_GetLocalPointVelocity(bodyId: b3BodyId, localPoint: b3Vec3) b3Vec3;
pub extern fn b3Body_GetWorldPointVelocity(bodyId: b3BodyId, worldPoint: b3Pos) b3Vec3;
pub extern fn b3Body_ApplyForce(bodyId: b3BodyId, force: b3Vec3, point: b3Pos, wake: bool) void;
pub extern fn b3Body_ApplyForceToCenter(bodyId: b3BodyId, force: b3Vec3, wake: bool) void;
pub extern fn b3Body_ApplyTorque(bodyId: b3BodyId, torque: b3Vec3, wake: bool) void;
pub extern fn b3Body_ApplyLinearImpulse(bodyId: b3BodyId, impulse: b3Vec3, point: b3Pos, wake: bool) void;
pub extern fn b3Body_ApplyLinearImpulseToCenter(bodyId: b3BodyId, impulse: b3Vec3, wake: bool) void;
pub extern fn b3Body_ApplyAngularImpulse(bodyId: b3BodyId, impulse: b3Vec3, wake: bool) void;
pub extern fn b3Body_GetMass(bodyId: b3BodyId) f32;
pub extern fn b3Body_GetLocalRotationalInertia(bodyId: b3BodyId) b3Matrix3;
pub extern fn b3Body_GetInverseMass(bodyId: b3BodyId) f32;
pub extern fn b3Body_GetWorldInverseRotationalInertia(bodyId: b3BodyId) b3Matrix3;
pub extern fn b3Body_GetLocalCenterOfMass(bodyId: b3BodyId) b3Vec3;
pub extern fn b3Body_GetWorldCenterOfMass(bodyId: b3BodyId) b3Pos;
pub extern fn b3Body_SetMassData(bodyId: b3BodyId, massData: b3MassData) void;
pub extern fn b3Body_GetMassData(bodyId: b3BodyId) b3MassData;
pub extern fn b3Body_ApplyMassFromShapes(bodyId: b3BodyId) void;
pub extern fn b3Body_SetLinearDamping(bodyId: b3BodyId, linearDamping: f32) void;
pub extern fn b3Body_GetLinearDamping(bodyId: b3BodyId) f32;
pub extern fn b3Body_SetAngularDamping(bodyId: b3BodyId, angularDamping: f32) void;
pub extern fn b3Body_GetAngularDamping(bodyId: b3BodyId) f32;
pub extern fn b3Body_SetGravityScale(bodyId: b3BodyId, gravityScale: f32) void;
pub extern fn b3Body_GetGravityScale(bodyId: b3BodyId) f32;
pub extern fn b3Body_IsAwake(bodyId: b3BodyId) bool;
pub extern fn b3Body_SetAwake(bodyId: b3BodyId, awake: bool) void;
pub extern fn b3Body_EnableSleep(bodyId: b3BodyId, enableSleep: bool) void;
pub extern fn b3Body_IsSleepEnabled(bodyId: b3BodyId) bool;
pub extern fn b3Body_SetSleepThreshold(bodyId: b3BodyId, sleepThreshold: f32) void;
pub extern fn b3Body_GetSleepThreshold(bodyId: b3BodyId) f32;
pub extern fn b3Body_IsEnabled(bodyId: b3BodyId) bool;
pub extern fn b3Body_Disable(bodyId: b3BodyId) void;
pub extern fn b3Body_Enable(bodyId: b3BodyId) void;
pub extern fn b3Body_SetMotionLocks(bodyId: b3BodyId, locks: b3MotionLocks) void;
pub extern fn b3Body_GetMotionLocks(bodyId: b3BodyId) b3MotionLocks;
pub extern fn b3Body_SetBullet(bodyId: b3BodyId, flag: bool) void;
pub extern fn b3Body_IsBullet(bodyId: b3BodyId) bool;
pub extern fn b3Body_EnableContactRecycling(bodyId: b3BodyId, flag: bool) void;
pub extern fn b3Body_IsContactRecyclingEnabled(bodyId: b3BodyId) bool;
pub extern fn b3Body_EnableHitEvents(bodyId: b3BodyId, enableHitEvents: bool) void;
pub extern fn b3Body_GetWorld(bodyId: b3BodyId) b3WorldId;
pub extern fn b3Body_GetShapeCount(bodyId: b3BodyId) c_int;
pub extern fn b3Body_GetShapes(bodyId: b3BodyId, shapeArray: [*c]b3ShapeId, capacity: c_int) c_int;
pub extern fn b3Body_GetJointCount(bodyId: b3BodyId) c_int;
pub extern fn b3Body_GetJoints(bodyId: b3BodyId, jointArray: [*c]b3JointId, capacity: c_int) c_int;
pub extern fn b3Body_GetContactCapacity(bodyId: b3BodyId) c_int;
pub extern fn b3Body_GetContactData(bodyId: b3BodyId, contactData: [*c]b3ContactData, capacity: c_int) c_int;
pub extern fn b3Body_ComputeAABB(bodyId: b3BodyId) b3AABB;
pub extern fn b3Body_GetClosestPoint(bodyId: b3BodyId, result: [*c]b3Vec3, target: b3Vec3) f32;
pub extern fn b3Body_CastRay(bodyId: b3BodyId, origin: b3Pos, translation: b3Vec3, filter: b3QueryFilter, maxFraction: f32, bodyTransform: b3WorldTransform) b3BodyCastResult;
pub extern fn b3Body_CastShape(bodyId: b3BodyId, origin: b3Pos, proxy: [*c]const b3ShapeProxy, translation: b3Vec3, filter: b3QueryFilter, maxFraction: f32, canEncroach: bool, bodyTransform: b3WorldTransform) b3BodyCastResult;
pub extern fn b3Body_OverlapShape(bodyId: b3BodyId, origin: b3Pos, proxy: [*c]const b3ShapeProxy, filter: b3QueryFilter, bodyTransform: b3WorldTransform) bool;
pub extern fn b3Body_CollideMover(bodyId: b3BodyId, bodyPlanes: [*c]b3BodyPlaneResult, planeCapacity: c_int, origin: b3Pos, mover: [*c]const b3Capsule, filter: b3QueryFilter, bodyTransform: b3WorldTransform) c_int;
pub extern fn b3CreateSphereShape(bodyId: b3BodyId, def: [*c]const b3ShapeDef, sphere: [*c]const b3Sphere) b3ShapeId;
pub extern fn b3CreateCapsuleShape(bodyId: b3BodyId, def: [*c]const b3ShapeDef, capsule: [*c]const b3Capsule) b3ShapeId;
pub extern fn b3CreateHullShape(bodyId: b3BodyId, def: [*c]const b3ShapeDef, hull: [*c]const b3HullData) b3ShapeId;
pub extern fn b3CreateTransformedHullShape(bodyId: b3BodyId, def: [*c]const b3ShapeDef, hull: [*c]const b3HullData, transform: b3Transform, scale: b3Vec3) b3ShapeId;
pub extern fn b3CreateMeshShape(bodyId: b3BodyId, def: [*c]const b3ShapeDef, mesh: [*c]const b3MeshData, scale: b3Vec3) b3ShapeId;
pub extern fn b3CreateHeightFieldShape(bodyId: b3BodyId, def: [*c]const b3ShapeDef, heightField: [*c]const b3HeightFieldData) b3ShapeId;
pub extern fn b3CreateCompoundShape(bodyId: b3BodyId, def: [*c]b3ShapeDef, compound: [*c]const b3CompoundData) b3ShapeId;
pub extern fn b3DestroyShape(shapeId: b3ShapeId, updateBodyMass: bool) void;
pub extern fn b3Shape_IsValid(id: b3ShapeId) bool;
pub extern fn b3Shape_GetType(shapeId: b3ShapeId) b3ShapeType;
pub extern fn b3Shape_GetBody(shapeId: b3ShapeId) b3BodyId;
pub extern fn b3Shape_GetWorld(shapeId: b3ShapeId) b3WorldId;
pub extern fn b3Shape_IsSensor(shapeId: b3ShapeId) bool;
pub extern fn b3Shape_SetUserData(shapeId: b3ShapeId, userData: ?*anyopaque) void;
pub extern fn b3Shape_GetUserData(shapeId: b3ShapeId) ?*anyopaque;
pub extern fn b3Shape_SetDensity(shapeId: b3ShapeId, density: f32, updateBodyMass: bool) void;
pub extern fn b3Shape_GetDensity(shapeId: b3ShapeId) f32;
pub extern fn b3Shape_SetFriction(shapeId: b3ShapeId, friction: f32) void;
pub extern fn b3Shape_GetFriction(shapeId: b3ShapeId) f32;
pub extern fn b3Shape_SetRestitution(shapeId: b3ShapeId, restitution: f32) void;
pub extern fn b3Shape_GetRestitution(shapeId: b3ShapeId) f32;
pub extern fn b3Shape_SetSurfaceMaterial(shapeId: b3ShapeId, surfaceMaterial: b3SurfaceMaterial) void;
pub extern fn b3Shape_GetSurfaceMaterial(shapeId: b3ShapeId) b3SurfaceMaterial;
pub extern fn b3Shape_GetMeshMaterialCount(shapeId: b3ShapeId) c_int;
pub extern fn b3Shape_SetMeshMaterial(shapeId: b3ShapeId, surfaceMaterial: b3SurfaceMaterial, index: c_int) void;
pub extern fn b3Shape_GetMeshSurfaceMaterial(shapeId: b3ShapeId, index: c_int) b3SurfaceMaterial;
pub extern fn b3Shape_GetFilter(shapeId: b3ShapeId) b3Filter;
pub extern fn b3Shape_SetFilter(shapeId: b3ShapeId, filter: b3Filter, invokeContacts: bool) void;
pub extern fn b3Shape_EnableSensorEvents(shapeId: b3ShapeId, flag: bool) void;
pub extern fn b3Shape_AreSensorEventsEnabled(shapeId: b3ShapeId) bool;
pub extern fn b3Shape_EnableContactEvents(shapeId: b3ShapeId, flag: bool) void;
pub extern fn b3Shape_AreContactEventsEnabled(shapeId: b3ShapeId) bool;
pub extern fn b3Shape_EnablePreSolveEvents(shapeId: b3ShapeId, flag: bool) void;
pub extern fn b3Shape_ArePreSolveEventsEnabled(shapeId: b3ShapeId) bool;
pub extern fn b3Shape_EnableHitEvents(shapeId: b3ShapeId, flag: bool) void;
pub extern fn b3Shape_AreHitEventsEnabled(shapeId: b3ShapeId) bool;
pub extern fn b3Shape_RayCast(shapeId: b3ShapeId, origin: b3Pos, translation: b3Vec3) b3WorldCastOutput;
pub extern fn b3Shape_GetSphere(shapeId: b3ShapeId) b3Sphere;
pub extern fn b3Shape_GetCapsule(shapeId: b3ShapeId) b3Capsule;
pub extern fn b3Shape_GetHull(shapeId: b3ShapeId) [*c]const b3HullData;
pub extern fn b3Shape_GetMesh(shapeId: b3ShapeId) b3Mesh;
pub extern fn b3Shape_GetHeightField(shapeId: b3ShapeId) [*c]const b3HeightFieldData;
pub extern fn b3Shape_SetSphere(shapeId: b3ShapeId, sphere: [*c]const b3Sphere) void;
pub extern fn b3Shape_SetCapsule(shapeId: b3ShapeId, capsule: [*c]const b3Capsule) void;
pub extern fn b3Shape_SetHull(shapeId: b3ShapeId, hull: [*c]const b3HullData) void;
pub extern fn b3Shape_SetMesh(shapeId: b3ShapeId, meshData: [*c]const b3MeshData, scale: b3Vec3) void;
pub extern fn b3Shape_GetContactCapacity(shapeId: b3ShapeId) c_int;
pub extern fn b3Shape_GetContactData(shapeId: b3ShapeId, contactData: [*c]b3ContactData, capacity: c_int) c_int;
pub extern fn b3Shape_GetSensorCapacity(shapeId: b3ShapeId) c_int;
pub extern fn b3Shape_GetSensorData(shapeId: b3ShapeId, visitorIds: [*c]b3ShapeId, capacity: c_int) c_int;
pub extern fn b3Shape_GetAABB(shapeId: b3ShapeId) b3AABB;
pub extern fn b3Shape_ComputeMassData(shapeId: b3ShapeId) b3MassData;
pub extern fn b3Shape_GetClosestPoint(shapeId: b3ShapeId, target: b3Vec3) b3Vec3;
pub extern fn b3Shape_ApplyWind(shapeId: b3ShapeId, wind: b3Vec3, drag: f32, lift: f32, maxSpeed: f32, wake: bool) void;
pub extern fn b3DestroyJoint(jointId: b3JointId, wakeAttached: bool) void;
pub extern fn b3Joint_IsValid(id: b3JointId) bool;
pub extern fn b3Joint_GetType(jointId: b3JointId) b3JointType;
pub extern fn b3Joint_GetBodyA(jointId: b3JointId) b3BodyId;
pub extern fn b3Joint_GetBodyB(jointId: b3JointId) b3BodyId;
pub extern fn b3Joint_GetWorld(jointId: b3JointId) b3WorldId;
pub extern fn b3Joint_SetLocalFrameA(jointId: b3JointId, localFrame: b3Transform) void;
pub extern fn b3Joint_GetLocalFrameA(jointId: b3JointId) b3Transform;
pub extern fn b3Joint_SetLocalFrameB(jointId: b3JointId, localFrame: b3Transform) void;
pub extern fn b3Joint_GetLocalFrameB(jointId: b3JointId) b3Transform;
pub extern fn b3Joint_SetCollideConnected(jointId: b3JointId, shouldCollide: bool) void;
pub extern fn b3Joint_GetCollideConnected(jointId: b3JointId) bool;
pub extern fn b3Joint_SetUserData(jointId: b3JointId, userData: ?*anyopaque) void;
pub extern fn b3Joint_GetUserData(jointId: b3JointId) ?*anyopaque;
pub extern fn b3Joint_WakeBodies(jointId: b3JointId) void;
pub extern fn b3Joint_GetConstraintForce(jointId: b3JointId) b3Vec3;
pub extern fn b3Joint_GetConstraintTorque(jointId: b3JointId) b3Vec3;
pub extern fn b3Joint_GetLinearSeparation(jointId: b3JointId) f32;
pub extern fn b3Joint_GetAngularSeparation(jointId: b3JointId) f32;
pub extern fn b3Joint_SetConstraintTuning(jointId: b3JointId, hertz: f32, dampingRatio: f32) void;
pub extern fn b3Joint_GetConstraintTuning(jointId: b3JointId, hertz: [*c]f32, dampingRatio: [*c]f32) void;
pub extern fn b3Joint_SetForceThreshold(jointId: b3JointId, threshold: f32) void;
pub extern fn b3Joint_GetForceThreshold(jointId: b3JointId) f32;
pub extern fn b3Joint_SetTorqueThreshold(jointId: b3JointId, threshold: f32) void;
pub extern fn b3Joint_GetTorqueThreshold(jointId: b3JointId) f32;
pub extern fn b3CreateParallelJoint(worldId: b3WorldId, def: [*c]const b3ParallelJointDef) b3JointId;
pub extern fn b3ParallelJoint_SetSpringHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3ParallelJoint_SetSpringDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3ParallelJoint_GetSpringHertz(jointId: b3JointId) f32;
pub extern fn b3ParallelJoint_GetSpringDampingRatio(jointId: b3JointId) f32;
pub extern fn b3ParallelJoint_SetMaxTorque(jointId: b3JointId, force: f32) void;
pub extern fn b3ParallelJoint_GetMaxTorque(jointId: b3JointId) f32;
pub extern fn b3CreateDistanceJoint(worldId: b3WorldId, def: [*c]const b3DistanceJointDef) b3JointId;
pub extern fn b3DistanceJoint_SetLength(jointId: b3JointId, length: f32) void;
pub extern fn b3DistanceJoint_GetLength(jointId: b3JointId) f32;
pub extern fn b3DistanceJoint_EnableSpring(jointId: b3JointId, enableSpring: bool) void;
pub extern fn b3DistanceJoint_IsSpringEnabled(jointId: b3JointId) bool;
pub extern fn b3DistanceJoint_SetSpringForceRange(jointId: b3JointId, lowerForce: f32, upperForce: f32) void;
pub extern fn b3DistanceJoint_GetSpringForceRange(jointId: b3JointId, lowerForce: [*c]f32, upperForce: [*c]f32) void;
pub extern fn b3DistanceJoint_SetSpringHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3DistanceJoint_SetSpringDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3DistanceJoint_GetSpringHertz(jointId: b3JointId) f32;
pub extern fn b3DistanceJoint_GetSpringDampingRatio(jointId: b3JointId) f32;
pub extern fn b3DistanceJoint_EnableLimit(jointId: b3JointId, enableLimit: bool) void;
pub extern fn b3DistanceJoint_IsLimitEnabled(jointId: b3JointId) bool;
pub extern fn b3DistanceJoint_SetLengthRange(jointId: b3JointId, minLength: f32, maxLength: f32) void;
pub extern fn b3DistanceJoint_GetMinLength(jointId: b3JointId) f32;
pub extern fn b3DistanceJoint_GetMaxLength(jointId: b3JointId) f32;
pub extern fn b3DistanceJoint_GetCurrentLength(jointId: b3JointId) f32;
pub extern fn b3DistanceJoint_EnableMotor(jointId: b3JointId, enableMotor: bool) void;
pub extern fn b3DistanceJoint_IsMotorEnabled(jointId: b3JointId) bool;
pub extern fn b3DistanceJoint_SetMotorSpeed(jointId: b3JointId, motorSpeed: f32) void;
pub extern fn b3DistanceJoint_GetMotorSpeed(jointId: b3JointId) f32;
pub extern fn b3DistanceJoint_SetMaxMotorForce(jointId: b3JointId, force: f32) void;
pub extern fn b3DistanceJoint_GetMaxMotorForce(jointId: b3JointId) f32;
pub extern fn b3DistanceJoint_GetMotorForce(jointId: b3JointId) f32;
pub extern fn b3CreateMotorJoint(worldId: b3WorldId, def: [*c]const b3MotorJointDef) b3JointId;
pub extern fn b3MotorJoint_SetLinearVelocity(jointId: b3JointId, velocity: b3Vec3) void;
pub extern fn b3MotorJoint_GetLinearVelocity(jointId: b3JointId) b3Vec3;
pub extern fn b3MotorJoint_SetAngularVelocity(jointId: b3JointId, velocity: b3Vec3) void;
pub extern fn b3MotorJoint_GetAngularVelocity(jointId: b3JointId) b3Vec3;
pub extern fn b3MotorJoint_SetMaxVelocityForce(jointId: b3JointId, maxForce: f32) void;
pub extern fn b3MotorJoint_GetMaxVelocityForce(jointId: b3JointId) f32;
pub extern fn b3MotorJoint_SetMaxVelocityTorque(jointId: b3JointId, maxTorque: f32) void;
pub extern fn b3MotorJoint_GetMaxVelocityTorque(jointId: b3JointId) f32;
pub extern fn b3MotorJoint_SetLinearHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3MotorJoint_GetLinearHertz(jointId: b3JointId) f32;
pub extern fn b3MotorJoint_SetLinearDampingRatio(jointId: b3JointId, damping: f32) void;
pub extern fn b3MotorJoint_GetLinearDampingRatio(jointId: b3JointId) f32;
pub extern fn b3MotorJoint_SetAngularHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3MotorJoint_GetAngularHertz(jointId: b3JointId) f32;
pub extern fn b3MotorJoint_SetAngularDampingRatio(jointId: b3JointId, damping: f32) void;
pub extern fn b3MotorJoint_GetAngularDampingRatio(jointId: b3JointId) f32;
pub extern fn b3MotorJoint_SetMaxSpringForce(jointId: b3JointId, maxForce: f32) void;
pub extern fn b3MotorJoint_GetMaxSpringForce(jointId: b3JointId) f32;
pub extern fn b3MotorJoint_SetMaxSpringTorque(jointId: b3JointId, maxTorque: f32) void;
pub extern fn b3MotorJoint_GetMaxSpringTorque(jointId: b3JointId) f32;
pub extern fn b3CreateFilterJoint(worldId: b3WorldId, def: [*c]const b3FilterJointDef) b3JointId;
pub extern fn b3CreatePrismaticJoint(worldId: b3WorldId, def: [*c]const b3PrismaticJointDef) b3JointId;
pub extern fn b3PrismaticJoint_EnableSpring(jointId: b3JointId, enableSpring: bool) void;
pub extern fn b3PrismaticJoint_IsSpringEnabled(jointId: b3JointId) bool;
pub extern fn b3PrismaticJoint_SetSpringHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3PrismaticJoint_GetSpringHertz(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_SetSpringDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3PrismaticJoint_GetSpringDampingRatio(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_SetTargetTranslation(jointId: b3JointId, targetTranslation: f32) void;
pub extern fn b3PrismaticJoint_GetTargetTranslation(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_EnableLimit(jointId: b3JointId, enableLimit: bool) void;
pub extern fn b3PrismaticJoint_IsLimitEnabled(jointId: b3JointId) bool;
pub extern fn b3PrismaticJoint_GetLowerLimit(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_GetUpperLimit(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_SetLimits(jointId: b3JointId, lower: f32, upper: f32) void;
pub extern fn b3PrismaticJoint_EnableMotor(jointId: b3JointId, enableMotor: bool) void;
pub extern fn b3PrismaticJoint_IsMotorEnabled(jointId: b3JointId) bool;
pub extern fn b3PrismaticJoint_SetMotorSpeed(jointId: b3JointId, motorSpeed: f32) void;
pub extern fn b3PrismaticJoint_GetMotorSpeed(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_SetMaxMotorForce(jointId: b3JointId, force: f32) void;
pub extern fn b3PrismaticJoint_GetMaxMotorForce(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_GetMotorForce(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_GetTranslation(jointId: b3JointId) f32;
pub extern fn b3PrismaticJoint_GetSpeed(jointId: b3JointId) f32;
pub extern fn b3CreateRevoluteJoint(worldId: b3WorldId, def: [*c]const b3RevoluteJointDef) b3JointId;
pub extern fn b3RevoluteJoint_EnableSpring(jointId: b3JointId, enableSpring: bool) void;
pub extern fn b3RevoluteJoint_IsSpringEnabled(jointId: b3JointId) bool;
pub extern fn b3RevoluteJoint_SetSpringHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3RevoluteJoint_GetSpringHertz(jointId: b3JointId) f32;
pub extern fn b3RevoluteJoint_SetSpringDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3RevoluteJoint_GetSpringDampingRatio(jointId: b3JointId) f32;
pub extern fn b3RevoluteJoint_SetTargetAngle(jointId: b3JointId, targetRadians: f32) void;
pub extern fn b3RevoluteJoint_GetTargetAngle(jointId: b3JointId) f32;
pub extern fn b3RevoluteJoint_GetAngle(jointId: b3JointId) f32;
pub extern fn b3RevoluteJoint_EnableLimit(jointId: b3JointId, enableLimit: bool) void;
pub extern fn b3RevoluteJoint_IsLimitEnabled(jointId: b3JointId) bool;
pub extern fn b3RevoluteJoint_GetLowerLimit(jointId: b3JointId) f32;
pub extern fn b3RevoluteJoint_GetUpperLimit(jointId: b3JointId) f32;
pub extern fn b3RevoluteJoint_SetLimits(jointId: b3JointId, lowerLimitRadians: f32, upperLimitRadians: f32) void;
pub extern fn b3RevoluteJoint_EnableMotor(jointId: b3JointId, enableMotor: bool) void;
pub extern fn b3RevoluteJoint_IsMotorEnabled(jointId: b3JointId) bool;
pub extern fn b3RevoluteJoint_SetMotorSpeed(jointId: b3JointId, motorSpeed: f32) void;
pub extern fn b3RevoluteJoint_GetMotorSpeed(jointId: b3JointId) f32;
pub extern fn b3RevoluteJoint_GetMotorTorque(jointId: b3JointId) f32;
pub extern fn b3RevoluteJoint_SetMaxMotorTorque(jointId: b3JointId, torque: f32) void;
pub extern fn b3RevoluteJoint_GetMaxMotorTorque(jointId: b3JointId) f32;
pub extern fn b3CreateSphericalJoint(worldId: b3WorldId, def: [*c]const b3SphericalJointDef) b3JointId;
pub extern fn b3SphericalJoint_EnableConeLimit(jointId: b3JointId, enableLimit: bool) void;
pub extern fn b3SphericalJoint_IsConeLimitEnabled(jointId: b3JointId) bool;
pub extern fn b3SphericalJoint_GetConeLimit(jointId: b3JointId) f32;
pub extern fn b3SphericalJoint_SetConeLimit(jointId: b3JointId, angleRadians: f32) void;
pub extern fn b3SphericalJoint_GetConeAngle(jointId: b3JointId) f32;
pub extern fn b3SphericalJoint_EnableTwistLimit(jointId: b3JointId, enableLimit: bool) void;
pub extern fn b3SphericalJoint_IsTwistLimitEnabled(jointId: b3JointId) bool;
pub extern fn b3SphericalJoint_GetLowerTwistLimit(jointId: b3JointId) f32;
pub extern fn b3SphericalJoint_GetUpperTwistLimit(jointId: b3JointId) f32;
pub extern fn b3SphericalJoint_SetTwistLimits(jointId: b3JointId, lowerLimitRadians: f32, upperLimitRadians: f32) void;
pub extern fn b3SphericalJoint_GetTwistAngle(jointId: b3JointId) f32;
pub extern fn b3SphericalJoint_EnableSpring(jointId: b3JointId, enableSpring: bool) void;
pub extern fn b3SphericalJoint_IsSpringEnabled(jointId: b3JointId) bool;
pub extern fn b3SphericalJoint_SetSpringHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3SphericalJoint_GetSpringHertz(jointId: b3JointId) f32;
pub extern fn b3SphericalJoint_SetSpringDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3SphericalJoint_GetSpringDampingRatio(jointId: b3JointId) f32;
pub extern fn b3SphericalJoint_SetTargetRotation(jointId: b3JointId, targetRotation: b3Quat) void;
pub extern fn b3SphericalJoint_GetTargetRotation(jointId: b3JointId) b3Quat;
pub extern fn b3SphericalJoint_EnableMotor(jointId: b3JointId, enableMotor: bool) void;
pub extern fn b3SphericalJoint_IsMotorEnabled(jointId: b3JointId) bool;
pub extern fn b3SphericalJoint_SetMotorVelocity(jointId: b3JointId, motorVelocity: b3Vec3) void;
pub extern fn b3SphericalJoint_GetMotorVelocity(jointId: b3JointId) b3Vec3;
pub extern fn b3SphericalJoint_GetMotorTorque(jointId: b3JointId) b3Vec3;
pub extern fn b3SphericalJoint_SetMaxMotorTorque(jointId: b3JointId, torque: f32) void;
pub extern fn b3SphericalJoint_GetMaxMotorTorque(jointId: b3JointId) f32;
pub extern fn b3CreateWeldJoint(worldId: b3WorldId, def: [*c]const b3WeldJointDef) b3JointId;
pub extern fn b3WeldJoint_SetLinearHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3WeldJoint_GetLinearHertz(jointId: b3JointId) f32;
pub extern fn b3WeldJoint_SetLinearDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3WeldJoint_GetLinearDampingRatio(jointId: b3JointId) f32;
pub extern fn b3WeldJoint_SetAngularHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3WeldJoint_GetAngularHertz(jointId: b3JointId) f32;
pub extern fn b3WeldJoint_SetAngularDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3WeldJoint_GetAngularDampingRatio(jointId: b3JointId) f32;
pub extern fn b3CreateWheelJoint(worldId: b3WorldId, def: [*c]const b3WheelJointDef) b3JointId;
pub extern fn b3WheelJoint_EnableSuspension(jointId: b3JointId, flag: bool) void;
pub extern fn b3WheelJoint_IsSuspensionEnabled(jointId: b3JointId) bool;
pub extern fn b3WheelJoint_SetSuspensionHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3WheelJoint_GetSuspensionHertz(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_SetSuspensionDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3WheelJoint_GetSuspensionDampingRatio(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_EnableSuspensionLimit(jointId: b3JointId, flag: bool) void;
pub extern fn b3WheelJoint_IsSuspensionLimitEnabled(jointId: b3JointId) bool;
pub extern fn b3WheelJoint_GetLowerSuspensionLimit(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_GetUpperSuspensionLimit(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_SetSuspensionLimits(jointId: b3JointId, lower: f32, upper: f32) void;
pub extern fn b3WheelJoint_EnableSpinMotor(jointId: b3JointId, flag: bool) void;
pub extern fn b3WheelJoint_IsSpinMotorEnabled(jointId: b3JointId) bool;
pub extern fn b3WheelJoint_SetSpinMotorSpeed(jointId: b3JointId, speed: f32) void;
pub extern fn b3WheelJoint_GetSpinMotorSpeed(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_SetMaxSpinTorque(jointId: b3JointId, torque: f32) void;
pub extern fn b3WheelJoint_GetMaxSpinTorque(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_GetSpinSpeed(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_GetSpinTorque(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_EnableSteering(jointId: b3JointId, flag: bool) void;
pub extern fn b3WheelJoint_IsSteeringEnabled(jointId: b3JointId) bool;
pub extern fn b3WheelJoint_SetSteeringHertz(jointId: b3JointId, hertz: f32) void;
pub extern fn b3WheelJoint_GetSteeringHertz(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_SetSteeringDampingRatio(jointId: b3JointId, dampingRatio: f32) void;
pub extern fn b3WheelJoint_GetSteeringDampingRatio(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_SetMaxSteeringTorque(jointId: b3JointId, torque: f32) void;
pub extern fn b3WheelJoint_GetMaxSteeringTorque(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_EnableSteeringLimit(jointId: b3JointId, flag: bool) void;
pub extern fn b3WheelJoint_IsSteeringLimitEnabled(jointId: b3JointId) bool;
pub extern fn b3WheelJoint_GetLowerSteeringLimit(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_GetUpperSteeringLimit(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_SetSteeringLimits(jointId: b3JointId, lowerRadians: f32, upperRadians: f32) void;
pub extern fn b3WheelJoint_SetTargetSteeringAngle(jointId: b3JointId, radians: f32) void;
pub extern fn b3WheelJoint_GetTargetSteeringAngle(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_GetSteeringAngle(jointId: b3JointId) f32;
pub extern fn b3WheelJoint_GetSteeringTorque(jointId: b3JointId) f32;
pub extern fn b3Contact_IsValid(id: b3ContactId) bool;
pub extern fn b3Contact_GetData(contactId: b3ContactId) b3ContactData;

pub const __VERSION__ = "Aro 0.0.0";
pub const __Aro__ = "";
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const __STDC_EMBED_NOT_FOUND__ = @as(c_int, 0);
pub const __STDC_EMBED_FOUND__ = @as(c_int, 1);
pub const __STDC_EMBED_EMPTY__ = @as(c_int, 2);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __GNUC__ = @as(c_int, 7);
pub const __GNUC_MINOR__ = @as(c_int, 1);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 0);
pub const __ARO_EMULATE_NO__ = @as(c_int, 0);
pub const __ARO_EMULATE_CLANG__ = @as(c_int, 1);
pub const __ARO_EMULATE_GCC__ = @as(c_int, 2);
pub const __ARO_EMULATE_MSVC__ = @as(c_int, 3);
pub const __ARO_EMULATE__ = __ARO_EMULATE_NO__;
pub inline fn __building_module(x: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &x;
    return @as(c_int, 0);
}
pub const TARGET_OS_WIN32 = @as(c_int, 0);
pub const TARGET_OS_WINDOWS = @as(c_int, 0);
pub const TARGET_OS_LINUX = @as(c_int, 1);
pub const TARGET_OS_UNIX = @as(c_int, 0);
pub const TARGET_OS_MAC = @as(c_int, 0);
pub const TARGET_OS_OSX = @as(c_int, 0);
pub const TARGET_OS_IPHONE = @as(c_int, 0);
pub const TARGET_OS_IOS = @as(c_int, 0);
pub const TARGET_OS_TV = @as(c_int, 0);
pub const TARGET_OS_WATCH = @as(c_int, 0);
pub const TARGET_OS_VISION = @as(c_int, 0);
pub const TARGET_OS_DRIVERKIT = @as(c_int, 0);
pub const TARGET_OS_MACCATALYST = @as(c_int, 0);
pub const TARGET_OS_SIMULATOR = @as(c_int, 0);
pub const TARGET_OS_EMBEDDED = @as(c_int, 0);
pub const TARGET_OS_NANO = @as(c_int, 0);
pub const TARGET_IPHONE_SIMULATOR = @as(c_int, 0);
pub const TARGET_OS_UIKITFORMAC = @as(c_int, 0);
pub const TARGET_OS_UEFI = @as(c_int, 0);
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`");
// <builtin>:52:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`");
// <builtin>:53:9
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __VAES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __VPCLMULQDQ__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __GFNI__ = @as(c_int, 1);
pub const __SHA__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __PKU__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __CLWB__ = @as(c_int, 1);
pub const __WBNOINVD__ = @as(c_int, 1);
pub const __SHSTK__ = @as(c_int, 1);
pub const __RDPID__ = @as(c_int, 1);
pub const __WAITPKG__ = @as(c_int, 1);
pub const __MOVDIRI__ = @as(c_int, 1);
pub const __MOVDIR64B__ = @as(c_int, 1);
pub const __PCONFIG__ = @as(c_int, 1);
pub const __PTWRITE__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __HRESET__ = @as(c_int, 1);
pub const __CMPCCXADD__ = @as(c_int, 1);
pub const __AVXIFMA__ = @as(c_int, 1);
pub const __AVXNECONVERT__ = @as(c_int, 1);
pub const __AVXVNNI__ = @as(c_int, 1);
pub const __AVXVNNIINT8__ = @as(c_int, 1);
pub const __SERIALIZE__ = @as(c_int, 1);
pub const __UINTR__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const __ELF__ = @as(c_int, 1);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __ATOMIC_BOOL_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WINT_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_SHORT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_INT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LLONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_POINTER_LOCK_FREE = @as(c_int, 1);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SCHAR_WIDTH__ = @as(c_int, 8);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __LONG_LONG_WIDTH__ = @as(c_int, 64);
pub const __WCHAR_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __WINT_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIG_ATOMIC_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __BITINT_MAXWIDTH__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 10);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_WINT_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTPTR_TYPE__ = c_long;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`");
// <builtin>:186:9
pub const __INTMAX_C = __helpers.L_SUFFIX;
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`");
// <builtin>:189:9
pub const __UINTMAX_C = __helpers.UL_SUFFIX;
pub const __PTRDIFF_TYPE__ = c_long;
pub const __SIZE_TYPE__ = c_ulong;
pub const __WCHAR_TYPE__ = c_int;
pub const __WINT_TYPE__ = c_uint;
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub inline fn __INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub inline fn __INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub inline fn __INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`");
// <builtin>:215:9
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub inline fn __UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub inline fn __UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`");
// <builtin>:240:9
pub const __UINT32_C = __helpers.U_SUFFIX;
pub const __UINT32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`");
// <builtin>:249:9
pub const __UINT64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const INT_LEAST8_FMTd__ = "hhd";
pub const INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const UINT_LEAST8_FMTo__ = "hho";
pub const UINT_LEAST8_FMTu__ = "hhu";
pub const UINT_LEAST8_FMTx__ = "hhx";
pub const UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const INT_FAST8_FMTd__ = "hhd";
pub const INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const UINT_FAST8_FMTo__ = "hho";
pub const UINT_FAST8_FMTu__ = "hhu";
pub const UINT_FAST8_FMTx__ = "hhx";
pub const UINT_FAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const INT_LEAST16_FMTd__ = "hd";
pub const INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST16_FMTo__ = "ho";
pub const UINT_LEAST16_FMTu__ = "hu";
pub const UINT_LEAST16_FMTx__ = "hx";
pub const UINT_LEAST16_FMTX__ = "hX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const INT_FAST16_FMTd__ = "hd";
pub const INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_FAST16_FMTo__ = "ho";
pub const UINT_FAST16_FMTu__ = "hu";
pub const UINT_FAST16_FMTx__ = "hx";
pub const UINT_FAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const INT_LEAST32_FMTd__ = "d";
pub const INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST32_FMTo__ = "o";
pub const UINT_LEAST32_FMTu__ = "u";
pub const UINT_LEAST32_FMTx__ = "x";
pub const UINT_LEAST32_FMTX__ = "X";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const INT_FAST32_FMTd__ = "d";
pub const INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_FAST32_FMTo__ = "o";
pub const UINT_FAST32_FMTu__ = "u";
pub const UINT_FAST32_FMTx__ = "x";
pub const UINT_FAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const INT_LEAST64_FMTd__ = "ld";
pub const INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_LEAST64_FMTo__ = "lo";
pub const UINT_LEAST64_FMTu__ = "lu";
pub const UINT_LEAST64_FMTx__ = "lx";
pub const UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const INT_FAST64_FMTd__ = "ld";
pub const INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_FMTo__ = "lo";
pub const UINT_FAST64_FMTu__ = "lu";
pub const UINT_FAST64_FMTx__ = "lx";
pub const UINT_FAST64_FMTX__ = "lX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_HAS_DENORM__ = "";
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = "";
pub const __FLT16_HAS_QUIET_NAN__ = "";
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = "";
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = "";
pub const __FLT_HAS_QUIET_NAN__ = "";
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_HAS_DENORM__ = "";
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = "";
pub const __DBL_HAS_QUIET_NAN__ = "";
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = "";
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = "";
pub const __LDBL_HAS_QUIET_NAN__ = "";
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __FLT_EVAL_METHOD__ = @as(c_int, 0);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const BOX3D_DISABLE_SIMD = @as(c_int, 1);
pub const __GLIBC_MINOR__ = @as(c_int, 44);
pub const @"bool" = bool;
pub const @"true" = @as(c_int, 1);
pub const @"false" = @as(c_int, 0);
pub const __bool_true_false_are_defined = @as(c_int, 1);
pub const _STDINT_H = @as(c_int, 1);
pub const _FEATURES_H = @as(c_int, 1);
pub const __KERNEL_STRICT_NAMES = "";
pub inline fn __GNUC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub inline fn __glibc_clang_prereq(maj: anytype, min: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &maj;
    _ = &min;
    return @as(c_int, 0);
}
pub const __GLIBC_USE = @compileError("unable to translate macro: undefined identifier `__GLIBC_USE_`");
// /usr/include/features.h:197:9
pub const _DEFAULT_SOURCE = @as(c_int, 1);
pub const __GLIBC_USE_ISOC2Y = @as(c_int, 0);
pub const __GLIBC_USE_ISOC23 = @as(c_int, 0);
pub const __USE_ISOC11 = @as(c_int, 1);
pub const __USE_POSIX_IMPLICITLY = @as(c_int, 1);
pub const _POSIX_SOURCE = @as(c_int, 1);
pub const _POSIX_C_SOURCE = @as(c_long, 202405);
pub const __USE_POSIX = @as(c_int, 1);
pub const __USE_POSIX2 = @as(c_int, 1);
pub const __USE_POSIX199309 = @as(c_int, 1);
pub const __USE_POSIX199506 = @as(c_int, 1);
pub const __USE_XOPEN2K = @as(c_int, 1);
pub const __USE_ISOC95 = @as(c_int, 1);
pub const __USE_ISOC99 = @as(c_int, 1);
pub const __USE_XOPEN2K8 = @as(c_int, 1);
pub const _ATFILE_SOURCE = @as(c_int, 1);
pub const __USE_XOPEN2K24 = @as(c_int, 1);
pub const __WORDSIZE = @as(c_int, 64);
pub const __WORDSIZE_TIME64_COMPAT32 = @as(c_int, 1);
pub const __SYSCALL_WORDSIZE = @as(c_int, 64);
pub const __TIMESIZE = __WORDSIZE;
pub const __USE_TIME_BITS64 = @as(c_int, 1);
pub const __USE_MISC = @as(c_int, 1);
pub const __USE_ATFILE = @as(c_int, 1);
pub const __USE_FORTIFY_LEVEL = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_GETS = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_SCANF = @as(c_int, 0);
pub const __GLIBC_USE_C23_STRTOL = @as(c_int, 0);
pub const _STDC_PREDEF_H = @as(c_int, 1);
pub const __STDC_IEC_559__ = @as(c_int, 1);
pub const __STDC_IEC_60559_BFP__ = @as(c_long, 201404);
pub const __STDC_IEC_559_COMPLEX__ = @as(c_int, 1);
pub const __STDC_IEC_60559_COMPLEX__ = @as(c_long, 201404);
pub const __STDC_ISO_10646__ = @as(c_long, 201706);
pub const __GNU_LIBRARY__ = @as(c_int, 6);
pub const __GLIBC__ = @as(c_int, 2);
pub inline fn __GLIBC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub const _SYS_CDEFS_H = @as(c_int, 1);
pub const __glibc_has_attribute = @compileError("unable to translate macro: undefined identifier `__has_attribute`");
// /usr/include/sys/cdefs.h:45:10
pub inline fn __glibc_has_builtin(name: anytype) @TypeOf(__builtin.has_builtin(name)) {
    _ = &name;
    return __builtin.has_builtin(name);
}
pub const __glibc_has_extension = @compileError("unable to translate macro: undefined identifier `__has_extension`");
// /usr/include/sys/cdefs.h:55:10
pub const __LEAF = @compileError("unable to translate macro: undefined identifier `__leaf__`");
// /usr/include/sys/cdefs.h:65:11
pub const __LEAF_ATTR = @compileError("unable to translate macro: undefined identifier `__leaf__`");
// /usr/include/sys/cdefs.h:66:11
pub const __THROW = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/sys/cdefs.h:79:11
pub const __THROWNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/sys/cdefs.h:80:11
pub const __NTH = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/sys/cdefs.h:81:11
pub const __NTHNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/sys/cdefs.h:82:11
pub const __COLD = @compileError("unable to translate macro: undefined identifier `__cold__`");
// /usr/include/sys/cdefs.h:102:11
pub inline fn __P(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub inline fn __PMT(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub const __CONCAT = @compileError("unable to translate C expr: unexpected token '##'");
// /usr/include/sys/cdefs.h:131:9
pub const __STRING = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:132:9
pub const __ptr_t = ?*anyopaque;
pub const __BEGIN_DECLS = "";
pub const __END_DECLS = "";
pub const __attribute_overloadable__ = "";
pub inline fn __bos(ptr: anytype) @TypeOf(__builtin.object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1))) {
    _ = &ptr;
    return __builtin.object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1));
}
pub inline fn __bos0(ptr: anytype) @TypeOf(__builtin.object_size(ptr, @as(c_int, 0))) {
    _ = &ptr;
    return __builtin.object_size(ptr, @as(c_int, 0));
}
pub inline fn __glibc_objsize0(__o: anytype) @TypeOf(__bos0(__o)) {
    _ = &__o;
    return __bos0(__o);
}
pub inline fn __glibc_objsize(__o: anytype) @TypeOf(__bos(__o)) {
    _ = &__o;
    return __bos(__o);
}
pub const __warnattr = @compileError("unable to translate macro: undefined identifier `__warning__`");
// /usr/include/sys/cdefs.h:366:10
pub const __errordecl = @compileError("unable to translate macro: undefined identifier `__error__`");
// /usr/include/sys/cdefs.h:367:10
pub const __flexarr = @compileError("unable to translate C expr: unexpected token '['");
// /usr/include/sys/cdefs.h:379:10
pub const __glibc_c99_flexarr_available = @as(c_int, 1);
pub const __REDIRECT = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/sys/cdefs.h:410:10
pub const __REDIRECT_NTH = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/sys/cdefs.h:417:11
pub const __REDIRECT_NTHNL = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/sys/cdefs.h:419:11
pub const __ASMNAME = @compileError("unable to translate macro: undefined identifier `__USER_LABEL_PREFIX__`");
// /usr/include/sys/cdefs.h:422:10
pub inline fn __ASMNAME2(prefix: anytype, cname: anytype) @TypeOf(__STRING(prefix) ++ cname) {
    _ = &prefix;
    _ = &cname;
    return __STRING(prefix) ++ cname;
}
pub const __REDIRECT_FORTIFY = __REDIRECT;
pub const __REDIRECT_FORTIFY_NTH = __REDIRECT_NTH;
pub const __attribute_malloc__ = @compileError("unable to translate macro: undefined identifier `__malloc__`");
// /usr/include/sys/cdefs.h:452:10
pub const __attribute_alloc_size__ = @compileError("unable to translate macro: undefined identifier `__alloc_size__`");
// /usr/include/sys/cdefs.h:460:10
pub const __attribute_alloc_align__ = @compileError("unable to translate macro: undefined identifier `__alloc_align__`");
// /usr/include/sys/cdefs.h:469:10
pub const __attribute_pure__ = @compileError("unable to translate macro: undefined identifier `__pure__`");
// /usr/include/sys/cdefs.h:479:10
pub const __attribute_const__ = @compileError("unable to translate C expr: unexpected token '__attribute__'");
// /usr/include/sys/cdefs.h:486:10
pub const __attribute_maybe_unused__ = @compileError("unable to translate macro: undefined identifier `__unused__`");
// /usr/include/sys/cdefs.h:492:10
pub const __attribute_used__ = @compileError("unable to translate macro: undefined identifier `__used__`");
// /usr/include/sys/cdefs.h:501:10
pub const __attribute_noinline__ = @compileError("unable to translate macro: undefined identifier `__noinline__`");
// /usr/include/sys/cdefs.h:502:10
pub const __attribute_deprecated__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`");
// /usr/include/sys/cdefs.h:510:10
pub const __attribute_deprecated_msg__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`");
// /usr/include/sys/cdefs.h:520:10
pub const __attribute_format_arg__ = @compileError("unable to translate macro: undefined identifier `__format_arg__`");
// /usr/include/sys/cdefs.h:533:10
pub const __attribute_format_strfmon__ = @compileError("unable to translate macro: undefined identifier `__format__`");
// /usr/include/sys/cdefs.h:543:10
pub const __attribute_nonnull__ = @compileError("unable to translate macro: undefined identifier `__nonnull__`");
// /usr/include/sys/cdefs.h:555:11
pub inline fn __nonnull(params: anytype) @TypeOf(__attribute_nonnull__(params)) {
    _ = &params;
    return __attribute_nonnull__(params);
}
pub const __returns_nonnull = @compileError("unable to translate macro: undefined identifier `__returns_nonnull__`");
// /usr/include/sys/cdefs.h:568:10
pub const __attribute_warn_unused_result__ = @compileError("unable to translate macro: undefined identifier `__warn_unused_result__`");
// /usr/include/sys/cdefs.h:577:10
pub const __wur = "";
pub const __always_inline = @compileError("unable to translate macro: undefined identifier `__always_inline__`");
// /usr/include/sys/cdefs.h:595:10
pub const __attribute_artificial__ = @compileError("unable to translate macro: undefined identifier `__artificial__`");
// /usr/include/sys/cdefs.h:604:10
pub const __extern_inline = @compileError("unable to translate C expr: unexpected token 'extern'");
// /usr/include/sys/cdefs.h:626:11
pub const __extern_always_inline = @compileError("unable to translate C expr: unexpected token 'extern'");
// /usr/include/sys/cdefs.h:627:11
pub const __fortify_function = __extern_always_inline ++ __attribute_artificial__;
pub const __va_arg_pack = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg_pack`");
// /usr/include/sys/cdefs.h:638:10
pub const __va_arg_pack_len = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg_pack_len`");
// /usr/include/sys/cdefs.h:639:10
pub const __restrict_arr = @compileError("unable to translate C expr: unexpected token '__restrict'");
// /usr/include/sys/cdefs.h:666:10
pub inline fn __glibc_unlikely(cond: anytype) @TypeOf(__builtin.expect(cond, @as(c_int, 0))) {
    _ = &cond;
    return __builtin.expect(cond, @as(c_int, 0));
}
pub inline fn __glibc_likely(cond: anytype) @TypeOf(__builtin.expect(cond, @as(c_int, 1))) {
    _ = &cond;
    return __builtin.expect(cond, @as(c_int, 1));
}
pub const __attribute_nonstring__ = "";
pub inline fn __attribute_copy__(arg: anytype) void {
    _ = &arg;
    return;
}
pub const __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI = @as(c_int, 0);
pub inline fn __LDBL_REDIR1(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR(name: anytype, proto: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR1_NTH(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR_NTH(name: anytype, proto: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR2_DECL(name: anytype) void {
    _ = &name;
    return;
}
pub inline fn __LDBL_REDIR_DECL(name: anytype) void {
    _ = &name;
    return;
}
pub inline fn __REDIRECT_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT(name, proto, alias);
}
pub inline fn __REDIRECT_NTH_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT_NTH(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT_NTH(name, proto, alias);
}
pub const __glibc_macro_warning1 = @compileError("unable to translate macro: undefined identifier `_Pragma`");
// /usr/include/sys/cdefs.h:807:10
pub const __glibc_macro_warning = @compileError("unable to translate macro: undefined identifier `GCC`");
// /usr/include/sys/cdefs.h:808:10
pub const __HAVE_GENERIC_SELECTION = @as(c_int, 1);
pub const __glibc_const_generic = @compileError("unable to translate C expr: expected type instead got 'const'");
// /usr/include/sys/cdefs.h:837:10
pub inline fn __fortified_attr_access(a: anytype, o: anytype, s: anytype) void {
    _ = &a;
    _ = &o;
    _ = &s;
    return;
}
pub inline fn __attr_access(x: anytype) void {
    _ = &x;
    return;
}
pub inline fn __attr_access_none(argno: anytype) void {
    _ = &argno;
    return;
}
pub inline fn __attr_dealloc(dealloc: anytype, argno: anytype) void {
    _ = &dealloc;
    _ = &argno;
    return;
}
pub const __attr_dealloc_free = "";
pub const __attribute_returns_twice__ = @compileError("unable to translate macro: undefined identifier `__returns_twice__`");
// /usr/include/sys/cdefs.h:884:10
pub const __attribute_struct_may_alias__ = @compileError("unable to translate macro: undefined identifier `__may_alias__`");
// /usr/include/sys/cdefs.h:893:10
pub const __stub___compat_bdflush = "";
pub const __stub_chflags = "";
pub const __stub_fchflags = "";
pub const __stub_gtty = "";
pub const __stub_revoke = "";
pub const __stub_setlogin = "";
pub const __stub_sigreturn = "";
pub const __stub_stty = "";
pub const _BITS_TYPES_H = @as(c_int, 1);
pub const __S16_TYPE = c_short;
pub const __U16_TYPE = c_ushort;
pub const __S32_TYPE = c_int;
pub const __U32_TYPE = c_uint;
pub const __SLONGWORD_TYPE = c_long;
pub const __ULONGWORD_TYPE = c_ulong;
pub const __SQUAD_TYPE = c_long;
pub const __UQUAD_TYPE = c_ulong;
pub const __SWORD_TYPE = c_long;
pub const __UWORD_TYPE = c_ulong;
pub const __SLONG32_TYPE = c_int;
pub const __ULONG32_TYPE = c_uint;
pub const __S64_TYPE = c_long;
pub const __U64_TYPE = c_ulong;
pub const _BITS_TYPESIZES_H = @as(c_int, 1);
pub const __SYSCALL_SLONG_TYPE = __SLONGWORD_TYPE;
pub const __SYSCALL_ULONG_TYPE = __ULONGWORD_TYPE;
pub const __DEV_T_TYPE = __UQUAD_TYPE;
pub const __UID_T_TYPE = __U32_TYPE;
pub const __GID_T_TYPE = __U32_TYPE;
pub const __INO_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __INO64_T_TYPE = __UQUAD_TYPE;
pub const __MODE_T_TYPE = __U32_TYPE;
pub const __NLINK_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSWORD_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF64_T_TYPE = __SQUAD_TYPE;
pub const __PID_T_TYPE = __S32_TYPE;
pub const __RLIM_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __RLIM64_T_TYPE = __UQUAD_TYPE;
pub const __BLKCNT_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __BLKCNT64_T_TYPE = __SQUAD_TYPE;
pub const __FSBLKCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSBLKCNT64_T_TYPE = __UQUAD_TYPE;
pub const __FSFILCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSFILCNT64_T_TYPE = __UQUAD_TYPE;
pub const __ID_T_TYPE = __U32_TYPE;
pub const __CLOCK_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __TIME_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __USECONDS_T_TYPE = __U32_TYPE;
pub const __SUSECONDS_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __SUSECONDS64_T_TYPE = __SQUAD_TYPE;
pub const __DADDR_T_TYPE = __S32_TYPE;
pub const __KEY_T_TYPE = __S32_TYPE;
pub const __CLOCKID_T_TYPE = __S32_TYPE;
pub const __TIMER_T_TYPE = ?*anyopaque;
pub const __BLKSIZE_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __FSID_T_TYPE = @compileError("unable to translate macro: undefined identifier `__val`");
// /usr/include/bits/typesizes.h:73:9
pub const __SSIZE_T_TYPE = __SWORD_TYPE;
pub const __CPU_MASK_TYPE = __SYSCALL_ULONG_TYPE;
pub const __OFF_T_MATCHES_OFF64_T = @as(c_int, 1);
pub const __INO_T_MATCHES_INO64_T = @as(c_int, 1);
pub const __RLIM_T_MATCHES_RLIM64_T = @as(c_int, 1);
pub const __STATFS_MATCHES_STATFS64 = @as(c_int, 1);
pub const __KERNEL_OLD_TIMEVAL_MATCHES_TIMEVAL64 = @as(c_int, 1);
pub const __FD_SETSIZE = @as(c_int, 1024);
pub const _BITS_TIME64_H = @as(c_int, 1);
pub const __TIME64_T_TYPE = __TIME_T_TYPE;
pub const _BITS_WCHAR_H = @as(c_int, 1);
pub const __WCHAR_MAX = __WCHAR_MAX__;
pub const __WCHAR_MIN = -__WCHAR_MAX - @as(c_int, 1);
pub const _BITS_STDINT_INTN_H = @as(c_int, 1);
pub const _BITS_STDINT_UINTN_H = @as(c_int, 1);
pub const _BITS_STDINT_LEAST_H = @as(c_int, 1);
pub const __intptr_t_defined = "";
pub const __INT64_C = __helpers.L_SUFFIX;
pub const __UINT64_C = __helpers.UL_SUFFIX;
pub const INT8_MIN = -@as(c_int, 128);
pub const INT16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT32_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT8_MAX = @as(c_int, 127);
pub const INT16_MAX = @as(c_int, 32767);
pub const INT32_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT8_MAX = @as(c_int, 255);
pub const UINT16_MAX = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT32_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_LEAST8_MIN = -@as(c_int, 128);
pub const INT_LEAST16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT_LEAST32_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT_LEAST64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_LEAST8_MAX = @as(c_int, 127);
pub const INT_LEAST16_MAX = @as(c_int, 32767);
pub const INT_LEAST32_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT_LEAST64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_LEAST8_MAX = @as(c_int, 255);
pub const UINT_LEAST16_MAX = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST32_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_FAST8_MIN = -@as(c_int, 128);
pub const INT_FAST16_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST32_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_FAST8_MAX = @as(c_int, 127);
pub const INT_FAST16_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST32_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_FAST8_MAX = @as(c_int, 255);
pub const UINT_FAST16_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST32_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INTPTR_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INTPTR_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const UINTPTR_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const INTMAX_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INTMAX_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINTMAX_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const PTRDIFF_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const PTRDIFF_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const SIG_ATOMIC_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const SIG_ATOMIC_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const SIZE_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const WCHAR_MIN = __WCHAR_MIN;
pub const WCHAR_MAX = __WCHAR_MAX;
pub const WINT_MIN = @as(c_uint, 0);
pub const WINT_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub inline fn INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const INT64_C = __helpers.L_SUFFIX;
pub inline fn UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const UINT32_C = __helpers.U_SUFFIX;
pub const UINT64_C = __helpers.UL_SUFFIX;
pub const INTMAX_C = __helpers.L_SUFFIX;
pub const UINTMAX_C = __helpers.UL_SUFFIX;
pub const BOX3D_EXPORT = "";
pub const B3_API = "";
pub const B3_INLINE = @compileError("unable to translate C expr: unexpected token 'static'");
// ../DINX/vendor/box3d-0.1.0/include/box3d/base.h:54:10
pub const B3_FORCE_INLINE = @compileError("unable to translate macro: undefined identifier `always_inline`");
// ../DINX/vendor/box3d-0.1.0/include/box3d/base.h:59:10
pub inline fn B3_LITERAL(T: anytype) @TypeOf(T) {
    _ = &T;
    return T;
}
pub const B3_ZERO_INIT = @compileError("unable to translate C expr: unexpected token '{'");
// ../DINX/vendor/box3d-0.1.0/include/box3d/base.h:66:10
pub const B3_ENABLE_VALIDATION = @as(c_int, 0);
pub const B3_NULL_INDEX = -@as(c_int, 1);
pub const B3_BREAKPOINT = @compileError("unable to translate macro: undefined identifier `__builtin_trap`");
// ../DINX/vendor/box3d-0.1.0/include/box3d/base.h:116:9
pub const B3_ASSERT = @compileError("unable to translate macro: undefined identifier `__FILE__`");
// ../DINX/vendor/box3d-0.1.0/include/box3d/base.h:127:9
pub inline fn B3_VALIDATE() anyopaque {
    return __helpers.cast(anyopaque, @as(c_int, 0));
}
pub const B3_HASH_INIT = @as(c_int, 5381);
pub const FLT_RADIX = __FLT_RADIX__;
pub const FLT_MANT_DIG = __FLT_MANT_DIG__;
pub const DBL_MANT_DIG = __DBL_MANT_DIG__;
pub const LDBL_MANT_DIG = __LDBL_MANT_DIG__;
pub const FLT_EVAL_METHOD = __FLT_EVAL_METHOD__;
pub const DECIMAL_DIG = __DECIMAL_DIG__;
pub const FLT_DIG = __FLT_DIG__;
pub const DBL_DIG = __DBL_DIG__;
pub const LDBL_DIG = __LDBL_DIG__;
pub const FLT_MIN_EXP = __FLT_MIN_EXP__;
pub const DBL_MIN_EXP = __DBL_MIN_EXP__;
pub const LDBL_MIN_EXP = __LDBL_MIN_EXP__;
pub const FLT_MIN_10_EXP = __FLT_MIN_10_EXP__;
pub const DBL_MIN_10_EXP = __DBL_MIN_10_EXP__;
pub const LDBL_MIN_10_EXP = __LDBL_MIN_10_EXP__;
pub const FLT_MAX_EXP = __FLT_MAX_EXP__;
pub const DBL_MAX_EXP = __DBL_MAX_EXP__;
pub const LDBL_MAX_EXP = __LDBL_MAX_EXP__;
pub const FLT_MAX_10_EXP = __FLT_MAX_10_EXP__;
pub const DBL_MAX_10_EXP = __DBL_MAX_10_EXP__;
pub const LDBL_MAX_10_EXP = __LDBL_MAX_10_EXP__;
pub const FLT_MAX = __FLT_MAX__;
pub const DBL_MAX = __DBL_MAX__;
pub const LDBL_MAX = __LDBL_MAX__;
pub const FLT_EPSILON = __FLT_EPSILON__;
pub const DBL_EPSILON = __DBL_EPSILON__;
pub const LDBL_EPSILON = __LDBL_EPSILON__;
pub const FLT_MIN = __FLT_MIN__;
pub const DBL_MIN = __DBL_MIN__;
pub const LDBL_MIN = __LDBL_MIN__;
pub const FLT_TRUE_MIN = __FLT_DENORM_MIN__;
pub const DBL_TRUE_MIN = __DBL_DENORM_MIN__;
pub const LDBL_TRUE_MIN = __LDBL_DENORM_MIN__;
pub const FLT_DECIMAL_DIG = __FLT_DECIMAL_DIG__;
pub const DBL_DECIMAL_DIG = __DBL_DECIMAL_DIG__;
pub const LDBL_DECIMAL_DIG = __LDBL_DECIMAL_DIG__;
pub const FLT_HAS_SUBNORM = "";
pub const DBL_HAS_SUBNORM = "";
pub const LDBL_HAS_SUBNORM = "";
pub const _MATH_H = @as(c_int, 1);
pub const __GLIBC_USE_LIB_EXT2 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_BFP_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_BFP_EXT_C23 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT_C23 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_TYPES_EXT = @as(c_int, 0);
pub const _BITS_LIBM_SIMD_DECL_STUBS_H = @as(c_int, 1);
pub const __DECL_SIMD_cos = "";
pub const __DECL_SIMD_cosf = "";
pub const __DECL_SIMD_cosl = "";
pub const __DECL_SIMD_cosf16 = "";
pub const __DECL_SIMD_cosf32 = "";
pub const __DECL_SIMD_cosf64 = "";
pub const __DECL_SIMD_cosf128 = "";
pub const __DECL_SIMD_cosf32x = "";
pub const __DECL_SIMD_cosf64x = "";
pub const __DECL_SIMD_cosf128x = "";
pub const __DECL_SIMD_sin = "";
pub const __DECL_SIMD_sinf = "";
pub const __DECL_SIMD_sinl = "";
pub const __DECL_SIMD_sinf16 = "";
pub const __DECL_SIMD_sinf32 = "";
pub const __DECL_SIMD_sinf64 = "";
pub const __DECL_SIMD_sinf128 = "";
pub const __DECL_SIMD_sinf32x = "";
pub const __DECL_SIMD_sinf64x = "";
pub const __DECL_SIMD_sinf128x = "";
pub const __DECL_SIMD_sincos = "";
pub const __DECL_SIMD_sincosf = "";
pub const __DECL_SIMD_sincosl = "";
pub const __DECL_SIMD_sincosf16 = "";
pub const __DECL_SIMD_sincosf32 = "";
pub const __DECL_SIMD_sincosf64 = "";
pub const __DECL_SIMD_sincosf128 = "";
pub const __DECL_SIMD_sincosf32x = "";
pub const __DECL_SIMD_sincosf64x = "";
pub const __DECL_SIMD_sincosf128x = "";
pub const __DECL_SIMD_log = "";
pub const __DECL_SIMD_logf = "";
pub const __DECL_SIMD_logl = "";
pub const __DECL_SIMD_logf16 = "";
pub const __DECL_SIMD_logf32 = "";
pub const __DECL_SIMD_logf64 = "";
pub const __DECL_SIMD_logf128 = "";
pub const __DECL_SIMD_logf32x = "";
pub const __DECL_SIMD_logf64x = "";
pub const __DECL_SIMD_logf128x = "";
pub const __DECL_SIMD_exp = "";
pub const __DECL_SIMD_expf = "";
pub const __DECL_SIMD_expl = "";
pub const __DECL_SIMD_expf16 = "";
pub const __DECL_SIMD_expf32 = "";
pub const __DECL_SIMD_expf64 = "";
pub const __DECL_SIMD_expf128 = "";
pub const __DECL_SIMD_expf32x = "";
pub const __DECL_SIMD_expf64x = "";
pub const __DECL_SIMD_expf128x = "";
pub const __DECL_SIMD_pow = "";
pub const __DECL_SIMD_powf = "";
pub const __DECL_SIMD_powl = "";
pub const __DECL_SIMD_powf16 = "";
pub const __DECL_SIMD_powf32 = "";
pub const __DECL_SIMD_powf64 = "";
pub const __DECL_SIMD_powf128 = "";
pub const __DECL_SIMD_powf32x = "";
pub const __DECL_SIMD_powf64x = "";
pub const __DECL_SIMD_powf128x = "";
pub const __DECL_SIMD_powr = "";
pub const __DECL_SIMD_powrf = "";
pub const __DECL_SIMD_powrl = "";
pub const __DECL_SIMD_powrf16 = "";
pub const __DECL_SIMD_powrf32 = "";
pub const __DECL_SIMD_powrf64 = "";
pub const __DECL_SIMD_powrf128 = "";
pub const __DECL_SIMD_powrf32x = "";
pub const __DECL_SIMD_powrf64x = "";
pub const __DECL_SIMD_powrf128x = "";
pub const __DECL_SIMD_acos = "";
pub const __DECL_SIMD_acosf = "";
pub const __DECL_SIMD_acosl = "";
pub const __DECL_SIMD_acosf16 = "";
pub const __DECL_SIMD_acosf32 = "";
pub const __DECL_SIMD_acosf64 = "";
pub const __DECL_SIMD_acosf128 = "";
pub const __DECL_SIMD_acosf32x = "";
pub const __DECL_SIMD_acosf64x = "";
pub const __DECL_SIMD_acosf128x = "";
pub const __DECL_SIMD_atan = "";
pub const __DECL_SIMD_atanf = "";
pub const __DECL_SIMD_atanl = "";
pub const __DECL_SIMD_atanf16 = "";
pub const __DECL_SIMD_atanf32 = "";
pub const __DECL_SIMD_atanf64 = "";
pub const __DECL_SIMD_atanf128 = "";
pub const __DECL_SIMD_atanf32x = "";
pub const __DECL_SIMD_atanf64x = "";
pub const __DECL_SIMD_atanf128x = "";
pub const __DECL_SIMD_asin = "";
pub const __DECL_SIMD_asinf = "";
pub const __DECL_SIMD_asinl = "";
pub const __DECL_SIMD_asinf16 = "";
pub const __DECL_SIMD_asinf32 = "";
pub const __DECL_SIMD_asinf64 = "";
pub const __DECL_SIMD_asinf128 = "";
pub const __DECL_SIMD_asinf32x = "";
pub const __DECL_SIMD_asinf64x = "";
pub const __DECL_SIMD_asinf128x = "";
pub const __DECL_SIMD_hypot = "";
pub const __DECL_SIMD_hypotf = "";
pub const __DECL_SIMD_hypotl = "";
pub const __DECL_SIMD_hypotf16 = "";
pub const __DECL_SIMD_hypotf32 = "";
pub const __DECL_SIMD_hypotf64 = "";
pub const __DECL_SIMD_hypotf128 = "";
pub const __DECL_SIMD_hypotf32x = "";
pub const __DECL_SIMD_hypotf64x = "";
pub const __DECL_SIMD_hypotf128x = "";
pub const __DECL_SIMD_exp2 = "";
pub const __DECL_SIMD_exp2f = "";
pub const __DECL_SIMD_exp2l = "";
pub const __DECL_SIMD_exp2f16 = "";
pub const __DECL_SIMD_exp2f32 = "";
pub const __DECL_SIMD_exp2f64 = "";
pub const __DECL_SIMD_exp2f128 = "";
pub const __DECL_SIMD_exp2f32x = "";
pub const __DECL_SIMD_exp2f64x = "";
pub const __DECL_SIMD_exp2f128x = "";
pub const __DECL_SIMD_exp10 = "";
pub const __DECL_SIMD_exp10f = "";
pub const __DECL_SIMD_exp10l = "";
pub const __DECL_SIMD_exp10f16 = "";
pub const __DECL_SIMD_exp10f32 = "";
pub const __DECL_SIMD_exp10f64 = "";
pub const __DECL_SIMD_exp10f128 = "";
pub const __DECL_SIMD_exp10f32x = "";
pub const __DECL_SIMD_exp10f64x = "";
pub const __DECL_SIMD_exp10f128x = "";
pub const __DECL_SIMD_cosh = "";
pub const __DECL_SIMD_coshf = "";
pub const __DECL_SIMD_coshl = "";
pub const __DECL_SIMD_coshf16 = "";
pub const __DECL_SIMD_coshf32 = "";
pub const __DECL_SIMD_coshf64 = "";
pub const __DECL_SIMD_coshf128 = "";
pub const __DECL_SIMD_coshf32x = "";
pub const __DECL_SIMD_coshf64x = "";
pub const __DECL_SIMD_coshf128x = "";
pub const __DECL_SIMD_expm1 = "";
pub const __DECL_SIMD_expm1f = "";
pub const __DECL_SIMD_expm1l = "";
pub const __DECL_SIMD_expm1f16 = "";
pub const __DECL_SIMD_expm1f32 = "";
pub const __DECL_SIMD_expm1f64 = "";
pub const __DECL_SIMD_expm1f128 = "";
pub const __DECL_SIMD_expm1f32x = "";
pub const __DECL_SIMD_expm1f64x = "";
pub const __DECL_SIMD_expm1f128x = "";
pub const __DECL_SIMD_exp2m1 = "";
pub const __DECL_SIMD_exp2m1f = "";
pub const __DECL_SIMD_exp2m1l = "";
pub const __DECL_SIMD_exp2m1f16 = "";
pub const __DECL_SIMD_exp2m1f32 = "";
pub const __DECL_SIMD_exp2m1f64 = "";
pub const __DECL_SIMD_exp2m1f128 = "";
pub const __DECL_SIMD_exp2m1f32x = "";
pub const __DECL_SIMD_exp2m1f64x = "";
pub const __DECL_SIMD_exp2m1f128x = "";
pub const __DECL_SIMD_exp10m1 = "";
pub const __DECL_SIMD_exp10m1f = "";
pub const __DECL_SIMD_exp10m1l = "";
pub const __DECL_SIMD_exp10m1f16 = "";
pub const __DECL_SIMD_exp10m1f32 = "";
pub const __DECL_SIMD_exp10m1f64 = "";
pub const __DECL_SIMD_exp10m1f128 = "";
pub const __DECL_SIMD_exp10m1f32x = "";
pub const __DECL_SIMD_exp10m1f64x = "";
pub const __DECL_SIMD_exp10m1f128x = "";
pub const __DECL_SIMD_sinh = "";
pub const __DECL_SIMD_sinhf = "";
pub const __DECL_SIMD_sinhl = "";
pub const __DECL_SIMD_sinhf16 = "";
pub const __DECL_SIMD_sinhf32 = "";
pub const __DECL_SIMD_sinhf64 = "";
pub const __DECL_SIMD_sinhf128 = "";
pub const __DECL_SIMD_sinhf32x = "";
pub const __DECL_SIMD_sinhf64x = "";
pub const __DECL_SIMD_sinhf128x = "";
pub const __DECL_SIMD_cbrt = "";
pub const __DECL_SIMD_cbrtf = "";
pub const __DECL_SIMD_cbrtl = "";
pub const __DECL_SIMD_cbrtf16 = "";
pub const __DECL_SIMD_cbrtf32 = "";
pub const __DECL_SIMD_cbrtf64 = "";
pub const __DECL_SIMD_cbrtf128 = "";
pub const __DECL_SIMD_cbrtf32x = "";
pub const __DECL_SIMD_cbrtf64x = "";
pub const __DECL_SIMD_cbrtf128x = "";
pub const __DECL_SIMD_atan2 = "";
pub const __DECL_SIMD_atan2f = "";
pub const __DECL_SIMD_atan2l = "";
pub const __DECL_SIMD_atan2f16 = "";
pub const __DECL_SIMD_atan2f32 = "";
pub const __DECL_SIMD_atan2f64 = "";
pub const __DECL_SIMD_atan2f128 = "";
pub const __DECL_SIMD_atan2f32x = "";
pub const __DECL_SIMD_atan2f64x = "";
pub const __DECL_SIMD_atan2f128x = "";
pub const __DECL_SIMD_rsqrt = "";
pub const __DECL_SIMD_rsqrtf = "";
pub const __DECL_SIMD_rsqrtl = "";
pub const __DECL_SIMD_rsqrtf16 = "";
pub const __DECL_SIMD_rsqrtf32 = "";
pub const __DECL_SIMD_rsqrtf64 = "";
pub const __DECL_SIMD_rsqrtf128 = "";
pub const __DECL_SIMD_rsqrtf32x = "";
pub const __DECL_SIMD_rsqrtf64x = "";
pub const __DECL_SIMD_rsqrtf128x = "";
pub const __DECL_SIMD_log10 = "";
pub const __DECL_SIMD_log10f = "";
pub const __DECL_SIMD_log10l = "";
pub const __DECL_SIMD_log10f16 = "";
pub const __DECL_SIMD_log10f32 = "";
pub const __DECL_SIMD_log10f64 = "";
pub const __DECL_SIMD_log10f128 = "";
pub const __DECL_SIMD_log10f32x = "";
pub const __DECL_SIMD_log10f64x = "";
pub const __DECL_SIMD_log10f128x = "";
pub const __DECL_SIMD_log10p1 = "";
pub const __DECL_SIMD_log10p1f = "";
pub const __DECL_SIMD_log10p1l = "";
pub const __DECL_SIMD_log10p1f16 = "";
pub const __DECL_SIMD_log10p1f32 = "";
pub const __DECL_SIMD_log10p1f64 = "";
pub const __DECL_SIMD_log10p1f128 = "";
pub const __DECL_SIMD_log10p1f32x = "";
pub const __DECL_SIMD_log10p1f64x = "";
pub const __DECL_SIMD_log10p1f128x = "";
pub const __DECL_SIMD_log2 = "";
pub const __DECL_SIMD_log2f = "";
pub const __DECL_SIMD_log2l = "";
pub const __DECL_SIMD_log2f16 = "";
pub const __DECL_SIMD_log2f32 = "";
pub const __DECL_SIMD_log2f64 = "";
pub const __DECL_SIMD_log2f128 = "";
pub const __DECL_SIMD_log2f32x = "";
pub const __DECL_SIMD_log2f64x = "";
pub const __DECL_SIMD_log2f128x = "";
pub const __DECL_SIMD_log2p1 = "";
pub const __DECL_SIMD_log2p1f = "";
pub const __DECL_SIMD_log2p1l = "";
pub const __DECL_SIMD_log2p1f16 = "";
pub const __DECL_SIMD_log2p1f32 = "";
pub const __DECL_SIMD_log2p1f64 = "";
pub const __DECL_SIMD_log2p1f128 = "";
pub const __DECL_SIMD_log2p1f32x = "";
pub const __DECL_SIMD_log2p1f64x = "";
pub const __DECL_SIMD_log2p1f128x = "";
pub const __DECL_SIMD_log1p = "";
pub const __DECL_SIMD_log1pf = "";
pub const __DECL_SIMD_log1pl = "";
pub const __DECL_SIMD_log1pf16 = "";
pub const __DECL_SIMD_log1pf32 = "";
pub const __DECL_SIMD_log1pf64 = "";
pub const __DECL_SIMD_log1pf128 = "";
pub const __DECL_SIMD_log1pf32x = "";
pub const __DECL_SIMD_log1pf64x = "";
pub const __DECL_SIMD_log1pf128x = "";
pub const __DECL_SIMD_logp1 = "";
pub const __DECL_SIMD_logp1f = "";
pub const __DECL_SIMD_logp1l = "";
pub const __DECL_SIMD_logp1f16 = "";
pub const __DECL_SIMD_logp1f32 = "";
pub const __DECL_SIMD_logp1f64 = "";
pub const __DECL_SIMD_logp1f128 = "";
pub const __DECL_SIMD_logp1f32x = "";
pub const __DECL_SIMD_logp1f64x = "";
pub const __DECL_SIMD_logp1f128x = "";
pub const __DECL_SIMD_atanh = "";
pub const __DECL_SIMD_atanhf = "";
pub const __DECL_SIMD_atanhl = "";
pub const __DECL_SIMD_atanhf16 = "";
pub const __DECL_SIMD_atanhf32 = "";
pub const __DECL_SIMD_atanhf64 = "";
pub const __DECL_SIMD_atanhf128 = "";
pub const __DECL_SIMD_atanhf32x = "";
pub const __DECL_SIMD_atanhf64x = "";
pub const __DECL_SIMD_atanhf128x = "";
pub const __DECL_SIMD_acosh = "";
pub const __DECL_SIMD_acoshf = "";
pub const __DECL_SIMD_acoshl = "";
pub const __DECL_SIMD_acoshf16 = "";
pub const __DECL_SIMD_acoshf32 = "";
pub const __DECL_SIMD_acoshf64 = "";
pub const __DECL_SIMD_acoshf128 = "";
pub const __DECL_SIMD_acoshf32x = "";
pub const __DECL_SIMD_acoshf64x = "";
pub const __DECL_SIMD_acoshf128x = "";
pub const __DECL_SIMD_erf = "";
pub const __DECL_SIMD_erff = "";
pub const __DECL_SIMD_erfl = "";
pub const __DECL_SIMD_erff16 = "";
pub const __DECL_SIMD_erff32 = "";
pub const __DECL_SIMD_erff64 = "";
pub const __DECL_SIMD_erff128 = "";
pub const __DECL_SIMD_erff32x = "";
pub const __DECL_SIMD_erff64x = "";
pub const __DECL_SIMD_erff128x = "";
pub const __DECL_SIMD_tanh = "";
pub const __DECL_SIMD_tanhf = "";
pub const __DECL_SIMD_tanhl = "";
pub const __DECL_SIMD_tanhf16 = "";
pub const __DECL_SIMD_tanhf32 = "";
pub const __DECL_SIMD_tanhf64 = "";
pub const __DECL_SIMD_tanhf128 = "";
pub const __DECL_SIMD_tanhf32x = "";
pub const __DECL_SIMD_tanhf64x = "";
pub const __DECL_SIMD_tanhf128x = "";
pub const __DECL_SIMD_asinh = "";
pub const __DECL_SIMD_asinhf = "";
pub const __DECL_SIMD_asinhl = "";
pub const __DECL_SIMD_asinhf16 = "";
pub const __DECL_SIMD_asinhf32 = "";
pub const __DECL_SIMD_asinhf64 = "";
pub const __DECL_SIMD_asinhf128 = "";
pub const __DECL_SIMD_asinhf32x = "";
pub const __DECL_SIMD_asinhf64x = "";
pub const __DECL_SIMD_asinhf128x = "";
pub const __DECL_SIMD_erfc = "";
pub const __DECL_SIMD_erfcf = "";
pub const __DECL_SIMD_erfcl = "";
pub const __DECL_SIMD_erfcf16 = "";
pub const __DECL_SIMD_erfcf32 = "";
pub const __DECL_SIMD_erfcf64 = "";
pub const __DECL_SIMD_erfcf128 = "";
pub const __DECL_SIMD_erfcf32x = "";
pub const __DECL_SIMD_erfcf64x = "";
pub const __DECL_SIMD_erfcf128x = "";
pub const __DECL_SIMD_tan = "";
pub const __DECL_SIMD_tanf = "";
pub const __DECL_SIMD_tanl = "";
pub const __DECL_SIMD_tanf16 = "";
pub const __DECL_SIMD_tanf32 = "";
pub const __DECL_SIMD_tanf64 = "";
pub const __DECL_SIMD_tanf128 = "";
pub const __DECL_SIMD_tanf32x = "";
pub const __DECL_SIMD_tanf64x = "";
pub const __DECL_SIMD_tanf128x = "";
pub const __DECL_SIMD_sinpi = "";
pub const __DECL_SIMD_sinpif = "";
pub const __DECL_SIMD_sinpil = "";
pub const __DECL_SIMD_sinpif16 = "";
pub const __DECL_SIMD_sinpif32 = "";
pub const __DECL_SIMD_sinpif64 = "";
pub const __DECL_SIMD_sinpif128 = "";
pub const __DECL_SIMD_sinpif32x = "";
pub const __DECL_SIMD_sinpif64x = "";
pub const __DECL_SIMD_sinpif128x = "";
pub const __DECL_SIMD_cospi = "";
pub const __DECL_SIMD_cospif = "";
pub const __DECL_SIMD_cospil = "";
pub const __DECL_SIMD_cospif16 = "";
pub const __DECL_SIMD_cospif32 = "";
pub const __DECL_SIMD_cospif64 = "";
pub const __DECL_SIMD_cospif128 = "";
pub const __DECL_SIMD_cospif32x = "";
pub const __DECL_SIMD_cospif64x = "";
pub const __DECL_SIMD_cospif128x = "";
pub const __DECL_SIMD_tanpi = "";
pub const __DECL_SIMD_tanpif = "";
pub const __DECL_SIMD_tanpil = "";
pub const __DECL_SIMD_tanpif16 = "";
pub const __DECL_SIMD_tanpif32 = "";
pub const __DECL_SIMD_tanpif64 = "";
pub const __DECL_SIMD_tanpif128 = "";
pub const __DECL_SIMD_tanpif32x = "";
pub const __DECL_SIMD_tanpif64x = "";
pub const __DECL_SIMD_tanpif128x = "";
pub const __DECL_SIMD_acospi = "";
pub const __DECL_SIMD_acospif = "";
pub const __DECL_SIMD_acospil = "";
pub const __DECL_SIMD_acospif16 = "";
pub const __DECL_SIMD_acospif32 = "";
pub const __DECL_SIMD_acospif64 = "";
pub const __DECL_SIMD_acospif128 = "";
pub const __DECL_SIMD_acospif32x = "";
pub const __DECL_SIMD_acospif64x = "";
pub const __DECL_SIMD_acospif128x = "";
pub const __DECL_SIMD_asinpi = "";
pub const __DECL_SIMD_asinpif = "";
pub const __DECL_SIMD_asinpil = "";
pub const __DECL_SIMD_asinpif16 = "";
pub const __DECL_SIMD_asinpif32 = "";
pub const __DECL_SIMD_asinpif64 = "";
pub const __DECL_SIMD_asinpif128 = "";
pub const __DECL_SIMD_asinpif32x = "";
pub const __DECL_SIMD_asinpif64x = "";
pub const __DECL_SIMD_asinpif128x = "";
pub const __DECL_SIMD_atanpi = "";
pub const __DECL_SIMD_atanpif = "";
pub const __DECL_SIMD_atanpil = "";
pub const __DECL_SIMD_atanpif16 = "";
pub const __DECL_SIMD_atanpif32 = "";
pub const __DECL_SIMD_atanpif64 = "";
pub const __DECL_SIMD_atanpif128 = "";
pub const __DECL_SIMD_atanpif32x = "";
pub const __DECL_SIMD_atanpif64x = "";
pub const __DECL_SIMD_atanpif128x = "";
pub const __DECL_SIMD_atan2pi = "";
pub const __DECL_SIMD_atan2pif = "";
pub const __DECL_SIMD_atan2pil = "";
pub const __DECL_SIMD_atan2pif16 = "";
pub const __DECL_SIMD_atan2pif32 = "";
pub const __DECL_SIMD_atan2pif64 = "";
pub const __DECL_SIMD_atan2pif128 = "";
pub const __DECL_SIMD_atan2pif32x = "";
pub const __DECL_SIMD_atan2pif64x = "";
pub const __DECL_SIMD_atan2pif128x = "";
pub const _BITS_FLOATN_H = "";
pub const __HAVE_FLOAT128 = @as(c_int, 1);
pub const __HAVE_DISTINCT_FLOAT128 = @as(c_int, 1);
pub const __HAVE_FLOAT64X = @as(c_int, 1);
pub const __HAVE_FLOAT64X_LONG_DOUBLE = @as(c_int, 1);
pub const __f128 = @compileError("unable to translate macro: undefined identifier `f128`");
// /usr/include/bits/floatn.h:72:12
pub const __CFLOAT128 = @compileError("unable to translate: invalid numeric type");
// /usr/include/bits/floatn.h:86:12
pub const _BITS_FLOATN_COMMON_H = "";
pub const __HAVE_FLOAT16 = @as(c_int, 0);
pub const __HAVE_FLOAT32 = @as(c_int, 1);
pub const __HAVE_FLOAT64 = @as(c_int, 1);
pub const __HAVE_FLOAT32X = @as(c_int, 1);
pub const __HAVE_FLOAT128X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT16 = __HAVE_FLOAT16;
pub const __HAVE_DISTINCT_FLOAT32 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT32X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT128X = __HAVE_FLOAT128X;
pub const __HAVE_FLOAT128_UNLIKE_LDBL = (__HAVE_DISTINCT_FLOAT128 != 0) and (__LDBL_MANT_DIG__ != @as(c_int, 113));
pub const __HAVE_FLOATN_NOT_TYPEDEF = @as(c_int, 1);
pub const __f32 = @compileError("unable to translate macro: undefined identifier `f32`");
// /usr/include/bits/floatn-common.h:93:12
pub const __f64 = @compileError("unable to translate macro: undefined identifier `f64`");
// /usr/include/bits/floatn-common.h:105:12
pub const __f32x = @compileError("unable to translate macro: undefined identifier `f32x`");
// /usr/include/bits/floatn-common.h:113:12
pub const __f64x = @compileError("unable to translate macro: undefined identifier `f64x`");
// /usr/include/bits/floatn-common.h:125:12
pub const __CFLOAT32 = @compileError("unable to translate: invalid numeric type");
// /usr/include/bits/floatn-common.h:151:12
pub const __CFLOAT64 = @compileError("unable to translate: invalid numeric type");
// /usr/include/bits/floatn-common.h:163:12
pub const __CFLOAT32X = @compileError("unable to translate: invalid numeric type");
// /usr/include/bits/floatn-common.h:171:12
pub const __CFLOAT64X = @compileError("unable to translate: invalid numeric type");
// /usr/include/bits/floatn-common.h:183:12
pub const HUGE_VAL = @compileError("unable to translate macro: undefined identifier `__builtin_huge_val`");
// /usr/include/math.h:49:10
pub const HUGE_VALF = __builtin.huge_valf();
pub const HUGE_VALL = @compileError("unable to translate macro: undefined identifier `__builtin_huge_vall`");
// /usr/include/math.h:61:11
pub const INFINITY = __builtin.inff();
pub const NAN = __builtin.nanf("");
pub const __GLIBC_FLT_EVAL_METHOD = __FLT_EVAL_METHOD__;
pub const __FP_LOGB0_IS_MIN = @as(c_int, 1);
pub const __FP_LOGBNAN_IS_MIN = @as(c_int, 1);
pub const FP_ILOGB0 = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const FP_ILOGBNAN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const __SIMD_DECL = @compileError("unable to translate macro: undefined identifier `__DECL_SIMD_`");
// /usr/include/bits/mathcalls-macros.h:19:9
pub const __MATHCALL_VEC = @compileError("unable to translate macro: undefined identifier `__MATH_PRECNAME`");
// /usr/include/bits/mathcalls-macros.h:21:9
pub const __MATHDECL_VEC = @compileError("unable to translate macro: undefined identifier `__MATH_PRECNAME`");
// /usr/include/bits/mathcalls-macros.h:25:9
pub const __MATHCALLX = @compileError("unable to translate macro: undefined identifier `_Mdouble_`");
// /usr/include/bits/mathcalls-macros.h:34:9
pub const __MATHDECLX = @compileError("unable to translate macro: undefined identifier `__MATHDECL_1`");
// /usr/include/bits/mathcalls-macros.h:36:9
pub const __MATHREDIR = @compileError("unable to translate macro: undefined identifier `__MATH_PRECNAME`");
// /usr/include/bits/mathcalls-macros.h:47:9
pub const __MATH_DECLARE_LDOUBLE = @as(c_int, 1);
pub const __MATH_TG_F32 = @compileError("unable to translate macro: undefined identifier `f`");
// /usr/include/math.h:1021:12
pub const __MATH_TG_F64X = @compileError("unable to translate macro: undefined identifier `l`");
// /usr/include/math.h:1027:13
pub const __MATH_TG = @compileError("unable to translate macro: undefined identifier `f`");
// /usr/include/math.h:1034:11
pub const fpclassify = @compileError("unable to translate macro: undefined identifier `__builtin_fpclassify`");
// /usr/include/math.h:1104:11
pub inline fn signbit(x: anytype) @TypeOf(__builtin.signbit(x)) {
    _ = &x;
    return __builtin.signbit(x);
}
pub const isfinite = @compileError("unable to translate macro: undefined identifier `__builtin_isfinite`");
// /usr/include/math.h:1131:11
pub const isnormal = @compileError("unable to translate macro: undefined identifier `__builtin_isnormal`");
// /usr/include/math.h:1139:11
pub const MATH_ERRNO = @as(c_int, 1);
pub const MATH_ERREXCEPT = @as(c_int, 2);
pub const math_errhandling = MATH_ERRNO | MATH_ERREXCEPT;
pub const M_E = @as(f64, 2.7182818284590452354);
pub const M_LOG2E = @as(f64, 1.4426950408889634074);
pub const M_LOG10E = @as(f64, 0.43429448190325182765);
pub const M_LN2 = @as(f64, 0.69314718055994530942);
pub const M_LN10 = @as(f64, 2.30258509299404568402);
pub const M_PI = @as(f64, 3.14159265358979323846);
pub const M_PI_2 = @as(f64, 1.57079632679489661923);
pub const M_PI_4 = @as(f64, 0.78539816339744830962);
pub const M_1_PI = @as(f64, 0.31830988618379067154);
pub const M_2_PI = @as(f64, 0.63661977236758134308);
pub const M_2_SQRTPI = @as(f64, 1.12837916709551257390);
pub const M_SQRT2 = @as(f64, 1.41421356237309504880);
pub const M_SQRT1_2 = @as(f64, 0.70710678118654752440);
pub const isgreater = @compileError("unable to translate macro: undefined identifier `__builtin_isgreater`");
// /usr/include/math.h:1443:11
pub const isgreaterequal = @compileError("unable to translate macro: undefined identifier `__builtin_isgreaterequal`");
// /usr/include/math.h:1444:11
pub const isless = @compileError("unable to translate macro: undefined identifier `__builtin_isless`");
// /usr/include/math.h:1445:11
pub const islessequal = @compileError("unable to translate macro: undefined identifier `__builtin_islessequal`");
// /usr/include/math.h:1446:11
pub const islessgreater = @compileError("unable to translate macro: undefined identifier `__builtin_islessgreater`");
// /usr/include/math.h:1447:11
pub const isunordered = @compileError("unable to translate macro: undefined identifier `__builtin_isunordered`");
// /usr/include/math.h:1448:11
pub const B3_PI = @as(f32, 3.14159265359);
pub const B3_DEG_TO_RAD = @as(f32, 0.01745329251);
pub const B3_RAD_TO_DEG = @as(f32, 57.2957795131);
pub const B3_MIN_SCALE = @as(f32, 0.01);
pub const B3_HUGE = @as(f32, 1.0e5) * b3GetLengthUnitsPerMeter();
pub const B3_MAX_WORKERS = @as(c_int, 32);
pub const B3_MAX_TASKS = @as(c_int, 256);
pub const B3_GRAPH_COLOR_COUNT = @as(c_int, 24);
pub const B3_CONTACT_MANIFOLD_COUNT_BUCKETS = @as(c_int, 8);
pub const B3_LINEAR_SLOP = @as(f32, 0.005) * b3GetLengthUnitsPerMeter();
pub const B3_MIN_CAPSULE_LENGTH = B3_LINEAR_SLOP;
pub const B3_OVERLAP_SLOP = @as(f32, 0.1) * B3_LINEAR_SLOP;
pub const B3_MAX_WORLDS = @as(c_int, 128);
pub const B3_MAX_ROTATION = @as(f32, 0.25) * B3_PI;
pub const B3_SPECULATIVE_DISTANCE = @as(f32, 4.0) * B3_LINEAR_SLOP;
pub const B3_MESH_REST_OFFSET = @as(f32, 1.0) * B3_LINEAR_SLOP;
pub const B3_CONTACT_RECYCLE_DISTANCE = @as(f32, 10.0) * B3_LINEAR_SLOP;
pub const B3_CONTACT_RECYCLE_ANGULAR_DISTANCE = @as(f32, 0.99240388);
pub const B3_MAX_AABB_MARGIN = @as(f32, 0.05) * b3GetLengthUnitsPerMeter();
pub const B3_AABB_MARGIN_FRACTION = @as(f32, 0.125);
pub const B3_TIME_TO_SLEEP = @as(f32, 0.5);
pub const B3_BODY_NAME_LENGTH = @as(c_int, 18);
pub const B3_SHAPE_NAME_LENGTH = @as(c_int, 18);
pub const B3_MAX_MANIFOLD_POINTS = @as(c_int, 4);
pub const B3_MAX_SHAPE_CAST_POINTS = @as(c_int, 64);
pub const B3_SHAPE_POWER = @as(c_int, 22);
pub const B3_CHILD_POWER = @as(c_int, 64) - (@as(c_int, 2) * B3_SHAPE_POWER);
pub const B3_MAX_SHAPES = @as(c_int, 1) << B3_SHAPE_POWER;
pub const B3_MAX_CHILD_SHAPES = @as(c_int, 1) << B3_CHILD_POWER;
pub const B3_NULL_ID = @compileError("unable to translate C expr: unexpected token '{'");
// ../DINX/vendor/box3d-0.1.0/include/box3d/id.h:83:10
pub const B3_ID_INLINE = @compileError("unable to translate C expr: unexpected token 'static'");
// ../DINX/vendor/box3d-0.1.0/include/box3d/id.h:86:10
pub inline fn B3_IS_NULL(id: anytype) @TypeOf(id.index1 == @as(c_int, 0)) {
    _ = &id;
    return id.index1 == @as(c_int, 0);
}
pub inline fn B3_IS_NON_NULL(id: anytype) @TypeOf(id.index1 != @as(c_int, 0)) {
    _ = &id;
    return id.index1 != @as(c_int, 0);
}
pub inline fn B3_ID_EQUALS(id1: anytype, id2: anytype) @TypeOf(((id1.index1 == id2.index1) and (id1.world0 == id2.world0)) and (id1.generation == id2.generation)) {
    _ = &id1;
    _ = &id2;
    return ((id1.index1 == id2.index1) and (id1.world0 == id2.world0)) and (id1.generation == id2.generation);
}
pub const B3_DEFAULT_CATEGORY_BITS = UINT64_MAX;
pub const B3_DEFAULT_MASK_BITS = UINT64_MAX;
pub const B3_DYNAMIC_TREE_VERSION = @as(c_ulonglong, 0x93EDAF889FD30B4A);
pub const B3_HULL_VERSION = @as(c_ulonglong, 0x9D4716CE3793900E);
pub const B3_MESH_VERSION = @as(c_ulonglong, 0xABD11AB62A6E886D);
pub const B3_HEIGHT_FIELD_HOLE = @as(c_int, 0xFF);
pub const B3_HEIGHT_FIELD_VERSION = @as(c_ulonglong, 0x8B18CBD138A6BC84);
pub const B3_COMPOUND_VERSION = ((@as(c_ulonglong, 0x830778DB07086EB4) ^ B3_DYNAMIC_TREE_VERSION) ^ B3_MESH_VERSION) ^ B3_HULL_VERSION;
pub const B3_MAX_COMPOUND_MESH_MATERIALS = @as(c_int, 4);
pub const __STDC_VERSION_STDDEF_H__ = @as(c_long, 202311);
pub const NULL = __helpers.cast(?*anyopaque, @as(c_int, 0));
pub const offsetof = @compileError("unable to translate macro: undefined identifier `__builtin_offsetof`");
// zig-pkg/aro-0.0.0-JSD1QqKGNwALqBes402gHE7CP3Ga6xHS1J4mjThB3ro4/include/stddef.h:18:9
