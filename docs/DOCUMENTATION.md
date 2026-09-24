# Documentation policy

[Português (Brasil)](../pt-BR/docs/DOCUMENTATION.md)

- Every public page has a matching English and Brazilian Portuguese version. Keep the pair in the same commit.
- English lives under `README.md` or `docs/`; Portuguese lives under `pt-BR/` or `pt-BR/docs/`.
- Preserve measured commands, source pins, hashes and proof limits. Do not translate code identifiers, paths, command names or upstream product names.
- Write status like a teammate would: say what works, what was actually checked and what is still blocked. Avoid milestone language that sounds more complete than the evidence.

The root README is the landing page. [CHANGELOG](../CHANGELOG.md) is the short human-readable history; [MEMORY](../MEMORY.md) is the re-entry note; `CONTRIBUTING.md` defines the verification gate. The active bounded G0 sequence is tracked in [G0_BACKLOG](G0_BACKLOG.md), with resource-token and scalar-adapter details in [G0_RESOURCE_TOKENS](G0_RESOURCE_TOKENS.md) and [G0_SCALAR_ADAPTER](G0_SCALAR_ADAPTER.md).
