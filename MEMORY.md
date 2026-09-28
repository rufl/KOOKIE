# KOOKIE working memory

Bounded foundations execute; G0 and G1 acceptance gates are complete.

## Current qualification batch

- `G1Demo` is the single executable G1 acceptance path on JVM and native. It
  covers a 60 Hz authoritative server, two loopback clients, observable
  prediction correction/reconciliation, one player weapon/enemy kill and
  focus-loss recovery.
- `G1Arena` owns 78 vertices/26 triangles for lower floor, ramp, upper
  platform, two stair steps and stacked rooms. Server snapshots include
  explicit bounds and all triangles; client upper/lower-floor queries pass.
- World plus numeric HUD staging uses 96 fixed vertices. The native SDL_GPU
  bridge owns persistent scene buffers; an isolated GPU run produced a 320×240
  P6 frame. Sixty-four deterministic stages retained the original Kof
  capacities.
- Contact sweeps reuse their offset array. Replay sidecars now hold 1,296 words,
  covering the 32-triangle state plus bounded presentation history.
- JVM/native checks, identical G1 runtime markers and 71/71 tests pass on each
  target.
- G0 remains closed: isolated presentation and authenticated external-LAN
  evidence pass. Operational host identities, addresses, fingerprints,
  deployment identifiers and raw evidence remain outside the repository.
- The JVM/native three-process G2 regression transports all 26 authored arena
  triangles, preserves stacked-room collision, uses versioned checksummed
  interaction/state messages, reaches terminal server-owned combat death and
  revision-4 key/door/secret/exit completion, and rejects stale input.

## Previous batch
- Fixed native inventory/triangle checkpoint padding, actual consumed movement ticks, held input across seeks and whole-record replay forwarding. Eighteen focused scenarios and 20 affected regressions passed on JVM/native; no local full matrix ran.
- A native high-arity call forwarding record getters dropped the fire argument in a focused reproduction. Replay now queues the existing `InputCommand` instead of reconstructing a wide call; no compiler repair is claimed.
- Loopback host lifecycle preserved player position and input sequence watermarks across reconnect, cleared pending commands and rejected stale input; this was local prerequisite coverage before the external bundle above closed the gate.
- Remote session reconnect preserved broad-phase send/receive watermarks across close/reopen; the native authenticated UDP probe resumed at sequence 9 and rejected older snapshots. The current qualification batch now supplies the formerly missing two-client external proof.
- Linux x86-64 has reproducible internal dogfood archives for native Kof and
  executable-JAR JVM runtimes, plus a Windows JVM external-LAN role archive.
  Windows native Kof/PE packaging remains fail-closed: no Kof Windows target,
  PE/runtime proof or signing inputs.
- Reproducible packages use project-owned provenance metadata. Deployment
  endpoint compatibility is kept outside this repository. KOOKIE has no public
  license.

## User intent

Build a boomer-shooter / looter-shooter / ARPG FPS engine with **native Kof `.kf` source for portable engine, game and tool logic**. External graphics/platform libraries and narrow ABI/shader code are allowed where genuinely needed. Borrow useful ideas from ZYLVE, DINX and CUBSHIP without hidden dependencies. Prefer larger coherent development batches with focused proofs; keep incomplete milestones explicit.

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
19. Native UDP transport uses authenticated SipHash framing over a fixed
300-word payload, enough for 32 bounded triangles, requires explicit non-zero
key provisioning before open, and exposes an atomic
`kookie_transport_open_remote_ipv4` bind for validated peer address/port. It
validates protocol/length/sequence with signed integer preservation and a
1,000 ms receive timeout; production key management remains unimplemented.
20. GPU recovery now exposes unavailable/ready/lost/failed state transitions and rejects recovery without a live headless device; loss notification is an explicit probe marker, not an SDL device-loss callback.
21. A claimed GPU window now requires a valid swapchain format through the present-capability probe; the Xvfb path still cannot claim DRI3 presentation.
22. The native transport can bind paired localhost UDP sockets or atomically
open a configured IPv4 peer, requires a test SipHash key before exchanging
authenticated frames, then clears key material on close; production key
management remains unimplemented.
23. GPU recovery capability reporting is state-aware: ready exposes clean reopen plus the explicit loss marker, lost exposes reopen only, and unavailable/failed expose no capabilities; SDL3 exposes no device-loss callback in the installed GPU API.
24. `RemoteSessionEndpoint` validates IPv4/port and non-zero SipHash keys, freezes peer/key mutation while active, permits key changes only while inactive, and is bound to both the environment key boundary and a live external UDP peer smoke; session orchestration and production secret storage remain unimplemented.
25. `RemoteSessionLink` gates broad-phase snapshots on endpoint activation and strictly increasing send/receive sequences; the native isolated probe sends and applies a snapshot through the link, while live session-loop orchestration remains unimplemented.
26. `BoundedRayTargetWorld` now performs bounded integer ray/pellet selection with nearest-hit and stable-ID tie ordering, source exclusion through `SpatialAimContract`, and target removal. `CombatWorld.resolveShotgunPelletTargets` and the session wrappers preserve one selected target per pellet, including repeated hits and bounded misses. `LoopbackSession.resolvePlayerSpatialShotgun` now connects that selection to authoritative player combat.
27. Native SIMD dispatch now selects AVX2/SSE2 on x86, has an AArch64 NEON source path and keeps a checked scalar fallback. `FFI001` still prevents Kof bulk-buffer integration, so this is not a measured engine speedup.
28. The current focused source gate is 63 JVM/native tests, plus Kof lint/LSP and the SIMD host/scalar/AArch64 proof. See [CHANGELOG](CHANGELOG.md) for the short human-readable history.

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

G1 proves the bounded authoritative shooter path, not a finished game:
server→loopback→client simulation, second-client admission, reconciliation,
focus-safe input, authored 3D contact, camera/HUD extraction and native SDL_GPU
render/readback all execute. The no-per-frame-growth claim is limited to
unchanged staging capacities across 64 deterministic frames and persistent
native scene buffers; it is not a 30-minute RSS/performance result.

G2 now has a qualified transport slice: host plus two clients exchange the
complete G1 arena and checksummed gameplay commands/state through server-owned
combat death and key/door/secret/exit completion on JVM and native. Closing G2
still requires replicated player/enemy simulation and rewards, bounded
join/leave/reconnect diagnostics, complete 3D door collision/render geometry,
and integrated feedback/audio. G5 retains sustained workload, RSS and
frame-budget acceptance. `FFI001` still blocks Kof bulk-buffer calls into the
optional SIMD kernel.

Earlier research evidence: original core/import/scalar-FFI probes, 18
course-driven programs (36 runs, two checks), and the JOML JVM success/native
import-rejection pair. Complete sources/results are in the linked research
documents. Those research probes were JVM/native x86 only, with no
games/editor/server or graphics launched. Later installation verification
exercised compiler CLI, LSP/DAP and the actual isolated editor/server; it did
not verify the engine graphics stack or run a full suite.

All graphical checks use a reviewed wrapper configured through `KOOKIE_PRESENTATION_ISOLATION_WRAPPER`, with private sockets, timeout and process cleanup; never the developer desktop. Full matrix only final pre-commit with user permit. Research docs and local tooling/configuration are delivered; no sibling engine/game source/assets were modified or copied.
