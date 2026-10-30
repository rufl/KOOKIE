# Contributing to KOOKIE

[Português (Brasil)](pt-BR/CONTRIBUTING.md)

KOOKIE keeps portable engine, game, and tool CPU behavior in Kof `.kf` source. External platform/GPU/audio libraries and narrow ABI/shader glue are explicit exceptions. Read `README.md`, `MEMORY.md`, and the relevant document under `docs/` before changing code.

If the change affects the player-facing release boundary, also read
[Demo release readiness](docs/DEMO_RELEASE.md); engine/package qualification
does not by itself mean that the Windows/Linux demo is playable.

## Language

Public pages and documentation are maintained in English and Brazilian Portuguese. Keep the matching file under `pt-BR/` synchronized whenever a page or document changes.

For a quick picture of recent work, read [CHANGELOG.md](CHANGELOG.md). Keep the changelog and the matching Portuguese file useful to a person joining the project: describe the behavior that changed, the check that supports it, and the limit that remains.

## Dependencies and licensing

KOOKIE is MIT. Every source or runtime component distributed in a KOOKIE
package must use a reviewed permissive license. Build and qualification tools
may use other licenses only when they are not linked, copied or required at
runtime. Pin versions and hashes, update `THIRD_PARTY_NOTICES.txt`, and make the
package dependency-closure check reject any unreviewed library.

## Verification gate

Before every push, run the repository gate from its root:

```bash
bash scripts/verify.sh
```

The gate runs:

1. the repository Kof linter;
2. Kof LSP diagnostics for every `.kf` source under `src/` and `probes/`;
3. Kof compiler checks for JVM and native targets;
4. the named Kof regression test suite for JVM and native targets;
5. JVM/native runtime smoke output for the checked resource-token and state contracts;
6. the optional native SDL adapter build and isolated-display smoke when its system dependencies and pressure gate permit it;
7. JVM and native compiler builds.

Hosted GitHub runners are shared virtual machines, so the workflow sets
`KOOKIE_SERVER_P95_BUDGET_US=8000` for a scheduling-tolerant headless-server
gate. The default local and soak budget remains 4000 microseconds; a hosted
CI pass does not replace recorded performance evidence.
The current Kof LSP analyzes each open document as a temporary single-file
module, so the gate records its known `PKG004`/`PKG006` package diagnostics and
fails on every other LSP error. Full package/import correctness is covered by
the JVM/native compiler checks.

### Inner development loop

Use the JVM regression suite while iterating on Kof logic:

```bash
bash scripts/dev_test.sh
```

The default run executes the 144 tests from `src/main.kf` without the native
assembly, linker, packaging and presentation gates. Use
`KOOKIE_DEV_TARGET=native bash scripts/dev_test.sh` for a native-specific
check. This is an iteration gate, not a replacement for `verify.sh`.

Full verification reuses canonical JVM/native artifacts under
`${XDG_CACHE_HOME:-$HOME/.cache}/kookie/canonical`; identity manifests
invalidate the cache when the source tree or pinned Kof toolchain changes.
Set `KOOKIE_CANONICAL_BUILD_CACHE_DIR` to override that location.

Run the bounded cross-target performance diagnostic when changing hot
simulation, allocation or native-boundary code:

```bash
python3 scripts/profile_kookie.py --target all --verify \
  --output build/kookie-performance-profile.json
```

This is a diagnostic gate, not a substitute for the full verification matrix.
Use `--require-perf` only on hosts with permitted hardware performance
counters.

### Local package gate

The release package checks require the exact Kof distribution used by `kof`,
plus the pinned Zig toolchain metadata used by the Windows fail-closed check.
When the archive directory contains `SHA256SUMS` and `SOURCE_COMMIT`, configure
the current shell before running the full gate:

```bash
source scripts/configure_kof_archive.sh /path/to/kof-0.6.8-linux-x86_64.tar.gz
export KOOKIE_ZIG_VERSION=0.17.0
export KOOKIE_ZIG_ARCHIVE_SHA256=1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026
bash scripts/verify.sh
```

The archive digest is generated per Kof build because tar metadata varies;
`configure_kof_archive.sh` verifies it and the pinned Kof source commit before
exporting the package inputs. `verify.sh` runs the same package identity
preflight before starting the expensive static and runtime matrix.
During package smoke, `verify_package.sh` reuses a per-run cache for the
server, content kooker and SIMD benchmark native builds across the native and
presentation archives. The cache is temporary and is never treated as a
release artifact.

When a session or replay contract changes, update the matching English and
Portuguese pages and the nearby source comments together. Document same-tick
state revisions and checkpoint/rewind epoch rules explicitly; do not leave those
invariants only in a regression test.

Do not commit build output, credentials, downloaded dependencies, or generated caches. Graphical checks must use a disposable isolated display and must not target the active desktop session. Native runtime findings remain bounded by the gates documented in `docs/ENGINE_PLAN.md`.
