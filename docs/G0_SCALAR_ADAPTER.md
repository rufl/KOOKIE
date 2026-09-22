# G0 scalar adapter contracts

[Português (Brasil)](../pt-BR/docs/G0_SCALAR_ADAPTER.md)

Status: **implemented and exercised on JVM/native**. This increment proves the scalar SDL lifecycle call and Kof-owned state contracts; it does not claim a native SDL window or audio device.

## SDL lifecycle boundary

`src/platform/sdl.kf` binds only scalar SDL calls:

- `SDL_GetVersion(): Int` for the existing version probe;
- `SDL_Init(Int): Bool`;
- `SDL_Quit(): void`.

`SdlLifecycle` owns the Kof-side initialized flag. It rejects negative flags, makes repeated initialization idempotent, and makes shutdown explicit. `probes/g0_platform/main.kf` calls `SDL_Init(0)` and `SDL_Quit()` on both targets when `/usr/lib/libSDL3.so` is installed. `0` intentionally requests no SDL subsystem; it avoids claiming that video/audio initialization has been proved.

No SDL pointer, struct, event union, callback, window, GPU device or audio device crosses this boundary. The measured FFI limitation remains: scalar extern calls work, while arrays/structs/pointers/out-buffers/callbacks do not form a portable binding.

## Window and input state

`WindowStateTracker` is a Kof-owned state contract for the future polling adapter:

- focus accepts only `0` or `1`;
- resize accepts only positive dimensions;
- close is monotonic for the current frame/session state;
- `snapshot()` returns copied scalar state through `WindowState`.

It does not poll SDL or create a native window. The future adapter must flatten SDL events into these scalar transitions on the main Kof thread.

## Queued audio state

`QueuedAudio` is a bounded FIFO contract, not an audio backend:

- explicit `open()`/`close()` lifecycle;
- positive clip token and gain in `[0, 100]` admission;
- fixed-capacity overflow rejection;
- FIFO dequeue with copied clip/gain metadata;
- no callback into Kof and no foreign mixer authority.

The class intentionally stores integer clip identities rather than pointers. A future SDL audio adapter can consume validated queue entries after a real device lifecycle is proved.

## Regression proof

`src/main.kf` contains the executable smoke path and two named tests:

- `resource token lifecycle`;
- `platform state and audio queue lifecycle`.

The gate runs both tests and compares JVM/native smoke output. When the local SDL3 shared library is available, it also runs the scalar platform probe; CI reports an explicit skip when that optional system library is absent:

```bash
kof check src --target jvm
kof check src --target native
kof test src --target jvm
kof test src --target native
kof run src/main.kf --target jvm
kof run src/main.kf --target native
kof run probes/g0_platform/main.kf --target jvm
kof run probes/g0_platform/main.kf --target native
```

Both targets pass for the Kof contracts. Native execution still emits the known full-runtime fallback warning outside the compiler checkout. JVM may emit the JDK restricted-native-access warning for the direct SDL lookup; the lifecycle result remains successful.

## Next proof boundary

The next native-only spike must use an isolated display and prove SDL video window creation/teardown, event polling, focus/resize transitions, and one queued audio device lifecycle from the emitted ELF. It must add a narrow C ABI adapter for pointer/struct/event data rather than casting SDL pointers to integer tokens. Do not label these Kof contracts as device or GPU proof.
