# Running and packaging KOOKIE

[Português (Brasil)](../pt-BR/docs/RUNNING_AND_PACKAGING.md)

This page keeps build, package and qualification detail out of the project
homepage. KOOKIE is experimental: these commands exercise bounded evidence
contracts, not a production support promise.

## Developer/source run

Install [Kof 0.5.0-beta](https://github.com/KofLang/Kof4j) to run the
authoritative source entrypoint from the repository root:

```bash
kof run src/main.kf --target native
```

This command is a console qualification path. It does not launch the
interactive packaged game. `kof run` itself does not require Python 3; Python
is currently used by repository lint, package/provenance validation, evidence
validation and rendezvous tooling.

The published package includes a self-contained update launcher:

- Linux: `kookie-launcher`
- Windows: `kookie-launcher.exe` or `kookie-launcher.cmd`

The launcher requires neither Kof nor Python at runtime. On every normal start
it queries the GitHub releases API for `rufl/KOOKIE`, selects the newest
non-draft published release containing the current target's package, signed
manifest and manifest signature, and updates before launching the game. The
current package channel is `dogfood`; prereleases are intentionally included.
It never downloads an unsigned mutable `latest` URL.

The update path is:

1. Validate HTTPS URLs (plain HTTP is accepted only for localhost fixture
   tests).
2. Verify the Ed25519 manifest signature against the public key embedded in
   the launcher.
3. Stream the archive to a private state directory and verify its exact size
   and SHA-256 from the signed manifest.
4. Reject archive traversal, absolute paths and symlinks; extract to a new
   staging directory and run `kookie --package-smoke`.
5. Atomically activate the validated package and retain the previous marker.
On startup, a bundled `PROVENANCE.txt` version is a local floor: an older or
equal public release is not activated, so a dogfood package is not silently
downgraded while its newer release is not yet published.


State is stored in `$XDG_STATE_HOME/kookie` or
`$HOME/.local/state/kookie` on Linux, and `%LOCALAPPDATA%\KOOKIE\state` on
Windows. `--state-dir PATH` and `KOOKIE_STATE_DIR` override this location.

Useful commands:

```bash
./kookie-launcher              # update, then launch
./kookie-launcher --check      # update/check without launching
./kookie-launcher --offline    # use the active package without network access
./kookie-launcher --self-test  # validate the embedded launcher key/target
```

Run the focused local signed-update fixture with:

```bash
bash scripts/verify_launcher.sh
```

Windows has equivalent `.exe` arguments; `kookie-launcher.cmd` forwards them.
`--check` and `--no-launch` return an error instead of silently falling back
when an update fails. Normal starts fall back to the last active package, if
one exists. The package-local `kookie`/`kookie.exe` remains the direct game
wrapper; `kookie --package-smoke` is the graphics-free package qualification
path.

The launcher is intentionally a separate native binary rather than the ZTASH
GUI: it reuses ZTASH's bounded download/archive/rollback safety model without
making KOOKIE releases depend on ZLAY, ZFONT, GLFW or the full ZTASH build.
The launcher currently targets Linux and Windows x86_64.

The Windows presentation package requires an interactive desktop session for
the SDL video/GPU window. A service receiver without that session cannot pass a
full `launch` action; use the bounded `--package-smoke` probe for service
qualification. The launcher keeps the desktop launch path unchanged and
reports a nonzero dogfood game exit instead of treating a headless presentation
failure as a successful launch.


The JVM target is used for local differential qualification and for the
explicit Windows compatibility package:

```bash
kof run src/main.kf --target jvm
```

It is not a silent fallback for Linux or the native SDL presentation profile.
Only `--runtime jvm --target windows-x86_64` distributes a JVM.

Run the focused gameplay and replay probe with:

```bash
bash scripts/verify_interactions.sh
```

Run the focused goose-versus-bots/session/overlay probe with:

```bash
bash scripts/verify_goose_game.sh
```

Run the focused multiplayer lobby and scoreboard probe with:

```bash
bash scripts/verify_multiplayer_ui.sh
```

## Content kooker

The developer launcher admits only documented, bounded source subsets. It
rejects malformed, oversized or unsupported input without publishing a
successful product.

```bash
scripts/kooker.sh cook map level.map level.kmesh
scripts/kooker.sh cook dust3d model.ds3 model.glb model.kmesh
scripts/kooker.sh cook blockbench character.bbmodel character.kchar
scripts/kooker.sh cook png texture.png texture.rgba.png
scripts/kooker.sh cook wav effect.wav effect.pcm16.wav
scripts/kooker.sh cook svg icon.svg icon.svgc
scripts/kooker.sh cook svgz icon.svgz icon.svgc
scripts/kooker.sh package 4 level.kmesh data/level.kmesh level.kpkg
scripts/kooker.sh inspect-package level.kpkg
scripts/kooker.sh validate-package kutter.kpkg
```

Source formats are authoring inputs, not runtime package formats. Linux
archives include a native `kooker` for the `cook` commands above;
package assembly and inspection remain in the JVM developer launcher.

## Offline KofScript products and sandbox

The KofScript wrapper emits canonical behavior, animation and sandbox-bytecode
artifacts without duplicating their runtime schemas:

```bash
scripts/kookie_kofscript_builder.sh behavior build/enemy.kofart
scripts/kookie_kofscript_builder.sh animation build/player-animation.kofart
scripts/kookie_kofscript_builder.sh script build/bounty.kofart
```

Execute a sandbox artifact against an admitted domain event on either Kof
target:

```bash
scripts/kookie_kofscript_runtime.sh build/bounty.kofart 7 1 3 1 42 2 20
KOOKIE_KOFSCRIPT_RUNTIME_TARGET=native \
  scripts/kookie_kofscript_runtime.sh build/bounty.kofart 7 1 3 1 42 2 20
```

The VM has forward-only control flow, fixed stack/instruction/output budgets
and capability-masked outputs. It has no filesystem, network, native-handle or
raw-array opcode; artifact loading occurs outside the sandbox.

## Signed Linux package

The release builder requires a clean source tree, exact Kof source identity,
verified Kof distribution digest and an owner-private Ed25519 key:

```bash
KOOKIE_VERSION=0.1.0-dogfood.N \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target linux-x86_64
```

The private key must be a regular mode-`0600` file. The packager also needs
Zig to build the native update launcher. It emits a Linux-targeted archive,
detached archive and manifest signatures, `SHA256SUMS`, a public key and
provenance JSON. Provenance binds the clean source commit, pinned Kof source
commit, compiler JAR hash and distribution archive hash.

Every Linux archive also contains the native `kookie-launcher` update entrypoint:

- `kookie-launcher`, which discovers the newest signed target release before
  starting the package game;

- `kookie-server`, a graphics-independent bounded workload server;
- `kooker`, the native bounded source kooker;
- `kookie-simd-bench`, the scalar/SIMD parity and timing probe.

The server reports counts, work budgets, p50/p95/p99/max tick time, RSS range,
checksum and logical resource plateau. It is qualification tooling, not a
packaged production hosting service. The SIMD route decision is measurement
output for its exact reduction workload, not a general speedup claim.

## Prototype content package

The first content profile stages a bounded, signed asset catalog under
`content/prototype`. It includes the converted GLB library from the Rgsdev
modular pack (75 greybox pieces plus the existing character asset), the
Classic64 pack, the requested animated goose, authored VFX PNGs, bounded
runtime PNG derivatives, cooked RGBA8 PNG outputs, and retained source
notices. `greybox_modules.json` is the editor-facing catalog: it binds each
module to its runtime GLB, 1-grid placement/snap metadata, collision role and
free texture-override policy. The Kutter Level Editor adds Zylve-style
placement tools and validation, plus MudLump-style grid/cursor workflow and
bounded undo/redo, while persisting through the existing Kof studio wire
format. It is opt-in so existing runtime packages remain content-free:

```bash
KOOKIE_VERSION=0.1.0-dogfood.prototype \
KOOKIE_BUILD_ID=prototype-content \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target linux-x86_64 \
  --content prototype
```

To run the native SDL presentation with the prototype goose and cat models,
build the presentation profile explicitly:

```bash
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime presentation --target linux-x86_64 \
  --content prototype
```

`G1NativePresentation` resolves `goose.glb` and `cat.glb` through the native
bounded model loader and submits their triangles to the SDL_GPU world pass.
The content-free `none` profile keeps the bounded procedural silhouette
fallback; it does not redistribute the prototype models.

`assets/prototype/manifest.json` binds the selected source paths, archive
SHA-256 values, converted output paths, frame grids, and license notices.
Package `PROVENANCE.txt` and the signed JSON manifest record the deterministic
prototype-content tree digest and file/asset counts.

The modular, Brackeys VFX and Classic64 notices identify CC0 sources. The
goose page is not CC0: it permits commercial use and editing but prohibits
reselling or redistributing the model file. It remains prototype-only by
explicit request; do not redistribute that asset as CC0.

The prototype catalog also contains the attributed Prildarill low-poly cat
source and GLB. Its source page permits use and editing and says credit is not
required; KOOKIE retains attribution voluntarily. No SPDX license or
standalone raw-file redistribution grant is stated, so the cat source and GLB
remain prototype-only and must not be advertised as CC0 or an independent
asset pack.
The native gameplay presentation uses the prototype `goose.glb` and `cat.glb`
when that profile is present. Their bounded vertex counts, materials,
positions, facing, animation state and attack/movement state are transferred
through the checked native model API; no unbounded mesh data enters the Kof
frame staging buffers.

The catalog also stages Echo Studios' five-state player-heart sheet at
`ui.player-hearts`. Its authored copy preserves the supplied 320x64 PNG; the
bounded runtime derivative is cooked from a 160x32 nearest-neighbor copy, and
the native presentation samples those five states into the 2D billboard atlas.
The source page is a name-your-own-price download but does not state a
standard license or standalone redistribution terms. Keep the heart asset
prototype-only; see `licenses/echo-studios-heart-terms.txt`.
The native gameplay presentation also stages the bounded Zylve-style tactical
map as a round upper-right overlay. `G1NativePresentation.setCooperativeMode`
is the mode seam: cooperative matches show local and remote player markers;
PvP suppresses both player markers while retaining the map and non-player
markers.

## SDL3/SDL_mixer development dependencies

The Linux gates accept SDL 3.4.16 and SDL_mixer 3.2.4 through `pkg-config`.
The shared resolver also accepts `KOOKIE_SDL3_PREFIX` and
`KOOKIE_SDL3_MIXER_PREFIX`, validates the exact header/package versions and
adds the selected library directory to the local smoke path. It does not
silently accept an older mixer or an unreviewed runtime library.

When the host has SDL3 but no SDL_mixer development package, prepare the
pinned local prefix:

```bash
bash scripts/bootstrap_sdl3_mixer.sh
```

The bootstrap also requires CMake, a C compiler and `curl` or `wget`; the host
SDL3 development files remain required.

The bootstrap verifies the official SDL_mixer 3.2.4 archive SHA-256, builds
the WAVE and bundled `stb_vorbis` backends, and installs into the ignored
`.kookie-deps/sdl3-mixer-3.2.4` prefix. For an offline reviewed source tree:

```bash
KOOKIE_SDL3_MIXER_SOURCE=/path/to/SDL_mixer-3.2.4 \
  bash scripts/bootstrap_sdl3_mixer.sh
```

### OGG Vorbis music and SFX

The developer cooker admits bounded OGG Vorbis and preserves the validated
pages byte-for-byte:

```bash
scripts/kooker.sh cook ogg input.ogg cooked.ogg
```

The cooker validates the single logical Vorbis stream, page CRCs and sequence
state, Vorbis headers, decoded-frame bounds and optional `LOOPSTART`,
`LOOPEND`/`LOOPLENGTH` sample-frame comments. Runtime SDL_mixer predecodes the
canonical payload with the pinned `stb_vorbis` backend; loop start/end/count
are sample-frame properties, not wall-clock approximations.

To enable an OGG soundtrack in the native adapter, set the path before launch:

```bash
KOOKIE_AUDIO_MUSIC_OGG=/absolute/path/theme.ogg ./kookie
```

The existing `assets/audio/ui/*.ogg` catalog is loaded as predecoded SFX tracks
and exposes exact loop bounds through the native UI-clip API. For presentation
or native Windows packages, `package_kookie.sh` also copies `.ogg` files found
under optional `assets/audio/music/` and `assets/audio/sfx/` directories;
runtime code only auto-starts the explicitly configured soundtrack path.

Without `KOOKIE_AUDIO_MUSIC_OGG`, the previous generated PCM music/effects
streams remain unchanged.

After preparation, `package_kookie.sh`, `verify.sh`, the external-LAN native
gates and the G5 renderer gate discover the prefix automatically. The
presentation package still bundles only the resolved SDL3/SDL_mixer runtime
libraries; host libc and the dynamic loader remain outside the archive.
The presentation archive also contains
`build/libkookie_persistence_adapter.so`; the Kof save owner uses that single
stateful bridge for staging, publication and confirmation, while SDL rendering
remains in `build/libkookie_sdl_adapter.so`.

## Linux SDL presentation package

Build the persistent SDL3/SDL_GPU presentation used for isolated visual
qualification and signed dogfood releases:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.N \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime presentation --target linux-x86_64
```

For a clean-tree package extraction and signature smoke, use:

```bash
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/verify_linux_presentation_package.sh
```

For a release artifact, build two byte-identical packages and write the
verified artifact set to an empty output directory:

```bash
KOOKIE_VERSION=0.1.0-demo.N \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/build_demo_release.sh \
  --target linux-x86_64 \
  --version 0.1.0-demo.N \
  --output /tmp/kookie-demo-linux
```

The builder requires a clean tree and does not claim native GPU evidence.
The 2026-10-02 qualification batch passed
`verify_linux_presentation_package.sh` with a temporary pinned SDL_mixer 3.2.4
prefix. It verified the signed archive, safe extraction and package smoke on
the current checkout; it did not prove a present-capable Linux GPU or the final
clean-tree paired release.


This profile requires SDL 3.4.16, SDL_mixer 3.2.4, `glslc`, a C compiler and
`pkg-config`. The archive contains the Kof menu/game application, SDL adapter,
SPIR-V shaders, SDL3 and SDL_mixer. It uses the host dynamic loader and libc.
Presentation archives also include `DEMO_CONTROLS.txt`. The default
presentation command uses the `none` content profile and does not redistribute
prototype assets; pass `--content prototype` to package the goose/cat model
demo explicitly.

### Controls

- Main menu: arrow keys or WASD.
- Select: Enter, Space or mouse click.
- Back: Escape.
- `Play`: local authoritative listen-server/client encounter; re-enter `Play`
  after Escape to reset the bounded encounter.
- Gameplay: `W`/`S` move forward/backward and `A`/`D` strafe relative to
  horizontal mouse look; vertical mouse look pitches the locked follow camera,
  the mouse wheel zooms it, and authored collision stops it at walls.
- Fire: `F` or left mouse button. Jump: `Ctrl`.
- Options: 1280×720 through 2560×1440, windowed/borderless/exclusive
  fullscreen, separate effects/music volume and three text sizes.
- Accessibility: HUD scale (`SMALL` 85%, `MEDIUM` 100%, `LARGE` 115%),
  tactical-map visibility and high-contrast text. Changes apply live in the
  presentation shell and retain fixed staging budgets.
- Multiplayer: Host, Join and Leave with editable IPv4 and port fields.
  After the peer connects, select `READY` on both clients before gameplay opens;
  the lobby shows the bounded peer identity, player count and honest ping
  placeholder until an RTT exists.
- During gameplay, `Tab` toggles the player screen; it shows player, status,
  score, HP, K/D and ping. `--` means RTT is not available yet.

Display changes commit only on Apply. Lobby packets use SipHash tags and replay
sequences. A configured 128-bit shared key authenticates peers; the local
fallback only detects accidental corruption. The lobby provides neither
encryption nor public identity.
### GUI qualification

The shell polish and accessibility settings are covered by bounded model/staging
probes:

```bash
bash scripts/verify_font_ui.sh
bash scripts/verify_multiplayer_ui.sh
bash scripts/verify_goose_game.sh
```

The multiplayer probe stages the main, options, accessibility, multiplayer and
Kutter shell frames on JVM and native paths. Graphical validation MUST use
`overzeer-isolated-display`; plain Xvfb or the active desktop is not evidence.

The current workstation's 2026-10-02 isolated attempt was fail-closed by full
(`62.54%` blocked), and the full orchestrator separately exceeded the
pressure-sensitive simulation p95 budget (`4153us > 4000us`). The local
`0.1.0-gui.1` package passed signed extraction and package smoke, but native
GPU presentation evidence remains open.

An earlier focused qualification record passed 512 measured ticks at p95
`3624us`, p99 `3689us` and maximum `3899us` under the declared `4000us`
simulation budget. The latest result below supersedes it for the current source;
the prior full-orchestration overrun remains recorded as pressure-sensitive.

The latest focused native run after the authoritative-path optimization uses
the package qualification window: 128 warm-up ticks and 512 measured ticks.
It recorded p50/p95/p99/max `3805/3925/3958/4936us`, workload checksum
`217802`, resource signature `520690`, and 64 KiB RSS growth/range under the
unchanged `4000us` p95 budget. `scripts/verify_package.sh` uses this same
window rather than a shorter cold-start sample.
The scalar enemy path, target-position cache and batched loot/reference-scene
checksum updates preserve the `217802` JVM/native workload checksum.

The current source commit also has a local native-only qualification package
`0.1.0-perf.2`, with archive SHA-256
`3d40aa2c012e610c460379c5ca0c62ecf0cc30b6bba57165bfe45c2dee8c8014`.
Its extracted package smoke and packaged dedicated-server p95 gate passed; it
is not a public release or a presentation artifact.

### Simple WAN goose session

Run the small authenticated rendezvous on a reachable Linux host:

```bash
KOOKIE_TRANSPORT_KEY_HEX=00112233445566778899aabbccddeeff \
python3 scripts/kookie_rendezvous.py --bind 0.0.0.0 --port 47101
```

The rendezvous refuses a missing, malformed or all-zero shared key, and never
evicts an existing two-player room when a third client presents the same code.

Start the Linux or Windows `presentation` client with the same key and:

```bash
export KOOKIE_WAN_RENDEZVOUS=1
export KOOKIE_RENDEZVOUS_HOST_IPV4=203.0.113.20
export KOOKIE_ROOM_CODE=4107
export KOOKIE_PLAYER_NAME_ID=1
export KOOKIE_TRANSPORT_KEY_HEX=00112233445566778899aabbccddeeff
./kookie
```

Use `Multiplayer > Host` on one client and `Multiplayer > Join` on the other.
After both clients show the peer as connected, select `READY` on both clients
to open gameplay. `Tab` opens the deterministic player screen; Escape returns
to the menu, and selecting `Play` starts a fresh local encounter.

The rendezvous authenticates the fixed UDP envelope, records each public UDP
endpoint, sends the peer endpoint, and stops relaying. Both clients then send
direct authenticated datagrams repeatedly for simple UDP hole punching. This is
best-effort: symmetric NAT, blocked UDP, or some CGNAT topologies require a
forwarded game port or a direct LAN address. It provides no relay, encryption,
identity service, or production DDoS protection. Leave
`KOOKIE_WAN_RENDEZVOUS` unset for direct LAN mode.

The gameplay path uses typed authoritative snapshots and fixed-tick input
bundles. Each bundle repeats up to three ordered inputs and carries the last
snapshot ACK; the host returns an input ACK. Newer ticks supersede older
snapshots, while a higher state sequence may replace the latest sample at the
same tick for lifecycle or stale-command diagnostics. This is the bounded
reliability layer used over the authenticated UDP envelope. It is not a
QUIC-compatible wire protocol.

The host retains a 12-tick bounded position history for hitscan lag
compensation. It derives a rewind tick from the acknowledged snapshot lag and
uses the historical source/target distance; clients render remote player
positions six ticks behind the live tick. These limits are deterministic and
do not provide sub-tick QUIC semantics.

Restoring an earlier replay checkpoint clears rewind samples from the discarded
future before fixed-tick advancement resumes.

The Linux package also contains `kookie-rendezvous.py`. The rendezvous can run
on Linux while both game clients run Linux or Windows.

### Run the currently published Linux dogfood

The latest public dogfood release is
[`0.1.0-dogfood.38`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.38).
It contains signed Linux and Windows x86-64 artifacts built from source commit
`a86d55eddb0aae2f0a7e05fb59033560d34c95c7`. For the Linux package, download
the release assets, then verify the checksum set and detached signatures:

```bash
sha256sum --check SHA256SUMS
openssl pkeyutl -verify -rawin -pubin \
  -inkey kookie-0.1.0-dogfood.38-linux-x86_64.pub.pem \
  -in SHA256SUMS -sigfile SHA256SUMS.sig
openssl pkeyutl -verify -rawin -pubin \
  -inkey kookie-0.1.0-dogfood.38-linux-x86_64.pub.pem \
  -in kookie-0.1.0-dogfood.38-linux-x86_64.tar.gz \
  -sigfile kookie-0.1.0-dogfood.38-linux-x86_64.tar.gz.sig
tar -xzf kookie-0.1.0-dogfood.38-linux-x86_64.tar.gz
cd kookie-0.1.0-dogfood.38-linux-x86_64
./kookie
```

The archive bundles SDL3, SDL_mixer and the native adapters, but uses the host
dynamic loader/libc and requires a supported presentation-capable Linux GPU.
This is the current-source dogfood package; target-hardware presentation
evidence remains an open D1 gate.


## Windows x86-64 packages

### Reachable Kof PE/COFF compiler


The pinned compiler bridge lowers the reachable optimized Kof IR graph to
deterministic C11, then uses Zig 0.16.0 to emit an AMD64 COFF object and
Windows PE:

```bash
scripts/kof_pe_build.sh path/to/main.kf --output build/kof-pe
scripts/verify_kof_pe_backend.sh
```

The standalone output is `kof-module.c`, `kof-module.obj` and
`kof-module.exe`. Add `--library` to emit the C/object module with the
exported `kookie_kof_gameplay_main` entry for a native host. The retained gate
builds twice, checks byte-for-byte reproducibility and PE/COFF headers,
compares generated-code output with the Kof JVM oracle, and proves unsupported
floating-point IR rejects with `PE001`.

The reachable target covers the current KOOKIE gameplay/presentation graph:
classes and fields, object and array allocation, integral/Boolean/String values,
locals, arithmetic, branches, loops, `print`/`println`, String `length` and
`charAt`, and integral FFI calls. It remains fail-closed for unsupported
floating-point IR, caught exceptions/concurrency, and non-integral FFI.
Generated allocations are process-lifetime; this target is for the bounded
gameplay workload, not an unbounded service.

The presentation probe uses `BoundedHostSessionSaveCoordinator` for the PE
reachable path. Kof encodes and validates the bounded wire; checked integral
FFI calls let the native persistence adapter stage/read schema bytes and run
the durable publish boundary without `File` or `String` FFI. The G7 native
probe and the G0 Play smoke verify fresh-session inventory restoration.

The no-SDL PE persistence qualification is:

```bash
bash scripts/verify_pe_durable_save.sh
```

### Native SDL shell

Build the native shell from the official MinGW development packages for SDL
3.4.16 and SDL_mixer 3.2.4:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/path/to/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/path/to/SDL3_mixer/x86_64-w64-mingw32 \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target windows-x86_64
```

The package links the complete reachable `src/` Kof gameplay PE object into
`kookie.exe`, alongside the native SDL3/SDL_mixer menu/lobby shell. It contains
`kookie.exe`, `SDL3.dll`, `SDL3_mixer.dll`, licenses and provenance; it contains
no JDK. The package smoke prints
`KOOKIE native Kof PE gameplay verified` after SDL initialization.

With `KOOKIE_RUN_WINE=1`, the isolated presentation smoke also requires the
`KOOKIE G7 native presentation durable save verified` marker. This exercises
the PE-safe scalar save bridge through the packaged Play path; the G0 owner
publishes on gameplay exit/window close and restores on process start/re-entry.
It does not replace native Windows hardware/GPU evidence.
Use `--runtime presentation` for the shared Kof SDL loop: it renders the
three-bot encounter, maps input, and supports the same direct/WAN transport as
Linux. A fresh Windows package still needs native hardware presentation smoke
before public release.

### Bundled Kof JVM runtime

The compatibility profile packages the Kof JVM artifact with one exact Windows
x64 OpenJDK runtime:

```bash
KOOKIE_WINDOWS_JAVA_ARCHIVE=/path/to/OpenJDK27U-jre_x64_windows_hotspot_27_35.zip \
KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256=e9cf542d5ffe2a894637b18c27a7802853976deaa3abe3e04dfbb8a307a145dd \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
SOURCE_DATE_EPOCH=<unix-timestamp> \
scripts/package_kookie.sh --runtime jvm --target windows-x86_64
```

The builder verifies the archive digest, safe ZIP paths, Windows x86-64 release
metadata, PE `java.exe` and retained runtime legal files. It builds and smokes
the canonical `kookie.jar`, then writes a timestamp-normalized,
deterministically ordered signed ZIP. This remains a compatibility profile;
the native PE/SDL profiles do not depend on it.

### Native PE/SDL_GPU presentation package

The presentation profile lowers the native SDL presentation probe and its
reachable gameplay graph to PE, statically links the SDL3/SDL_mixer adapter,
and bundles both SPIR-V and DXIL shader products:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/path/to/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/path/to/SDL3_mixer/x86_64-w64-mingw32 \
KOOKIE_DXC=/path/to/dxc \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
SOURCE_DATE_EPOCH=<unix-timestamp> \
scripts/package_kookie.sh --runtime presentation --target windows-x86_64
```

`glslc` must be on `PATH`. `scripts/verify_windows_presentation.sh` rebuilds
the signed package twice, compares every archive/signature, validates safe ZIP
paths and retained licenses, and checks the native PE, SDL import libraries
and SPIR-V/DXIL entries. `KOOKIE_RUN_WINE=1` adds the optional compatibility
smoke; it requires `wine` and `overzeer-isolated-display`.

For target-hardware evidence, set `KOOKIE_RUN_NATIVE_PRESENTATION=1` and
provide `KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER`. The reviewed wrapper
must provide a private Windows display/session, bounded timeout and complete
process-tree cleanup; the script launches the extracted `kookie.exe`, validates
the D1 markers and P6 screenshot, and retains `native-evidence.json`.
For the publishable Windows artifact, use the clean-tree deterministic builder:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/path/to/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/path/to/SDL3_mixer-3.2.4/x86_64-w64-mingw32 \
KOOKIE_DXC=/path/to/dxc \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/build_demo_release.sh \
  --target windows-x86_64 \
  --version 0.1.0-demo.N \
  --output /tmp/kookie-demo-windows
```

The `0.1.0-dogfood.38` qualification batch passed
`verify_windows_presentation.sh` with pinned MinGW SDL3/SDL_mixer prefixes and
DXC. This proves the reproducible signed PE/SDL/SPIR-V/DXIL artifact path only;
native Windows input/audio/GPU/driver evidence and outside-checkout interactive
smoke remain release gates.

It writes the signed archive, manifest, public key, detached signatures,
`SHA256SUMS` and `BUILD_SUMMARY.txt`. Native Windows launch/input/audio/GPU
evidence remains a separate target-hardware gate.

On a supported Windows GPU with the reviewed native isolation wrapper, the full
smoke executes the same native Kof PE entry that owns the SDL window, GPU scene
staging, audio queue, kutter reload and gameplay markers. The package has no
JVM dependency. This remains target-specific evidence; it does not generalize
to other OS/GPU combinations or WAN/security qualification.

### Paired demo release workflow
For exact workstation paths, readiness checks, secret setup and dispatch commands, see [RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md).

`.github/workflows/release_demo.yml` is a manually dispatched, manually
approved workflow. It builds Linux and Windows packages independently, then
publishes them as one pre-release only after the `kookie-demo-release`
environment approves the publish job.

The workflow requires self-hosted runners with labels
`kookie-demo-release`, `linux`/`windows` and `x64`. Both runners need Kof
`0.5.0-beta` at the pinned source commit, Python 3, OpenSSL, `glslc`, Zig
0.16.0 and the pinned Kof distribution digest. The Linux runner additionally
needs SDL3 development files and an isolated display wrapper for optional
package presentation smoke; the workflow bootstraps the pinned SDL_mixer
prefix when its `pkg-config` entry is absent. The Windows runner additionally
needs MinGW SDL3/SDL_mixer prefixes and `KOOKIE_DXC`; native Windows smoke also
requires the reviewed `KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER`.

The hosted `verify.yml` job has a 45-minute budget because installing Wine
with both `wine64` and `wine32:i386` can exceed the old core budget on a cold
Ubuntu runner. The i386 architecture remains required because a win64 prefix
needs the `syswow64/rundll32.exe` helper.

Configure environment secrets `KOOKIE_SIGNING_KEY_PEM` and
`KOOKIE_KOF_ARCHIVE_SHA256`. Dispatch with `publish=false` for artifact-only
qualification. Set `publish=true` only after native Linux and Windows
launch/input/audio/GPU evidence has been retained with the release record.

### G6 bounded runtime probes

Run the non-graphical expansion qualification as one focused command:

```bash
bash scripts/verify_g6_runtime.sh
```

It compiles and executes safe worker publication, packaged KofScript/session
activation, persistent Kutter reopen/rollback and the fixed-window WAN channel.
The WAN result is limited to direct IPv4/UDP endpoints with a pre-shared key,
bounded retransmission and backpressure; it does not claim NAT traversal,
relay service, confidentiality or DDoS resistance.

## External-LAN qualification roles

Build the Windows JVM role bundle separately:

```bash
scripts/package_external_lan_roles.sh \
  --version 0.1.0-external-lan.1 \
  --build-id "${KOOKIE_BUILD_ID:-local}" \
  --output release/external-lan
```

The archive contains host/client JARs and Windows `.cmd` launchers, but no
transport key or run manifest. It is cross-host qualification tooling, not a
KOOKIE product package. Operational evidence stays outside this repository.
Revalidate a locally produced evidence bundle with:

```bash
python3 scripts/verify_external_lan_evidence_bundle.py \
  /path/to/external-lan-evidence.tar.gz
```

Run the same-host multi-process regression with:

```bash
KOOKIE_EXTERNAL_LAN_TARGET=jvm \
KOOKIE_EXTERNAL_LAN_MODE=processes \
bash scripts/verify_external_lan.sh
```

Use `KOOKIE_EXTERNAL_LAN_TARGET=native` for the native path. Same-host evidence
remains `externalHostExecution=unproven`.

## Repository verification gate

The complete gate is final pre-commit verification. In Pi sessions it requires
the user's one-shot `/precommit-matrix` permission:

```bash
bash scripts/verify.sh
```

During implementation, run only the smallest focused check that proves the
changed behavior.

The hosted GitHub Actions gate also runs `scripts/verify_kof_pe_backend.sh`.
Its PE checks parse the COFF/PE headers directly; they do not depend on the
platform-specific wording emitted by `file` for an AMD64 COFF object.

## Graphical qualification isolation

Never run KOOKIE graphical checks against the active desktop or physical
monitors. Supply a reviewed disposable isolation wrapper through
`KOOKIE_PRESENTATION_ISOLATION_WRAPPER`; it must provide private display and
session sockets, a bounded timeout and complete process-tree cleanup.

Offscreen SDL checks prove lifecycle and GPU-resource behavior, not real window
presentation. Use `KOOKIE_SDL_VIDEO_DRIVER=x11` only with an isolated
present-capable environment. Set
`KOOKIE_SCREENSHOT_PATH=/absolute/path.ppm` to retain a qualified frame.
