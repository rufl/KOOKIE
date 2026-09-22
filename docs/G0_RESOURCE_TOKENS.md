# G0 checked resource-token contract

[Português (Brasil)](../pt-BR/docs/G0_RESOURCE_TOKENS.md)

Status: **implemented and exercised on JVM/native Kof targets**. This is the first bounded G0 engine contract; it is not a native SDL registry yet.

## Contract

`src/core/resources.kf` defines:

- `ResourceToken(slot, generation, kind)`: immutable identity returned to Kof code;
- `ResourceRegistry(capacity)`: fixed-capacity slot storage;
- `acquire(kind)`: allocates the first free slot or returns an invalid token;
- `isValid(token)`: checks slot bounds, active state, generation and resource kind;
- `release(token)`: invalidates the current token and advances that slot's generation;
- `activeCount()` and `capacity()`: bounded observability for admission/tests.

A token is an identity, not a pointer. The slot is an index into adapter-owned state, the generation rejects stale reuse, and the kind rejects cross-resource use. Invalid acquisition uses `slot = -1`, `generation = 0`, and `kind = 0`; no native address is encoded.

## Invariants

1. A newly acquired token is valid exactly while its slot is occupied with the same generation and kind.
2. A released token is stale immediately; releasing it again returns `false` and changes no state.
3. A token with the correct slot/generation but a different kind is rejected.
4. Reusing a released slot advances its generation, so the old token cannot authorize access to the replacement.
5. Exhaustion and non-positive kinds return an invalid token instead of throwing or silently aliasing a resource.
6. Slot indices are checked before array access. The registry does not use native bounds faults as control flow.
7. Generation wrap is bounded back to `1` after `2,147,483,646`; persistent identity is not promised across process restarts.

The current class is deliberately single-threaded and Kof-owned. It does not expose payload storage, native pointers, GPU handles, audio handles, persistence, thread safety or automatic reclamation. Those behaviors remain adapter contracts to prove separately.

## Regression proof

`src/main.kf` contains a smoke path and a named `test "resource token lifecycle"` covering:

- acquisition and active-count admission;
- wrong-kind rejection;
- release and stale-token rejection;
- double-release rejection;
- generation change on slot reuse.

Run from the repository root:

```bash
kof test src --target jvm
kof test src --target native
kof run src/main.kf --target jvm
kof run src/main.kf --target native
```

The JVM and native test suites pass with one named test each. The native compiler still emits the documented full-runtime fallback warning when invoked outside its compiler checkout; this does not change the token result.

## Next adapter step

Use this contract at the scalar SDL adapter boundary. The adapter may own native pointers behind a registry, but it must expose only checked integer tokens and copied scalar metadata. Add resource-specific kinds, stale-token diagnostics and explicit GPU-safe retirement before connecting the registry to SDL_GPU or queued audio. Do not persist these tokens or treat an integer cast as a handle.
