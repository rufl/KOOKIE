# KOOKIE
[Português (Brasil)](pt-BR/README.md)

KOOKIE is an experimental 3D shooter engine built around Kof. It is for
boomer-shooter, looter-shooter and ARPG-FPS experiments—not a finished game.
The doors have prerequisites. The network has prerequisites. Calling this finished has paperwork.

## The honest status

G0 and G1 run on JVM and native Linux x86-64:

- authoritative 60 Hz loopback server/client sessions, two-client admission,
  snapshots and observable prediction/reconciliation;
- bounded movement, capsule contact, triangle BVH and spatial projectile queries;
- deterministic combat with one integrated player/enemy path, bounded
  per-pellet shotgun targeting, and authoritative encounter snapshots carrying
  up to 32 enemy states plus the latest confirmed impact into client HUD/audio;
- an authored 78-vertex/26-triangle arena with a walkable slope, steps and
  stacked rooms, replicated with explicit broad-phase bounds;
- camera, bounded world staging and a semantic combat HUD with framed
  health/ammo indicators, a connection glyph, active/reserve encounter load,
  a focus-responsive crosshair, hit/kill markers and edge damage warnings;
  SDL_GPU uploads the fixed 288-vertex arena/door/HUD scene without per-frame
  buffer growth;
- cooperative key, 3D door, secret and exit progression, command replay and
  versioned level saves;
- saves, replays, inventory, equipment, skills and status effects;
- a small SDL3/SDL_GPU adapter; JVM and native three-process transport
  regressions carry the complete 26-triangle arena, unified checksummed
  movement/fire/interaction/lifecycle commands, recipient-specific gameplay
  baselines, ordered multiplayer feedback and bounded authoritative encounter
  state;
- continuous hitscan/projectile/shotgun enemy roles, client movement
  prediction with unacknowledged-input replay, generation-safe reconnect
  recovery, full 3D door collision/render geometry and feedback batch
  gap/duplicate recovery;
- listener-relative distance attenuation and stereo panning computed in Kof,
  with allocation-free left/right PCM submission through the native SDL audio
  adapter.

The important gaps are still real:

- Kof bulk-buffer FFI is blocked by `FFI001`, so the native SIMD kernel is not
  wired into Kof-owned hot loops;
- crash-durable saves, content cooking, full physics, streamed/compressed
  audio and HRTF/EFX, sustained G5 soak/performance proof and the creator
  pipeline are unfinished.

If a claim is not backed by a focused test or probe, it is not presented as
done.

## Try it

Install `kof` and Python 3. Run the G1 end-to-end scenario:

```bash
kof run src/main.kf --target native
```

Run the focused gameplay/replay probe:

```bash
bash scripts/verify_interactions.sh
```

Build an internal Linux dogfood archive:

```bash
KOOKIE_VERSION=0.1.0-dogfood.1 scripts/package_kookie.sh
```

The builder emits a target-bound `.tar.gz`, `SHA256SUMS` and provenance JSON.
For Linux-only JVM differential qualification, use the executable-JAR
fallback:

```bash
KOOKIE_RUNTIME=jvm KOOKIE_VERSION=0.1.0-dogfood.jvm.1 \
scripts/package_kookie.sh
```

Build the native Linux SDL_GPU presentation package used for isolated visual
qualification and ztash dogfood deployment:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.presentation.1 \
scripts/package_kookie.sh
```

It contains the Kof arena/combat-HUD executable, SDL adapter, SPIR-V shaders
and resolved Linux runtime libraries. Confirmed authoritative impacts drive the
same bounded HUD marker and synthesized SDL clip exercised by the probe. It is
a qualification surface, not a finished interactive game.

The Windows JVM archive contains the Kof executable JAR, an embedded Windows
JDK, a PE launcher, SDL3, and `kookie-visual.exe`. The installed shortcut
targets `kookie-visual.exe`, which opens the SDL visual qualification window;
`kookie.exe` remains the console/runtime smoke launcher.

Windows native Kof packaging still fails closed until the Kof compiler can
produce a real Windows target. The visual package exercises the SDL/window
boundary and is not proof of native Kof execution.

For the authenticated G0 LAN qualification, build the Windows JVM role
archive separately:

```bash
scripts/package_external_lan_roles.sh \
  --version 0.1.0-external-lan.1 \
  --build-id "${KOOKIE_BUILD_ID:-local}" \
  --output release/external-lan
```

The archive contains host/client JARs and Windows `.cmd` launchers, but no
transport key or run manifest. The authenticated JVM transport is implemented
directly in Kof through the JDK `java.net` UDP APIs; Java is used only for
launcher evidence metadata. JVM and native roles share the authenticated UDP
wire contract and may be mixed during protocol qualification. Cross-host
qualification evidence contains operational machine data and is intentionally
kept outside this repository. Revalidate a locally produced bundle with:

```bash
python3 scripts/verify_external_lan_evidence_bundle.py \
  /path/to/external-lan-evidence.tar.gz
```

For a local JVM multi-process transport regression, run:

```bash
KOOKIE_EXTERNAL_LAN_TARGET=jvm \
KOOKIE_EXTERNAL_LAN_MODE=processes \
bash scripts/verify_external_lan.sh
```

Set `KOOKIE_EXTERNAL_LAN_TARGET=native` (the default) for the native
multi-process path. Both paths produce the same evidence contract; local
same-host evidence remains `externalHostExecution=unproven`.

The full gate is for final pre-commit verification (in Pi, after `/precommit-matrix`):

```bash
bash scripts/verify.sh
```

Graphical checks must use a reviewed isolated-display wrapper supplied through
`KOOKIE_PRESENTATION_ISOLATION_WRAPPER`. Offscreen SDL checks are useful for
lifecycle and GPU-resource tests; they do not prove that a real window can
present. Set `KOOKIE_SDL_VIDEO_DRIVER=x11` only on a host that can provide
isolated presentation. Set `KOOKIE_SCREENSHOT_PATH=/absolute/path.ppm` to keep
a captured frame.

## What we are building

Engine, game and tool CPU behavior stays in `.kf`. Native code is limited to
small adapters, ABI boundaries, shaders and bootstrap glue. There is no hidden
replacement engine in C, Java, Rust or Zig.

The first supported native target is Linux x86-64. JVM is a comparison target,
not a substitute for native behavior. SDL3 + SDL_GPU is the graphics boundary,
initially with Vulkan/SPIR-V.

## Roadmap

Next is G3: complete the authoritative multiplayer
kill→rolled-drop→pickup/equip→stat/skill-change→boss-reward→save/reload slice.
G2 remains covered by the JVM/native source suite, focused interaction probe,
host-plus-two-client process qualification and isolated headless SDL_GPU/audio
probe.

Deferred until the core gates are stronger:

- full physics and content cooking;
- production save schema and dedicated/WAN transport hardening;
- streamed audio/HRTF, image and text services;
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
