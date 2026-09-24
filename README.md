# KOOKIE
[Português (Brasil)](pt-BR/README.md)

KOOKIE is an experimental 3D shooter engine built around Kof. It is for
boomer-shooter, looter-shooter and ARPG-FPS experiments—not a finished game.
The doors have prerequisites. The network has prerequisites. Calling this finished has paperwork.

## The honest status

The useful foundation is running and tested on JVM and native Linux x86-64:

- authoritative fixed-step sessions and snapshots;
- bounded movement, collision, BVH and spatial projectile queries;
- deterministic combat, including per-pellet shotgun targeting;
- cooperative key, door, secret and exit progression, command replay and versioned level saves;
- saves, replays, inventory, equipment, skills and status effects;
- a small SDL3/SDL_GPU adapter and authenticated localhost transport probes.

The important gaps are still real:

- window presentation needs an isolated host with DRI3 support;
- Kof bulk-buffer FFI is blocked by `FFI001`, so the native SIMD kernel is not
  wired into Kof-owned hot loops;
- crash-durable saves, production multiplayer, content cooking, full physics,
  production audio and a complete creator pipeline are not finished.

If a claim is not backed by a focused test or probe, it is not presented as
done.

## Try it

Install `kof` and Python 3. Run the focused gameplay/replay probe:

```bash
bash scripts/verify_interactions.sh
```

The full gate is for final pre-commit verification (in Pi, after `/precommit-matrix`):

```bash
bash scripts/verify.sh
```

Graphical checks must use the repository's isolated-display wrapper. Offscreen
SDL checks are useful for lifecycle and GPU-resource tests; they do not prove
that a real window can present. Set `KOOKIE_SDL_VIDEO_DRIVER=x11` only on a
host that can provide isolated presentation. Set
`KOOKIE_SCREENSHOT_PATH=/absolute/path.ppm` to keep a captured frame.

## What we are building

Engine, game and tool CPU behavior stays in `.kf`. Native code is limited to
small adapters, ABI boundaries, shaders and bootstrap glue. There is no hidden
replacement engine in C, Java, Rust or Zig.

The first supported native target is Linux x86-64. JVM is a comparison target,
not a substitute for native behavior. SDL3 + SDL_GPU is the graphics boundary,
initially with Vulkan/SPIR-V.

## Roadmap

Next: qualify isolated window presentation and prove the two-client LAN session with reconnect.
Closed authored doors now block the scalar authoritative path and client geometry reflects activation; a playable 3D arena is still not done.

Deferred until the core gates are stronger:

- full physics and content cooking;
- production save schema and multiplayer transport;
- production audio/image/text services;
- package compression and foreign physics/UI libraries.

## Documentation

- [Project memory](MEMORY.md): decisions, caveats and the next action.
- [G0 backlog](docs/G0_BACKLOG.md): completed work, active work and deferred
  scope.
- [Engine plan](docs/ENGINE_PLAN.md): architecture and milestone gates.
- [Kof language notes](docs/KOF_LANGUAGE.md): syntax, targets, FFI and runtime
  boundaries.
- [Executed probes](docs/RESEARCH_PROBES.md): commands, results and proof
  limits.
- [Changelog](CHANGELOG.md): recent project history.

The [Portuguese documentation](pt-BR/docs/) mirrors the English documentation.

## Working rules

Prefer a small executable contract over a large untested scaffold. Keep
changes bounded, deterministic and reversible. Do not hide a native blocker
behind a JVM fallback or claim a graphical capability that was not exercised
on a capable host.

## License and provenance

Research notes record the compiler versions, upstream links, pinned SHAs and
proof limits. Sibling repositories were inspected read-only; no source or
asset license was changed here. See [CONTRIBUTING.md](CONTRIBUTING.md) before
adding dependencies or changing the verification boundary.
