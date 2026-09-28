# Games made with Kof and their graphics stacks

Research date: 2026-09-22. Internet/API/source research only; none of these games was built or launched here.

## Answer

**Yes: two concrete source-published Kof games were found**, including an FPS-like raycaster. A third Pong demo is reported in an upstream issue. None of the inspected material establishes a released, production-quality shooter using Kof's native ELF backend.

| Project | Classification | Actual graphics/runtime route | Confidence |
|---|---|---|---|
| [DoomKof](https://github.com/M-Tesla/DoomKof) | Doom-inspired software-raycast FPS prototype | `.kf` simulation → JVM → **Jaylib JNI 5.5.0-2 → raylib**; alternate `.kf` → KofJS → **browser Canvas2D with authored JS** | Source/build verified; not executed |
| [kofman / Byte Eater](https://github.com/lavdev/kofman) | Pac-Man-style browser arcade game | `.kf` → **kof.ui / KofJS / Canvas2D + DOM**; JVM `kof.web` backend; JS keyboard glue | Source/build verified; not executed |
| [Pong by tomast1337](https://github.com/KofLang/Kof4j/issues/431#issuecomment-5722558116) | Video-linked experimental game | Author reports **Kof + raylib**; discussion describes C bridge | No game source/build located; exact target/version not verified; video not viewed |
| Kof4j `tetris.run()` | Bundled terminal easter egg | Kof call → **Java runtime + ANSI terminal / stty** | Implementation source verified; game logic is not `.kf` |

GitHub releases APIs returned empty arrays for DoomKof and kofman during research. This does not mean they cannot be played from source, nor that no release exists elsewhere. No KofLang Steam/itch title was identified in the scoped search.

## DoomKof: the most relevant precedent

Snapshot: [`d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb`](https://github.com/M-Tesla/DoomKof/tree/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb), commit 2026-08-29.

The README calls it a simple experiment. It is a Doom-inspired raycaster, **not an original Doom port, WAD-compatible engine or proof of full 3D**.

### What is actually Kof

[`src/engine.kf`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/src/engine.kf) contains map/game state, collision/ray stepping, enemies, shooting, pickups and rendering-column data. Observed configuration includes a 16×16 map, fixed-point scale 256, 64 columns and 640×400 presentation. Representative functions: `ray`, `fillColumn`, `fire`, `boot`, `tick`, `tickView`.

This is meaningful Kof game logic, not merely a Kof launcher around another engine.

### Desktop graphics evidence

[`src-raylib/main.kf`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/src-raylib/main.kf) imports:

```text
com.raylib.Raylib
com.raylib.Helpers
org.bytedeco.javacpp.BytePointer
```

It calls `InitWindow`, `SetTargetFPS(24)`, input/cursor polling, `DrawRectangle`, `DrawText`, `BeginDrawing`, `EndDrawing`, `CloseWindow`. The column renderer is implemented through those drawing primitives.

[`scripts/run-raylib.sh`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/scripts/run-raylib.sh) pins `uk.co.electronstudio.jaylib:jaylib:5.5.0-2`, builds with `--target=jvm --classpath`, then invokes Java with compiled classes and Jaylib on the classpath. [`DEPENDENCIES.md`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/DEPENDENCIES.md) identifies JNI Jaylib, not Jaylib-FFM.

**Conclusion:** a native OS window backed by raylib, but the Kof code executes on the JVM. This is not `--target native` evidence.

### Browser graphics evidence

[`scripts/build-js-play.sh`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/scripts/build-js-play.sh) builds engine Kof to JS and patches exports. [`web/play.mjs`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/web/play.mjs) imports them, gets a Canvas2D context and draws walls/sprites/weapon/HUD/minimap. It also owns DOM keyboard/mouse/pointer lock and frame scheduling.

The browser route therefore contains substantial handwritten JS presentation/input. Do not use it as proof of our stricter all-Kof engine-logic goal.

### Historical compatibility and reuse

The project targets Kof 0.2.1-beta/JDK 21 and reports old compiler/classpath/constant/void-call workarounds. Treat these as dated project observations, not current 0.4.9 limitations. No license file was found in the inspected tree, and GitHub license metadata was null. Study architecture, but do not copy source without resolving permission.

## kofman / Byte Eater

Snapshot: [`d0d0d1bdb83653d58f9a21e8552775b7d4839699`](https://github.com/lavdev/kofman/tree/d0d0d1bdb83653d58f9a21e8552775b7d4839699), commit 2026-09-11. MIT license in repository.

### Actual architecture

- [`Makefile`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/Makefile): KofJS frontend build, sprite copy, web-input patch, JVM server.
- [`game.kf`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/src/game/game.kf): Kof UI window/labels/Canvas, 100 ms interval, gameplay update, drawing and HUD.
- [`simulation.kf`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/src/game/simulation.kf): movement, enemies, collision, frightened mode, death/reset and progression.
- [`draw_ops.kf`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/src/game/draw_ops.kf): flat integer draw operations separating simulation/scene construction from Canvas handles.
- [`server.kf`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/src/server/server.kf): health/score REST routes, static files and `app.listen(8080)`.
- [`assets/web-input.js`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/assets/web-input.js): authored JS keyboard-to-button bridge.

Graphics is browser Canvas2D/DOM, not SDL, Sokol, raylib or LWJGL. The JVM process serves HTTP; it does not render the game.

The “100% Kof” headline needs qualification: gameplay and backend are Kof, but browser input and build glue include JS/shell. The README's baseline is 0.3.2-beta. It explicitly says the game client does not submit scores itself; REST submission is demonstrated separately. Browser runtime claims in the README were not reproduced here.

**Lesson for KOOKIE:** pure simulation plus extracted drawing commands is useful. A 10 Hz maze game with generic list draw commands is not a performance model for an FPS; port the separation, not the limitations or temporary compiler workarounds.

## Pong, native FFI, and what upstream tests prove

[Issue #431](https://github.com/KofLang/Kof4j/issues/431), opened 2026-09-17, describes an initial direct-raylib `extern` failure on Kof 0.4.2-beta. The author posted [“pong in kof+raylib”](https://github.com/KofLang/Kof4j/issues/431#issuecomment-5722558116) with a video attachment. Another comment describes a C bridge. No standalone source, exact raylib version, license or reproducible demo command was found.

The issue was closed on 2026-09-20 after scalar native FFI landed. Do not repeat the original report as a blanket current lack of native FFI. Conversely, closing the issue does not establish an inspected production graphics integration.

Important source detail: upstream [`FfiNativeE2ETest`](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/test/java/dev/kof/compiler/FfiNativeE2ETest.java#L32-L69) defines its **own** C `InitWindow` fixture, which prints arguments. It tests a raylib-shaped ABI; it does not open a real raylib window.

Our separate SDL3 version query proves a real scalar library call, but likewise does not create a window. See [RESEARCH_PROBES](RESEARCH_PROBES.md).

## Official graphics support is not a ready-made FPS stack

- [`kof.ui` Canvas tutorial](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/learn/35-kof-ui.md): DOM/KofJS rendering, JVM/native no-op UI paths. Source confirms browser `document.createElement("canvas")` / `getContext("2d")` and placeholder JVM drawing methods.
- [`kof-ui-widgets`](https://github.com/KofLang/kof-ui-widgets/tree/7f359825f86093e98a75c846696e0813301f306c): `.kf` widgets and charts; [target document](https://github.com/KofLang/kof-ui-widgets/blob/7f359825f86093e98a75c846696e0813301f306c/docs/targets.md) distinguishes real browser/webview rendering from JVM/native no-ops.
- [`KofGpu.java`](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/KofGpu.java): specialized Vulkan matrix compute, not a frame renderer. C Vulkan helpers and GLSL compute shaders do not establish a native game renderer.
- [`KofTetris.java`](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/KofTetris.java) and [runtime implementation](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/jvm/JvmStringMiscRuntime.java#L123-L197): JVM-only terminal game implemented in Java runtime source.
- [KofOS applications ledger](https://github.com/KofLang/KofOS/blob/7a5d40b426e7f7c8708853225a7f94d3ce6f830d/docs/apps_and_modules.md): Snake/Tetris/Pac-Man/Pong and other inherited VibeOS game names explicitly **not ported**. Do not count plans as Kof games.

## Search scope and negative evidence

Discovery used general web searches in English/Portuguese, direct GitHub org/repository searches, candidate build/render source, release endpoints and upstream issue discussion. Public web search alone missed the two strongest examples; GitHub README searches found them.

Representative public-web queries:

```text
KofLang Kof4j game graphics engine
"KofLang" jogos OR jogo OR motor OR biblioteca OR gráfico
"KofLang" OR "Kof4j" "SDL" OR "raylib" OR "sokol" OR "LWJGL" OR "OpenGL"
"Kof" "linguagem" "jogo" -"King of Fighters" -SNK -mugen
"KofLang" OR "Kof4j" site:itch.io OR site:store.steampowered.com
```

GitHub API search scope/results at research time:

| Repository/README query | Results / interpretation |
|---|---|
| `Kof4j in:readme` | 20, including DoomKof and kofman |
| `KofLang in:readme` | 14, mainly tooling/apps plus kofman |
| `kof raylib in:readme` | 3; DoomKof plus unrelated C/C++ projects |
| `Kof4j SDL in:readme`, `KofLang SDL in:readme` | 0 each |
| Equivalent Kof4j/KofLang + LWJGL or OpenGL | 0 each |
| `KofLang sokol in:readme` | 0 |

[Org API](https://api.github.com/orgs/KofLang/repos?per_page=100&type=all) returned ten public repos: Kof4j, koflang.github.io, Kof-Editor, kof-docker-image, kof-agent, kof-ui-widgets, kof-docs, Kof-editor-theme-maker, KofOS, KofWatch. No dedicated official game engine was present in that list.

Reproducible endpoints: [Kof4j README search](https://api.github.com/search/repositories?q=Kof4j+in%3Areadme&per_page=100), [KofLang README search](https://api.github.com/search/repositories?q=KofLang+in%3Areadme&per_page=100), [raylib search](https://api.github.com/search/repositories?q=kof+raylib+in%3Areadme&per_page=100), [DoomKof releases](https://api.github.com/repos/M-Tesla/DoomKof/releases?per_page=100), [kofman releases](https://api.github.com/repos/lavdev/kofman/releases?per_page=100).

Excluded false positives: King of Fighters projects (including C/SDL games), owner names such as K0F, unrelated C++/raylib fighting games, and compiler forks mistaken for games. “Kof” is an especially noisy search term.

These searches are not authenticated exhaustive global code searches. Private/unindexed projects, different names, branches and releases outside GitHub could be missed. Correct conclusion: **no reusable native Kof SDL/Sokol/LWJGL package or shipped native shooter was established within this scope**, not “none exists.”

## Consequence for the engine plan

Use these projects as evidence that Kof can express game logic and interoperate with graphics, not as proof that native runtime, asset upload and frame-time problems are solved. Keep KOOKIE's CPU engine logic genuinely `.kf`; evaluate the narrow SDL3 graphics ABI explicitly. No browser renderer, Jaylib runtime switch, Java Tetris or hidden C engine should be labeled an all-Kof native shooter implementation.

## Related Java ecosystem research

[MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md) separately assesses Minecraft Java26.3, its actual dependencies, mod libraries and standalone alternatives across ECS, GUI, physics, sound and rendering. These are not additional Kof games. It includes a real JOML1.10.9 Kof JVM probe and native import-rejection control; graphics/audio/physics integration remains untested.
