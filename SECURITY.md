# Security policy

[Português (Brasil)](pt-BR/SECURITY.md)

KOOKIE is experimental software, but authentication, parsers, packages,
persistence and release provenance are treated as security boundaries.

## Supported state

Security fixes target the current `main` branch and, when practical, the most
recent signed dogfood release. Older tags and locally modified packages are not
supported release lines.

The session boundary also treats tick/sequence ordering as a security invariant:
newer same-tick revisions are accepted only with a higher state sequence,
older/replayed state is rejected, and checkpoint restore discards future rewind
history before simulation resumes.

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/rufl/KOOKIE/security/advisories/new).
Do not open a public issue for a vulnerability that could expose credentials,
forge authenticated traffic, bypass package/signature checks, corrupt durable
state or execute untrusted input.

Include, when available:

- the affected commit or release tag and target platform;
- the boundary involved: transport, parser/kooker, package, save/replay,
  signature/provenance or bundled dependency;
- impact and the smallest reproducible input or sequence;
- focused logs with credentials, transport keys and private machine data
  removed;
- whether the issue reproduces against an unmodified checkout.

Never attach signing keys, deployment tokens, transport secrets or private
cross-host evidence.

## Response and disclosure

There is no commercial support SLA. Reports are triaged as maintainer capacity
allows. Reproduction, scope and a coordinated disclosure point are established
before publication. A fix is not considered complete until the affected
boundary has a focused regression or executable probe.

Non-sensitive hardening suggestions and ordinary correctness bugs belong in the
public issue tracker.
