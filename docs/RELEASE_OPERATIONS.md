# KOOKIE release operations

This is the concrete release procedure for the current qualification
workstation and the GitHub Actions workflow. It does not generate or replace
the owner-controlled release signing key.

## Current checkout and local toolchain paths

```bash
cd /home/lich/lichforge/code/monorepo/engines/KOOKIE

export KOF_ROOT=/tmp/kof-debug/dist-ci/kof-0.5.0-beta-linux-x86_64
export KOF_ARCHIVE=/tmp/kof-debug/dist-ci/kof-0.5.0-beta-linux-x86_64.tar.gz
export KOOKIE_WINDOWS_SDL_PREFIX=/tmp/kookie-release-deps/sdl/SDL3-3.4.18/x86_64-w64-mingw32
export KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/tmp/kookie-release-deps/mixer/SDL3_mixer-3.2.4/x86_64-w64-mingw32
export KOOKIE_DXC=/tmp/kookie-release-deps/dxc/bin/dxc
export PATH="$KOF_ROOT/bin:$PATH"
export KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c
export KOOKIE_KOF_ARCHIVE_SHA256="$(sha256sum "$KOF_ARCHIVE" | cut -d ' ' -f 1)"
```

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
environment exist, the same command can upload the two required repository
secrets:

```bash
bash scripts/check_release_readiness.sh \
  --repo rufl/KOOKIE \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --set-github-secrets
```

The command sets:

- `KOOKIE_SIGNING_KEY_PEM` from the permanent key file;
- `KOOKIE_KOF_ARCHIVE_SHA256` from the exact Kof archive supplied to both
  release runners.

It refuses to update secrets when the local key/archive is invalid.

## One-command bootstrap

`scripts/bootstrap_release.sh` is the single entry point for the safe,
repeatable sequence. It validates the permanent key and Kof archive, creates
the environment with required reviewers, configures both repository secrets,
checks the two self-hosted runners, and can dispatch qualification.

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

Register two **online** self-hosted x86-64 runners with these labels:

```text
self-hosted, linux, x64, kookie-demo-release
self-hosted, windows, x64, kookie-demo-release
```

Both runners need Kof `0.5.0-beta` at
`bf17ac7e736471c8a04b4153e5b0f607be75e70c`, Python 3, OpenSSL, `glslc`, Zig
`0.17.0` and the exact Kof archive whose digest is stored in
`KOOKIE_KOF_ARCHIVE_SHA256`.
The runner must expose that archive as `KOOKIE_KOF_ARCHIVE`; release jobs
recompute its SHA-256 before building, instead of trusting digest metadata alone.
The hosted verification workflow downloads the official Zig 0.17.0 Linux
archive over HTTPS and verifies SHA-256
`1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026` before
adding it to `PATH`; it does not depend on a Node-based setup action.
The Linux release runner exposes pinned SDL3 3.4.18 at
`$HOME/.local/share/kookie-deps/sdl/SDL3-3.4.18`; the workflow exports
`KOOKIE_SDL3_PREFIX` before preparing SDL_mixer. An older or unreviewed system
SDL3 is not a substitute.


The Linux runner additionally needs SDL3 development files, the pinned
SDL_mixer preparation path and an isolated display wrapper for optional
presentation smoke. The Windows runner additionally needs the MinGW SDL3 and
SDL_mixer prefixes and `KOOKIE_DXC`. Native Windows presentation smoke also
requires a reviewed `KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER` that
provides a private display/session boundary, bounded timeout and process cleanup.
Both native presentation runners must set non-empty
`KOOKIE_PRESENTATION_HARDWARE_ID` and `KOOKIE_PRESENTATION_GPU_DRIVER`
environment variables. These values identify the physical target and driver
used for the authoritative evidence; missing values fail the release gate.
On Windows, the runner service must use Git for Windows `bash.exe`, not the WSL
shim. Keep tool paths at machine scope; NTFS does not reliably expose POSIX mode
bits, so the package gate restricts transient signing keys with `icacls.exe`.
The Windows package gate also excludes linker options beginning with `-Wl,/`
from Git Bash MSYS path conversion.

Create `kookie-demo-release` in repository **Settings → Environments** and add
required reviewers before allowing `publish=true`.

## Dispatch

Qualify artifacts first. Set `RELEASE_VERSION` to the candidate version:

```bash
RELEASE_VERSION=0.1.0-demo.N
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version="$RELEASE_VERSION" \
  -f publish=false \
  -f run_linux_presentation_smoke=true \
  -f run_windows_wine_smoke=false \
  -f run_windows_presentation_smoke=true
```

Inspect the run:

```bash
gh run watch "$(gh run list \
  --repo rufl/KOOKIE \
  --workflow release_demo.yml \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')" \
  --repo rufl/KOOKIE
```

Only after `RELEASE_QUALIFICATION.json` is generated with
`releaseEligible=true` and the environment approval is granted, publish the
same candidate:

```bash
RELEASE_VERSION=0.1.0-demo.N
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version="$RELEASE_VERSION" \
  -f publish=true \
  -f run_linux_presentation_smoke=true \
  -f run_windows_wine_smoke=false \
  -f run_windows_presentation_smoke=true
```

The public release must use the permanent key. The local qualification key,
local `/tmp` dependency paths and local candidate archives are not release
infrastructure.
