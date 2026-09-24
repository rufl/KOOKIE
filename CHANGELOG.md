# Changelog

This file records meaningful changes to KOOKIE in plain language. It is not a promise that a milestone is finished; the roadmap and focused checks are the source of truth.

## 2026-09-24

### What moved forward

- Added bounded consumed-command interaction replay, reserved capture slots and v2 replay files with genuine v1 reads. Playback re-simulates up to 4096 ticks from a full checkpoint, with an explicit movement player and interactions from either player.
- Added level progression save section 11/version 1 with stable IDs and level/content-version checks. Schema file v2 uses actual envelope sizes and independent checksums; configured capacities, one-copy recovery, repair and v1 compatibility are preserved.
- Fixed uninitialized inventory/triangle checkpoint padding, preserved held input across seeks, and captured movement at its actual consumed tick. Replay now forwards complete input records; native fire bits and repeated presentation sequences are verified.
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
- Latest batch: 16 focused scenarios passed on JVM and native through `scripts/verify_interactions.sh`; 20 affected existing regressions passed on each target.
- Catch-up and two-actor spatial replay reproductions failed before their fixes and passed afterward.
- Poisoned checkpoint buffers and held-fire checkpoint seek failed before their fixes and passed afterward.
- Earlier combat batch: 63/63 tests on each target, plus SIMD host/scalar/AArch64 checks. That full suite was not rerun locally for this batch.

### Still not done

- Crash-durable saves still need atomic replacement plus filesystem flush/sync primitives.
- Kof needs bulk-buffer FFI before native SIMD can serve Kof-owned hot loops.
- Window presentation still needs an isolated host with usable DRI3 support.
- Production multiplayer, content cooking, production audio, and the full physics stack remain roadmap work.
- Native Windows compilation, relocatable runtime packaging, license notices and KOOKIE registration in OVERZEER remain release prerequisites. No release package or deployment was claimed.

## Earlier work

- Built the bounded G0/G1 session, fixed-step, snapshot, collision, replay, save, inventory, progression, enemy, projectile, and SDL-adapter foundations.
- Added authenticated localhost UDP transport probes, headless SDL_GPU recovery checks, replay presentation capture, and deterministic combat/event contracts.
