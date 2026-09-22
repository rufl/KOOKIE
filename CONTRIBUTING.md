# Contributing to KOOKIE

[Português (Brasil)](pt-BR/CONTRIBUTING.md)

KOOKIE keeps portable engine, game, and tool CPU behavior in Kof `.kf` source. External platform/GPU/audio libraries and narrow ABI/shader glue are explicit exceptions. Read `README.md`, `MEMORY.md`, and the relevant document under `docs/` before changing code.

## Language

Public pages and documentation are maintained in English and Brazilian Portuguese. Keep the matching file under `pt-BR/` synchronized whenever a page or document changes.

## Verification gate

Before every push, run the repository gate from its root:

```bash
bash scripts/verify.sh
```

The gate runs:

1. the repository Kof linter;
2. Kof LSP diagnostics for every `.kf` source under `src/` and `probes/`;
3. Kof compiler checks for JVM and native targets;
4. JVM and native compiler builds.

The current Kof LSP analyzes each open document as a temporary single-file
module, so the gate records its known `PKG004`/`PKG006` package diagnostics and
fails on every other LSP error. Full package/import correctness is covered by
the JVM/native compiler checks.

Do not commit build output, credentials, downloaded dependencies, or generated caches. Graphical checks must use a disposable isolated display and must not target the active desktop session. Native runtime findings remain bounded by the gates documented in `docs/ENGINE_PLAN.md`.
