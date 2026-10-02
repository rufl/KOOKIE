# G0 scalar adapter contracts

[Português (Brasil)](../pt-BR/docs/G0_SCALAR_ADAPTER.md)

Status: **implemented and exercised on JVM/native plus isolated real-window presentation**. The narrow C boundary now covers SDL lifecycle, SDL_mixer effects/music streams, bounded synthesized clips, SPIR-V scene upload/draw and Kof-owned event state. The current native presentation probe reports a valid swapchain capability, draws and captures the 486-vertex authored scene, and consumes the authoritative combat event's clip `201`; machine-specific evidence remains outside the repository.

The current source/CI gate uses Kof `0.5.0-beta` at the pinned source commit;
this page records the bounded adapter contract, while machine-specific
presentation evidence remains a separate release requirement.


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
- default playback SDL_mixer open/close with slot+generation+kind tokens;
- independent effects/music tracks backed by SDL audio streams;
- bounded PCM silence and clip transfer without a callback into Kof;
- SPIR-V SDL_GPU device create/claim/release/destroy behind a checked token;
- first shader, texture upload, sampler, pipeline and swapchain draw path;
- explicit shutdown ordering for GPU, windows, mixer tracks/streams and SDL.

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
- no callback into Kof and no competing gameplay/audio policy authority.

The native adapter proves a real SDL_mixer lifecycle, separate gain controls,
bounded silence transfer and deterministic synthesized clip variants
(`clipId=1` and impact clips `201`–`203`, at most 480 stereo F32 frames). The
presentation probe selects clip `201` from the confirmed authoritative kill
event. Scalar FFI still cannot pass a Kof-owned sample buffer; decoded asset
ownership and streamed voice lifetimes remain later boundaries.

## GPU lifecycle

The adapter requests SPIR-V support, creates an SDL_GPU device, claims an SDL window, uploads a bounded semantic palette and scene vertices through transfer buffers, submits the swapchain draw, waits for GPU idle and releases resources. The reviewed isolated-display path has recorded `gpu-open`, positive swapchain capability, draw completion, screenshot capture and clean exit; unavailable environments still fail closed as `gpu-unavailable`.

## Regression proof

`src/main.kf` contains the executable smoke path and focused contracts for
resource tokens, platform/audio lifecycle, frame staging and the GameShell
menu/options/lobby transaction.

`scripts/verify_exception.sh` preserves the native exception-lifetime reproducer and its JVM/native negative controls: JVM exits on the failed assertion; native currently reaches `unreachable` with exit 0. This is a compiler defect record, not an engine cleanup guarantee.

The gate also checks the Kof native adapter probe. If SDL3 headers, `gcc`, `glslc`, `pkg-config` and a reviewed `KOOKIE_PRESENTATION_ISOLATION_WRAPPER` are available, it compiles the adapter and SPIR-V shaders, emits the native probe ELF and runs it through that wrapper with dummy audio. If those dependencies are absent, CI records an explicit skip.

```bash
bash scripts/verify.sh
```

The gate materializes temporary links to canonical Kof packages while compiling standalone probes, then removes them on exit. Kof source checks, tests and builds pass on JVM/native. The C adapter compiles with `-Wall -Wextra -Werror`; shaders compile through `glslc`; fixed scene staging, positive draw timing, screenshot capture and resource teardown are exercised inside the isolated display.

The probe drains pre-existing SDL events through one bounded native scalar
helper. Keeping the drain loop in C avoids a measured native compiler failure
where assigning an extern `Int` inside that Kof loop emitted an invalid
`kof_unbox_int` call; the crash was in generated probe code, not SDL.

## Next proof boundary

Production work beyond this boundary includes decoded asset ownership,
streamed voices, real SDL device-loss notification and bounded resource
retirement under sustained load. Do not cast SDL pointers to integer tokens,
add callbacks into Kof, or infer those contracts from the qualified scene/clip
probe.
