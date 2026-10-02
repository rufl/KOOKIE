# KOOKIE engine plan

Status: **living architecture and acceptance gates; the bounded G0–G6 implementation is complete within explicit qualification limits, while the D1 playable-demo release remains open**.

Research baseline: 2026-09-22, Kof 0.4.9-beta. Current qualification gate:
Kof 0.5.0-beta source commit
`bf17ac7e736471c8a04b4153e5b0f607be75e70c`. Project architecture is
[ARCHITECTURE.md](ARCHITECTURE.md). See [language/runtime evidence](KOF_LANGUAGE.md),
[initial probes](RESEARCH_PROBES.md), [course deep dive](KOF_COURSE.md),
and [game-system survey](GAME_ECOSYSTEM.md) for evidence boundaries.

The current release gap is tracked in [Demo release readiness](DEMO_RELEASE.md).
On 2026-10-02, signed Linux package/package smoke and Windows native PE/SDL
presentation artifact gates passed with temporary pinned build dependencies.
They do not replace a clean-tree paired build, outside-checkout interactive
smoke or target-hardware presentation evidence.

## 1. Product and non-negotiable ownership

Build a **true-3D, content-driven first-person engine** supporting three game profiles on the same simulation/render/content foundation:

| Profile | Required strengths |
|---|---|
| Boomer shooter | Responsive mouse look, acceleration/air control, readable projectile patterns, keys/doors/secrets, authored interconnected combat spaces, fast weapon switching |
| Looter shooter | Rolled item instances, firearm archetypes and affixes, equipment/inventory, elite modifiers, repeatable encounter/reward loops, save integrity |
| ARPG FPS | Active skills with prerequisites, resource costs and cooldowns, progression trees, damage types/resistances, defensive and timed/stacking effects, build synergies, bosses and equipment-driven builds |

These are configurable rulesets, not three forks. A boomer profile can disable loot/progression without maintaining a second movement, collision or renderer implementation.

### Source ownership rule

All **engine-owned CPU behavior** is `.kf`: loop, entity storage, math, movement, collision, AI, combat, loot, animation decisions, render extraction/culling/sorting/pass policy, audio policy, saves, content cooking, runtime UI, authoring logic and game code.

Allowed non-Kof boundary, kept small and reviewable:

1. Unmodified external platform/GPU/audio/codec libraries, initially SDL3.
2. C ABI marshaling that Kof cannot currently express: native handles, struct/event unions, pointers, buffer transfer and library setup/teardown. No gameplay or scene algorithms.
3. GPU shader source/binaries: Kof does not currently provide a supported general graphics-shader target. HLSL/SPIR-V and generated backend variants are an explicit graphics exception, not CPU engine code hidden elsewhere.
4. External compiler/linker/shader tools and minimal declarative build/bootstrap glue. KOOKIE-owned kooker/editor behavior remains Kof, not Python/JS/Zig/Rust applications.

The existing Kof compiler/runtime is an upstream tool dependency written partly in Java/assembly. Fixing an upstream compiler defect is distinct from moving KOOKIE gameplay into Java. Any maintained compiler delta must be pinned, documented and upstreamed where practical.

**Forbidden shortcuts:** a Java/Bevy/Zig engine driven by `.kf` scripts; handwritten JS game logic stored in Kof strings; a C `engine_tick`/`render_world` implementation; casting integers into arbitrary native pointers; duplicating gameplay in a second language to make the demo work.

This plan does not choose a public license or authorize redistribution of third-party assets. Resolve ownership/notices before publishing ports.

## 2. Platform and graphics decision

### Proposed baseline: SDL3 + SDL_GPU

- First runtime: **Kof native Linux x86-64 ELF**.
- Development oracle: JVM for small pure-Kof differential probes, not a silent shipping fallback.
- Initial graphics backend: SDL_GPU Vulkan with offline SPIR-V shaders.
- SDL handles window/events/relative mouse/gamepads/timing/audio-device access. Kof owns the main loop and game state.
- SDL_GPU handles device resources, command buffers, upload synchronization, pipelines, draw/compute submission and presentation. Kof decides what to submit and in what order.
- Use one renderer implementation initially. Do not build SDL, Sokol, raylib, OpenGL and Vulkan backends simultaneously.

**Why:** full 3D/instancing/compute headroom for projectile crowds and ARPG effects, modern desktop backend model, robust shooter input surface, one platform dependency and a single inspectable platform/graphics boundary. This is a design judgment, **not measured evidence that SDL_GPU is fastest for Kof**.

### Alternatives considered

| Candidate | Fit | Decision |
|---|---|---|
| SDL3 + SDL_GPU | Vulkan/D3D12/Metal abstraction; polling input/main loop; GPU resources/compute; one platform/GPU API boundary | Preferred native spike |
| SDL3 + `sokol_gfx` | Compact GPU API; explicit render extraction/batching; can retain SDL platform loop | Viable alternative if SDL_GPU hardware/shader constraints fail; adds integration between two libraries |
| `sokol_app` + `sokol_gfx` | Small footprint, portable graphics, compact retained API | Native Kof cannot currently supply retained callbacks; app lifecycle would need extra bridge ownership. Not the first path |
| raylib / Jaylib | Shortest route to examples; actual DoomKof precedent; math/models/audio included | Good comparison/prototyping option, but Jaylib means JVM and many raylib structs still need native ABI work. Not a substitute for the engine-owned renderer plan |
| Direct Vulkan | Maximum control | Too much driver/synchronization/shader work before shooter behavior; no demonstrated need |
| LWJGL | Mature JVM bindings | Target-specific alternative, not evidence of native Kof interoperability |
| Kof Canvas / WebKitGTK | Existing 2D/browser ecosystem | Wrong initial real-time 3D/runtime boundary; browser is not the native target |
| Bevy/wgpu through Rust shim | Large Rust runtime and rendering ownership stack | Violates engine ownership if simulation/render architecture remains Rust |

Sokol remains credible; it is not rejected as incapable of shooters. Its backend list evolves, so pin headers/shader tools if selected rather than relying on stale capability tables.

SDL_GPU also has limitations: modern GPU feature floor, strict shader resource layouts, no general browser backend in the proposed route, no promise of cutting-edge ray tracing/mesh shaders. SDL portability does not imply full Kof native PE/Mach-O output. KOOKIE now retains a separately gated reachable AMD64 console PE/COFF compiler path with qualified native Windows Kof PE gameplay and native PE/SDL_GPU presentation packaging; Windows presentation smoke remains target/GPU-gated, while macOS, ARM and browser support remain independent expansion gates.

Sources: [SDL GPU contract](https://wiki.libsdl.org/SDL3/CategoryGPU), [relative mouse mode](https://wiki.libsdl.org/SDL3/SDL_SetWindowRelativeMouseMode), [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross), [Sokol](https://github.com/floooh/sokol), [raylib](https://github.com/raysan5/raylib), [SDL license](https://github.com/libsdl-org/SDL/blob/main/LICENSE.txt).

### Modern Minecraft reuse assessment

[MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md) records the current Java26.3 stack and candidates. Its SDL3 migration supports our platform choice, **not** a claim that Minecraft uses SDL_GPU. Its Renderpearl API split does not establish an open-source reuse grant. Current rendering lessons are extracted frame state, explicit pass attachments, resource generations, visibility/batching and persistent instance lifetimes.

Prioritize bounded `.kf` math/command ports from JOML/Brigadier, Artemis/Ashley-inspired typed storage, Minecraft-style definition/item-patch/codec contracts, owo-inspired layout and Flywheel-inspired instance lifecycles. JOML1.10.9 was measured on Kof JVM; native rejected its Java imports. Do not import JARs or entire mod runtimes as native engine libraries.

Kof owns bounded listener-relative attenuation and stereo panning and submits
PCM without per-call allocation. SDL_mixer 3.2.4 is now the sole
device/mixing authority with separate effects and music buses. OpenAL Soft is
not distributable under the native presentation profile's permissive-library
policy. Jolt physics and RmlUi/ImGui UI still require explicit
foreign-subsystem ownership approval.

### Recommended library set (2026-09-22)

Selection criterion: native Linux shooter fit, maintained narrow APIs, license
clarity, and compatibility with `.kf` ownership—not an unmeasured claim of
maximum performance. Adopt in stages; do not link every candidate into G0.

| Area | Recommended choice | Boundary / reason |
|---|---|---|
| Platform and graphics | **SDL3 + SDL_GPU** | One window/input/gamepad/GPU stack; 3D and compute. Kof owns extraction, culling, batching and passes. zlib license. Keep Sokol as an alternative only if the GPU/ABI spike fails |
| Shader build | **SDL_shadercross + DXC**, SPIRV-Cross and SPIRV-Tools as required by the build | HLSL → offline SPIR-V for Linux; reflect resource layouts. Build-time tools, not mandatory shipped runtime shader compilers. Installed ShaderC alone is not the selected HLSL pipeline |
| Audio | **SDL_mixer 3.2.4** | One zlib-licensed mixer authority with separate effects/music streams and Kof-owned cue, gain and spatial policy. Optional codec backends are disabled/not bundled; PCM streams require no decoder dependency |
| Image decoding | **Kof-owned PNG kooker**, then **SDL3_image** only for a runtime pixel service | The current kooker validates, decodes and canonicalizes the bounded PNG subset itself. A future SDL3_image boundary may decode admitted canonical PNG for upload; it does not own source admission, color-space/material decisions or cooking. zlib library; optional codec dependencies have separate notices |
| Text rendering | **FreeType**, then **HarfBuzz** when implementing shaped text | Rasterization and shaping services only. Kof owns widgets, layout, focus and glyph-cache policy. Font fallback, bidi/line breaking, IME and accessibility are not solved merely by linking these libraries |
| Package compression | **Zstandard (`libzstd`)** | Add at the cooked-package stage, not per frame. Use bounded independently addressable chunks, declared decoded lengths and decoder limits; compression is not integrity/authentication. BSD license option |

**Audio choice details.** SDL_mixer is the adopted device/mixer authority.
KOOKIE submits generated PCM streams and bounded cooked PCM16 clips, so
packages do not need optional compressed-audio decoders. Any future native
codec must pass the permissive-license and dependency-closure gate before
packaging. OpenAL Soft is not an alternative under that native presentation
policy because the inspected implementation is LGPL-2.0-or-later. The separate
Windows JVM profile retains its OpenJDK license tree; it does not relax the
native media-library gate. Do not run a second library as a competing mixer
authority.

**Keep these engine libraries in Kof:** typed entity/component storage; a small
math library using selective MIT JOML ports; shooter movement/collision;
AI/navigation under the current rule; combat/loot/statuses; content schemas and
source admission for glTF/brush maps, Dust3D, LibreSprite and MagicaVoxel;
player UI and authoring logic. Do not add a foreign ECS or call a C math
library once per vector operation. GLB is the canonical 3D interchange result,
while source-format intake remains a validated kooker concern; the native JSON
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

**Observed local availability:** SDL3 3.4.16 is the system package;
SDL_mixer 3.2.4 was built from pinned source with only the PCM input needed by
this integration. FreeType 2.14.3, HarfBuzz 14.5.0 and zstd 1.5.7 are also
available. SDL3_image and SDL_shadercross remain outside the current gate.
This inventory does not prove automatic future integration.

**Adoption status/order:** SDL_GPU/input, checked token transfer, the world-space
perspective/material/depth pass, bounded stereo spatialization and SDL_mixer
effects/music gain are integrated. Add image/text services and package
compression only when each contract is established. Pin artifact hashes, build
options, transitive notices and adapter ABI at each adoption. This shortlist
implies no separate backend/plugin framework or performance promise.

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

The upstream native Kof runtime currently accepts scalar `extern` calls;
arrays/structs/pointers/out-buffers and native callbacks remain blocked there.
The KOOKIE PE bridge separately lowers bounded heap/array values and integral
FFI for the qualified Windows graphs. The original measurements covered actual
SDL version and libm calls, **not graphics initialization**.

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

For bulk asset payloads, a low-level file-range-to-staging copy may avoid per-byte FFI **only** when Kof has validated/cooked the format, offset and size; the adapter must not become an asset parser/kooker. Small `File.writeBytes/readBytes/readRange` probes preserved zero/high-bit bytes on JVM/native. The implemented renderer stages a fixed 486-vertex arena/door/HUD scene through checked scalar calls and persistent native buffers; Kof now emits perspective clip coordinates plus normalized per-vertex depth, and SDL_GPU resolves the scene through a D16 depth target. Large/ranged asset error cases and a real bulk-buffer adapter remain unproven.


Scalar staging overhead is a **go/no-go measurement**. If representative draw/instance/animation uploads miss budget, prefer a properly specified upstream buffer-FFI addition (element format, length, borrow/copy lifetime, ownership and GC rules). Do not encode binary frames as JSON/Base64 strings or assume a pointer cast solves bulk transfer. Do not grow the shim into a C renderer to pass a benchmark.

### Native startup and GC gates

Real SDL video/GPU/audio initialization now runs from the emitted native ELF in the isolated presentation probe. That proves the exact window, fixed scene, synthesized clips, stereo channel gains and teardown path; it does not prove retained callbacks, foreign threads, streamed decoding, HRTF/EFX or arbitrary driver/platform support.


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
events. They never mutate authoritative simulation state. `editor` and `kooker`
use the same content/world query contracts but publish changes through revision-
checked transactions. `platform` is an adapter module, not a simulation module.

Modules are source/build boundaries first, not independently loaded binaries.
Each module exposes small data-oriented contracts and keeps implementation
helpers private by convention. The application root composes modules for the
player, kooker and kutter entry points. Dynamic loading, arbitrary callbacks,
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
compiled into the player/kooker/kutter. This remains the broadest safe path
through current native Kof limitations. The implemented no-rebuild
`BoundedKofScriptProgram` tier is deliberately narrower: forward-only bytecode
receives copied domain-event fields and emits capability-masked public
commands/events under fixed budgets. It has no save/network/filesystem/native
authority and must not become a second gameplay authority.

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
  supersedes older ticks; a higher state sequence may revise the latest sample
  at the same tick.
- Explicit tick, sequence, acknowledgement, baseline and content-revision
  fields.
- Bounded packet sizes, decode work, queues and entity counts.
- No native pointers, runtime slots or raw Kof object memory on the wire.

The implemented protocol keeps commands at 11 words and recipient-specific
player/progression state at 20 words. A checksummed encounter message uses
`20 + 8N` words for at most 32 enemies; each entry carries stable ID, role,
state, target, health and integer 3D position. A checksummed feedback message
uses `6 + 11F` words for at most 16 ordered impact events. Both variable
messages fit the shared 300-word native/JVM transport bound. Clients validate
before mutation, admit connection generation before sequence, reject stale or
gapped messages and apply authoritative state even when bounded presentation
queues drop feedback.

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

Movement profiles define ground friction/acceleration, air acceleration, speed caps, jump buffering/coyote time, bunnyhop/dash policy and crouch. Keep intent and jump contracts explicit; implement projection-based Quake-like acceleration as a deliberate profile rather than mislabeling vector-approach acceleration.

A rigidbody library is not initially required. If later demanded for piles/vehicles/destruction, assess it as an explicit external-library exception; never move player/combat authority into it by default.

## 6. Renderer and presentation

Initial renderer: opaque/masked forward rendering, depth buffer, static lightmap or vertex-light support, bounded dynamic lights, instanced static meshes, sprites/billboards, first-person viewmodel, decals/particles and HUD. True 3D permits stacked rooms, pitch, slopes, vertical encounters and mesh enemies.

- Kof performs frustum/spatial culling, visibility lists, material/mesh/pipeline grouping, transparent ordering and render-pass orchestration.
- Static resources retained; frame buffers/staging reused. Dynamic resource churn forbidden in steady play.
- Baseline passes: depth/opaque + optional bounded shadows, transparent/effects, viewmodel, postprocess/tone map, UI. Do not introduce deferred/clustered complexity until measured light populations need it.
- Low-resolution/pixelated, palette/limited-light and cleaner modern styles are material/postprocess profiles, not alternate world simulators.
- Single coordinate convention: meters, Y up, right-handed world, camera forward -Z. Build explicit projection/clip conversion for SDL_GPU's documented clip/depth convention; do not transpose/flip ad hoc. Validate culling winding, normals, handedness, depth range and texture origin together.
- Shader sources in HLSL, offline SPIR-V for first platform; pin SDL_shadercross and reflect/validate vertex/uniform bindings. Additional backend shader products only when their target is exercised.
- First animation path: sprite/billboard or rigid mesh; then Kof animation state/interpolation and skeletal pose evaluation, GPU skinning shader. Bind pose/index/weight admission stays in the kooker. No per-frame asset parsing.
- HUD/menu/inventory/debug overlay CPU logic and layout are `.kf`, rendered through the engine. External text/font rasterization may be a narrow library dependency; do not begin with an entire webview editor/runtime UI.

Targets such as viewmodel FOV, recoil/sway, muzzle flashes, hit feedback, readable rarity colors and status icons are engine features, not reasons to put presentation logic in the C adapter.

## 7. Combat and ARPG model

### Weapons and damage

- Separate immutable `WeaponDef` from runtime magazine/reload/cooldown/spin/burst state and item-instance modifiers. Hitscan, swept projectile, deterministic bounded shotgun pellets and bounded multi-target area damage now share authoritative query/damage paths; `BoundedRayTargetWorld` supplies bounded integer ray/pellet selection, and `CombatWorld.resolveShotgunPelletTargets` plus session wrappers preserve one selected target per pellet. Full automatic spatial integration still requires a shared actor-radius/aim contract.

- One trigger state machine; no competing old/new firing systems.
- Per-shot stable ID and explicit RNG stream; ammo consumption and accepted shot creation commit together.
- One `DamageRequest` resolution path now applies source scaling, crit, channel resistance, armor, defensive modifiers, shield and health in a documented bounded order; status application and death transition remain centralized.
- Damage channels now use four bounded resistance slots per actor with percentage mitigation and minimum damage; shields absorb post-mitigation damage before health and expose authoritative remaining shield state.
- Exactly one alive→dead transition owns XP, loot and quest credit; presentation consumes events and never awards rewards.
- Enemy/boss affixes can modify defined hooks without arbitrary same-frame recursive proc loops. Proc depth/rate limits explicit.

### Loot, inventory and progression

- `ItemDef` identifies a bounded template through `BoundedItemDefinitionStore`; `BoundedItemRoll` stores stable ID, seed, item level, rarity, selected affixes and condition, while `BoundedItemInventory` owns stable IDs, ownership and quantities.
- `BoundedLootTable` performs deterministic weighted definition selection and deterministic rarity/affix/condition rolls from an explicit seed; accepted rolls enter inventory through bounded identity validation. `BoundedAffixPoolStore` now selects weighted, non-contiguous content affix IDs deterministically; `BoundedAffixStatStore`, `BoundedItemStatComposer` and `BoundedItemStatResult` apply flat → additive percentage → multiplicative percentage composition with bounded overflow checks.
- Affix composition order remains explicit: base → flat → additive percentage → multiplicative groups → caps/rounding. Recompute on equipment/definition changes, not every frame.
- Inventory/equipment/stash/crafting use validation + reservation + atomic commit. `BoundedItemInventory.purchaseFrom` now atomically transfers item quantity and currency, `BoundedEquipmentLoadout` validates ownership, prevents duplicate slot assignment, supports bounded unequip and persists slot/item ownership, and `BoundedCraftingSystem` atomically consumes bounded ingredients/currency into a rolled output; `BoundedItemReservation` now stages multi-item/currency reservations with revision-based stale commit rejection; crafted inventory/roll/currency state round-trips through the existing save sections.
- Skill definitions declare prerequisites/rank caps/resource costs/cooldowns/tags; `BoundedSkillDefinitionStore` and `BoundedSkillProgression` now provide bounded prerequisite-gated learn/rank/experience progression plus deterministic activation/resource/cooldown checks with skill v1 save section persistence, and `LoopbackSession` exposes authoritative per-player skill learning/ranking/activation APIs whose configured damage percentages feed player combat.
- Status definitions specify refresh/replace/add-stack rules, duration caps and fixed-tick damage schedules. `BoundedStatusDefinitionStore` and `BoundedStatusEffects` now refresh duration, cap additive stacks, expire deterministically and persist status v1 state; `LoopbackSession` applies configured periodic damage before each fixed-step expiry/tick, plus flat/percentage damage and defensive flat/percentage protection modifiers after armor. Enemy combat accepts the same bounded modifier path. Death/reset/load clears or retains effects intentionally.
- Save item rolls in the dedicated rolled-item v1 section; `BoundedItemInventory` now round-trips stable ID, definition, seed, level, rarity, affixes and condition, so balance/content migration cannot silently reroll equipment.
- `BoundedWorldLoot` retains at most eight complete rolled drops with stable/source IDs, rank and integer 3D position. Death reward preflight reserves world-loot, XP and currency capacity before the alive→dead commit; pickup removes a drop only after inventory accepts its exact roll. Recipient-specific checksummed state kinds `7` and `8` replicate complete inventory/equipment/skill/status and world-loot state. Save section 12 persists world drops plus loot/currency reward claims, and `decodeG3Authority` restores the player/runtime pair atomically against configured content.

Preserve atomic transaction and stable identity invariants; do not inherit fixed weapon names, small inventory sizes or fixed tier-drop tables. These systems are part of the planned engine, not deferred out of scope after a shooting demo.

### AI and encounters

Begin with deterministic state machines: idle/patrol/investigate/chase/attack/recover/stagger/dead; melee, projectile and hitscan archetypes. Kof perception uses spatial candidates, squared distance/FOV cosine, shared LOS and tick-stamped threat memory.

Authored waypoint/portal navigation first, then a real cooked navmesh/A* pipeline with bounded expansions and explicit `pending/success/failure`. Spread expensive perception/path updates over ticks; fixed scheduling and owned scratch arrays, no Kof worker threads until GC-safe. Encounter volumes, wave budgets, boss phases, spawn admission, key/door/secret triggers are data-driven.

## 8. Content, kutter workflow and persistence

### Content pipeline

Editable sources → **Kof kooker** → versioned engine package → validated runtime load.

Initial source formats: project manifest and entity/encounter/item definitions
in readable structured data; static meshes/materials in a documented glTF
subset; Dust3D `.ds3`; LibreSprite `.ase`/`.aseprite`; MagicaVoxel `.vox`;
Blockbench `.bbmodel` character rigs; standalone PNG images; and audio in a
deliberately small supported set. These are offline intake formats, not runtime
package formats.
Validate finite geometry, triangle
indices, voxel dimensions/palette references, sprite frame bounds, animation
metadata, size/count limits, resource references, transforms and collision
flags. Native decoder libraries may provide pixels/PCM, not scene/loot/collision
semantics.

### External asset intake compatibility

The bounded kookers checksum each admitted source and normalize accepted data
into the canonical product/package contract. Retaining the original file and a
full tool/version receipt remains required package-provenance hardening:

| Source | Required intake result |
|---|---|
| Dust3D `.ds3` | Validate exported mesh/UV/skeleton data and produce GLB plus materials and optional collision |
| LibreSprite `.ase`/`.aseprite` | Extract bounded frames/layers/tags/slices and produce PNG atlas, versioned metadata and animation definitions |
| MagicaVoxel `.vox` | Parse bounded voxel models/palette/supported scene chunks and produce deterministic mesh/GLB plus materials and optional voxel collision |
| Blockbench `.bbmodel` | Parse the exact 5.0 cube/bone outliner and bounded numeric position/rotation/scale clips into reopened `KCHR` v1 rig data; texture pixels and per-face UV/material output require a separate product |
| PNG `.png` | Verify a 1 MiB/64-chunk/256×256 static 8-bit subset, decode color types 0/2/3/4/6 with palette/transparency and filters 0–4, then reopen deterministic RGBA8 PNG output; reject Adam7, APNG, unsupported ancillary chunks and ambiguous color profiles |
| PCM WAVE `.wav` | Admit exact RIFF/WAVE PCM tag `0x0001` with mono/stereo 8- or 16-bit samples at 8–96 kHz under 2 MiB/32 chunks/30 seconds/1 MiB canonical PCM; strip bounded inert metadata and reopen deterministic PCM16; reject RF64, extensible, float, compressed, cue/loop and unknown semantics |

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
documented format does not grant redistribution rights to the tool. Blockbench
is an external GPL-3.0-or-later application; KOOKIE's independently implemented
`.bbmodel` reader neither embeds the application nor copies its implementation.

The standalone image reader follows the
[W3C PNG Third Edition Recommendation](https://www.w3.org/TR/png-3/) for its
explicit subset. It preserves sample values; runtime sRGB/linear interpretation
belongs to material policy, and embedded color profiles reject rather than
silently changing that policy.

The audio reader follows the PCM registration in
[RFC 2361](https://www.rfc-editor.org/rfc/rfc2361) and the RIFF/WAVE model
documented by [SDL_LoadWAV](https://wiki.libsdl.org/SDL3/SDL_LoadWAV).
Compressed or streamed audio remains a separate future pipeline.

For boomer-shooter authoring add a Quake-style textual brush `.map` subset: convex brush plane clipping/triangulation, entity/property translation, material mapping and derived collision/visibility. TrenchBroom can be an external authoring tool; our `.kf` kooker remains the import authority. This does **not** promise WAD/BSP/QuakeC/source-port compatibility. Source maps are not shipped original-game assets.

Cooked package contract: magic, schema/tool/content versions, stable IDs, chunk offsets/lengths, dependency hashes, explicit endianness, bounds and corruption checks. Reject traversal, duplicate IDs, overlapping/out-of-range payloads and decompression overrun. Do not serialize Kof object memory or internal array headers.

The implemented bounded G4 pipeline consumes sealed `BoundedContentPackage`
and canonical geometry products. It stages package, extension, trusted-hook,
enemy-definition and geometry/collision/navigation/replication checksums,
revision-checks the active generation, then publishes all products atomically.
Its 13-word compatibility identity binds engine/API/network schema and every
content checksum. Stale, incomplete, mismatched or invalid transactions retain
the prior generation.

`BoundedSourceKooker` admits the documented indexed GLB,
Dust3D/Aseprite/VOX, convex brush-map, Blockbench 5.0 character, PNG and PCM
WAVE subsets under explicit size/count/chunk/depth/duration limits.
`scripts/kooker.sh` provides developer JVM file `cook`, `package`,
`inspect-package` and `validate-package` commands. Linux archives also carry a
native runner for the same Kof `cook` path; package operations remain JVM-only.
The package reader validates
explicit little-endian fields, paths, chunk bounds/overlap/hashes and registry
records. `BoundedExternalPackageRuntime` constructs candidates and swaps the
package plus extension/definition/hook registries only after complete
validation, so a bad reload preserves all active state.

Trusted declarations bind supported static implementation IDs/versions and
typed session-started, player-connected, enemy-defeated, loot-picked-up or
kutter-published subscriptions. `BoundedTrustedHookRuntime` binds the module
and extension checksums to a published generation, requires monotonic event
sequence/phases, and preflights per-hook budgets plus global output capacity
before emitting bounded commands/events. `LoopbackSession` applies each
accepted grant-currency command exactly once after aggregate
overflow/recipient validation. `G4KutterDemo` exercises the bounty path after
authoritative elite death; this is static trusted execution, not arbitrary
callbacks or sandboxing.

`BoundedKutterWorkspace` provides revision-checked world/entity/weapon/loot
transactions, collision/AI inspection, console edits, play-in-editor and
bounded undo/redo while publishing geometry/collision/navigation/render
together. The native adapter stages a separate candidate scene, waits for
synchronous SDL_GPU upload-fence completion before reusing the persistent
buffer, then activates at a frame boundary. The Kof coordinator gates old
generation retirement on references and fence completion. It does not reload
arbitrary Kof code or shaders.

Remote endpoints exchange an 18-word offer and 7-word response containing the
exact compatibility identity and checksums before snapshots/gameplay. Mismatch
and malformed offers receive a diagnostic rejection. The authenticated UDP
role path and separate processes exercise this exchange; a fresh
three-machine G4 evidence bundle remains a qualification limit, not an
in-process protocol gap.

Native mixed Int/Double/String record JSON failed the measured round-trip, including corrupt numeric/string values; direct record getters passed. The implemented `.kpkg`, canonical geometry and kooker outputs therefore use explicit bounded integer/binary layouts. Before adopting native JSON for definitions, glTF or saves, require a compiler/runtime repair plus schema-specific round-trip, malformed-input and bounds proof. Do not truncate floats or move content semantics into the adapter.

Current source rejects native `process.run`/`process.spawn` with `PROC001`. External shader/conversion tools therefore need the permitted minimal build orchestration or a separately proven platform capability; the native `.kf` kooker cannot assume the course's process examples work. It still owns content validation and cooking decisions.

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
- Migrations operate on schemas, never raw slots/pointers. `BoundedSaveSections`, `BoundedSaveSchemaWireCodec`, `BoundedSaveSchemaFileStore` and `BoundedSaveMigrationGate` now persist progression v1, item v1, quest v1, world v2, RNG v2, currency v1, rolled-item v1, equipment v1, skill v1 and status v1 sections, transforming prior world/RNG versions with default fields; typed bounded item ownership/quantity, quest state/progress, atomic inventory currency/item transactions, rolled item fields, equipment slot ownership, skill progression and status effects round-trip through the schema wire; unsupported/newer sections fail with the old save left intact. Future section-version transforms remain required.
- Replay presentation history now captures authoritative player weapon events and replicated enemy impact/audio presentation events automatically; the history is included in the native-safe replay sidecar and atomic checkpoint bundle. The isolated DRI3 screenshot gate passes; crash-durable save publication remains deferred and is not a G0 release gate.
- Implemented level progression: section `11`, version `1`, payload `[levelId, contentVersion, count, (stableId, activeFlag)*count]`. IDs/versions are `1..1000000`; up to 64 authored interactions require at most 131 words. The sealed destination requires matching level/content identity and the exact ID set, independent of declaration order. Invalid dependencies, undeclared requirements, duplicate/unknown IDs or missing sections reject without changing live progress. Old saves may explicitly start a fresh level; no progress is invented.
- `BoundedSaveSections` and schema codecs allow up to 12 sections and 160 words per section. Schema file v2 is `[magic, 2, slotWords]` plus two `[wireLength, checksum, wire...]` slots sized to the actual envelope. The fixed 316-word v1 format remains readable; repair writes v2. Corrupt/truncated/trailing files, insufficient destination capacity and valid newer schemas leave the destination intact.
- Interaction capture records consumed `(tick, player, sequence, targetId)` commands, including failed gameplay checks, in strict tick/player order with increasing per-player sequences. Admission reserves the bounded 64-command log before mutating sequence state. Export through `exportInteractionReplay` before disabling capture. Replay bundle v2 carries this log; genuine v1 reads produce an empty log. The older plain replay wire codec rejects interaction-bearing timelines rather than dropping commands.
- `replayTimelineToTick(movementPlayer, timeline, targetTick)` requires capture disabled, focused participants, a current full checkpoint/sidecar and at most 4096 intervening ticks. It re-simulates one explicitly selected movement stream plus both players' interaction commands; it is not a combined two-player movement recording. Checkpoints retain held fire/jump, pending interactions and sequence watermarks; movement capture uses consumed ticks. Older checkpoint payloads remain usable by checkpoint restoration, but full playback requires the current input-state snapshot. Level-save restoration requires capture disabled, cancels pending interactions, preserves live sequence watermarks and republishes client progress.
- A newer state sequence may revise the most recent authoritative sample at the
  same tick; older ticks/sequences remain rejected. Restoring an earlier
  checkpoint clears discarded future rewind samples before the next fixed tick.
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
apps/            player host/client, dedicated server, kooker, kutter
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
| **G4 — Kutter and extension pipeline** | Kof kooker, supported mesh/brush formats, package validation, data-mod manifests, trusted Kof extension modules, inspector/editors, staged reload | A second distinct multiplayer sample game is built from definitions/extensions without editing core engine code. Server/client reject incompatible package/API/mod manifests. Invalid content leaves the prior running world intact; geometry/collision/nav/replication revisions stay aligned |
| **G5 — Scale and release** | AI budgets, batching/instancing, animation, streaming only as needed, dedicated headless server, migrations/replay, reconnect/admission hardening, packaging/notices | Reference LAN workload meets declared budgets; dedicated server runs without graphics; memory/resource counts plateau; package runs outside source checkout; reconnect/session recovery and extension compatibility are proven |
| **G6 — Expansion** | Extra OS/backend/architecture, safe jobs, WAN transport, richer editor, runtime sandboxed extensions | Bounded jobs, package-bound KofScript/session activation, persistent Kutter, limited WAN and native Windows PE/SDL shell/presentation packages have focused probes; no general portability, WAN security, sandbox or DRI3-capable visual presentation claim is inferred |
| **D1 — Playable demo release** | Qualify the current local authoritative presentation loop on both targets, retain the bounded Host/Join lobby and player screen, use the deterministic clean-tree builder and publish current Linux/Windows packages through the approved pair workflow | Clean extracted Linux and Windows packages launch outside the checkout, map documented controls to real gameplay, complete encounter→exit/restart, pass fresh-host and native-hardware presentation checks, and publish signed provenance. A source probe or PE marker alone does not pass D1 |

G0 evidence is tracked in [G0_BACKLOG](G0_BACKLOG.md): native/session
feasibility, isolated window presentation and authenticated external-LAN
execution pass their G0 contracts. G1 is also closed by the executable
`G1Demo` path: a 60 Hz authoritative server admits two loopback clients,
exposes prediction correction and reconciliation, resolves one weapon/enemy
encounter, and clears held movement/fire across focus loss. Its authored
78-vertex/26-triangle arena supplies a walkable slope, steps and stacked rooms;
the server replicates its triangle data and explicit bounds to the client.
Kof projects the authored world through a perspective camera and emits a fixed
486-vertex native SDL_GPU scene with normalized per-vertex depth: 78 arena
vertices, 36 door vertices and 372 HUD vertices for
health/ammunition, a shape-distinct connection glyph, active/reserve encounter
load, confirmed hit/kill markers, edge damage warnings, structural
inventory/equipment/skill/world-loot status, shape-distinct elite/boss
threat/defeat cues and a structural kutter-publication rail. The confirmed
local hitscan event also reaches bounded replay/audio queues and native SDL clip
playback. An isolated GPU smoke rendered and read back the bounded scene, and
the original G1 focused set passed 84/84 scenarios on JVM and native. The
current bounded source qualification suite passes 94 scenarios on both targets.
G1's no-per-frame-growth evidence is 64 deterministic stages with unchanged
Kof capacities plus persistent native scene buffers. The completed G5 evidence
below adds the full authored collision workload, a 30-minute soak and
hardware-instanced rendering; it does not broaden G1 beyond the explicitly
qualified platforms and bounds.

G2 is closed by the JVM/native three-process transport slice carrying the full
arena, unified checksummed movement/fire/interaction/lifecycle commands,
recipient-specific player/progression baselines, ordered feedback batches and
bounded encounter state. Three continuous hitscan/projectile/shotgun enemy
roles move, retarget the nearest live player and replicate role, target, health
and 3D position. Clients predict ordered local movement, replay unacknowledged
inputs during reconciliation and reset input, prediction and feedback epochs
when a reconnect advances the connection generation. Initial join publishes
tick-zero gameplay, feedback and encounter baselines; stale generations reject
before sequence admission. Doors use authored half-extents for full 3D
segment/AABB collision and stage a 36-vertex perspective/depth-tested cuboid;
the native headless GPU probe draws the resulting 486-vertex arena/door/HUD
scene.
Feedback transport preserves multi-event order, rejects duplicates and gaps
without partial presentation, and resumes from the new-generation baseline.
The Kof layer computes listener-relative distance attenuation and stereo
panning; SDL_mixer queues the resulting left/right PCM gains. HRTF/EFX waits
for a proven permissive solution; streamed decoding remains later expansion,
while the completed G5 soak is recorded below. Neither is missing G2
acceptance.

G3 is closed at its current acceptance gate. Server-owned enemy deaths produce
deterministic full rolls; remote pickup/equip/progression commands cannot
author outcomes; equipment/status modifiers change observed boss damage; and
boss loot/XP/currency claims survive atomic schema-file save/reload without
duplication. A bounded public registry now seals versioned manifests,
dependencies, capabilities and namespaced content contributions with
deterministic ordering, diagnostics and checksums. Complete sealed elite/boss
definitions drive combat, behavior, loot, progression and currency, and
`LoopbackSession.admitDefinedEnemy` commits the actor plus reward contracts
atomically. Checksummed recipient authority/world-loot schemas preserve full
inventory and RNG identity; state kinds `7`/`8` traverse authenticated
same-host host-plus-two-client processes on JVM and native; that G3 state-kind
qualification remains same-host. G4 now adds typed domain-event subscriptions;
the bounded
GLB/Dust3D/Aseprite/VOX/brush kooker and file CLI; validated external
package/registry loading; transactional Kutter inspection/editing with
undo/redo and play-in-editor; fence-gated frame-boundary GPU reload; and
compatibility offer/response transport before gameplay. Package, manifest,
module, definition and aligned product checksums form one revisioned identity;
stale, malformed and incompatible updates preserve the active generation. The
second two-player sample runs the compiled elite-bounty hook after
authoritative death, and output/reward overflow remains atomic. The handshake
passed with host and clients in three isolated Linux network namespaces and
distinct IPv4 stacks. G4 is complete for this bounded contract. General format
compatibility, arbitrary code/shader reload, a production-grade editor, and
fresh qualification on three physical machines are explicitly outside that
claim.

The completed bounded G5 slice executes a 192-vertex/64-triangle authored
collision scene with 64 enemies, 256 moving projectiles, 512 pickups,
24 dynamic lights and 64 effects in the graphics-free Kof server. Rolling work
limits admit 16 AI states, 64 projectile slots and 128 pickup slots per tick.
`scripts/verify_dedicated_server.sh` proves matching JVM/native behavior,
unchanged resource signature `520690` and all 64 collision triangles loaded.
On Linux 6.18.54-1-lts/x86_64, a 16-core Genuine Intel family 6 model 197 CPU,
the focused native sample recorded p50/p95/p99/max
1.518/1.623/1.717/1.757 ms and a 64 KiB RSS growth/range.

`scripts/verify_dedicated_soak.sh` paced 108,000 measured ticks at 60 Hz after
600 warm-up ticks. p50/p95/p99/max were 2.489/3.202/3.721/23.645 ms; RSS
first/last was 3,620/3,748 KiB with 128 KiB growth/range across 181 samples.
The logical resource signature stayed `520690`; the final workload checksum was
`884139`. Simulation p95 therefore remains below the declared 4 ms budget.

`scripts/verify_dedicated_network.sh` runs one authenticated host and two client
processes through content admission and a complete four-chunk state update on
every one of 256 ticks. Both clients finish with state checksum `569221` and
resource signature `520690`; client B disconnects and resumes at generation 2.
Client state is committed only after all chunks and the whole-state checksum
pass, so stale, replayed or tampered transactions preserve the prior state.

`scripts/verify_g5_renderer.sh` stages 2,952 vertex attributes as 984 hardware
triangle instances—64 environment triangles, 832 entity markers and 88
light/effect markers—in one draw. Inside the isolated display wrapper, Vulkan
26.2.3 on `Intel(R) Graphics (ARL)` measured 600 frames at 1920×1080:
p50/p95/p99/max submission time was 0.304/0.645/0.845/1.089 ms, including the
per-frame upload. The visually reviewed 320×240 readback checksum was
`39710142`; its PPM SHA-256 is
`20b37c94927b04689071200346f1e98f3498ce6408697bae697535773f15f5d4`.

Crash-durable saves validate a staged file, fsync file data, rename atomically
and fsync the parent directory. Save migrations cover multi-step old schemas;
replay v3 binds engine/content/seed identity and a whole-payload checksum.
Release packaging requires an exact Kof 0.5.0-beta toolchain, clean source
tree and owner-private Ed25519 key, then signs the archive, provenance manifest
and checksum set. The packaged headless server remains graphics-independent.

G5 is complete for this declared Linux x86-64 contract. The evidence does not
claim multi-machine/WAN behavior, other OS or GPU performance, arbitrary
population scalability, streamed content, or G6 sandboxing.

G6 is qualified for the declared bounded contract by
`scripts/verify_g6_runtime.sh`, the reproducible native Windows PE/SDL package
gates, and the native shell's isolated Wine smoke. The native shell smoke
linked the complete reachable `src/` Kof object, launched through the SDL3
shell, and passed the expected gameplay markers plus the native PE marker.
The presentation package gate additionally verifies native Kof PE linkage to
the SDL3/SDL_mixer adapter and retained SPIR-V/DXIL products. Its optional Wine
visual smoke requires an isolated DRI3-capable GPU; the default isolated Xvfb
environment is intentionally not treated as presentation evidence.

This qualifies native Kof PE gameplay on Windows, native PE/SDL_GPU
presentation packaging, and the separate JVM compatibility package on the
recorded host. It does not claim NAT traversal, relay service, confidentiality,
DDoS resistance, arbitrary editor extensibility, a general-purpose runtime
sandbox, or other OS/GPU coverage.

G6 qualification is not D1 release completion. The current presentation source
now implements the bounded local `Play` encounter, the explicit two-player
`Host/Join` ready lobby and the host-authoritative `Tab` player screen. The
fixed-tick input/ACK protocol, endpoint pinning, 12-tick hitscan rewind,
six-tick remote interpolation and prediction-correction metrics are bounded
source behavior with focused checks; they do not make the public artifact
current.

The 2026-10-02 qualification batch passed signed Linux package/package smoke
with a temporary pinned SDL_mixer prefix and the signed Windows native PE/SDL
presentation artifact gate with pinned MinGW/DXC dependencies. D1 remains open
for a clean-tree Linux/Windows pair, outside-checkout play/restart/quit smoke,
fresh-host/runtime-floor verification, native Linux GPU presentation evidence,
native Windows hardware presentation evidence, final release policy/notes and
cross-host multiplayer evidence if advertised. D1 is tracked in
[Demo release readiness](DEMO_RELEASE.md).

### Measured bounded evidence and retained performance targets

Reference scene for first scale gate: 64 active enemies, 256 moving projectiles, 512 pickups, bounded dynamic lights/effects and one medium authored level. Maintain a heavier stress variant after the baseline is correct; do not claim arbitrary population scalability.

Targets to measure on explicitly recorded CPU/GPU/driver/resolution/build: 60 Hz simulation, p95 simulation work ≤4 ms/tick, p95 frame ≤8.33 ms for a 120 Hz rendering target at 1080p, and no monotonic resource/RSS growth in a 30-minute bounded soak after warm-up. Record p99/max and GC/upload costs, not average FPS alone. A miss changes capacity/content/implementation based on profiles; it does not justify moving gameplay out of Kof.

These thresholds are design goals. Correctness may be tested under software rendering, but software-renderer timings cannot certify hardware targets. Graphics/input proof must be serialized inside an isolated disposable display environment.

### DXPERF-051 SIMD dispatch evidence

`native/kookie_simd_dispatch.c` is a narrow native mechanism, not a gameplay
implementation. It selects AVX2 or SSE2 at runtime on x86, NEON on AArch64,
and always retains checked scalar `i32` and `u8` reductions. Dispatch
initialization is thread-safe; unsupported or forced-scalar builds remain
valid. The `kookie_simd_sum_u8_buffer` entry point maps one Kof
`Buffer(U8)` plus its Kof-validated extent to the selected reduction.

Kof 0.5.0-beta source commit `bf17ac7e736471c8a04b4153e5b0f607be75e70c`
provides the native `Buffer(U8, INOUT)` contract. CI builds that exact source
instead of the older same-version release archive. Independent adversarial
verification supplied on 2026-09-30 passed native x86-64 and supported cross
paths at upstream commits `b4c2b734a`, `381f6fab0` and `bf17ac7e7` (evidence
`c73556f5a`); Script, JavaScript, Android, riscv32 and MCU paths still report
`FFI001`. KOOKIE did not rerun that upstream matrix.

`scripts/verify_simd_dispatch.sh` verifies `i32` and `u8` vector-tail parity
through host-selected and forced-scalar C paths, runs the same Kof
`Buffer(U8)` benchmark on JVM and native, and syntax-checks the AArch64 NEON
source. A 2026-09-30 native run on the recorded Intel Arrow Lake-P host reduced
64 MiB in 233,350,224 ns through the Kof scalar loop and 1,073,834 ns through
the AVX2 buffer route (217.3x for this exact reduction). The packaged
`kookie-simd-bench` reports its own measured route decision. This is ABI and
representative reduction evidence, not a frame-time, gameplay or general
engine-speed claim; production gameplay remains Kof-owned and scalar.


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

Repository display rule: configure `KOOKIE_PRESENTATION_ISOLATION_WRAPPER` with a reviewed wrapper that provides private display/session sockets, bounded timeouts and complete process-tree cleanup. Never interact with the developer desktop/monitors. Plain Xvfb or merely unsetting DISPLAY is insufficient for graphical tests. No full matrix during implementation; final pre-commit matrix only with the user's one-shot permit.

### Risk register

| Risk | Current evidence | Action / release gate |
|---|---|---|
| Bulk FFI remains target-specific; structs/pointers/native callbacks are not a general contract | Pinned 0.5.0-beta `Buffer(U8, INOUT)` passes the packaged JVM/native `u8` reduction benchmark; supplied cross verification passes, while Script/JS/Android/riscv32/MCU remain `FFI001` | Use only measured targets, retain scalar fallback, and route production work only when a profile identifies the same bulk-reduction shape |
| Native C-runtime/driver initialization | Real SDL3 GPU/audio/input paths pass on qualified Linux; Windows native Kof PE gameplay passes through the SDL shell smoke, and the presentation package gate verifies native PE/SDL_GPU linkage and shader products | Keep separate platform/GPU gates; do not infer DRI3-capable Windows presentation from package linkage or graphics-free smoke |
| Native collector after spawn | Cumulative spawn gate in allocator source | Single Kof thread; long soak; no unsafe manual-GC bypass |
| Native codegen performance | Minimal optimization pipeline | Measure representative arrays/math/FFI; use batching/preallocation; no C gameplay rewrite |
| Distribution runtime closure | The Windows JVM profile retains a digest-pinned full OpenJDK runtime and legal tree; native compiler pruning still emits its known warning | Keep the JVM choice explicit, record runtime identity/size, compare reproducible archives and never treat it as silent native fallback |
| Native stale exception handler | Later assertion re-entered a completed try/catch and exited 0; failure-path hangs remain externally bounded | Validate expected failures before throw; use external timeout/exit/output gates; no control-flow shim |
| Native JSON/split parity | Fractional mixed-record JSON corrupted values; escaped-pipe split differed from JVM | Repair/prove exact content/save schemas and parser contracts before G3/G4 reliance |
| Language/docs rapidly diverge | 0.3.7 course / older portal pages / 0.5.0-beta release gate | Pin exact toolchain identity and archive digest; upgrade through focused behavior probes, not compile-only claims |
| Editor reliability/security | Single-file run, JS UI, privileged unauthenticated handlers | CLI + separate LSP-capable editor; no dependency on editor fork |
| Kutter pipeline becomes second engine | Multiple monolithic runtimes or authorities | Shared .kf runtime/query/content contracts; staged frame-boundary publish |
| License/asset assumptions | Unclear code/asset rights; unlicensed DoomKof source | Preserve provenance, resolve grants, own/test assets initially |
| Native portability overclaimed | Upstream native output remains Linux ELF; the KOOKIE bridge emits deterministic AMD64 PE/COFF for the qualified reachable gameplay/presentation graphs and rejects floating-point IR, catchable exceptions and concurrency with `PE001` | Keep separate platform gates; retain actual Windows shell smoke and artifact checks, and require DRI3-capable visual evidence before claiming presentation execution |

## 12. Historical first implementation increment

G0 began with scalar core/tick contracts, a bounded session codec, one modular
Kof entrypoint and an isolated SDL3 platform probe. Early JVM/native runs
exposed cross-package record/array boxing and wrapped-scalar-extern verifier
defects, so direct FFI remained isolated until the compiler contract matured.
The retained probes now guard those boundaries; the completed bounded G0–G6
implementation and the acceptance evidence above supersede the original
increment checklist. D1 remains an open player-facing release gate; see
[Demo release readiness](DEMO_RELEASE.md).
