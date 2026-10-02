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

The published presentation package is self-contained: players launch its
`kookie`/`kookie.exe` entrypoint without installing Kof or Python. An
auto-installing, self-updating launcher with stable/beta/alpha/canary channels
is not published yet; see [Demo release readiness](DEMO_RELEASE.md) for the
current package and target-hardware gates.

### Launcher boundary

The launcher requested for the player workflow is not implemented or published
yet. Keep two responsibilities separate:

- **Player launcher:** downloads and launches only signed KOOKIE game packages.
  It must not install the Kof compiler or require Python at runtime.
- **Developer bootstrap:** optionally installs the exact pinned Kof toolchain
  needed for source qualification, then runs developer commands.

Stable, beta, alpha and canary are release channels, not arbitrary Git branch
checkouts. Each channel needs a signed manifest containing target, version,
artifact URL, SHA-256, signature, Kof identity and minimum runtime metadata.
The launcher must embed the release public key, verify HTTPS plus the manifest
signature and artifact hash, stage updates in a new directory, switch
atomically, retain one rollback version and require explicit opt-in for
non-stable channels. It must never execute an unsigned `latest` download or
replace a running installation.

The repository currently lacks the native launcher binaries, signed channel
manifests, published Kof toolchain artifacts for those channels and the
Windows Authenticode policy. Until those exist, direct source runs require Kof;
full repository qualification and package/evidence gates additionally require
Python, while the signed package remains the user path.




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

The private key must be a regular mode-`0600` file. The builder emits a
Linux-targeted archive, detached archive and manifest signatures,
`SHA256SUMS`, a public key and provenance JSON. Provenance binds the clean
source commit, pinned Kof source commit, compiler JAR hash and distribution
archive hash.

Every Linux archive also contains:

- `kookie-server`, a graphics-independent bounded workload server;
- `kooker`, the native bounded source kooker;
- `kookie-simd-bench`, the scalar/SIMD parity and timing probe.

The server reports counts, work budgets, p50/p95/p99/max tick time, RSS range,
checksum and logical resource plateau. It is qualification tooling, not a
packaged production hosting service. The SIMD route decision is measurement
output for its exact reduction workload, not a general speedup claim.

## Prototype content package

The first content profile stages a bounded, signed asset catalog under
`content/prototype`. It includes converted GLB models from the modular and
Classic64 packs, the requested animated goose, authored VFX PNGs, bounded
runtime PNG derivatives, cooked RGBA8 PNG outputs, and retained source notices.
It is opt-in so existing runtime packages remain content-free:

```bash
KOOKIE_VERSION=0.1.0-dogfood.prototype \
KOOKIE_BUILD_ID=prototype-content \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target linux-x86_64 \
  --content prototype
```

`assets/prototype/manifest.json` binds the selected source paths, archive
SHA-256 values, converted output paths, frame grids, and license notices.
Package `PROVENANCE.txt` and the signed JSON manifest record the deterministic
prototype-content tree digest and file/asset counts.

The modular, Brackeys VFX and Classic64 notices identify CC0 sources. The
goose page is not CC0: it permits commercial use and editing but prohibits
reselling or redistributing the model file. It remains prototype-only by
explicit request; do not redistribute that asset as CC0.

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
Presentation archives also include `DEMO_CONTROLS.txt`; the first demo uses
the `none` content profile and does not redistribute prototype assets.

### Controls

- Main menu: arrow keys or WASD.
- Select: Enter, Space or mouse click.
- Back: Escape.
- `Play`: local authoritative listen-server/client encounter; re-enter `Play`
  after Escape to reset the bounded encounter.
- Options: 1280×720 through 2560×1440, windowed/borderless/exclusive
  fullscreen, separate effects/music volume and three text sizes.
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
snapshot ACK; the host returns an input ACK. This is the bounded reliability
layer used over the authenticated UDP envelope. It is not a QUIC-compatible
wire protocol.

The host retains a 12-tick bounded position history for hitscan lag
compensation. It derives a rewind tick from the acknowledged snapshot lag and
uses the historical source/target distance; clients render remote player
positions six ticks behind the live tick. These limits are deterministic and
do not provide sub-tick QUIC semantics.

The Linux package also contains `kookie-rendezvous.py`. The rendezvous can run
on Linux while both game clients run Linux or Windows.

### Run the currently published Linux dogfood

The latest public package is
[`0.1.0-dogfood.34`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.34).
It is a signed Linux x86-64 presentation dogfood build from source commit
`4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`; it predates the current input/
session bridge, fixed-tick netcode, lobby/score screen and native Windows
PE/SDL qualification. Download the seven release assets, then verify the
checksum set and detached signatures:

```bash
sha256sum --check SHA256SUMS
openssl pkeyutl -verify -rawin -pubin \
  -inkey kookie-0.1.0-dogfood.34-linux-x86_64.pub.pem \
  -in SHA256SUMS -sigfile SHA256SUMS.sig
openssl pkeyutl -verify -rawin -pubin \
  -inkey kookie-0.1.0-dogfood.34-linux-x86_64.pub.pem \
  -in kookie-0.1.0-dogfood.34-linux-x86_64.tar.gz \
  -sigfile kookie-0.1.0-dogfood.34-linux-x86_64.tar.gz.sig
tar -xzf kookie-0.1.0-dogfood.34-linux-x86_64.tar.gz
cd kookie-0.1.0-dogfood.34-linux-x86_64
./kookie
```

The archive bundles SDL3, SDL_mixer and the native adapters, but uses the host
dynamic loader/libc and requires a supported presentation-capable Linux GPU.
That published commit predates the source-tree input/session bridge, fixed-tick
input/ACK path, lag-compensated rewind, remote interpolation, WAN rendezvous,
fixed Host/Join lobby, explicit ready gate and player screen. Rebuild the
presentation profile for the current playable goose path; the published
archive does not contain these changes.


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

The `native` profile's marker proves PE linkage and SDL initialization only.
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
and SPIR-V/DXIL entries. `KOOKIE_RUN_WINE=1` adds the optional full smoke; it
requires `wine` and `overzeer-isolated-display`.

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

The 2026-10-02 qualification batch passed
`verify_windows_presentation.sh` with pinned MinGW SDL3/SDL_mixer prefixes and
DXC. This proves the reproducible signed PE/SDL/SPIR-V/DXIL artifact path only;
native Windows input/audio/GPU/driver evidence and outside-checkout interactive
smoke remain release gates.

It writes the signed archive, manifest, public key, detached signatures,
`SHA256SUMS` and `BUILD_SUMMARY.txt`. Native Windows launch/input/audio/GPU
evidence remains a separate target-hardware gate.

On a DRI3-capable isolated host, the full smoke executes the same native Kof
PE entry that owns the SDL window, GPU scene staging, audio queue, kutter
reload and gameplay markers. The package has no JVM dependency. This remains
target-specific evidence; it does not generalize to other OS/GPU combinations
or WAN/security qualification.

### Paired demo release workflow

`.github/workflows/release_demo.yml` is a manually dispatched, manually
approved workflow. It builds Linux and Windows packages independently, then
publishes them as one pre-release only after the `kookie-demo-release`
environment approves the publish job.

The workflow requires self-hosted runners with labels
`kookie-demo-release`, `linux`/`windows` and `x64`. Both runners need Kof
`0.5.0-beta` at the pinned source commit, Python 3, OpenSSL, `glslc`, Zig
0.16.0 and the pinned Kof distribution digest. The Linux runner additionally
needs SDL3/SDL_mixer development files and an isolated display wrapper for
optional package presentation smoke. The Windows runner additionally needs
MinGW SDL3/SDL_mixer prefixes and `KOOKIE_DXC`.

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
