# Playable demo release readiness

[Português (Brasil)](../pt-BR/docs/DEMO_RELEASE.md)

This page is the authority for the difference between a qualified source path,
a qualification artifact and a player-facing KOOKIE demo. The current source
contains a bounded playable slice, but a source probe or package-linkage gate
is not a public release until a clean archive is exercised on its target
hardware.

## Current public state

The latest public release is [`0.1.0-dogfood.34`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.34),
published on 2026-09-30. It contains one signed Linux x86-64 SDL presentation
archive built from source commit `4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`.
It predates the current source presentation path, KOF-owned multiplayer
lobby/score screen, native Windows PE/SDL qualification and the hosted-CI P95
gate fix. No current Windows demo archive is published.

The current source tree has these release-capable paths:

- Local `Play` starts an authoritative listen-server/client goose encounter
  with bounded keyboard/mouse input, three bots, HUD/nameplates, damage and
  deterministic reset by leaving and re-entering `Play`.
- `Multiplayer > Host/Join` admits a fixed two-player session, exposes room and
  peer identity, requires explicit `READY` from both connected players, and
  publishes a bounded host-authoritative `Tab` scoreboard.
- Linux x86-64 native SDL3/SDL_GPU presentation packaging with SDL_mixer,
  signed provenance and outside-checkout package smoke.
- Windows x86-64 native Kof PE gameplay linkage to the SDL shell and the
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
2. enter the local authoritative listen-server/client session through `Play`;
3. map keyboard and mouse input to bounded `InputCommand` values and camera look;
4. move, jump, aim and fire through the authoritative session;
5. show an enemy encounter, damage, death feedback and HUD state;
6. expose a deterministic exit or restart path; and
7. quit cleanly after repeated start/play/restart cycles.

If multiplayer is advertised in the same dogfood release, also require
`Host/Join`, the two-player `READY` gate, `Tab` scoreboard behavior and
cross-host evidence for the supported LAN/WAN claim.

The published presentation archive remains a qualification artifact because it
predates the current source tree. The source path is now implemented: `Play`
starts a local authoritative encounter; `Host/Join` admits a second player
through the explicit ready lobby; three goose bots attack players; host
snapshots replicate player/bot state; and `Tab` shows the bounded
host-authoritative player screen. Fresh package and hardware evidence are still
required before calling it a public release.


## Remaining work, ordered by release impact

### Closed in the current source tree — not release evidence

- The native SDL path polls held keyboard/mouse input, advances the
  authoritative session, reconciles the joined client and renders bots,
  nameplates, hearts and HUD state.
- `Play` resets the bounded encounter when the user returns to the menu and
  starts it again.
- `Multiplayer > Host/Join` owns fixed two-player lifecycle, explicit ready and
  unready state, bounded identity/ping/error display and deterministic
  scoreboard snapshots. `bash scripts/verify_multiplayer_ui.sh` proves the
  model, codec, overlay bounds and JVM/native probe path.
- `bash scripts/verify_goose_game.sh` proves the focused goose gameplay path.

### P0 — Linux release qualification

- Build a new clean-tree signed Linux `presentation` archive from the current
  source, with the current lobby/score screen and local gameplay path.
- Verify the archive outside the checkout on a fresh supported Linux system:
  signature/checksum, extraction, launch, `Play`, movement/look/fire, damage,
  restart, quit and repeated relaunch.
- Run the isolated present-capable GPU smoke and retain machine, driver,
  wrapper, screenshot and exit evidence. The current environment lacks the
  SDL3_mixer development header, so this evidence is not reproduced here.
- Document the tested loader/libc/GPU floor. SDL3 and SDL_mixer are bundled,
  but arbitrary distribution compatibility is not implied.

### P0 — Windows release qualification

- Build a new signed Windows x86-64 `presentation` ZIP from the current tree,
  including native Kof PE, SDL3/SDL_mixer DLLs, shaders, notices and provenance.
- Verify extraction, launch and repeated `Play`/restart/quit outside the
  checkout on supported Windows hardware and drivers.
- Run `scripts/verify_windows_presentation.sh`; its reproducibility and PE/
  SDL/SPIR-V/DXIL checks are artifact evidence, not native hardware evidence.
- Retain native Windows GPU/input/audio evidence. Wine proves the package path
  only; the optional visual Wine smoke requires an isolated DRI3-capable GPU.
- Decide whether ordinary-user distribution requires Authenticode signing;
  SmartScreen-facing distribution still needs it.

### P1 — paired distribution and release operations

- Publish matching Linux and Windows archives from one clean source/toolchain
  identity with manifests, public key, detached signatures and `SHA256SUMS`.
- Add a manually approved release workflow or operator checklist that builds,
  verifies and publishes both demo archives as a pair. The current CI verifies
  components but does not publish the current pair.
- Add release notes containing controls, supported floors, known limitations,
  exact source/toolchain identities and the multiplayer best-effort boundary.

### P1 — content and product boundary

- Decide whether the first demo ships the fixed authored arena only or a
  separate content package. The prototype asset profile remains opt-in.
- Resolve redistribution terms for every bundled asset. The prototype goose
  asset remains restricted by its upstream terms and must not be relabeled CC0
  or included silently.
- If multiplayer is advertised publicly, run fresh cross-host LAN/WAN evidence.
  The rendezvous and direct UDP hole punch remain best-effort dogfood networking:
  no relay, symmetric-NAT recovery, production WAN security or DDoS protection.
- A result/victory screen, broader content, save/replay, Kutter, KofScript and
  full ARPG progression are polish or separate product scope, not prerequisites
  for the bounded local demo once restart/exit is demonstrated.


## Acceptance matrix before publishing

| Check | Linux x86-64 | Windows x86-64 |
|---|---:|---:|
| Clean extracted package launches | Required | Required |
| Signature/checksum/provenance verification | Required | Required |
| Menu/options/input/audio/resize | Required | Required |
| Real local authoritative gameplay loop | Required | Required |
| Enemy damage/death/HUD/exit or restart | Required | Required |
| Outside-checkout repeated-run smoke | Required | Required |
| Native hardware presentation evidence | Required on supported Linux GPU | Required on supported Windows GPU |
| Multiplayer lobby/ready/`Tab` scoreboard | Required if advertised | Required if advertised |
| Cross-host multiplayer | Required if advertised for the simple WAN dogfood path | Required if advertised for the simple WAN dogfood path |


## Explicitly not blocking this demo

Full ARPG breadth, arbitrary authoring-format support, relay service, symmetric
NAT recovery, production WAN security, HRTF/EFX, streamed/compressed audio, a
general extension sandbox, macOS/ARM support and broad GPU coverage remain
separate milestones. They must not be used to expand this bounded goose game
claim, but they also do not block the scoped source implementation.

The implementation plan tracks this work as **D1 — Playable demo release** in
[ENGINE_PLAN.md](../docs/ENGINE_PLAN.md). Build and qualification commands remain
in [RUNNING_AND_PACKAGING.md](../docs/RUNNING_AND_PACKAGING.md).
