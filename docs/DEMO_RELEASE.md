# Playable demo release readiness

[Português (Brasil)](../pt-BR/docs/DEMO_RELEASE.md)

This page is the authority for the difference between a qualified source path,
a qualification artifact and a player-facing KOOKIE demo. The current source
contains a bounded playable slice, but a source probe or package-linkage gate
is not a public release until a clean archive is exercised on its target
hardware.

## Current public state

The latest public dogfood release is [`0.1.0-dogfood.38`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.38), published from source commit
`a86d55eddb0aae2f0a7e05fb59033560d34c95c7` through the paired release
workflow. It contains signed Linux and Windows x86-64 artifacts using the
pinned Kof 0.5.0-beta source commit
`bf17ac7e736471c8a04b4153e5b0f607be75e70c`. It remains a pre-release
qualification artifact: target-hardware presentation evidence and the D1
player-facing release gate remain open.

The current source tree has these release-capable paths:

The player-facing test game is named **GatoGanso**. The presentation defaults
to `Jared Lite` for bounded UI text and `Pixand` for display/title text; both
font files and their SIL Open Font License notice ship with the package.


- Local `Play` starts an authoritative listen-server/client goose encounter
  with bounded keyboard/mouse input, three bots, HUD/nameplates, damage and
  deterministic reset by leaving and re-entering `Play`.
- `Multiplayer > Host/Join` admits a fixed two-player session, exposes room and
  peer identity, requires explicit `READY` from both connected players, and
  publishes a bounded host-authoritative `Tab` scoreboard.
- The session uses fixed-tick input bundles with snapshot/input ACKs, pins the
  authenticated peer endpoint, rewinds hitscan through a bounded 12-tick
  history, interpolates remote players six ticks behind and exposes prediction
  correction metrics. A higher state sequence can revise the latest authoritative
  sample at the same tick for lifecycle or stale-command diagnostics; older
  ticks/sequences remain rejected. The direct IPv4/UDP WAN path remains best
  effort and is not QUIC-compatible.
- Linux x86-64 native SDL3/SDL_GPU presentation packaging with SDL_mixer,
  signed provenance and outside-checkout package smoke. On 2026-10-02, the
  clean-tree builder produced `0.1.0-linux-e2e.1` from source commit
  `1678a7de671866d94080718c367ab05875a92c2d` with Kof source commit
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`; it verified deterministic
  duplicate builds, signatures/checksums, safe extraction and package smoke,
  and `scripts/verify_goose_game.sh` passed. The archive SHA-256 was
  `e3dddf0eab08b2d4ced71bc5c1b2e2f5e593bfe20af01b8e9c5594d2d9ed6536`.
  This local qualification used an ephemeral Ed25519 key and a pinned
  SDL_mixer 3.2.4 prefix, so it is not a public release identity. The
  isolated presentation run reported `No DRI3 support detected` and `No
  supported SDL_GPU backend found` before timeout 124; target-hardware
  evidence remains required.
- Windows x86-64 native Kof PE gameplay linkage to the SDL shell and the
  SDL_GPU presentation package, with SPIR-V/DXIL products and reproducible
  artifact gates. The signed presentation artifact gate passed with pinned
  MinGW SDL3/SDL_mixer and DXC; no target Windows hardware evidence is retained.
- Native-shell Wine gameplay-marker smoke for Windows. Native Windows visual
  smoke is available through `KOOKIE_RUN_NATIVE_PRESENTATION=1` and the
  reviewed `KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER`; Wine, package
  linkage and Xvfb output are not visual target presentation evidence.
- A signed Linux dogfood package pipeline and a separate Windows JVM package
  for compatibility/qualification. The JVM package is not a native-game
  fallback.

The published archive is the current-source dogfood qualification package:
`Play` starts a local authoritative encounter; `Host/Join` admits a second
player through the explicit ready lobby; three goose bots attack players; host
snapshots replicate player/bot state; `Tab` shows the bounded host-authoritative
player screen; and the fixed-tick input/ACK, rewind and interpolation paths are
bounded in the session and presentation code. The package passed the paired
artifact, checksum and signature gates, but target-hardware presentation and
outside-checkout interactive evidence remain required for D1.


## Previous D1 qualification — 2026-10-07

A fresh D1 qualification pass ran from a clean KOOKIE checkout. The release
gate remains **blocked**; no player-facing public release is claimed.

Passed:

- `scripts/build_demo_release.sh --target linux-x86_64` produced the
  deterministic signed local artifact
  `0.1.0-d1-e2e.1` from source commit
  `9d9cfe784e534fe34a0e30694198435ce90a7546`; archive SHA-256:
  `edf553e256bc9fa34b58a2217c3db87a207765fbb4cdc058cb5703130c1d5738`.
- The Linux duplicate-build, detached-signature, checksum, safe-extraction and
  package-smoke gates passed. The artifact was extracted and smoke-tested
  outside the checkout at
  `/home/lich/lichforge/ztash-releases/kookie-d1-e2e-extracted`.
- Focused launcher, interaction/recovery, goose-game and multiplayer UI
  probes passed.
- The existing Windows `0.1.0-dogfood.60` native package passed isolated Wine
  `--package-smoke` outside the checkout. Its manifest is `runtime=native`
  with `windows_presentation=false`; this is not D1 presentation evidence.

Blocked:

- The Linux presentation smoke reached the native SDL shell but reported
  `No DRI3 support detected` and
  `No supported SDL_GPU backend found!`; `Play`/encounter/restart/quit was
  therefore not certified on target-capable hardware.
- `scripts/verify_windows_presentation.sh` could not build the paired current
  source artifact: `KOOKIE_WINDOWS_SDL_PREFIX` is unset, and
  `KOOKIE_WINDOWS_SDL_MIXER_PREFIX`, `KOOKIE_DXC` and `dxc` are unavailable.
- The Linux artifact used an ephemeral Ed25519 key because no permanent
  `KOOKIE_SIGNING_KEY` was available. It is a qualification artifact, not a
  release identity.
- The candidate public release URL returned HTTP `404`; no paired publication,
  Authenticode/SmartScreen decision, native Windows hardware evidence or fresh
  cross-host multiplayer evidence exists.

The remaining D1 actions are a clean extracted interactive smoke outside the
checkout, target-capable Linux GPU evidence, native Windows presentation
evidence through the reviewed wrapper, and release notes/policy for promotion
from dogfood pre-release to player-facing release.




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

The published presentation archive is the current-source dogfood qualification
package `0.1.0-dogfood.38`: `Play` starts a local authoritative encounter;
`Host/Join` admits a second player through the explicit ready lobby; three
goose bots attack players; host snapshots replicate player/bot state; `Tab`
shows the bounded host-authoritative player screen; and the fixed-tick input/ACK,
rewind and interpolation paths are bounded in the session and presentation code.
The paired artifact, checksum and signature gates passed. Clean
outside-checkout interactive and target-hardware evidence remain required before
calling it a player-facing release.

### Executable D1 evidence contract

- Linux target smoke sets `KOOKIE_RUN_PRESENTATION=1`, requires the reviewed
  `KOOKIE_PRESENTATION_ISOLATION_WRAPPER` and a real `/dev/dri/renderD*` node,
  then runs the extracted package. Missing isolation or GPU capability fails
  closed; Xvfb, Wine and headless GPU tests are not substitutes.
- Windows target smoke sets `KOOKIE_RUN_NATIVE_PRESENTATION=1`, requires
  `KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER`, and runs the extracted
  `kookie.exe` through that wrapper with a native display/session.
- `scripts/validate_presentation_evidence.py` requires present capability,
  positive GPU draw time, audio-open, screenshot checksum, a bounded P6 PPM and
  the D1 gameplay/restart plus G0/G1/G2/G4/Kutter markers. It writes the
  machine, OS, wrapper, command, log hash and screenshot hash to `evidence.json`.
- `release_demo.yml` uploads the Linux evidence artifact when Linux smoke is
  enabled and the Windows evidence artifact when native Windows smoke is
  enabled. `run_windows_wine_smoke` remains package compatibility evidence only.

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
- The GUI shell now has a consistent framed hierarchy, selected-row rails,
  screen-specific subtitles, bounded text clipping and explicit keyboard hints
  across main, options, multiplayer, accessibility and Kutter. The main menu
  exposes Play, Multiplayer, Options, Accessibility, Kutter and Quit.
  Accessibility changes HUD scale (85/100/115 percent), tactical-map visibility
  and high-contrast text while preserving fixed staging budgets. The expanded
  `scripts/verify_multiplayer_ui.sh` probe stages five shell frames in JVM and
  native paths; `scripts/verify_font_ui.sh` covers the bundled font/title path.

- The current GUI qualification build produced
  `0.1.0-gui.1` from source commit
  `b1d4db92bf3adf166d503ca0eb44d8569498950c`; its Linux archive SHA-256 is
  `d9b909a4270fc9ca8fbd46a63bd0a21bc646e819da2ae6c3f89fa143dc1da902`.
  Deterministic duplicate builds, signatures, extraction and package smoke
  passed. This uses the temporary pinned SDL_mixer 3.2.4 prefix and an
  ephemeral key, so it is a local qualification artifact, not a public
  release. The isolated overzeer presentation attempt was fail-closed by
  full I/O PSI (`62.54%` blocked) and retains no hardware presentation
  evidence; a separate full verification attempt also stopped at the
  pressure-sensitive simulation p95 budget (`4153us > 4000us`).

- The focused dedicated-server gate now passes 512 measured ticks with p95
  `3624us`, p99 `3689us` and maximum `3899us` under the `4000us` simulation
  budget; the earlier full orchestration overrun was pressure-sensitive.

- The current source commit
  `87d3bc63b3bbc66c23f796258f5b9ea5147fb0df` also produced local native
  package `0.1.0-perf.2`; its archive SHA-256 is
  `3d40aa2c012e610c460379c5ca0c62ecf0cc30b6bba57165bfe45c2dee8c8014`.
  Extracted package smoke passed, and the packaged dedicated server passed the
  4ms p95 gate (`3396us` in the retained run). This is not a public release.

- The fixed-tick input/ACK, peer-pinning, rewind and remote-interpolation
  helpers are covered by focused G6 checks; they do not replace target-host
  gameplay evidence.
- `bash scripts/verify_goose_game.sh` proves the focused goose gameplay path.

### P0 — Linux release qualification

- The paired `0.1.0-dogfood.38` Linux archive is the current qualification
  artifact for the signed `presentation` runtime. The release workflow built
  it from one source/toolchain identity; deterministic packaging, signatures,
  safe extraction and package smoke passed.
- The remaining Linux gates are outside-checkout launch/restart/quit on a fresh
  supported system and the real present-capable GPU smoke defined above. They
  must retain the machine, driver, wrapper, screenshot, log and exit evidence.
  This is separate from the artifact/package gate.
- Verify the final archive outside the checkout on a fresh supported Linux
  system: signature/checksum, extraction, launch, `Play`, movement/look/fire,
  damage, restart, quit and repeated relaunch.
- Run the isolated present-capable GPU smoke and retain machine, driver,
  wrapper, screenshot and exit evidence. The default system image lacks
  SDL3_mixer development files; configure a pinned SDL_mixer 3.2.4 prefix
  before invoking the package gate.
- This workstation's isolated Xvfb/DRM run reported `No DRI3 support
  detected` and `No supported SDL_GPU backend`; it is not Linux hardware
  presentation evidence.
- Document the tested loader/libc/GPU floor. SDL3 and SDL_mixer are bundled,
  but arbitrary distribution compatibility is not implied.

- `scripts/verify_linux_presentation_package.sh` verifies the extracted signed
  archive and can run the packaged presentation through the isolated wrapper.
- `scripts/build_demo_release.sh` is the clean-tree release builder: it creates
  two byte-identical packages, verifies signatures and provenance, extracts the
  archive outside the checkout and runs package smoke.

### P0 — Windows release qualification

- The paired `0.1.0-dogfood.38` Windows ZIP includes native Kof PE,
  SDL3/SDL_mixer DLLs, SPIR-V/DXIL shaders, notices and provenance.
  `scripts/verify_windows_presentation.sh` passed reproducible signed
  PE/SDL/SPIR-V/DXIL qualification; this does not prove Windows hardware
  presentation.
- The remaining Windows gates are outside-checkout launch and repeated
  `Play`/restart/quit on supported hardware, followed by the native wrapper
  smoke and retained GPU/input/audio evidence. Wine remains compatibility
  evidence only.
- A clean detached-worktree run of `scripts/build_demo_release.sh` produced
  `0.1.0-windows-e2e.1` from source commit
  `1678a7de671866d94080718c367ab05875a92c2d` with Kof source commit
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`. The archive SHA-256 is
  `c8153ae34b2a1ea7f8c85411df95393c02573fc433a477c539153459975e80a4`.
  Outside-checkout verification passed duplicate-build determinism,
  detached signatures, `SHA256SUMS`, safe ZIP extraction, the `kookie.exe` PE
  `MZ` header, clean-tree/Windows-presentation manifest fields and bundled
  SPIR-V/DXIL entries. The qualification key was temporary, so this is not a
  public release artifact.
- An optional isolated Wine presentation smoke reached the native SDL shell but
  exited with code 70 and `kookie_gpu_open: No supported SDL_GPU backend
  found!`. This is environment evidence only and does not replace Windows
  hardware presentation evidence.
- Verify extraction, launch and repeated `Play`/restart/quit outside the
  checkout on supported Windows hardware and drivers.
- `scripts/build_demo_release.sh` writes the final clean-tree Windows archive,
  manifest, signatures, `SHA256SUMS` and build summary after deterministic
  double-build verification.
- Retain native Windows GPU/input/audio evidence. Wine proves the package path
  only; the optional visual Wine smoke requires an isolated DRI3-capable GPU.
- Decide whether ordinary-user distribution requires Authenticode signing;
  SmartScreen-facing distribution still needs it.



### P1 — paired distribution and release operations

- The paired `0.1.0-dogfood.38` Linux/Windows archives are published with
  manifests, public key, detached signatures and `SHA256SUMS`.
- Run `.github/workflows/release_demo.yml` with `publish=false` for future
  qualification; its approved `publish=true` path requires the
  `kookie-demo-release` environment approval and builds the Linux/Windows pair
  before publication.
- Self-hosted runners must carry `kookie-demo-release`, `linux`/`windows` and
  `x64` labels; `.github/actionlint.yaml` declares the custom label for local
  workflow linting.
- Publication does not replace native target-hardware evidence. Attach the
  Linux and Windows evidence artifacts from the executable D1 contract before
  promoting this dogfood package to a player-facing release.
- Add release notes containing controls, supported floors, known limitations,
  exact source/toolchain identities and the multiplayer best-effort boundary.

### P1 — content and product boundary

- The first demo ships the fixed authored arena with `content_profile=none`;
  the separate prototype content package remains opt-in and is not part of the
  release artifact.
- Resolve redistribution terms for every bundled asset. The prototype goose
  asset remains restricted by its upstream terms and is not included here.
- Keep the Prildarill cat out of the release package until standalone raw-file
  redistribution is explicitly confirmed; it remains prototype-only.
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
NAT recovery, production WAN security, HRTF/EFX, streamed audio and codecs
outside the bounded OGG Vorbis/WAVE set, a general extension sandbox, macOS/ARM
support and broad GPU coverage remain separate milestones. They must not be used
to expand this bounded goose game claim, but they also do not block the scoped
source implementation.

The implementation plan tracks this work as **D1 — Playable demo release** in
[ENGINE_PLAN.md](../docs/ENGINE_PLAN.md). Build and qualification commands remain
in [RUNNING_AND_PACKAGING.md](../docs/RUNNING_AND_PACKAGING.md).
