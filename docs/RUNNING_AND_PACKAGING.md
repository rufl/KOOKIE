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
- `kookie-cooker`, the native bounded source cooker;
- `kookie-simd-bench`, the scalar/SIMD parity and timing probe.

The server reports counts, work budgets, p50/p95/p99/max tick time, RSS range,
checksum and logical resource plateau. It is qualification tooling, not a
packaged production hosting service. The SIMD route decision is measurement
output for its exact reduction workload, not a general speedup claim.

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

## Windows x86-64 packages

### Bounded Kof PE/COFF compiler

The pinned compiler bridge lowers optimized Kof IR to deterministic C11, then
uses Zig 0.16.0 to emit an AMD64 COFF object and Windows console PE:

```bash
scripts/kof_pe_build.sh path/to/main.kf --output build/kof-pe
scripts/verify_kof_pe_backend.sh
```

The output is `kof-module.c`, `kof-module.obj` and `kof-module.exe`. The retained
gate builds twice, checks byte-for-byte reproducibility and PE/COFF headers,
compares generated-code output with the Kof JVM oracle, and proves unsupported
IR rejects with `PE001`.

This is an intentionally bounded compiler target: top-level functions,
integral/Boolean/String values, locals, arithmetic, branches, loops and
`print`/`println`. Classes, heap objects, arrays, exceptions, concurrency, FFI
and SDL calls reject instead of producing stubs. It therefore qualifies the
compiler route; it does not compile the full KOOKIE gameplay or presentation
module yet.

### Native SDL shell

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
persistent. The bounded compiler above can emit Windows console PE code, but
cannot yet lower the full KOOKIE gameplay/SDL IR. Linux remains the authoritative
native gameplay target.

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
metadata, PE `java.exe` and retained runtime legal files. It builds and smokes a
canonical executable `kookie.jar`, then writes a timestamp-normalized,
deterministically ordered signed ZIP. The package contains `kookie.cmd`,
`kookie.jar`, `runtime/`, `JAVA_RUNTIME.txt`, licenses and provenance; the
target machine needs no separately installed Java. `runtime/legal` and
`runtime/NOTICE` remain authoritative for the bundled OpenJDK licenses.

This profile runs the graphics-free Kof core. It does not replace the native
Windows SDL shell or claim a Windows SDL gameplay/presentation backend.
`scripts/verify_windows_jvm_package.sh` builds the package twice, compares every
signed artifact, verifies the signature set and runs the packaged JAR.
### SDL presentation compatibility package

The presentation profile combines the Kof JVM gameplay artifact with the
Windows SDL3/SDL_mixer adapter and both SPIR-V and DXIL shader products:

```bash
KOOKIE_WINDOWS_JAVA_ARCHIVE=/path/to/OpenJDK27U-jre_x64_windows_hotspot_27_35.zip \
KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256=e9cf542d5ffe2a894637b18c27a7802853976deaa3abe3e04dfbb8a307a145dd \
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
paths and retained licenses, and checks the SDL import library plus SPIR-V/DXIL
entries. `KOOKIE_RUN_WINE=1` adds the optional gameplay smoke; it requires
`wine` and `overzeer-isolated-display`. This profile is a bounded JVM gameplay
plus native presentation route; it does not make the bounded PE compiler emit
the full Kof/SDL program.

On a DRI3-capable isolated host, the full Wine smoke verifies the Kof JVM
gameplay path together with the native SDL3/SDL_mixer presentation path. It
must not be generalized to native PE gameplay, other OS/GPU combinations or
WAN/security qualification.
### G6 bounded runtime probes

Run the non-graphical expansion qualification as one focused command:

```bash
bash scripts/verify_g6_runtime.sh
```

It compiles and executes safe worker publication, packaged KofScript/session
activation, persistent Studio reopen/rollback and the fixed-window WAN channel.
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

## Graphical qualification isolation

Never run KOOKIE graphical checks against the active desktop or physical
monitors. Supply a reviewed disposable isolation wrapper through
`KOOKIE_PRESENTATION_ISOLATION_WRAPPER`; it must provide private display and
session sockets, a bounded timeout and complete process-tree cleanup.

Offscreen SDL checks prove lifecycle and GPU-resource behavior, not real window
presentation. Use `KOOKIE_SDL_VIDEO_DRIVER=x11` only with an isolated
present-capable environment. Set
`KOOKIE_SCREENSHOT_PATH=/absolute/path.ppm` to retain a qualified frame.
