# KOOKIE
[Português (Brasil)](pt-BR/README.md)

Public pages and documentation are maintained in English and Brazilian Portuguese. Keep matching changes synchronized under `pt-BR/`.


Research and plan for a **Kof-first, native 3D shooter engine**: boomer shooters, looter shooters and ARPG FPS.

**Current state:** G0 implementation has started. A minimal modular Kof core,
session envelope smoke codec, checked resource-token registry, scalar SDL
lifecycle contract, bounded window/audio state, and a narrow native SDL adapter
exist. Compiler checks and Kof contract tests pass on JVM/native. The native
window/audio smoke is wired but its isolated-display run remains pressure-gated;
SDL_GPU, textured rendering and multiplayer transport are not implemented.

## Proposed direction

- All engine-owned CPU logic and authoring/cooking behavior in **`.kf`**.
- Initial runtime: **Kof native Linux x86-64**, with JVM used as a development comparison target.
- Preferred platform/render library: **SDL3 + SDL_GPU**, first Vulkan/SPIR-V.
- Non-Kof limited to indispensable external libraries, small ABI marshaling, GPU shaders and minimal tool/bootstrap glue. No hidden C/Java/Rust/Zig engine.
- Borrow algorithms and contracts from DINX, ZYLVE and CUBSHIP; do not transplant their engines or assume rights to their assets.

This is a proposed stack, not a proven graphics binding. Kof scalar FFI works; buffer/struct/pointer limitations, exception-handler correctness and native collector behavior must be addressed before committing to a sustained shooter workload.

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
only when testing a presentable window path.

This setup does not resolve the native runtime blockers below.

G0 native feasibility is implemented. The isolated native adapter smoke now
accepts hidden-window lifecycle, resize/focus event flattening, dummy audio,
stale-token teardown, process cleanup, an offscreen SDL_GPU textured quad mesh
with GPU-idle timing within the declared 16,667-microsecond frame budget; the
latest sample measured 1461 microseconds for three draws on `renderD129`.
Window presentation still reports `gpu-unavailable` because the Xvfb path has
no DRI3 presentation support. G1 includes fixed-step authority, bounded input
commands and edge transitions, two-client loopback admission, per-client
stale-input rejection, snapshot sequence validation, bounded authoritative
movement, camera/input clamping, bounded integer component storage, bounded
snapshot history with interpolation, bounded prediction input replay, scalar
collision queries, integer 3D segment and triangle sweeps, radius-expanded
capsule movement, deterministic bounded triangle collection/BVH queries with
removal/rebuild and geometry revisions, bounded capsule slide/step traversal,
and shared player/projectile/line-of-sight admission. Next: add a DRI3-capable
isolated presentation path, replace shader-generated vertices with bounded GPU
vertex/index-buffer uploads, add stale broad-phase revision rejection, and
extend capsule obstacles before weapons. Use the repository's disposable
isolated-display wrapper for graphical verification.
Do not create a large untested engine scaffold first.
## Provenance

Research recorded 2026-09-22. Primary links, pinned upstream SHAs, executable hash and distinctions between measured/source-derived/proposed claims are in the documents. Sibling trees were inspected read-only and may change. No source/asset license was assigned or changed.
