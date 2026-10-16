# KOOKIE release operations

This is the concrete release procedure for the current qualification
workstation and the GitHub Actions workflow. It does not generate or replace
the owner-controlled release signing key.

## Current publication state

The latest published dogfood is
[`0.1.0-dogfood.63`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.63),
a signed Linux/Windows x86-64 pair from source commit
`3bd382a072817fe545ae9a80abfd1dd344878ada`.

The current source commit
`e8cad301b566607a3b8095a219d05441de3240e5` passed Verify KOOKIE run
[`38978943862`](https://github.com/rufl/KOOKIE/actions/runs/38978943862).
Release dispatch
[`38981016223`](https://github.com/rufl/KOOKIE/actions/runs/38981016223)
targets `0.1.0-dogfood.64`; its Kof toolchain and Linux package passed, but
the Windows package job is queued because `kookie-windows-01` is offline. Do
not treat the candidate as published. After the Windows job passes, the
`kookie-demo-release` environment approval is still required before the
workflow can create the pre-release.

## Current checkout and local toolchain paths

```bash
cd /home/lich/lichforge/code/monorepo/engines/KOOKIE
source scripts/kof_pin.sh

export KOF_ROOT=/tmp/kof-debug/dist-ci/kof-0.6.5-linux-x86_64
export KOF_ARCHIVE=/tmp/kof-debug/dist-ci/kof-0.6.5-linux-x86_64.tar.gz
export KOOKIE_WINDOWS_SDL_PREFIX=/tmp/kookie-release-deps/sdl/SDL3-3.4.18/x86_64-w64-mingw32
export KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/tmp/kookie-release-deps/mixer/SDL3_mixer-3.2.4/x86_64-w64-mingw32
export KOOKIE_WINDOWS_FREETYPE_PREFIX=/tmp/kookie-release-deps/freetype/x86_64-w64-mingw32
export KOOKIE_WINDOWS_HARFBUZZ_PREFIX=/tmp/kookie-release-deps/harfbuzz/x86_64-w64-mingw32
export KOOKIE_DXC=/tmp/kookie-release-deps/dxc/bin/dxc
export PATH="$KOF_ROOT/bin:$PATH"
export KOOKIE_KOF_SOURCE_COMMIT=8e59b24acc978eb2546509b5cfca867a06e7283a
export KOOKIE_KOF_ARCHIVE_SHA256="$(sha256sum "$KOF_ARCHIVE" | cut -d ' ' -f 1)"
```

`KOF_ARCHIVE` must be a source-built, metadata-normalized Kof `0.6.5`
distribution from the pinned Kof `lab` commit. `scripts/prepare_kof_source.sh`
verifies the upstream native GC cycle guard before Maven packaging; the
release toolchain then applies
`patches/kof-native-emitter-performance.patch` (the pinned source already
contains the native emitter allocation change; the patch retains the
deterministic register-allocation tie-break) and checks its SHA-256
`4898952c8f4130d1b5a9e8effb56b0dd7a58d228596b50f69427639c15843664`.
No local GC patch is applied. Its compiler JAR must match the resulting source
build; the release workflow rechecks `kof version` before packaging. Native
package gates also require `pkg-config`, FreeType 2 and HarfBuzz for the text
renderer.

The existing `/tmp/kookie-release-qualification.pem` is ephemeral and must not
be uploaded as the public release identity. Use an owner-controlled permanent
Ed25519 key with mode `0600`, for example:

```bash
export KOOKIE_SIGNING_KEY="$HOME/.config/kookie/release/kookie-ed25519.pem"
test -f "$KOOKIE_SIGNING_KEY"
test "$(stat -c '%a' "$KOOKIE_SIGNING_KEY")" = 600
```

## Readiness and secret configuration

The repository includes a fail-closed checker. It does not print key contents:

```bash
bash scripts/check_release_readiness.sh \
  --repo rufl/KOOKIE \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE"
```

After the two self-hosted release runners and the `kookie-demo-release`
environment exist, the same command can configure the owner-controlled signing
secret:

```bash
bash scripts/check_release_readiness.sh \
  --repo rufl/KOOKIE \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --set-github-secrets
```

The command sets only `KOOKIE_SIGNING_KEY_PEM`. The hosted `toolchain` job
builds the pinned Kof archive once per release run, publishes it with
`SHA256SUMS` and `SOURCE_COMMIT`, and both target jobs verify that artifact
before packaging. `KOOKIE_KOF_ARCHIVE_SHA256` remains a per-job package
environment value, not a static repository secret.

It refuses to update the signing secret when the local key/archive is invalid.
The paired `RELEASE_QUALIFICATION.json` also records the exact
`kofArchiveSha256` and `kofCompilerSha256` values and rejects a Linux/Windows
pair whose Kof artifact identities differ.

## One-command bootstrap

`scripts/bootstrap_release.sh` is the single entry point for the safe,
repeatable sequence. It validates the permanent key and Kof archive, creates
the environment with required reviewers, configures the signing secret, checks
the two self-hosted runners, and can dispatch qualification.

Dry-run/readiness only:

```bash
bash scripts/bootstrap_release.sh \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE"
```

```bash
RELEASE_VERSION=0.1.0-demo.N
bash scripts/bootstrap_release.sh --apply \
  --reviewer release-admin \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --version "$RELEASE_VERSION" \
  --qualify
```

For the final publication after both native target smokes have passed:


```bash
RELEASE_VERSION=0.1.0-demo.N
bash scripts/bootstrap_release.sh --apply \
  --reviewer release-admin \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --version "$RELEASE_VERSION" \
  --qualify \
  --linux-presentation-smoke \
  --windows-presentation-smoke \
  --publish --confirm-hardware-evidence
```

Adding `--publish` requires the explicit
`--confirm-hardware-evidence` acknowledgement and still pauses at the
GitHub environment approval. The script cannot create physical runner hosts
or invent a permanent signing key; it exits with setup URLs instead.

## Runner contract

The release workflow requires two **online** self-hosted x86-64 runners with
these labels:

```text
self-hosted, linux, x64, kookie-demo-release
self-hosted, windows, x64, kookie-demo-release
```

Both runners need Git for Windows/Linux shell support as applicable, Python 3,
OpenSSL, `glslc`, `spirv-val` and the repository checkout. The hosted
`toolchain` job builds Kof `0.6.5` from
`8e59b24acc978eb2546509b5cfca867a06e7283a`; each self-hosted job downloads
and verifies that exact archive and prepends its `kof` binary. A preinstalled
archive, Kof compiler digest secret or preinstalled Zig is not part of the
release-runner contract.

The Linux runner additionally needs:

- pinned SDL3 development files at
  `$HOME/.local/share/kookie-deps/sdl/SDL3-3.4.18`;
- the reviewed `overzeer-isolated-display` sandbox and `gamescope`;
- a usable `/dev/dri/renderD*` node and the paired primary DRM card node for
  the Gamescope headless compositor.

The tracked `scripts/linux_gamescope_isolated_display` wrapper composes those
pieces into a private headless Wayland/Xwayland display and the release job
uses SDL's X11 backend through Gamescope's Xwayland server inside it. The
workflow prepares the pinned SDL_mixer prefix when its `pkg-config` entry is
absent.

The Windows runner needs Git Bash, Windows PowerShell 5, and `dxc`. The release
configure step downloads and verifies a pinned MSYS2 `pkgconf` archive (version
`1~3.0.8-1`, SHA-256
`b8ef0afd0f5da42c40a455491148c6e8ca5436ab2f0167f0a93074d4eeb9249b`) plus the
pinned MinGW FreeType/HarfBuzz runtime bundle
`freetype-2.15.0-harfbuzz-14.6.0-runtime-16.2.0`; every package URL and
SHA-256 is tracked in `MINGW_TEXT_PACKAGE_MANIFEST` in the workflow. It uses
the runner's `tar --zstd` support, or downloads and verifies the pinned zstd
`1.5.7` Windows archive (SHA-256
`acb4e8111511749dc7a3ebedca9b04190e37a17afeb73f55d4425dbf0b90fad9`) to
stream extraction. It then exports the generated MinGW text prefixes and
discovers `dxc` from `PATH` or known installed locations. It downloads and
verifies the official MinGW development archives for SDL3 `3.4.18` (SHA-256
`049b9dd711e3fb3f8d84feb998dfec54a75e17cf539c4a80ff4d058d839771cf`) and
SDL_mixer `3.2.4` (SHA-256
`2ff5f59be4683e0afb4339c4fa73c6228651e52d37b040ecf80da08edb3cecd6`) on
each release run. It also downloads and verifies the official Zig `0.17.0`
Windows archive with SHA-256
`b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428`, then
uses the tracked `scripts/windows_isolated_display` wrapper. Native Windows
presentation smoke also records the first PCI display adapter's PNP identity,
name and driver version as target hardware evidence.
Presentation packages also stage the project-authored liquid and power-up
runtime JSON under `config/runtime`; this is separate from the optional
prototype-content profile and keeps the native presentation probe runnable in
the `content-profile=none` dogfood package.

Both native presentation runners must set non-empty
`KOOKIE_PRESENTATION_HARDWARE_ID` and `KOOKIE_PRESENTATION_GPU_DRIVER`
environment variables. These values identify the physical target and driver
used for authoritative evidence; missing values fail the release gate.

On Windows, the runner service must use Git for Windows `bash.exe`, not the WSL
shim. Keep tool paths at machine scope; NTFS does not reliably expose POSIX mode
bits, so the package gate restricts transient signing keys with `icacls.exe`.
The Windows package gate also excludes linker options beginning with `-Wl,/`
from Git Bash MSYS path conversion.

### Runner preflight and cache contract

Before release packaging, the workflow runs
`scripts/runner_preflight.sh release-linux` or
`scripts/runner_preflight.sh release-windows`. The preflight records OS, CPU,
memory and free disk in the GitHub step summary, then rejects a runner that
lacks the pinned Kof archive, Zig, SDL, shader, text-runtime or DXC inputs
required by its target.

The workflow caches only immutable downloaded archives, keyed by their
version and SHA-256. Every cache hit is hashed again before extraction. A cache
does not replace the Kof `SHA256SUMS`/`SOURCE_COMMIT` checks or the release
runner's GPU/display preflight.

The hosted `verify.yml` workflow builds the Kof archive once per run. Its
static/JVM, native/package and Windows JVM jobs consume that exact archive in
parallel. Native verification has a separate longer timeout because Kof native
code generation is materially slower than the static/JVM path.


Create `kookie-demo-release` in repository **Settings → Environments** and add
required reviewers before allowing `publish=true`.

## Dispatch

Qualify artifacts first. Set `RELEASE_VERSION` to the candidate version:

```bash
RELEASE_VERSION=0.1.0-demo.N
SOURCE_COMMIT="$(git rev-parse HEAD)"
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version="$RELEASE_VERSION" \
  -f source_commit="$SOURCE_COMMIT" \
  -f publish=false \
  -f run_linux_presentation_smoke=true \
  -f run_windows_wine_smoke=false \
  -f run_windows_presentation_smoke=true
```

Inspect the run and retain its immutable source commit:

```bash
QUALIFICATION_RUN="$(gh run list \
  --repo rufl/KOOKIE \
  --workflow release_demo.yml \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')"
gh run watch "$QUALIFICATION_RUN" --repo rufl/KOOKIE
SOURCE_COMMIT="$(gh run view "$QUALIFICATION_RUN" \
  --repo rufl/KOOKIE --json headSha --jq .headSha)"
```

After the qualification run succeeds with `releaseEligible=true`, dispatch the
same immutable source commit with `publish=true`. The publish workflow checks
out `SOURCE_COMMIT`, rebuilds both artifacts from it, generates and signs its
own final `RELEASE_QUALIFICATION.json`, then pauses at the environment approval
before creating the public prerelease:

```bash
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version="$RELEASE_VERSION" \
  -f source_commit="$SOURCE_COMMIT" \
  -f publish=true \
  -f run_linux_presentation_smoke=true \
  -f run_windows_wine_smoke=false \
  -f run_windows_presentation_smoke=true
```

The public release must use the permanent key. The local qualification key,
local `/tmp` dependency paths and local candidate archives are not release
infrastructure.
