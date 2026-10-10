# Changelog

This file records meaningful changes to KOOKIE in plain language. It is not a promise that a milestone is finished; the roadmap and focused checks are the source of truth.

## Unreleased
- Updated the native dependency baseline to latest stable SDL 3.4.18 and Zig
  0.17.0; SDL_mixer remains at its latest stable 3.2.4. GitHub Actions now use
  checkout v7, setup-java v6, download-artifact v8 and the latest verified
  setup-zig commit, while CI runs on Temurin 27. PE/COFF builds now pass
  explicit `-g0` to keep Zig 0.17.0's debug paths out of reproducible objects.
  The Kof `0.5.0-beta` source pin remains `bf17ac7e736471c8a04b4153e5b0f607be75e70c`;
  the latest tagged archive at `317d9f6b1c3e27032cc955a05f859f6c627d9338`
  fails native Buffer qualification (`FFI001`).

- Hardened KOOKIE's native binary consumers against the pinned Kof
  `0.5.0-beta` `File.readBytes()` partial-word bug: bounded source, save,
  replay, package and KofScript reads now use `readRange`. Linux presentation
  verification rejects a nonzero child status, Windows PE/package/release
  checks fail closed on path, classpath, cleanup, reviewer and provenance
  mismatches, and release smoke capability failures happen before builds.
- Added `scripts/report_code_mix.py` and a source-composition audit. The current
  working tree is 94,374 physical lines: 76.85% Kof, 0.59% KofScript, 11.36%
  C/header, 6.96% shell, 2.53% Python, 1.59% PE-bridge Java and 0.12% GPU
  shader. The runtime-only slice is 86.43% Kof; native mechanisms remain at
  the boundary unless a bulk-buffer ABI proves a faster, safe migration.

- Added an isolated KofJS UI demo and a published UI asset manifest. UI
  references now use generated bindings from the manifest, with stable IDs,
  package-relative runtime paths, required lowercase SHA-256 digests, and
  explicit prototype-asset optionality. The demo stylesheet resolves packaged
  font URLs without fallback 404 requests. Shared `verify_ui_manifest.py`
  gates validate the `none`, `prototype` and demo staging profiles.
- Added a bounded retained layout/component kit for apps, games and Kutter
  surfaces: `KookieUiLayoutSpec`, `KookieUiPanel`, buttons, text fields,
  toggles, sliders, progress/badge feedback, toolbars, tabs and inspectors.
  Common control state stays in Kof for deterministic JVM/native probes while
  KofJS renders the same handles; the G10 probe and UI demo now exercise the
  shared composition path.
- Added `KookieUiSoundCue`/`KookieUiSoundBank` for package-relative `.ogg`/`.wav`
  cue metadata, exact publication tuples for the 14 registered UI OGG clips,
  bounded FIFO/spatial gains and deterministic native-adapter metadata. The
  native SDL path now applies left/right gains to registered UI tracks; the
  KofScript descriptor carries the same sound node, clip ID and default gain.
  The UI demo and G10 probe exercise both layers. Descriptor SHA-256 is not a
  substitute for a release file-byte/license gate.
- Audited the active Kof4j `0.5.0-beta` pin
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`: `Buffer(U8)` is a synchronous
  byte boundary on JVM/native x86-64 and passes the local SIMD INOUT fixture.
  The pinned source claims cross support, while newer upstream `main` docs
  still report Native `FFI001`; KOOKIE keeps checked scalar/owned staging
  until a target-specific bulk fixture proves a portable engine boundary.
- Added the P0 dedicated-server performance path: the direct tick benchmark keeps
  its existing p95 gate, while a bounded 64-sample phase profile reports clock,
  collision, AI, projectile, pickup and finalize percentiles. Enemy snapshot and
  impact histories now evict through head/count ring buffers instead of shifting
  full arrays at capacity.
- Added the first internal Kof/KofJS UI library slice: bounded SVG/PNG asset
  metadata with required alternative text, Jared Lite/Pixand text roles,
  dark surface tokens, bounded intrinsic SVG icons, reusable `bindMenu` and
  `bindHud` compositions, and a composable `KookieUiDocument` facade. The
  focused G10 probe qualifies JVM/native execution and KofJS type-check/build
  output.
- Added the KofScript GUI companion `src/ui/kookie_ui.ks`: bounded semantic
  text/asset/icon descriptors with publication validation and deterministic
  lifecycle state. The UI gate now executes this companion on JVM/native;
  handle-backed rendering remains in the Kof/KofJS facade because current
  KofScript runtimes do not expose `kof.ui` handles.
- Rebuilt the native engine UI skin on the shared Kof/KofJS design tokens:
  `KookieUiNativeTheme` now centralizes FrameStaging surfaces, focus rails,
  semantic text colors and accessibility contrast for GameShell, HUD,
  nameplates and scoreboard. The gameplay HUD now exposes stable HP, AMMO, BAG
  and XP labels within a bounded 438-vertex budget. The SDL atlas palette and
  host stylesheet now use the same background/surface/accent/focus/danger/
  success tokens. Focused multiplayer, font and gameplay UI gates remain
  green.
- Optimized native UI staging for render-boundary cost: `FrameStaging` now
  writes quads/triangles in one bounded operation, primitive spans batch Kof/C
  upload calls, and CPU/GPU scene capacities grow with headroom to avoid
  reallocating or rebuilding buffers on small HUD/menu count changes. Gameplay
  UI remains one scene draw call.
- Native job workers now execute only platform scheduling and completion;
  result and descriptor-checksum semantics remain in Kof's
  `BoundedJobGraph`, removing engine computation from the C worker.
- Native transport no longer computes received-payload sums in C; Kof
  aggregates the received words while the C boundary retains socket and
  wire-word transfer mechanics.
- Added bounded open-format SVG and SVGZ intake in Kof: static W3C shape
  parsing, fixed-point `SVGC` canonical vector wire, color/alpha preservation,
  gzip decoding and rejection of scripts/external/CSS features.

- Native world GPU buffers now grow from the submitted scene/world vertex counts
  instead of a fixed actor budget, and the presentation smoke reports the
  current batch capacity before gameplay drawing.
- Native GLB loading now retains every source triangle for the goose and cat,
  allocating scene arrays and embedded images from GLB-declared sizes instead
  of fixed caps; complete animal surfaces no longer show holes.
- Native model texture upload now copies the cat GLB's embedded PNG into a
  full-size UV region; the goose keeps its dedicated procedural material tiles
  because its GLB has no embedded image.
- Native goose and cat model emission now applies the idle animation tick to
  the authored GLB pose; gameplay animals no longer freeze when they are not
  moving.
- Projectile tracers now render at foreground depth, and bounded replay
  presentation history rolls over instead of aborting fixed-step gameplay
  after repeated fire and dry-fire input.
- Native menu glyphs now preserve grayscale edge coverage through SDL_GPU and
  the Windows shell, while menu option rows apply the selected text size and
  keep long labels inside their panels.
- Display Apply now synchronizes and verifies windowed/borderless sizes, uses
  the selected resolution for borderless windows, and verifies exclusive
  fullscreen transitions.
- Native GLB actors now use dedicated UV-addressed model texture tiles for
  goose body/head/feet and cat materials instead of the arena palette, while
  retaining a denser bounded sample of the authored meshes.
- Autonomous enemy ticks now tolerate having no live player target, so repeated
  fire/death cycles cannot abort the fixed-step gameplay loop.
- Kept 7x7 menu text inside the native clip contract: the `GATOGANSO`
  display title now uses a fitting scale, and oversized labels clip glyphs
  before staging instead of sending rejected coordinates to SDL_GPU.
- Camera-relative gameplay now applies horizontal mouse yaw to WASD movement,
  while the deterministic third-person follow, scroll zoom and authored
  obstacle collision remain active.
- Stabilized live GatoGanso fixed ticks by draining confirmed player weapon
  presentation events and skipping dead autonomous enemies; confirmed shots
  now render bounded on-screen tracers.
- SDL gameplay now enables relative mouse mode while active, so WASD and
  continuous mouselook use the same focused gameplay input path.
- First-person presentation now omits the local goose world mesh, projects
  actor overlays with the GPU camera, and selects local hitscan targets along
  the crosshair ray instead of by nearest distance.
- Rebuilt the bundled GatoGanso font atlas from tight glyph bounds into
  readable 7x7 cells with an 8-cell advance; native GPU and Windows shell
  renderers now use the same width and bit-mask contract.
- Added bounded native GLB presentation for the GatoGanso encounter: the
  prototype content profile now uploads the existing goose and cat models
  directly into the SDL_GPU world pass with per-actor animation/material
  state. Content-free presentation packages retain the bounded procedural
  silhouette fallback and do not redistribute prototype assets.
- Pinned the hosted verification workflow to the signed Node24-compatible
  `mlugg/setup-zig` commit while upstream `v2` still declares Node20.
- Pinned release artifact upload/download actions to their Node24-compatible
  major versions and made the Linux release job export its pinned SDL3 3.4.16
  prefix; the host's newer system SDL3 is no longer accepted implicitly.
- Made the Windows Git Bash packaging gate use NTFS ACLs instead of relying on
  POSIX `chmod` mode bits; transient Ed25519 signing keys are restricted with
  `icacls.exe`.
- Made Windows cross-linker options immune to Git Bash's MSYS path conversion;
  `/Brepro` and `/subsystem:console` now reach Zig as linker flags.
- Hardened the hosted Ubuntu verification workflow's Wine gate: enable the i386
  architecture, install both Wine architectures and initialize a win64 prefix
  before the Windows durable-save smoke. Wine64-only installation can fail before
  the actual PE test when `syswow64/rundll32.exe` is unavailable.
- Added bounded OGG Vorbis intake to the developer and packaged native kooker:
  page CRC/sequence/continuation/BOS/EOS state, Vorbis identification/comment/
  setup headers, decoded-frame and optional sample-frame loop bounds are
  validated before the byte-preserving payload is retained. SDL_mixer's pinned
  `stb_vorbis` path predecodes OGG music and the bundled UI SFX tracks, and
  explicit sample-frame loop start/end/count controls avoid gap-prone
  wall-clock looping.
- Closed the pressure-sensitive G5 dedicated-server p95 gap. The authoritative
  workload now uses a scalar enemy step without a per-tick
  `EnemyAttackDecision` record, caches stable projectile target slots and
  coordinates, batches pickup checksum blocks and reference-scene checksum
  deltas. JVM/native output remains checksum `217802` with resource signature
  `520690`; the focused native gate with 128 warm-up and 512 measured ticks passed at
  p50/p95/p99/max `3805/3925/3958/4936us` under the `4000us` budget.
  Package verification uses the same qualification window.
- Closed the Linux presentation packaging gap for the PE-safe save bridge:
  `libkookie_persistence_adapter.so` is now shipped beside the SDL adapter, so
  host staging, publication and confirmation resolve to one shared native
  persistence state instead of a missing FFI library.
- Completed the bounded P2 crash-durable save publication contract. The Kof
  `BoundedSessionSaveCoordinator` now encodes level progression plus G3
  authority, stages arbitrary paths, loads/restores validated sections,
  discards interrupted staging and exposes the explicit
  `stage → native publish → confirmPublished` boundary. The POSIX Kof gate
  exercises that path end to end; the native adapter flushes file data,
  performs same-directory atomic replacement and flushes directory metadata on
  POSIX and Windows. Added phase-interruption E2E coverage for pre-sync,
  post-sync, post-rename, post-directory-sync and torn-stage recovery in
  `scripts/verify_durable_save.sh` and
  `scripts/verify_durable_save_windows.sh`; the G7 player-facing goose gate
  now publishes and restores a freshly constructed session, including
  inventory, and the G0 presentation owner publishes on gameplay exit or
  window close and restores on process start/re-entry. A dedicated-server save
  owner remains a separate integration milestone.
- Added the PE-safe `BoundedHostSessionSaveCoordinator` bridge. Kof keeps
  section encoding, schema validation, migration and rollback; checked
  integral calls hand bounded wire words to the native adapter for file-byte
  staging/read and durable publication without `File` or `String` FFI. The G7
  native gate, `scripts/verify_pe_durable_save.sh` under generated PE/Wine and
  the G0 packaged presentation smoke now exercise the PE-safe bridge and its
  presentation lifecycle; a dedicated-server save trigger remains separate.
- Fixed the expanded G1 arena regression: restored the raised-room collision
  geometry, synchronized the JVM transport backend with the native 1,740-word
  / 6,984-byte frame bound, and updated the external role receiver for the
  24-word gameplay-state message. External evidence gates now validate all 178
  authored arena triangles.
- Added a shared fail-closed SDL3/SDL_mixer resolver and a pinned
  `scripts/bootstrap_sdl3_mixer.sh` path for hosts that have SDL 3.4.16 but no
  SDL_mixer development package. Linux package, presentation, LAN and G5 gates
  now accept the prepared prefix, validate exact 3.4.16/3.2.4 metadata and
  continue bundling only the reviewed SDL runtime libraries.
- Added the native `kookie-launcher` for Linux and Windows x86_64. It discovers
  the newest published target package from the KOOKIE GitHub release API,
  verifies the embedded Ed25519 manifest and archive digest, extracts safely,
  atomically activates updates, retains the previous marker and falls back to
  the active package on transient update failures. Added the signed local
  updater fixture at `scripts/verify_launcher.sh`.
- Prevented a local dogfood package from being downgraded when the public GitHub
  channel is older or equal: the launcher reads the bundled `PROVENANCE.txt`
  identity and keeps the highest available SemVer baseline until a newer
  published release exists.
- Fixed Windows dogfood/service launches without `LOCALAPPDATA` or
  `USERPROFILE`: the launcher now reuses the already-created remote action
  directory as isolated state, falling back to `TEMP`/`TMP` when telemetry is
  unavailable.
- Made dogfood launcher child creation service-safe: the bundled game does not
  inherit remote capture handles, while normal Windows window creation remains
  enabled; desktop launches retain inherited stdio.
- In dogfood mode, the launcher now captures the bundled game's stdout/stderr
  with bounded buffers and propagates a nonzero game exit; desktop mode keeps
  the detached reaper and inherited stdio.

- Branded the player-facing test game **GatoGanso** and set `Jared Lite`
  as the default UI font with `Pixand` for display/title text. The supplied
  SIL Open Font License files, source TTFs and deterministic bounded native
  atlas are retained in the source and distributable font catalog.
- Added the flexible accessibility surface to the GatoGanso shell and native
  Windows shell: HUD scale at 85/100/115 percent, tactical-map visibility and
  high-contrast text. Live presentation applies scale/map changes without
  changing fixed overlay budgets.
- Expanded the bounded GUI probe to stage the accessibility frame and added
  regression coverage for live HUD scaling, minimap visibility and high
  contrast. The main menu now has explicit Accessibility and Quit rows while
  preserving Kutter authoring access.


- Added a dedicated Kutter Level Editor surface inspired by DINX authoring
  modes, MudLump cursor/grid editing and Zylve placement/validation workflows.
  It supports bounded select/prop/spawn/encounter/trigger/light/erase tools,
  cursor placement, selection movement, preview state, history and
  `BoundedKutterStudio` persistence.
- Fixed the CI linter and native/JVM regression gate by reducing the
  Rgsdev greybox catalog's repeated long calls to bounded range helpers and
  making level-editor tool-cycle coverage use the actual directional input
  contract.
- Added a Zylve-style round upper-right tactical minimap to the native gameplay
  presentation. Cooperative matches show local and remote player markers;
  PvP suppresses player markers while retaining non-player markers. Added
  camera-relative arena mapping, bounded marker geometry, and native/Kof
  regression coverage.

## 2026-10-02
### GUI shell polish and current Linux qualification

- Added a consistent framed shell, selected-row rails, screen-specific
  subtitles, bounded text clipping and explicit keyboard hints across the
  main, options, multiplayer and Kutter screens.
- Expanded `scripts/verify_multiplayer_ui.sh` to stage all four screen frames
  in both JVM and native paths; `scripts/verify_goose_game.sh` passes.
- Built local qualification artifact `0.1.0-gui.1` from source commit
  `b1d4db92bf3adf166d503ca0eb44d8569498950c`; the Linux archive SHA-256 is
  `d9b909a4270fc9ca8fbd46a63bd0a21bc646e819da2ae6c3f89fa143dc1da902`.
  Deterministic signing, extraction and package smoke passed. The artifact
  uses an ephemeral key and is not a public release.
- The overzeer presentation attempt remained blocked by full I/O pressure
  (`62.54%` blocked); no target-hardware presentation claim is made.

### Dedicated server budget recovery

- Cached active projectile counts and updated the reference-scene dynamic
  checksum incrementally without changing the deterministic workload checksum.
- `bash scripts/verify_dedicated_server.sh` now passes 512 measured ticks with
  p95 `3624us`, p99 `3689us` and maximum `3899us` under the `4000us` budget.
- Produced local native qualification package `0.1.0-perf.2` from source
  commit `87d3bc63b3bbc66c23f796258f5b9ea5147fb0df`; its archive SHA-256 is
  `3d40aa2c012e610c460379c5ca0c62ecf0cc30b6bba57165bfe45c2dee8c8014`.
  Extracted package smoke and packaged-server p95 qualification passed; it is
  not a public release.


### Demo release qualification refresh

- Recorded the current qualification result: the signed Linux presentation
  package gate/package smoke passed with a temporary pinned SDL_mixer 3.2.4
  prefix, and the signed Windows native PE/SDL presentation artifact gate
  passed with pinned MinGW SDL3/SDL_mixer and DXC.
- Clarified that these are artifact/package checks only. D1 still requires one
  clean-tree Linux/Windows pair, outside-checkout interactive
  play/restart/quit smoke, fresh-host/runtime-floor verification, native Linux
  GPU evidence, native Windows hardware evidence, final release policy/notes
  and cross-host multiplayer evidence if advertised.
- Added `.github/actionlint.yaml` metadata for the custom
  `kookie-demo-release` self-hosted runner label.

### Fresh local Play encounters

- Made every main-menu `Play` transition emit a one-shot gameplay-entry
  request. The presentation consumes it before the first gameplay tick and
  constructs a fresh authoritative bot encounter; ready multiplayer entry uses
  the same path.
- The focused presentation smoke now processes and advances the first fixed
  gameplay tick after that reset, separating input-admission failures from
  authoritative tick failures in the native diagnostic.
- Clipped Goose actor bodies, hearts and nameplates to the native screen
  bounds so edge-of-view labels cannot reject gameplay GPU vertex uploads.

### Full 3D world gameplay pass

- Replaced the presentation's fake integer screen projection with a GPU
  world-space pass. Kof stages authored `(x,y,z)` coordinates; the native
  SDL_GPU vertex shader applies a perspective view-projection matrix and
  D16 depth testing.
- Added a generated textured material atlas and separate world vertex stream
  for arena surfaces and interaction doors. The authored lower floor, raised
  platforms and upper room surfaces now render as room-over-room geometry;
  actors/HUD remain a separate overlay pass.

### Windows D3D12 pipeline compatibility

- Declared the SDL_GPU color-target count and fragment sampler count
  explicitly when creating the menu and scene pipelines. D3D12 rejected the
  previous incomplete resource metadata with `0x80070057`; the native HLSL
  vertex output signatures remain ordered for SDL_GPU's D3D12 contract, and
  backend/pipeline diagnostics remain available for hardware smoke runs.
- Preserved string payloads for uncaught Kof throws in the PE runtime so
  native presentation assertions report their actual failure message.


### Linux clean-tree qualification

- A local 2026-10-02 run built `0.1.0-linux-e2e.1` from source commit
  `1678a7de671866d94080718c367ab05875a92c2d`, verified deterministic signed
  package output, outside-checkout package smoke and the focused goose gameplay
  smoke. The archive used a temporary qualification key, so it is not a public
  release artifact.
- Isolated presentation reached the native shell but reported no DRI3 support
  and no supported SDL_GPU backend before timeout 124. Linux target-hardware
  presentation evidence remains open.

### Windows clean-tree qualification

- A local 2026-10-02 run built `0.1.0-windows-e2e.1` from source commit
  `1678a7de671866d94080718c367ab05875a92c2d` with Kof source commit
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`. The archive SHA-256 is
  `c8153ae34b2a1ea7f8c85411df95393c02573fc433a477c539153459975e80a4`.
- Outside-checkout verification passed deterministic duplicate builds,
  detached signatures, `SHA256SUMS`, safe ZIP extraction, the `kookie.exe` PE
  `MZ` header, clean-tree/Windows-presentation manifest fields and bundled
  SPIR-V/DXIL entries. The temporary qualification key means this is not a
  public release artifact.
- The optional isolated Wine presentation smoke reached native SDL but exited
  with code 70 and `kookie_gpu_open: No supported SDL_GPU backend found!`.
  Target Windows GPU/input/audio evidence remains open.

### Authoritative same-tick snapshot revisions

- Fixed authoritative snapshot admission to replace newer revisions at the same
  server tick while continuing to reject older ticks and sequence numbers.
- Reset rewind-history watermarks when replay restores an earlier checkpoint,
  preserving fixed-tick advancement after rollback.

## 2026-10-01
### Netcode fixed-tick híbrido

- Added the UZDoom-inspired fixed-tick input history: clients repeat up to
  three ordered inputs, include the latest snapshot ACK and retire history only
  after an authoritative input ACK.
- Added typed input-bundle and input-ACK messages with bounded validation,
  checksums, stale/order rejection and deterministic snapshot interpolation
  helpers.
- Pinned the native authenticated transport to the admitted peer address after
  handshake, rejecting valid-key datagrams from unexpected endpoints.
- Kept the portable authenticated UDP envelope instead of adding a QUIC
  dependency; the channel semantics are QUIC-inspired, not QUIC-compatible.
- Added a bounded 12-tick authoritative rewind history for hitscan range
  validation, deriving the rewind point from acknowledged snapshot lag instead
  of trusting client distance.
- Wired six-tick remote-player interpolation into the native presentation path
  and exposed deterministic prediction correction count/average/maximum metrics.
- Added focused G6 tests for lag-compensation tick derivation, historical
  distances, interpolation windows and correction accounting.


### G6 Windows PE/SDL qualification

- Fixed the Windows SDL adapter module lifetime: Kof FFI calls can close their
  per-call native arena without unloading the pinned adapter state.
- Expanded the reachable Kof PE/COFF lowering subset to cover the current
  gameplay and presentation graphs: classes, fields, objects, arrays,
  integral/Boolean/String values, control flow, printing, String indexing and
  integral FFI.
- Added reproducible native Windows packages: the SDL shell links the complete
  reachable `src/` Kof PE object, and the presentation profile links native
  Kof PE gameplay to the SDL3/SDL_mixer GPU adapter with SPIR-V/DXIL products.
- The isolated native-shell Wine smoke passed the gameplay markers and
  `KOOKIE native Kof PE gameplay verified`. Presentation Wine smoke remains
  optional and requires a DRI3-capable isolated GPU; the default Xvfb wrapper
  is not presentation evidence.
- Hardened the GitHub-hosted PE gate against `file` version differences by
  validating COFF/PE headers directly instead of matching platform-specific
  object-description text.

### KOF-first multiplayer lobby and score screen

- Added the bounded `MatchLobbyState` lifecycle for fixed two-player Host/Join,
  room/name identity, peer count, ping, transport errors and explicit
  ready/unready state.
- Added a bounded host-authoritative `MatchScoreboardState` with deterministic
  ranking, versioned/checksummed snapshots, stale/duplicate/tamper rejection
  and capacity-safe decode.
- Added the Kof-owned lobby card and `Tab` player screen with player, status,
  score, HP, K/D and honest ping display. Gameplay now waits for both connected
  players to select `READY`.
- Added `scripts/verify_multiplayer_ui.sh` and integrated the focused probe into
  the repository verification path.

### First demo package automation

- Added `scripts/verify_linux_presentation_package.sh` for signed extraction,
  package smoke and optional isolated presentation smoke.
- Added `scripts/build_demo_release.sh` for clean-tree deterministic double
  builds, provenance/signature validation and target package smoke.
- Added the manually approved `.github/workflows/release_demo.yml` pair
  builder/publisher for Linux and Windows presentation artifacts.
- Fixed the Linux presentation launcher to change into its package root before
  resolving the bundled SDL adapter path; package smoke now runs from outside
  the extracted directory.
- Normalized Linux tar ordering, ownership and timestamps so repeated
  presentation builds are byte-identical; package smoke executes outside the
  extracted root.
- Presentation archives now include `DEMO_CONTROLS.txt` and enforce the
  first-demo `content_profile=none` boundary.
- Fixed native presentation qualification: the shooter HUD now accepts the
  authored 100-health goose actors, GPU scene submission counts staged vertices
  instead of reserved frame capacity, and the strict evidence marker is emitted
  only after the rendered main-menu capture checks pass.
- Rejected synthetic all-zero Kof distribution digests; prototype package smoke
  now uses the recorded verified pinned distribution identity.
- Hardened the simple WAN path: rendezvous now requires an explicit nonzero
  shared key, preserves existing two-player rooms, and has an authenticated
  direct-peer punchthrough smoke covering Linux/Windows-compatible UDP framing.

### Playable demo release readiness

- The latest public `0.1.0-dogfood.34` artifact remains a signed Linux x86-64
  presentation dogfood build from source commit
  `4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`; it predates the current source
  presentation/lobby/score path and no current Windows demo archive is public.
- The current source path now covers local `Play`, fixed two-player `Host/Join`,
  explicit readiness and the deterministic player screen. Remaining D1 work is
  clean-tree Linux/Windows presentation packaging, outside-checkout repeated
  play/restart/quit smoke, fresh-host verification and native hardware evidence.



### CI headless performance gate

- Made the dedicated-server P95 budget explicit and configurable through
  `KOOKIE_SERVER_P95_BUDGET_US`. Local and soak verification retain the
  4000-microsecond default; hosted CI uses an 8000-microsecond ceiling to
  absorb shared-runner scheduling noise without changing the recorded target.


## 2026-09-30

### Kof-first artifacts, sandbox and Windows compiler paths

- Added canonical bounded graph, behavior, scene hierarchy, skeleton and
  animation-graph products, including deterministic codecs, reopen validation,
  revisioned publication and GLB hierarchy/skin intake.
- Added offline artifact envelopes plus a bounded KofScript stack VM with static
  control-flow/stack/resource proof, explicit command/event capabilities and
  atomic authoritative-session application. The KofScript builder emits one
  artifact that the JVM and native Kof runtimes reopen and execute identically.
- Added a reproducible Windows JVM package with a SHA-256-pinned OpenJDK x64
  runtime, retained legal tree, canonical executable JAR and signed deterministic
  ZIP; the focused gate rebuilds and compares every signed artifact.
- Added a strict optimized-IR compiler bridge for a bounded top-level
  integral/String/control-flow subset. It emits deterministic C11, AMD64 COFF
  and console PE artifacts through pinned Zig, verifies semantic parity against
  the Kof JVM, and rejects unsupported classes, heap/arrays, exceptions, FFI
  and SDL IR with `PE001`. At this historical entry the native Windows
  gameplay path was not yet qualified; the 2026-10-01 entry above records the
  later bounded PE/SDL qualification.

### G6 bounded expansion paths

- Added scalar-copy native jobs with bounded worker count, strict ordinal
  publication and deterministic completion folding.
- Added package-bound KofScript descriptors/artifacts, staged activation that
  preserves the prior program on failure, and authoritative-session execution.
- Added persistent Kutter hierarchy/transforms/assets with canonical
  binary save/open and rollback on invalid files.
- Added a fixed-window WAN channel with bounded retransmission, deterministic
  loss/latency pressure, ordered delivery, replay rejection and backpressure.
- Added `scripts/verify_g6_runtime.sh` and focused probes for all four paths.
- Added a reproducible Windows SDL presentation package with SDL3/SDL_mixer,
  SPIR-V/DXIL, and pinned OpenJDK 27. Static package evidence is retained;
  the full isolated Wine gameplay qualification is recorded in the
  2026-10-01 entry above.


### GitHub project homepage and contributor surface

- Rebuilt the root README as a progressive project homepage with the supplied
  KOOKIE logo, five meaningful badges, quick routes, one architecture diagram,
  bounded feature/evidence tables and explicit limitations.
- Added a restrained 1280×640 social preview built from the supplied logo,
  moved detailed run/package commands into a paired guide, and added paired
  security reporting guidance.
- Added English and Brazilian Portuguese bug/proposal forms plus a concise
  bilingual pull-request template. Repository description, discovery topics
  and private vulnerability reporting complete the automatable GitHub surface;
  the source-controlled social preview is ready for GitHub's browser-only
  upload.

### Bounded PCM WAVE intake and packaged native kooker

- Added a strict RIFF/WAVE reader for mono/stereo PCM tag `0x0001`, 8- or
  16-bit samples at 8–96 kHz, bounded to 2 MiB, 32 chunks, 30 seconds and
  1 MiB of canonical PCM. It validates RIFF/chunk lengths, byte rate, block
  alignment and zero padding; strips bounded `JUNK`, `PAD ` and `LIST/INFO`;
  and rejects compressed, float, extensible, RF64, cue/loop and unknown
  semantics.
- Added reopened deterministic PCM16 output with source, normalized-sample,
  metadata and canonical checksums through `kooker cook wav`. Linux
  archives now include the native Kof kooker; package smoke checks
  canonicalization, idempotent reopen, malformed-input rejection and absence
  of graphics dependencies outside the checkout.
- Fixed the JVM developer launcher's lifecycle so its temporary module tree is
  removed after both successful and rejected commands instead of leaking under
  `/tmp`.
- Corrected default package-manifest URLs to the actual version-tagged GitHub
  release directory and reject non-HTTPS custom artifact directories.

### Bounded standalone PNG image intake

- Added a 1 MiB, 64-chunk, 256×256 standalone PNG reader for non-interlaced
  8-bit grayscale, truecolor, indexed, grayscale-alpha and RGBA images. It
  verifies every chunk CRC and zlib Adler checksum, joins consecutive `IDAT`
  chunks, reverses filters 0–4 and resolves `PLTE`/`tRNS` into exact RGBA.
- Added reopened deterministic RGBA8 PNG output with source, pixel, metadata
  and canonical checksums through `kooker cook png`. Validated `tEXt`
  is stripped; Adam7, APNG, other bit depths and other ancillary or unknown
  chunks reject instead of losing image semantics. Aseprite atlas output now
  uses the same canonical encoder.

### Bounded Blockbench character intake

- Added an independently implemented Blockbench `.bbmodel` 5.0 reader for
  cube-only characters with bounded UUID bone hierarchies and numeric
  position/rotation/scale clips. It caps source bytes, tokens, bones, cuboids,
  hierarchy depth, clips and keyframes; duplicate/unknown UUIDs, Molang,
  effects and unsupported interpolation reject deterministically.
- Added reopened little-endian `KCHR` v1 output with fixed-point cuboid,
  hierarchy and keyframe records plus source/character/bone/animation/product
  checksums. `kooker cook blockbench` writes the package-ready product;
  failed intake writes none. Texture pixels and per-face UV/material data are
  not part of this first `KCHR` contract.

### Kof Buffer SIMD integration

- Pinned CI and release builds to Kof 0.5.0-beta source commit
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`; the older same-version release
  archive predates native `Buffer(U8)` support. Package provenance now records
  the Kof source commit, distribution SHA-256 and compiler JAR SHA-256.
- Added checked unsigned-byte reductions to the AVX2, SSE2, NEON and scalar
  dispatch paths plus the bounded `kookie_simd_sum_u8_buffer` Kof FFI entry
  point. The C probe covers empty input and vector-tail boundaries through both
  selected and forced-scalar routes.
- Added a Kof-owned 1 MiB `Buffer(U8)` benchmark with JVM/native parity and a
  64-round route measurement. On the recorded Intel Arrow Lake-P host, native
  Kof scalar reduction took 233,350,224 ns and the AVX2 route took 1,073,834 ns
  (217.3x for this workload only).
- Linux native and presentation archives now include `kookie-simd-bench`, its
  graphics-independent dispatch library and package smoke coverage. This closes
  the ABI/representative-benchmark prerequisite, not production gameplay
  integration or a general engine-speed claim.

### Bounded G5 completion and release hardening

- Upgraded every release and CI gate to exact Kof `0.5.0-beta`, pinned the
  Linux x86-64 release archive SHA-256 to
  `f93f02eb62af584ea49ffb44efdbf54f970bdb9570f16fdc48ccc28242798ca9`,
  and migrated the source contracts exercised by both JVM and native builds.
- Added the complete bounded reference scene: 192 authored vertices,
  64 collision triangles, 64 active enemies, 256 moving projectiles,
  512 pickups, 24 dynamic lights and 64 effects. The server loads every
  authored triangle and retains per-tick AI/projectile/pickup work ceilings of
  16/64/128.
- Corrected the dedicated workload's omitted collision load, removed
  native-backend argument-spill hazards from projectile distance, segment and
  impact paths and changed its broad phase from root-only rejection to bounded
  traversal without per-query allocation.
- Replicated the complete reference state on every tick to two authenticated
  same-host client processes. Four-chunk client updates are transactional:
  inconsistent, replayed or whole-state-checksum-invalid input cannot partially
  replace the active view. Client B disconnects and resumes at generation 2.
- Replaced CPU-expanded scene drawing with one actual GPU-instanced triangle
  draw: 2,952 staged vertex attributes become 984 instances. The isolated
  hardware gate rendered 600 frames at 1920×1080 on Vulkan 26.2.3,
  `Intel(R) Graphics (ARL)`, at p50/p95/p99/max submission time of
  0.304/0.645/0.845/1.089 ms. The visually reviewed readback retained SHA-256
  `20b37c94927b04689071200346f1e98f3498ce6408697bae697535773f15f5d4`.
- The focused native simulation run recorded p50/p95/p99/max
  1.518/1.623/1.717/1.757 ms. A paced 30-minute run measured 108,000 ticks
  after 600 warm-up ticks at 2.489/3.202/3.721/23.645 ms, with a stable
  resource signature and 128 KiB RSS growth/range across 181 samples.
- Added staged, validated, file-fsync/rename/directory-fsync save publication
  with interrupted-write recovery; multi-step save migration; replay v3
  identity and whole-payload checksums; and rollback guards for save, replay
  and reconnect state.
- Release packaging now requires a clean source tree, exact Kof identity and an
  owner-private Ed25519 key. It signs the archive, provenance manifest and
  checksum set, embeds the public key, and records the source commit,
  toolchain/archive digest, durable-save and replay contracts.
- Independent adversarial upstream verification supplied on 2026-09-30 passed
  `Buffer(U8, INOUT)` plus token FFI on native x86-64 and supported cross paths
  at commits `b4c2b734a`, `381f6fab0` and `bf17ac7e7` (evidence
  `c73556f5a`). KOOKIE did not rerun that matrix; Script, JavaScript, Android,
  riscv32 and MCU remain `FFI001`, and no SIMD speedup is claimed.


## 2026-09-29

### Bounded G5 headless timing and scale transport

- Added `BoundedDedicatedServer`, a graphics-free fixed-step workload using the
  real enemy, projectile and world-loot modules. The declared baseline owns
  64 enemies, 256 moving projectiles and 512 pickups under rolling per-tick
  ceilings of 16 AI states, 64 projectile slots and 128 pickup slots.
- Removed repeated spatial-position scans from enemy/projectile hot paths and
  bypassed sweep-result allocation when the workload has no authored obstacles.
- Extracted authenticated UDP from the SDL adapter into
  `libkookie_headless_adapter.so`. The same graphics-independent library now
  supplies monotonic timing, RSS sampling, real-time pacing and configurable
  warm-up/measurement lengths to the packaged Linux server.
- Added bounded request/state messages, generation-aware admission and client
  views for the dedicated workload. A native focused gate runs one host and two
  client processes through compatibility admission, four workload checkpoints,
  disconnect and generation-2 reconnect.
- JVM and native match checksum `797255` and resource signature `675172` after
  256 ticks. On the recorded Linux workstation, a native 512-tick sample after
  128 warm-up ticks recorded p50/p95/p99/max
  1.186/1.245/1.269/2.195 ms and 64 KiB RSS growth/range. A 30-minute paced run
  then measured 108,000 ticks after 600 warm-up ticks at
  1.216/1.891/2.182/4.110 ms with 128 KiB RSS growth/range across 181 samples.
  This qualifies the collision-free headless subset, not the authored
  collision/render scene, multi-machine gameplay or 1080p frame timing.
- Linux packages contain the server binary and its headless adapter; package
  smoke checks telemetry outside the checkout and rejects graphics-linked
  server dependencies.

### Bounded G4 kutter pipeline completion

- Expanded trusted modules from the elite-death path to typed
  session-started, player-connected, enemy-defeated, loot-picked-up and
  kutter-published subscriptions. Static implementation/version pairs remain
  generation-bound, phase-ordered and capacity-budgeted.
- Added bounded offline intake for Dust3D projects plus validated textured GLB,
  raw/zlib 32-bit RGBA Aseprite files, MagicaVoxel models/palette/scene chunks
  and integer-grid convex Quake-style brushes. Canonical geometry, collision,
  PNG atlas, metadata, material, entity and visibility identities are produced
  deterministically; unsupported constructs fail with format diagnostics.
- Added `scripts/kooker.sh` with file `cook`, one-chunk `package`,
  `inspect-package` and `validate-package` commands.
- Added a little-endian `.kpkg` envelope and external loader with bounded
  logical paths, chunk ranges/hashes and extension/definition/hook records.
  Reload validates candidate state first; rejection preserves the active
  package, registries and generation.
- Added the Kutter screen and `BoundedKutterWorkspace` for revision-checked
  world/entity/weapon/loot mutations, collision/AI inspection, play-in-editor
  and bounded undo/redo. Geometry, collision, navigation and render identities
  publish as one transaction.
- Added coordinated Kof and SDL-adapter reload state machines. The adapter
  builds a separate candidate scene, waits for synchronous upload-fence
  completion before reusing the persistent GPU buffer, then activates at a
  frame boundary. Kof references gate retirement of the old generation.
- Added the compatibility control handshake to remote role transport. An
  18-word offer carries the exact 13-word identity; a 7-word response admits or
  rejects it with a diagnostic before snapshots or gameplay.
- All 84 focused source scenarios pass on JVM and native. The authenticated
  role probe also passed with the host and two clients in separate Linux
  network namespaces and distinct IPv4 stacks, including reconnect and the
  compatibility handshake. This is not evidence from three physical machines.
- The Kutter candidate-preservation and activation path also rendered through
  isolated headless SDL_GPU at 320×240. The final frame checksum was
  `28,585,778` (PPM SHA-256
  `c9c17e6de93dfd13ac04ee70896a2739be0ba5cf70c9c65b06e924b430064a6d`);
  visual review found no clipping, overlap or illegible labels. Isolated Xvfb
  could not qualify window presentation because it lacks DRI3, so this claim is
  limited to the actual offscreen GPU render/reload path.

### Persistent native game shell, menus and permissive packaging

- Replaced the Windows auto-closing color-matrix executable and embedded-JDK
  package with one persistent native `kookie.exe` using SDL3 and SDL_mixer.
  The resizable high-DPI window supports maximize, restore, windowed,
  borderless and exclusive-fullscreen transitions.
- Added an old-school pixel main menu, display/audio/text options transaction
  and a host/join/leave lobby with editable IPv4/port fields and explicit
  connection state. Keyboard and mouse navigation share the same actions.
- Added the equivalent persistent Kof game shell to the Linux SDL_GPU
  presentation while preserving the bounded G1 gameplay scene.
- Migrated native audio submission to separate SDL_mixer effects and music
  streams with independent volume controls.
- Licensed KOOKIE under MIT and restricted distributable source/runtime
  dependencies to permissive components. Packages now include MIT and
  third-party notices; Linux packages no longer bundle the dynamic loader or
  libc, and distributable JVM packages are rejected.
- The native Windows artifact now launches `kookie.exe`. Focused isolated Wine
  checks exercised main, options and multiplayer screens plus real resize,
  maximize and restore; package smoke loaded SDL 3.4.16 and SDL_mixer 3.2.4
  without opening a window.

### Generation-bound trusted-hook execution

- Trusted-hook declarations now bind a supported static implementation ID and
  binary version into the sealed module checksum. Missing implementations,
  unsupported versions and phase mismatches fail closed before publication.
- Added `BoundedTrustedHookRuntime`: a published generation and its exact
  extension/module checksums are bound before monotonic ticks execute hooks in
  deterministic phase order. Per-hook budgets and global command/event
  capacities are preflighted, so rejection leaves prior phase output intact.
- Added one-time authoritative application of bounded hook commands.
  Disconnected recipients, unsupported commands and currency overflow reject
  without partial mutation or command replay.
- The G4 two-player sample now executes the compiled elite-bounty hook after a
  confirmed enemy death. It emits a typed event and adds four currency through
  the authoritative session on top of the data-defined five-currency reward.
- Focused tests cover wrong implementation phase/version, budget and capacity
  rejection, mismatched published generations, monotonic ticks, overflow and
  exactly-once command application.
- All 78 source scenarios pass on JVM and native; Kof checks, lint and LSP pass.


### First G4 transactional kutter-publication slice

- Added `BoundedTrustedModuleRegistry` for at most 32 statically compiled hook
  declarations tied to manifest contributions, phase and command/event budgets.
  Dependency/load/priority order is deterministic and the sealed checksum binds
  the exact extension registry.
- Added revision-checked `BoundedKutterPublication` and a 13-word
  `BoundedContentCompatibility` wire identity covering engine/API/network,
  package, manifest, module, definition, generation and aligned
  geometry/collision/navigation/replication products. Stale, mismatched and
  invalid transactions leave the prior active generation intact.
- Added `G4KutterDemo`, a distinct public-API two-player encounter driven by a
  data-defined elite and trusted-module declaration. Deterministic death emits
  valid encounter, per-player authority and world-loot state.
- Extended the fixed HUD from 312 to 372 vertices, and the complete scene from
  426 to 486, with a source→validation→publication rail and shape-distinct
  success/failure marks. The boss crown is more compact and remains structurally
  distinct from the elite diamond.
- An isolated capture exposed native-only coordinate corruption in the former
  high-local-count kutter/threat staging methods. Small fixed-coordinate
  helpers now keep the publication cap, compatibility plus, elite diamond and
  boss crown exact; JVM/native assertions bind their structural vertices.
- All 77 source scenarios pass on JVM and native; Kof checks, lint and LSP pass.
- Isolated Wayland SDL_GPU presentation passes at 320×240 with present
  capability `11`, an 11,270 µs draw and frame checksum `30,358,034`. Visual
  review confirmed bounded panel contents, readable shape-distinct
  source/validation/publication/success and boss-crown cues, and no clipping or
  overlap in those panels.
- Qualified Linux presentation dogfood `0.1.0-dogfood.27` from
  `82bf57d69083` (SHA256
  `ad4a57ee4f92cf8da93d7d29b8002d95656327d35438c54f29a2b8e8d056abce`,
  4,281,751 bytes). Outside-checkout package smoke bound the exact version,
  build and archive. The extracted archive also exited `0` inside a reviewed
  isolated display with a nested compositor, reported capability `11`, drew
  in 9,087 µs and reproduced frame checksum `30,358,034`; its persisted
  capture was byte-identical to the source verification capture.


### G3 closure: bounded extensions, data-defined bosses and threat HUD

- Added `BoundedExtensionRegistry` with versioned manifests, declared
  dependencies/capabilities, namespaced contributions, deterministic
  load/priority resolution, immutable checksums and fail-closed diagnostics.
- Added complete sealed elite/boss definitions for combat, behavior,
  deterministic instance loot, progression and currency. Defined enemy
  admission preflights all actor/reward capacity and commits atomically.
- Migrated the G1 demo, G3 save/reload path and authenticated external
  JVM/native transport probe to instantiate those definitions rather than
  configuring elite/boss rewards per enemy.
- Extended the fixed HUD from 264 to 312 vertices, and the complete scene from
  378 to 426, with structural elite-diamond, boss-crown, count and defeat cues.
  The presentation derives those cues from authoritative enemy kind without
  per-frame capacity growth.
- All 75 source scenarios pass on JVM and native. Kof lint/LSP, authenticated
  same-host JVM/native transport and isolated Wayland SDL_GPU presentation
  pass. The 320×240 capture reported present capability `11`, drew in
  10,789 µs and produced checksum `30,593,757`; visual review found no clipping,
  panel overlap or ambiguous color-only threat state.
- Qualified Linux presentation dogfood `0.1.0-dogfood.26` from
  `2abfeb172b61` (SHA256
  `325c4f9cf82ff42ed6e72898012d6e56afdb09f75a078a99f033a0519f50d3ac`,
  4,232,726 bytes). Outside-checkout package smoke bound the exact version,
  build and archive. The archive also exited `0` inside a reviewed isolated
  display with a nested compositor, reported capability `11`, drew in
  5,104 µs and reproduced frame checksum `30,593,757`.

### G3 process replication and semantic HUD polish

- Extended the fixed semantic HUD from 174 to 264 vertices with bounded
  inventory fill/full, equipment, skill XP/rank and ranked world-loot status.
  Every state has structural shape feedback as well as color; inactive slots
  remain degenerate inside the fixed 378-vertex arena/door/HUD scene.
- The presentation demo now derives this panel from the real authoritative G3
  kill, rank-3 drop, skill and currency-reward path.
- Routed recipient player-authority kind `7` and world-loot kind `8` through
  authenticated same-host host-plus-two-client processes on JVM and native.
  The evidence validator proves item/equipment `900`, skill rank `1` and zero
  world drops after pickup; separate-host execution remains unproven.
- All 74 source scenarios pass on JVM and native. Kof lint/LSP, the focused
  interaction probe and JVM/native external-process transport regressions pass.
- Qualified Linux presentation dogfood `0.1.0-dogfood.25` from
  `a02c7c1edd58` (SHA256
  `15f74f040f02a6faadea161057f8b8184323b9b5ccf9b1c3fe10d8dbf0bbab6a`,
  4,207,580 bytes). Outside-checkout package smoke bound the exact version,
  build and archive. The presentation package also exited `0` inside a
  reviewed isolated display with a nested compositor, reported present
  capability `11`, drew in 83,543 µs and produced a validated 320×240 frame
  with checksum `29,772,824`; visual review found no clipping or HUD overlap.

### First authoritative G3 loot/progression vertical slice

- Connected the single alive→dead reward transition to deterministic complete
  item rolls, bounded world drops, remote pickup/equip/progression admission,
  equipment/status combat modifiers and atomic boss loot/XP/currency preflight.
  A full inventory retains the drop, currency and RNG identity.
- Added checksummed recipient-specific player-authority state kind `7` and
  world-loot state kind `8`. Clients receive full inventory rolls, equipment,
  skills, statuses and ranked 3D drops without authoring outcomes.
- Added save section 12 for world drops and loot/currency claim identities.
  `decodeG3Authority` restores player and runtime state atomically; re-resolving
  a saved boss death cannot duplicate rewards.
- Split newly touched wide native member calls for weapon definition, enemy
  admission, reward configuration and world-drop position into bounded calls
  or structured input after native forwarding corrupted trailing arguments.
- All 74 source scenarios pass on JVM and native. The focused interaction probe
  passes on both targets, and package smoke validates Linux native/JVM and
  presentation archives, checksums, provenance, runtime and the fail-closed
  Windows-native gate.
- Presentation packages now include a separate native `kookie-smoke.bin`;
  `kookie --package-smoke` selects it without opening a display. Deployment
  automation can validate packaged Kof/runtime dependencies headlessly, while
  normal launch still selects the isolated SDL_GPU presentation executable.
- G3 remains open for external-process transport of state kinds `7`/`8`,
  bounded public extension registries and complete data-driven elite/boss
  rules.

### Completed G2 LAN boomer-shooter slice

- Added continuous replicated hitscan, projectile and shotgun enemy roles.
  Enemies move, retarget the nearest live player and replicate role, target,
  health and integer 3D position in bounded `20 + 8N` encounter messages.
- Completed client movement prediction/reconciliation with ordered
  unacknowledged-input replay. Join now publishes recipient-specific tick-zero
  gameplay, feedback and encounter baselines; reconnect advances the
  connection generation and resets input, prediction and feedback epochs
  before sequence admission.
- Replaced scalar door planes with authored 3D segment/AABB volumes and
  36-vertex camera-projected cuboids. The fixed native scene is now 78 arena,
  36 door and 174 HUD vertices.
- Added ordered `6 + 11F` multiplayer feedback batches with whole-message
  validation, duplicate/gap rejection and generation-baseline recovery.
  Listener-relative attenuation and stereo panning are computed in Kof; the
  native SDL adapter queues allocation-free left/right PCM gains.
- All 73 source scenarios pass on JVM and native. The interaction probe,
  JVM/native host-plus-two-client process qualification and isolated headless
  SDL_GPU/audio adapter pass; the GPU capture included the 3D door and produced
  checksum `29,811,635`.

### Authoritative enemy encounter replication

- Added a checksummed encounter-state message of `20 + 8N` words for at most
  32 enemies, below the authenticated transport's 300-word bound. It carries
  encounter active/reserve counts, enemy ID/role/state/target/health/position
  and the latest confirmed impact; clients reject malformed or stale state.
- Remote fire now resolves against the real enemy combat/encounter authority
  instead of a dummy player-combat actor. Terminal damage releases the
  encounter slot, grants the server-owned 25-currency reward and replicates
  enemy state `7`, health `0` and impact sequence `2`.
- Host responses now send player/progression state plus encounter state to both
  authenticated clients. Client admission updates bounded presentation/audio
  queues without allowing presentation backpressure to roll back state.
- Polished the fixed 174-vertex HUD with a shape-distinct connection glyph and
  active/reserve encounter track. Connection and reserve status change geometry
  as well as color; the full scene remains within 252 vertices.
- All 73 source scenarios pass on JVM/native; the interaction probe and local
  JVM/native host-plus-two-client process regressions also pass. The LAN
  evidence validator requires terminal encounter/state/health and
  confirmed-impact markers.
- Qualified Linux presentation dogfood `0.1.0-dogfood.23` from
  `d89a16461e6d` (SHA256
  `43250c6763d9ef98d81e9ed3541a1c335139636e8852cbe2501a008cd5b30d7c`,
  3,808,495 bytes). The archive exited `0` inside a reviewed isolated display
  with a nested Wayland compositor, reported present capability `11`, drew in
  23,844 µs and produced a validated 320×240 frame with checksum `29,309,607`.

### Confirmed combat feedback slice

- Connected accepted authoritative hitscan and single-target shotgun results to
  one monotonic, bounded impact presentation/audio queue. Presentation
  backpressure never rolls back authoritative damage and exposes a drop count;
  confirmed events also enter the bounded replay presentation history.
- Extended the semantic HUD with structural hit and kill markers plus
  full-height edge damage warnings. Feedback expires by simulation tick,
  duplicate event sequences reject, and inactive geometry remains degenerate
  inside the fixed allocation. HUD staging is now 174 vertices and the complete
  authored scene is 252, below the existing 256-vertex native bound.
- Routed `G1Demo`'s real authoritative kill through the HUD and native
  presentation probe. SDL audio now receives that event's clip `201` at gain
  `100` instead of an unrelated sample clip.
- Qualified Linux presentation dogfood `0.1.0-dogfood.22` from
  `82ccdd5` (SHA256
  `3fa7b256ccec83104c33799dd2ac723381135f60ab6aecc5551d013c0280a474`,
  3,802,863 bytes). The archive exited `0` inside a reviewed isolated display
  with a nested Wayland compositor, reported present capability `11`, drew in
  8,399 µs and produced a validated 320×240 frame with checksum `29,150,337`.

### Semantic HUD and visual dogfood

- Replaced three unlabeled numeric bars with bounded dark status panels:
  framed health and ammunition tracks, structural health/round icons,
  encounter pips and a focus-responsive crosshair. Critical and unfocused
  states change geometry as well as color.
- Expanded the persistent SDL_GPU scene budget from 128 to 256 vertices and
  replaced the four-color debug texture with a 16-color semantic world/HUD
  palette. The authored scene now stages 78 world plus 138 HUD vertices.
- Added a Linux `presentation` package runtime containing the native Kof
  arena/HUD executable, SDL adapter, SPIR-V shaders and resolved runtime
  libraries. The relocatable launcher anchors asset loading to its package.
- Added observable HUD-state regression coverage. All 72 source tests pass on
  JVM and native; native, JVM and presentation archive/checksum/provenance
  package smokes pass.
- The packaged presentation ran inside a reviewed isolated display with a
  nested compositor, reported present capability `11`, rendered in 11,257 µs,
  captured a validated 320×240 frame and exited cleanly. Machine-specific
  evidence remains outside the repository.

## 2026-09-28
### Current qualification batch

- Replaced the narrow interaction wire with one bounded checksummed gameplay
  protocol for movement, fire, interaction, disconnect and reconnect. The
  authoritative state now carries both player positions, combat health,
  currency, progression mask and lifecycle generation/reason/diagnostic.
- Added exact server-tick admission for remote fire/movement/interactions and a
  server-owned terminal hitscan currency reward. JVM/native host-plus-two-client
  processes now prove movement, death plus 25 currency, revision-4 progression,
  reconnect generation two and explicit stale-command diagnosis.
- Closed the G1 authoritative-shooter gate with one executable scenario on JVM
  and native: a 60 Hz server admits two loopback clients, exposes a four-unit
  prediction correction and reconciliation, resolves one player weapon/enemy
  kill, and proves focus loss cannot leave movement or fire queued.
- Added an authored 78-vertex/26-triangle true-3D arena with a walkable ramp,
  two stair steps and stacked lower/upper rooms. Broad-phase snapshots now carry
  explicit bounds with the triangle revision/data, so the client queries the
  same upper and lower floors.
- Added fixed-capacity camera/world/HUD staging and a persistent native SDL_GPU
  scene vertex/upload path. An isolated GPU probe rendered 78 arena plus 18
  numeric HUD vertices, read back a 320×240 P6 frame and preserved staging
  capacities across 64 deterministic frames.
- Removed the contact controller's per-sweep allocation. Expanded replay
  sidecar storage to 1,296 words so the 32-triangle arena state and bounded
  presentation history remain atomic; the previously failing replay bundle now
  passes.
- JVM and native checks pass, the focused G1 runtime marker is identical on
  both targets, and all 71 tests pass on each target.

- The isolated presentation gate validated real window presentation, input,
  audio, GPU draw, screenshot capture and clean exit without touching an active
  desktop.
- The authenticated external-LAN gate validated two independent clients,
  authentication, monotonic transport sequences, clean exits and distinct
  machine identities. Operational host details and evidence remain outside the
  repository.
- `bash scripts/verify.sh` passed on commit `bd5c6d1`: lint, LSP, JVM/native
  checks, 70/70 tests on each target, runtime smoke, package smoke and both
  compiler builds. The optional adapter run was safely deferred once by the
  isolated-display PSI pressure gate.
- `KOOKIE_EXTERNAL_LAN_MODE=processes` passed the authenticated host plus two
  client processes locally, including reconnect and stale-frame rejection;
  all three roles exited `0`. The evidence correctly remains
  `externalHostExecution=unproven` because all identities are on one machine.
- Built and extracted-smoke-tested native Linux `0.1.0-dogfood.20`
  (`bd5c6d1`, SHA256
  `e7a121899948740ef059f9f25d5eac5d3be77c45009c127e0739cfbc88fc961f`,
  2426844 bytes), JVM Linux `0.1.0-dogfood.jvm.20` (SHA256
  `714da5e311d6939e1a52e81c4c5d8ba1fa5623cddaadeac8b93e6caa492d169a`,
  433882 bytes), and the external-LAN role archive (SHA256
  `3b6bb75cc360fa75e67d4f6cba54c0326b4fdf65b5106616f06a07d70d4c516b`,
  1088335 bytes).
- Earlier presentation attempts failed closed when the isolated environment
  could not provide the required presentation capability. Machine-specific
  diagnostics remain outside the repository.
- Deployment compatibility and package smoke were validated without retaining
  endpoint names, addresses, service details or deployment identifiers here.

- Added target-aware local process qualification: `KOOKIE_EXTERNAL_LAN_TARGET=jvm`
  now builds and runs three direct Kof JVM roles through
  `scripts/verify_external_lan.sh`, records the same identity/exit metadata,
  and validates the same evidence contract as the native path. The default
  remains `native`; same-host evidence remains unproven for external-host DoD.

- Focused target-aware LAN regressions passed in native process mode, JVM
  process mode and JVM single-process mode. Each run exited `0` with
  authenticated gameplay, reconnect, stale-frame rejection and evidence
  validation; process modes remain same-host evidence only.

### Cross-target external LAN transport

- Split the G0 transport probe into a target-neutral Kof contract with native
  UDP and a direct Kof JVM UDP backend through JDK `java.net` APIs. Both
  share authenticated framing, key handling, replay and sequence rejection.
- `scripts/verify_external_lan_role.sh` now builds either `native` or `jvm`
  roles. `scripts/package_external_lan_roles.sh` emits Windows host/client JVM
  JARs and `.cmd` launchers without embedding the run key or manifest.
- Mixed native-host/JVM-client and JVM-host/native-client two-client smokes
  pass locally. Separate-machine evidence is validated privately and remains
  outside the repository; native Windows PE support remains outside G0.


## 2026-09-26
### Two-client transport qualification

- Added a native two-slot authenticated UDP probe that exchanges broad-phase
  snapshots between two loopback clients, replays a duplicate datagram to prove
  stale-frame rejection, closes both sockets, reopens them on fresh ports, and
  verifies the post-reconnect sequence.
- Fixed single-client reconnect qualification to restore the transport key after
  close; `kookie_transport_close` intentionally clears key state.
- External host/LAN qualification and DRI3 screenshot proof remain open.
- Extended native UDP qualification to four authenticated slots, wildcard
  remote-client binding, explicit host-listener binding and local-port
  inspection. The adapter probe now includes an external-style host plus
  two-client path; external-host execution remains open.
- Added `scripts/verify_presentation.sh` and a strict P6/JSON evidence
  validator. The presentation gate now fails closed unless a real GPU window,
  positive present capability, screenshot and adapter completion markers exist.
- Expanded external-style LAN qualification through the production
  `LoopbackSession` path: server-owned combat damage, key/door/secret/exit
  progression, stale-input rejection, client reconnect and two-client
  authenticated transport evidence.
- `scripts/verify_external_lan.sh` now emits host-identity JSON evidence and
  labels the same-host topology without claiming separate-host execution.
- Added role-aware multi-process qualification: `KOOKIE_EXTERNAL_LAN_MODE=processes`
  launches host/client-A/client-B as separate native processes, while
  `scripts/verify_external_lan_role.sh` runs one role with a configurable host
  IPv4 and receive timeout for a separate-host qualification run.
- LAN evidence JSON now requires an authentication marker, positive host
  receive sequences for both clients and role-specific zero exit statuses;
  combined role logs preserve host/client identity markers for later
  separate-host validation.
- Added `scripts/collect_external_lan_evidence.sh` to combine the three
  separate-host role logs and invoke strict `separate-hosts` validation without
  losing per-role identity or exit-status markers.
- Separate-host role logs now include hashed machine identity, transport-key
  fingerprint, target host IPv4 and exit status. The validator requires
  matching key fingerprints and three distinct machine fingerprints before
  marking external-host execution as proven.
- Added a shared external-LAN run manifest. Role logs carry one run ID, and
  separate-host collection requires the manifest, matching key fingerprint and
  matching role set before producing proven evidence.
- The external collector now emits a self-contained evidence tarball with
  manifest, role logs, combined log, JSON evidence and `SHA256SUMS`.
- Added a standalone bundle verifier that rechecks archive checksums,
  manifest/evidence hashes and the proven external-host gate fields without
  requiring the raw transport key.
- Presentation success evidence now records the isolation wrapper, adapter-log
  hash and GPU marker values alongside the existing screenshot evidence.
- `scripts/verify_presentation.sh` now rejects offscreen/no-render-node
  configurations before running the expensive verification path.
- Presentation blocker artifacts now include DRM render-node inventory and
  display variables, making missing-capability triage reproducible.
- Presentation qualification now preserves the adapter log and emits a
  machine-readable blocker artifact with DRI3/runtime diagnostics when the
  host cannot satisfy the gate; blocked runs remain failures.

### G0 definition of done

- Defined finite completion criteria: runtime integration, focused success and
  rejection coverage on JVM/native, lint, documentation, clean generated state
  and a committed change.
- Defined the two remaining G0 release gates: isolated DRI3 presentation proof
  and authenticated external-host two-client LAN proof. Additional importers,
  expanded physics, future save migrations and production services are
  explicitly deferred to separately scoped milestones.

### Content package schema

- Added a bounded `src/content` package validator with engine/tool/content
  identity, coordinate/unit metadata, sorted namespaced assets and
  dependencies, bounded chunk ranges, deterministic identity checksums,
  canonical integer-wire encoding, decode validation, and tamper rejection.
- This batch covers schema admission only; source importers, cooked
  geometry/navigation products, signatures, and atomic publication remain open.

### Kof-owned authored collision

- Added bounded indexed authored collision geometry in `src/core`, including
  coordinate/unit metadata, source and geometry revision identity, surface
  kinds, deterministic checksums, sealing/validation, and replacement into the
  authoritative BVH triangle collection.
- JVM/native coverage proves indexed admission, nearest-hit queries,
  replacement identity, stale-geometry removal, and bounded rejection.

### Collision package admission

- Added a deterministic indexed collision wire codec and package admission
  contract. Admission requires matching namespaced asset identity, geometry
  revision, chunk kind, checksum, and triangle count.
- Tampered collision wire data and mismatched package identities are rejected
  on JVM and native targets.

### GLB, publication, and physics contracts

- Added bounded canonical GLB intake with glTF/GLB magic/version validation,
  deterministic indexed geometry encoding, exact reopen validation, and
  collision-product emission.
- Added bounded standard glTF 2.0 JSON/BIN intake for buffers, bufferViews,
  accessors, indexed mesh primitives, float POSITION data and uint16/uint32
  indices. Admission validates chunk lengths, accessor bounds, interleaved
  strides and triangle mode, and emits source/tool/options provenance receipts
  plus canonical runtime-reopen data.
- Added atomic geometry/collision/navigation/replication publication admission
  to a bounded generation cache. Referenced generations survive replacement;
  inactive unreferenced generations retire at explicit frame boundaries.
- Added sampled triangle capsule contact with slope/ground/step policy,
  expanded dynamic AABB narrow-phase sweeps, static/dynamic projectile sweeps,
  and authoritative enemy-session navigation-product routing.
- Added a bounded GLB kooker that admits package/collision identity,
  encodes canonical collision data, derives deterministic triangle-centroid
  navigation, and atomically publishes geometry, collision, navigation and
  replication generations.
- JVM/native coverage now passes 70 tests. External host/LAN qualification
  and DRI3 screenshot proof remain open.

### Qualification release

- Built `0.1.0-dogfood.18` in local release staging with a native Linux archive
  and a Windows JVM visual-qualification archive, each with SHA256SUMS and
  immutable provenance.
- Linux archives now ship a statically linked launcher plus the bundled
  dynamic loader and libraries, avoiding dependence on the receiver's host
  loader paths.
- Local archive checks and launcher smoke pass. Operational deployment records
  are intentionally not retained in this repository.

### Qualification release

- Ran the focused interaction, lint/LSP, and package smoke gates successfully.
- Built deployable release `0.1.0-dogfood.14`: Linux native and Windows JVM
  visual-qualification archives with SHA256SUMS and immutable provenance
  metadata.
- Removed older generated KOOKIE release directories and temporary package
  artifacts. DRI3 screenshot proof and authenticated two-client LAN proof
  remain open qualification gates.

## 2026-09-25

### Qualification batch

- Replaced the scoped local dogfood archives with fresh Linux native
  `0.1.0-dogfood.11` and Windows JVM `0.1.0-dogfood.jvm.11` packages.
- Revalidated the interaction probe and package smoke gate before rebuilding;
  each archive has target-specific SHA256SUMS and project-owned provenance
  metadata.
- Windows remains a JVM qualification package, not native Kof/PE support.
- Fixed remote broad-phase pump sequencing to use the caller's monotonic tick;
  reconnect now resumes at sequence 9 in the native transport probe instead of
  silently restarting at the next local counter.

## 2026-09-26

### Deployment qualification

- Qualified Linux native and Windows JVM dogfood packages with exact archive
  SHA-256 and byte-size provenance. Operational endpoints and deployment
  identities are intentionally not recorded here. Windows remains a JVM
  qualification package, not native Kof/PE support.
- Added the Windows SDL visual qualification launcher and deployed
  `0.1.0-dogfood.jvm.15` from build `aa407f2`; the Windows shortcut now opens
  `kookie-visual.exe` instead of the console-only JVM launcher.

## 2026-09-24

### What moved forward

- Added bounded consumed-command interaction replay, reserved capture slots and v2 replay files with genuine v1 reads. Playback re-simulates up to 4096 ticks from a full checkpoint, with an explicit movement player and interactions from either player.
- Added level progression save section 11/version 1 with stable IDs and level/content-version checks. Schema file v2 uses actual envelope sizes and independent checksums; configured capacities, one-copy recovery, repair and v1 compatibility are preserved.
- Fixed uninitialized inventory/triangle checkpoint padding, preserved held input across seeks, and captured movement at its actual consumed tick. Replay now forwards complete input records; native fire bits and repeated presentation sequences are verified.
- Connected authored door activation to authoritative scalar movement blocking and client-facing `FrameStaging` geometry. Closed doors block crossing their X plane; opened doors stop blocking. The 3D arena collision contract remains unfinished.
- Added bounded loopback client disconnect/reconnect lifecycle. Reconnect preserves authoritative position and input sequence watermarks, clears pending input and rejects stale commands; the real authenticated LAN proof remains separate.
- Added remote-session reconnect sequencing. Broad-phase send/receive watermarks survive close/reopen, the authenticated native UDP probe resumes at sequence 9, and older snapshots remain rejected. Two-client LAN proof is still a separate gate.
- Added reproducible Linux x86-64 dogfood archives for native Kof and executable-JAR JVM runtimes, with provenance, SHA256SUMS and extracted-binary smoke. Windows packaging still fails closed until Kof exposes a real PE target and signing/runtime proof.
- Fixed Ubuntu CI's AArch64 SIMD check selecting x86 host libc headers. Clang now uses its own freestanding C11 headers; the cross-target check remains mandatory and does not claim AArch64 linking or execution.
- Added cooperative key/door/secret/exit progression, bounded tick commands, client state and file-backed checkpoint restore. Pause/focus loss cancels pending interactions; duplicate requests cannot award a secret twice.
- Fixed catch-up inputs and weapon cooldowns using the final frame tick instead of the actual simulation tick.
- Fixed overlapping spatial replay rows that overwrote an actor's Z coordinate and left native memory in the payload. Spatial state is now version 2; corrupted version-1 layouts are rejected, not guessed at.
- Added deterministic integer ray targeting with nearest-hit selection, stable-ID tie breaks, spread offsets, bounded target storage, source exclusion through `SpatialAimContract`, and safe rejection of invalid queries.
- Connected the shared aim contract to authoritative player shotgun combat without hiding a second damage authority. `LoopbackSession.resolvePlayerSpatialShotgun` derives weapon offsets, selects one target per pellet, and resolves the result through `CombatWorld.resolveShotgunPelletTargets`.
- Added bounded miss handling, target removal, and player/enemy session wrappers so selected pellet targets travel through the normal combat/event path.
- Added JVM/native coverage for center rays, offset pellets, source exclusion, spread-specific damage, target removal, ordered pellet events, repeated target IDs, and wrong-length selections.
- Added production-safe native SIMD dispatch with AVX2/SSE2 selection on x86, NEON source coverage on AArch64, and a checked scalar fallback. The host path, scalar path, and AArch64 source path are verified.
- Kept the important limits visible: Kof bulk-buffer FFI is still blocked by `FFI001`, so the SIMD kernel is not presented as an engine speedup.
- Refreshed the active roadmap in English and Brazilian Portuguese instead of quietly letting status drift.

### Checks

- CI repair: host SIMD, forced scalar, AArch64 syntax, workflow validation and the JVM/native interaction probe passed locally.
- Latest batch: 18 focused scenarios passed on JVM and native through `scripts/verify_interactions.sh`; 20 affected existing regressions passed on each target.
- Catch-up and two-actor spatial replay reproductions failed before their fixes and passed afterward.
- Poisoned checkpoint buffers and held-fire checkpoint seek failed before their fixes and passed afterward.
- Earlier combat batch: 63/63 tests on each target, plus SIMD host/scalar/AArch64 checks. That full suite was not rerun locally for this batch.

### Still not done

- Crash-durable saves still need atomic replacement plus filesystem flush/sync primitives.
- Kof needs bulk-buffer FFI before native SIMD can serve Kof-owned hot loops.
- Window presentation still needs an isolated host with usable DRI3 support.
- Production multiplayer, content cooking, production audio, and the full physics stack remain roadmap work.
- Native Windows compilation, relocatable runtime packaging and license notices remain release prerequisites. No release package or deployment was claimed.

## Earlier work

- Built the bounded G0/G1 session, fixed-step, snapshot, collision, replay, save, inventory, progression, enemy, projectile, and SDL-adapter foundations.
- Added authenticated localhost UDP transport probes, headless SDL_GPU recovery checks, replay presentation capture, and deterministic combat/event contracts.
