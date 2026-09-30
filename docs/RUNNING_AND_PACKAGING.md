# Running and packaging KOOKIE

[Português (Brasil)](../pt-BR/docs/RUNNING_AND_PACKAGING.md)

This page keeps build, package and qualification detail out of the project
homepage. KOOKIE is experimental: these commands exercise bounded evidence
contracts, not a production support promise.

## Developer run

Install [Kof 0.5.0-beta](https://github.com/KofLang/Kof4j) and Python 3, then
run the authoritative demo from the repository root:

```bash
kof run src/main.kf --target native
```

The JVM target exists for local differential qualification:

```bash
kof run src/main.kf --target jvm
```

It is not a distributable fallback. KOOKIE release archives do not include or
require a JVM.

Run the focused gameplay and replay probe with:

```bash
bash scripts/verify_interactions.sh
```

## Content cooker

The developer launcher admits only documented, bounded source subsets. It
rejects malformed, oversized or unsupported input without publishing a
successful product.

```bash
scripts/kookie_cooker.sh cook map level.map level.kmesh
scripts/kookie_cooker.sh cook dust3d model.ds3 model.glb model.kmesh
scripts/kookie_cooker.sh cook blockbench character.bbmodel character.kchar
scripts/kookie_cooker.sh cook png texture.png texture.rgba.png
scripts/kookie_cooker.sh cook wav effect.wav effect.pcm16.wav
scripts/kookie_cooker.sh package 4 level.kmesh data/level.kmesh level.kpkg
scripts/kookie_cooker.sh inspect-package level.kpkg
scripts/kookie_cooker.sh validate-package creator.kpkg
```

Source formats are authoring inputs, not runtime package formats. Linux
archives include a native `kookie-cooker` for the `cook` commands above;
package assembly and inspection remain in the JVM developer launcher.

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
- `kookie-cooker`, the native bounded source cooker;
- `kookie-simd-bench`, the scalar/SIMD parity and timing probe.

The server reports counts, work budgets, p50/p95/p99/max tick time, RSS range,
checksum and logical resource plateau. It is qualification tooling, not a
packaged production hosting service. The SIMD route decision is measurement
output for its exact reduction workload, not a general speedup claim.

## Linux SDL presentation package

Build the persistent SDL3/SDL_GPU presentation used for isolated visual
qualification and ZEER dogfood deployment:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.N \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime presentation --target linux-x86_64
```

This profile requires SDL 3.4.16, SDL_mixer 3.2.4, `glslc`, a C compiler and
`pkg-config`. The archive contains the Kof menu/game application, SDL adapter,
SPIR-V shaders, SDL3 and SDL_mixer. It uses the host dynamic loader and libc.

### Controls

- Main menu: arrow keys or WASD.
- Select: Enter, Space or mouse click.
- Back: Escape.
- Options: 1280×720 through 2560×1440, windowed/borderless/exclusive
  fullscreen, separate effects/music volume and three text sizes.
- Multiplayer: Host, Join and Leave with editable IPv4 and port fields.

Display changes commit only on Apply. Lobby packets use SipHash tags and replay
sequences. A configured 128-bit shared key authenticates peers; the local
fallback only detects accidental corruption. The lobby provides neither
encryption nor public identity.

## Windows x86-64 shell

Build the native shell from the official MinGW development packages for SDL
3.4.16 and SDL_mixer 3.2.4:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/path/to/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/path/to/SDL3_mixer/x86_64-w64-mingw32 \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target windows-x86_64
```

The ZIP contains `kookie.exe`, `SDL3.dll`, `SDL3_mixer.dll`, licenses and
provenance. It contains no JDK. The menu/options/lobby shell is interactive and
persistent, but Kof cannot currently emit Windows PE gameplay code. Linux
remains the authoritative native gameplay target.

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

## Graphical qualification isolation

Never run KOOKIE graphical checks against the active desktop or physical
monitors. Supply a reviewed disposable isolation wrapper through
`KOOKIE_PRESENTATION_ISOLATION_WRAPPER`; it must provide private display and
session sockets, a bounded timeout and complete process-tree cleanup.

Offscreen SDL checks prove lifecycle and GPU-resource behavior, not real window
presentation. Use `KOOKIE_SDL_VIDEO_DRIVER=x11` only with an isolated
present-capable environment. Set
`KOOKIE_SCREENSHOT_PATH=/absolute/path.ppm` to retain a qualified frame.
