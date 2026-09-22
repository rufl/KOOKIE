# Kof Editor: what to learn, use and avoid

Research and installation date: 2026-09-22. The original source audit below preceded installation. The later [local installation](#local-installation) includes actual compiler, protocol and isolated native-window verification.

Pinned source: [`KofLang/Kof-Editor@bed6ae7d567b090497a447583a10b8522acaf66a`](https://github.com/KofLang/Kof-Editor/tree/bed6ae7d567b090497a447583a10b8522acaf66a), `VERSION` = `0.1.4-beta`. Compiler cross-reference: [Kof4j 22a186b9](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63), 0.4.9-beta. Upstream packaging may select older compilers. The locally installed pairing is verified only for the workflows listed below, not every upstream feature.

## Actual architecture

```text
core scanner/theme + front.kf + web.kf
                │ scripts/web-combine.sh
                ▼
       build/editor-web.kf
                │ kof serve (JVM)
                ▼
 legacy handle(method,path,body) HTTP server
                │
                ▼
 handwritten HTML/CSS/JavaScript served from Kof strings
                │
                ▼
 browser or Linux WebKitGTK native window
```

The backend, scanner and theme logic contain real Kof code. However, `pageJs()` in `src/ui/web/web.kf` contains substantial **handwritten JavaScript** implementing document state, text editing, tabs, keybindings, completion, formatting and DOM updates. A `.kf` file containing JavaScript strings is not an all-Kof implementation of those behaviors.

“Native window” means WebKitGTK hosting the web UI, **not** the editor compiled to Kof native ELF. The separate core console demo exercises lexer/buffer/theme functionality; it is not the GUI.

The web UI uses a transparent textarea over highlighted text, gutter and minimap. Its buffer is JavaScript document state, not the `src/core/buffer.kf` demo's `List<String>` buffer. The web combiner excludes that buffer and highlighter.

The editor scanner is a separate `.kf` implementation following compiler lexer behavior. It is not the compiler's actual Java frontend imported into the editor. Static Pages introduces another small JavaScript tokenizer. Language versions can drift between all three.

Sources: [web implementation](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/ui/web/web.kf), [web combiner](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/web-combine.sh), [scanner](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/core/lexer.kf), [core buffer](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/core/buffer.kf).

## Feature inventory

| Area | Source implements | Boundary |
|---|---|---|
| Editing | Tabs, explorer, gutter, minimap, wrap, autosave, palette, snippets | Whole-document repaint/tokenization; not a mature incremental editor model |
| Themes | Six palettes; granular schema; Kof JSON/YAML import/export | Useful Kof data-processing reference; avoid copying GPL code without license review |
| Problems | Lexer error tokens | Not semantic/type diagnostics |
| Check | Actual `kof check` subprocess, output panel | Separate action, not continuously attached LSP |
| Completion | Static JS words + document regex symbols | Not typed member completion |
| Navigation | Active-document token outline/text search | Not project symbol resolution |
| Rename | Word-boundary text replacement in current document | Can touch unrelated symbols/comments/strings |
| Formatting | Browser JS formatting function | Not the compiler formatter, even though an unused Kof formatting helper also exists |
| Run | Copies active file to shared temporary directory; invokes compiler | Loses sibling modules/config/assets; target hardcoded JVM |
| Terminal | One-shot shell command | No persistent PTY/session; cwd handling is unreliable |
| Git | CLI status/diff/stage/commit | Repository cwd ambiguity and broad `git add -A`; unsafe for shared monorepo work |
| Debugging | No source implementation of LSP/DAP client or breakpoints found | Compiler tooling availability is not editor integration |

### Critical workflow details

- `front.kf` copies only the active file into fixed `/tmp/kof-editor-run`, removing existing `.kf` files there first. **[INFERENCE]** simultaneous sessions conflict and multi-file engine execution is not faithful.
- Run's UI target toggle can display JVM/JS, but `/api/run` passes the literal `"jvm"` to `kofRun`. This is a current editor source defect, not a native compiler limitation.
- Check/Run write the supplied document path first (`saveTempDoc` is misleadingly named), then compile. They are not harmless checks against an isolated unsaved buffer.
- Backend commands invoke `kof` from `PATH`; setting the launch script's `KOF` variable alone does not pin that subprocess compiler.
- Completion/formatting change textarea state through paths different from ordinary input/save state. **[INFERENCE]** stale document state can be saved/restored; no execution proof was collected. Avoid unsaved transformations until tested.
- The terminal constructs a cwd-prefixed command but posts the original command. **[INFERENCE]** its displayed cwd does not establish the actual subprocess cwd. Use a real terminal for builds.
- Nine language templates do not establish nine live syntax parsers: `/tokenize` dispatches to the Kof lexer.

Source: [front.kf](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/ui/front.kf), [web handlers](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/ui/web/web.kf#L1903-L1984).

## Security: privileged host tool, not a sandbox

**Source-verified:** editor routes accept arbitrary paths for read/write and arbitrary shell text for `/api/exec` and `/api/gitcmd`. No authentication, workspace restriction or Origin/CSRF check appears in those handlers. Some filesystem/Git paths are interpolated into shell commands without adequate shell escaping. A directory selected in the explorer is not a filesystem security boundary.

**Source-derived exposure with the inspected compiler:** `scripts/web.sh` passes only `--port`. Kof 0.4.9 `CmdServe` defaults `host = "0.0.0.0"`; the editor's legacy `handle(...)` path passes that host to `KofHttpServer.serve`, which creates the server socket. Its dispatch calls the handler directly. Therefore the upstream script paired with this compiler is configured to listen on all interfaces, not just localhost. Printing a localhost URL does not change binding. No exploit was run. The local launcher below does not use this exposed configuration.

For **this legacy handler mode**, explicitly passing `--host 127.0.0.1` changes the bind address. It still does not add authentication, Origin checks or workspace confinement. A network-isolated disposable environment with only a scratch workspace is the preferred research environment. Do not run this editor against untrusted projects, expose it to a LAN, or let it commit monorepo changes.

Do not confuse this with Kof `web.app()` + `main()` mode: that path owns its server and ignores the CLI host/port flags. It is not the current Kof Editor serving path.

Compiler evidence: [CmdServe default/flag parsing](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdServe.java#L39-L84), [legacy serve branch](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdServe.java#L177-L218), [KofHttpServer](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/KofHttpServer.java#L39-L58).

## Source and package workflows

These upstream interfaces were recorded during the original source audit; they are **not the installed local launcher**. The installation used `web-combine.sh` and explicit loopback serving inside a private network namespace. Do not run the unconfined server command below as the normal desktop workflow.

```sh
# Core console demonstration, not editor UI
KOF=/absolute/path/to/kof bash scripts/run.sh --no-pause
KOF=/absolute/path/to/kof bash scripts/build.sh

# Compile/serve the actual UI explicitly; set PATH for child compiler commands too
bash scripts/web-combine.sh
/absolute/path/to/kof serve build/editor-web.kf --port 8080 --host 127.0.0.1

# Upstream installer/package interfaces, not recommendations to run blindly
KOF=/absolute/path/to/kof bash scripts/install.sh
KOF_JAR=/absolute/path/to/kof.jar bash scripts/package-editor.sh
```

Dependencies vary: Bash, Kof/JVM, browser or WebKitGTK host; Git for Git actions, shell for processes, optional `zenity` folder picker and `script` utility. An embedded JDK in the compiler distribution does not make the editor package itself self-contained.

Observed source inconsistencies:

- Source installer contains an author-specific `/home/mel/.../kof-webview` path, later hardcodes `~/.local/bin/kof`, and has inconsistent configurable/hardcoded ports.
- Its launcher computes an open-file URL but does not pass that URL to the WebView launch.
- Current packager embeds source into a copied compiler JAR; it is not a native editor build. The Unix extraction path appears to produce `editor/editor/src.kf` while launching `editor/src.kf` **[INFERENCE; not reproduced]**.
- Packaging/workflows mix compiler release tag `0.2.6-beta` with asset names `0.2.5-beta`. Do not assume a downloaded package uses the current compiler.
- Old `release.sh --jvm` pins alpha JAR names. `--native` can suppress build failure and still create a native-named archive without a native executable. Archive existence is not runtime proof.
- README's tag-release description differs from current push/manual CI packaging. Historical Swing scripts mentioned in docs are absent from the inspected scripts directory.

Sources: [installer](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/install.sh), [packager](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/package-editor.sh), [legacy release](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/release.sh), [current release workflow](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/.github/workflows/release.yml).

## Static Pages is a separate mode

`static-snapshot.sh` captures HTML/CSS/JS from the server and replaces HTTP calls with a handwritten JavaScript fetch/filesystem shim. This is **not** compilation of the whole editor through KofJS.

Bundled demonstration mode cannot compile/run processes or perform real Git operations. Supported browsers may grant access to a user-selected directory through File System Access APIs, but still have no Kof compiler. A success-style “demo: no compiler” response is not build evidence. The browser tokenizer is a different implementation and cannot certify semantic validity.

Source: [static-snapshot.sh](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/static-snapshot.sh).

## Historical compiler failures are not current guarantees

README still describes a native lexer crash against Kof 0.2.3-beta. Its own [restriction ledger](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/docs/08-restricoes-kof.md) explicitly closes R1, citing collector/reference-resolution fixes and reported core parity. Those are historical upstream reports, not a 0.4.9 engine benchmark.

Do not inherit old prohibitions on module imports, field names, method order or increment syntax without a current reproducer. Conversely, upgrading Kof does not fix editor-owned temporary-file copying, hardcoded targets, shell quoting or package paths.

## Decision for KOOKIE development

Use the pinned compiler CLI from the actual project/entry root, plus an existing editor configured as a client of `kof lsp`. Kof Editor is optional language-study material, **not a prerequisite to engine development and not the proposed world editor**.

Current upstream LSP docs describe diagnostics, stdlib completion/signature help, hover, definitions, references, formatting and project rename. They also document text-scanning limitations: cross-file navigation/rename is not a fully typed semantic index and may affect unrelated same-name occurrences. Preview refactors. The generated VS Code grammar/command extension does not automatically establish an attached LSP client.

Upstream documents JVM/native DAP through JDWP/GDB/MI; Kof Editor does not wire those features in. Installed CLI debugger sessions were subsequently exercised after local protocol repairs; see the verification boundary below.

```sh
kof editor list
kof editor detect
kof editor status
kof lsp
```

External development tools do not violate `.kf` engine ownership. Do not copy the editor's JS-in-strings UI, ad hoc compiler duplication, privileged HTTP shell or concatenated build workaround into KOOKIE.

References: [LSP contract](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/tooling/LSP.md), [editor tooling](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/editors/overview.md), [VS Code scope](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/editors/vscode.md), [GPLv3 editor license](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/LICENSE).

## Local installation

All additions are user-local. No system package replacement, desktop autostart,
background editor service or global IDE settings change was made.

| Component | Installed location / version |
|---|---|
| Kof CLI | `~/.local/bin/kof` → `~/.local/share/kof4j/0.4.9-beta/bin/kof` |
| Compiler source | Persistent checkout at `~/.local/share/kof4j/0.4.9-beta/source`, pinned SHA above plus local tooling patch |
| Compiler JAR | SHA-256 `9a4c133d773058a0ea3b3bf503511439e67bbb8efb80a2d5ab848dbc8274b548`; **not** the unmodified release JAR |
| Maven | `~/.local/bin/mvn`, Apache Maven 3.9.16; official archive SHA-512 verified |
| Java | Existing system OpenJDK 27; compiler source requires Java 25 or newer |
| Kof Editor | `~/.local/bin/kof-editor`, source 0.1.4-beta at `~/.local/share/kof-editor/source` |
| Native WebView | Built from the pinned Kof4j C source, using existing WebKitGTK 4.1 / GTK 3 |
| LSP / DAP client | Existing MrCode, installed local extension `lich-local.kof-lsp-client@0.1.0`; `vscode-languageclient` 9.0.1 |
| Native prerequisites | Existing GCC 16.2, binutils 2.47, GDB 17.2, pkg-config, SDL3 3.4.16, Vulkan headers/loader, ShaderC and SPIRV-tools |
| Other prerequisites | Existing Git, Bash, curl, unzip, Python, bubblewrap and DBus tools |

```sh
kof version
mvn --version

# Run from the real entry/project directory; relative assets keep that cwd.
kof check main.kf --target native
kof run main.kf --target native
kof run main.kf --target jvm

# Kof Editor: explicitly choose the only project exposed to its backend.
kof-editor --workspace /absolute/project /absolute/project/main.kf
kof-editor --check --workspace /absolute/project

# LSP-capable development workflow; reload an already-open MrCode window.
mrcode /home/lich/lichforge/code/monorepo/engines/KOOKIE
```

In MrCode, trust only projects whose compiler/debugger execution you authorize.
The extension recognizes `.kf` and `.kof`; it starts `kof lsp` over stdio rather
than opening a terminal. Use **Kof: Select Target**, **Run Active File**,
**Check Active File**, **Build Active File Directory** and **Format Active
Document**. `.vscode/tasks.json` provides explicit target selection and project
tasks; `.vscode/launch.json` supplies JVM/native F5 configurations. LSP analysis
still uses upstream JVM semantics; native checking is a separate CLI task.
The extension is disabled in untrusted and virtual workspaces.

### Local editor confinement

The desktop entry defaults to KOOKIE; the CLI can select another project.
The launcher starts the JVM backend and real WebKitGTK window inside bubblewrap
with a private network, PID/IPC/UTS namespaces and a private DBus session.
Only the selected project is writable at `/workspace`; system/compiler/editor
files are read-only. The host home, SSH credentials and unrelated projects are
not exposed. Backend `127.0.0.1:8765` exists only inside that private network,
not on host loopback or the LAN. Compiler commands use the pinned installation.
State and `server.log` live in `~/.local/state/kof-editor/workspaces/`.

This confines the upstream privileged handlers; it does **not** repair their
authentication, shell quoting, Git cwd or single-file JVM Run behavior.
Do not use the built-in Git/terminal against untrusted content. Remote Git and
downloads are intentionally unavailable inside the private network. Use MrCode
and a real terminal for native or multi-file projects. Closing the launcher
reaps its server/window process groups.

### Local tooling repairs and verification boundary

The unmodified compiler exposed reproducible tooling defects. The local source
patch retains full-sync LSP buffers after edits, evicts closed buffers and emits
numeric completion kinds. DAP now emits `initialized` once the backend is ready,
completes configuration before acknowledging launch, reports owned JVM exit,
and detaches attached JVMs without killing them. Native evaluation quotes its
GDB/MI expression as one argument. No compiler/runtime semantics were changed.

Verified:

- Final installed CLI: JVM/native check, build and execution; relative file access
  and `math.sqrt(81.0)` returning `9.0`.
- Installed stdio LSP: invalid diagnostics, clearing after edits, completion,
  hover and formatting using the updated buffer.
- Installed JVM and real-GDB native DAP: initialize/configure, `.kf` breakpoint,
  source stack frame, continue and termination. JVM local `value = 41` and
  native evaluation `40 + 2 = 42` were observed.
- Focused compiler regression group: 46 tests, zero failures/errors/skips.
- Actual Kof Editor native window: visually inspected in isolated X11; backend
  open/save/check/run succeeded. Host-home exclusion, read-only compiler mount
  and private network namespace were checked.
- Actual MrCode extension host: `.kf`/`.kof` association, diagnostics clearing,
  completion, hover and formatting; JVM/native Run preserved relative file
  access, and both F5 sessions stopped at line 3 and terminated after continue.
  The native breakpoint was also visually inspected.

Receipts, protocol traces and editor/IDE screenshots are retained under
`~/.local/state/kof-tooling-verification/`. Graphical checks used the reviewed
`overzeer-isolated-display.sh` wrapper with private sockets, bounded lifetime,
serialized execution, pressure gating and process-tree cleanup—not the active
desktop. No repository-wide test matrix was run.

The native smoke returned no locals for its simple constant local; only native
expression evaluation is established, not comprehensive variable inspection.
JVM stepping/evaluation, every LSP request, browser KofJS, every editor menu and
the engine graphics/audio stack were not verified by this installation.
MrCode emitted a generic, unattributed error notification during automated
debugging; the captured DAP trace had no failed or unanswered requests and both
sessions completed. This is not a claim that all IDE notifications are resolved.
The native adapter also reports its exit code as a string in the captured
upstream event; strict consumers may require further protocol work.
Native runtime pruning still warns when its source-relative lookup fails and
emits the full runtime; the cwd-preserving native run passed with that warning.
The native handler-lifetime, fractional-record JSON and cumulative `spawn`/GC
risks recorded in the research remain engine G0 blockers, not installation fixes.

For maintenance, retain the installation JSON, original upstream JAR and
`artifacts/tooling-fixes.patch` under `~/.local/share/kof4j/0.4.9-beta/`.
An upstream reinstall can overwrite the repaired JAR: reapply/review the patch,
run the focused LSP/DAP tests, then repeat the installed workflows before
switching versions. Editor source, launcher and provenance are retained under
`~/.local/share/kof-editor/`; client source, lockfile and installable VSIX under
`~/.local/share/kof-lsp-client/`.
