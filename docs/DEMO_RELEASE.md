# Playable demo release readiness

[Português (Brasil)](../pt-BR/docs/DEMO_RELEASE.md)

This page is the authority for the difference between a qualification artifact
and a player-facing KOOKIE demo. The project has strong bounded engine evidence,
but a rendered qualification scene is not gameplay.

## Current public state

The latest public release is [`0.1.0-dogfood.34`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.34),
published on 2026-09-30. It contains one signed Linux x86-64 SDL presentation
archive built from source commit `4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`.
It predates the current native Windows PE/SDL qualification and the hosted-CI
P95 gate fix. No current Windows demo archive is published.

The current source tree has these release-capable paths:

- Linux x86-64 native SDL3/SDL_GPU presentation packaging with SDL_mixer,
  signed provenance and outside-checkout package smoke.
- Windows x86-64 native Kof PE gameplay linkage to both the SDL shell and the
  SDL_GPU presentation package, with SPIR-V/DXIL products and reproducible
  artifact gates.
- Native-shell Wine gameplay-marker smoke for Windows. Presentation visual Wine
  smoke remains optional and requires a DRI3-capable isolated GPU; package
  linkage or Xvfb output is not visual presentation evidence.
- A signed Linux dogfood package pipeline and a separate Windows JVM package
  for compatibility/qualification. The JVM package is not a native-game
  fallback.

## What “playable demo” means for this milestone

A limited G1 vertical slice is enough. It does not need the complete looter/ARPG
roadmap, public WAN hosting, general-purpose modding or every source importer.
It must, on both supported targets:

1. launch from a clean extracted package without the Kof toolchain or checkout;
2. enter a real local listen-server plus local-client session;
3. map keyboard and mouse input to bounded `InputCommand` values and camera look;
4. move, jump, aim and fire through the authoritative session;
5. show at least one enemy encounter, damage, death feedback and HUD state;
6. expose a deterministic win/exit or restart path; and
7. quit cleanly after repeated start/play/restart cycles.

The published presentation archive remains a qualification artifact because it
predates the current source tree. The source presentation now has a bounded
playable path: `Play` starts an authoritative two-player session, each side
maps SDL keyboard/mouse input, three goose bots attack players, and host/join
snapshots replicate player/bot state. Nameplates and 20-point heart segments
show the selected player names and authoritative energy. The same path is
available to the Linux and Windows `presentation` profiles; fresh package and
hardware evidence is still required before calling it a public release.


## Missing work, ordered by release impact

### P0 — scoped playable loop implemented in source

- The native SDL presentation now polls held keyboard/mouse input, builds
  bounded `InputCommand` values, advances the authoritative session and
  reconciles the joined client from host snapshots.
- `Play` starts a fresh authored encounter with two goose players and three
  bot geese. Bots target both players; firing damages the nearest live bot,
  and hearts/nameplates render the resulting state.
- `Escape` returns to the menu and entering `Play` resets the encounter. The
  gameplay path is intentionally small: one arena, one weapon and a bounded
  encounter rather than the full ARPG roadmap.


### P0 — native Windows gameplay evidence

- The Windows `presentation` profile now reaches the same Kof SDL gameplay path
  as Linux, including input, bots, nameplates, hearts and direct/WAN transport.
- Build and smoke the PE package outside the checkout, then run the presentation
  smoke on supported Windows hardware/driver coverage. Wine artifact evidence
  does not replace native presentation evidence.


### P1 — release packaging and distribution

- Build a new clean-tree signed Linux presentation archive from the post-G6
  source, and publish its archive, manifest, public key, detached signatures and
  `SHA256SUMS` together.
- Build and publish a matching signed Windows x86-64 native presentation ZIP
  containing the exact SDL DLLs, shader products, notices and provenance.
- Verify both archives on fresh machines outside the checkout: extract, launch,
  play, restart, quit, and repeat after checksum/signature verification.
- Document the supported Linux loader/libc/GPU floor and Windows x86-64 GPU/driver
  floor. The Linux package uses the host loader/libc; SDL3 and SDL_mixer are
  packaged, but arbitrary distro compatibility is not implied.
- Add user-facing release notes with controls, known limitations, dependency
  requirements and the exact commit/toolchain identities. Authenticode signing
  is optional for an internal dogfood ZIP but is still missing if the Windows
  archive is meant for ordinary users without SmartScreen warnings.
- Add an explicit manually approved release workflow or operator checklist.
  The current verification workflow checks components but does not build and
  publish the current Linux and Windows demo archives as a pair.

### P1 — demo content and product boundary

- Decide whether the first demo ships the fixed authored qualification arena or a
  separate content package. The current prototype asset profile is opt-in and is
  not automatically wired into the presentation gameplay path.
- Bundle only assets with cleared redistribution terms. The prototype goose
  asset remains restricted by its upstream terms and cannot be relabeled CC0 or
  silently included in a public demo.
- State explicitly that the simple authenticated rendezvous and direct UDP
  hole-punch path are best-effort dogfood networking. Relay service, symmetric
  NAT recovery, production WAN security, Kutter editing, KofScript, save/replay
  and full ARPG progression remain separate product boundaries.


## Acceptance matrix before publishing

| Check | Linux x86-64 | Windows x86-64 |
|---|---:|---:|
| Clean extracted package launches | Required | Required |
| Signature/checksum/provenance verification | Required | Required |
| Menu/options/input/audio/resize | Required | Required |
| Real local authoritative gameplay loop | Required | Required |
| Enemy damage/death/HUD/result/restart | Required | Required |
| Outside-checkout repeated-run smoke | Required | Required |
| Native hardware presentation evidence | Required on supported Linux GPU | Required on supported Windows GPU |
| Cross-host multiplayer | Required for the simple WAN dogfood path | Required for the simple WAN dogfood path |


## Explicitly not blocking this demo

Full ARPG breadth, arbitrary authoring-format support, relay service, symmetric
NAT recovery, production WAN security, HRTF/EFX, streamed/compressed audio, a
general extension sandbox, macOS/ARM support and broad GPU coverage remain
separate milestones. They must not be used to expand this bounded goose game
claim, but they also do not block the scoped source implementation.

The implementation plan tracks this work as **D1 — Playable demo release** in
[ENGINE_PLAN.md](../docs/ENGINE_PLAN.md). Build and qualification commands remain
in [RUNNING_AND_PACKAGING.md](../docs/RUNNING_AND_PACKAGING.md).
