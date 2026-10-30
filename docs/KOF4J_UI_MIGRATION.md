# Kof/KofScript reusable UI and media boundary

This document fixes the ownership boundary for reusable UI work in KOOKIE and
its migration path to the official Kof4j standard library. It is an architecture
contract, not a second UI framework.

## Decision

Use the official Kof4j primitives first:

- `kof.ui` owns colors, themes, windows, widgets, layout handles, components,
  state, events, Canvas and design tokens.
- `kof.media` owns file/handle media operations: `Image.open`, `Audio.openWav`,
  `Video.open`, `Mic.record/list`, image/audio metadata and byte export.
- KOOKIE owns the GatoGanso visual skin, published asset manifests, native
  `FrameStaging` presentation and game-specific composition.
- KofScript owns bounded semantic descriptors. It does not retain `kof.ui`
  handles or native pointers; a Kof/KofJS host consumes its descriptors.

The current Kof4j `kof.ui` implementation renders for KofJS and intentionally
keeps JVM/native handles as no-ops. The current `kof.media` API has no
low-latency sound-cue bank or playback method. KOOKIE therefore adds only a
semantic sound-cue/queue adapter over the existing bounded `QueuedAudio`
contract. It does not duplicate `kof.ui`, decode media, or create another
renderer.

## Measured Kof 0.6.6 ABI boundary (historical)

The active KOOKIE source pin is Kof4j
[`2971d2fe4cc873eb50fcd1b7d7d3e097381281c8`](https://github.com/KofLang/Kof4j/tree/2971d2fe4cc873eb50fcd1b7d7d3e097381281c8) (`0.6.8`).
The Buffer qualification below was run with Kof `0.6.6`; do not treat it as
evidence for the active pin until rerun.

The pinned implementation and the latest upstream documentation are not
identical:

- [`KofBuffer.java`](https://github.com/KofLang/Kof4j/blob/7c237861a9035d84b1f7ec4cfddd89daef4c6ddd/kof-compiler/src/main/java/dev/kof/compiler/KofBuffer.java)
  exposes `buffer.alloc(Int)`, `buffer.peek8/32/64`, `buffer.poke8/32/64` and
  `Buffer.bytes()` on JVM, JS and native x86-64; its source comments also claim
  riscv64/aarch64 support.
- [`CompilerFfiBinding.java`](https://github.com/KofLang/Kof4j/blob/7c237861a9035d84b1f7ec4cfddd89daef4c6ddd/kof-compiler/src/main/java/dev/kof/compiler/CompilerFfiBinding.java)
  lowers `Buffer(U8)` as the `B` token and a synchronous payload pointer on the
  pinned native implementation. `scripts/verify_simd_dispatch.sh` exercises
  copy-in/copy-back and an INOUT reduction on JVM and native x86-64.
- The P1 fixture additionally fills eight bytes with Kof `buffer.poke8`, crosses
  one C INOUT call and checks the copied-back inverted bytes. It passed with
  `buffer-fixture-sum=809` and `buffer-inout-sum=1231` on both targets.
- The pinned upstream buffer guide still documents Native as an honest gap,
  while the pinned compiler/runtime source exposes the bounded native
  implementation used by KOOKIE. Cross-target support therefore remains an
  upstream source claim, not a KOOKIE qualification result.
- [`RUNTIME_ABI.md`](https://github.com/KofLang/Kof4j/blob/7c237861a9035d84b1f7ec4cfddd89daef4c6ddd/docs/runtime/RUNTIME_ABI.md)
  is a behavioral runtime contract, not a stable public C wire ABI. KOOKIE
  must not copy object headers, array layouts or allocator details into an
  engine-facing library.

Decision for KOOKIE: use `Buffer(U8)` only for synchronous, bounded,
target-qualified byte calls. The P1 producer proof and the
`GPU_SCENE_VERTEX_V1` source path do not establish generic zero-copy, retained
payload pointers or work that outlives the call. Kof keeps `FrameStaging`,
`QueuedAudio` and content wires as bounded semantic arrays; native code copies
the GPU payload into owned storage.

The GPU V1 descriptor fixes schema, length, stride, generation and checksum,
and scalar `kookie_gpu_scene_push_vertex_resource` remains the fallback. The
focused native adapter and Vulkan renderer gate now passes on local
`Intel(R) Graphics (ARL)` evidence with one draw call, 984 instances and p95
frame time of `1710` microseconds. This qualifies the selected local Linux
vertical slice; broader target hardware and cross-platform presentation remain
release gates.


## Ownership map

| Concern | Reusable owner now | Kof4j destination | Boundary |
| --- | --- | --- | --- |
| Row/column/stack/panel composition | `KookieUiLayout*` skin helpers | `kof.ui` layout primitives | Skin chooses tokens; Kof4j owns handles |
| Buttons, fields, toggles, sliders, feedback | `kookie_ui_components.kf` | `kof.ui` widgets/components | Keep game/editor composition local until an upstream generic API exists |
| Fonts and typography | `font_catalog.kf`, `KookieUiText` | `kof.ui.Font` and design tokens | Font files/catalog remain package assets |
| SVG/PNG references | `KookieUiAsset`, generated UI manifest | `kof.ui.Image`/`Icon`, `kof.media.ImageData` | Manifest verifies publication; runtime decodes |
| Audio file intake | `content` WAV/OGG intake | `kof.media.Audio` | Keep decoder/packaging ownership at the content boundary |
| UI sound effects | `KookieUiSoundCue` + `KookieUiSoundBank` | Future `kof.media` playback/cue API | Queue carries clip IDs; native adapter owns decoding/playback |
| KofScript UI | `KookieUiScriptDocument` | Future official descriptor package | No handles, no pointers, bounded state |
| Native gameplay HUD | `kookie_ui_native.kf` + `FrameStaging` | Not a `kof.ui` replacement | One existing native renderer and fixed budgets |

## Implemented first slice

`src/ui/kookie_ui_audio.kf` adds a reusable, target-neutral cue contract:

- `KookieUiSoundCue` validates a package-relative `.ogg`/`.wav` source, a
  non-empty semantic label, a lowercase SHA-256 digest, a positive native clip
  ID and a default gain in `0..100`.
- `KookieUiSoundBank` registers a bounded cue set before opening, queues one-
  shot or spatial effects through `core.QueuedAudio`, preserves FIFO and
  exposes the consumed clip/gains for the native adapter. It does not decode
  files or retain SDL handles.
- `kookie_ui_audio_catalog.kf` is the native publication boundary:
  `kookieUiPublishedSoundCue` binds exact source/digest pairs to the 14 native
  OGG clip IDs, and `kookieUiSoundBankAddPublished` admits only those cues.
  Generic `KookieUiSoundBank.add()` remains available for external adapters and
  future WAV publication.

`src/ui/kookie_ui.ks` exposes the same sound node in the KofScript descriptor:
`bindSound(soundType, soundId, source, label, checksum, clipId, defaultGain)`,
`nodeClipId()` and `nodeGain()`, plus the OGG/WAV kind constants. Asset
publication uses `bindAsset(assetType, assetId, source, alt, checksum)`; both
numeric kind arguments stay in stable first positions for native lowering. The
descriptor only records semantic data and participates in its existing
checksum/lifecycle rules.

## Migration to Kof4j

### Phase 1 — current repository

1. Reuse `kof.ui` and `kof.media` instead of adding compiler intrinsics.
2. Keep KOOKIE skin/token/manifest code as a thin composition layer.
3. Use the sound cue adapter for native game effects; keep file validation and
   package staging separate from playback.
4. Keep KofScript descriptors bounded and host-consumed.

### Phase 2 — upstream contribution

1. Propose a target-neutral `kof.media` sound contract only after playback
   semantics are defined for KofJS, JVM and native targets: ownership, close,
   gain, looping, spatialization and failure behavior.
2. Move generic descriptor types and tests to Kof4j only when KofScript has an
   official import/module boundary for them. Until then, the concatenated local
   script gate is the honest integration point.
3. Move generic layout/widget behavior to `kof.ui`; retain only GatoGanso token
   values, asset IDs and game composition in KOOKIE.
4. Replace each local wrapper at its call sites, then delete the obsolete
   wrapper. Do not add aliases or compatibility shims.

### Acceptance invariants

- One authoritative UI renderer per target.
- No game authority, native pointer or decoder hidden in a reusable UI class.
- Published raster/vector/audio references are package-relative and digest
  checked at the publication boundary.
- Kof and KofScript expose equivalent semantic state and rejection rules.
- JVM/native probes remain deterministic even when `kof.ui` is a no-op.
- KofJS remains the only target claiming real `kof.ui` rendering until Kof4j
  closes the other target contracts.
