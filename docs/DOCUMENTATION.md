# Documentation policy

[Português (Brasil)](../pt-BR/docs/DOCUMENTATION.md)

- Every public page has a matching English and Brazilian Portuguese version. Keep the pair in the same commit.
- English lives under `README.md` or `docs/`; Portuguese lives under `pt-BR/` or `pt-BR/docs/`.
- Preserve measured commands, source pins, hashes and proof limits. Do not translate code identifiers, paths, command names or upstream product names.
- Write status like a teammate would: say what works, what was actually checked and what is still blocked. Avoid milestone language that sounds more complete than the evidence.

The active source/CI baseline is the official Kof `0.6.7` release tag
`kof-0.6.7-linux-x86_64` at commit
`83626d5cc47074ed3edd6e3fb39dd83bcb4e3011`. Current session documentation must
describe strict tick ordering, newer same-tick state-sequence revisions and
fresh rewind history after checkpoint restore. Research pages retain their
dated toolchain snapshots intentionally; refresh their scope and evidence
limits without rewriting historical measurements.

The root README is the landing page.
[Running and packaging](RUNNING_AND_PACKAGING.md) holds developer, release,
kooker and qualification commands. [Demo release readiness](DEMO_RELEASE.md)
is the authority for the gap between engine qualification and a playable
Windows/Linux demo. [CHANGELOG](../CHANGELOG.md) is the short human-readable
history; [MEMORY](../MEMORY.md) is the re-entry note; `CONTRIBUTING.md` defines
the verification gate. The active bounded G0 sequence is tracked in
[G0_BACKLOG](G0_BACKLOG.md), with resource-token and scalar-adapter details in
[G0_RESOURCE_TOKENS](G0_RESOURCE_TOKENS.md) and
[G0_SCALAR_ADAPTER](G0_SCALAR_ADAPTER.md).
The reusable UI/media boundary and the independently audited upstream ABI are
recorded in
[KOF4J_UI_MIGRATION](KOF4J_UI_MIGRATION.md); it deliberately distinguishes the
current CI pin from older reviewed upstream source and historical measurements.
The proposed Kof/native migration is tracked in
[KOF_NATIVE_BOUNDARY_PLAN](KOF_NATIVE_BOUNDARY_PLAN.md); its normative
copy/lifetime and batch contract is [KOF_NATIVE_BOUNDARY_SPEC](KOF_NATIVE_BOUNDARY_SPEC.md).

Build timeout, heartbeat, historical ETA and diagnostic artifacts are described
in [CI_BUILD_OBSERVABILITY](CI_BUILD_OBSERVABILITY.md).
