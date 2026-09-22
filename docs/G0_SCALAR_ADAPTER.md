# G0 scalar adapter contracts

[Português (Brasil)](../pt-BR/docs/G0_SCALAR_ADAPTER.md)

Status: **implemented and compiler-exercised on JVM/native**. This increment adds narrow C SDL window/audio/GPU lifecycle glue, bounded clip PCM transfer, a first SPIR-V texture upload/draw path, and Kof-owned event state contracts. The native window/audio/GPU smoke is wired but its isolated-display run is pressure-deferred; no accepted textured draw is claimed.

## SDL lifecycle boundary

`src/platform/sdl.kf` binds scalar SDL calls:

- `SDL_GetVersion(): Int` for the version probe;
- `SDL_Init(Int): Bool`;
- `SDL_Quit(): void`.

`SdlLifecycle` owns the Kof-side initialized flag. It rejects negative flags, makes repeated initialization idempotent, and makes shutdown explicit. `probes/g0_platform/main.kf` calls `SDL_Init(0)` and `SDL_Quit()` on both targets when `/usr/lib/libSDL3.so` is installed. `0` intentionally requests no SDL subsystem; it does not prove video/audio initialization.

The direct Kof binding still carries no SDL pointer, struct, event union, callback, window, GPU device or audio device. The measured Kof FFI limitation remains: scalar extern calls work, while arrays/structs/pointers/out-buffers/callbacks do not form a portable binding.

## Narrow native adapter

`native/kookie_sdl_adapter.c` is the allowed ABI glue for the blocked pointer/struct boundary. It owns SDL pointers and exposes only checked scalar results:

- window create/destroy with slot+generation+kind tokens;
- stale and wrong-kind window-token rejection;
- `SDL_PollEvent` flattened to event kind plus two scalar payload fields;
- default playback audio-stream open/close with slot+generation+kind tokens;
- bounded PCM silence and clip transfer into the SDL audio stream, with no callback;
- SPIR-V SDL_GPU device create/claim/release/destroy behind a checked token;
- first shader, texture upload, sampler, pipeline and swapchain draw path;
- explicit shutdown ordering: release GPU claim, destroy GPU device, destroy windows, destroy audio stream.

The adapter does not retain Kof pointers, callbacks, gameplay state, entities or Kof-owned audio sample buffers. `probes/g0_native_adapter/main.kf` exercises hidden window creation/teardown, real SDL event polling into `WindowStateTracker`, synthetic resize/focus queueing, optional GPU lifecycle plus the first upload/draw, dummy playback-device open/close, bounded silence and clip PCM transfer, and stale-token rejection.

## Window and input state

`src/core/window_state.kf` provides the Kof-owned state contract:

- focus accepts only `0` or `1`;
- resize accepts only positive dimensions;
- close is monotonic for the current frame/session state;
- `applyNativeEvent(kind, dataA, dataB)` maps adapter kinds `1..4` to close, resize and focus transitions;
- `snapshot()` returns copied scalar state through `WindowState`.

The adapter flattens SDL events, while Kof owns the transition policy and authoritative loop. The probe polls adapter output and applies event kinds and scalar payloads to a Kof `WindowStateTracker`; the isolated smoke remains the acceptance boundary for OS-generated behavior.

## Queued audio state

`src/core/audio_queue.kf` is a bounded FIFO contract:

- explicit `open()`/`close()` lifecycle;
- positive clip token and gain in `[0, 100]` admission;
- fixed-capacity overflow rejection;
- FIFO dequeue with copied clip/gain metadata;
- no callback into Kof and no foreign mixer authority.

The native adapter now proves a real SDL audio stream lifecycle, bounded silence transfer and a bounded clip descriptor (`clipId=1`, at most 480 stereo F32 frames). The adapter generates that deterministic clip payload because scalar FFI cannot yet pass a Kof-owned sample buffer; the next audio boundary is explicit buffer ownership, not a second mixer authority.

## GPU lifecycle

The adapter requests SPIR-V support, creates an SDL_GPU device, claims the hidden SDL window, uploads a bounded 2x2 RGBA texture through a transfer buffer, samples it in a triangle pipeline, submits one swapchain draw, waits for GPU idle, and releases resources. GPU failure is reported as `gpu-unavailable`; successful execution is not accepted until the isolated probe records `gpu-open` and completion.

## Regression proof

`src/main.kf` contains the executable smoke path and two named tests:

- `resource token lifecycle`;
- `platform state and audio queue lifecycle`.

The gate also checks the Kof native adapter probe. If SDL3 headers, `gcc`, `glslc`, `pkg-config` and `overzeer-isolated-display` are available, it compiles the adapter and SPIR-V shaders, emits the native probe ELF and runs it through the isolated-display wrapper with dummy audio. If those dependencies are absent, CI records an explicit skip. The current isolated-display attempts were pressure-deferred by the wrapper's pressure gate; they must be rerun before calling the window/audio/GPU smoke accepted.

```bash
bash scripts/verify.sh
```
The gate materializes temporary links to the canonical `src/core` package while compiling the standalone probe, then removes them on exit. Kof source checks, tests and builds pass on JVM/native. The C adapter compiles with `-Wall -Wextra -Werror`; shader sources compile through `glslc`. Native execution still emits the known full-runtime fallback warning outside the compiler checkout; JVM may emit the JDK restricted-native-access warning for direct SDL lookup.

## Next proof boundary

Rerun the isolated native adapter smoke and record window/audio/GPU acceptance. Then measure scalar staging for the first bounded textured draw and rerun the native exception-handler reproducer with negative controls. Do not cast SDL pointers to integer tokens, add callbacks into Kof, or call the optional GPU path accepted without isolated evidence.
