# KOOKIE
[Português (Brasil)](pt-BR/README.md)

Public pages and documentation are maintained in English and Brazilian Portuguese. Keep matching changes synchronized under `pt-BR/`.


Research and planning for a **Kof-first, native 3D shooter engine**: boomer shooters, looter shooters and ARPG FPS.

**Where things stand:** KOOKIE is an engine under construction, not a finished game or a proven graphics stack. The bounded G0/G1 foundation is real and tested on JVM and native targets: sessions, fixed-step authority, snapshots, collision/BVH queries, spatial projectiles, saves/replays, item/progression state, and a narrow SDL adapter all exist. The latest combat work adds deterministic ray and shotgun-pellet selection plus an exact per-pellet damage contract.

The honest short version:

- The native target is Linux x86-64. JVM runs are our comparison target.
- Headless SDL_GPU rendering, recovery, queued audio, and authenticated localhost UDP probes work in their limited test shapes.
- Window presentation still depends on a host with isolated DRI3 support.
- Kof bulk-buffer FFI is still blocked by `FFI001`, so the SIMD kernel is proven as a native mechanism but is not yet wired into Kof-owned hot loops.
- Crash-durable saves, production multiplayer, content cooking, production audio, and the full physics stack are still ahead.

This project favors small executable contracts over impressive scaffolding. If a claim is not backed by a focused probe or test, it stays a proposal.

## Proposed direction

- Keep engine, game, and tool CPU behavior in **`.kf`**.
- Start with **Kof native Linux x86-64**, using JVM as a development comparison target.
- Use **SDL3 + SDL_GPU**, initially Vulkan/SPIR-V.
- Keep non-Kof code to indispensable libraries, narrow ABI marshaling, shaders, and minimal tool/bootstrap glue. No hidden C/Java/Rust/Zig engine.
- Borrow useful algorithms and contracts from DINX, ZYLVE and CUBSHIP without transplanting their engines or assuming rights to their assets.

The stack is promising, not proven end to end. Scalar FFI works; bulk buffers, native exception correctness, collector behavior, and long-running graphics/audio workloads still need real gates.

## Changelog

[Recent project history](CHANGELOG.md)

## Documentation

| Document | Purpose |
|---|---|
| [MEMORY.md](MEMORY.md) | Short re-entry reference: decisions, versions, caveats and next action |
| [Kof language](docs/KOF_LANGUAGE.md) | Syntax, types, modules, targets, tooling, FFI, GC, performance and licensing |
| [Kof Editor](docs/KOF_EDITOR.md) | Actual architecture/workflows, current defects, historical limitations and security boundary |
| [Games and graphics](docs/GAME_ECOSYSTEM.md) | DoomKof, Byte Eater, reported Pong, actual libraries and search limits |
| [Minecraft systems](docs/MINECRAFT_SYSTEMS.md) | Current Java26.3 stack; ECS/UI/physics/audio/rendering reuse, licenses, native-port boundaries and measured JOML interop |
| [Monorepo reuse](docs/MONOREPO_REUSE.md) | Specific source paths, reusable invariants, non-examples and ownership caveats |
| [Executed probes](docs/RESEARCH_PROBES.md) | Complete small `.kf` sources, commands, results, failures and proof limits |
| [Course deep dive](docs/KOF_COURSE.md) | Course/official-doc coverage, version drift, algorithms, tooling and engine implications |
| [Course-driven probes](docs/COURSE_PROBES.md) | 18 complete programs and measured JVM/native results, including serialization and exception failures |
| [Engine plan](docs/ENGINE_PLAN.md) | Architecture, library decision, ownership rules, genre systems, creator pipeline and milestone gates |
| [G0 resource tokens](docs/G0_RESOURCE_TOKENS.md) | Checked slot/generation/kind lifecycle contract and regression proof |
| [G0 backlog](docs/G0_BACKLOG.md) | Active bounded implementation sequence and deferred scope |
| [G0 scalar adapter](docs/G0_SCALAR_ADAPTER.md) | Scalar SDL lifecycle and Kof-owned window/audio state contracts with proof limits |

[Portuguese documentation](pt-BR/docs/) mirrors every English document.


## Findings that change the plan

1. **Version drift:** examined compiler/release is 0.4.9-beta, while the fetched README/site advertise older versions. Pin source and executable separately.
2. **Games exist:** [DoomKof](https://github.com/M-Tesla/DoomKof) has `.kf` gameplay with JVM Jaylib/raylib or browser Canvas; [Byte Eater](https://github.com/lavdev/kofman) uses KofJS/Canvas. Neither establishes a shipped native-ELF FPS.
3. **Real native interop:** our `.kf` probes called libm and installed SDL3 on JVM/native x86-64. Float-array FFI was correctly rejected with `FFI001`.
4. **Native runtime risk:** current auto-GC gate closes after Kof `spawn`. Begin single-threaded; preallocation is useful but not proof of long-running stability.
5. **Editor is not an all-Kof native IDE:** substantial interactive behavior is handwritten JS served from `.kf` strings. Run copies one document and hardcodes JVM; privileged host routes lack authentication. Use compiler CLI and a separately configured LSP-capable editor for engine work.
6. **Deeper compiler checks found blockers:** native fractional-record JSON failed; an assertion after a normally completed try/catch re-entered the old handler and falsely exited successfully. Native bounds faults skipped catch/finally. Do not trust course “PASS” output or blanket target-parity claims.
7. **Minecraft reuse is selective:** Java26.3 now uses SDL3, but its mods are not standalone engine libraries. JOML1.10.9 ran from Kof JVM with `--deps`; native rejected its Java imports. Prefer bounded math/command ports and data/lifecycle contracts; Jolt, RmlUi or ImGui would require explicit foreign-subsystem ownership choices.

## Installed local tooling

`kof`, `mvn` and `kof-editor` are on the user PATH. Kof4j 0.4.9-beta has a pinned
local LSP/DAP repair; Kof Editor 0.1.4-beta uses a project-restricted, private-network
launcher. Existing MrCode has an actual Kof language client, formatter, CLI tasks
and JVM/native debug configurations. Reload its window after installation.
See [installation, commands, safety and proof boundaries](docs/KOF_EDITOR.md#local-installation).

## Verification before push

Run the same gate locally and in GitHub Actions:

```bash
bash scripts/verify.sh
```

It runs the Kof source linter, LSP diagnostics, JVM/native compiler checks,
named regression tests, JVM/native runtime smoke checks, the optional native
SDL adapter smoke when dependencies and pressure permit, and JVM/native builds.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the contract.
The adapter smoke defaults to `SDL_VIDEODRIVER=offscreen` and passes the first
available `/dev/dri/renderD*` node to the isolated wrapper. Override with
`KOOKIE_RENDER_NODE=/dev/dri/renderD129`; set `KOOKIE_SDL_VIDEO_DRIVER=x11`
only when testing a presentable window path. Set
`KOOKIE_SCREENSHOT_PATH=/absolute/path.ppm` to export a presentable frame as
binary PPM; the file is written only when window presentation is available.

This setup does not resolve the native runtime blockers below.

G0 native feasibility is implemented. The isolated native adapter smoke now
accepts hidden-window lifecycle, resize/focus event flattening, dummy audio,
stale-token teardown, process cleanup, and an offscreen SDL_GPU indexed
textured quad with explicit vertex/index-buffer uploads, per-device cached GPU
resources, and fence-wait telemetry within the declared 16,667-microsecond
frame budget; the latest sample measured 1675 microseconds for three draws on
`renderD128`, including a 527-microsecond fence-wait sample. An overlap probe
submitted four frames across two target slots, retired all fences, and observed
peak in-flight depth two. A clean device recreation rebuilt cached resources
and completed a post-recovery draw. Window presentation still reports
`gpu-unavailable` because the Xvfb path has no DRI3 presentation support; a
capability probe reports swapchain format and present modes when a window
device is claimable.
G1 includes fixed-step authority, bounded input commands and edge transitions,
two-client loopback admission, per-client stale-input rejection, snapshot
sequence validation, bounded authoritative movement, camera/input clamping,
bounded integer component storage, bounded snapshot history with interpolation,
bounded prediction input replay, scalar collision queries, integer 3D segment
and triangle sweeps, radius-expanded capsule movement, deterministic bounded
triangle collection/BVH queries with removal/rebuild and geometry revisions,
eight-slot ordered capsule step obstacles with clear/reconfigure operations,
frame staging budgets, authoritative-session broad-phase snapshots with bounded
payload application and sequence guards, a fixed-capacity validated broad-phase
transport queue with overflow rejection, a bounded native UDP peer transport
probe across paired localhost sockets with validated `RemoteSessionEndpoint`
configuration for IPv4 peer address/port, authenticated SipHash framing,
explicit non-zero key provisioning before open through
`KOOKIE_TRANSPORT_KEY_HEX` or a mode-0600-or-stricter
`KOOKIE_TRANSPORT_KEY_FILE`, explicit closed-transport key rotation,
activation freeze, sequence/length validation, signed payload words, and a
1,000 ms receive timeout. The authoritative session probe drives three
authenticated broad-phase ticks, and SDL reset/lost events retire GPU resources
through the event pump before recovery. A Kof 0.4.10-beta verification rerun
preserves the observed native exception-lifetime gate. A capability-gated DRI3
window path now renders a swapchain frame and captures a screenshot checksum
when presentation is available. Next: run that path on an isolated
present-capable host. Use the repository's disposable isolated-display wrapper
for graphical verification.
Do not create a large untested engine scaffold first.
## Provenance

Research recorded 2026-09-22. Primary links, pinned upstream SHAs, executable hash and distinctions between measured/source-derived/proposed claims are in the documents. Sibling trees were inspected read-only and may change. No source/asset license was assigned or changed.
