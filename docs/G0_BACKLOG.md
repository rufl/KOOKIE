# G0 implementation backlog

[Português (Brasil)](../pt-BR/docs/G0_BACKLOG.md)

This is the active bounded implementation sequence after the initial research and contract commits.

## Completed

- Modular `core`/`session` Kof source and scalar SDL3 probe.
- Bilingual documentation and push verification gate.
- Checked Kof-owned resource tokens with slot, generation and kind validation.
- JVM/native regression smoke and three named regression tests.
- Scalar `SDL_Init(0)`/`SDL_Quit()` lifecycle exercised on JVM/native.
- Kof-owned focus/resize/close state and bounded FIFO audio queue.
- Narrow C SDL adapter with checked window/audio/GPU tokens and scalar event flattening.
- Bounded PCM silence and deterministic clip transfer into an SDL audio stream without callbacks.
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
- Isolated offscreen SDL_GPU device and SPIR-V indexed quad draw accepted with explicit vertex/index-buffer uploads and per-device cached GPU resources; the latest smoke measured 1675 microseconds for three draws against the declared 16,667-microsecond frame budget on `renderD128`, with a 527-microsecond fence-wait sample.
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
- The authorized isolated native smoke now executes through the SDL adapter: authenticated session transport, headless GPU recovery and audio pass; window presentation logs `No DRI3 support detected`, so the capability-gated screenshot path remains unexecuted. This host exposes `/dev/dri/renderD128` and `/dev/dri/renderD129`, but the Xvfb-backed isolated display cannot provide DRI3.
- The DRI3 runtime boundary is recorded in both language trees: the transport smoke is executable, while window presentation still requires an isolated present-capable host.
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
- Bounded inventory/equipment and broad-phase geometry replay codecs now round-trip state with JVM/native coverage; integrating these codecs into the loopback checkpoint payload remains next. Replay checkpoints retain 320 bounded snapshot values and restore enemy combat, AI, spatial and projectile state while clearing transient impact presentation/audio queues.

## Next batch

1. Run the DRI3-capable window screenshot path on an isolated present-capable host; the isolated X11/offscreen smoke was exercised again and correctly reported `gpu-unavailable`, while Xvfb remains presentation-incompatible.


## Deferred

- Full physics, content cooking, save schema and production multiplayer transport.
- Production audio, image/text services, package compression and foreign physics/UI libraries.


Do not replace a blocked native capability with JVM fallback, a hidden C engine, a fake-success stub or an unverified graphics scaffold.
