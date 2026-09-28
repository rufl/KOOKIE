# Executed research probes

Date: 2026-09-22. These are narrow CLI experiments, not engine tests or graphics certification.

## Environment and artifact

- Linux x86-64; OpenJDK 27 (`java -version`: build 27).
- `kof info --json`: Kof/compiler/runtime/stdlib 0.4.9, beta release 0.4.9-beta; `embeddedJdk: false`.
- [Release jar](https://github.com/KofLang/Kof4j/releases/tag/kof-0.4.9-beta-linux-x86_64), 42,090,580 bytes.
- SHA-256: `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`, checked against release API metadata.
- System SDL3: `pkg-config --modversion sdl3` → `3.4.16`; library directory `/usr/lib`.
- Each command had a 60-second timeout. DISPLAY, WAYLAND_DISPLAY and DBUS_SESSION_BUS_ADDRESS were removed from child environments. **No display API, window, editor server or GPU was launched**; this was not a graphical test. Clearing those variables alone would not qualify as graphical isolation.
- No repository-wide tests, source rebuilds or display matrix were run. No compiler installation or user configuration was changed.

## Invocation

Download the pinned jar and verify its hash. Set `JAR` to that file. Native compilation also needs compatible assembler/linker and system libraries; this experiment used the existing host toolchain. These commands describe what was exercised, not a portable dependency installer.

```sh
export JAVA_TOOL_OPTIONS=--enable-native-access=ALL-UNNAMED
java --enable-native-access=ALL-UNNAMED -jar "$JAR" info --json
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run core/main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run core/main.kf --target native
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run ffi/main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run ffi/main.kf --target native
java --enable-native-access=ALL-UNNAMED -jar "$JAR" check ffi_array/main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" check ffi_array/main.kf --target native
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run module/main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run module/main.kf --target native
```

The original core invocation used `core.kf` before the other probes were added. Files were subsequently separated into the directories above. The original array checks used `ffi_array.kf`; the source is unchanged. `JAVA_TOOL_OPTIONS` propagated native access to child JVMs; its standard diagnostic line is omitted from the result table.

## Observed results

| Probe | JVM | Native x86-64 | Meaning |
|---|---|---|---|
| Typed mutable arrays + class method loop + record + map + seeded RNG | exit 0; `-20`, `true`, `12`, `12`, `true` | same | This data shape works; not a performance measurement |
| libm sqrt + SDL3 version scalar extern | exit 0; `3.0`, `3004016` | same | Scalar library downcalls work; SDL version only, no initialization/rendering |
| Float-array extern declaration | exit 1; `FFI001` | exit 1; `FFI001` | Buffer ABI is not implemented; expected rejection |
| Directory import / separate combat function | exit 0; `20` | same | This multi-file import shape works |
| Several entry points placed beside one another | exit 1; `PKG002` | same | `run` collects siblings; probe layout needed separate roots |

Native successful runs emitted the warning:

```text
NativeBackend: runtime prune DESABILITADO (java.lang.IllegalStateException: NativeRuntime.java not found (run from the kof-compiler module)) — emitindo runtime completo (fallback seguro).
```

This is a real release-distribution limitation, not a probe failure. Full emitted assembly was roughly 722–741 KB for these tiny programs. That is assembly-source size, **not executable size**. No pruning workaround was used.

Exact rejected-boundary diagnostics (original filename):

```text
ffi_array.kf:1:1: error: extern 'upload' in /tmp/not-loaded.so: FFI binding not implemented on the JVM target yet (FFI001) [FFI001]
ffi_array.kf:1:1: error: extern 'upload' in /tmp/not-loaded.so: FFI binding not implemented on the NATIVE target yet (FFI001) [FFI001]
```

The array probe was checked, not executed; it did not attempt to load the named library. An initial scalar-FFI run failed before code generation because three `.kf` siblings each declared main:

```text
:0:0: error: module has 3 main() functions; expected exactly one [PKG002]
```

Moving each independent probe into its own entry directory made the unchanged scalar source execute successfully. This distinguishes a module-layout mistake from FFI support.

## Complete probe sources

### `core/main.kf`

```kof
record Hit(Int amount, Float fraction)

class Pool {
    Float[] positions
    Int[] health
    constructor(Int count) {
        this.positions = new Float[count]
        this.health = new Int[count]
    }
    void step(Float dt) {
        for (var i = 0; i < 4; i++) {
            positions[i] = positions[i] + dt * 120.0f
            health[i] = health[i] - 1
        }
    }
}

main() {
    var pool = Pool(4)
    for (var i = 0; i < 4; i++) { pool.health[i] = 100 }
    for (var tick = 0; tick < 120; tick++) { pool.step(0.008333334f) }
    var hit = Hit(12, 0.5f)
    println(pool.health[0])
    println(pool.positions[0] > 119.0f && pool.positions[0] < 121.0f)
    println(hit.amount())
    var totals: Map<String, Int> = mapOf("damage", 12)
    println(totals.get("damage"))
    rng.seed(42)
    var first = rng.int(1000)
    rng.seed(42)
    println(first == rng.int(1000))
}
```

### `ffi/main.kf`

```kof
extern "/usr/lib/libm.so.6" sqrt(Double value): Double
extern "/usr/lib/libSDL3.so" SDL_GetVersion(): Int
main() {
    println(sqrt(9.0))
    println(SDL_GetVersion())
}
```

### `ffi_array/main.kf`

```kof
extern "/tmp/not-loaded.so" upload(Float[] values): void
main() {
    var values = new Float[4]
    upload(values)
}
```

### `module/main.kf`

```kof
import sim
main() {
    println(damageAfterArmor(25, 5))
}
```

### `module/sim/combat.kf`

```kof
package sim
Int damageAfterArmor(Int damage, Int armor) {
    return if (damage > armor) damage - armor else 0
}
```

## Not established

- Real SDL video/GPU/audio initialization from Kof native ELF; C runtime/TLS/driver compatibility.
- Pointer/struct/array FFI support, callback retention or safe zero-copy transfer.
- Shooter frame times, FFI throughput, long-running collector safety or memory plateau.
- Cross-platform native executable support, cross-architecture parity, JS runtime parity.
- Kof Editor installation, visual operation, debugger integration or security exploitation.
- Games found online running correctly on this compiler version.

Those remain explicit implementation gates in [ENGINE_PLAN](ENGINE_PLAN.md). The proposed SDL adapter and all proposed engine APIs are unimplemented; no game engine scaffold was created during research.

## Subsequent course-driven experiments

[COURSE_PROBES](COURSE_PROBES.md) adds 18 programs/38 invocations on the same artifact: functions, math, collections, arrays, byte/range IO, JSON, exceptions and an unchanged course queue solution. It records native failures as well as successes, including a stale exception handler and corrupt mixed-record JSON. The original results above remain unchanged; they never established those broader contracts.
