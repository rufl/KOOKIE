# KOOKIE engine plan

Status: **proposed architecture and acceptance gates; no engine implementation yet**.

Research baseline: 2026-09-22, Kof 0.4.9-beta. Project architecture is
[ARCHITECTURE.md](ARCHITECTURE.md). See [language/runtime evidence](KOF_LANGUAGE.md),
[initial probes](RESEARCH_PROBES.md), [course deep dive](KOF_COURSE.md),
[course-driven probes](COURSE_PROBES.md), [game precedents](GAME_ECOSYSTEM.md),
[editor findings](KOF_EDITOR.md), and [monorepo port map](MONOREPO_REUSE.md).

## 1. Product and non-negotiable ownership

Build a **true-3D, content-driven first-person engine** supporting three game profiles on the same simulation/render/content foundation:

| Profile | Required strengths |
|---|---|
| Boomer shooter | Responsive mouse look, acceleration/air control, readable projectile patterns, keys/doors/secrets, authored interconnected combat spaces, fast weapon switching |
| Looter shooter | Rolled item instances, firearm archetypes and affixes, equipment/inventory, elite modifiers, repeatable encounter/reward loops, save integrity |
| ARPG FPS | Active skills, cooldown/resource costs, progression trees, damage types/resistances, timed/stacking effects, build synergies, bosses and equipment-driven builds |

These are configurable rulesets, not three forks. A boomer profile can disable loot/progression without maintaining a second movement, collision or renderer implementation.

### Source ownership rule

All **engine-owned CPU behavior** is `.kf`: loop, entity storage, math, movement, collision, AI, combat, loot, animation decisions, render extraction/culling/sorting/pass policy, audio policy, saves, content cooking, runtime UI, authoring logic and game code.

Allowed non-Kof boundary, kept small and reviewable:

1. Unmodified external platform/GPU/audio/codec libraries, initially SDL3.
2. C ABI marshaling that Kof cannot currently express: native handles, struct/event unions, pointers, buffer transfer and library setup/teardown. No gameplay or scene algorithms.
3. GPU shader source/binaries: Kof does not currently provide a supported general graphics-shader target. HLSL/SPIR-V and generated backend variants are an explicit graphics exception, not CPU engine code hidden elsewhere.
4. External compiler/linker/shader tools and minimal declarative build/bootstrap glue. KOOKIE-owned cooker/editor behavior remains Kof, not Python/JS/Zig/Rust applications.

The existing Kof compiler/runtime is an upstream tool dependency written partly in Java/assembly. Fixing an upstream compiler defect is distinct from moving KOOKIE gameplay into Java. Any maintained compiler delta must be pinned, documented and upstreamed where practical.

**Forbidden shortcuts:** a Java/Bevy/Zig engine driven by `.kf` scripts; handwritten JS game logic stored in Kof strings; a C `engine_tick`/`render_world` implementation; casting integers into arbitrary native pointers; duplicating gameplay in a second language to make the demo work.

This plan does not choose a public license or authorize redistribution of sibling assets. Resolve ownership/notices before publishing ports.

## 2. Platform and graphics decision

### Proposed baseline: SDL3 + SDL_GPU

- First runtime: **Kof native Linux x86-64 ELF**.
- Development oracle: JVM for small pure-Kof differential probes, not a silent shipping fallback.
- Initial graphics backend: SDL_GPU Vulkan with offline SPIR-V shaders.
- SDL handles window/events/relative mouse/gamepads/timing/audio-device access. Kof owns the main loop and game state.
- SDL_GPU handles device resources, command buffers, upload synchronization, pipelines, draw/compute submission and presentation. Kof decides what to submit and in what order.
- Use one renderer implementation initially. Do not build SDL, Sokol, raylib, OpenGL and Vulkan backends simultaneously.

**Why:** full 3D/instancing/compute headroom for projectile crowds and ARPG effects, modern desktop backend model, robust shooter input surface, one platform dependency, and existing ZYLVE SDL_GPU experience. This is a design judgment, **not measured evidence that SDL_GPU is fastest for Kof**.

### Alternatives considered

| Candidate | Fit | Decision |
|---|---|---|
| SDL3 + SDL_GPU | Vulkan/D3D12/Metal abstraction; polling input/main loop; GPU resources/compute; ZYLVE precedent | Preferred native spike |
| SDL3 + `sokol_gfx` | Compact GPU API; reuse DINX batching concepts; can retain SDL platform loop | Viable alternative if SDL_GPU hardware/shader constraints fail; adds integration between two libraries |
| `sokol_app` + `sokol_gfx` | Small footprint, portable graphics, DINX familiarity | Native Kof cannot currently supply retained callbacks; app lifecycle would need extra bridge ownership. Not the first path |
| raylib / Jaylib | Shortest route to examples; actual DoomKof precedent; math/models/audio included | Good comparison/prototyping option, but Jaylib means JVM and many raylib structs still need native ABI work. Not a substitute for the engine-owned renderer plan |
| Direct Vulkan | Maximum control | Too much driver/synchronization/shader work before shooter behavior; no demonstrated need |
| LWJGL | Mature JVM bindings | Target-specific alternative, not evidence of native Kof interoperability |
| Kof Canvas / WebKitGTK | Existing 2D/browser ecosystem | Wrong initial real-time 3D/runtime boundary; browser is not the native target |
| Bevy/wgpu through Rust shim | Existing CUBSHIP stack | Violates engine ownership if simulation/render architecture remains Rust |

Sokol remains credible; it is not rejected as incapable of shooters. Its backend list evolves, so pin headers/shader tools if selected rather than relying on stale capability tables.

SDL_GPU also has limitations: modern GPU feature floor, strict shader resource layouts, no general browser backend in the proposed route, no promise of cutting-edge ray tracing/mesh shaders. SDL portability does not imply Kof native PE/Mach-O output. Windows/macOS/ARM/browser support remains a separately gated expansion, not an initial deliverable claim.

Sources: [SDL GPU contract](https://wiki.libsdl.org/SDL3/CategoryGPU), [relative mouse mode](https://wiki.libsdl.org/SDL3/SDL_SetWindowRelativeMouseMode), [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross), [Sokol](https://github.com/floooh/sokol), [raylib](https://github.com/raysan5/raylib), [SDL license](https://github.com/libsdl-org/SDL/blob/main/LICENSE.txt).

### Modern Minecraft reuse assessment

[MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md) records the current Java26.3 stack and candidates. Its SDL3 migration supports our platform choice, **not** a claim that Minecraft uses SDL_GPU. Its Renderpearl API split does not establish an open-source reuse grant. Current rendering lessons are extracted frame state, explicit pass attachments, resource generations, visibility/batching and persistent instance lifetimes.

Prioritize bounded `.kf` math/command ports from JOML/Brigadier, Artemis/Ashley-inspired typed storage, Minecraft-style definition/item-patch/codec contracts, owo-inspired layout and Flywheel-inspired instance lifecycles. JOML1.10.9 was measured on Kof JVM; native rejected its Java imports. Do not import JARs or entire mod runtimes as native engine libraries.

Keep queued SDL audio for G0. For the production FPS stack, **recommend OpenAL Soft** for positional sound, HRTF and EFX; SDL3_mixer is the simpler/basic-spatial alternative, not a second mandatory backend. This is a library-selection recommendation, not an implemented audio backend or an adopted redistribution license. Jolt physics and RmlUi/ImGui UI still require explicit foreign-subsystem ownership approval.

### Recommended library set (2026-09-22)

Selection criterion: native Linux shooter fit, maintained narrow APIs, license
clarity, and compatibility with `.kf` ownership—not an unmeasured claim of
maximum performance. Adopt in stages; do not link every candidate into G0.

| Area | Recommended choice | Boundary / reason |
|---|---|---|
| Platform and graphics | **SDL3 + SDL_GPU** | One window/input/gamepad/GPU stack; 3D and compute. Kof owns extraction, culling, batching and passes. zlib license. Keep Sokol as an alternative only if the GPU/ABI spike fails |
| Shader build | **SDL_shadercross + DXC**, SPIRV-Cross and SPIRV-Tools as required by the build | HLSL → offline SPIR-V for Linux; reflect resource layouts. Build-time tools, not mandatory shipped runtime shader compilers. Installed ShaderC alone is not the selected HLSL pipeline |
| Production audio | **OpenAL Soft** | 3D sources/listener, attenuation/Doppler, HRTF and EFX. Kof retains cues, voice admission/priority, world occlusion queries and configured effect policy. Library performs mixing/spatial DSP; this is an explicit audio-mechanism delegation |
| Image decoding | **SDL3_image** | Decode authored PNG initially into bounded pixel buffers. Keep format admission, color-space/material decisions, cooking and GPU uploads under Kof policy. zlib library; optional codec dependencies have their own notices |
| Text rendering | **FreeType**, then **HarfBuzz** when implementing shaped text | Rasterization and shaping services only. Kof owns widgets, layout, focus and glyph-cache policy. Font fallback, bidi/line breaking, IME and accessibility are not solved merely by linking these libraries |
| Package compression | **Zstandard (`libzstd`)** | Add at the cooked-package stage, not per frame. Use bounded independently addressable chunks, declared decoded lengths and decoder limits; compression is not integrity/authentication. BSD license option |

**Audio choice details.** OpenAL is not an audio-file decoder. Start with a
restricted PCM WAV input policy using SDL's existing `SDL_LoadWAV`; add one
compressed-audio decoder only when streamed music requirements justify it.
Do not run SDL_mixer and OpenAL as competing device/mixer authorities. OpenAL
Soft is LGPL-2.0-or-later, with separately Apache-2.0 HRTF data in the inspected
source: review notices, corresponding-source and relinking obligations for the
actual distribution. If that tradeoff is unwanted and basic spatial audio is
enough, choose SDL3_mixer instead (zlib, SDL >= 3.4.0). Its simpler licensing
does not automatically license every optional decoder.

**Keep these engine libraries in Kof:** typed entity/component storage; a small
math library using selective MIT JOML ports; shooter movement/collision;
AI/navigation under the current rule; combat/loot/statuses; content schemas and
source admission for glTF/brush maps, Dust3D, LibreSprite and MagicaVoxel;
player UI and authoring logic. Do not add a foreign ECS or call a C math
library once per vector operation. GLB is the canonical 3D interchange result,
while source-format intake remains a validated cooker concern; the native JSON
gate remains.

**High-value alternatives requiring an ownership decision:**

| Library | Why it is attractive | Why it is not silently adopted |
|---|---|---|
| **Jolt Physics** (MIT) | Best assessed general physics shortcut: shape casts, collision, rigid bodies and virtual characters | Transfers collision/solver/controller behavior out of Kof. If approved, name the delegated parts and keep movement intent, weapons/damage and fixed-tick authority in Kof |
| **Recast + Detour** (zlib) | Navmesh generation plus pathfinding/queries; useful for multi-level 3D environments | Recast moves navigation cooking out of Kof; Detour moves runtime navigation out. DetourCrowd additionally owns avoidance/movement and should not replace the shooter controller |
| **Dear ImGui** (MIT) | Strong developer inspector/debug-editor shortcut; SDL3/SDL_GPU integration | Foreign widget/layout state is not just drawing adaptation. Only add with an explicit authoring-UI exception |
| **RmlUi** (MIT) | Strong retained player/menu/inventory UI alternative; real SDL_GPU backend | Foreign layout/widget behavior; requires C++ callback/span adaptation. Not a browser and not a complete accessibility solution |

Hand-building robust swept capsule collision, navmesh cooking and rich UI is a
major consequence of the current ownership rule. These alternatives could
reduce that work; an integer-token wrapper does not make their algorithms Kof.
Do not port entire Jolt/Recast/UI implementations merely to change the language.

**External authoring/debug tools:** Blender for glTF/GLB source assets,
TrenchBroom for brush-map authoring, RenderDoc plus Vulkan validation layers for
GPU diagnosis. These are development tools, not engine-owned CPU implementations.
Define the transport-independent session/protocol contracts from G0. Defer
choosing a third-party networking library until the LAN slice requires one; a
transport still does not supply replication, prediction or authoritative
simulation.

**Observed local availability:** `pacman -Q` and `pkg-config` found SDL3
3.4.16, OpenAL 1.25.2, FreeType 2.14.3, HarfBuzz 14.5.0 and zstd 1.5.7.
SDL3_image, SDL3_mixer and SDL_shadercross were absent from the queried package
database and pkg-config modules. This inventory does not prove native Kof
integration, device compatibility or completed binding work. No libraries were
installed or devices opened during this selection.

**Adoption order:** resolve the native compiler correctness gate → prove
SDL_GPU/input/queued-audio and checked token/buffer transfer → add image/text
services → integrate the chosen production audio backend → add package
compression when the format is established. Pin artifact hashes, build options,
transitive notices and adapter ABI at each adoption. There is no separate
backend/plugin framework or performance promise implied by this shortlist.

Primary sources: [SDL GPU](https://wiki.libsdl.org/SDL3/CategoryGPU),
[shadercross](https://github.com/libsdl-org/SDL_shadercross) and its
[DXC build option](https://github.com/libsdl-org/SDL_shadercross/blob/main/CMakeLists.txt),
[OpenAL Soft](https://github.com/kcat/openal-soft/tree/8d2d2e2ed1f51df960e7eb4bb26b64625c873c0d),
[SDL WAV API](https://wiki.libsdl.org/SDL3/SDL_LoadWAV),
[SDL_image](https://github.com/libsdl-org/SDL_image),
[FreeType licensing](https://freetype.org/license.html),
[HarfBuzz shaping](https://harfbuzz.github.io/what-is-harfbuzz.html),
[zstd](https://github.com/facebook/zstd),
[Jolt 5.6.0](https://github.com/jrouwe/JoltPhysics/tree/v5.6.0),
[Recast/Detour](https://github.com/recastnavigation/recastnavigation).
Versioned UI sources and additional license boundaries are in
[MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md).

## 3. The FFI boundary must be proven first

Current native Kof accepts scalar `extern` calls; arrays/structs/pointers/out-buffers and native callbacks are blocked. We measured actual SDL version and libm calls, **not graphics initialization**.

### Adapter contract

Proposed API categories below are design contracts, not existing functions:

| Category | Data crossing the boundary | Who owns the behavior |
|---|---|---|
| Lifecycle | ABI version, capabilities, create/destroy, status/error | Adapter owns SDL resources; Kof owns application lifecycle decisions |
| Input | Poll event; tagged type; scalar fields; normalized text copied as String | Adapter flattens SDL_Event only; Kof bindings, commands and focus policy |
| Resources | Typed integer token; scalar descriptor fields; explicit release | Adapter registry owns native pointers; Kof asset/resource lifetime policy |
| Uploads | Staging token, offset/count, fixed scalar tuples; later safe bulk buffers if supported | Adapter packs/transfers bytes; Kof creates/validates data and content semantics |
| Commands | Begin/end pass, bind pipeline/resource, viewport/scissor, draw/dispatch | Kof pass selection, sort order, visibility and batching |
| Audio | Decoded clip/stream token, queue data, gain/channel controls | Kof voice allocation/priority and spatialization policy; SDL device/queue for G0, configured mixing/spatial DSP/codec mechanisms in the selected production library |
| Diagnostics | Numeric status and copied error text | No exceptions unwinding across C/Kof boundary |

Rules:

- Tokens are slot+generation+kind identities, never raw pointer bits in `Long`. Reject stale/wrong-kind tokens, bounds overflow and double release.
- Adapter registry does **not** own entities, inventory, collision world, animation state or the scene graph.
- Descriptor setters are mechanical translations to SDL structures; they must not hide culling, sorting, material selection or frame scheduling.
- Strings are copied at the call boundary; never retain Kof heap addresses. Return error text with an explicit stable/copy lifetime.
- Main-thread affinity for events/window/GPU work. No C-held Kof callbacks. Foreign audio/driver threads may touch only library/adapter-owned data.
- Explicit teardown after GPU-safe retirement, not GC finalizers. Frames-in-flight require fences/cycling; a Kof object becoming unreachable does not mean a GPU buffer is no longer in use.
- Adapter ABI version and library versions checked at startup; incompatibility fails clearly, not through a no-op renderer.

### Honest upload strategy

The first cube can use scalar staging calls. A matrix/instance is written as a fixed tuple per call, not sixteen individual FFI calls. Static vertex/index payloads upload once; dynamic data uses bounded reusable staging buffers. Kof owns packing policy and resource layout; the C side only copies the specified tuple into checked buffer positions.

For bulk asset payloads, a low-level file-range-to-staging copy may avoid per-byte FFI **only** when Kof has validated/cooked the format, offset and size; the adapter must not become an asset parser/cooker. Small `File.writeBytes/readBytes/readRange` probes preserved zero/high-bit bytes on JVM/native. Large/ranged error cases and actual adapter staging remain unproven; the adapter path is still proposed, not implemented.

Scalar staging overhead is a **go/no-go measurement**. If representative draw/instance/animation uploads miss budget, prefer a properly specified upstream buffer-FFI addition (element format, length, borrow/copy lifetime, ownership and GC rules). Do not encode binary frames as JSON/Base64 strings or assume a pointer cast solves bulk transfer. Do not grow the shim into a C renderer to pass a benchmark.

### Native startup and GC gates

Real SDL video/GPU/audio initialization must run from the emitted native ELF. Kof's direct native entry/runtime may interact differently with libc/TLS/driver initialization than a conventional C executable. A scalar version call proves neither initialization nor callback/thread safety.

Begin with **one Kof thread**. Source shows native auto-GC disabled after any Kof `spawn`; do not use worker threads or manual collection as a workaround. Preallocate hot arrays/scratch, then measure memory behavior including unavoidable runtime allocations. If native cannot satisfy the gates, document the failure and repair the compiler/ABI or explicitly revisit the target choice. Never silently change the shipping target to JVM.

### Compiler correctness gate

Course-driven probes exposed a native exception-handler lifetime defect: a failed assertion after a normally completed try/catch re-entered that earlier catch and falsely exited successfully. Source lowering jumps past `KofTryEnd`; [KOF_COURSE](KOF_COURSE.md) records the path and [COURSE_PROBES](COURSE_PROBES.md) preserves the reproducer and controls. Resolve this in a pinned compiler and revalidate normal completion, later throws and resource cleanup before relying on native exception-based tests or lifecycle handling. A return-based workaround is not proof of a correctly unlinked handler.

Native bounds faults separately terminated without catch/finally, while explicit String-throw and return cleanup passed narrower probes. Validate all indices/capacities/token inputs before access; fatal faults are not recoverable pool misses. Do not claim cleanup for a process-termination path.

## 4. Runtime architecture

```text
SDL event/time polling
        ↓
Client input snapshot → tick-stamped command
        ↓
Serialized loopback/LAN transport
        ↓
Authoritative server session (.kf)
        ├─ fixed-step world
        │   ├─ movement + collision
        │   ├─ weapons + projectiles + damage/statuses
        │   ├─ AI + encounters
        │   ├─ loot + progression + interactions
        │   └─ state changes + bounded domain events
        ↓
Authoritative snapshots/events
        ↓
Client prediction + reconciliation (.kf)
        ↓
Render/audio/UI extraction (.kf)
        ↓
Visibility + sorting + batching + pass orchestration (.kf)
        ↓
Thin scalar/buffer ABI adapter → SDL_GPU / SDL audio
```
### Core plus static modules

KOOKIE uses a **modular monolith**: one authoritative Kof runtime assembled from
explicit, statically linked modules. This is the Iceball-style core-plus-modules
shape without introducing a dynamic plugin ABI or multiple runtime authorities.

`core` is deliberately small and dependency-stable. It owns primitive data and
contracts: IDs, typed storage, math, clock, commands, events, RNG, allocation
limits, revision/generation rules and shared result types. Core does not import
gameplay, rendering, audio, UI, editor code or native handles.

Modules own complete vertical capabilities and may depend only on lower layers:

```text
core
 ├─ content contracts ── world/collision ── gameplay ── arpg
 ├─ presentation contracts ── render
 ├─ domain events ── audio
 └─ UI snapshots ── ui
```

The `render`, `audio` and `ui` modules consume read-only world snapshots and
events. They never mutate authoritative simulation state. `editor` and `cooker`
use the same content/world query contracts but publish changes through revision-
checked transactions. `platform` is an adapter module, not a simulation module.

Modules are source/build boundaries first, not independently loaded binaries.
Each module exposes small data-oriented contracts and keeps implementation
helpers private by convention. The application root composes modules for the
player, cooker and studio entry points. Dynamic loading, arbitrary callbacks,
service locators and a public plugin ABI are deferred until two real consumers
prove a need.

This is preferable to both extremes:

- A single monolithic runtime would simplify the first executable but would
  quickly blur ownership, create import cycles and make the three game profiles
  hard to compose or test.
- Dynamic plugins would add ABI/versioning/lifetime/threading complexity before
  Kof's native FFI and runtime correctness gates are proven.

The first implementation may keep modules in one build and one process. The
boundary is still enforced through dependency direction, read-only snapshots,
typed commands/events and explicit transaction publication.
### Extension architecture

Extensibility is a first-class contract, not access to engine internals. KOOKIE
has two APIs:

1. A private internal module API optimized for the engine and allowed to change.
2. A versioned public extension API composed of handles, definitions, queries,
   commands, events, registries and snapshots. Extensions never receive raw
   pointers or mutable references to core arrays.

The extension model has three tiers:

```text
Tier 1: data packages
  items, weapons, enemies, encounters, levels, materials, UI data,
  localization, recipes, progression and schemas

Tier 2: trusted Kof modules
  new components, systems, AI, world generation, editor tools and commands
  compiled into the application through the static module composition root

Tier 3: optional sandboxed runtime behavior
  only after the core API and failure budgets are proven; restricted to
  declared capabilities and explicit host calls, never engine authority
```

Every extension has a manifest containing a namespaced identity, API/schema
versions, dependencies, capabilities, content declarations, load order,
network role and save migrations. Content IDs are namespaced (`mod:item_name`);
runtime slots and native resource tokens never appear in persistent data.

The public API supports:

- Registry contribution for definitions, components, commands and serializers.
- Read-only world queries and bounded command buffers.
- Phase-specific system hooks with deterministic ordering.
- Domain-event subscription with declared filters and budgets.
- World/encounter generation through seeded, bounded generators.
- Render/audio/UI extraction through engine-owned snapshots and commands.
- Save migration and network codec registration.
- Explicit capability negotiation and conflict diagnostics.

Extensions do not mutate the world during arbitrary callbacks. A system reads
the approved snapshot/query view, emits commands, and receives a deterministic
commit point. Ordering is dependency-first, then declared priority, then
namespaced ID. Conflicts, capacity exhaustion, invalid content and missing
capabilities fail closed with an actionable diagnostic.

The first shipping extension SDK should use trusted `.kf` modules statically
compiled into the player/cooker/studio. This is the safest path through current
native Kof limitations while preserving a stable mod-facing API. A later
runtime script or bytecode tier may provide no-rebuild mods, but it must use
the same public contracts, capability limits, save/network declarations and
deterministic budgets. It must not become a second gameplay authority.

Internal modules may access optimized arrays directly. Public extensions may
only use stable handles, queries, commands, events and snapshots. This keeps
the engine fast without forcing every internal refactor to become a permanent
modding promise.
### Multiplayer-first session model

Every play is a network session. Single-player is a local listen server plus a
local client connected through the same loopback transport used by LAN play;
there is no privileged single-player simulation path.

```text
single-player:
  player process
    ├─ authoritative server world
    ├─ client presentation world
    └─ serialized loopback protocol

LAN host:
  host process ─ server world + local client
  peer processes ─ client worlds

dedicated server:
  headless server world
  peer processes ─ client worlds
```

The server owns authoritative simulation, content identity, RNG outcomes,
damage, inventory, loot, progression, world persistence, extension execution
with server authority and admission decisions. A client owns input capture,
local presentation, prediction of explicitly permitted actions and
reconciliation. Client results are proposals, never authoritative outcomes.

The first transport contract is transport-independent:

- Reliable ordered control channel for handshake, join/leave, commands that
  require delivery, content/session metadata and migration errors.
- Unreliable sequenced channel for input and snapshots where newer state
  supersedes older state.
- Explicit tick, sequence, acknowledgement, baseline and content-revision
  fields.
- Bounded packet sizes, decode work, queues and entity counts.
- No native pointers, runtime slots or raw Kof object memory on the wire.

The loopback path must serialize and decode messages instead of passing
references directly. This proves the real client/server boundary in
single-player and prevents local play from hiding replication bugs.

Session admission checks protocol/API versions, engine build identity, content
package hashes, extension manifests, capability requirements and compatible
save schema before a client enters the world. The server rejects mismatches
with a diagnostic; it does not silently downgrade gameplay authority.

Extensions declare `server`, `client`, `shared` or `data` roles:

- `server` extensions may register authoritative systems, world generation,
  replication schemas, commands and save migrations.
- `client` extensions may register prediction helpers, render/audio/UI
  extraction and presentation assets.
- `shared` extensions provide definitions and codecs required by both sides;
  they must obey deterministic rules.
- `data` extensions contribute validated content without executable behavior.

No extension may make a client-only decision authoritative. Server and client
must load compatible namespaced definitions, and replicated extension state
must use declared schemas rather than serialized internal arrays.

Prediction is selective, not a promise of cross-platform float lockstep.
Clients predict local movement and other explicitly approved commands, retain
input history, then reconcile against server snapshots. Damage, inventory,
loot, progression, encounters and world persistence remain server-owned.




### Entity/component storage

Start with explicit component arrays, not a reflection-heavy general ECS framework:

- Generation-checked entity identity; free-list allocator; dense active iteration lists.
- Separate typed arrays for transform/velocity/health/collider/weapon/projectile/AI/status data; cold immutable definitions outside tick state.
- Preserve stable IDs across references; saves use persistent IDs and definitions, not dense slots or SDL tokens.
- Structural creates/destroys deferred to a known tick boundary; no iterator invalidation during damage/collision traversal.
- Separate component-presence/active fields; avoid nullable primitive semantics in hot pools.
- Pool capacity and overflow behavior explicit. Critical damage/death/loot state cannot silently disappear. Reject excessive content/spawns deterministically, reserve capacity before committing transactions, or retain a bounded pending result. Cosmetic effects may be dropped with an observable count.

Use Kof records/classes for configuration and cold results. For math kernels operate on scalar fields/caller-owned arrays; no temporary vector objects per collision/ray/particle.

### Clock and input

Initial decision: **60 Hz simulation**, render independently with interpolation; max **four** catch-up steps. Clamp incoming debt to a documented bounded window; account for discarded simulation time rather than spiral indefinitely. No promise of deterministic cross-platform float lockstep.

- One-shot commands persist until an actual tick consumes them; they are not repeated for every catch-up tick.
- Held movement/fire is sampled for each tick. Mouse delta is an angular input, not velocity multiplied by dt; assign its accumulated delta exactly once or distribute explicitly across pending command ticks, never duplicate it.
- Focus loss clears held input, releases capture and prevents stale firing. Pause resets accumulated wall-clock debt and disarms pending one-shot actions according to the game profile.
- Render interpolation never mutates authoritative state. Optional late camera presentation must not change recorded aim used by hits.
- Replay records the resulting tick commands, not raw platform events or frame times.

### Tick ordering

One documented order: consume commands → update timer/status deadlines and AI intents → movement/collision → weapon/projectile resolution → centralized damage/death/rewards → interactions/inventory transactions → deferred entity changes → output snapshot/events. Stable ID order breaks equal-time ties.

Status/weapon deadlines use integer ticks. DOT ticks have explicit inclusive/exclusive expiry rules and are not skipped merely because one rendered frame was long. Record and test the chosen rule.

## 5. Movement, world collision and physics

Use real 3D triangle/convex static collision with a **kinematic capsule player**, not a raycaster world constraint or a general rigidbody library as the initial authority.

Kof-owned collision modules:

- Ray/segment tests, swept broadphase bounds, triangle BVH construction/traversal, nearest-hit reduction.
- Capsule/convex contact and continuous sweep, bounded slide iterations, skin tolerance, ground probing, slope limit and step-up/forward/down sequence.
- Dynamic actor broadphase plus narrow phase; swept sphere/capsule projectiles; teleports have separate overlap recovery.
- Zero-length movement, starting penetration, grazing edges, opposing contacts and high-speed pass-through are explicit cases. Never use only destination overlap.
- Static/moving door platforms modeled with owned transforms and consistent query data. Player, AI LOS, bullets and editor picking query the same authoritative cooked world.

Movement profiles define ground friction/acceleration, air acceleration, speed caps, jump buffering/coyote time, bunnyhop/dash policy and crouch. Borrow DINX intent/jump contracts; implement projection-based Quake-like acceleration as a deliberate profile rather than mislabeling vector-approach acceleration.

A rigidbody library is not initially required. If later demanded for piles/vehicles/destruction, assess it as an explicit external-library exception; never move player/combat authority into it by default.

## 6. Renderer and presentation

Initial renderer: opaque/masked forward rendering, depth buffer, static lightmap or vertex-light support, bounded dynamic lights, instanced static meshes, sprites/billboards, first-person viewmodel, decals/particles and HUD. True 3D permits stacked rooms, pitch, slopes, vertical encounters and mesh enemies.

- Kof performs frustum/spatial culling, visibility lists, material/mesh/pipeline grouping, transparent ordering and render-pass orchestration.
- Static resources retained; frame buffers/staging reused. Dynamic resource churn forbidden in steady play.
- Baseline passes: depth/opaque + optional bounded shadows, transparent/effects, viewmodel, postprocess/tone map, UI. Do not introduce deferred/clustered complexity until measured light populations need it.
- Low-resolution/pixelated, palette/limited-light and cleaner modern styles are material/postprocess profiles, not alternate world simulators.
- Single coordinate convention: meters, Y up, right-handed world, camera forward -Z. Build explicit projection/clip conversion for SDL_GPU's documented clip/depth convention; do not transpose/flip ad hoc. Validate culling winding, normals, handedness, depth range and texture origin together.
- Shader sources in HLSL, offline SPIR-V for first platform; pin SDL_shadercross and reflect/validate vertex/uniform bindings. Additional backend shader products only when their target is exercised.
- First animation path: sprite/billboard or rigid mesh; then Kof animation state/interpolation and skeletal pose evaluation, GPU skinning shader. Bind pose/index/weight admission stays in the cooker. No per-frame asset parsing.
- HUD/menu/inventory/debug overlay CPU logic and layout are `.kf`, rendered through the engine. External text/font rasterization may be a narrow library dependency; do not begin with an entire webview editor/runtime UI.

Targets such as viewmodel FOV, recoil/sway, muzzle flashes, hit feedback, readable rarity colors and status icons are engine features, not reasons to put presentation logic in the C adapter.

## 7. Combat and ARPG model

### Weapons and damage

Separate immutable `WeaponDef` from runtime magazine/reload/cooldown/spin/burst state and item-instance modifiers. Support hitscan, swept projectile, shotgun spread and area damage through shared query/damage paths.

- One trigger state machine; no competing old/new firing systems.
- Per-shot stable ID and explicit RNG stream; ammo consumption and accepted shot creation commit together.
- One `DamageRequest` resolution path applies source scaling, crit, armor/resistance, shield/health, status application and death transition in a documented order.
- Damage channels and mitigation formulas are data-driven but versioned. Do not silently combine incompatible CUBSHIP armor-before-resistance and ZYLVE formula assumptions.
- Exactly one alive→dead transition owns XP, loot and quest credit; presentation consumes events and never awards rewards.
- Enemy/boss affixes can modify defined hooks without arbitrary same-frame recursive proc loops. Proc depth/rate limits explicit.

### Loot, inventory and progression

- `ItemDef` identifies a template; `ItemInstance` stores stable ID, seed, item level, rarity, selected affixes/rolled values and mutable condition/socket state.
- Loot selection: encounter table → weighted base item → rarity → eligible prefix/suffix/mod pool → rolls with exclusions/tier constraints. Use separate per-system RNG streams; preserve results in saves.
- Affix composition order explicit: base → flat → additive percentage → multiplicative groups → caps/rounding. Recompute on equipment/definition changes, not every frame.
- Inventory/equipment/stash/crafting use validation + reservation + atomic commit. Full inventory, duplicate IDs, insufficient currency and incompatible slots leave items, currency and RNG unchanged.
- Skill definitions declare prerequisites/rank caps/costs/cooldowns/tags; character instances own ranks/loadout/XP/resources.
- Status definitions specify refresh/replace/add-stack rules, duration cap and ticking schedule. Death/reset/load clears or retains effects intentionally.
- Save item rolls, not merely current RNG state, so balance/content migration cannot silently reroll equipment.

Borrow ZYLVE's transaction/identity invariants, not its fixed weapon names, small inventory sizes or fixed tier-drop tables. These systems are part of the planned engine, not deferred out of scope after a shooting demo.

### AI and encounters

Begin with deterministic state machines: idle/patrol/investigate/chase/attack/recover/stagger/dead; melee, projectile and hitscan archetypes. Kof perception uses spatial candidates, squared distance/FOV cosine, shared LOS and tick-stamped threat memory.

Authored waypoint/portal navigation first, then a real cooked navmesh/A* pipeline with bounded expansions and explicit `pending/success/failure`. Spread expensive perception/path updates over ticks; fixed scheduling and owned scratch arrays, no Kof worker threads until GC-safe. Encounter volumes, wave budgets, boss phases, spawn admission, key/door/secret triggers are data-driven.

## 8. Content, creator workflow and persistence

### Content pipeline

Editable sources → **Kof cooker** → versioned engine package → validated runtime load.

Initial source formats: project manifest and entity/encounter/item definitions
in readable structured data; static meshes/materials in a documented glTF
subset; Dust3D `.ds3`; LibreSprite `.ase`/`.aseprite`; MagicaVoxel `.vox`;
images/audio in a deliberately small supported set. These are offline intake
formats, not runtime package formats. Validate finite geometry, triangle
indices, voxel dimensions/palette references, sprite frame bounds, animation
metadata, size/count limits, resource references, transforms and collision
flags. Native decoder libraries may provide pixels/PCM, not scene/loot/collision
semantics.

### External asset intake compatibility

The Kof cooker preserves the original source and tool/version receipt, then
normalizes the result into the canonical package contract:

| Source | Required intake result |
|---|---|
| Dust3D `.ds3` | Validate exported mesh/UV/skeleton data and produce GLB plus materials and optional collision |
| LibreSprite `.ase`/`.aseprite` | Extract bounded frames/layers/tags/slices and produce PNG atlas, versioned metadata and animation definitions |
| MagicaVoxel `.vox` | Parse bounded voxel models/palette/supported scene chunks and produce deterministic mesh/GLB plus materials and optional voxel collision |

Use GLB for 3D runtime interchange and PNG plus versioned metadata for sprite
runtime interchange. OBJ/FBX are conversion fallbacks, not runtime contracts.
Unsupported chunks, color/depth modes, animation features or coordinate
conventions fail with a diagnostic or require an explicit normalization rule;
they never pass through as ambiguous data. Publish only after decoded-size,
index, palette, frame, transform and finite-number limits pass.

Dust3D is an external MIT authoring tool. LibreSprite is GPLv2 and cannot be
embedded in KOOKIE; use external export or an independently implemented format
reader with separate notices. MagicaVoxel is proprietary freeware; do not
bundle its application. Accepting user-provided `.vox` files and reading the
documented format does not grant redistribution rights to the tool.

For boomer-shooter authoring add a Quake-style textual brush `.map` subset: convex brush plane clipping/triangulation, entity/property translation, material mapping and derived collision/visibility. TrenchBroom can be an external authoring tool; our `.kf` cooker remains the import authority. This does **not** promise WAD/BSP/QuakeC/source-port compatibility. Source maps are not shipped original-game assets.

Cooked package contract: magic, schema/tool/content versions, stable IDs, chunk offsets/lengths, dependency hashes, explicit endianness, bounds and corruption checks. Reject traversal, duplicate IDs, overlapping/out-of-range payloads and decompression overrun. Do not serialize Kof object memory or internal array headers.

Native mixed Int/Double/String record JSON failed the measured round-trip, including corrupt numeric/string values; direct record getters passed. Before adopting native JSON for definitions, glTF or saves, require a compiler/runtime repair and schema-specific round-trip, malformed-input and bounds proof. Do not truncate floats, silently switch the cooker to JVM or move content semantics into the adapter. Binary file IO passed a small probe but is not an implemented alternative format/codec.

Current source rejects native `process.run`/`process.spawn` with `PROC001`. External shader/conversion tools therefore need the permitted minimal build orchestration or a separately proven platform capability; the native `.kf` cooker cannot assume the course's process examples work. It still owns content validation and cooking decisions.

### Engine authoring tools

Do not fork Kof Editor first. Build `.kf` tools that use the same runtime libraries:

1. Command-line cook/validate/package and a playable project template.
2. In-engine inspector/console, spawn/weapon/loot tools and collision/AI visualization.
3. World/entity editing, asset browser, encounter/item/skill editors, undo/redo and play-in-editor.
4. Prepare all fallible edit/cook work, then revision-check and publish world/collision/nav/render products together at a frame boundary. Never show new geometry with stale collision.

Data/shader reload can be supported after validation and GPU-safe retirement. Initial `.kf` code iteration is rebuild/restart, not promised arbitrary live code replacement. Do not introduce a second scripting language.

### Saves and replay

- Versioned save sections: character/progression, item instances and ownership, world persistence, quest/encounter state, explicit RNG streams and content IDs.
- Snapshot at a defined tick boundary; stage file, validate/checksum, flush/sync, atomic replacement and directory-durability policy appropriate to the target. `BoundedRedundantSaveFileStore` and `BoundedSaveSchemaFileStore` now write two bounded wire copies, recover one corrupted copy and repair both copies; interrupted-write recovery, flush/sync, atomic replacement and directory durability still require a proven filesystem primitive. Corruption detection is not authentication.
- Migrations operate on schemas, never raw slots/pointers. `BoundedSaveSections`, `BoundedSaveSchemaWireCodec`, `BoundedSaveSchemaFileStore` and `BoundedSaveMigrationGate` now persist and migrate known legacy, progression, world and RNG sections, including version-zero world/RNG default-field transforms; unsupported/newer sections fail with the old save left intact. Future section-version transforms remain required.
- Replay stores engine/content version, initial snapshot/seed, tick commands and checkpoints/hash diagnostics. `BoundedReplayWireCodec` and `BoundedReplayFileStore` now persist bounded engine/content metadata, seed, signed tick commands, ordered checkpoints, hash diagnostics and initial snapshots with corruption rejection; bounded seek selects a checkpoint and exposes commands through the target tick, while simulation re-execution remains the caller's responsibility. Timestamped presentation events are not sufficient.
- Mod policy: trusted `.kf` code requires rebuild and has host authority; data-only mods have bounded path/schema admission. Do not label trusted code a sandbox.

Networking is a first-class requirement, not a later co-op feature. Preserve one
authoritative server simulation, serializable tick commands, snapshots,
prediction/reconciliation and transport-independent codecs from G0 onward.
Single-player uses the same server/client session over loopback; LAN host and
dedicated server are compositions of the same session modules. Do not promise
cross-target float lockstep: replicate commands, authoritative state and
declared extension schemas instead.

## 9. Proposed source layout

Directories below are **future ownership boundaries**, not files created by this
research. Final entry/module-root wiring is established in milestone G0; Kof
`run` auto-collects sibling sources, so multiple mains cannot simply live under
one indiscriminately collected root.

```text
src/
  core/          ids, arrays, math, clock, commands, events, RNG
  platform/      Kof extern declarations and checked resource wrappers
  session/       server/client roles, admission, ticks, snapshots, prediction
  net/           wire messages, codecs, channels, sequence/ack/baseline state
  world/         entity state, spatial queries, level state, collision
  render/        extraction, culling, materials, batching, pass policy
  animation/     clips, pose state, interpolation
  audio/         voice policy, spatialization, event mapping
  gameplay/      movement, weapons, damage, AI, encounters, interactions
  arpg/          item definitions/instances, stats, loot, skills, progression
  content/       schemas, validation, package readers, migrations
  extensions/    manifests, registries, capabilities, public API adapters
  ui/            HUD, menus, inventory, debug/authoring views
apps/            player host/client, dedicated server, cooker, studio
samples/         boomer arena and looter/ARPG encounter projects
native/          only indispensable ABI/library adaptation
shaders/         GPU-only source and generated backend products
content/         authored source assets/definitions with provenance
```

No monolithic `runtime.kf` owns all systems. No generic service container or
plugin ABI before two concrete consumers require it. Session and network
modules depend on core contracts; server modules own authority; client modules
consume snapshots and emit input commands; renderer callbacks never mutate the
world.



## 10. Milestones and observable acceptance

No calendar promise; each gate has runnable evidence. A successful gate authorizes the next scope, not a declaration that the complete engine exists.

| Gate | Work | Acceptance / stop condition |
|---|---|---|
| **G0 — Native and session feasibility** | Pin compiler/artifact/SDL; resolve exception-handler defect; establish modular build; define wire envelope/codecs; scalar adapter/resource tokens; real native startup; memory/FFI measurements | Corrected native handler-lifetime/cleanup probes pass, including negative controls. Native ELF opens isolated SDL_GPU window, draws textured geometry, handles resize/focus/relative mouse, plays a short queued audio clip, closes cleanly. Loopback transport can encode/decode bounded control/input/snapshot messages without references or raw pointers. Failure blocks native/session architecture commitment |
| **G1 — Authoritative shooter foundation** | IDs/component arrays, 60 Hz server tick, client input commands, loopback server/client worlds, snapshot baseline, capsule/BVH, camera, renderer/HUD, one weapon/enemy | Single-player completes a real server→loopback→client session. Client prediction/reconciliation is observable. A second client can be admitted by the same protocol harness. Authored true-3D arena supports slopes/stairs/stacked rooms; focus loss cannot stick fire/movement. No per-frame pool growth |
| **G2 — LAN boomer-shooter slice** | LAN transport adapter, hitscan/projectile/shotgun, several enemy roles, doors/keys/secrets, feedback/audio, encounter definitions, join/leave handling | Host and at least two clients complete start→fight→key/door→secret→exit over LAN. Server owns damage/death/rewards. Disconnect/reconnect and stale input are bounded and diagnosed. Movement profiles remain tunable without renderer changes |
| **G3 — Looter / ARPG slice** | Rolled items/affixes, inventory/equipment, XP/skills/statuses, elites/bosses, authoritative saves, extension registries and replicated schemas | Multiplayer kill→rolled drop→pickup/equip→observable stat/skill change→boss reward→save/reload. Full inventory cannot lose item/currency/RNG. Same seed/content yields same server result. Clients cannot mint damage, items, currency or progression |
| **G4 — Creator and extension pipeline** | Kof cooker, supported mesh/brush formats, package validation, data-mod manifests, trusted Kof extension modules, inspector/editors, staged reload | A second distinct multiplayer sample game is built from definitions/extensions without editing core engine code. Server/client reject incompatible package/API/mod manifests. Invalid content leaves the prior running world intact; geometry/collision/nav/replication revisions stay aligned |
| **G5 — Scale and release** | AI budgets, batching/instancing, animation, streaming only as needed, dedicated headless server, migrations/replay, reconnect/admission hardening, packaging/notices | Reference LAN workload meets declared budgets; dedicated server runs without graphics; memory/resource counts plateau; package runs outside source checkout; reconnect/session recovery and extension compatibility are proven |
| **G6 — Expansion** | Extra OS/backend/architecture, safe jobs, WAN transport, richer editor, runtime sandboxed extensions | Each extension proves actual runtime/ABI/content compatibility; no portability, WAN, sandbox or platform claim is inferred from dependency support |

G0 small core/scalar/import/IO probes are **partially researched**, not complete. The precise experiments in RESEARCH_PROBES and COURSE_PROBES include both successes and unresolved native failures. There is no compiler repair, SDL window, GPU adapter, sustained timing or memory proof yet.

### Initial performance hypotheses, not achieved numbers

Reference scene for first scale gate: 64 active enemies, 256 moving projectiles, 512 pickups, bounded dynamic lights/effects and one medium authored level. Maintain a heavier stress variant after the baseline is correct; do not claim arbitrary population scalability.

Targets to measure on explicitly recorded CPU/GPU/driver/resolution/build: 60 Hz simulation, p95 simulation work ≤4 ms/tick, p95 frame ≤8.33 ms for a 120 Hz rendering target at 1080p, and no monotonic resource/RSS growth in a 30-minute bounded soak after warm-up. Record p99/max and GC/upload costs, not average FPS alone. A miss changes capacity/content/implementation based on profiles; it does not justify moving gameplay out of Kof.

These thresholds are design goals. Correctness may be tested under software rendering, but software-renderer timings cannot certify hardware targets. Graphics/input proof must be serialized inside an isolated disposable display environment.

## 11. Verification and decision risks

### Focused proof strategy

- Language/ABI: small executable `.kf` probes covering exact new types, imports, scalar/buffer lifetimes and native library paths.
- Compiler failure paths: externally compare outputs/exit status; a green native exit can conceal a caught assertion. Keep normal-try→later-throw negative controls and fatal-versus-catchable fault distinctions. Do not reuse self-catching assertion recipes from the course.
- Collision: thin-wall pass-through, starting overlap, slope/step boundaries and corner slide; retain focused regressions for plausible defects.
- Simulation: one-shot edge consumption under zero/multiple ticks, overload debt policy, pause/focus transitions.
- Combat: ammo+shot atomicity, cooldown deadlines, DOT expiry/catch-up, one death/reward transition.
- Economy: item conservation and uniqueness, failure rollback, RNG rollback, save/load/migration consistency.
- GPU: actual surface verification for shader/texture/culling/depth, resize/minimize/focus and resource teardown. Never substitute source checks or an `InitWindow` print fixture for a real window.
- Tooling: malformed content rejection and stale edit/cook result rejection with prior valid world preserved.

Repository display rule: use `overzeer-isolated-display` or an equivalently reviewed wrapper with private display/session sockets, bounded timeouts and complete process-tree cleanup. Never interact with the developer desktop/monitors. Plain Xvfb or merely unsetting DISPLAY is insufficient for graphical tests. No full matrix during implementation; final pre-commit matrix only with the user's one-shot permit.

### Risk register

| Risk | Current evidence | Action / release gate |
|---|---|---|
| FFI has no bulk buffers/structs/pointers/native callbacks | Source + array rejection measured | Minimal scalar adapter; measure upload overhead; upstream buffer contract if needed |
| Native C-runtime/driver initialization | Only version/libm calls measured | G0 real SDL GPU/audio/input proof; do not infer from mock ABI fixtures |
| Native collector after spawn | Cumulative spawn gate in allocator source | Single Kof thread; long soak; no unsafe manual-GC bypass |
| Native codegen performance | Minimal optimization pipeline | Measure representative arrays/math/FFI; use batching/preallocation; no C gameplay rewrite |
| Distribution runtime pruning | Warning reproduced outside compiler checkout | Fix upstream or explicitly measure/accept full-runtime dependency/size before release |
| Native stale exception handler | Later assertion re-entered a completed try/catch and exited 0; lowering skips handler removal | Resolve/revalidate before trusting G0 exception cleanup or test results; no control-flow shim |
| Native JSON/split parity | Fractional mixed-record JSON corrupted values; escaped-pipe split differed from JVM | Repair/prove exact content/save schemas and parser contracts before G3/G4 reliance |
| Language/docs rapidly diverge | 0.3.7 course / older portal pages / 0.4.9 release | Source SHA + executable digest; upgrade through focused behavior probes, not compile-only claims |
| Editor reliability/security | Single-file run, JS UI, privileged unauthenticated handlers | CLI + separate LSP-capable editor; no dependency on editor fork |
| Creator pipeline becomes second engine | Sibling monoliths/multiple authorities | Shared .kf runtime/query/content contracts; staged frame-boundary publish |
| License/asset assumptions | Mixed sibling rights; unlicensed DoomKof source | Preserve provenance, resolve grants, own/test assets initially |
| Native portability overclaimed | Examined native output is Linux ELF | Separate platform gates; SDL backend list is not Kof executable support |

## 12. First implementation increment

**G0 is in progress.** The initial modular/session foundation now exists:

- `src/core/foundation.kf`: scalar core protocol/tick contracts.
- `src/session/loopback.kf`: bounded five-word envelope smoke codec.
- `src/main.kf`: one modular Kof entrypoint.
- `probes/g0_platform/main.kf`: isolated scalar SDL3 platform probe.

Focused JVM/native runs pass for the session smoke and direct scalar
`SDL_GetVersion()` probe. The native backend still emits the known full-runtime
pruning warning. The first attempt exposed a Kof cross-package record/array
boxing defect and a wrapped-scalar-extern verifier defect; the implementation
now keeps the initial public module boundary scalar/array-contract based and
isolates direct FFI in its own probe. These compiler defects remain upstream
gates, not engine workarounds to generalize.

Next G0 actions:

1. Preserve these probes as focused regressions and establish the checked
   token/resource contract without pointer casts.
2. Prove actual SDL window/GPU/audio initialization from native ELF under the
   isolated display wrapper.
3. Measure scalar tuple staging and bounded single-thread memory behavior.
4. Repair or explicitly gate the native compiler defects before adding the
   full session/world implementation.
