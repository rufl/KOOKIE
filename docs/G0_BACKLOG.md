# G0 implementation backlog

[Português (Brasil)](../pt-BR/docs/G0_BACKLOG.md)

This is the active bounded implementation sequence after the initial research and contract commits.

## Completed

- Modular `core`/`session` Kof source and scalar SDL3 probe.
- Bilingual documentation and push verification gate.
- Checked Kof-owned resource tokens with slot, generation and kind validation.
- Focused JVM/native regression smoke and named behavioral contracts.
- Scalar `SDL_Init(0)`/`SDL_Quit()` lifecycle exercised on JVM/native.
- Kof-owned focus/resize/close state and bounded FIFO audio queue.
- Narrow C SDL adapter with checked window/audio/GPU tokens and scalar event flattening.
- Bounded PCM silence and deterministic clip transfer into an SDL_mixer effects stream without callbacks into Kof.
- Native adapter probe applying real adapter events to Kof state and running the first SPIR-V texture upload/draw path.
- Bounded Kof frame staging contract measured at 15 scalar writes for a three-vertex textured triangle, with publish/discard ownership checks.
- Native exception lifetime reproducer and negative controls recorded in the verification gate.
- Native adapter exposes elapsed GPU draw timing after GPU-idle retirement.
- G1 fixed-step clock, bounded input commands with fire/jump edge transitions, loopback server/client snapshot sync, and bounded integer component storage.
- G1 two-client loopback admission, per-client input sequencing, stale snapshot rejection, bounded authoritative movement, and camera/input clamping.
- Isolated native smoke accepted hidden-window lifecycle, resize/focus flattening, dummy audio, stale-token teardown, and clean process cleanup; GPU reported unavailable for window presentation.
- Bounded client snapshot history with integer interpolation and explicit prediction/reconciliation authority boundaries.
- Bounded scalar collision queries with clamped movement resolution and out-of-bounds placement rejection.
- Bounded prediction input history (capacity eight) with replay across authoritative reconciliation; server state remains authoritative.
- Bounded integer 3D segment sweep queries through an axis-aligned volume, rejecting starting penetration and over-budget traversal.
- Bounded integer triangle queries with degenerate-triangle rejection and previous-sample resolution.
- Bounded capsule center movement with radius-expanded bounds and shared player/projectile/line-of-sight admission.
- Isolated offscreen SDL_GPU device and SPIR-V indexed quad draw accepted with explicit vertex/index-buffer uploads and per-device cached GPU resources; the smoke stayed within the declared 16,667-microsecond frame budget.
- Fixed-step clock exposes the declared 60 Hz frame budget to GPU acceptance checks.
- Frame staging accepts a six-vertex textured quad within a bounded 30-scalar-write budget.
- Bounded triangle collections use a fixed-capacity deterministic binary BVH with nearest-hit selection, removal/rebuild, geometry revisions, and traversal diagnostics.
- Bounded capsule movement returns authoritative slide/step results over an eight-slot collection of deterministically ordered step obstacles, with clear/reconfigure operations.
- Authoritative sessions own the bounded broad-phase triangle collection, hand off its geometry revision with query snapshots, reject stale collection queries, expose a bounded integer payload contract, and apply payloads into a client collection with sequence guards.
- Bounded broad-phase transport queues copy validated payloads into fixed packet storage, reject overflow without dropping queued data, and drive client replication through dequeue/apply.
- Spatial movement admission combines capsule bounds with broad-phase triangle queries and rejects stale geometry revisions.
- Isolated GPU overlap smoke submits four frames across two target slots, retires all fences, and reports peak in-flight depth.
- Headless GPU recovery smoke destroys and recreates the device, rebuilds cached resources, and completes a post-recovery draw.
- Bounded native UDP peer transport sends and receives authenticated integer broad-phase frames across paired localhost datagram sockets; explicit non-zero SipHash key provisioning is required before open, `kookie_transport_set_key_from_environment` accepts the 32-hex-character `KOOKIE_TRANSPORT_KEY_HEX` boundary, `kookie_transport_set_key_from_file` loads exactly 32 hex characters only from a regular mode-0600-or-stricter `KOOKIE_TRANSPORT_KEY_FILE`, `kookie_transport_rotate_key_from_file` reprovisions the closed transport, `kookie_transport_open_remote_ipv4` atomically binds a local socket to a validated IPv4 peer/port, and framing covers protocol version, payload length, sequence and signed payload words with a fixed 1,000 ms receive timeout and packet bounds.
- `RemoteSessionLink` now gates broad-phase snapshots on endpoint activation and monotonic send/receive sequences; the native probe binds, sends and applies a session snapshot through that link.
- `LoopbackSession` now owns remote endpoint configuration, activation, snapshot send gating, monotonic receive validation and disconnect; the native probe drives three authenticated broad-phase ticks through that authoritative session handoff.
- GPU recovery state exposes unavailable/ready/lost/failed states and a state-aware capability bitmask: ready supports clean reopen plus reset/loss events, while lost retains reopen only; it rejects recovery without a live headless device and rebuilds resources after recovery.
- SDL render-device reset/lost events now flow through the event pump, retire cached GPU resources safely for reset or lost-device paths, and drive headless recovery without the former explicit loss marker; the native probe exercises reset rebuild and loss recovery.
- The authorized isolated native smoke executes through the SDL adapter:
  authenticated session transport, headless GPU recovery and audio pass.
- The integrated presentation gate runs `scripts/verify_presentation.sh`
  through a reviewed wrapper configured by
  `KOOKIE_PRESENTATION_ISOLATION_WRAPPER`. Evidence records resize/focus input,
  GPU draw, audio, screenshot capture and clean exit without recording the
  operational host in this repository.
- When a presentable window is available, `KOOKIE_SCREENSHOT_PATH` exports the captured swapchain frame as a binary PPM; the path remains capability-gated and unset by default.
- `CombatWorld` now provides bounded authoritative weapon definitions, magazine/reserve reload state, cooldown-gated atomic shots, armor-aware damage, critical hits, and exactly one alive-to-dead transition per actor; JVM/native tests cover ammo atomicity and damage/death invariants.
- `CombatWorld` now resolves bounded hitscan and projectile shots through the same weapon/range/damage authority, consumes projectile slots deterministically, and publishes sequenced hit/death events without silently dropping critical events; JVM/native tests cover range rejection, ammo atomicity, projectile retirement, and event order.
- `EnemyStateWorld` now implements deterministic idle/patrol/investigate/chase/attack/recover/stagger/dead transitions with integer perception and attack deadlines; `EncounterDirector` enforces bounded active counts and spawn budgets, with JVM/native tests for cooldown, terminal death, and admission overflow.
- `AuthoritativeEnemySession` now binds enemy state, combat actors, encounter budgets and sequenced combat events; enemy attacks resolve through authoritative hitscan, while consumed death events transition enemies to terminal state and release encounter slots. JVM/native tests cover attack decisions, non-death consumption, death bridging, and deterministic respawn budget.
- `LoopbackSession` now owns bounded enemy perception inputs, steps configured enemy decisions inside the fixed-step tick, consumes combat events, and publishes monotonic enemy snapshots with client admission; JVM/native tests cover attack decisions and replicated state.
- `EnemySpatialWorld` now provides bounded positions, deterministic BVH-backed line-of-sight queries, movement resolved at the last free sample, and spatial gating for enemy/projectile attacks in the authoritative tick; JVM/native tests cover clear paths, obstacles, blocked movement and projectile damage.
- The authoritative enemy session now advances bounded projectiles across fixed ticks with obstacle sweeps, terminal target resolution, deterministic blocking and projectile retirement; encounter directors now support bounded spawn zones and positioned admission, with JVM/native coverage through direct and loopback ticks.
- `EnemyNavigator` now provides bounded deterministic four-neighbor A* over the authoritative obstacle collection, with fixed node/route budgets, stable tie ordering and explicit no-route results; spatial enemy steering advances through the selected waypoint and JVM/native tests cover detour selection.
- Spatial projectiles now publish bounded terminal impact events for hit, obstacle block and expiry/cancellation, preserving projectile/source/target IDs, impact position and applied damage; JVM/native tests cover the authoritative hit event.
- `LoopbackSession` now stages replicated enemy impact snapshots into bounded render presentation and audio queues with deterministic hit/block/expiry clip mappings; duplicate snapshots are rejected and JVM/native tests cover identity, ordering and audio consumption.
- Player fire edges now drive a bounded authoritative weapon presentation queue with accepted-shot state, ammo transitions and held-fire suppression; the isolated native SDL adapter consumes confirmed impact clips 201/202/203 through its audio bridge.
- `BoundedSaveState` now validates a version-1, revision-bounded integer payload, exposes deterministic envelope checksums, rejects capacity/value corruption, and supports in-memory restore; `BoundedSaveHistory` publishes strictly increasing revisions with bounded deterministic eviction and restore; `BoundedSaveWireCodec` frames validated envelopes into bounded integer words and rejects header, length, version and checksum corruption; `BoundedSaveFileStore` persists the bounded wire through the measured `File.writeBytes`/`readRange` APIs using signed-byte-safe base-64 digits and rejects malformed/corrupted records; `BoundedRedundantSaveFileStore` and `BoundedSaveSchemaFileStore` write two bounded copies, recover one corrupted copy and expose repair operation; schema persistence now covers progression v1, item v1, quest v1, world v2, RNG v2 and currency v1, with typed bounded item ownership/quantity, quest state/progress and atomic item/currency transactions; interrupted-write recovery, flush/sync, atomic replacement and directory durability remain deferred.
- Item definitions now validate bounded level ranges/base values/affix pools; deterministic loot tables select weighted definitions and deterministic rarity/affix/condition rolls, and accepted stable item rolls can enter bounded inventory transactions with JVM/native coverage.
- Rolled-item v1 save sections now persist stable ID, definition, seed, level, rarity, affixes and condition alongside inventory ownership/quantity and currency; JVM/native coverage rejects malformed roll records, verifies round-trip preservation, and loads older inventories with an empty roll section.
- `BoundedEquipmentLoadout` now validates owned stable items, enforces unique bounded slot assignment, supports equip/unequip transactions and persists equipment v1 slot ownership; JVM/native coverage verifies round-trip restoration and invalid assignment rejection.
- `BoundedAffixStatStore` and `BoundedItemStatComposer` now apply bounded flat/additive/multiplicative stat composition, while `BoundedCraftRecipe` and `BoundedCraftingSystem` validate and commit ingredient/currency consumption into rolled outputs; crafted inventory, roll and currency state persists through the existing save sections with JVM/native coverage.
- `BoundedItemReservation` now stages multiple item/currency requirements and rejects stale commits through inventory revisions; bounded skill definitions/progression and status definitions/effects support learn/rank/experience, duration refresh, capped stacks and deterministic ticking, with skill v1/status v1 save sections and JVM/native round-trip coverage.
- `LoopbackSession` now owns authoritative per-player skill learning/experience and status application/ticking, and exposes progression v1 save encode/decode through the expanded bounded section envelope; JVM/native coverage verifies fixed-step expiry and round-trip restoration.
- Skill definitions now enforce bounded prerequisites and activation metadata; player skill activation consumes bounded resources and enforces deterministic cooldowns. Statuses now provide bounded flat/percentage defense modifiers, and authoritative combat applies them after armor; JVM/native coverage verifies prerequisite gating, activation rejection/expiry and defensive status mitigation.
- Combat now validates four bounded damage channels, applies channel resistance before armor and status defense, and routes post-mitigation damage through bounded shields before health; player and enemy loopback APIs expose shield/resistance state with JVM/native coverage.
- Statuses now apply bounded per-tick damage before expiry, and area damage resolves validated target batches through the same resistance/armor/shield/health path with ordered combat events; JVM/native coverage verifies fixed-step DoT, area mitigation, event order and duplicate-target rejection.
- Weapon definitions now support deterministic bounded shotgun pellet counts, spread falloff and bounded target lists; one shell publishes ordered pellet combat events through the shared resistance/armor/shield/health path. JVM/native coverage verifies pellet damage, ammo atomicity, target distribution and event order.
- Focus loss now clears pending player commands, emits held-button release edges, blocks new input while unfocused, and rearms cleanly on focus regain; JVM/native coverage prevents stale firing.
- Pause now resets fixed-step wall-clock debt, disarms pending player commands, blocks simulation/input while paused, and resumes without catch-up spikes; JVM/native coverage fixes the documented pause contract.
- `InputReplayRecorder` now records validated resulting tick commands (not raw platform events) in a bounded FIFO, preserves deterministic order, rejects stale/duplicate/invalid commands, and replays or resets without unbounded growth; `LoopbackSession` captures consumed commands only when explicitly enabled and resets the bounded capture on disable; `BoundedReplayWireCodec` and `BoundedReplayFileStore` persist bounded engine/content metadata, seed, signed tick commands, ordered checkpoints, hash diagnostics and initial snapshots with corruption rejection; replay checkpoints carry bounded state snapshots, and `LoopbackSession.encodeReplayCheckpoint`/`applyReplayCheckpoint` restore tick, movement, prediction, snapshot, player combat, skill resources/cooldowns, statuses, enemy combat actors, AI state, spatial positions, encounter budgets and encounter links before staging commands.
- `BoundedAffixPoolStore` now provides weighted deterministic selection of non-contiguous content affix IDs for item rolls; JVM/native coverage verifies stable seeded selection.
- Save write durability still requires a proven atomic replacement plus flush/sync filesystem primitive; current bounded redundant/schema stores validate, recover one bad copy and repair it, but do not claim crash-durable publication.
- Player weapon and replicated enemy impact/audio presentation events now enter replay history automatically and round-trip through checkpoint sidecars; JVM/native coverage verifies the path. The isolated DRI3 screenshot gate now passes; crash-durable save publication remains deferred and is not a G0 release gate.
- DXPERF-051 now has a production-safe native dispatch mechanism: runtime AVX2/SSE2 selection on x86, NEON source coverage on AArch64, checked scalar fallback, thread-safe initialization, host/scalar execution proof and AArch64 cross-target syntax proof. Bulk Kof integration remains blocked by the existing `FFI001` array/buffer boundary; no speedup is claimed.
- `BoundedRayTargetWorld` now provides bounded integer ray and shotgun-pellet target selection with nearest-hit ordering, stable-ID ties, spread offsets, source exclusion through `SpatialAimContract`, target removal and invalid-input rejection; JVM/native coverage proves center and offset pellet hits.
- `CombatWorld.resolveShotgunPelletTargets` and player/enemy session wrappers now accept exactly one validated target per pellet, preserve repeated target IDs when multiple pellets hit the same actor, allow bounded misses, and publish ordered combat events; JVM/native coverage proves target order and rejects wrong-length selections.
- `LoopbackSession.resolvePlayerSpatialShotgun` now builds one shared `SpatialAimContract`, derives weapon pellet offsets from the authoritative combat state, selects spatial targets, and resolves the selected IDs through the authoritative per-pellet combat path; JVM/native coverage proves spread-specific damage, source exclusion, target removal and target health.
- `BoundedInteractionWorld` and `LoopbackSession` now implement cooperative one-shot key/door/secret/exit progression with sealed bounded definitions, server-position reach checks, per-player sequence/tick admission, focus/pause cancellation, deterministic simultaneous requests and client activation snapshots. Checkpoint bundles preserve definitions, activations, pending requests and sequence watermarks.
- Fixed actual-tick catch-up scheduling and spatial checkpoint row overlap. Seven focused JVM/native scenarios and 14 affected existing tests per target pass. Spatial replay v2 rejects unrecoverable v1 row layouts.
- Interaction replay now records up to 64 consumed commands, reserves capacity before admission, persists them in v2 bundles and re-simulates from full checkpoints. Movement uses consumed ticks; held input and presentation sequence survive repeated seeks.
- Level progression now uses section 11/version 1 with level/content identity and exact stable-ID matching. Save files use bounded, checksummed v2 copies; genuine v1 files remain readable and repair upgrades them. Sixteen focused scenarios and 20 affected existing regressions pass on each target.
- Fixed native checkpoint serialization of unused inventory roll fields and triangle rows; poisoned-buffer regressions prevent stale memory from entering replay files.
- Door integration now uses authored 3D center/half-extents for authoritative segment/AABB blocking. Open doors stop blocking; closed doors stage a camera-projected 36-vertex cuboid through `FrameStaging`, including paths above and beside the volume.
- The external transport qualification has a target-neutral Kof contract with
  native UDP and direct JVM/JDK `java.net` backends. Both use the authenticated
  framing, key, replay and sequence contract. Separate-host qualification later
  passed with two independently identified clients; operational identities and
  raw evidence remain outside the repository.
- The Kof JVM boundary was measured directly with JDK
  `DatagramSocket`, `DatagramPacket` and `InetAddress` imports and runtime
  send/receive. The same imports remain rejected on the native target, so
  this backend is intentionally JVM-only; see `docs/KOF_LANGUAGE.md`.
- Reproducible Linux x86-64 archives support native Kof and the persistent SDL
  presentation. Windows x86-64 now ships a native SDL3 + SDL_mixer shell with
  a resizable/maximizable window, menu/options/lobby and no embedded JDK.
  Kof-authored Windows gameplay remains blocked because the compiler exposes no
  PE target. JVM host/client role archives remain qualification tooling, not
  distributable KOOKIE runtimes. Product packages include MIT/zlib notices and
  reject unreviewed distributed runtime libraries.
- Added the first bounded content package schema under `src/content`: versioned engine/tool/content identities, coordinate/unit metadata, sorted namespaced asset and dependency IDs, bounded chunk ranges, product masks, deterministic package checksums, canonical integer-wire encoding, decode validation and tamper rejection. JVM/native coverage adds the 64th passing scenario. Full source importers beyond the bounded GLB path remain open.
- Added Kof-owned authored collision representation in `src/core`: bounded indexed vertices and triangles, coordinate/unit metadata, stable source/revision identity, surface kinds, deterministic checksums, sealing/validation, and atomic replacement into the authoritative BVH collection. Collision admission and nearest-hit queries are covered on JVM/native.
- Collision package admission now binds a sealed indexed collision codec to the package's namespaced asset, geometry revision, chunk kind, checksum and triangle count; JVM/native coverage rejects tampered wire data and mismatched package identities.
- Added bounded external GLB JSON/BIN intake under `src/content`: standard glTF 2.0 asset/buffer/bufferView/accessor/mesh primitive parsing, float POSITION and uint16/uint32 index decoding, stride/length/mode validation, source/tool/options provenance receipts, canonical integer-wire reopen validation and collision-product emission.
- Added atomic geometry/collision/navigation/replication publication admission to a bounded generation cache; referenced generations survive replacement and unreferenced inactive generations retire at explicit frame boundaries.
- Added Kof-owned sampled triangle capsule contact with slope/ground/step policy, expanded dynamic AABB narrow-phase sweeps, projectile static/dynamic sweeps and authoritative enemy-session navigation-product routing. JVM/native coverage now passes 70 tests.
- Added bounded GLB cooking under `src/content`: package/collision admission, canonical collision encoding, deterministic triangle-centroid navigation products, and atomic geometry/collision/navigation/replication generation publication. JVM/native coverage exercises the end-to-end cook.
- Extended native UDP transport to four authenticated slots, wildcard-bound
  remote clients, explicit host listener binding and local-port inspection.
  `scripts/verify_external_lan.sh` passes an authenticated host plus two client
  sockets, bidirectional broad-phase snapshots and stale-datagram rejection;
  its local process topology remains regression coverage, not external proof.
- The external-style qualification drives the production `LoopbackSession`
  path through server-owned combat damage, key/door/secret/exit progression,
  stale-input rejection, client reconnect and two-client transport evidence.
  Local runs remain explicitly unproven; the retained separate-machine bundle
  below is the qualifying evidence.
- `KOOKIE_EXTERNAL_LAN_MODE=processes` now builds and launches the host,
  client-A and client-B roles as separate native processes. The
  `scripts/verify_external_lan_role.sh` runner exposes the same role path for
  a host or client on another machine, with `KOOKIE_EXTERNAL_LAN_TARGET=native`
  or `jvm`, `KOOKIE_EXTERNAL_LAN_HOST_IPV4`, shared key material and an
  extended receive-timeout override.
- The local multi-process verifier now accepts `KOOKIE_EXTERNAL_LAN_TARGET=native`
  or `jvm`. JVM mode builds and launches three direct Kof JVM roles and uses
  the same role metadata and evidence validator as native mode; this expands
  local cross-target regression coverage without claiming separate-host proof.
- Raised the shared authenticated UDP payload bound to 300 words (32 arena
  triangles) and kept native/JVM transport capacities synchronized. The
  three-process regression now exchanges the complete 26-triangle `G1Arena`
  in both directions and proves stacked-room collision after receipt.
- Replaced the interaction-only wire with unified, versioned checksummed
  movement, fire, interaction, disconnect and reconnect commands plus
  authoritative state for both player positions, combat health, currency,
  progression masks and connection generation/reason/diagnostic. Admitted
  fire, movement and interactions advance exact server ticks.
- JVM/native three-process role runs now prove client-issued movement,
  authoritative enemy hitscan death plus 25 currency, terminal encounter state
  and health, latest confirmed feedback, revision-4 key/door/secret/exit
  completion, disconnect/reconnect generation two and explicit stale-generation
  diagnosis. Host responses send recipient-specific 20-word gameplay state,
  ordered `6 + 11F` feedback batches and a checksummed `20 + 8N` encounter
  message containing role and 3D position for at most 32 enemies.
- Combined source and interaction qualifications close G2's continuous
  hitscan/projectile/shotgun roles, prediction/reconciliation, generation-safe
  join/recovery, 3D door volume, feedback recovery and Kof-to-SDL stereo
  spatialization contracts. The local role run is not WAN evidence and does not
  replace the separate-host release gate.


- `scripts/package_external_lan_roles.sh` builds Windows JVM host/client
  archives without embedding the raw key or run manifest. Its `.cmd`
  launchers select a packaged or installed Java runtime and append role
  identity, key fingerprint, run ID and exit status to the evidence log.
- Native and JVM roles may be mixed for protocol qualification, but these
  local mixed-target smokes do not satisfy separate-host identity evidence.
- External LAN JSON evidence now records authentication status, positive
  per-client host receive sequences, role-specific process exit statuses and
  host/client identities. The validator rejects missing sequence, auth or
  exit-status markers instead of treating gameplay markers alone as proof.
- Separate-host role logs now append role identity, a hashed machine
  fingerprint, the transport-key fingerprint and the configured host IPv4.
  `separate-hosts` validation requires all three roles, matching key
  fingerprints and three distinct machine fingerprints before marking external
  execution as proven; same-host process evidence remains unproven.
- Separate-host qualification passed with two independently identified clients,
  matching authentication material, positive transport sequences and clean
  process exits. Operational host names, addresses, fingerprints, run IDs and
  raw evidence remain outside the repository.
- A shared run manifest now binds the run ID, three roles, listener ports,
  source revision and transport-key fingerprint. Separate-host collection
  requires the manifest and rejects mixed-run evidence.
- `scripts/verify_presentation.sh` writes machine-readable local evidence and
  preserves its adapter log when presentation cannot be proven. Generated
  evidence is operational data and must not be committed.
- The fail-closed validator accepts only a real window with positive present
  capability, draw-time marker, valid P6 screenshot and clean exit.

1. With `KOOKIE_TRANSPORT_KEY_HEX` set, create one shared run manifest with
   the transport key on the operator host:
   `python3 scripts/create_external_lan_run_manifest.py /tmp/kookie-lan-run.json`.
   Copy that manifest to all three hosts and export the printed
   `KOOKIE_EXTERNAL_LAN_RUN_ID` plus `KOOKIE_EXTERNAL_LAN_RUN_MANIFEST` on
   each host. Start one host with listeners 47101 and 47102, run client-A and
   client-B from separate hosts with the same key and host IPv4, then run
   `scripts/collect_external_lan_evidence.sh host/probe.log
   client-a/probe.log client-b/probe.log evidence.json` with the manifest
   variable set. Native roles use `KOOKIE_EXTERNAL_LAN_TARGET=native`; JVM
   roles use `KOOKIE_EXTERNAL_LAN_TARGET=jvm` through the role runner or
   `scripts/package_external_lan_roles.sh` and its Windows `.cmd` launchers.
   Native and JVM roles share the wire contract, but each role log must retain
   identity, machine-fingerprint, key-fingerprint, run-ID and exit markers.
   The collector rejects missing, mixed or same-machine manifests; same-host
   process mode proves orchestration only.
   The collector also writes a self-contained `external-lan-evidence.tar.gz`
   containing the manifest, all role logs, combined log, evidence JSON and
   `SHA256SUMS`.

   Reviewers can run `python3
   scripts/verify_external_lan_evidence_bundle.py evidence-bundle.tar.gz` to
   recheck archive checksums, manifest/evidence hashes and the proven gate
   fields without access to the raw transport key.

## Definition of done and release exit

This backlog uses a finite evidence contract. “Implemented”, “mostly done” and
passing a JVM-only probe are not completion states.

### Work-item completion contract

Every implementation item is done only when all of these are true:

1. The supported input, output, limits, identity/revision rules and rejection
   behavior are written in the owning source contract.
2. The real runtime path consumes the product; a detached fixture, mock,
   fallback, no-op or source-text assertion does not qualify.
3. At least one focused behavior scenario proves the success path and each
   plausible corruption, overflow, stale-generation or unsupported-input path.
4. The scenario passes on both JVM and native targets. A known compiler/runtime
   warning may remain only when the documented safe fallback is exercised and
   the scenario still passes.
5. The backlog records the exact source boundary, scenario name/count and
   external artifact required for any host capability.
6. The change is linted, committed, and leaves no generated repository files or
   test temporary files.

### Current release exit gates

The current G0 release is closed: the existing completed contracts remain green
and both numbered evidence gates are present.

1. **DRI3 isolated presentation — passed**: on an isolated present-capable host,
   native Kof opens a real window, draws the qualification scene, handles resize
   and focus input, plays the queued audio clip, captures a screenshot, and
   closes cleanly. The evidence records host, OS, GPU/driver, display isolation
   wrapper, command, exit status and artifact path. `gpu-unavailable` or
   Xvfb/offscreen output is a failure, not a substitute.
2. **External authenticated LAN — passed**: a separate-host run used one host
   and two independently identified clients. The production session path
   admitted both authenticated clients, reached
   fight→key/door→secret→exit progression, proved server-owned damage,
   reconnected, rejected stale input, advanced both receive sequences and
   exited all three roles cleanly. Local bundle verification binds the run
   manifest, source revision, three logs, matching key fingerprint and three
   distinct machine fingerprints; localhost-only and same-machine evidence
   still does not qualify.

The completed bounded contracts already mapped to this definition are:

- package schema, collision admission, external GLB JSON/BIN intake, provenance
  and canonical reopen;
- bounded GLB cooking into collision/navigation products;
- atomic four-product publication and generation retirement;
- triangle capsule contact, dynamic narrow phase, projectile sweeps and
  authoritative session navigation routing.
- bounded authoritative enemy encounter state/impact replication and terminal
  reward evidence across the host-plus-two-client process path.

These contracts are complete because JVM/native behavior coverage currently
passes 72 scenarios and both external evidence gates pass. No G0 release
blocker remains.

### Explicit non-goals for this release

The following are not silently open-ended G0 work. They are deferred release
scope and require a separately numbered milestone with its own acceptance
matrix before implementation starts:

- **Additional source importers**: each selected format needs a bounded fixture,
  size/count/unsupported-feature rejection, provenance, canonical package
  output and JVM/native coverage. “Support all authoring formats” is not a
  definition of done.
- **Physics expansion**: completion means a named authored 3D arena proves
  slopes, stairs, stacked rooms, dynamic bodies and projectile contacts under
  declared budgets. A larger solver without that scenario is not complete.
- **Save evolution**: each future section/version needs a migration fixture,
  malformed/newer-version rejection, old-save preservation and JVM/native
  coverage. Unbounded forward compatibility is not promised.
- **Production multiplayer transport**: completion is the external two-client
  gate above plus declared disconnect, reconnect, stale-input and capacity
  limits. More transport features are not implied.
- **Production audio/image/text services, compression and foreign physics/UI
  libraries**: out of scope; no implementation work is required for G0.

The external authenticated LAN gate has passed, so this backlog is closed for
G0. New work must open a new milestone rather than extending “Next batch”
indefinitely.

## Release qualification

The roadmap is not complete; completed work remains recorded here rather than archiving the active backlog.

- Installed `kof info --json` reports 0.4.9-beta on Linux x86-64. Its native
  assembler emits Linux ELF; the native Windows SDL shell does not change that
  compiler limit.
- Release archives cover native Linux and the native Windows SDL3 + SDL_mixer
  platform shell. Authoritative Kof gameplay on Windows remains unproven.
- Operational deployment records and cross-host evidence are intentionally
  retained outside this repository.



## Deferred

- Full physics beyond the bounded contact/narrow-phase slice, source importers beyond bounded GLB, future save-schema transforms and production multiplayer transport.
- Production audio, image/text services, package compression and foreign physics/UI libraries.


Do not replace a blocked native capability with JVM fallback, a hidden C engine, a fake-success stub or an unverified graphics scaffold.
