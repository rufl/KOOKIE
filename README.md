# KOOKIE
[Português (Brasil)](pt-BR/README.md)

KOOKIE is an experimental 3D shooter engine built around Kof. It is for
boomer-shooter, looter-shooter and ARPG-FPS experiments—not a finished game.
The doors have prerequisites. The network has prerequisites. Calling this finished has paperwork.

## The honest status

G0, G1, G2, G3 and the bounded G4 implementation run on JVM and native Linux x86-64:

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
  a focus-responsive crosshair, hit/kill markers, edge damage warnings,
  shape-backed inventory/equipment/skill/world-loot state, structural
  elite/boss threat cues and a source→validation→publication creator rail;
  SDL_GPU uploads the fixed 486-vertex arena/door/HUD scene (372 HUD vertices)
  without per-frame buffer growth;
- cooperative key, 3D door, secret and exit progression, command replay and
  versioned level saves;
- saves, replays, inventory, equipment, skills and status effects;
- authoritative G3 kill→rolled-drop→pickup/equip→stat/skill-change→boss-reward
  flow, recipient-specific inventory/equipment/progression and world-loot
  schemas, plus atomic save/reload of rolls and reward claims;
- bounded public extension manifests, dependencies, capabilities and
  deterministic content contributions, plus sealed data-defined elite/boss
  combat, behavior, loot, progression and currency rules;
- a transactional G4 path that binds package, extension, trusted-hook
  implementation/version, enemy-definition and aligned product checksums into
  a 13-word compatibility identity; stale edits retain the active generation,
  while a generation-bound runtime executes the compiled elite-bounty hook
  after a confirmed kill and applies its bounded currency command exactly once;
- trusted hooks subscribe to typed session-started, player-connected,
  enemy-defeated, loot-picked-up and editor-published events; only registered
  static implementation/version pairs execute under phase and output budgets;
- the file cooker admits a bounded indexed GLB subset, Dust3D `.ds3` plus its
  exported textured GLB, 32-bit RGBA `.ase`/`.aseprite`, `.vox` models and
  scene chunks, and integer-grid convex Quake-style `.map` brushes; it emits
  canonical geometry/collision, PNG atlas/metadata and package-ready checksums;
- `.kpkg` files validate headers, logical paths, chunk ranges/hashes and
  registry payloads before an external generation replaces the active one;
  malformed reloads leave the prior package and registries active;
- the Creator screen exposes bounded world/entity/weapon/loot edits, collision
  and AI inspection, play-in-editor, and revision-checked undo/redo. Publication
  swaps geometry/collision/navigation/render products atomically;
- staged native scene reload keeps the active scene intact while building a
  candidate, waits for synchronous upload-fence completion before reusing the
  persistent GPU buffer, and activates at a frame boundary; Kof generation
  references gate retirement;
- an 18-word compatibility offer and 7-word response transport the exact
  13-word content identity before snapshots or gameplay commands. Mismatch and
  corrupt frames fail closed with a diagnostic response;
- a small SDL3/SDL_GPU adapter; JVM and native three-process transport
  regressions carry the complete 26-triangle arena, unified checksummed
  movement/fire/interaction/lifecycle commands, recipient-specific gameplay
  and G3 player-authority/world-loot baselines, ordered multiplayer feedback
  and bounded authoritative encounter state;
- a persistent, resizable 1280×720 game shell with old-school pixel menus,
  mouse and keyboard navigation, a display/audio/text options transaction and
  a simple SipHash-tagged host/join/leave lobby;
- continuous hitscan/projectile/shotgun enemy roles, client movement
  prediction with unacknowledged-input replay, generation-safe reconnect
  recovery, full 3D door collision/render geometry and feedback batch
  gap/duplicate recovery;
- listener-relative distance attenuation and stereo panning computed in Kof,
  with allocation-free PCM submission to independent SDL_mixer effects and
  music buses.

The important gaps are still real:

- G3 process qualification remains same-host. The G4 compatibility handshake
  passed with a host and two clients in three isolated Linux network namespaces
  with distinct IPv4 stacks; no fresh three-physical-machine G4 evidence bundle
  is retained;
- authoring support is intentionally bounded rather than general format
  compatibility: one indexed GLB primitive and canonical products are capped
  at 256 vertices/triangles, VOX intake at 20 voxels, and the documented
  Aseprite, Dust3D and brush subsets reject unsupported constructs;
- live reload covers validated scene/render products, not arbitrary Kof code,
  shaders, editor plugins or unbounded resource streaming;
- Kof bulk-buffer FFI is blocked by `FFI001`, so the native SIMD kernel is not
  wired into Kof-owned hot loops;
- crash-durable saves, full physics, streamed/compressed audio and HRTF/EFX,
  sustained G5 soak/performance proof, richer G6 authoring and sandboxed
  runtime extensions remain unfinished.
- the native Windows shell is interactive and persistent, but Kof cannot yet
  emit Windows PE gameplay code; its Play screen is not proof of authoritative
  Kof execution on Windows;

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

Build a native Linux package:

```bash
KOOKIE_VERSION=0.1.0-dogfood.1 scripts/package_kookie.sh
```

The builder emits a target-bound `.tar.gz`, `SHA256SUMS` and provenance JSON.
Distributable JVM packages are intentionally unsupported because a Java
runtime would violate KOOKIE's permissive-only distributed dependency policy.
The JVM target remains available for local differential verification.

Cook authoring files and build or inspect one-chunk external packages with the
JVM-only developer CLI:

```bash
scripts/kookie_cooker.sh cook map level.map level.kmesh
scripts/kookie_cooker.sh cook dust3d model.ds3 model.glb model.kmesh
scripts/kookie_cooker.sh package 4 level.kmesh data/level.kmesh level.kpkg
scripts/kookie_cooker.sh inspect-package level.kpkg
scripts/kookie_cooker.sh validate-package creator.kpkg
```

The cooker rejects oversized, malformed or unsupported input without writing a
successful result. Source formats are not runtime package formats.

Build the persistent Linux SDL_GPU presentation package used for isolated
visual qualification and ZEER dogfood deployment:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.presentation.1 \
scripts/package_kookie.sh
```

It contains the Kof menu/game application, SDL adapter, SPIR-V shaders, SDL3
and SDL_mixer. The launcher uses the host system runtime rather than bundling
the dynamic loader or libc.

Build the native Windows x86-64 shell from the official MinGW development
packages for SDL 3.4.16 and SDL_mixer 3.2.4:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/path/to/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/path/to/SDL3_mixer/x86_64-w64-mingw32 \
scripts/package_kookie.sh --runtime native --target windows-x86_64
```

The `.zip` contains `kookie.exe`, `SDL3.dll`, `SDL3_mixer.dll`, licenses and
provenance. It contains no JDK and no auto-closing color-matrix executable.
Normal launch remains open until the user quits. `--package-smoke` is a
non-graphical dependency/version check for deployment automation.

Main-menu controls are arrow keys or WASD, Enter/Space to select, Escape to go
back, and mouse click. Options include 1280×720 through 2560×1440, windowed,
borderless or exclusive fullscreen, separate effects/music volume and three
text sizes. Display changes commit only on Apply. Multiplayer exposes Host,
Join, Leave, editable IPv4/port fields and connection state. Lobby packets use
SipHash tags and replay sequences. A configured 128-bit shared key
authenticates peers; the built-in local fallback only detects accidental
corruption. The lobby provides neither encryption nor public identity.

Windows uses the same native menu/lobby contract while the compiler lacks a PE
target. Linux remains the authoritative Kof gameplay target.

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
wire contract and may be mixed during protocol qualification. This bundle is
qualification tooling, not a distributable KOOKIE runtime; its JVM/JDK
requirements are outside the product package dependency policy. Cross-host
evidence contains operational machine data and is intentionally kept outside
this repository. Revalidate a locally produced bundle with:

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

Authoritative engine and gameplay CPU behavior stays in `.kf`. Native code is
limited to adapters, ABI boundaries, shaders and platform bootstrap glue. The
Windows native shell owns only the menu, options, lobby and presentation
boundary required while Kof lacks a PE target; it is not a replacement
gameplay engine.

The first authoritative native gameplay target is Linux x86-64. JVM is a
local comparison target, not a distributable fallback. SDL3 + SDL_GPU is the
graphics boundary and SDL_mixer owns effects/music buses.

## Roadmap

G3 is closed at its current acceptance gate: the authoritative multiplayer
kill→rolled-drop→pickup/equip→stat/skill-change→boss-reward→save/reload path
runs on JVM and native; state kinds `7`/`8` traverse authenticated same-host
processes; and bounded manifest/capability/contribution registries instantiate
complete sealed elite/boss definitions. The bounded G4 gate now includes typed
hook events, the documented source subsets and file CLI, fail-closed external
package loading, transactional Creator tools, fence-gated frame-boundary reload,
and compatibility offer/response transport. The handshake passed across three
isolated Linux network namespaces with distinct IPv4 stacks. This does not
claim general source-format compatibility, arbitrary live-code reload, a
production-grade editor or fresh qualification on three physical machines.
G2 remains covered by the source suite, focused interaction probe, process
qualification and isolated SDL_GPU/audio probe.

Deferred until the core gates are stronger:

- full physics and broader source-format/cooker profiles;
- production save schema and dedicated/WAN transport hardening;
- streamed audio/HRTF, image and text services;
- package compression, richer authoring and foreign physics/UI libraries.

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

KOOKIE source and produced programs use the [MIT License](LICENSE). Distributed
third-party source/runtime components are permissive: SDL 3.4.16 and
SDL_mixer 3.2.4 use the zlib License. Exact versions, sources and notices are
in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).

The Kof compiler is an external build tool, is not distributed, and permits
generated programs to use their own license. Java remains local
qualification-only and is excluded from KOOKIE packages. Research notes record
compiler versions, pinned SHAs and proof limits. See
[CONTRIBUTING.md](CONTRIBUTING.md) before adding dependencies or changing the
verification boundary.
