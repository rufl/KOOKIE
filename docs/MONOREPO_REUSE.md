# Reuse map: ZYLVE, DINX and CUBSHIP

Research date: 2026-09-22. Read-only inspection of live sibling working trees; no source changes, builds, tests or graphical runs. Other work is active in those projects, so line ranges are a locator snapshot, not a pinned release. Port **behavior and invariants into `.kf`**, not entire Zig/Rust engines or their ABI objects.

## Recommended ownership split

| Source project | Best lessons for KOOKIE | Do not import wholesale |
|---|---|---|
| DINX | Shooter input intent, jump policy, native-resource handles, render batching, revision-safe work publication | Flecs/Sokol Zig wrappers, giant engine coordinator, incomplete collision/corpus helpers |
| ZYLVE | ARPG item identity, atomic inventory/progression, fixed-step input edges, render sorting, live-edit staging | Game-specific balance, tiny pickup caps, proprietary/third-party assets, giant runtime files |
| CUBSHIP | Geometry kernels, firing/damage contracts, bounded AI searches, sectioned saves | Bevy schedule/entity ownership, Rust serialization, purported replay/physics guarantees not established by source |

## DINX

### D1. Controller intent and jump policy — first shooter milestone

Source: [player_controller_runtime.zig](../../DINX/src/core/player_controller_runtime.zig), especially `PlayerControllerBoundaryPolicy`, `shouldCoyoteJump`, `JumpAssist`, `stepBox3DPlayerIntent`, `accelerateHorizontal` (roughly lines 19–116, 329–489).

Preserve:

- Input normalization and explicit acceleration/braking policy.
- Coyote jump requires a fresh press within a finite nonnegative time window.
- Buffered press consumed once; jump-release cut affects upward velocity, not falling.
- Distinct ownership of controller intent versus collision resolution.

Do not copy tuning blindly: its acceleration approaches a target velocity vector, not Quake's projection-based air acceleration. KOOKIE needs explicit per-game movement profiles.

[engine.zig](../../DINX/src/core/engine.zig), around 7888–7918, has a **physics subloop** with 60 Hz accumulator, two-step catch-up ceiling, discarded-time accounting and fractional debt. This is not evidence that every DINX gameplay system is fixed-step. Choose one KOOKIE clock policy rather than combining incompatible sibling policies.

### D2. Handles and resource lifetimes — first ABI milestone

[physics_backend_runtime.zig](../../DINX/src/core/physics_backend_runtime.zig), `HandleIndex`, around 707–770: `(id,generation)` lookup, slot+1 sentinel, bounded open addressing, backward-shift deletion instead of tombstone buildup. The table uses power-of-two masking; preserve that invariant if ported.

Useful for SDL resource tokens and engine entity references. The implementation is not a ready dense ECS/free-list allocator. Kof must own its component storage; native pointers remain adapter-owned.

### D3. Render extraction and batching — after first correct draws

[actor_batch.zig](../../DINX/src/render/actor_batch.zig), `Runtime`, `submit`, `flush`, around 25–81 and 326–423:

- Exact geometry identity remains pinned for a frame; deforming buffers update only when safe.
- Batch compatibility includes geometry/index mode/view/sampler/non-instance lighting.
- Projected-overlap barriers preserve order when batching could change depth behavior.
- Instance-buffer exhaustion can fall back to immediate draws rather than silently dropping accepted actors.

Port these contracts, not Sokol/Zig structs. Bounded pairwise scans should not grow into an unbounded quadratic renderer. [ecs_query_runtime.zig](../../DINX/src/core/ecs_query_runtime.zig) also illustrates world-bound query lifetimes and owned/shared writeback, but is Flecs-specific rather than an independent ECS implementation.

### D4. Stale-result rejection and persistence — scale milestone

- [terrain_streaming_task.zig](../../DINX/src/world/terrain_streaming_task.zig), `Task`/`Demand.matches`, around 9–47, 99–133: seed/config/epoch/distance/layer admission; owned result with no live-world mutation.
- [meshing_snapshot.zig](../../DINX/src/world/meshing_snapshot.zig), around 143–164, 284–302: owned center/seam snapshot; center and neighbor epochs **and presence** determine validity. Loading or evicting a neighbor invalidates stale seams even without an edit.
- [region_store.zig](../../DINX/src/world/region_store.zig), around 22–45, 93–103, 416–459: append-only arena, payload sync before index publication, atomic manifest rename, bounded compaction/grouping. Its durability contract is specifically local POSIX behavior, not automatically cross-platform.
- [native_tooling.zig](../../DINX/src/core/native_tooling.zig), `JobRequest`/`JobResult`, around 239–325: versioned operation request, executable authority owned by trusted provider configuration, explicit terminal outcomes, artifact format/size/hash metadata. A schema is not itself a sandbox or proof the hash was verified.

Initially keep KOOKIE single-threaded; these are ownership/revision models for later work, **not a reason to enable Kof native spawn despite its GC restriction**.

### Do not mistake these for completed systems

- [physics.zig](../../DINX/src/core/physics.zig), `sweepAabbAgainstVoxel` around 65–113, returns early if the destination does not overlap. **[INFERENCE]** fast pass-through can be missed; this is not the required continuous capsule solver.
- [ugc/dinxmap.zig](../../DINX/src/ugc/dinxmap.zig), around 1563–1633, counts legacy fixture constructs. The Quake corpus tool checks BSP lump ranges/statistics, not a complete brush compiler plus runtime loader. Do not claim a ready Quake pipeline based on a corpus check.

## ZYLVE

### Z1. Item identity and atomic transactions — core looter/ARPG milestone

Sources: [item_types.zig](../../ZYLVE/src/item_types.zig), `Instance`, stat composition and visibility (roughly 307–550); [inventory.zig](../../ZYLVE/src/inventory.zig), identity/ownership (85–134, 165–257); [item_progression.zig](../../ZYLVE/src/item_progression.zig), transaction results (70–264); [arpg_progression.zig](../../ZYLVE/src/arpg_progression.zig), storage/skills/XP/ailments.

Preserve:

- Stable instance identity separate from item definition, including after equipment/stash moves.
- Explicit failure outcomes; validation before mutation of item/currency/materials/RNG.
- Gambling stages inventory and RNG/currency together, commits only when the item fits. Failed capacity must not consume money or random-state progression.
- Hidden/unidentified/broken item stat visibility is explicit, not accidentally leaked through comparison UI.
- Skill activation validates learning/loadout/mana/cooldown, then commits costs and cooldown together.
- Status duration/refresh rules and resistance caps are named policies.

Adapt rather than transplant: KOOKIE needs definition-driven firearms/affix pools/rarity ranges and genre profiles. Whole-inventory copy-before-commit is cheap for ZYLVE's tiny bounded inventory; for larger storage, stage only touched slots and reserve capacity while preserving atomic semantics.

Important limitation: [world3d_simulation.zig](../../ZYLVE/src/world3d_simulation.zig), `dropEnemyLoot` around 4217–4290, uses fixed tier/affix mappings and a small pickup pool. This is **not** a general rolled multi-affix loot generator. Some extra-drop failures are ignored. Do not inherit silent loss or its balance tables. Older socket code accepts fewer gem types than the schema; choose one coherent authority, not both paths.

### Z2. Fixed-step input and event separation — first gameplay milestone

[runtime3d.zig](../../ZYLVE/src/runtime3d.zig), around 5480–5600:

- 1/60-second ticks, bounded catch-up, pause/studio/freeze debt clearing.
- One-shot jump/dash/reload/interact/skill edges consumed only after a simulation step actually happens.
- Held movement/fire available to subsequent steps.
- Simulation results precede presentation/event consumption.

[world3d_simulation.zig](../../ZYLVE/src/world3d_simulation.zig), `damageEnemyOwned` around 1381–1435, illustrates a shared damage/reward owner. KOOKIE should enforce one alive→dead transition, one loot/XP outcome and separate cosmetic effects. Do not port game-specific boss behavior into a generic damage service.

### Z3. Small allocation-conscious kernels — early ports

- [render_queue.zig](../../ZYLVE/src/render_queue.zig), lines 1–99: pass/state/depth metadata; opaque grouping and transparent far-to-near ordering; deterministic tie-break; explicit overflow. Copy ordering contracts, not a 512-entry ceiling or silent drop policy.
- [spatial_hash.zig](../../ZYLVE/src/spatial_hash.zig), lines 1–115: bounded array-backed broadphase with caller-owned output. Results are candidate cells, **not exact radius intersections**. Respect coordinate bounds and unique insertion; always apply a narrow phase.

### Z4. Live editing, packages and saves — authoring milestone

- [terrain/live_edit.zig](../../ZYLVE/src/terrain/live_edit.zig), `Session.stage`/`commit` around 244–303: prepare all fallible work before publication, reject stale revisions and double consumption, commit without allocation.
- [runtime_map_domain.zig](../../ZYLVE/src/runtime_map_domain.zig), around 227–281: dependent products published together at frame boundary; session/coordinator tokens reject prior-session results.
- [content_package.zig](../../ZYLVE/src/content_package.zig), around 36–106: bounded envelope/ranges/paths, duplicate rejection, corruption checks and data-only admission. Its checksum is not cryptographic authentication.
- [savegame.zig](../../ZYLVE/src/savegame.zig), around 12–25, 85–155: explicit versioned fields, staging file, sync then rename. Do not copy raw memory or fixed world counts; directory durability still needs platform proof.

Telemetry JSONL is diagnostics, not deterministic replay. KOOKIE's recorder needs tick commands, explicit RNG streams, content/build identities and checkpoints.

## CUBSHIP

### C1. Geometry kernels — selective cooker/reference use

[cubout-core/src/triangles.rs](../../CUBSHIP/cubout-core/src/triangles.rs), `triangle_aabb_intersection` and `voxelize_surface` (18–187): SAT geometry, finite input/buffer bounds, bounded voxel resolution/work, barycentric color/texture sampling. The header explicitly says **surface-only**, no interior filling, skins or animation import.

Port math directly into `.kf` when useful. `glam`, `serde_json`, `dot_vox` and Rust collections are implementation dependencies, not a C-callable library we should hide behind. Voxelization itself is optional for KOOKIE; full 3D static triangle collision does not require turning every asset into voxels.

### C2. Firing/damage transitions — contract reference

- [weapon_fire_handler.rs](../../CUBSHIP/cubgame/src/architecture/weapon/weapon_fire_handler.rs), around 79–203: spin-up, trigger, cooldown, reload, magazine/ammo checks, shot event and sequence.
- [cubgame/src/systems.rs](../../CUBSHIP/cubgame/src/systems.rs), around 24–129: armor consumption separated from health damage/resistance.

Avoid known weak semantics: the DOT scheduler emits at most one overdue tick on a long frame; the damage system does not itself guard already-dead targets before death-event creation. **[INFERENCE]** importing these literally risks frame-dependent damage and repeated death rewards. Its root plugin and weapon plugin also register overlapping paths; do not reproduce dual authorities.

### C3. Budgeted AI — later population scaling

- [pathfinding.rs](../../CUBSHIP/cubmind/src/pathfinding.rs), around 84–296: navmesh A* with max-node budget, explicit result status and waypoints.
- [perception.rs](../../CUBSHIP/cubmind/src/perception.rs), around 78–149: spatial candidate query, distance/FOV and LOS.

Limits: “hierarchical” delegates to capped A*; cross-chunk linkage is approximate. Failed paths contain start/end but carry `Failed`; never follow them as a direct valid route. Reuse scratch arrays rather than allocating a grid each frame/candidate vector per agent; use cosine FOV comparisons. A real portal/navmesh cooker still needs implementation.

### C4. Save/replay/network contracts — not implementations to copy

- [cubsave/src/system.rs](../../CUBSHIP/cubsave/src/system.rs), around 295–355, 435–508: independently serialized/compressed sections, stage/sync/rename. Existing HMAC fallback and signed-range assumptions are not a security design to inherit.
- [cubway/src/net/demo.rs](../../CUBSHIP/cubway/src/net/demo.rs), around 251–313, 393–458: timestamped event playback, not deterministic simulation replay. Seek moves a cursor without restoring a world checkpoint.
- [prediction/systems.rs](../../CUBSHIP/cubway/src/net/prediction/systems.rs), around 260–335: replay unacknowledged commands through shared movement logic is the useful contract. Actual movement around 111–195 uses a waist ray and held-jump reset, not swept capsule collision.
- [cublevel/src/lib.rs](../../CUBSHIP/cublevel/src/lib.rs): level schema includes Bevy Entity IDs. KOOKIE saves/authored levels must use stable content/entity identifiers, not runtime ECS handles.

## Graphics stacks observed

| Project | Source evidence | Meaning |
|---|---|---|
| ZYLVE | [c.zig](../../ZYLVE/src/c.zig), SDL_CreateGPUDevice with SPIR-V in runtime3d, SDL GPU render passes | SDL3 GPU; Linux/Vulkan precedent. Existing SPIR-V assets do not automatically support Metal/D3D12 |
| DINX | [render/renderer.zig](../../DINX/src/render/renderer.zig), zsokol.gfx/app; build selects GL/D3D11 | Sokol precedent; also owns software rasterizers. Zig wrappers are not reusable Kof ABI |
| CUBSHIP | [Cargo.toml](../../CUBSHIP/Cargo.toml), Bevy 0.18/wgpu 27/Avian 0.6; Bevy RenderDevice/RenderQueue | Rust/Bevy stack; not a thin external graphics layer for KOOKIE |

## Licensing and ownership

- **DINX:** [LICENSE](../../DINX/LICENSE) provides MIT terms and warns third-party notices remain separate. Preserve attribution for substantial copied/translated code; map corpus and assets are separate.
- **ZYLVE:** [README](../../ZYLVE/README.md), around 251–256, limits the whole game to private/internal use. No blanket public redistribution grant was established. User authorization permits researching/borrowing owned logic for this project; it does not clear third-party/commercial art, sound, fonts or code.
- **CUBSHIP:** [README](../../CUBSHIP/README.md) claims MIT, but the inspected root/direct-crate license packaging was incomplete. Resolve actual rights/notices before distribution. cubout-core explicitly preserves original ownership rather than granting fresh rights.

Every port should record source path, revision/hash at port time, borrowed behavior, changed semantics and retained notices. Research did not copy sibling code or assets and did not assign KOOKIE a license.

## Port sequence and anti-patterns

1. Session roles, stable IDs, tick-stamped commands, loopback codecs, input
   edge consumption, fixed tick and render-item metadata.
2. Authoritative server/client snapshots, prediction/reconciliation,
   movement intent and newly correct continuous collision, one firing/damage/
   death authority.
3. LAN admission/replication, item identities, atomic inventory/stat/skill
   transactions and definition-driven loot.
4. Revisioned cooker/editor publication, versioned saves, replay checkpoints
   and extension manifests/schema migration.
5. Budgeted AI, streaming, dedicated-server scale and broader transport only
   after the representative multiplayer slice works.

Avoid monolithic runtime coordinators, engine-owned logic in foreign shims,
competing ECS/weapon authorities, tiny inherited capacities, silent gameplay
overflow, pretending checksum equals authentication, pretending single-player
can bypass replication, and trusting names/backlog labels over behavior.
Sibling examples are design evidence, not performance or correctness
certification for the port.
