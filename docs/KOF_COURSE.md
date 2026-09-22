# Kof course and official-documentation deep dive

Research date: 2026-09-22. This extends [KOF_LANGUAGE](KOF_LANGUAGE.md), not an engine implementation. Complete executed sources/results are in [COURSE_PROBES](COURSE_PROBES.md).

## Sources, versions and evidence

- Supplied [complete course](https://github.com/lunalully/curso-completo-de-kof), pinned at [`d6fc8318e77f30ab0d6be87055d86a7eb63960d3`](https://github.com/lunalully/curso-completo-de-kof/tree/d6fc8318e77f30ab0d6be87055d86a7eb63960d3). Its README claims solutions were verified against **0.3.7-beta**. That is an upstream historical claim, not our course-wide certification.
- Supplied [official documentation portal](https://koflang.github.io/docs). Its underlying [docs-core.json](https://koflang.github.io/docs/docs-core.json) snapshot reports generation `2026-09-17T15:26:18.853Z`, repository `KofLang/Kof4j@main`, **94 documents: 47 learn + 47 training**. The reader can refresh documents from GitHub; the portal is not a versioned language specification.
- Compiler source remains [`22a186b9bf9df37c03809ba6ef4af85085386f63`](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63), version 0.4.9-beta. Portal blob hashes for functions, collections, exceptions, stdlib and native architecture differed from this checkout; filesystem lesson matched. Do not assume a portal snapshot, current branch and executable are identical.
- Executed artifact remains the hash-verified **0.4.9-beta Linux release jar**, OpenJDK 27; exact environment and digest in [RESEARCH_PROBES](RESEARCH_PROBES.md).
- Evidence labels: **measured** = our bounded execution; **source-reviewed** = inspected implementation; **lesson** = teaching material; **decision** = proposed KOOKIE policy. Source-reviewed platform/security findings below were not exercised against services or adversarial systems.

## Coverage and retained lessons

The study covered all 16 module areas through their lessons and representative solutions, plus the five project briefs and relevant compact examples. It did not execute every exercise or certify every API.

| Module | Useful learning | Engine interpretation / limits |
|---|---|---|
| 00 fundamentals | Declarations, control flow, functions, capture, records versus mutable classes, collections, errors, JSON/IO | Exact source shapes matter; historical workarounds need fresh probes |
| 01 algorithms | Linear/binary search, sorting, recursion, asymptotic costs | Sorted-input invariants, bounded traversal, no allocation-heavy recursive hot path |
| 02 data structures | Fixed arrays, lists, stacks, circular queues, graph traversal, hashing | Preallocated frame/event buffers; actual native collection implementation matters |
| 03 databases | Explicit SQL/binds, typed rows, connection ownership, transactions | Potential cold persistence/indexing, not proven game-save atomicity |
| 04 security | Passwords, hashes/HMAC, authenticated encryption, secrets, identity | Available primitives do not supply authorization or client trust |
| 05 networks | Protocol boundaries, HTTP, task handles, process distinction | Task readiness/failure/ownership; no native multiplayer transport established |
| 06 HTTP servers | Routes, request context, middleware, status and headers | Captured state is shared despite request-local context; no server needed now |
| 07 frontend | Colors/themes, widget composition, KofJS/DOM | Color values useful; native widget calls do not establish rendering |
| 08 good practices | Data/state/rule separation, explicit composition, config/logging | Avoid containers and hot-loop logging; validate config at runtime |
| 09 cybersecurity | Threat models, untrusted input, path/identity boundaries | Do not copy unsafe path-prefix, rate-limiter or demo-login recipes |
| 10 data science | Mean/variance, correlation, regression, nearest neighbors | Offline analysis/AI concepts; validate degenerate inputs and use real math APIs |
| 11 testing | Observable state transitions, boundaries, assertions | Several exception tests can falsely pass; current native handler bug compounds this |
| 12 debugging | Error taxonomy, DAP, compile/run/profile distinction | Native fatal faults differ from String throws; inspect is not a native profiler |
| 13 microservices | Message/error contracts, ownership, configuration | Retain contracts, not distributed-service architecture for this local engine |
| 14 architecture | Records, state owners, pure rules, explicit interface adapters | Real seams only; concrete-variable examples do not prove interface dispatch |
| 15 DevOps | Reproducible builds, packaging, target receipts | Pin actual toolchain; compiler packaging is not game asset/library packaging |

The projects are teaching assignments, not finished reference applications. The file-backed task manager is a useful save-model analogy but lacks a complete robust parser/atomic-write contract. The REST/blog/security-monitor briefs do not justify adding infrastructure to KOOKIE.

## Language knowledge strengthened by execution

See the probe document for complete programs and exact outputs.

- **Functions:** arity overloads, default String argument, mutation visible to a captured lambda and nested lambda invocation passed on JVM/native. The course statement that top-level overloads do not exist is stale for these signatures.
- **Numbers:** a Long class field compared with Int literal and a discarded Double method result passed; the historical crash/VerifyError workaround is not needed for these measured forms. Builtin Double `math.sqrt(16.0)`, `math.lerp(0.0,10.0,0.5)` and `math.pow(2.0,3.0)` returned `4.0`, `5.0`, `8.0` on both.
- **Arrays:** `new Int[2][3]`, lengths, zero initialization and nested read/write passed. The older lesson's `Int[]` element assigned another array is not a valid 2D recipe. Prefer explicitly correct dimensions or flat component arrays.
- **Collections:** both `reduce(callback, seed)` and the course's `reduce(seed, callback)` returned 6. Do not manufacture a limitation from documentation disagreement. Map `.size()` worked; existing key with value zero remained distinguishable from missing-key null.
- **Records:** mixed Int/Double/String, standalone Double and Float getters returned correct values. Their success is distinct from broken JSON handling.
- **Binary IO:** `File.writeBytes`, `readBytes`, instance `readRange(1,2)` preserved zero and high-bit values. Independently inspected bytes were `00 7f 80 ff` after each target run. The Kof representation is `Int[]`, not a borrowed native byte pointer. This does not establish FFI transfer, large files, error parity, sync or atomic replacement.
- **Course code:** unchanged `02-estruturas-de-dados/solucoes/16-fila-circular.kf` ran on both and printed FIFO order `10,20,30,40`. That sample does not prove overflow/underflow, wraparound reuse or throughput.

Relevant primary lessons: [course functions](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/00-fundamentos/04-funcoes-e-lambdas.md), [historical workarounds](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/00-fundamentos/99-notas-workarounds.md), [current functions](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/learn/06-functions.md), [stdlib math](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/learn/39-stdlib.md), [filesystem](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/learn/34-file-system.md).

## Measured discrepancies that change engineering decisions

### Native JSON is not safe for the tested schema

`record Save(Int version, Double speed, String name)` with `(1,1.25,"hero")` round-tripped correctly on JVM. Native encoded speed as `0.0`, decoded a wrong tiny Double and an empty name. Decoding a literal JSON string independently also produced a wrong Double. A separate direct-record probe passed, narrowing the problem to the serialization path rather than blanket record failure.

The course is internally inconsistent: its README says JSN001/JSN002 closed, while the JSON lesson retains an older float restriction. Neither proves current correctness. **Decision:** gate native save/content schemas on an upstream/compiler fix and value-preserving round-trip/error tests. Do not silently move the cooker to another language, truncate floats or call a green compile a working serializer. Binary IO success is not yet an implemented replacement codec.

### String split differs by target

For `"a|b|c"`, `split("\\|")` yielded length 3 on JVM and 1 on native; `split("|")` yielded 5 versus 3. Plain comma gave 3 on both. Native runtime scans a single character rather than a regex ([RuntimeStringEdit.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeStringEdit.java#L188-L216)).

**Decision:** format parsers need explicit delimiter/escaping/Unicode contracts and target checks. Do not reuse a JVM regex recipe in native asset/save parsing. One matching comma example is not general parity.

### Assertion tests can falsely pass, for two different reasons

1. **Course-test error on both targets:** `try { operation(); assert(false, "must throw") } catch (String e) { assert(true) }` catches its own failed assertion when the operation succeeds. Several stack/search/cart/inventory solutions use this pattern. Assertions lower to ordinary language throws, not an independent testing channel.
2. **Current native compiler defect:** even an assertion placed *after* a normally completed try/catch re-entered the old handler. The minimal probe printed `no-throw`, `false`, `true`, `unreachable` and exited 0; JVM stopped after `false` with exit 1. Without the preceding try, the false assertion failed correctly on both.

Source cause matches the observation: [StatementLowerer.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/StatementLowerer.java#L388-L477) jumps to `finallyLabel` at line 406; the no-finally branch places `KofTryEnd` immediately **before** that label at lines 474–475. Normal flow skips handler removal. [NativeMethodEmitter.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/nat/NativeMethodEmitter.java#L284-L309) installs/restores the TLS exception chain at try-start/end; [RuntimeGc.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeGc.java#L370-L390) follows that chain on a throw.

A helper returning from both branches produced expected values in a control probe, but **is not a safe general workaround**: returning does not itself establish that the TLS chain was unlinked; a later throw may encounter an expired frame. No compiler patch was made in this research. **Decision:** repair/revalidate this before relying on native exception cleanup or exception-based test results. Keep negative controls and compare observed outputs/exit codes externally.

Course example: [stack test](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/11-testes-unitarios/solucoes/03-pilha-test.kf#L36-L42).

### Fatal native faults are not ordinary exceptions

Explicit String-throw propagation and return-through-finally printed their cleanup markers on both targets. Array access at `length` inside try/catch/finally was caught on JVM; native exited 1 with `Runtime error: array index out of bounds`, with **no catch, cleanup or continuation marker**. Native [panic/bounds/null implementation](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeGc.java#L361-L412) uses process exit, not String unwinding.

**Decision:** validate capacity/index/resource inputs before touching storage; do not use caught bounds errors for normal pool misses. Explicit adapter teardown remains required; a `finally` claim does not cover fatal process termination. Dynamic zero division/null faults were source-reviewed, not separately executed here.

## Algorithms: learn the contract, not just the sample

- **Search:** binary search requires sorted data. Use an overflow-safe midpoint `low + (high - low) / 2` with validated indices. A normal absent entity is not necessarily exceptional; choose an explicit result/active-generation check suitable for the hot path.
- **Queues:** circular arrays avoid `List.remove(0)` shifts. Engine event queues need capacity admission, wraparound and full/empty state contracts; the teaching example is not the complete implementation.
- **Graphs:** the lesson stores an edge list, scans all edges to build each neighbor list, removes queue front elements and searches visited lists linearly. It does not supply an O(V+E), allocation-free engine BFS. Use precomputed adjacency and owned queues/visited scratch when that workload exists.
- **Sorting:** the displayed bubble sort has no early exit, so its best-case work remains quadratic despite the table. The merge sample allocates split/output lists recursively and selects the right half on equal keys; a stable equal-key render sort cannot simply inherit the table's “stable” label. Prefer bounded arrays/reused scratch and an explicit tie key.
- **Hashing:** generic expected-O(1) hash-table teaching does not describe this native Map. [RuntimeEnum.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeEnum.java#L109-L157) scans keys linearly. Use maps for suitable cold data; do not promise constant-time native entity lookup from the API name.
- **Recursion:** no guaranteed tail-call optimization. Untrusted content/tree depth needs a bound or explicit traversal stack. String-recursion examples additionally allocate substrings and have native-byte/JVM-UTF-16 differences.
- **Numerics:** use available Double math instead of the course's hand-coded Newton sqrt. Pearson/regression examples need zero-variance/zero-denominator and input-length handling. Squared distance avoids unnecessary square roots in nearest-candidate ranking. `now()` is epoch milliseconds, not the engine's required monotonic/high-resolution clock.

Primary course chapters: [sorting](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/01-algoritmos/03-ordenacao.md), [graphs](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/02-estruturas-de-dados/05-grafos.md), [hashing](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/02-estruturas-de-dados/06-hash.md), [statistics/nearest neighbors](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/10-ciencia-de-dados/02-correlacao-regressao-knn.md).

## Platform APIs: source-reviewed boundaries, not executed certification

| Surface | Current source finding | KOOKIE consequence |
|---|---|---|
| Database | Native SQLite exists (`sqlite:` DSN). Zero-bind execute returns SQLite status; bound execute does not consistently check prepare/step failures. Transaction rollback responds to Kof throws, not automatically every SQL error | No assumption of JDBC-equivalent errors or reliable save atomicity; database path remains unproven |
| Task concurrency | Kof `spawn`/`await` differs from starting an OS process. Cancellation is cooperative; completion can represent failure | Existing no-native-Kof-workers GC decision remains; no course-based worker shortcut |
| External process | Both native `process.run` and `process.spawn` are rejected with `PROC001`. Result fields elsewhere are `.stdout`, `.stderr`, `.exitCode`, not course `.output` | Native cooker cannot assume it can launch shader/asset tools through these APIs; use allowed minimal external build orchestration or prove a proper platform extension |
| UI | Native Window show/close and Canvas rendering contain explicit no-ops | Retain SDL_GPU/native input plan; compiling widgets is not visual proof |
| HTTP | Native HTTPS explicitly unsupported; JVM HTTPS client uses a trust-all certificate manager | Not an authenticated download/multiplayer stack; do not send credentials or trust remote assets on the strength of the URL scheme |
| Configuration | Typed API parses deployment text at runtime; malformed values can use fallback. Selected profile replaces, rather than layers over, the default file in lookup | Validate required engine ranges/paths at startup; compilation does not validate configuration |
| Security | Capability varies by architecture; crypto primitives do not establish application authorization, safe paths or trusted client identity | No auth/web infrastructure added; save checksums are not anti-cheat authority |

Source anchors: [database runtime](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeDb4.java#L63-L194), [process gates](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/ExpressionProcessCallLowerer.java#L18-L89), [native UI](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeUi.java), [native HTTP parser](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/nat/NativeHttpParseUrl.java), [JVM TLS/client](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/jvm/JvmWebHttpRuntime.java#L113-L186), [config lookup](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/jvm/JvmConfigRuntime.java#L81-L132).

Do not port the course's security demonstrations as production controls:

- Normalizing a path and rejecting a `..` prefix does not establish asset-root containment: absolute paths/symlinks remain concerns.
- The manual limiter filters away other clients' entries when processing one client; alternating keys can erase history. Its shared mutable list is not concurrency-safe.
- Demo login code issues privileged claims without a real credential check; forwarded IP headers need a trusted-proxy policy, not blind acceptance.
- Per-request context does not make captured collections/connections private. The course's distributed stock examples do not implement an atomic inventory reservation.

These are source/algorithm observations, not executed attacks. See [secure coding](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/09-ciberseguranca/06-secure-coding.md), [limiter solution](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/09-ciberseguranca/solucoes/06-rate-limit.kf), [demo auth CRUD](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/06-http-servidores/solucoes/10-crud-auth-db.kf).

## Architecture, testing and toolchain lessons

- Model cold data with records, mutable state with explicit owners, deterministic rules with functions. Constructor/function arguments are dependency injection without a container. Do not create repository/service layers simply to imitate a web course.
- A declared interface is not a tested interface call. The architecture solutions infer concrete adapter variables; an engine seam using interface-typed parameters still needs its exact dispatch probe.
- `kof run` collects sibling sources; `kof test` compiles files independently. Isolate independent course mains/types. Named tests run sequentially inside a generated runner and do not reset shared state or resources. The native exception findings prevent assuming every green test result is sound.
- `kof test` has a timeout option but defaults to unlimited in inspected source. Some “integrator” examples call a blocking server loop rather than define unit tests. Do not run solution directories indiscriminately.
- **Measured/source-reviewed:** `check` compiles into temporary output; native checking emitted assembly. It does not execute the result. `inspect` selects JVM compilation and is not a native profiler. Native profile reports aggregate timing/RSS where supported and rejects `--methods`; native debug uses GDB or a GDB/MI DAP bridge.
- Source compiler builds require Java **25**, not the course CI's 21. Our release jar used Java 27. `kof c` is a separate C-subset compiler; `kofc` is not a valid `.kf` build target.
- Native deployment packages an ELF plus metadata/checksums; it does not automatically gather assets or SDL/shared-library dependencies. `kof deps` is a JAR dependency mechanism, not a native graphics/asset package manager.
- Config parsing and “release” builds are not proof of runtime correctness; stripped debug information is not an assertion-disable contract.

Primary tooling source: [CmdCheck](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdCheck.java), [CmdTest](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdTest.java), [Inspect](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/Inspect.java), [Profile](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/Profile.java), [KofDebug](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/KofDebug.java), [CmdDeploy](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdDeploy.java).

## Resulting engine decisions

1. Keep `.kf` ownership, native-first Linux, SDL_GPU and one Kof thread. The course does not supply a native renderer or remove the existing FFI/GC gates.
2. Put native exception-handler repair/revalidation at the start of G0. Do not build resource cleanup and test confidence atop the reproduced stale-handler behavior.
3. Retain native JSON correctness as an explicit save/content gate. File-byte success reduces one uncertainty but does not establish durable saves or bulk graphics upload.
4. Use bounded component/event/traversal arrays, builtin math and explicit algorithm invariants; no blind transfer of teaching complexity tables.
5. Preserve observations, exact sources and negative controls in [COURSE_PROBES](COURSE_PROBES.md). Upgrade by rerunning relevant contracts, not by trusting a newer “all targets” table.

The course README references Kof's GPL-3.0 philosophy/examples rather than providing clear independent permissive licensing. Preserve attribution for reproduced material and review rights before incorporating code. No upstream compiler/course changes, engine code, database/server infrastructure or graphical tests were introduced by this study.
