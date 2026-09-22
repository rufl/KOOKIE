# G0 scalar adapter contracts

[Português (Brasil)](../pt-BR/docs/G0_SCALAR_ADAPTER.md)

Status: **implemented and compiler-exercised on JVM/native**. This increment adds a narrow C SDL adapter and Kof-owned state contracts. The native window/audio smoke is wired but its isolated-display run is pressure-deferred; no GPU device or textured draw is claimed.

## SDL lifecycle boundary

`src/platform/sdl.kf` binds scalar SDL calls:

- `SDL_GetVersion(): Int` for the version probe;
- `SDL_Init(Int): Bool`;
- `SDL_Quit(): void`.

`SdlLifecycle` owns the Kof-side initialized flag. It rejects negative flags, makes repeated initialization idempotent, and makes shutdown explicit. `probes/g0_platform/main.kf` calls `SDL_Init(0)` and `SDL_Quit()` on both targets when `/usr/lib/libSDL3.so` is installed. `0` intentionally requests no SDL subsystem; it does not prove video/audio initialization.

The direct Kof binding still carries no SDL pointer, struct, event union, callback, window or audio device. The measured Kof FFI limitation remains: scalar extern calls work, while arrays/structs/pointers/out-buffers/callbacks do not form a portable binding.

## Narrow native adapter

`native/kookie_sdl_adapter.c` is the allowed ABI glue for the blocked pointer/struct boundary. It owns SDL pointers and exposes only checked scalar results:

- window create/destroy with slot+generation+kind tokens;
- stale and wrong-kind window-token rejection;
- `SDL_PollEvent` flattened to event kind plus two scalar payload fields;
- default playback audio-device open/close with slot+generation+kind tokens;
- explicit shutdown that destroys adapter-owned windows and closes audio.

The adapter does not retain Kof pointers, callbacks, gameplay state, entities or audio sample buffers. `probes/g0_native_adapter/main.kf` exercises hidden window creation/teardown, scalar event polling, dummy playback-device open/close and stale-token rejection.

## Window and input state

`src/core/window_state.kf` provides the Kof-owned state contract:

- focus accepts only `0` or `1`;
- resize accepts only positive dimensions;
- close is monotonic for the current frame/session state;
- `snapshot()` returns copied scalar state through `WindowState`.

The native adapter now flattens SDL events, but Kof event-to-state application is still the next integration boundary. The Kof loop remains authoritative.

## Queued audio state

`src/core/audio_queue.kf` is a bounded FIFO contract:

- explicit `open()`/`close()` lifecycle;
- positive clip token and gain in `[0, 100]` admission;
- fixed-capacity overflow rejection;
- FIFO dequeue with copied clip/gain metadata;
- no callback into Kof and no foreign mixer authority.

The native adapter proves device open/close only. Queue data is not uploaded to SDL yet; the next audio step must choose a bounded PCM transfer contract without introducing a second mixer authority.

## Regression proof

`src/main.kf` contains the executable smoke path and two named tests:

- `resource token lifecycle`;
- `platform state and audio queue lifecycle`.

The gate also checks the Kof native adapter probe. If SDL3 headers, `gcc`, `pkg-config` and `overzeer-isolated-display` are available, it builds the adapter, emits the native probe ELF and runs it through the isolated-display wrapper with dummy audio. If those dependencies are absent, CI records an explicit skip. The current isolated-display attempt was deferred by the wrapper's pressure gate; it must be rerun before calling the graphical/audio smoke accepted.

```bash
bash scripts/verify.sh
kof check probes/g0_native_adapter/main.kf --target native
```

Local scalar probes passed on JVM/native. Kof source checks, tests and builds pass on JVM/native. Native execution still emits the known full-runtime fallback warning outside the compiler checkout; JVM may emit the JDK restricted-native-access warning for direct SDL lookup.

## Next proof boundary

Rerun the isolated native adapter smoke and record window/audio acceptance. Then apply flattened events to `WindowStateTracker`, add a bounded PCM queue transfer, and measure SDL_GPU window/device setup. Do not cast SDL pointers to integer tokens, add callbacks into Kof, or label these contracts as GPU/textured-render proof.
