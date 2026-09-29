# KOOKIE working memory

Bounded foundations execute; G0, G1, G2 and G3 acceptance gates are complete, and G4 has its first transactional vertical slice.

## Current qualification batch

- `G1Demo` is the single executable G1 acceptance path on JVM and native. It
  covers a 60 Hz authoritative server, two loopback clients, observable
  prediction correction/reconciliation, one player weapon/enemy kill,
  focus-loss recovery and confirmed kill feedback reaching HUD plus queued
  audio.
- `G1Arena` owns 78 vertices/26 triangles for lower floor, ramp, upper
  platform, two stair steps and stacked rooms. Server snapshots include
  explicit bounds and all triangles; client upper/lower-floor queries pass.
- World, door and semantic HUD staging uses 486 fixed vertices: 78 arena, 36
  door and 372 HUD vertices for framed health/ammo tracks, structural icons, a
  shape-distinct connection glyph, active/reserve encounter load, a
  focus-responsive crosshair, hit/kill markers, edge damage warnings,
  inventory/equipment/skill/world-loot state, shape-distinct elite/boss cues
  and a creator source→validation→publication rail. Feedback expires by
  simulation tick and rejects duplicate event sequences. The native SDL_GPU
  bridge owns persistent scene buffers and a 16-color semantic palette;
  no-per-frame-growth proof remains bounded to unchanged staging capacities.
- Contact sweeps reuse their offset array. Replay sidecars now hold 1,296 words,
  covering the 32-triangle state plus bounded presentation history.
- The prior 77-scenario JVM/native source gate passed. The new GameShell
  end-to-end scenario and both target checks pass; the full source matrix was
  not rerun locally without the pre-commit permit.
- G0 remains closed: isolated presentation and authenticated external-LAN
  evidence pass. Operational host identities, addresses, fingerprints,
  deployment identifiers and raw evidence remain outside the repository.
- The JVM/native three-process G2 regression transports all 26 authored arena
  triangles, unified checksummed gameplay commands and bounded authoritative
  encounter state. Clients apply enemy ID/state/target/health/position, active
  and reserve counts, and the latest confirmed impact. The qualified path
  proves terminal enemy state `7`, health `0`, impact sequence `2`, 25 currency,
  revision-4 key/door/secret/exit completion, reconnect generation two and
  explicit stale diagnosis.
- G3 is closed at its current acceptance gate. Enemy death owns deterministic
  rolled world loot, remote pickup/equip/progression admission,
  equipment/status combat modifiers and boss loot/XP/currency. Checksummed
  state kinds 7/8 replicate complete per-player authority and world drops
  through loopback and same-host JVM/native external processes; save section 12
  preserves drops and reward claims. Separate-host execution remains unproven.
- G4 is in progress. Its published compatibility identity now binds a sealed
  package, extension manifest, trusted-hook implementation/version, enemy
  definitions and aligned geometry/collision/navigation/replication products.
  A generation/checksum-bound runtime executes the compiled elite-bounty hook
  after authoritative death, preflights budgets/capacity and applies its
  currency command exactly once. Stale or invalid state retains prior output.
  Remaining source formats, the broader hook/event surface, external package
  loading, editor tooling, live staged reload and transport qualification are
  open.

## Latest implementation batch

- Replaced the Windows color-matrix/JVM launch split with one persistent native
  SDL3 + SDL_mixer shell. Its resizable high-DPI window, old-school main menu,
  display/audio/text options and SipHash-tagged host/join/leave lobby match the
  Kof-owned Linux shell contract. Windows remains a platform shell rather than
  proof of Kof gameplay because the compiler has no PE target.
- The Linux presentation now starts at a persistent Kof main menu and keeps
  the bounded G1 scene behind Play. SDL_mixer owns distinct effects/music
  streams; the adapter remains scalar, token-checked and allocation-free on
  queue submission.
- KOOKIE is MIT. Distributable packages contain only reviewed permissive
  components and host system APIs: SDL 3.4.16 and SDL_mixer 3.2.4 are zlib.
  Linux no longer bundles its loader/libc, Windows no longer embeds a JDK, and
  distributable JVM packaging fails closed.
- Focused isolated Wine runs visually verified main/options/multiplayer and
  exercised resize, maximize and restore. The packaged executable loaded the
  pinned SDL versions and exited its non-graphical smoke cleanly. An isolated
  X11 adapter run verified the Linux resizable-window contract; this host could
  not provide a private SDL_GPU presentation backend for the new Linux menu.

### Trusted-hook execution batch

- Extended `BoundedTrustedModuleRegistry` so every declaration must bind a
  supported static implementation ID and binary version before sealing; both
  values participate in compatibility identity.
- Added `BoundedTrustedHookRuntime` with monotonic ticks, deterministic phase
  order, published generation/checksum binding, per-hook budgets, global
  capacities and atomic rejection diagnostics.
- Added exactly-once authoritative hook-command application to
  `LoopbackSession`; invalid recipients, unsupported commands and aggregate
  currency overflow preserve session state.
- `G4CreatorDemo` now consumes its published module: a confirmed elite death
  executes the bounty hook, emits a typed event and grants four currency above
  the definition-owned reward.

### Prior creator-publication batch

- Added `BoundedTrustedModuleRegistry`: at most 32 static hook declarations,
  each tied to a manifest capability/contribution, phase and bounded
  command/event budgets, sealed in dependency/load/priority order.
- Added `BoundedCreatorPublication` and `BoundedContentCompatibility`: a
  revision-checked transaction binds package, extension, hook, definition and
  four product checksums; a 13-word wire identity rejects API/network/content
  mismatches, and failed publication leaves the active generation intact.
- Added `G4CreatorDemo`, a distinct two-player extension/definition-driven
  elite encounter using public engine APIs. Its deterministic death publishes
  encounter, player-authority and world-loot state.
- Extended the HUD to 372 fixed vertices with a structural
  source→validation→publication rail and separate success/failure marks.
  Creator/threat staging now uses small fixed-coordinate helpers so native and
  JVM structural vertices remain exact. The full scene remains below the native
  512-vertex capacity at 486 vertices.
- Existing `BoundedExtensionRegistry` and `BoundedEnemyDefinitionRegistry`
  remain the manifest and data-definition foundations used by G1, G3, the
  external transport probe and the new creator transaction.
- That batch's focused source gate was 77 JVM/native scenarios; Kof checks,
  lint and LSP passed. Isolated Wayland SDL_GPU presentation passed at 320×240
  with present capability `11`, an 11,270 µs draw and frame checksum
  `30,358,034`; visual review found no clipping or overlap in the
  creator/threat panels. The full
  repository matrix was not run locally.

## Earlier batches
- Fixed native inventory/triangle checkpoint padding, actual consumed movement ticks, held input across seeks and whole-record replay forwarding. Eighteen focused scenarios and 20 affected regressions passed on JVM/native; no local full matrix ran.
- A native high-arity call forwarding record getters dropped the fire argument in a focused reproduction. Replay now queues the existing `InputCommand` instead of reconstructing a wide call; no compiler repair is claimed.
- Loopback host lifecycle preserved player position and input sequence watermarks across reconnect, cleared pending commands and rejected stale input; this was local prerequisite coverage before the external bundle above closed the gate.
- Remote session reconnect preserved broad-phase send/receive watermarks across close/reopen; the native authenticated UDP probe resumed at sequence 9 and rejected older snapshots. The current qualification batch now supplies the formerly missing two-client external proof.
- Linux x86-64 has reproducible native Kof and SDL presentation archives. The
  Windows x86-64 archive is a native SDL shell with no Java runtime; the
  Windows JVM external-LAN role bundle remains qualification tooling only.
  Kof-authored Windows PE gameplay remains blocked by the absent compiler
  target, not hidden behind the platform shell.
- Reproducible packages use project-owned provenance metadata, include MIT and
  zlib notices and reject unreviewed distributed runtime libraries. Deployment
  endpoint compatibility remains outside this repository.

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

- Native Linux x86-64 is the authoritative Kof gameplay target; JVM is a local
  differential oracle. The native Windows platform shell is supported, but
  Windows Kof gameplay waits for a compiler PE target.
- SDL 3.4.16 + SDL_GPU with Vulkan/SPIR-V is the graphics boundary; SDL_mixer
  3.2.4 owns effects/music buses. The scalar ABI adapter remains until Kof
  buffer FFI exists.
- One Kof simulation thread; 60 Hz tick, independently interpolated rendering, four-step catch-up proposal.
- Typed component arrays + generation IDs, true-3D capsule/BVH collision, one damage/death/reward authority.
- Kof-owned renderer policy, content cooker, game UI and creator tooling; HLSL/GPU shader exception explicit.
- Full looter/ARPG systems are milestone G3, not dropped after a boomer-shooter demonstration. Creator workflow is G4. See plan for exact scope/acceptance.
- No automatic JVM fallback, no hidden C gameplay engine, no editor fork prerequisite.

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
24. `RemoteSessionEndpoint` validates IPv4/port and non-zero SipHash keys, freezes peer/key mutation while active, permits key changes only while inactive, and is used by live host/client role orchestration; production secret distribution remains external.
25. `RemoteSessionLink` gates snapshots on endpoint activation and strictly increasing send/receive sequences. JVM/native three-process qualification carries gameplay, feedback and encounter state through the real session loop.
26. `BoundedRayTargetWorld` now performs bounded integer ray/pellet selection with nearest-hit and stable-ID tie ordering, source exclusion through `SpatialAimContract`, and target removal. `CombatWorld.resolveShotgunPelletTargets` and the session wrappers preserve one selected target per pellet, including repeated hits and bounded misses. `LoopbackSession.resolvePlayerSpatialShotgun` now connects that selection to authoritative player combat.
27. Native SIMD dispatch now selects AVX2/SSE2 on x86, has an AArch64 NEON source path and keeps a checked scalar fallback. `FFI001` still prevents Kof bulk-buffer integration, so this is not a measured engine speedup.
28. The historical G3 focused gate was 75 JVM/native tests, plus Kof lint/LSP
    and the SIMD host/scalar/AArch64 proof. See [CHANGELOG](CHANGELOG.md) for
    current focused verification.
29. Accepted authoritative impacts enter bounded monotonic presentation/audio
    history and ordered `6 + 11F` feedback batches. Whole-message validation,
    duplicate/gap rejection and generation baselines prevent partial or stale
    presentation without rolling back authoritative damage.
30. Host encounter state uses a dynamic checksummed `20 + 8N`-word message,
    bounded to 32 enemies and the shared 300-word transport capacity. Each
    entry replicates stable ID, role, state, target, health and 3D position.
31. G2 is complete: continuous hitscan/projectile/shotgun roles,
    unacknowledged-input prediction replay, generation-safe join/recovery, 3D
    door segment/AABB collision plus 36-vertex rendering, full feedback
    recovery and Kof-owned attenuation/stereo pan submitted through SDL.
32. G3's public content boundary is a bounded immutable registry, not a plugin
    ABI: manifests declare versions, dependencies, capabilities, load order,
    migrations, network schema and provenance; contributions and elite/boss
    definitions fail closed before session start. Trusted module hooks, cooker
    output and staged reload remain G4.


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
- Recommended expansion set: SDL3/SDL_GPU; offline SDL_shadercross/DXC; optional OpenAL Soft when later HRTF/Doppler/EFX requirements exceed the implemented G2 SDL stereo path; SDL3_image for image decoding; FreeType/HarfBuzz for text services; zstd for cooked packages. Full boundaries, local availability, licenses and adoption gates are in [ENGINE_PLAN](docs/ENGINE_PLAN.md#recommended-library-set-2026-09-22).
## Next action and proof boundary

G1 proves the bounded authoritative shooter path, not a finished game:
server→loopback→client simulation, second-client admission, reconciliation,
focus-safe input, authored 3D contact, camera/HUD extraction and native SDL_GPU
render/readback all execute. The no-per-frame-growth claim is limited to
unchanged staging capacities across 64 deterministic frames and persistent
native scene buffers; it is not a 30-minute RSS/performance result.

G2 is complete: host plus two clients exchange recipient-specific gameplay
baselines, ordered feedback batches and continuous multi-role encounter state.
Clients predict movement, replay unacknowledged inputs on reconciliation and
reset epochs after reconnect; the interaction, process and isolated SDL probes
pass.

G3 remains complete at its current gate, and all 78 source scenarios now pass
on JVM/native. Server-owned kill→rolled drop→pickup/equip→observable damage/skill
change→boss reward→schema-file save/reload executes without client-authored
outcomes or duplicate rewards. State kinds 7/8 traverse authenticated same-host
host-plus-two-client processes on both targets. Bounded public manifests,
capabilities and deterministic contributions now instantiate complete sealed
elite/boss rules atomically. Separate-host execution is unproven; G4 remains
the complete cooker/source intake, broader trusted-hook/domain-event surface,
external package loading, editor transactions, GPU-safe staged reload and
compatibility-handshake transport. G5 retains sustained workload, RSS and
frame-budget acceptance; `FFI001` still blocks Kof bulk-buffer calls into the
optional SIMD kernel.

Earlier research evidence: original core/import/scalar-FFI probes, 18
course-driven programs (36 runs, two checks), and the JOML JVM success/native
import-rejection pair. Complete sources/results are in the linked research
documents. Those research probes were JVM/native x86 only, with no
games/editor/server or graphics launched. Later installation verification
exercised compiler CLI, LSP/DAP and the actual isolated editor/server; it did
not verify the engine graphics stack or run a full suite.

All graphical checks use a reviewed wrapper configured through `KOOKIE_PRESENTATION_ISOLATION_WRAPPER`, with private sockets, timeout and process cleanup; never the developer desktop. Full matrix only final pre-commit with user permit. Sibling source changes are limited to ZEER's KOOKIE deployment descriptor; no sibling engine/game source or assets were copied.
