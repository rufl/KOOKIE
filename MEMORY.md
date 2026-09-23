# KOOKIE working memory

Last research and tooling installation: 2026-09-22. Read [README](README.md) then [ENGINE_PLAN](docs/ENGINE_PLAN.md). G0 implementation now includes a checked resource-token contract; tooling installation is not engine implementation.

## User intent

Create an engine for boomer shooters / looter shooters / ARPG FPS using **native Kof `.kf` source for all portable engine/game/tool logic**. External graphics/platform libraries and indispensable ABI/shader code are exceptions, not permission to build the engine in another language. Borrow useful logic from ZYLVE, DINX, CUBSHIP. Current work has started bounded G0 implementation; it has not yet implemented the native graphics/audio engine.

## Pinned research identities

- Kof4j: `22a186b9bf9df37c03809ba6ef4af85085386f63`, VERSION `0.4.9-beta`.
- Executed release: `kof-0.4.9-beta-linux-x86_64`, published 2026-09-20; standalone jar SHA-256 `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`.
- Kof Editor: `bed6ae7d567b090497a447583a10b8522acaf66a`, VERSION `0.1.4-beta`; now installed with a project-restricted, network-isolated launcher and visually verified in private X11.
- Do not infer release state from README 0.4.0 or website 0.4.1. Source SHA and release jar are separately identified, not assumed byte-equivalent.
- Complete course: [`lunalully/curso-completo-de-kof@d6fc8318e77f30ab0d6be87055d86a7eb63960d3`](https://github.com/lunalully/curso-completo-de-kof/tree/d6fc8318e77f30ab0d6be87055d86a7eb63960d3), baseline 0.3.7-beta. [Official portal](https://koflang.github.io/docs) snapshot was generated 2026-09-17; several pages differ from pinned compiler source. See [KOF_COURSE](docs/KOF_COURSE.md).
- Minecraft Java26.3, released2026-09-15; exact version-metadata SHA-1 `96c00d95a31328714d3811cfade2804bb050e455`. Uses SDL3/LWJGL3.4.3 and JOML1.10.9; source/version/license matrix in [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Temporary research clones/jars were under `/tmp/kookie-*`; not project dependencies. Durable evidence and full probe sources live in [RESEARCH_PROBES](docs/RESEARCH_PROBES.md), [COURSE_PROBES](docs/COURSE_PROBES.md) and [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Active CLI is now a source-built local tooling repair, not the original research release: JAR SHA-256 `9a4c133d773058a0ea3b3bf503511439e67bbb8efb80a2d5ab848dbc8274b548`. Persistent compiler/editor/client sources, Maven 3.9.16, installation paths, protocol fixes and verification boundaries are documented in [KOF_EDITOR](docs/KOF_EDITOR.md#local-installation). Existing OpenJDK 27 and native prerequisites were reused. No native runtime/engine repair is implied.

## Proposed decisions

- Native Linux x86-64 first; JVM differential oracle. Additional OS/architectures not promised.
- SDL3 + SDL_GPU, first Vulkan/SPIR-V; thin checked scalar ABI adapter until Kof buffer FFI exists. SDL3 3.4.16 was installed for the version-query probe; graphics was not tested.
- One Kof simulation thread; 60 Hz tick, independently interpolated rendering, four-step catch-up proposal.
- Typed component arrays + generation IDs, true-3D capsule/BVH collision, one damage/death/reward authority.
- Kof-owned renderer policy, content cooker, game UI and creator tooling; HLSL/GPU shader exception explicit.
- Full looter/ARPG systems are milestone G3, not dropped after a boomer-shooter demonstration. Creator workflow is G4. See plan for exact scope/acceptance.
- No automatic JVM fallback, no hidden C engine, no editor fork prerequisite.

## Facts not to forget

1. Functions use `Int f(Int x)` / `f(Int x): Int`, **not fun/fn**. `record` and `class X(...)` are immutable/record-style; mutable classes use fields + explicit constructor. No top-level ordinary variables, array literals or Kotlin safe-call/coalesce assumptions.
2. `.kf` modules/imports work. Measured directory import on JVM/native; `run` collects siblings and rejects multiple `main()` functions (`PKG002`). Separate application entry scopes.
3. Native **scalar** `extern` works now; old blanket “native FFI unsupported” claims are stale. Measured sqrt → `3.0`, SDL_GetVersion → `3004016` on both targets.
4. `extern upload(Float[])` → `FFI001` on both measured targets. Structs/pointers/out-buffers/variadics and native callbacks are outside the supported scalar gate. Integer resource IDs must be real adapter registry tokens, not pointer casts.
5. Native x86 collector's automatic path is gated by **cumulative `kof_spawn_count == 0`**. Awaiting a task does not reopen it. Do not bypass by unsafe manual GC. Library threads must never retain/call Kof heap state.
6. Packaged native execution warned runtime pruning cannot find `NativeRuntime.java` outside compiler module; full-runtime fallback ran. Tiny upstream binary-size claims are not verified for this release path.
7. Native compiler optimization is limited; JVM JIT may outperform it. No engine FPS/memory/graphics readiness was measured.
8. `kof.gpu` is specialized matrix compute, not a 3D graphics engine. Kof Canvas is browser-oriented; WebKitGTK/Jaylib native windows do not imply native ELF execution.
9. Upstream raylib-shaped `InitWindow` FFI test uses a printing C fixture, not a real window. Our SDL version query likewise proves only its exact call.
10. Course-driven probes passed overload/default/nested-capture examples, 2D Int arrays, direct floating-point record getters, Double math, both reduce argument orders, and zero-versus-missing map values on JVM/native.
11. Binary `File.writeBytes/readBytes/readRange` preserved `00 7f 80 ff` on both. This proves a tiny instance-API path, not bulk FFI, large-file behavior or atomic save durability.
12. Native mixed Int/Double/String record JSON was wrong: encoded 1.25 as 0.0, decoded wrong Double/empty String; JVM round-trip passed. Gate native persistence/content JSON on repair and schema-specific proof.
13. Native `split` is not JVM regex splitting: escaped pipe gave one element versus three. Avoid assuming shared parser semantics.
14. Critical native handler defect: after a normal try/catch, a later failed assertion re-entered that catch and exited 0. Source lowering jumps past `KofTryEnd`. A bare false assertion fails correctly. Do not institutionalize a control-flow workaround; fix/revalidate the compiler before relying on exception cleanup/tests.
15. Native bounds errors terminate without catch/finally; explicit String throw/return cleanup passed the narrower probes. Validate indices and adapter inputs before access; assertions are catchable language throws, not an independent test-failure channel.
16. JOML1.10.9 from Minecraft26.3 worked with Kof JVM `--deps`: vector length/dot and matrix translation printed `5.0,25.0,5.0,4.0`. Same source/native rejected both Java imports with `PKG006`. This proves the narrow Java math path, not JNI/graphics or native JAR use.
17. Authoritative broad-phase snapshots now traverse a fixed-capacity validated transport queue; overflow rejects without dropping queued payloads, then dequeue/apply updates client geometry with sequence guards.
18. Headless GPU smoke now covers overlap depth two and clean device recreation with cached-resource rebuild; actual device-loss callbacks and retirement remain unimplemented.
19. Native UDP transport uses authenticated SipHash framing over a fixed 78-word
payload, requires explicit non-zero key provisioning before open, and exposes an
atomic `kookie_transport_open_remote_ipv4` bind for validated peer address/port;
it validates protocol/length/sequence with signed integer preservation and a
1,000 ms receive timeout; production key management remains unimplemented.
20. GPU recovery now exposes unavailable/ready/lost/failed state transitions and rejects recovery without a live headless device; loss notification is an explicit probe marker, not an SDL device-loss callback.
21. A claimed GPU window now requires a valid swapchain format through the present-capability probe; the Xvfb path still cannot claim DRI3 presentation.
22. The native transport can bind paired localhost UDP sockets or atomically
open a configured IPv4 peer, requires a test SipHash key before exchanging
authenticated frames, then clears key material on close; production key
management remains unimplemented.
23. GPU recovery capability reporting is state-aware: ready exposes clean reopen plus the explicit loss marker, lost exposes reopen only, and unavailable/failed expose no capabilities; SDL3 exposes no device-loss callback in the installed GPU API.
24. `RemoteSessionEndpoint` validates IPv4/port and non-zero SipHash keys, freezes peer/key mutation while active, permits key changes only while inactive, and is bound to both the environment key boundary and a live external UDP peer smoke; session orchestration and production secret storage remain unimplemented.


## Editor cautions

See [KOF_EDITOR](docs/KOF_EDITOR.md). Interactive UI is substantially authored JS inside `.kf`; independent scanner, not compiler frontend reuse. Run copies active file to fixed temp root and hardcodes JVM. No actual LSP/DAP client integration found. Host filesystem/shell endpoints unrestricted and unauthenticated.

With inspected compiler, source `web.sh` omits host and legacy handler serves on default `0.0.0.0`. Explicit `--host 127.0.0.1` applies to **legacy handle mode**, not `web.app()+main` mode; loopback is still not authorization/Origin protection. Prefer isolated scratch use, not monorepo Git/Run actions. Old native scanner R1 is explicitly closed in editor's own historical ledger.

## Game evidence

- **DoomKof:** source-published raycaster, `.kf` gameplay; desktop JVM Jaylib JNI 5.5.0-2/raylib, alternate browser Canvas+JS. Source license not established. No verified native-ELF release.
- **Byte Eater / kofman:** source-published MIT browser game, KofJS/kof.ui Canvas, JVM web backend, authored JS keyboard bridge.
- **Pong:** raylib demo reported/video-linked in Kof4j issue #431; game source and exact execution target not verified.
- Builtin Tetris is Java-runtime terminal game; KofOS game list is unported plans.
- Search did not establish a shipped native Kof shooter or ready SDL/Sokol binding package. This is bounded negative evidence, not proof none exists.

## Borrowing map

- DINX: controller intent/jump policy, generation-safe handles, exact render-batch identities/order barriers, revision/neighbor-presence admission.
- ZYLVE: item identity, atomic item/currency/RNG transactions, skill/status semantics, fixed-step input edges, render queue/spatial hash, staged live-edit publication.
- CUBSHIP: isolated SAT geometry, weapon/damage transition contracts, bounded AI search and sectioned saves.
- Do **not** inherit endpoint-only “sweep,” waist-ray player collision, fixed tiny loot pools/silent drops, duplicate weapon authorities, raw ECS IDs in saves, event playback mislabeled deterministic replay, or corpus inspectors mislabeled map cookers.
- DINX MIT; ZYLVE whole-game private/internal notice; CUBSHIP README MIT claim lacks complete inspected notice packaging. User permission does not clear third-party assets. Capture source revision/hash and licenses at port time.
- Minecraft: not a conventional archetype ECS. Borrow definition/instance separation, item override patches, validated codecs, extraction snapshots and audio voice lifecycles. Prioritize JOML/Brigadier MIT subsets, Artemis/Ashley storage contracts, owo layout and Flywheel instance lifecycles; see [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Recommended library set: SDL3/SDL_GPU; offline SDL_shadercross/DXC; OpenAL Soft for production FPS audio (SDL3_mixer is the basic-spatial alternative); SDL3_image for image decoding; FreeType/HarfBuzz for text services; zstd for cooked packages. G0 remains SDL-only with queued audio. Full boundaries, local availability, licenses and adoption gates are in [ENGINE_PLAN](docs/ENGINE_PLAN.md#recommended-library-set-2026-09-22).
## Next action and proof boundary

G0 GPU proof accepts an isolated offscreen SDL_GPU indexed textured quad,
explicit vertex/index-buffer uploads, SPIR-V draw submission, per-device cached
GPU resources, and fence-wait telemetry through a render node. The latest smoke
measured 1675 microseconds for three draws against the declared 16,667-
microsecond 60 Hz frame budget on `renderD128`, including a 527-microsecond
fence-wait sample. An overlap probe submitted four frames across two target
slots, retired all fences, and observed peak in-flight depth two. Clean device
recreation rebuilt cached resources and completed a post-recovery draw. The
window path still reports `gpu-unavailable` because Xvfb lacks DRI3 presentation
support; a capability probe reports swapchain format and present modes when a
window device is claimable. G1 now also has bounded six-vertex frame staging,
deterministic triangle collection/BVH queries with removal/rebuild and geometry
revisions, authoritative capsule slide/step traversal over eight ordered
bounded obstacles, clear/reconfigure operations, bounded broad-phase transport
snapshots with fixed-capacity dequeue/apply and sequence guards, a native
authenticated UDP peer probe across paired localhost sockets with a validated
`RemoteSessionEndpoint`, atomic native IPv4 peer opening, configurable peer/port
and SipHash test keys, sequence/length validation, signed payload words, and a
1,000 ms receive timeout, explicit GPU recovery states plus reporting for clean
paths and closed-device rejection, stale query rejection, and spatial movement
admission combining capsule and broad-phase collisions. Next: add a DRI3-capable
isolated presentation path, integrate authenticated frames with a live remote
session and production secret storage/rotation, add actual SDL/device-loss
callbacks/resource retirement, and rerun the native exception reproducer after a
compiler upgrade. The native exception-handler defect remains a compiler gate.

Earlier research evidence: original core/import/scalar-FFI probes, 18
course-driven programs (36 runs, two checks), and the JOML JVM success/native
import-rejection pair. Complete sources/results are in the linked research
documents. Those research probes were JVM/native x86 only, with no
games/editor/server or graphics launched. Later installation verification
exercised compiler CLI, LSP/DAP and the actual isolated editor/server; it did
not verify the engine graphics stack or run a full suite.

All graphical checks use `overzeer-isolated-display` or reviewed equivalent with private sockets, timeout and process cleanup; never the developer desktop. Full matrix only final pre-commit with user permit. Research docs and local tooling/configuration are delivered; no sibling engine/game source/assets were modified or copied.
