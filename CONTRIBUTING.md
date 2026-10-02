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

When a session or replay contract changes, update the matching English and
Portuguese pages and the nearby source comments together. Document same-tick
state revisions and checkpoint/rewind epoch rules explicitly; do not leave those
invariants only in a regression test.

Do not commit build output, credentials, downloaded dependencies, or generated caches. Graphical checks must use a disposable isolated display and must not target the active desktop session. Native runtime findings remain bounded by the gates documented in `docs/ENGINE_PLAN.md`.
