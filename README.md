<p align="center">
  <img src="docs/media/kookie-logo.png" alt="KOOKIE" width="700">
</p>

<p align="center">
  <a href="https://github.com/rufl/KOOKIE/actions/workflows/verify.yml"><img alt="KOOKIE verification status" src="https://github.com/rufl/KOOKIE/actions/workflows/verify.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/rufl/KOOKIE/releases"><img alt="Latest KOOKIE dogfood release" src="https://img.shields.io/github/v/release/rufl/KOOKIE?include_prereleases&amp;sort=semver&amp;label=dogfood&amp;color=38bdf8"></a>
  <img alt="Project status: experimental" src="https://img.shields.io/badge/status-experimental-f59e0b">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/github/license/rufl/KOOKIE?color=22c55e"></a>
  <img alt="Kof 0.5.0-beta" src="https://img.shields.io/badge/Kof-0.5.0--beta-64748b">
</p>

<p align="center">
  <strong>An experimental 3D shooter engine built around Kof.</strong><br>
  Boomer-shooter combat, ARPG structure, authoritative multiplayer and a
  fail-closed content pipeline—without a general-purpose engine behind it.
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> ·
  <a href="#the-shape-of-the-engine">Architecture</a> ·
  <a href="https://github.com/rufl/KOOKIE/releases">Dogfood releases</a> ·
  <a href="docs/RUNNING_AND_PACKAGING.md">Build and package</a> ·
  <a href="pt-BR/README.md">Português (Brasil)</a>
</p>

> **Experimental, deliberately.** KOOKIE is an engine lab, not a finished game
> or a general-purpose engine. Claims below are limited to the focused probes,
> hardware and workloads that produced them.

## Start here

| If you want to… | Go here |
|---|---|
| Run the current authoritative demo | [Quick start](#quick-start) |
| Download a signed Linux dogfood build | [Releases](https://github.com/rufl/KOOKIE/releases) |
| Understand the boundaries | [Architecture](docs/ARCHITECTURE.md) |
| Build, package or run qualification roles | [Running and packaging](docs/RUNNING_AND_PACKAGING.md) |
| See the evidence and open work | [Engine plan](docs/ENGINE_PLAN.md) and [G0 backlog](docs/G0_BACKLOG.md) |
| Change the project | [Contributing](CONTRIBUTING.md) |

## Why this exists

Most engines optimize for broad applicability. KOOKIE optimizes for inspectable
authority boundaries and claims that can be reproduced.

Portable engine, game and tool decisions stay in Kof. C owns narrow,
explicit platform boundaries: SDL3/SDL_GPU, SDL_mixer, UDP, filesystem
durability and measured SIMD dispatch. A feature is not called done because a
class or menu exists; it needs an executable path and a stated proof limit.

The result is intentionally opinionated:

- the server decides combat, loot, progression and persistence;
- clients predict presentation-safe movement, then reconcile;
- source assets cross bounded validation and canonicalization before runtime;
- malformed state, packages, saves and compatibility offers fail closed;
- release artifacts bind source and toolchain provenance with signatures.

## Quick start

Prerequisites: [Kof 0.5.0-beta](https://github.com/KofLang/Kof4j) and Python 3.

```bash
git clone https://github.com/rufl/KOOKIE.git
cd KOOKIE
kof run src/main.kf --target native
```

Run the focused gameplay/replay path:

```bash
bash scripts/verify_interactions.sh
```

Run the non-graphical G6 expansion probes:

```bash
bash scripts/verify_g6_runtime.sh
```

Presentation packages additionally require SDL 3.4.16, SDL_mixer 3.2.4 and
`glslc`. Exact package, kooker, Windows and cross-host qualification commands
live in [Running and packaging](docs/RUNNING_AND_PACKAGING.md).

## What works today

| Area | Implemented bounded path |
|---|---|
| **Authority and networking** | 60 Hz server/client sessions, two-client admission, authenticated compatibility handshake, sequenced commands, snapshots, prediction/reconciliation, reconnect and replay/tamper rejection; bounded direct-IPv4 WAN window with retries/backpressure |
| **Shooter and ARPG systems** | Hitscan/projectile/shotgun combat, enemy roles, deterministic loot, inventory, equipment, skills, status effects, bosses, rewards and exactly-once progression |
| **World and presentation** | True 3D authored arena with slopes, steps and stacked rooms; capsule/triangle collision; doors, secrets and exits; semantic HUD; SDL_GPU instancing; positional gain/pan through SDL_mixer |
| **Content and kutter tooling** | Bounded GLB, Dust3D, Aseprite, VOX, Quake-style brush, Blockbench, PNG and WAV intake; canonical products; `.kpkg` validation; transactional Kutter edits; persistent Kutter hierarchy/transform/asset registry |
| **Persistence and release** | Checksummed replay, schema migrations, crash-durable save publication, signed clean-tree packages, dependency closure and outside-checkout smoke |
| **Runtime targets** | Authoritative native Linux x86-64; native Windows Kof PE gameplay linked to SDL3/SDL_mixer shell; native Windows Kof PE SDL_GPU presentation with SPIR-V/DXIL products; separate reproducible Windows Kof JVM compatibility package; deterministic reachable Kof-to-AMD64 PE/COFF compiler |

## The shape of the engine

```mermaid
flowchart LR
    subgraph KOF["Kof-owned engine and game logic"]
        INPUT["Player input"] --> CLIENT["Client prediction"]
        CLIENT -->|"sequenced commands"| SERVER["60 Hz authority"]
        SERVER --> WORLD["World · combat · loot"]
        WORLD --> SAVE["Save + replay"]
        SERVER -->|"snapshots + ordered feedback"| CLIENT

        SOURCE["Authoring sources"] --> KOOKER["Bounded validate + cook"]
        KOOKER --> GENERATION["Canonical package generation"]
        GENERATION --> WORLD
        CLIENT --> VIEW["Render · audio · UI state"]
    end

    subgraph NATIVE["Narrow native/platform boundaries"]
        TRANSPORT["UDP + filesystem"]
        SDL["SDL3 · SDL_GPU · SDL_mixer"]
        SIMD["Measured SIMD dispatch"]
    end

    SERVER <--> TRANSPORT
    SAVE <--> TRANSPORT
    VIEW --> SDL
    WORLD --> SIMD
```

Kof owns decisions. Native code owns explicit ABI and platform boundaries.
Presentation consumes authoritative state; it does not award damage, loot or
progression. See [Architecture](docs/ARCHITECTURE.md) for the full contracts.

## Engineering evidence

These numbers describe exact retained qualification workloads—not general
performance claims.

| Evidence | Recorded result | Boundary |
|---|---:|---|
| Authoritative session | 60 Hz, host + two clients | Same-host process qualification; G4 also passed across three isolated Linux network namespaces |
| G5 simulation soak | p95 **3.202 ms/tick**; RSS within **128 KiB** after warm-up | 30 minutes on one Linux x86-64 workstation; 64 enemies, 256 projectiles, 512 pickups, 24 lights, 64 effects |
| SDL_GPU reference scene | **984** hardware triangle instances in **one draw**; p95 submission **0.645 ms** | 600 frames at 1920×1080 on recorded Intel Arrow Lake graphics |
| Kof buffer SIMD probe | 64 MiB batch: scalar **233.350 ms**, AVX2 **1.074 ms** | Exact reduction ABI/workload only; not a gameplay-wide speedup claim |
| Release chain | Ed25519-signed archive, manifest and checksum set | Clean source tree, pinned Kof source and verified distribution digest required |

## Content that crosses the boundary

The kooker accepts documented subsets rather than claiming general format
compatibility:

`GLB` · `Dust3D` · `Aseprite` · `VOX` · `MAP` · `Blockbench` · `PNG` · `WAV`

It emits bounded canonical geometry/collision, RGBA8 images/atlases, `KCHR`
characters, PCM16 audio and package-ready checksums. Products are reopened and
validated before atomic publication; failed imports keep the prior generation
active.

```bash
scripts/kooker.sh cook blockbench character.bbmodel character.kchar
scripts/kooker.sh cook png texture.png texture.rgba.png
scripts/kooker.sh cook wav effect.wav effect.pcm16.wav
```

Limits are part of the contract, not temporary documentation omissions. See
[Additional intake hardening](docs/ARCHITECTURE.md#additional-intake-hardening)
for the production work still open.

## Honest boundaries

- Transport evidence now includes the bounded direct-IPv4 authenticated endpoint
  and a deterministic fixed-window/retry channel; it is not a fresh
  three-physical-machine qualification bundle and does not claim NAT traversal,
  relay service, confidentiality or DDoS resistance.
- Linux x86-64 remains the authoritative native Kof gameplay target. Windows now
  has qualified native Kof PE gameplay in both the SDL shell and SDL_GPU
  presentation package; the separate JVM package is compatibility-only.
  Optional isolated Wine smoke remains environment-gated and target/GPU
  specific.
- Importers support small, explicit profiles—not arbitrary files from each
  named format.
- Live reload covers validated scene/render products, not arbitrary Kof code,
  shaders, editor plugins or unbounded streaming.
- Rich authoring beyond the bounded persistent Kutter, broader OS/GPU coverage,
  streamed/compressed audio, HRTF/EFX and a general-purpose sandboxed extension
  API remain unfinished.

If a claim lacks a focused test or probe, it is not presented as complete.

## Repository map

| Path | Purpose |
|---|---|
| [`src/`](src/) | Kof-owned engine, game, session, content and UI logic |
| [`native/`](native/) | Narrow SDL, transport, persistence and SIMD adapters |
| [`apps/`](apps/) | Packaged server, kooker, SIMD benchmark and platform tools |
| [`probes/`](probes/) | Focused executable evidence at risky boundaries |
| [`scripts/`](scripts/) | Verification, packaging and qualification automation |
| [`docs/`](docs/) | Architecture, plans, language notes and research evidence |

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — authority, data flow and runtime
  boundaries.
- [Engine plan](docs/ENGINE_PLAN.md) — gate definitions, measurements and
  deferred scope.
- [Running and packaging](docs/RUNNING_AND_PACKAGING.md) — developer,
  release, kooker and qualification commands.
- [Kof language notes](docs/KOF_LANGUAGE.md) — syntax, targets, FFI and runtime
  findings.
- [Executed probes](docs/RESEARCH_PROBES.md) — commands, results and proof
  limits.
- [Changelog](CHANGELOG.md) — recent behavior changes.
- [Project memory](MEMORY.md) — current decisions, caveats and next action.

Public documentation is mirrored in
[Brazilian Portuguese](pt-BR/README.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing dependencies,
authority boundaries or qualification claims. During development, run the
smallest focused check that proves the change. The complete gate is:

```bash
bash scripts/verify.sh
```

Graphical checks must use the repository's reviewed isolated-display contract;
never target an active desktop or physical monitor. Security-sensitive findings
belong in the [private reporting path](SECURITY.md), not a public issue.

## License and provenance

KOOKIE is [MIT licensed](LICENSE). Native distributed runtime dependencies are
SDL 3.4.16 and SDL_mixer 3.2.4 under the zlib License. The optional Windows JVM
profile bundles one SHA-256-pinned OpenJDK runtime under its own licenses and
preserves `runtime/legal` and `runtime/NOTICE`. Exact sources and boundaries are
recorded in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).

The Kof compiler remains an external build tool and is not distributed. Only
the explicit Windows JVM profile bundles Java; its provenance records the
runtime vendor, version and archive digest.
