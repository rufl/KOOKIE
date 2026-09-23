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

## Next batch

1. Run the DRI3-capable window screenshot path on an isolated present-capable host; Xvfb remains presentation-incompatible.
2. Integrate authoritative enemy decisions into the fixed-step `LoopbackSession` tick and replicated snapshots.


## Deferred

- Full physics, weapons, enemies, content cooking, save schema and multiplayer transport.
- Production audio, image/text services, package compression and foreign physics/UI libraries.


Do not replace a blocked native capability with JVM fallback, a hidden C engine, a fake-success stub or an unverified graphics scaffold.
