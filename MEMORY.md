# KOOKIE working memory

Bounded foundations execute; the G0–G6 implementation gates are complete within the qualification limits below. The D1 player-facing demo release is still open.

## Current qualification batch

- `G1Demo` is the single executable G1 acceptance path on JVM and native. It
  covers a 60 Hz authoritative server, two loopback clients, observable
  prediction correction/reconciliation, one player weapon/enemy kill,
  focus-loss recovery and confirmed kill feedback reaching HUD plus queued
  audio.
- `G1Arena` owns 142 unique vertices/178 triangles across a 320 by 280
  footprint: interconnected corridors, L-shaped cover and a raised room.
  Server snapshots include explicit bounds and all triangles; client
  raised-room/corridor/cover queries pass.
- World, door and semantic HUD staging uses persistent bounded capacities for
  the expanded arena, door cuboid, animated animals and HUD. The native
  SDL_GPU bridge owns persistent scene buffers and a 16-color semantic
  palette; no per-frame-growth proof remains bounded to unchanged staging
  capacities.
- Contact sweeps reuse their offset array. Replay sidecars now hold 1,296 words,
  covering the 32-triangle state plus bounded presentation history.
- The retained 84-scenario qualification baseline passed on JVM and native;
  three later focused Blockbench, PNG and WAV intake scenarios also pass on
  both targets. The current focused source qualification suite totals 94
  scenarios on JVM and native. The full repository matrix was not run without
  the pre-commit permit.
- G0 remains closed: isolated presentation and authenticated external-LAN
  evidence pass. Operational host identities, addresses, fingerprints,
  deployment identifiers and raw evidence remain outside the repository.
- The JVM/native three-process G2 regression transports all 178 authored arena
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
- G4 is complete for its bounded contract. Typed hook subscriptions cover
  session/player/enemy/loot/editor publication; the kooker admits the documented
  GLB, Dust3D, Aseprite, VOX, convex brush, Blockbench 5.0, PNG, PCM WAVE and
  OGG Vorbis subsets through the developer JVM CLI and packaged Linux native
  intake CLI; `.kpkg` reload validates candidate package/registry state before
  swap; the Kutter workspace provides inspection, edits, play-in-editor and
  bounded undo/redo; and GPU products activate at a frame boundary only after
  their upload fence. An 18-word offer and 7-word response transport the exact
  13-word compatibility identity through authenticated remote-role transport
  before gameplay. That handshake passed with host and clients in three
  isolated Linux network namespaces and distinct IPv4 stacks. General format
  compatibility, arbitrary code/shader reload, a production editor and fresh
  qualification on three physical machines are outside this claim.

## Fixed-tick netcode batch

- The current session protocol sends up to three ordered inputs per fixed tick,
  carries the latest snapshot ACK and retires history only after an authoritative
  input ACK. Typed input bundles/ACKs validate checksums and reject stale or
  out-of-order state.
- The snapshot window accepts a higher state sequence at the same tick and
  replaces the latest sample without opening an interpolation gap; older ticks
  or sequences remain rejected. Checkpoint restore clears rewind samples from
  the discarded future before the next tick.
- The authenticated native transport pins the admitted peer endpoint after the
  handshake. It remains a bounded authenticated UDP envelope with
  QUIC-inspired channel semantics, not QUIC/TLS or a production relay.
- The host retains 12 ticks of authoritative position history and derives
  hitscan rewind from acknowledged snapshot lag. Remote players render six
  ticks behind the live tick; prediction exposes deterministic correction
  count/average/maximum metrics.

## G5 completion batch

- Release and CI now build exact Kof 0.5.0-beta source commit `bf17ac7e7364`.
  Supplied upstream evidence covers `Buffer(U8, INOUT)` on native x86-64 and
  supported cross paths; KOOKIE does not rerun that matrix. KOOKIE's packaged
  JVM/native benchmark now validates the exact buffer ABI and `u8` reduction.
  One recorded native batch reduced 64 MiB in 233,350,224 ns in Kof scalar code
  and 1,073,834 ns through AVX2; this is not a gameplay speedup claim.
- The complete bounded scene has 192 authored vertices, 64 loaded collision
  triangles, 64 enemies, 256 projectiles, 512 pickups, 24 lights and 64 effects.
  The 30-minute 60 Hz soak kept simulation p95 at 3.202 ms and RSS within
  128 KiB after warm-up.
- The latest focused native dedicated-server gate uses the same bounded
  128-warm-up/512-measured window as package qualification and records
  p50/p95/p99/max `3.805/3.925/3.958/4.936 ms`, checksum `217802`, resource
  signature `520690`, and 64 KiB RSS growth/range. The scalar enemy step,
  target-position cache, batched loot checksum and batched scene checksum
  preserve JVM/native parity.
- Two authenticated same-host clients receive the complete state every tick.
  Four-chunk assembly is transactional and checksum-gated; client B reconnects
  at generation 2 without accepting rollback.
- SDL_GPU submits 984 hardware triangle instances in one draw. On the recorded
  Intel Arrow Lake Vulkan 26.2.3 device, 600 1920×1080 frames measured
  p50/p95/p99/max 0.304/0.645/0.845/1.089 ms; visual readback passed.
- Crash-durable save publication, multi-step migrations, checksummed
  identity-bound replay v3 and clean-tree Ed25519 release signing close bounded
  G5. `BoundedSessionSaveCoordinator` remains the arbitrary-path Kof-first
  session boundary: it encodes level progression plus G3 authority,
  stages/loads/restores validated sections and discards interrupted staging.
  `BoundedHostSessionSaveCoordinator` is the PE-safe fixed-host boundary:
  Kof owns wire encoding, validation, migration and rollback; checked integral
  calls transfer bounded words to native schema-byte staging/read and durable
  publication without `File` or `String` FFI. The POSIX Kof gate, G7
  player-facing goose gate, `scripts/verify_pe_durable_save.sh` through
  generated PE/Wine and G0 presentation smoke prove stage → publish → confirm
  → fresh-session restore, including inventory. The G0 presentation owner
  publishes on gameplay exit/window close and restores on process start/re-entry;
  a dedicated-server save owner remains separate. Multi-machine/WAN and other
  hardware/OS performance remain unclaimed.
- Linux archives now build the same Kof content-kooker entry point natively.
  Package smoke exercises PCM WAVE and OGG Vorbis canonicalization, idempotent
  reopen, malformed-input rejection and a graphics-dependency denylist outside
  the checkout.

## Windows PE/SDL qualification batch

- The Windows PE backend now lowers the reachable current gameplay/presentation
  graph: classes/fields, objects, arrays, integral/Boolean/String values,
  control flow, printing, String indexing and integral FFI. Standalone output
  is console PE; library output exports `kookie_kof_gameplay_main`.
- The reproducible Windows native shell package links the complete reachable
  `src/` Kof object to the SDL3/SDL_mixer shell without Java. Its isolated Wine
  smoke passed the gameplay markers and `KOOKIE native Kof PE gameplay verified`.
- The reproducible presentation package links native Kof PE gameplay to the
  SDL3/SDL_mixer GPU adapter and retains SPIR-V/DXIL products. Its artifact gate
  passes; optional visual Wine smoke requires an isolated DRI3-capable GPU and
  is not inferred from the default Xvfb environment.
- The separate Windows JVM package remains a compatibility profile, not a
  fallback for native PE gameplay. Native PE remains AMD64/Windows-specific;
  floating-point IR, catchable exceptions and concurrency still fail closed
  with `PE001`.

## Public dogfood and playable-demo status

- The latest public artifact is
  [`0.1.0-dogfood.34`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.34),
  a signed Linux x86-64 presentation archive from source commit
  `4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`. It predates the current
  presentation, lobby/scoreboard and Windows PE/SDL source path; no current
  Windows demo archive is public.
- The current presentation source now runs local `Play` through the bounded
  authoritative session: SDL keyboard/mouse input, three goose bots, damage,
  nameplates, 20-point hearts, HUD state and reset by leaving/re-entering
  `Play`.
- `Host/Join` now owns fixed two-player admission, explicit ready/unready
  gating and the host-authoritative `Tab` player screen. The lobby/scoreboard
  probe validates identity, lifecycle, capacity, checksum, stale/duplicate
  rejection, tamper rejection and deterministic ranking on JVM and native.
- D1 remains open for a current clean-tree Linux/Windows presentation pair,
  outside-checkout repeated play/restart/quit smoke, fresh-host/runtime-floor
  verification, native target-hardware presentation evidence and final release
  operations. Package-linkage or PE-marker success alone is not a playable-demo
  release.
- The default Linux system image lacks the SDL3_mixer development header. A
  temporary pinned SDL_mixer 3.2.4 prefix let
  `verify_linux_presentation_package.sh` pass signed artifact, safe extraction
  and package smoke on 2026-10-02. The isolated Xvfb/DRM visual smoke then
  reported `No DRI3 support detected` and `No supported SDL_GPU backend`, so no
  current Linux target-hardware presentation evidence is retained.
- The 2026-10-02 Windows presentation artifact gate passed with temporary
  pinned MinGW SDL3/SDL_mixer prefixes and DXC, including reproducible signed
  PE/SDL/SPIR-V/DXIL outputs. No native Windows hardware/input/audio/GPU
  evidence is retained.
- `scripts/build_demo_release.sh` produces two identical clean-tree
  presentation artifacts per target, and the approved paired workflow
  publishes them only after environment approval; the public release is still
  unchanged.

## Earlier platform-release batch

- The Windows presentation compatibility profile passed its prior reproducible
  signed package gate and isolated Wine smoke on a DRI3-capable host. The
  current presentation profile supersedes that JVM gameplay path with native
  Kof PE while retaining the separate JVM compatibility package.
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
- `G4KutterDemo` now consumes its published module: a confirmed elite death
  executes the bounty hook, emits a typed event and grants four currency above
  the definition-owned reward.

### Prior kutter-publication batch

- Added `BoundedTrustedModuleRegistry`: at most 32 static hook declarations,
  each tied to a manifest capability/contribution, phase and bounded
  command/event budgets, sealed in dependency/load/priority order.
- Added `BoundedKutterPublication` and `BoundedContentCompatibility`: a
  revision-checked transaction binds package, extension, hook, definition and
  four product checksums; a 13-word wire identity rejects API/network/content
  mismatches, and failed publication leaves the active generation intact.
- Added `G4KutterDemo`, a distinct two-player extension/definition-driven
  elite encounter using public engine APIs. Its deterministic death publishes
  encounter, player-authority and world-loot state.
- Extended the HUD to 372 fixed vertices with a structural
  source→validation→publication rail and separate success/failure marks.
  Kutter/threat staging now uses small fixed-coordinate helpers so native and
  JVM structural vertices remain exact. The expanded arena stages 534
  triangulated vertices; presentation capacities are derived from the active
  arena, door, HUD and overlay components.
- Existing `BoundedExtensionRegistry` and `BoundedEnemyDefinitionRegistry`
  remain the manifest and data-definition foundations used by G1, G3, the
  external transport probe and the new kutter transaction.
- That batch's focused source gate was 77 JVM/native scenarios; Kof checks,
  lint and LSP passed. Isolated Wayland SDL_GPU presentation passed at 320×240
  with present capability `11`, an 11,270 µs draw and frame checksum
  `30,358,034`; visual review found no clipping or overlap in the
  kutter/threat panels. The full
  repository matrix was not run locally.

## Earlier batches
- Fixed native inventory/triangle checkpoint padding, actual consumed movement ticks, held input across seeks and whole-record replay forwarding. Eighteen focused scenarios and 20 affected regressions passed on JVM/native; no local full matrix ran.
- A native high-arity call forwarding record getters dropped the fire argument in a focused reproduction. Replay now queues the existing `InputCommand` instead of reconstructing a wide call; no compiler repair is claimed.
- Loopback host lifecycle preserved player position and input sequence watermarks across reconnect, cleared pending commands and rejected stale input; this was local prerequisite coverage before the external bundle above closed the gate.
- Remote session reconnect preserved broad-phase send/receive watermarks across close/reopen; the native authenticated UDP probe resumed at sequence 9 and rejected older snapshots. The current qualification batch now supplies the formerly missing two-client external proof.
- Linux x86-64 has reproducible native Kof and SDL presentation archives.
  Windows x86-64 now has native Kof PE gameplay in the SDL3/SDL_mixer shell and
  native PE/SDL_GPU presentation package; the separate JVM external-LAN role
  bundle remains compatibility tooling only. The native-shell Wine smoke passed
  gameplay markers and the native PE marker.
- Reproducible packages use project-owned provenance metadata, include MIT and
  zlib notices and reject unreviewed distributed runtime libraries. Deployment
  endpoint compatibility remains outside this repository.

## User intent

Build a boomer-shooter / looter-shooter / ARPG FPS engine with **native Kof `.kf` source for portable engine, game and tool logic**. External graphics/platform libraries and narrow ABI/shader code are allowed where genuinely needed. Prefer larger coherent development batches with focused proofs; keep incomplete milestones explicit.

## Pinned research identities

- Current KOOKIE build toolchain: Kof `0.5.0-beta` source
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`; locally built Linux x86-64
  distribution SHA-256
  `f6fd41ed59c461dd968376e8e2dd3f0dc24ee712578d318a7fb3f707bc761bdc`
  and compiler JAR SHA-256
  `6634e1bf80334cc2518c50f9d1a05e2da92ff318282775ba58a087891e2420a6`.
  The prior official archive identity
  `f93f02eb62af584ea49ffb44efdbf54f970bdb9570f16fdc48ccc28242798ca9`
  predates the native Buffer contract and is no longer the KOOKIE build input.
- Kof4j: `22a186b9bf9df37c03809ba6ef4af85085386f63`, VERSION `0.4.9-beta`.
- Executed release: `kof-0.4.9-beta-linux-x86_64`, published 2026-09-20; standalone jar SHA-256 `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`.
- Kof Editor: `bed6ae7d567b090497a447583a10b8522acaf66a`, VERSION `0.1.4-beta`; now installed with a project-restricted, network-isolated launcher and visually verified in private X11.
- Do not infer release state from README 0.4.0 or website 0.4.1. Source SHA and release jar are separately identified, not assumed byte-equivalent.
- Complete course: [`lunalully/curso-completo-de-kof@d6fc8318e77f30ab0d6be87055d86a7eb63960d3`](https://github.com/lunalully/curso-completo-de-kof/tree/d6fc8318e77f30ab0d6be87055d86a7eb63960d3), baseline 0.3.7-beta. [Official portal](https://koflang.github.io/docs) snapshot was generated 2026-09-17; several pages differ from pinned compiler source. See [KOF_COURSE](docs/KOF_COURSE.md).
- Minecraft Java26.3, released2026-09-15; exact version-metadata SHA-1 `96c00d95a31328714d3811cfade2804bb050e455`. Uses SDL3/LWJGL3.4.3 and JOML1.10.9; source/version/license matrix in [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Temporary research clones/jars were under `/tmp/kookie-*`; not project dependencies. Durable evidence and full probe sources live in [RESEARCH_PROBES](docs/RESEARCH_PROBES.md), [COURSE_PROBES](docs/COURSE_PROBES.md) and [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- The active CLI is the source-pinned Kof 0.5.0-beta distribution at
  `~/.local/share/kof4j/0.5.0-beta-bf17ac7e`, using the host Java runtime and
  compiler JAR SHA-256
  `6634e1bf80334cc2518c50f9d1a05e2da92ff318282775ba58a087891e2420a6`.
  The earlier official distribution remains installed side by side but cannot
  compile KOOKIE's native `Buffer(U8)` benchmark.

## Proposed decisions

- Native Linux x86-64 remains the authoritative Kof gameplay target; the JVM is
  a differential oracle and a separate Windows compatibility profile. The
  Windows PE bridge is qualified for the reachable gameplay/presentation graphs,
  with native shell Wine evidence and presentation artifact evidence; visual
  presentation smoke remains DRI3/GPU-gated.
- SDL 3.4.16 + SDL_GPU with Vulkan/SPIR-V is the graphics boundary; SDL_mixer
  3.2.4 owns effects/music buses. The packaged Kof benchmark validates the
  bulk-buffer ABI and chooses between the measured SIMD and scalar reduction
  routes. Gameplay stays on the scalar Kof path until profiling identifies a
  production bulk workload with the same ownership and amortization.
- One Kof simulation thread; 60 Hz tick, independently interpolated rendering, four-step catch-up proposal.
- Typed component arrays + generation IDs, true-3D capsule/BVH collision, one damage/death/reward authority.
- Kof-owned renderer policy, content kooker, game UI and kutter tooling; HLSL/GPU shader exception explicit.
- Full looter/ARPG systems are milestone G3, not dropped after a boomer-shooter demonstration. Kutter workflow is G4. See plan for exact scope/acceptance.
- No automatic JVM fallback, no hidden C gameplay engine, no editor fork prerequisite.

## Facts not to forget

1. Functions use `Int f(Int x)` / `f(Int x): Int`, **not fun/fn**. `record` and `class X(...)` are immutable/record-style; mutable classes use fields + explicit constructor. No top-level ordinary variables, array literals or Kotlin safe-call/coalesce assumptions.
2. `.kf` modules/imports work. Measured directory import on JVM/native; `run` collects siblings and rejects multiple `main()` functions (`PKG002`). Separate application entry scopes.
3. Native **scalar** `extern` works now; old blanket “native FFI unsupported” claims are stale. Measured sqrt → `3.0`, SDL_GetVersion → `3004016` on both targets.
4. Kof 0.5.0-beta `Buffer(U8, INOUT)` plus token FFI passed supplied independent native x86-64/cross verification. Script/JS/Android/riscv32/MCU still return `FFI001`; structs/pointers/variadics and native callbacks remain outside the general contract. Integer resource IDs must be real adapter tokens, not pointer casts.
5. Native x86 collector's automatic path is gated by **cumulative `kof_spawn_count == 0`**. Awaiting a task does not reopen it. Do not bypass by unsafe manual GC. Library threads must never retain/call Kof heap state.
6. Packaged native execution warned runtime pruning cannot find `NativeRuntime.java` outside compiler module; full-runtime fallback ran. Tiny upstream binary-size claims are not verified for this release path.
7. Native compiler optimization remains limited; the JVM JIT may outperform it. Representative bounded simulation and hardware-render timings are now recorded for G5, not generalized to other workloads or platforms.
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
27. Native SIMD dispatch selects AVX2/SSE2 on x86, has an AArch64 NEON source path and keeps checked scalar fallbacks. The packaged Kof benchmark routes a 1 MiB `Buffer(U8)` through the dispatcher for 64 rounds and retains scalar parity across vector tails. The recorded native AVX2 batch was 217.3x faster than the native Kof scalar reduction for this exact workload; no gameplay or general engine speedup is inferred.
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
    definitions fail closed before session start. G4 adds generation-bound
    trusted hooks, deterministic kooker products and staged package/GPU reload.
33. Current native lowering can clobber a scalar `extern` result retained in a
    local across later calls; returning an `extern` Bool directly also reached
    `kof_unbox_bool` with an invalid value. Headless configuration and transport
    receive paths therefore consume results immediately into validated object
    fields before any later call. This is a focused compiler workaround, not a
    compiler repair or permission to generalize the ABI.
34. Retaining a spatial slot or `SpatialPositionResult` across later calls in
    the continuous-projectile loop passed on JVM but broke terminal hits,
    impact events and presentation on native. Keep the proven coordinate-call
    shape; `EnemySpatialWorld.find` caches the last ID/slot internally to remove
    repeat scans without exposing that native-lowering defect.


## Editor cautions

See [KOF_EDITOR](docs/KOF_EDITOR.md). Interactive UI is substantially authored JS inside `.kf`; independent scanner, not compiler frontend reuse. Run copies active file to fixed temp root and hardcodes JVM. No actual LSP/DAP client integration found. Host filesystem/shell endpoints unrestricted and unauthenticated.

With inspected compiler, source `web.sh` omits host and legacy handler serves on default `0.0.0.0`. Explicit `--host 127.0.0.1` applies to **legacy handle mode**, not `web.app()+main` mode; loopback is still not authorization/Origin protection. Prefer isolated scratch use, not monorepo Git/Run actions. Old native scanner R1 is explicitly closed in editor's own historical ledger.

## Game evidence

- **DoomKof:** source-published raycaster, `.kf` gameplay; desktop JVM Jaylib JNI 5.5.0-2/raylib, alternate browser Canvas+JS. Source license not established. No verified native-ELF release.
- **Byte Eater / kofman:** source-published MIT browser game, KofJS/kof.ui Canvas, JVM web backend, authored JS keyboard bridge.
- **Pong:** raylib demo reported/video-linked in Kof4j issue #431; game source and exact execution target not verified.
- Builtin Tetris is Java-runtime terminal game; KofOS game list is unported plans.
- Search did not establish a shipped native Kof shooter or ready SDL/Sokol binding package. This is bounded negative evidence, not proof none exists.

## Adopted design constraints

- Controller intent/jump policy, generation-safe handles, exact render-batch identities/order barriers and revision/neighbor-presence admission remain explicit contracts.
- Item identity, atomic item/currency/RNG transactions, skill/status semantics, fixed-step input edges, render queue/spatial hash and staged live-edit publication remain explicit contracts.
- Isolated SAT geometry, weapon/damage transition contracts, bounded AI search and sectioned saves remain explicit contracts.
- Do **not** inherit endpoint-only “sweep,” waist-ray player collision, fixed tiny loot pools/silent drops, duplicate weapon authorities, raw ECS IDs in saves, event playback mislabeled deterministic replay, or corpus inspectors mislabeled map kookers.
- Any copied or translated third-party code or assets require traceable provenance, a pinned source revision and license/notice review before distribution.
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

G3 remains complete at its current gate. Server-owned
kill→rolled drop→pickup/equip→observable damage/skill change→boss
reward→schema-file save/reload executes without client-authored outcomes or
duplicate rewards. State kinds 7/8 traverse authenticated same-host
host-plus-two-client processes on both targets. Bounded public manifests,
capabilities and deterministic contributions instantiate complete sealed
elite/boss rules atomically.

G4 is complete for the bounded implementation summarized above. Its
compatibility exchange uses production role transport and separate processes,
but the retained qualification is not a fresh three-machine run.

G5 is complete for the bounded Linux x86-64 contract. The reference workload
loads 64 authored collision triangles and runs 64 enemies, 256 moving
projectiles, 512 pickups, 24 lights and 64 effects under 16/64/128 rolling
budgets. The focused native sample recorded p50/p95/p99/max
1.518/1.623/1.717/1.757 ms. The 600-warm-up/108,000-tick paced run recorded
2.489/3.202/3.721/23.645 ms and a 128 KiB RSS range while preserving resource
signature `520690`.

An authenticated host replicates the complete state every tick to two client
processes; transactional four-chunk assembly rejects replay/tamper and client B
resumes at generation 2. SDL_GPU draws 984 hardware instances in one call; the
recorded 1920×1080 Vulkan run measured p95 submission time 0.645 ms. Durable
saves, replay v3, migrations and signed clean-tree packages close the release
hardening. Evidence remains same-host, fixed-population and single-workstation.
G6 now has bounded expansion probes and native Windows PE/SDL package gates;
broad multi-machine/WAN, other OS/GPU targets and arbitrary scale remain
unclaimed.

G6 is qualified for its declared bounded contract: native Windows PE gameplay
linkage, SDL shell/presentation package gates, KofScript/Kutter/WAN probes and
CI evidence are retained. This does not make the static presentation shell a
playable demo; D1 remains the player-facing release gate.

Earlier research evidence: original core/import/scalar-FFI probes, 18
course-driven programs (36 runs, two checks), and the JOML JVM success/native
import-rejection pair. Complete sources/results are in the linked research
documents. Those research probes were JVM/native x86 only, with no
games/editor/server or graphics launched. Later installation verification
exercised compiler CLI, LSP/DAP and the actual isolated editor/server; it did
not verify the engine graphics stack or run a full suite.

All graphical checks use a reviewed wrapper configured through
`KOOKIE_PRESENTATION_ISOLATION_WRAPPER`, with private sockets, timeout and
process cleanup; never the developer desktop. Full matrix only final
pre-commit with user permit.
