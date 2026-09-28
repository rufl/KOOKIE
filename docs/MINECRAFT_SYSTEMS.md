# Modern Minecraft Java systems: reuse with Kof

Research date: **2026-09-22**. This is a library/architecture assessment, not an implemented engine or a measured performance comparison. Native Linux x86-64 and Kof-owned CPU behavior remain the baseline in [ENGINE_PLAN](ENGINE_PLAN.md). Foreign ECS/GUI/physics ownership is a possible explicit alternative, not silently approved by this research.

**Best immediate candidates:** selective MIT JOML math and Brigadier ports; Artemis/Ashley-inspired Kof storage; Minecraft-style content definitions/components/codecs; owo-inspired UI layout; Flywheel-inspired instance lifecycles; one native audio backend. Jolt is the strongest assessed shortcut if foreign physics ownership is accepted. RmlUi and Dear ImGui similarly reduce UI work if foreign widget/layout ownership is accepted.

## 1. Current baseline, not a 1.21-era stack

The [official version manifest](https://piston-meta.mojang.com/mc/game/version_manifest_v2.json) identified **Java Edition 26.3**, released **2026-09-15**, as latest at research time. The downloaded [exact version metadata](https://piston-meta.mojang.com/v1/packages/96c00d95a31328714d3811cfade2804bb050e455/26.3.json) matched SHA-1 `96c00d95a31328714d3811cfade2804bb050e455`; it specifies Java **25**, `java-runtime-epsilon`. No Minecraft client/server JAR or game assets were downloaded or executed.

Actual named dependencies in that metadata:

| Dependency | Shipped version | What this establishes |
|---|---|---|
| JOML | 1.10.9 | Standalone Java math dependency |
| Brigadier | 1.3.11 | Standalone command parser/dispatcher |
| DataFixerUpper | 10.0.21 | Codec/schema-migration library |
| LWJGL modules | 3.4.3 | Core, **SDL**, OpenAL, OpenGL, Vulkan, FreeType, STB, ShaderC, SPVC, VMA, jemalloc |
| fastutil | 8.5.18 | Java primitive collections, not an ECS |
| ICU4J | 78.3 | Unicode/text services; not a GUI toolkit |
| Netty | 4.2.16.Final | Networking libraries; not game replication semantics |
| JOrbis | 0.0.17 | Java Vorbis dependency; not a complete sound engine |
| text2speech | 1.19.12 | Narration integration, not positional audio |
| `at.yawk.lz4:lz4-java` | 1.10.1 | Java compression binding/library, not a save schema |

There is no named Ashley, Artemis, Dominion, Bullet, Jolt or PhysX dependency. Dependency absence alone cannot prove the internal entity/physics architecture.

### Material current changes

- **SDL3 replaces GLFW** for windowing, input and platform integration. Physical gameplay bindings use SDL scancodes; text-edit shortcuts use keycodes; gameplay mouse mode is always relative. This supports the existing SDL3 platform choice, but **does not mean Minecraft uses SDL_GPU**. [Official 26.3 release](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-3).
- OpenGL **and Vulkan are implemented**. [26.2 release notes](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-2) explicitly introduced experimental Vulkan and said Default meant Prefer OpenGL. 26.3 discusses both backends and ShaderC for both; its runtime default was not independently exercised here. The [earlier Vulkan announcement](https://www.minecraft.net/en-us/article/another-step-towards-vibrant-visuals-for-java-edition) alone is not evidence of an active backend.
- The **26.2→26.3 vanilla migration primer** identifies a rendering-API split from Blaze3D into **Renderpearl** (`api`, `backend`, `frontend`). Other Blaze3D helpers remain. Separation into a project/package is **not evidence of a separately reusable open-source license**. [NeoForge 26.3 primer](https://docs.neoforged.net/primer/docs/26.3/).
- Terrain uses MultiDrawIndirect on supported devices, with separate-draw paths still described. Improved Transparency uses approximate OIT; Mojang warns of artifacts and potential extra cost. The primer identifies Wavelet OIT. Neither feature is a prerequisite for this FPS engine.
- Data-pack version is **121.0**, resource-pack **97.1**. Several predicate/loot/provider formats changed; do not implement a current system by copying 1.21 JSON examples unchanged.

**Evidence bounds:** current unversioned Fabric prose pages read here identify themselves as **26.2**; several NeoForge concept pages are **26.1**. Exact 26.3 release notes and versioned Fabric API references are used where available. Older 1.21.8 mapping APIs below are explicitly historical, not a full 26.3 source audit.

**License boundary:** Minecraft stopped obfuscating newer releases, but Mojang explicitly said the [EULA did not change](https://www.minecraft.net/en-us/article/removing-obfuscation-in-java-edition). Readable game code is not permissively licensed library code. The [product-wide attribution page](https://www.minecraft.net/en-us/attribution) mixes editions, historical dependencies and products: entries such as EnTT, bgfx or FMOD do not establish current **Java Edition** use. Independently licensed Brigadier/DFU/JOML are different from Minecraft's own gameplay/renderer code.

## 2. Three integration routes

| Route | What works in principle | Actual cost / boundary |
|---|---|---|
| Kof JVM + Java library | Java classes on the dependency classpath | JOML constructor/method math was exercised below. Other Java libraries remain untested; reflection, generics, interface callbacks, JNI and classpath resolution need separate proof. Does not satisfy native-ELF shipping by itself |
| Native Kof + C/C++ library | Narrow checked scalar adapter over an allowed foreign subsystem | Current native FFI cannot pass arbitrary arrays, structs, pointers, out-buffers or callbacks. Adapter owns native memory/resources; Kof receives checked tokens and copied values. C++ virtual interfaces require real adapter implementations |
| Native `.kf` port or independent implementation | Selected algorithms and data/lifecycle contracts | Best for portable engine-owned CPU logic. A Java source translation does not bring the JVM/reflection/JNI with it. Source-derived ports retain upstream license obligations |

A token adapter does **not** make a Java JAR native. Embedding a JVM or moving gameplay into a foreign engine would be a separate architecture decision. Native `spawn` currently disables automatic GC; begin on one Kof thread. Foreign library threads must not retain Kof heap references or call into Kof. See [KOF_LANGUAGE](KOF_LANGUAGE.md) and [COURSE_PROBES](COURSE_PROBES.md).

## 3. ECS, registries, components, data and AI

### What Minecraft actually contributes

**Vanilla Java is not a conventional archetype-ECS reference.** The [26.2 Fabric entity tutorial](https://docs.fabricmc.net/develop/entities/first-entity) uses entity subclasses and registered `EntityType`s; [26.1 NeoForge entity docs](https://docs.neoforged.net/docs/entities/) describe `Entity` inheritance and per-instance `tick`/`baseTick`/`rideTick`. Historical [1.21.8 EntityIndex](https://maven.fabricmc.net/docs/yarn-1.21.8+build.1/net/minecraft/world/entity/EntityIndex.html) maps IDs/UUIDs to entity objects. This is distinct from component-column iteration.

Useful separations for a looter/FPS:

- **Definitions versus instances:** namespaced registries contain shared definitions; entity/item instances hold changing state. Persist stable content IDs, not transient dense ECS indices.
- **Item defaults plus patches:** [item data components](https://docs.fabricmc.net/develop/items/custom-data-components), introduced in [1.20.5](https://www.minecraft.net/en-us/article/minecraft-java-edition-1-20-5), replace unstructured item-stack tags with typed, validated values. A prototype plus override/removal patch maps well to affixes, charges and durability. This did not replace all NBT or convert world entities to an ECS. [Detailed 26.1 component contracts](https://docs.neoforged.net/docs/items/datacomponents/).
- **Persistence versus network codecs:** these are different contracts. Validation, references and migrations are not automatically efficient replication.
- **Data-driven effects:** registered operation IDs, predicates and a typed evaluation context let data configure Kof-owned behavior. A new JSON type does not implement its effect automatically.
- **AI memories/sensors/behaviors:** the historical [1.21.8 Brain API](https://maven.fabricmc.net/docs/yarn-1.21.8+build.1/net/minecraft/entity/ai/brain/Brain.html) shares perception results through memories, with sensors and prioritized activities/tasks. Borrow a typed blackboard, expiration and sensor cadence—not Minecraft's entity hierarchy or a claimed general ECS.

26.3 specifically splits context integer/float providers, broadens ID/tag/inline registry references, removes several dedicated reference forms, renames loot-entry `conditions`→`condition` and `functions`→`modifier`, and changes predicate discriminator `condition`→`type`. **Borrow validation/reference resolution, not evolving Minecraft wire spelling or its documented undefined arithmetic cases.** Define KOOKIE's own versioned schema and explicit errors.

### Candidate libraries

| Candidate / classification | Verified identity and license | Kof fit / recommendation |
|---|---|---|
| **Brigadier**, actual vanilla dependency | Shipped **1.3.11**; [inspected public source](https://github.com/Mojang/brigadier/tree/9ba4f13c0fe82b07c08c2dc2d8043f075ffd0d98), **MIT** | Best small standalone source-port candidate: cursor reader, literal/typed argument nodes, parse diagnostics, usage/completion and permission-aware dispatch. JVM reuse plausible; native port bounded subset |
| **DataFixerUpper**, actual vanilla dependency | Shipped **10.0.21**; [inspected public source](https://github.com/Mojang/DataFixerUpper/tree/5fc0978694e996cfe68a742b67a0d506c17de3f0), **MIT** | JVM codecs/migrations useful. Native: implement a small explicit codec/schema layer and sequential save migrations, **not** the full generic optics/type-rewrite engine |
| **Artemis-ODB**, independent Java ECS | Published **2.3.0**; [source pin](https://github.com/junkdog/artemis-odb/tree/6bb08e44bae8960ac516d9656b2bc0a57f794036), **BSD-2-Clause core**, Apache-2.0 reflection files | Best assessed Java storage/lifecycle reference: per-type stores indexed by entity ID, all/one/exclude queries, deferred structural mutation. Replace reflection/classes with explicit type IDs and Kof typed stores |
| **Ashley**, independent libGDX-ecosystem ECS | Published **1.7.4**; architecture inspected at [1.7.3 pin](https://github.com/libgdx/ashley/tree/57b728edd07f46dfade4343d1ad875dee9241e81); **Apache-2.0** | Simple Family/query vocabulary. Published POM depends on libGDX core **1.9.9**, not necessarily its window/backend. Do not port libGDX or Java object pooling wholesale |
| **Dominion**, independent Java archetype ECS | **0.9.0**, [source pin](https://github.com/dominion-dev/dominion-ecs-java/tree/b5aea3287937c3b4e2f3d31a94f9072c003b5b63), **MIT**, Java17+ | Lower priority. Archetype chunks contain Java object-reference columns, not flat native numeric SoA; supporting storage uses Unsafe/atomics. Do not transplant its parallel scheduler or internal chunk IDs |

Published-release metadata matters: [Artemis Maven metadata](https://repo.maven.apache.org/maven2/net/onedaybeard/artemis/artemis-odb/maven-metadata.xml) still identifies 2.3.0 (2019), despite a develop README advertising 2.4.0; [Ashley metadata](https://repo.maven.apache.org/maven2/com/badlogicgames/ashley/ashley/maven-metadata.xml) identifies 1.7.4 (2021). These are useful established designs, not newly released Minecraft systems. Age alone is not a performance or abandonment verdict.

Brigadier/DFU inspected public-source commits are **not asserted byte-equivalent** to the shipped artifacts. Their [Brigadier POM](https://libraries.minecraft.net/com/mojang/brigadier/1.3.11/brigadier-1.3.11.pom) and [DFU POM](https://libraries.minecraft.net/com/mojang/datafixerupper/10.0.21/datafixerupper-10.0.21.pom) establish artifact dependencies. Brigadier has no declared runtime dependencies; DFU exposes a larger Gson/Guava/fastutil ecosystem. Minecraft's resolved versions differ from some DFU declarations.

**Recommended native contract:** generation-checked entity IDs, explicit component type IDs, typed per-type storage, all/any/none query membership and a structural-change queue applied at documented phase boundaries. Choose one design, not several ECS engines. Keep hot combat fields out of string-keyed maps. Full archetype migration is deferred until workload evidence justifies it.

**Port pitfalls:** recycled components must not leak stale references; internal storage locations are not save identities. Brigadier's UTF-16 cursor offsets need an explicit Kof diagnostic convention. Ordinary parse errors should return structured results rather than rely on the currently broken native exception-handler lifecycle. DFU-inspired validation must distinguish missing optional fields from malformed present values and reject unacceptable partial results. It cannot repair Kof's measured fractional-record JSON defect.

## 4. GUI and text

Vanilla supplies useful **contracts**, not a standalone licensed GUI package: [26.2 Screen initialization/extraction](https://docs.fabricmc.net/develop/rendering/gui/custom-screens), historical [1.21.8 render-state layering/focus/narration](https://docs.neoforged.net/docs/1.21.8/gui/screens/), and current SDL3 text/input migration. Keep input routing, focus, hit testing, layout, rendering and narration separate. Text input/preedit is not a sequence of physical key events. Tooltips/scissors/layers cannot be reordered solely to maximize batching.

| Candidate / classification | Identity / license | Recommendation and hidden work |
|---|---|---|
| **owo-ui in owo-lib**, Minecraft mod library | **0.13.1+26.2**, [pin](https://github.com/wisp-forest/owo-lib/tree/9c9772e1728dd4c5f1178ce955d1b3747f53493a), **MIT** | Best selective `.kf` layout source candidate: fixed/content/percentage sizing, measure/mount/update/draw, focus and tooltips. Fabric/Minecraft/Mixins remain embedded; even screenless adapters use Minecraft services. Not standalone or verified26.3-compatible |
| **YACL**, Minecraft settings library | **3.9.7**, [pin](https://github.com/isXander/YetAnotherConfigLib/tree/84628d403a72afca148b439d64249e20a72bef34); build targets include26.3; **LGPL-3.0-or-later** | Borrow settings contract: default, applied/bound, pending value; apply/discard/reset and availability. Not a general HUD/editor toolkit. An independent state-machine implementation avoids unnecessary source-port coupling |
| **ModernUI + Arc3D**, standalone JVM core with separate Minecraft bridge | ModernUI **3.13.0**, [source](https://github.com/BloCamLimb/ModernUI/tree/3.13.0), **LGPL-3.0-or-later**; Arc3D **2026.2.0** dependency | Genuine Java UI alternative, not a native C++ toolkit. Own rendering/lifecycle/text stack; large native port. JDK/AWT-backed shaping cannot be copied as a few Java algorithms. Bridge3.13.0.5 targets26.1–26.1.2, not established26.3 |
| **RmlUi**, independent native library, not Minecraft | **6.3**, [source](https://github.com/mikke89/RmlUi/tree/6.3), **MIT**, C++17 | Strongest assessed retained player-UI shortcut if foreign GUI ownership is accepted. Real SDL3+SDL_GPU backend; CSS-like authoring, not a browser. This backend lacks clip masks, filters and shader decorators; callback/span/pointer adapter required |
| **Dear ImGui**, independent native library, not Minecraft | **v1.92.9b**, [source](https://github.com/ocornut/imgui/tree/v1.92.9b), **MIT** | Strong editor/debug shortcut if foreign GUI ownership is accepted. SDL3+SDL_GPU backend; upload preparation before the GPU render pass. Docking is a separate branch/tag choice; not a complete player-UI localization/accessibility system |

For a Kof-owned UI, port only small owo layout/focus contracts and independently implement YACL-style pending settings. Do not inherit Minecraft windows, registries, XML loaders or its entire mod framework. ModernUI's core dependencies include LWJGL/ICU/fastutil; its notices include AOSP and separately licensed fonts. Exact Arc3D release-license closure was not separately established here; do not treat the whole stack as one MIT dependency.

**Text is a separate native-service opportunity:** FreeType handles font rasterization; HarfBuzz handles shaping. They do not replace application bidi/layout policy, font fallback, IME, focus or narration by themselves. FreeType appears in actual26.3 dependencies; that does not prove Minecraft uses HarfBuzz directly. [FreeType offers FTL or GPLv2](https://freetype.org/license.html), with FTL credit obligations; [HarfBuzz uses Old MIT plus per-directory exceptions](https://raw.githubusercontent.com/harfbuzz/harfbuzz/main/COPYING). Pin implementations/fonts and audit their notices before integration. No Kof font bridge was exercised.

RmlUi's default FreeType support is not full shaping; its HarfBuzz sample has integration caveats. ImGui1.92 dynamic font atlases likewise do not establish complete bidi/shaping/accessibility. Keeping glyph rasterization/shaping as low-level graphics services is materially different from moving widget state and layout into a foreign GUI engine.

## 5. Physics, collision and movement

Historical [1.21.8 Entity APIs](https://maven.fabricmc.net/docs/yarn-1.21.8+build.1/net/minecraft/entity/Entity.html) expose axis-aligned bounding boxes, movement adjustment, step-height collection and axis ordering; [VoxelShape](https://maven.fabricmc.net/docs/yarn-1.21.8+build.1/net/minecraft/util/shape/VoxelShape.html) provides box decomposition, raycast and axis-distance clipping. This is **not evidence of a general rigid-body solver or swept-capsule controller**, and exact26.3 movement internals were not audited. Keep KOOKIE's true-3D capsule/BVH direction; do not inherit voxel-only geometry or Minecraft's tick/tuning rules.

| Candidate / classification | Identity / license | Integration judgment |
|---|---|---|
| **Jolt Physics**, standalone native engine | **5.6.0**, [versioned docs](https://jrouwe.github.io/JoltPhysicsDocs/5.6.0/index.html), [source/license](https://github.com/jrouwe/JoltPhysics/tree/v5.6.0), **MIT**, C++17 | Best assessed foreign-physics candidate: ray/shape queries, static triangle meshes, rigid bodies and CharacterVirtual. Native adapter to the kernel, not Java JNI exports. Adoption transfers collision/simulation ownership and requires an explicit exception |
| **jolt-jni**, standalone Java binding | **6.1.1**, **MIT**; [actual build pin](https://raw.githubusercontent.com/stephengold/jolt-jni/6.1.1/gradle.properties) uses `stephengold/JoltPhysics` fork `sg260915` | Potential Kof JVM route, untested. Do not assume JNI6.1.1 embeds unmodified upstream5.6.0. Native Kof does not need this Java layer |
| **Bullet / Libbulletjme / Minie**, native kernel and Java integrations | Minie **9.0.3** [pins](https://raw.githubusercontent.com/stephengold/Minie/9.0.3/gradle/libs.versions.toml) Libbulletjme **22.0.3**, jME3.8.1. [Licenses](https://raw.githubusercontent.com/stephengold/Libbulletjme/22.0.3/LICENSE): BSD-3-Clause glue/V-HACD, zlib Bullet, MIT exception | Credible alternative, also seen in Minecraft's DynamX ecosystem—not vanilla. JVM Libbulletjme is less engine-coupled than Minie; native bind Bullet itself. No reason to integrate both Bullet and Jolt |
| **Valkyrien Skies2**, Minecraft moving-world mod | **2.4.11**, [tagged MC1.20.1 configuration](https://raw.githubusercontent.com/ValkyrienSkies/Valkyrien-Skies-2/2.4.11/gradle.properties), LGPLv3 integration | Moving reference-frame case study, not a clean standalone library. Closed VSCore/Krunch components lack an established standalone grant. [2.4.10 added selectable Jolt](https://api.modrinth.com/v2/version/DiPIynfN); do not describe it as exclusively Krunch or wholly open |
| **Physics Mod**, Minecraft visual-effects mod | **3.2.5 for26.3**, [release](https://api.modrinth.com/v2/version/6losOHhe), [All Rights Reserved metadata](https://api.modrinth.com/v2/project/Xy8aRQKS) | Client-only debris/ragdoll presentation case study, **not reusable source** or proof of authoritative collision. Upstream PhysX/PhysX-JNI licenses do not license the mod itself |

Jolt caveats matter for a shooter: CharacterVirtual wall-slide/stair/ground-stick behavior is real controller ownership, not marshaling. A virtual character may not appear in ordinary broadphase queries without an inner body or additional queries. Linear CCD is not rotational CCD. Static triangle meshes and dynamic convex bodies have different constraints; cooking/internal-edge behavior needs testing. No controller or physics runtime was launched here.

If chosen, begin with synchronous stepping; worlds/shapes/bodies use checked generation tokens. Native callbacks must remain native. Contact decisions that require an immediate return cannot simply become deferred Kof events: configure filters/policy beforehand, then poll copied post-step events. Keep weapons, damage, movement intent and gameplay authority in `.kf`; explicitly identify which collision/controller decisions are delegated.

**Default remains Kof collision**, not a physics dependency change. Porting an entire Jolt/Bullet/PhysX solver into Kof is not a small library task. The practical choices are a bounded Kof controller/collision subsystem or an explicitly accepted foreign solver.

## 6. Sound and spatial audio

Actual26.3 metadata confirms **LWJGL OpenAL**. This establishes the OpenAL binding, not an independently verified exact bundled OpenAL Soft version. Fabric's **26.2** [sound-event](https://docs.fabricmc.net/develop/sounds/using-sounds), [asset](https://docs.fabricmc.net/develop/sounds/custom) and [dynamic-sound](https://docs.fabricmc.net/develop/sounds/dynamic-sounds) docs distinguish server-distributed logical events from client playback instances, category gain, moving/looping voices and subtitles. Positional assets should be mono; UI-only sound need not go through a server. Minecraft's volume/range coupling is a game-specific contract, not a generic audio-gain law.

| Candidate / classification | Source identity / license | Native Kof fit |
|---|---|---|
| **OpenAL Soft**, native OpenAL implementation | [Pinned source](https://github.com/kcat/openal-soft/tree/8d2d2e2ed1f51df960e7eb4bb26b64625c873c0d), **LGPL-2.0-or-later**; default SADIE-II-derived HRTF data Apache-2.0 | Strongest Minecraft-associated advanced3D option: distance/direction/Doppler, HRTF, streaming and EFX filtering/reverb. Needs adapter for context/device pointers and buffer upload. EFX does **not** trace the world automatically |
| **SDL3_mixer**, independent SDL audio library | [Pinned source](https://github.com/libsdl-org/SDL_mixer/tree/cfa8d2c106caf89c585a5aae9eae9d75939eaf2f), README declares **3.0**, requires SDL≥3.4.0; **zlib** | Closest fit to existing SDL stack: cached/streamed audio, reusable tracks, groups/tags, fades, gain, frequency ratio and basic spatial panning. Native callbacks need not enter Kof. Not a vanilla dependency |
| **miniaudio**, independent native library | [Pinned source](https://github.com/mackron/miniaudio/tree/9634bedb5b5a2ca38c1ee7108a9358a4e233f14d), **MIT-0 or public-domain alternative** | Permissive alternative with mixing, node graph, spatialization and decoding. WAV/FLAC/MP3 support does not imply built-in Ogg support. Pin ABI/build; not an additional mandatory backend |
| **Sound Physics Remastered**, Minecraft mod | [Pinned source](https://github.com/henkelmax/sound-physics-remastered/tree/ce6c71b8a5fcffc50e75d0407c9c516b0bfca515), declared **1.5.1+26.3**, beta upload configuration; repository **GPLv3** text | Occlusion, material absorption and reverb case study. Minecraft/OpenAL/mod coupling; not a standalone sound device/mixer. Do not translate GPL source and call the result a permissive Kof module |

The pinned [SDL3_mixer header](https://raw.githubusercontent.com/libsdl-org/SDL_mixer/cfa8d2c106caf89c585a5aae9eae9d75939eaf2f/include/SDL3_mixer/SDL_mixer.h) explicitly describes its spatial feature as basic and directs advanced3D users toward OpenAL. Decoder options have their own licenses. [OpenAL Soft README](https://raw.githubusercontent.com/kcat/openal-soft/8d2d2e2ed1f51df960e7eb4bb26b64625c873c0d/README.md) states the LGPL/HRTF split; [miniaudio license](https://raw.githubusercontent.com/mackron/miniaudio/9634bedb5b5a2ca38c1ee7108a9358a4e233f14d/LICENSE) states its alternatives. These are pinned source snapshots, not claims about their latest stable release numbers.

**Choice:** retain queued SDL audio for G0. For a production mixer, evaluate SDL3_mixer first if basic spatial sound suffices; choose OpenAL Soft instead when HRTF/EFX are actual requirements. miniaudio is a third packaging/license alternative, not a reason to build three backends. No audio device was opened in this research.

**Kof-owned audio library:** cue IDs, asset selection, bus/category policy, source lifetime, voice budget/priority, loops/fades/cancellation, subtitle events and bounded occlusion updates. Native library owns device, decoding, mixing and DSP. World queries stay in the chosen collision owner; do not cast one occlusion ray per voice per frame without a budget. Backend attenuation/effects are explicitly configured mechanisms; policy remains Kof-owned. Existing ENGINE_PLAN's Kof-owned attenuation baseline is unchanged unless delegation of that calculation is deliberately selected.

## 7. Rendering and resource lifetimes

| Candidate / classification | Identity / license | Recommendation |
|---|---|---|
| **JOML**, actual vanilla math dependency | **1.10.9**, [source](https://github.com/JOML-CI/JOML/tree/1.10.9), **MIT** | Highest-priority selective port; direct JVM use measured below. Mutable/destination overloads avoid incidental allocation. Define multiplication order, aliasing, radians, handedness and depth convention |
| **Flywheel**, Minecraft instancing library | **1.0.6**, Minecraft26.1.2 source [pin](https://github.com/Engine-Room/Flywheel/tree/b9d129af84384610eed21799563efe1b54055d20), **MIT** | Best permissive instance-lifecycle reference: persistent instances, changed/visible/deleted state, model/material/bounds. Actual runtime depends on Minecraft/loaders/Mixins, not standalone SDL |
| **Sodium**, Minecraft optimization mod | Development **0.9.3-alpha.1 for26.3**, [pin](https://github.com/CaffeineMC/sodium/tree/44b89f42dec873aa7c799224d7a10359b393a487), **PolyForm Shield1.0.0** plus third-party material | Architecture study only by default. Restrictive noncompete terms extend across language/architecture changes; not a casual `.kf` source port. Current code has GL/Vulkan/Renderpearl paths; older OpenGL-only summaries are stale |
| **LWJGL**, actual vanilla native binding layer | **3.4.3**, [source](https://github.com/LWJGL/lwjgl3/tree/3.4.3), **BSD-3-Clause**, native components separately licensed | Useful JVM binding, not a rendering engine. Native Kof should adapt selected underlying C APIs directly rather than port LWJGL or add a JVM bridge |
| **Iris**, Minecraft shader-pack compatibility mod | **1.11.4**, Minecraft26.1.2 [pin](https://github.com/IrisShaders/Iris/tree/bff1e69cb6c5519d8745784aa9c8b92984de67e7), repository **LGPLv3**, README warns about **AGPLv3 glsl-transformer** dependency | Low fit: OptiFine/ShadersMod compatibility, Minecraft/Sodium/OpenGL coupling and substantial license closure. Not a shortcut to a native SDL renderer;26.3/Vulkan support not established by this pin |

Indium is not an extra modern renderer to add: its [own README](https://github.com/comp500/Indium/blob/1.21.x/main/README.md) says Sodium0.6+ integrates Fabric Rendering API support, making Indium unnecessary and incompatible with those versions.

### What to carry into `.kf`

1. **Extraction → preparation → drawing.** Current [Fabric API0.160.5+26.3 extraction events](https://maven.fabricmc.net/docs/fabric-api-0.160.5+26.3/net/fabricmc/fabric/api/client/rendering/v1/level/LevelExtractionEvents.html) forbid attaching mutable world objects to render state. Extract minimal interpolated transforms, resource IDs and draw data into reusable frame storage. Start sequentially; this boundary does not require Kof worker threads.
2. **Explicit passes/pipelines and staging.** 26.3 Renderpearl uses explicit pass attachments; ShaderC and explicit shader layouts serve both backends. SDL_GPU already supplies pipelines, command buffers, transfer buffers, passes and fences. Adapt SDL's contracts instead of cloning Renderpearl's abstraction layers.
3. **Visibility and dirty geometry are separate.** Sodium's source shows section meshing, cancellation, pooled arrays, region batches, camera-relative coordinates and graph/frustum visibility. It does not establish generic greedy meshing. For this engine begin with conservative bounds/frustum tests and room/spatial-region caches, not a Minecraft voxel/chunk requirement.
4. **Persistent instances.** Flywheel's lifecycle is useful for props, loot meshes and repeated effects. Kof decides changed/visible/deleted state; the adapter only packs/uploads records. Model changes and reloads invalidate dependent instances.
5. **Resource generations and retirement.** Current [resource reload API](https://maven.fabricmc.net/docs/fabric-api-0.160.5+26.3/net/fabricmc/fabric/api/resource/v1/ResourceLoader.html) distinguishes preparation/application; [render invalidation](https://maven.fabricmc.net/docs/fabric-api-0.160.5+26.3/net/fabricmc/fabric/api/client/rendering/v1/InvalidateRenderStateCallback.html) forbids retaining invalid render objects. For KOOKIE, stage/validate replacements, publish generations at a frame boundary, keep the previous valid asset on preparation failure, and retire old GPU resources after last use. Transactional rollback here is our recommendation, not a claim about Minecraft guarantees.

Do not treat arbitrary Minecraft GLSL as SDL-compatible shader input. [SDL_GPU](https://wiki.libsdl.org/SDL3/CategoryGPU) uses its own resource layouts/backend formats and `[0,1]` depth conventions; JOML's default GL examples require deliberate projection choices. SDL's four-color-attachment limit differs from the eight target slots documented in Minecraft26.2. Complex OIT/pass ports can exceed that boundary.

Current scalar FFI makes dynamic staging throughput an unresolved measurement, not a zero-copy promise. A matrix/instance should cross as a bounded tuple operation rather than sixteen independent field calls where possible. No render benchmark, graphics initialization or shader execution was performed.

## 8. Recommended reusable Kof library slices

These are proposed boundaries, **not created packages or promised APIs**. Keep the existing G0 compiler/ABI gates first; do not start seven libraries in parallel before native feasibility is established.

| Priority | Slice | Reuse source/idea | Bounded first contract |
|---|---|---|---|
| 1 | Math | JOML MIT subset | Vectors, quaternions, transforms, AABB/frustum; caller-owned destinations, documented coordinate convention |
| 2 | IDs and entity storage | Artemis/Ashley contracts | Generation IDs, typed per-type arrays, query membership, deferred structural changes; no reflection or parallel scheduler |
| 3 | Content, item patches and codecs | Minecraft concepts + DFU MIT ideas | Namespaced definitions, inherit/override/remove patches, validation/reference resolution, structured errors, explicit migrations; repair native JSON first |
| 4 | Developer commands | Brigadier MIT subset | Cursor/span parser, typed arguments, permission-aware command-ID dispatch; no exception-driven normal parse errors |
| 5 | UI and settings | owo MIT subset + independent YACL-style state | Measure/layout, focus/input routing, pending/apply/discard/reset, draw extraction; low-level font services separate |
| 6 | Render data/resources/instances | Current extraction contracts + Flywheel MIT subset | Reusable frame data, explicit draw/pass policy, resource generations, dirty persistent instances; SDL_GPU stays backend |
| 7 | Audio events and voices | Minecraft sound-instance separation | Cue/bus/voice/subtitle policy over **one** selected mixer; budgeted acoustic queries |

AI blackboards/sensors and typed effect contexts fit later gameplay milestones. Existing capsule/BVH collision remains unless a Jolt/Bullet ownership exception is selected. A full DFU rewrite engine, Dominion scheduler, ModernUI/Arc3D native translation, Iris compatibility layer or Sodium transplant would increase rather than reduce initial scope.

For the additional shipped libraries, borrow the **problem boundaries**, not the whole Java stack: primitive numeric storage from fastutil's use case, Unicode-aware text from ICU's use case, framed asynchronous transport from Netty's use case, bounded compression from LZ4's use case. None solves KOOKIE's ECS, UI, replication or save-version policy automatically. No port or Kof interoperability assessment of those complete libraries was performed; select native dependencies only when the feature requires them.

## 9. Executed Kof/JOML probe

This is the only new executable library-integration proof in this research. It uses the actual JOML artifact named by Minecraft26.3, not a mocked Java fixture.

### Inputs and setup

- Kof release JAR: `/tmp/kookie-kof-cli-0.4.9-beta.jar`, SHA-256 `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`; OpenJDK27. Compiler/source identity and acquisition are recorded in [RESEARCH_PROBES](RESEARCH_PROBES.md).
- [JOML artifact](https://libraries.minecraft.net/org/joml/joml/1.10.9/joml-1.10.9.jar): **814581 bytes**, SHA-1 `438e036486bad66b189bff385dd07dea4f74a146` matched the version metadata; SHA-256 `feca4db853371704338621c120acc5cc32300d8af635fa42414b6213301e216b`.
- Preloaded isolated cache path: `/tmp/kookie-minecraft-research/deps/org/joml/joml/1.10.9/joml-1.10.9.jar`. No user dependency cache or project installation was changed; the artifact was downloaded directly and hash-checked, not resolved transitively.
- Dedicated working directory: `/tmp/kookie-minecraft-research/joml-probe`, containing only this probe's `main.kf` and dependency declaration. Kof `run` collects siblings, so unrelated entry files must not share it.
- `kofdeps` content: `org.joml:joml:1.10.9` followed by newline.
- `JAVA_TOOL_OPTIONS=--enable-native-access=ALL-UNNAMED` was supplied to propagate the setting to Kof's child JVM. Both runs were serial with a60-second timeout. They used no graphical, audio-device or server APIs.

Complete `main.kf`:

```kof
import org.joml.Vector3f
import org.joml.Matrix4f
main() {
    var v = new Vector3f(3.0f, 4.0f, 0.0f)
    println(v.length())
    println(v.dot(v))
    var m = new Matrix4f()
    m.translation(2.0f, 0.0f, 0.0f)
    m.transformPosition(v)
    println(v.x())
    println(v.y())
}
```

Commands, from that working directory with the stated environment:

```sh
java --enable-native-access=ALL-UNNAMED \
  -Dkof.deps.home=/tmp/kookie-minecraft-research/deps \
  -jar /tmp/kookie-kof-cli-0.4.9-beta.jar \
  run main.kf --target jvm --deps

java --enable-native-access=ALL-UNNAMED \
  -Dkof.deps.home=/tmp/kookie-minecraft-research/deps \
  -jar /tmp/kookie-kof-cli-0.4.9-beta.jar \
  run main.kf --target native --deps
```

### Observed results

JVM **exit0**, stdout:

```text
5.0
25.0
5.0
4.0
```

Native **exit1**, empty stdout, diagnostics:

```text
:0:0: error: import 'org.joml.Vector3f' not found in the module (expected org/joml/Vector3f/ or org/joml/Vector3f.kf under the root) [PKG006]
:0:0: error: import 'org.joml.Matrix4f' not found in the module (expected org/joml/Matrix4f/ or org/joml/Matrix4f.kf under the root) [PKG006]
```

JVM stderr additionally printed `Picked up JAVA_TOOL_OPTIONS: --enable-native-access=ALL-UNNAMED` twice; native stderr printed it once. No other diagnostics were observed.

**Proves:** Java class imports, constructor calls, Float arguments/results, object mutation and these vector/matrix operations work on the tested Kof JVM path with `--deps`. The same dependency declaration does not expose Java classes on native; rejection occurred before native execution.

**Does not prove:** all JOML overloads, callback/generic-builder support, JNI/FFM bindings, performance, graphics/audio/physics startup, or any other library's Kof integration. No native `.kf` JOML port was implemented.

## 10. Licensing and adoption rules

- **Permissive source ports:** JOML/Brigadier/DFU/owo/Flywheel are attractive, but preserve applicable copyright/license notices. Apache-derived Ashley/reflection code also carries Apache conditions; do not relicense a source translation merely because its extension changes.
- **Copyleft integrations:** OpenAL Soft, YACL, ModernUI and Iris require component/dependency-specific distribution review. Dynamic linking is not a blanket exemption; source/modification/relinking and notice obligations depend on the applicable license and packaging. This does not automatically make every engine file LGPL.
- **Restricted or missing grants:** Sodium's PolyForm Shield is not unrestricted OSS; Physics Mod is All Rights Reserved; closed VSCore/Krunch reuse was not licensed by the public mod wrapper. Treat these as architecture evidence, not source donors without additional rights.
- **Assets are separate:** fonts, HRTF datasets, sounds, shaders and shader packs have their own terms. Minecraft's EULA and third-party asset permissions are not cleared by owning the game or having readable source.
- **Pin the actual integration:** record upstream commit/artifact hash, library build options and dependency notices when a port/backend is selected. Several research pins are development snapshots or older compatible branches, explicitly marked above; “used by a modern Minecraft mod” is not evidence of26.3 compatibility.

Research used official Mojang metadata/release notes, versioned Fabric/NeoForge APIs, Maven metadata/POMs, pinned source/license files and author-maintained mod metadata. GitHub's unauthenticated API rate limit prevented some latest-release lookups; pinned source identities were used instead, not guessed release versions. No engine changes, dependency installation, full test suite, desktop access or game launch occurred.
