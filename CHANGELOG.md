# Changelog

This file records meaningful changes to KOOKIE in plain language. It is not a promise that a milestone is finished; the roadmap and focused checks are the source of truth.

## 2026-09-29
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
- Built and deployed Linux presentation dogfood `0.1.0-dogfood.23` from
  `d89a16461e6d` to the local ztash catalog (SHA256
  `43250c6763d9ef98d81e9ed3541a1c335139636e8852cbe2501a008cd5b30d7c`,
  3,808,495 bytes). The exact archive exited `0` inside
  `overzeer-isolated-display` plus a nested Wayland compositor, reported
  present capability `11`, drew in 23,844 µs and produced a validated 320×240
  frame with checksum `29,309,607`.

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
- Built and deployed Linux presentation dogfood `0.1.0-dogfood.22` from
  `82ccdd5` to the local ztash catalog (SHA256
  `3fa7b256ccec83104c33799dd2ac723381135f60ab6aecc5551d013c0280a474`,
  3,802,863 bytes). The exact archive exited `0` inside
  `overzeer-isolated-display` plus a nested Wayland compositor, reported
  present capability `11`, drew in 8,399 µs and produced a validated 320×240
  frame with checksum `29,150,337`.

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
- The packaged presentation ran inside `overzeer-isolated-display` with a
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
- Added a bounded GLB cooker that admits package/collision identity,
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
