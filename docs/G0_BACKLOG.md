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

## Next batch

1. Add a tiny native ABI adapter that stores SDL-owned pointers behind checked integer tokens. No gameplay ownership, raw pointers, callbacks or bulk buffers.
2. Prove SDL window creation and teardown from the native ELF using the repository's isolated-display wrapper.
3. Flatten real SDL events into Kof focus/resize/close state. Keep the Kof loop authoritative.
4. Prove one queued audio device lifecycle without adding a second mixer authority.
5. Measure scalar staging for one bounded textured draw before choosing a buffer-FFI change.
6. Re-run the native exception-handler reproducer and negative controls with the pinned compiler before relying on exception cleanup.
7. Record every measured failure or acceptance boundary in both language trees.

## Deferred

- Textured mesh renderer and shader pipeline beyond the first smoke draw.
- Input mapping, camera, server/client loopback and prediction.
- Collision, weapons, enemies, content cooking, save schema and multiplayer transport.
- Production audio, image/text services, package compression and foreign physics/UI libraries.

Do not replace a blocked native capability with JVM fallback, a hidden C engine, a fake-success stub or an unverified graphics scaffold.
