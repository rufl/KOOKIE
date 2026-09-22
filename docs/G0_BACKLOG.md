# G0 implementation backlog

[Português (Brasil)](../pt-BR/docs/G0_BACKLOG.md)

This is the active bounded implementation sequence after the initial research and contract commits.

## Completed

- Modular `core`/`session` Kof source and scalar SDL3 probe.
- Bilingual documentation and push verification gate.
- Checked Kof-owned resource tokens with slot, generation and kind validation.
- JVM/native regression smoke and two named regression tests.
- Scalar `SDL_Init(0)`/`SDL_Quit()` lifecycle exercised on JVM/native.
- Kof-owned focus/resize/close state and bounded FIFO audio queue.
- Narrow C SDL adapter with checked window/audio/GPU tokens and scalar event flattening.
- Bounded PCM silence and deterministic clip transfer into an SDL audio stream without callbacks.
- Native adapter probe applying real adapter events to Kof state and running the first SPIR-V texture upload/draw path.

## Next batch

1. Re-run the isolated native adapter smoke after the pressure gate permits it; record window, dummy-audio and GPU acceptance.
2. Measure scalar staging and frame ownership around the first bounded textured draw.
3. Re-run the native exception-handler reproducer and negative controls with the pinned compiler before relying on exception cleanup.
4. Record every measured failure or acceptance boundary in both language trees.

## Deferred

- Textured mesh renderer and shader pipeline beyond the first smoke draw.
- Input mapping, camera, server/client loopback and prediction.
- Collision, weapons, enemies, content cooking, save schema and multiplayer transport.
- Production audio, image/text services, package compression and foreign physics/UI libraries.

Do not replace a blocked native capability with JVM fallback, a hidden C engine, a fake-success stub or an unverified graphics scaffold.
