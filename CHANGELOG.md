# Changelog

This file records meaningful changes to KOOKIE in plain language. It is not a promise that a milestone is finished; the roadmap and focused checks are the source of truth.

## 2026-09-24

### What moved forward

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

- Latest batch: seven focused scenarios passed on JVM and native through `scripts/verify_interactions.sh`; 14 affected existing regressions passed on each target. Changed-source lint/LSP passed.
- Catch-up and two-actor spatial replay reproductions failed before their fixes and passed afterward.
- Earlier combat batch: 63/63 tests on each target, plus SIMD host/scalar/AArch64 checks. That full suite was not rerun for this batch.

### Still not done

- Crash-durable saves still need atomic replacement plus filesystem flush/sync primitives.
- Kof needs bulk-buffer FFI before native SIMD can serve Kof-owned hot loops.
- Window presentation still needs an isolated host with usable DRI3 support.
- Production multiplayer, content cooking, production audio, and the full physics stack remain roadmap work.
- Native Windows compilation, relocatable runtime packaging, license notices and KOOKIE registration in OVERZEER remain release prerequisites. No release package or deployment was claimed.

## Earlier work

- Built the bounded G0/G1 session, fixed-step, snapshot, collision, replay, save, inventory, progression, enemy, projectile, and SDL-adapter foundations.
- Added authenticated localhost UDP transport probes, headless SDL_GPU recovery checks, replay presentation capture, and deterministic combat/event contracts.
