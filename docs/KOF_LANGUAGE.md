# Kof language and runtime reference for KOOKIE

Research date: 2026-09-22. This is a working reference, not a claim of complete language conformance.

The active source/CI baseline is the official Kof `0.6.8` release tag
`kof-0.6.8-linux-x86_64` at commit
[`2971d2fe4cc873eb50fcd1b7d7d3e097381281c8`](https://github.com/KofLang/Kof4j/tree/2971d2fe4cc873eb50fcd1b7d7d3e097381281c8).
Its Linux archive SHA-256 is
`8da8f9efc7c55b6e5314248b90a0ac62d900117f4a3503af8dadf6ce82a20577`.
CI independently builds this pinned source after verifying the upstream
native-GC cycle guard and normalizing compiler metadata. ABI measurements
below retain their stated Kof versions; 0.6.6 measurements do not transfer
without rerunning their gates.

- Source gates must run `source scripts/kof_pin.sh`; it prepends the tracked
  `scripts/kof-as/as` wrapper. The wrapper uses Clang's integrated assembler
  for Kof's `as -o OBJECT FILE.s` calls and delegates other assembler command
  lines to system `as`.
- `scripts/verify_simd_dispatch.sh` is the Buffer qualification gate. Its recorded
  JVM/native x86-64 pass is for Kof `0.6.6`; it must be rerun for `0.6.8`.
- The 0.4.9 and 0.5.0 material below is retained as historical research.


- Compiler source: [`KofLang/Kof4j@22a186b9bf9df37c03809ba6ef4af85085386f63`](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63), `VERSION` = `0.4.9-beta`.
- Executed artifact: [Linux release, 0.4.9-beta, published 2026-09-20](https://github.com/KofLang/Kof4j/releases/tag/kof-0.4.9-beta-linux-x86_64), standalone `kof-cli-0.4.9-beta.jar`.
- Jar SHA-256: `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`, matched GitHub release asset metadata before execution.
- The fetched repository README says 0.4.0-beta; [the website](https://koflang.github.io/) says 0.4.1-beta. Neither identifies the release actually measured here.
- **Measured** means locally executed; **source-verified** means read in the pinned implementation; **upstream claim** means documented but not independently exercised. Proposed engine behavior is explicitly a decision, not a Kof feature.
- [Initial probes](RESEARCH_PROBES.md) and [course-driven probes](COURSE_PROBES.md) preserve complete sources, commands, output and limitations. [Course deep dive](KOF_COURSE.md) reconciles the supplied course and official docs. Only JVM/native x86-64 were exercised; no browser, native graphics, cross-architecture or long-duration proof was performed.

## What the language is

Kof is statically typed, general-purpose, with its own lexer, parser, semantic analysis and linear stack-based IR. JVM bytecode, native assembly/ELF and JavaScript modules are backend outputs; user Kof is not translated to Java and then compiled with javac. Compiler implementation and generated runtime support do use Java. Do not conflate those statements.

Source extension is `.kf`. KofScript `.ks` shares the frontend and executes IR directly; it is not JavaScript. KofC is a separate C-subset compiler, not a route for turning C libraries into Kof engine code.

For this project, **Kof-native source** means engine/game/tool logic written in `.kf`; **native target** means the Linux ELF backend. JVM execution can still run an engine authored in Kof, but is not the proposed native shipping target.

## Practical syntax

| Intent | Actual form / caveat |
|---|---|
| Entry point | `main() { ... }`; exactly one per module. Not `Int main()` |
| Mutable / fixed binding | `var n = 1`; `val n = 1`; also `Int n = 1` or `var n: Int = 1` |
| Function | `Int damage(Int raw, Int armor) { return raw - armor }` or `damage(Int raw): Int { ... }` |
| Expression body | `Int twice(Int x) = x * 2` |
| Defaults / overloads | `String greet(String who = "world")`; same name with distinct parameter signatures. Both measured |
| Condition as value | `var x = if (condition) a else b`; no C ternary |
| Loop | `while (condition) { ... }`, `for (var i = 0; i < count; i++) { ... }` |
| Collection loop | `for (var item in items) { ... }`; `var` is required |
| Mutable object | `class Pool { Int count; constructor(Int count) { this.count = count } }` |
| Immutable data | `record Hit(Int amount, Float fraction)`; access with `hit.amount()` |
| Constructor call | `Pool(4)`; `class X(...)` is record-style, not an ordinary mutable primary constructor |
| Fixed-size array | `var xs = new Float[count]`; `xs[i] = value` |
| Multidimensional array | `new Int[2][3]`; nested indexing/lengths measured. Not an external contiguous-buffer guarantee |
| List | `var xs: List<Int> = listOf(1, 2)`; `add`, `get`, `set`, `remove(index)`, `.size` |
| Map / set | `mapOf("key", 1)`; `setOf("a", "b")`; homogeneous element types |
| Lambda | `(x: Int) -> x + 1`; mutable captures are boxed; use explicit parameters |
| Function value from function | Wrap in a lambda; do not assume bare `twice` / `::twice` references |
| Error | `throw "message"`; `catch (String e)`; `finally` |
| Null check | `String? value = map.get(key)` followed by `if (value != null)` |
| String equality | `==` compares content; concatenate with `+` |
| Conversion | `value as Float`, `longValue as Int`; validate narrowing at boundaries |
| Concurrency | `val task = spawn compute()`; `var result = await task` |
| Tests | `test "name" { assert(condition, "message") }`; `kof test` |
| Native interop | `extern "/path/lib.so" symbol(Int x): Int` |

Semicolons are optional in common forms; the examples above are schematic fragments unless included in the executed probes. Use the formal grammar when a declaration is ambiguous.

### Do not import habits from other languages

- No `fun`, `fn`, `func`, `let`, `const`, JS-style `async`, range `0..n`, array literal `[1, 2]`, Kotlin `?.`/`?:`/`!!`, named arguments, import aliases, traits or macros.
- No ordinary top-level `var`/`val` in `.kf`; put state inside an explicit state object, not accidental globals. Script wrapping is a different execution mode.
- No automatic `${expression}` string interpolation. It remains literal text.
- Primitive types do not expose Java-style `Int.MAX_VALUE`; use explicit bounds.
- Do not assume all Java collection methods exist. In particular list removal is by index, and positional `add(index, value)` is not the documented API.
- `val` fixes a binding, not deep immutability of the object it references.
- `record` is immutable/reference storage with content equality, **not** a promised packed C/value struct. Avoid allocating vector records in inner loops.
- `entity` is an ORM/data feature, not a built-in game ECS.

Sources: [syntax](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/syntax.md), [grammar](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/grammar.md), [classes](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/classes.md), [anti-idioms](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/training/anti-patterns/fake-idioms.md). The anti-idiom page itself contains stale rows; it is guidance, not an oracle.

## Types and semantics that matter for an engine

- Primitive numeric widths: signed `Byte`/`Short`/`Int`/`Long` = 8/16/32/64 bits; `Float`/`Double` = IEEE-754 32/64 bits. `Char` is a UTF-16 code unit. No unsigned integer family.
- Use explicitly typed `Float[]`, `Int[]` and `Long[]` for hot state. Generics are erased; generic containers can box primitives. Array storage must not be assumed to match C memory layout or be exposed by casting a handle.
- Ordinary classes compare by identity; strings/records compare by content. Object/collection arguments copy a reference, not contents.
- Arithmetic overflow is not a checked gameplay contract. Guard inventory counts, currency, indexing and save sizes; use specified PRNG arithmetic rather than accidental host overflow.
- Generic `Option`/`Result` and discriminated unions are not available as built-ins. Use explicit records/classes/enums and checked state transitions.
- Nullability has changed recently. Literal `= null` is rejected (`SEM048`), while null can arrive through APIs. `Bool?` is rejected (`SEM095`); `Troolean` is a separate three-valued feature. Do not use nullable primitives to encode hot-path occupancy; explicit active flags and generation IDs are clearer. Probe any new nullable/generic field pattern.
- Map/set iteration order is unspecified. Use stable entity/item IDs and sorted or explicitly ordered processing for replay, saves and loot.
- Float results may differ between targets; do not promise bit-identical cross-target multiplayer lockstep.
- `rng.seed`/`rng.int` exist; reseeding reproducibility was measured. For separate loot/combat/AI streams, implement explicit per-stream RNG state in `.kf`; do not couple everything to the global builtin sequence.
- Exceptions are strings. Keep normal misses, exhausted pools and collision-free queries as ordinary results, not exception-driven control flow. **Measured native defect:** a normally completed try/catch left a handler active for a later failed assertion. Native bounds faults bypassed catch/finally entirely. Successful explicit-throw/return cleanup probes do not override those failures; see [reproductions](COURSE_PROBES.md).

Sources: [types](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/types.md), [semantics](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/semantics.md), [type system](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/type-system.md), [modules/RNG](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/modules.md).

## Modules, build and dependencies

A source unit may declare `package sim`; `import sim` can expand the matching module-root directory. Specific type imports and directory/package imports have different qualification rules. Do not assume Java wildcard semantics or alias imports.

**Measured:** an entry file importing `sim/combat.kf` ran on both targets and printed `20`. **Also measured:** `kof run file.kf` collected sibling entry files and rejected three `main()` functions (`PKG002`). Put game, kooker, tests and demos in separate entry roots; source-combining scripts are not the default modular architecture.

Commands from the release CLI:

```sh
kof version
kof info --json
kof check path/to/main.kf --target native
kof build path/to/main.kf --target native --output build/native
kof run path/to/main.kf --target native
kof run path/to/main.kf --target jvm
kof inspect path/to/main.kf --json
kof profile path/to/main.kf --target native
kof lsp
```

`kof check` currently invokes full compilation into a temporary directory and deletes its output; it is not a frontend-only operation despite course/docs wording ([CmdCheck.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdCheck.java#L78-L107)). Native checking emitted assembly in our probe. It still does not prove generated code executes. `run` collects siblings; `test` compiles files independently. `inspect` uses the JVM path, not native code-size/performance inspection.

`kof deps` is an upstream package-manager MVP, not evidence of a mature graphics package registry. Pin compiler, library versions, shader compiler and checksums explicitly. Investigate project/module-root configuration before finalizing the proposed multi-entry layout in ENGINE_PLAN.

**Measured Java-library boundary:** with `kofdeps` declaring `org.joml:joml:1.10.9`, `run main.kf --target jvm --deps` executed real JOML vector length/dot and matrix translation. An isolated `-Dkof.deps.home=...` cache supplied the hash-verified JAR. The same source with `--target native --deps` rejected both Java imports with `PKG006`. Complete source, commands, artifact hashes and output are in [MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md). This does not establish native JAR execution, general JNI support or callback/generic-builder interoperability.

The full distribution bundles a JDK. Source `pom.xml` requires Java release 25. The standalone jar was exercised using OpenJDK 27, not the bundled runtime. Do not infer that generated programs plus emitted runtime support need only Java 21 merely because bytecode generation uses a V21 baseline.

**Observed packaging defect:** native execution from an unrelated directory warned `NativeRuntime.java not found (run from the kof-compiler module)` and emitted the full runtime instead of pruning it. The probes still passed. Do not advertise upstream tiny-binary figures for a packaged KOOKIE build until this path is measured or repaired.

Tooling includes formatting, diagnostics, IR inspection, profiling, LSP and debugger commands. Upstream now documents JVM/native DAP, GDB/MI and DWARF; presence of those CLI features does not imply Kof Editor wires them into its UI. See [KOF_EDITOR](KOF_EDITOR.md).

The local installation now includes a persistent compiler build with scoped
LSP/DAP protocol fixes and a real editor client. Its measured workflows and
remaining limitations are recorded in [local tooling](KOF_EDITOR.md#local-installation).
These repairs do not change the native runtime findings below.

## Target suitability

| Target | Evidence / engine decision |
|---|---|
| JVM | Measured core/import/scalar FFI probes pass. Useful differential oracle and possible explicitly chosen fallback. Java classpath interop exists; Jaylib game precedent exists |
| Native x86-64 | Measured same probes pass; preferred Linux engine spike. Full SDL window/GPU/input/audio and long-running memory behavior still gates |
| Native RISC-V / AArch64 | Real backend and scalar FFI support in pinned source/docs, not placeholders. Not executed here; not an initial shipping commitment |
| JS / KofJS | ES modules with embedded GraalJS host facilities. Browser has a different host capability set; `extern` cannot simply access native libraries there |
| Android | JVM-derived packaging path; not a native desktop port and not an initial target |
| Script | Useful tooling exploration; not the real-time game runtime |

A distribution of the upstream compiler for Windows/macOS does **not** prove native PE/Mach-O output. The examined upstream native targets are Linux ELF architectures; the KOOKIE build now adds a separately verified, bounded AMD64 PE/COFF bridge for its reachable Windows gameplay/presentation graphs. Cross-platform game shipping beyond those packages still requires separate proof; do not promise it from SDL portability alone.

## FFI: usable now, incomplete for graphics

**Measured:** this release runs scalar `extern` calls on JVM/native x86-64 and
the bounded `Buffer(U8)` SIMD fixture on both targets. Calling libm
`sqrt(9.0)` returned `3.0`; calling installed SDL3 `SDL_GetVersion()` returned
`3004018`.

Source-verified scalar set: `Int`, `Long`, `Float`, `Double`, `Bool`/`Boolean`,
`String`; `void` additionally allowed as a return. Native requires a library
string and links by use with a direct ABI call, not runtime `dlopen`.

Current `0.6.6` also has a byte-only `Buffer(U8)` contract with
`buffer.alloc`, `buffer.peek8/32/64`, `buffer.poke8/32/64` and `Buffer.bytes()`.
The pinned implementation maps it to the `B` FFI token and a synchronous
payload pointer; the local gate proves Kof `buffer.poke8` producer data,
copy-in/copy-back and an INOUT reduction on JVM and native x86-64. The pinned source comments claim
the same surface for native riscv64/aarch64, but KOOKIE has not rerun that
runtime matrix. `scripts/verify_simd_dispatch.sh` additionally performs
freestanding syntax-only proofs for AArch64 Linux, RISC-V Linux and
x86-64/AArch64 macOS when Clang is available. Those proofs cover target
compilation only; cross-target runtime support remains unqualified.

The older 0.4.9 probe rejected `extern ... upload(Float[] values): void` on JVM
and native. That result remains historical; current 0.6.6 array/record binding
is target-specific and does not establish a portable engine upload ABI.

Returning SDL pointers as `Long` is never a supported substitute.

The pinned `0.6.6` source implements synchronous, non-escaping FFI callbacks
on JVM, the host JS runner and Native x86-64/riscv64/aarch64 for scalar and
`String` arguments with primitive or `void` returns. KOOKIE has not yet run a
local callback probe against this source build, so it is not promoted as an
engine ABI. A C library retaining a callback beyond the downcall is outside
the lifetime contract.

Consequences:

1. Direct scalar APIs and the measured synchronous byte fixture can be called
   directly; do not wrap them gratuitously.
2. SDL event unions, GPU descriptors, typed vertex uploads, native resource
   pointers and asynchronous audio/GPU work need a **small C ABI adapter**.
3. Export integer **registry tokens**, not pointer casts; validate
   type/generation/bounds, copy strings immediately, and release resources
   explicitly.
4. Keep simulation, collision, scene traversal, culling, sorting, materials,
   pass selection, animation, asset semantics and tools in Kof. Adapter code
   marshals; it does not become the engine.
5. The bulk-data path is an explicit performance gate. Scalar staging and the
   byte benchmark prove correctness, not acceptable frame time for dynamic
   geometry/instancing.
6. Native `_start`/C-runtime integration needs actual graphics-library
   initialization proof. A version query does not prove allocator/TLS/thread-
   heavy library paths.

Sources: [pinned Kof4j source](https://github.com/KofLang/Kof4j/tree/7c237861a9035d84b1f7ec4cfddd89daef4c6ddd),
[KofBuffer.java](https://github.com/KofLang/Kof4j/blob/7c237861a9035d84b1f7ec4cfddd89daef4c6ddd/kof-compiler/src/main/java/dev/kof/compiler/KofBuffer.java),
[CompilerFfiBinding.java](https://github.com/KofLang/Kof4j/blob/7c237861a9035d84b1f7ec4cfddd89daef4c6ddd/kof-compiler/src/main/java/dev/kof/compiler/CompilerFfiBinding.java),
[local Buffer gate](../scripts/verify_simd_dispatch.sh),
[runtime ABI](https://github.com/KofLang/Kof4j/blob/7c237861a9035d84b1f7ec4cfddd89daef4c6ddd/docs/runtime/RUNTIME_ABI.md).

### Current 0.6.6 ABI boundary
`bytes()` returns a managed copy; a native FFI payload is valid only for the
downcall. The qualified source path now uses a bounded `Buffer(U8)` directly
for `GPU_SCENE_VERTEX_V1`: Kof encodes six `i32_le` fields, C validates and
copies them into adapter-owned scene storage, and the scalar resource call
remains the fallback.

This is not a generic zero-copy or asynchronous API. Transport and persistence
still use their existing semantic arrays and C ownership rules. Any further
batch path must define schema, length, stride, capacity, generation and
checksum, copy before returning, and pass target-specific runtime gates.
`RUNTIME_ABI.md` remains behavioral, not a public C layout.

## Memory and performance risks

Current x86 source is more useful than the older memory overview:

- Native objects use Kof-managed allocation and a conservative collector. `RuntimeMemory` checks the free list, attempts collection, then uses `mmap`.
- **Source-verified:** auto-collection on free-list exhaustion is conditional on cumulative `kof_spawn_count == 0`. Once the process has used Kof `spawn`, this gate stays closed because worker stacks are not scanned. `await` does not reset the counter.
- Do not schedule native Kof jobs yet or call manual GC around live worker state to bypass the gate. Begin with one Kof simulation/render thread. A library's own audio/driver threads may operate only on its owned memory, without retaining Kof heap pointers or calling Kof code.
- Preallocate entity arrays, event buffers, collision scratch and render lists. No per-bullet class allocation, transient lambda creation, string logging or generic collection churn in the frame loop. Sealed behavior programs are immutable through their public mutation API; hot evaluation checks the sealed/configured invariant rather than recomputing full topology validation and checksums per enemy/tick. Keep explicit `validate()` at admission and serialization boundaries.
- The optimizer source lists constant folding, dead-effect elimination, reachability and jump cleanup. It is not an LLVM-class optimizing pipeline. `as` and `ld` do not supply high-level loop/vectorization optimization. Native is not automatically faster than JVM JIT.
- Small probes establish language viability, not an FPS budget or memory plateau. Require a bounded allocation/GC soak and representative gameplay timing before committing to large crowds.
- Do not hardcode internal object/header/array layouts from docs. The older MEMORY_MODEL page still describes a 16-byte allocation header while current allocator code adds 32 bytes.

Sources: [RuntimeMemory.java:71–185](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeMemory.java#L71-L185), [RuntimeConcurrency.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeConcurrency.java), [optimizer](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/backend/Optimizer.java#L34-L97).

## Standard-library boundaries

Relevant surfaces include collections, JSON, files/paths/directories, math, time, RNG, configuration/logging, processes, concurrency and tests. Use high-level stdlib for cold paths only after checking target behavior.

Course-driven measurements establish small instance `File.writeBytes/readBytes/readRange` operations with embedded zero/high-bit bytes, Double `math.sqrt/lerp/pow`, both `List.reduce` argument orders, `.size()` on a map and absent-null versus present-zero map values. Use builtin math rather than carrying the course's historical Newton-sqrt workaround.

**Do not assume stdlib parity:** native mixed-field fractional-record JSON corrupted values in the measured shape; JVM regex `split("\\|")` and native splitting returned different results. These are content/save correctness gates, not reasons to silently use JVM. Native `Map` lookup scans keys linearly ([RuntimeEnum.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeEnum.java#L109-L157)); generic hash-table O(1) teaching is not its measured or source-derived complexity.

`kof.ui` is a UI/Canvas-facing API, not a 3D game renderer. Existing Kof games supplement missing browser input with JavaScript. `kof.media` availability is not proof of low-latency positional audio.

`kof.gpu` is specialized Vulkan **compute** integration (matrix/matvec calls), not a swapchain/material/mesh renderer. Its source explicitly describes native fallback stubs and JS rejection; do not propose it as KOOKIE's native graphics layer. [KofGpu.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/KofGpu.java).

## Licensing

Kof compiler/tools and Kof Editor are GPLv3. Upstream explicitly states that user-written Kof programs may use their own license and need not become GPL solely through compiler use: [LICENSING.md](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/distribution/LICENSING.md).

Keep the upstream statement with the release record. Redistributing compiler/editor modifications, embedding runtime components, copying game/sibling source and bundling assets are separate questions. Review exact incorporated material and notices before distribution; this document does not grant a new license or legal clearance.

## How to refresh this knowledge

1. Pin source SHA and executable hash separately; do not execute an unexplained old `lib/kof.jar` from a source checkout.
2. Read `VERSION`, release metadata, changed language-reference and FFI/allocator source before believing landing-page tables.
3. Rerun only the focused probes affected by a compiler upgrade; add the real engine workload once it exists.
4. Record outcomes and failures in RESEARCH_PROBES rather than replacing historical observations with current claims.
5. Use the [human course](https://koflang.github.io/learn), [training corpus](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63/training), and [formal reference](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference) together. Resolve disagreements with the pinned implementation and execution.
