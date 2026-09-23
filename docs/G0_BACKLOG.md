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
- Isolated offscreen SDL_GPU device and SPIR-V indexed quad draw accepted with explicit vertex/index-buffer uploads; the latest smoke measured 1089 microseconds for three draws against the declared 16,667-microsecond frame budget on `renderD129`.
- Fixed-step clock exposes the declared 60 Hz frame budget to GPU acceptance checks.
- Frame staging accepts a six-vertex textured quad within a bounded 30-scalar-write budget.
- Bounded triangle collections use a fixed-capacity deterministic binary BVH with nearest-hit selection, removal/rebuild, geometry revisions, and traversal diagnostics.
- Bounded capsule movement now returns authoritative slide/step results, including successful traversal over a configured bounded step obstacle.
- Authoritative loopback rejects query snapshots carrying stale broad-phase geometry revisions.

## Next batch

1. Add a DRI3-capable isolated presentation path for window screenshots; Xvfb remains presentation-incompatible.
2. Re-run the native exception-handler reproducer after a compiler upgrade; require stale output change before trusting exception cleanup.
3. Add broad-phase collection handoff from the authoritative session instead of the revision-only contract.
4. Extend capsule obstacles beyond one bounded step prism and add multiple-obstacle ordering.
5. Add GPU resource reuse across frames; current smoke recreates buffers, pipeline, and texture per draw.
6. Record each new measured failure or acceptance boundary in both language trees.

## Deferred

- Full physics, weapons, enemies, content cooking, save schema and multiplayer transport.
- Production audio, image/text services, package compression and foreign physics/UI libraries.


Do not replace a blocked native capability with JVM fallback, a hidden C engine, a fake-success stub or an unverified graphics scaffold.
