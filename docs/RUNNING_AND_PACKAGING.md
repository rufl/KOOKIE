# Running and packaging KOOKIE

[Português (Brasil)](../pt-BR/docs/RUNNING_AND_PACKAGING.md)

This page keeps build, package and qualification detail out of the project
homepage. KOOKIE is experimental: these commands exercise bounded evidence
contracts, not a production support promise.

## Runtime gameplay tuning

Native presentation builds load `config/runtime/enemy_tuning.json` (source:
`assets/prototype/runtime/enemy_tuning.json`). Values use integer game units
and are validated before the session starts. Edit the packaged JSON to tune
enemy perception/attack ranges, cooldowns, weapon damage/range, and encounter
count/delay without rebuilding. The file must contain all schema-version-1
fields; missing, malformed, out-of-range, unknown, or duplicate fields prevent
the demo session from starting. Keep protocol constants, array capacities,
resource limits, and launcher security limits compiled in; they are invariants,
not gameplay tuning.

## Developer/source run

Install the official Kof 0.6.8 Linux release distribution, matching source tag
`kof-0.6.8-linux-x86_64` and commit
`2971d2fe4cc873eb50fcd1b7d7d3e097381281c8`. Its published archive SHA-256 is
`8da8f9efc7c55b6e5314248b90a0ac62d900117f4a3503af8dadf6ce82a20577`.
The release workflow builds the pinned source commit for its reproducible
toolchain artifact; it does not consume that upstream archive.

`scripts/install_kof_lab.sh` is a separate rolling-upgrade workflow. It follows
the moving `lab` branch and updates the repository pin; do not use it when you
need the fixed 0.6.8 release baseline.

To refresh this environment from the current Kof lab head, run
`bash scripts/install_kof_lab.sh`. It builds the current lab commit, checks that
the branch did not move during the build, then updates the tracked source pin,
installs the result under `~/.local/share/kof4j/`, and atomically points
`~/.local/bin/kof` at the new installation. Existing installations remain
available for rollback. If `lab` advances during the build, the installer
fails closed without switching `kof`; rerun it.

Before any native Kof command, source `scripts/kof_pin.sh`. The pin script
prepends `scripts/kof-as/as`, so native gates require `clang`; the wrapper
delegates non-Kof assembler invocations to the system assembler. Native SDL
presentation builds additionally require `pkg-config`, FreeType 2 and
HarfBuzz.

```bash
source scripts/kof_pin.sh
kof run src/main.kf --target native
```

This command is a console qualification path. It does not launch the
interactive packaged game. `kof run` itself does not require Python 3; Python
is currently used by repository lint, package/provenance validation, evidence
validation and rendezvous tooling.

## Browser game client (not WASM)

Kof 0.6.8 has `jvm`, `native`, and `js` targets; it has no WASM target. The
full `src` entrypoint depends on native SDL/GPU and filesystem APIs unavailable
to the JS target. `apps/web_alpha` therefore packages a standalone responsive
HTML/WebGL2 client, not a native-game or WASM build:

```bash
bash scripts/build_web_alpha.sh
```

The default output is the sibling LichForge static site at
`../../LICHFORGEWEB/assets/kookie-alpha`. Use `--output DIR` to stage it
elsewhere. Serve the files over HTTP/HTTPS and open the page. It contains one
play surface: the live 3D scene, compact HUD, a movement stick, drag-to-look,
and touch actions for jump, roll, dash, glide, fly, shoot, melee, special
projectile and throwable; keyboard and mouse remain available. Movement repeats
according to stick deflection and the movement-speed setting. Settings retain
movement speed and camera sensitivity alongside server and reconnect options.
Training mode is available with `?kookie_role=training&kookie_autoconnect=1`.
It admits up to four players into a local combat session with four server-owned
100-HP dummies; the WebGL client shows confirmed melee damage numbers. Dummies
respawn after 45 server ticks. WebGL and SDL use the imported nine-frame smoke
flipbook (horizontal atlas in WebGL, cooked 3x3 atlas in SDL) for grounded
movement and takeoff/landing cues. `scripts/verify_native_presentation_smoke.sh`
exercises all three triggers and confirms SDL stages the flipbook in its GPU pass.

`apps/web_server/main.kf` runs an authoritative fixed-tick WebSocket server
with eight-player/four-spectator admission. `scripts/verify_kof_web_server.sh`
qualifies admission, movement/action/combat/projectile/collision/disconnect
behavior, shared concurrent Kutter edits, and the network-visible double-jump
roll animation and roll-side bit. This is local qualification, not proof of
WAN/tailnet latency or every gameplay edge case.

The SDL gameplay client can join this same authoritative session. Configure
`KOOKIE_KUTTER_HOST` and `KOOKIE_KUTTER_PORT`, and set
`KOOKIE_KUTTER_PATH=/session/goose` or `/session/cat` to match the server's
game route. Hosted connections use verified `wss://` by default; plain `ws://`
is accepted only for loopback and requires `KOOKIE_KUTTER_SCHEME=ws`. Optional
`KOOKIE_KUTTER_TOKEN` supplies the server's bearer subprotocol token. The
default path `/kutter/session` remains the separate editor route. Native builds
need libcurl 7.86.0 or newer with WebSocket support; Linux presentation
packages rely on system libcurl and its transport libraries (including
`libnghttp2` when required by the host libcurl), while Windows packaging
requires `KOOKIE_WINDOWS_CURL_PREFIX`.
The native client sends authoritative inputs and renders shared snapshot state;
its compact throwable/effect markers are not the browser's 3D item renderer.

Run the canonical local full-scene qualification path through the native Kof
server. Build it once:

```bash
server_dir="$(mktemp -d -t kookie-web-server-XXXXXX)"
bash scripts/build_web_server.sh --output "$server_dir"
```

Measure loopback snapshot cadence and input-to-authoritative-ACK latency:

```bash
scripts/bench_web_multiplayer.py "$server_dir/kookie-web-server" 0 8
```

Port `0` selects a free local port. Results include eight connected players and
four spectators; they measure WebSocket/TCP on loopback and exclude browser
rendering, packet loss, and tailnet/WAN latency. Use a separate browser and
tailnet test for end-to-end latency.

The server's per-client snapshot trailer acknowledges input only after an
authoritative tick applies it. The browser retains a bounded 64-frame history,
uses recent authoritative displacement to predict local horizontal movement for
at most 50 ms while inputs remain unacknowledged, then returns to server state.
This does not replicate KOOKIE's collision or jump simulation on the client.
Remote actors use a jitter-adaptive 50–150 ms interpolation delay; the server
continues to own collision, combat, and action outcomes.
The browser contract checks a missing intermediate snapshot and confirms that
an unacknowledged horizontal input still produces bounded presentation movement.
It does not simulate network packet loss or prove convergence under WAN jitter.

## Live 4v4 battle console

Build the web server, then launch the interactive battle console:

```bash
server_dir="$(mktemp -d -t kookie-web-server-XXXXXX)"
bash scripts/build_web_server.sh --output "$server_dir"
scripts/b2teams4.py "$server_dir/kookie-web-server" 8080
```

In the browser, open **Settings → Open game console**, choose **Spectator**,
then connect to `ws://SERVER_HOST:8080`. Run `/b2teams4` to spawn the eight bots
on that same server and spectate their battle in the page; `/stop` disconnects
them. Browser bots load eligible pickup positions from the shipped runtime
powerup JSON when they have no active effect, then return to combat. They use
jump, roll, dash, glide/fly, melee, ranged fire, special attacks, and throwables
based on range and vertical separation. The battle ends when one team is
eliminated or after two minutes. The console requires an active spectator join;
it does not require a separate CLI process.
Browser and CLI battle bots spawn with 300 health (three times the former
100-health pool); the browser HUD displays the 300-point maximum.

The Web multiplayer HUD shows 300 maximum health, team-colored hearts (blue for
blue players; red for red), and one shared ammo card for bullets, watermelon
seeds, or Wizard Hat fireballs. HUD values use ThaleahFat; damage numbers have
a Settings toggle. Confirmed hits briefly flinch and flash remote players; hits
on the local player briefly flash the screen red with a direction indicator.
Dizzy players show orbiting cartoon stars.

The shared throwable pickup spawns at randomized safe arena locations and
randomly selects a crate, boulder, bomb, flour package, or watermelon. Press the
throw action near an item to pick it up, hold the same action to charge, then
release to throw; the HUD shows charge power and a parabolic landing preview.
Bombs explode and flour bursts on contact. Other throws impact their target;
watermelons bounce once and scatter four slices, each restoring a little health
and seed ammo. Non-explosive throws can briefly dizzy players. Ground smoke from
jumps, landings, and running is white.

Action buttons on touch layouts can be repositioned independently. Desktop
keyboard and mouse controls keep their existing axes.

The CLI mode is also available. At the `kookie>` prompt, `/b2teams4` spawns
four goose bots on red and four cat bots on blue, then streams authoritative
tick, alive count, and movement-snapshot counts for up to two minutes. CLI and
browser bots seek eligible powerups when they have no active effect, then use
jump, roll, dash, glide/fly, melee, ranged fire, special attacks, and throwables
based on target range and vertical separation. The CLI reads the authored
waypoints from `assets/prototype/runtime/power_ups/*.json`; the server remains
authoritative for pickups, damage, and collisions. Same-team targets are ignored
by direct targeting and projectile/throwable damage. A round returns to the
prompt when one team is eliminated or the timer expires. The CLI monitor accepts
browser spectators joining before or during a battle. Enter `/quit` or press
Ctrl+C to stop it.

Pass `--log PATH` when launching the CLI to write one `kookie-battle-v1` JSON
snapshot per newly observed server tick during each battle. Analyze the result:

```bash
scripts/b2teams4.py "$server_dir/kookie-web-server" 8080 --log battle.ndjson
scripts/analyze_battle_log.py battle.ndjson --format text
```

The parser estimates team strength from alive-player count plus remaining
health, then compares an early baseline with three contiguous late windows. A
snowball requires the same team's lead in every late window and a configured
minimum increase over its early lead (`--min-growth`, default `0.1`). The
result is a heuristic from periodic snapshots, not causal proof; bot-only
matches do not establish human-match balance.

The web server loads seven authoritative power-up definitions: Coffee Mug,
Jetpack, Megaphone, Scuba Kit, Wool Ball, multiplayer Coffee, and Wizard Hat.
Coffee Mug increases movement speed; the Wizard Hat grants five fireballs.
Watermelon seeds are another ammo type, acquired from watermelon slices. Pickup
effects and expiry are server-authoritative and tick-based. Scuba currently
reduces oxygen drain, but the web simulation does not apply oxygen-depletion
damage or replicate oxygen, so scuba has no visible HUD effect yet. Uncollected
power-up objects and exact active power-up names/timers are not replicated or
rendered.

Run the 12-second headless `/b2teams4` smoke check with

`scripts/b2teams4.py "$server_dir/kookie-web-server" 8080 --smoke`. It verifies
moving snapshots, actual damage, a power-up pickup, each bot's movement/action
inputs, and observed attack, airborne and roll animation states. Throwable
pickup and throw behavior is covered separately by
`scripts/verify_web_multiplayer.py`; bots may not reach the shared throwable
pickup before a short smoke round ends. Floor/arena projectile collision
prevents out-of-bounds snapshots; projectile and blast damage use Kof's
authoritative area-damage service after collision and team checks. Walk/run
transition coverage is deterministic in
`scripts/verify_kof_web_server.sh`. The bot routes (`/session/goose` and
`/session/cat`) remain benchmark-only spawn selectors; regular `/session` joins
keep default goose/free-for-all behavior.

Start the server in a separate terminal from its package directory; the
executable loads `lib/libkookie_web_server.so` relative to its current
directory:

```bash
cd "$server_dir"
KOOKIE_WEB_PORT=8766 KOOKIE_WEB_MAX_CONNECTIONS=0 ./kookie-web-server
```

Build and serve the browser package in another terminal:

```bash
browser_dir="$(mktemp -d -t kookie-web-alpha-XXXXXX)"
bash scripts/build_web_alpha.sh --output "$browser_dir"
python3 -m http.server 8080 --directory "$browser_dir"
```

Open
`http://127.0.0.1:8080/?kookie_ws=ws://127.0.0.1:8766/session`, click `CONNECT`,
then use `PING`, `PROTOCOL ECHO`, or an authoritative action (`WASD`/arrow
movement, `Q`/`E` look, `SPACE` jump, `F` fire, `M` melee, `X` special, `R`
reset). Click the canvas to capture pointer lock for mouse look. Admission
requests the full authoritative scene snapshot before enabling action controls.
The Kof server maintains bounded tick, 3D player position/camera, stamina, ammo,
combo, VFX, four actor states, one projectile and one pickup. The WebGL2 client
loads the staged goose, cat, ground and wall GLB assets, displays an accessible
HUD and top-down minimap, persists bounded settings, and reconnects up to five
times when enabled. WebGL2 is required for the browser's 3D scene; the client
fails closed when unavailable.

Click `CHECK GATEWAY` to query the configured `GET /healthz` route. It reports
transport, protocol, bearer-admission mode and active sessions. `GET /metrics`
exposes bounded counters for upgrades, rejections, frames, commands and health
requests. The Kof server is TCP-only and supports local `ws://` qualification;
it does not provide hosted identity, bearer admission or TLS termination.

For the same browser client and native backend over the Chopper tailnet,
install Kof 0.6.6, ensure `tailscale serve status` already routes `/` to
`http://<Chopper-tailnet-IPv4>:8504`, then run from this checkout:

```bash
scripts/run_tailnet_web_preview.sh
```

The script rebuilds the browser client, Zig Bugfeed sidecar and both native Kof
backends, prints the HTTPS URL, and remains running until interrupted; it stops
the services and gateway on exit. Open the printed URL from Chopper, DDJARIN, or
another device on the same tailnet. Caddy binds only Chopper's Tailscale IPv4
address; the game backend listens on `KOOKIE_WEB_PORT` (default `8766`) and
Kutter on `KOOKIE_KUTTER_PORT` (default `8768`), both loopback-only.
`/session`, `/healthz`, and `/metrics` route to gameplay; `/bugfeed*` routes to
its dedicated Zig process, so uploads up to the 8 MiB screenshot limit bypass
the gameplay adapter's 8 KiB HTTP request buffer. `/kutter/session` routes to
the separate Kof editor-service process on port `8768`. Browser and native
editors share one in-memory canonical document there and broadcast edits to
each other. Save/export produces the canonical `.kutter` file; server-side
persistence and automatic loading into gameplay are not implemented. The Kof
protocol has no authentication, so Tailscale ACLs are the access boundary.
Tailscale Serve terminates TLS; both Kof services remain TCP-only. The preview
requires Zig 0.17.0; Node.js is not a backend runtime dependency.

Run the Kof server end-to-end gate:

```bash
bash scripts/verify_kof_web_server.sh
```
The gate selects a free loopback port by default, so an already-running preview
server cannot satisfy the health check in place of the process under test.
Set `KOOKIE_WEB_TEST_PORT` only when a fixed port is required.


The dependency-free Python gateway remains a legacy compatibility fixture for
bearer-token and WSS qualification. It is not the Kof server path or a
production identity/session service.

For the legacy Python gateway, qualify token-gated admission with a bounded
bearer token:

```bash
python3 scripts/kookie_websocket_session.py --port 8765 \
  --auth-token qualification-token
```

For a local credential file, keep the token out of the process arguments:

```bash
printf '%s\n' qualification-token > gateway.token
chmod 600 gateway.token
python3 scripts/kookie_websocket_session.py --port 8765 \
  --auth-token-file gateway.token
```

The file must be a regular file with mode `0600` or stricter and one valid
token; the gateway rereads it for each WebSocket upgrade. `--auth-token` and
`--auth-token-file` are mutually exclusive.

Open
`http://127.0.0.1:8080/?kookie_ws=ws://127.0.0.1:8765/session&kookie_token=qualification-token`.
The browser negotiates `kookie.v1` plus `bearer.<token>`; the gateway selects
`kookie.v1`. A missing or incorrect token is rejected with HTTP `401` before
the WebSocket session is admitted. Without `--auth-token`, the local gateway
keeps protocol-only admission for transport qualification.

For WSS qualification, provide a certificate and key:

```bash
python3 scripts/kookie_websocket_session.py --port 8765 \
  --tls-certfile localhost.crt --tls-keyfile localhost.key \
  --auth-token qualification-token
```

Use `kookie_ws=wss://127.0.0.1:8765/session` in the browser and enter the token in the
session authentication field. The bearer token and gateway are qualification
controls only; hosted production still requires a real identity/session
service, observability, deployment TLS policy, and the authoritative server
service.

The non-browser protocol check is:

```bash
python3 scripts/verify_websocket_session.py
```

This path validates the binary frame limit, Kof handshake checksum, admission
response, heartbeat, game-plane echo, authoritative scene snapshots, configured
token rejection/admission and malformed-frame rejection without a third-party
Python dependency. It is not a replacement for `kof run src/main.kf --target
native`; hosted production still requires the identity/session and operations
services described below.

The published package includes a self-contained update launcher:

- Linux: `kookie-launcher`
- Windows: `kookie-launcher.exe` or `kookie-launcher.cmd`

The launcher requires neither Kof nor Python at runtime. On every normal start
it queries the GitHub releases API for `rufl/KOOKIE`, selects the newest
non-draft published release containing the current target's package, signed
manifest and manifest signature, and updates before launching the game. The
current package channel is `dogfood`; prereleases are intentionally included.
It never downloads an unsigned mutable `latest` URL.

The update path is:

1. Validate HTTPS URLs (plain HTTP is accepted only for localhost fixture
   tests).
2. Verify the Ed25519 manifest signature against the public key embedded in
   the launcher.
3. Stream the archive to a private state directory and verify its exact size
   and SHA-256 from the signed manifest.
4. Reject archive traversal, absolute paths and symlinks; extract to a new
   staging directory and run `kookie --package-smoke`.
5. Atomically activate the validated package and retain the previous marker.
On startup, a bundled `PROVENANCE.txt` version is a local floor: an older or
equal public release is not activated, so a dogfood package is not silently
downgraded while its newer release is not yet published.


State is stored in `$XDG_STATE_HOME/kookie` or
`$HOME/.local/state/kookie` on Linux, and `%LOCALAPPDATA%\KOOKIE\state` on
Windows. `--state-dir PATH` and `KOOKIE_STATE_DIR` override this location.

Useful commands:

```bash
./kookie-launcher              # update, then launch
./kookie-launcher --check      # update/check without launching
./kookie-launcher --offline    # use the active package without network access
./kookie-launcher --self-test  # validate the embedded launcher key/target
```

Run the focused local signed-update fixture with:

```bash
bash scripts/verify_launcher.sh
```

Windows has equivalent `.exe` arguments; `kookie-launcher.cmd` forwards them.
`--check` and `--no-launch` return an error instead of silently falling back
when an update fails. Normal starts fall back to the last active package, if
one exists. The package-local `kookie`/`kookie.exe` remains the direct game
wrapper; `kookie --package-smoke` is the graphics-free package qualification
path.

The launcher is intentionally a separate native binary rather than the ZTASH
GUI: it reuses ZTASH's bounded download/archive/rollback safety model without
making KOOKIE releases depend on ZLAY, ZFONT, GLFW or the full ZTASH build.
The launcher currently targets Linux and Windows x86_64.

The Windows presentation package requires an interactive desktop session for
the SDL video/GPU window. A service receiver without that session cannot pass a
full `launch` action; use the bounded `--package-smoke` probe for service
qualification. The launcher keeps the desktop launch path unchanged and
reports a nonzero dogfood game exit instead of treating a headless presentation
failure as a successful launch.


The JVM target is used for local differential qualification and for the
explicit Windows compatibility package:

```bash
kof run src/main.kf --target jvm
```

It is not a silent fallback for Linux or the native SDL presentation profile.
Only `--runtime jvm --target windows-x86_64` distributes a JVM.

Run the focused gameplay and replay probe with:

```bash
bash scripts/verify_interactions.sh
```

Run the focused goose-versus-bots/session/overlay probe with:

```bash
bash scripts/verify_goose_game.sh
```

Run the focused multiplayer lobby and scoreboard probe with:

```bash
bash scripts/verify_multiplayer_ui.sh
```

## Content kooker

The developer launcher admits only documented, bounded source subsets. It
rejects malformed, oversized or unsupported input without publishing a
successful product.

```bash
scripts/kooker.sh cook map level.map level.kmesh
scripts/kooker.sh cook dust3d model.ds3 model.glb model.kmesh
scripts/kooker.sh cook blockbench character.bbmodel character.kchar
scripts/kooker.sh cook png texture.png texture.rgba.png
scripts/kooker.sh cook wav effect.wav effect.pcm16.wav
scripts/kooker.sh cook svg icon.svg icon.svgc
scripts/kooker.sh cook svgz icon.svgz icon.svgc
scripts/kooker.sh package 4 level.kmesh data/level.kmesh level.kpkg
scripts/kooker.sh inspect-package level.kpkg
scripts/kooker.sh validate-package kutter.kpkg
```

Source formats are authoring inputs, not runtime package formats. Linux
archives include a native `kooker` for the `cook` commands above;
package assembly and inspection remain in the JVM developer launcher.

## Offline KofScript products and sandbox

The KofScript wrapper emits canonical behavior, animation and sandbox-bytecode
artifacts without duplicating their runtime schemas:

```bash
scripts/kookie_kofscript_builder.sh behavior build/enemy.kofart
scripts/kookie_kofscript_builder.sh animation build/player-animation.kofart
scripts/kookie_kofscript_builder.sh script build/bounty.kofart
```

Execute a sandbox artifact against an admitted domain event on either Kof
target:

```bash
scripts/kookie_kofscript_runtime.sh build/bounty.kofart 7 1 3 1 42 2 20
KOOKIE_KOFSCRIPT_RUNTIME_TARGET=native \
  scripts/kookie_kofscript_runtime.sh build/bounty.kofart 7 1 3 1 42 2 20
```

The VM has forward-only control flow, fixed stack/instruction/output budgets
and capability-masked outputs. It has no filesystem, network, native-handle or
raw-array opcode; artifact loading occurs outside the sandbox.

## Signed Linux package

The release builder requires a clean source tree, exact Kof source identity,
verified Kof distribution digest and an owner-private Ed25519 key:

```bash
KOOKIE_VERSION=0.1.0-dogfood.N \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target linux-x86_64
```

The private key must be a regular mode-`0600` file. The packager also needs
Zig to build the native update launcher. It emits a Linux-targeted archive,
detached archive and manifest signatures, `SHA256SUMS`, a public key and
provenance JSON. Provenance binds the clean source commit, pinned Kof source
commit, compiler JAR hash and distribution archive hash.
The archive path and digest are checked, and its `lib/kof.jar` must match the
installed compiler JAR before packaging; digest metadata alone is not trusted.
The CI package gates may set
`KOOKIE_PREBUILT_NATIVE_BUILD`/`KOOKIE_PREBUILT_NATIVE_MANIFEST` or
`KOOKIE_PREBUILT_JVM_BUILD`/`KOOKIE_PREBUILT_JVM_MANIFEST` after compiling
`src` once for that target. Each manifest must match the current source commit
and `src` tree hash, target, Kof version, Kof source commit and compiler JAR
SHA-256. A missing or mismatched manifest fails closed; local packaging
without these variables still performs its own build.
The CI toolchain also caches the immutable pinned Kof distribution and the
canonical JVM/native `src` builds by source/toolchain identity. Cache hits are
still checked with the archive checksum or build identity manifest; a miss
falls back to the normal build.


Every Linux archive also contains the native `kookie-launcher` update entrypoint:

- `kookie-launcher`, which discovers the newest signed target release before
  starting the package game;

- `kookie-server`, a graphics-independent bounded workload server;
- `kooker`, the native bounded source kooker;
- `kookie-simd-bench`, the scalar/SIMD parity and timing probe.

The server reports counts, work budgets, p50/p95/p99/max tick time, RSS range,
checksum and logical resource plateau. It is qualification tooling, not a
packaged production hosting service. The SIMD route decision is measurement
output for its exact reduction workload, not a general speedup claim.

## Prototype content package

The first content profile stages a bounded, signed asset catalog under
`content/prototype`. It includes the converted GLB library from the Rgsdev
modular pack (75 greybox pieces plus the existing character asset), the
Classic64 pack, the requested animated goose, authored VFX PNGs, bounded
runtime PNG derivatives, cooked RGBA8 PNG outputs, and retained source
notices. `greybox_modules.json` is the editor-facing catalog: it binds each
module to its runtime GLB, 1-grid placement/snap metadata, collision role and
free texture-override policy. The Kutter Level Editor adds Zylve-style
placement tools and validation, plus MudLump-style grid/cursor workflow and
bounded undo/redo, while persisting through the existing Kof studio wire
format. It is opt-in so existing runtime packages remain content-free:



```bash
KOOKIE_VERSION=0.1.0-dogfood.prototype \
KOOKIE_BUILD_ID=prototype-content \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target linux-x86_64 \
  --content prototype
```
Kutter has web and native clients backed by the same live server document; it
is not a separate dockable desktop application. The web editor uses a compact
creative-mode layout with a game viewport, build toolbar, and on-demand
Layers/Properties drawer. The native surface has a model-backed 2D top-down
overview, paginated clickable hierarchy and inspector panels, snapped viewport
placement, and duplicate/group/ungroup/delete/recolor controls. Four hierarchy
entries are visible per page; header arrows change pages and show the current
page/total, while viewport selection or placement switches to the selected
node's page. Click a hierarchy row to focus it; Up/Down then selects adjacent
nodes, and Enter/Escape exits hierarchy focus.
Viewport coordinates map to the displayed grid, and the Select tool picks the
nearest authored node only inside its scaled footprint; empty clicks preserve
the current selection. Other tools place at the cursor.
The ASSET control opens a paginated browser for the 75-entry greybox catalog.
Rows show entry index and module kind; pointer or keyboard navigation selects
an entry.
Selecting Prop then clicking Place creates an asset-linked
prop; with a Prop selected, Enter assigns the selected catalog token. Schema v3
persists that reference, migrates v1/v2 documents, and duplicate preserves it.
The MOVE / ROTATE control arms move mode; the next viewport click moves the
selected node to the snapped cursor position. Escape cancels armed move mode.
The 2D overview draws screen-space footprints from each node's transformed box
corners, so rotation and X/Z scale affect the colored marker shape. Y offsets
the marker and draws a bounded elevation stem. Markers clip to viewport bounds,
show the selected node's facing direction, and use muted/red/green fills for
the default/first/second color presets. These are projected box proxies, not
rendered catalog meshes.
Native presentation also stages the authored bounded 3D box proxies into the
regular GPU world pass, snaps its camera to the selected node, and supports
bounded wheel zoom. Editor camera state is separate from gameplay camera state.
UI panels overlay that world pass; the viewport is not a clipped render target.
Catalog thumbnails, names/search, actual GLB rendering, and arbitrary RGB
materials are not implemented.
Clicking HEIGHT decreases/increases selected node Y by one active grid step;
height, rotation and scale edits participate in undo/redo. Clicking ROT adjusts
angle; SCALE minus/plus decreases/increases the selected axis in 100-unit
steps, while clicking its label cycles X/Y/Z. C switches between two preset colors.
Keyboard controls also
rotate, scale, move, undo, and redo. The hierarchy/inspector dock can be widened
by dragging its left divider; panels cannot be rearranged, and the left tools
panel remains fixed.
The Windows x64 game package is a portable directory/archive with runtime
dependencies, not a single-file executable; packaging requires a verified Kof
distribution archive and matching SHA-256.

To run the native SDL presentation with the prototype goose and cat models,
build the presentation profile explicitly:

```bash
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime presentation --target linux-x86_64 \
  --content prototype
```

`G1NativePresentation` resolves `goose.glb` and `cat.glb` through the native
bounded model loader and submits their triangles to the SDL_GPU world pass.
The content-free `none` profile keeps the bounded procedural silhouette
fallback; it does not redistribute the prototype models.

The presentation probe treats the content profile as a runtime contract:
`content=prototype` requires both native GLB models and their declared bounded
vertex counts; it fails closed if either model is unavailable or invalid.
`content=none` is the only profile that permits the procedural silhouette
fallback. Package provenance records this as
`prototype_models_policy=strict-native-required` or `fallback-allowed`.


`assets/prototype/manifest.json` binds the selected source paths, archive
SHA-256 values, converted output paths, frame grids, and license notices.
Package `PROVENANCE.txt` and the signed JSON manifest record the deterministic
prototype-content tree digest and file/asset counts.

The modular, Brackeys VFX and Classic64 notices identify CC0 sources. The
goose page is not CC0: it permits commercial use and editing but prohibits
reselling or redistributing the model file. It remains prototype-only by
explicit request; do not redistribute that asset as CC0.

The prototype catalog also contains the attributed Prildarill low-poly cat
source and GLB. Its source page permits use and editing and says credit is not
required; KOOKIE retains attribution voluntarily. No SPDX license or
standalone raw-file redistribution grant is stated, so the cat source and GLB
remain prototype-only and must not be advertised as CC0 or an independent
asset pack.
The native gameplay presentation uses these prototype GLBs when that profile is
present. Their bounded vertex counts, materials, positions, facing and authored
animation clips pass through the checked Kof model API; roll uses the authored
run pose with a bounded procedural quarter-turn over twelve ticks because the
source GLBs contain no roll clip. Native roll is driven from the local/remote
roll input bit. No unbounded mesh data enters frame staging.

The catalog also stages Echo Studios' five-state player-heart sheet at
`ui.player-hearts`. Its authored copy preserves the supplied 320x64 PNG; the
bounded runtime derivative is cooked from a 160x32 nearest-neighbor copy, and
the native presentation samples those five states into the 2D billboard atlas.
The source page is a name-your-own-price download but does not state a
standard license or standalone redistribution terms. Keep the heart asset
prototype-only; see `licenses/echo-studios-heart-terms.txt`.
The native gameplay presentation also stages the bounded Zylve-style tactical
map as a round upper-right overlay. `G1NativePresentation.setCooperativeMode`
is the mode seam: cooperative matches show local and remote player markers;
PvP suppresses both player markers while retaining the map and non-player
markers.

## SDL3/SDL_mixer development dependencies

The Linux gates accept SDL 3.4.18 and SDL_mixer 3.2.4 through `pkg-config`.
The shared resolver also accepts `KOOKIE_SDL3_PREFIX` and
`KOOKIE_SDL3_MIXER_PREFIX`, validates the exact header/package versions and
adds the selected library directory to the local smoke path. It does not
silently accept an older mixer or an unreviewed runtime library.

When the host has SDL3 but no SDL_mixer development package, prepare the
pinned local prefix:

```bash
bash scripts/bootstrap_sdl3_mixer.sh
```

The bootstrap also requires CMake, a C compiler and `curl` or `wget`; the host
SDL3 development files remain required.

The bootstrap verifies the official SDL_mixer 3.2.4 archive SHA-256, builds
the WAVE and bundled `stb_vorbis` backends, and installs into the ignored
`.kookie-deps/sdl3-mixer-3.2.4` prefix. For an offline reviewed source tree:

```bash
KOOKIE_SDL3_MIXER_SOURCE=/path/to/SDL_mixer-3.2.4 \
  bash scripts/bootstrap_sdl3_mixer.sh
```

### OGG Vorbis music and SFX

The developer cooker admits bounded OGG Vorbis and preserves the validated
pages byte-for-byte:

```bash
scripts/kooker.sh cook ogg input.ogg cooked.ogg
```

The cooker validates the single logical Vorbis stream, page CRCs and sequence
state, Vorbis headers, decoded-frame bounds and optional `LOOPSTART`,
`LOOPEND`/`LOOPLENGTH` sample-frame comments. Runtime SDL_mixer predecodes the
canonical payload with the pinned `stb_vorbis` backend; loop start/end/count
are sample-frame properties, not wall-clock approximations.

To enable an OGG soundtrack in the native adapter, set the path before launch:

```bash
KOOKIE_AUDIO_MUSIC_OGG=/absolute/path/theme.ogg ./kookie
```

The UI catalog is user-supplied JDSherbert material and currently has no
license/redistribution terms in the repository; its 14 files are therefore a
release publication blocker, not a cleared third-party dependency. SHA-256
metadata in the UI cue manifest does not resolve that legal gate. Use the
focused semantic checks while developing:

```bash
bash scripts/verify_ui_library.sh
bash scripts/verify_ui_demo.sh
```

Do not publish a package containing `assets/audio/ui/*.ogg` until the pack's
license and redistribution permission are recorded in
`THIRD_PARTY_NOTICES.txt`.

The existing `assets/audio/ui/*.ogg` catalog is loaded as predecoded SFX tracks
and exposes exact loop bounds through the native UI-clip API. For presentation
or native Windows packages, `package_kookie.sh` also copies `.ogg` files found
under optional `assets/audio/music/` and `assets/audio/sfx/` directories;
runtime code only auto-starts the explicitly configured soundtrack path.

Without `KOOKIE_AUDIO_MUSIC_OGG`, the previous generated PCM music/effects
streams remain unchanged.

After preparation, `package_kookie.sh`, `verify.sh`, the external-LAN native
gates and the G5 renderer gate discover the prefix automatically. The
presentation package still bundles only the resolved SDL3/SDL_mixer runtime
libraries; host libc and the dynamic loader remain outside the archive.
The presentation archive also contains
`build/libkookie_persistence_adapter.so`; the Kof save owner uses that single
stateful bridge for staging, publication and confirmation, while SDL rendering
remains in `build/libkookie_sdl_adapter.so`.

## Linux SDL presentation package

Build the persistent SDL3/SDL_GPU presentation used for isolated visual
qualification and signed dogfood releases:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.N \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime presentation --target linux-x86_64
```

For a clean-tree package extraction and signature smoke, use:

```bash
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/verify_linux_presentation_package.sh
```

For a release artifact, build two byte-identical packages and write the
verified artifact set to an empty output directory:

```bash
KOOKIE_VERSION=0.1.0-demo.N \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/build_demo_release.sh \
  --target linux-x86_64 \
  --version 0.1.0-demo.N \
  --output /tmp/kookie-demo-linux
```

The builder requires a clean tree and does not claim native GPU evidence.
The 2026-10-02 qualification batch passed
`verify_linux_presentation_package.sh` with a temporary pinned SDL_mixer 3.2.4
prefix. It verified the signed archive, safe extraction and package smoke on
the current checkout; it did not prove a present-capable Linux GPU or the final
clean-tree paired release.


This profile requires SDL 3.4.18, SDL_mixer 3.2.4, `glslc`, `spirv-val`, a C
compiler and `pkg-config`. The archive contains the Kof menu/game application,
SDL adapter, validated SPIR-V shaders, the shader manifest/reflection header,
SDL3 and SDL_mixer. It uses the host dynamic loader and libc.
Presentation archives also include `DEMO_CONTROLS.txt`. The default
presentation command uses the `none` content profile and does not redistribute
prototype assets; pass `--content prototype` to package the goose/cat model
demo explicitly.

### Controls

- Main menu: arrow keys or WASD.
- Select: Enter, Space or mouse click.
- Back: Escape.
- `Play`: local authoritative listen-server/client encounter; re-enter `Play`
  after Escape to reset the bounded encounter.
- Gameplay: `W`/`S` move forward/backward and `A`/`D` strafe relative to
  horizontal mouse look; the vertical mouse look pitches the third-person
  follow camera, the mouse wheel zooms it, and authored collision stops the
  spring arm at walls and ramps. Segment/triangle checks are continuous in
  bounded fixed-point space, then resolve to the previous safe sample.
- Fire: `F` or left mouse button. Jump: `Space` or `Ctrl`.
- Options: 1280×720 through 2560×1440, windowed/borderless/exclusive
  fullscreen, separate effects/music volume and three text sizes.
- Accessibility: HUD scale (`SMALL` 85%, `MEDIUM` 100%, `LARGE` 115%),
  tactical-map visibility and high-contrast text. Changes apply live in the
  presentation shell and retain fixed staging budgets.
- Multiplayer: Host, Join and Leave with editable IPv4 and port fields.
  After the peer connects, select `READY` on both clients before gameplay opens;
  the lobby shows the bounded peer identity, player count and honest ping
  placeholder until an RTT exists.
- During gameplay, `Tab` toggles the player screen; it shows player, status,
  score, HP, K/D and ping. `--` means RTT is not available yet.

Display changes commit only on Apply. Lobby packets use SipHash tags and replay
sequences. A configured 128-bit shared key authenticates peers; the local
fallback only detects accidental corruption. The lobby provides neither
encryption nor public identity.
### GUI qualification

The shell polish and accessibility settings are covered by bounded model/staging
probes:

```bash
bash scripts/verify_font_ui.sh
bash scripts/verify_multiplayer_ui.sh
bash scripts/verify_goose_game.sh
```

The multiplayer probe stages the main, options, accessibility, multiplayer and
Kutter shell frames on JVM and native paths. Graphical validation MUST use
`overzeer-isolated-display`; plain Xvfb or the active desktop is not evidence.

The current workstation's 2026-10-02 isolated attempt was fail-closed by full
(`62.54%` blocked), and the full orchestrator separately exceeded the
pressure-sensitive simulation p95 budget (`4153us > 4000us`). The local
`0.1.0-gui.1` package passed signed extraction and package smoke, but native
GPU presentation evidence remains open.

An earlier focused qualification record passed 512 measured ticks at p95
`3624us`, p99 `3689us` and maximum `3899us` under the declared `4000us`
simulation budget. The latest result below supersedes it for the current source;
the prior full-orchestration overrun remains recorded as pressure-sensitive.

The latest focused native run after the authoritative-path optimization uses
the package qualification window: 128 warm-up ticks and 512 measured ticks.
It recorded p50/p95/p99/max `3805/3925/3958/4936us`, workload checksum
`217802`, resource signature `520690`, and 64 KiB RSS growth/range under the
unchanged `4000us` p95 budget. `scripts/verify_package.sh` uses this same
window rather than a shorter cold-start sample.
The scalar enemy path, target-position cache and batched loot/reference-scene
checksum updates preserve the `217802` JVM/native workload checksum.

The current source commit also has a local native-only qualification package
`0.1.0-perf.2`, with archive SHA-256
`3d40aa2c012e610c460379c5ca0c62ecf0cc30b6bba57165bfe45c2dee8c8014`.
Its extracted package smoke and packaged dedicated-server p95 gate passed; it
is not a public release or a presentation artifact.

### Simple WAN goose session

Run the small authenticated rendezvous on a reachable Linux host:

```bash
KOOKIE_TRANSPORT_KEY_HEX=00112233445566778899aabbccddeeff \
python3 scripts/kookie_rendezvous.py --bind 0.0.0.0 --port 47101
```

The rendezvous refuses a missing, malformed or all-zero shared key, and never
evicts an existing two-player room when a third client presents the same code.

Start the Linux or Windows `presentation` client with the same key and:

```bash
export KOOKIE_WAN_RENDEZVOUS=1
export KOOKIE_RENDEZVOUS_HOST_IPV4=203.0.113.20
export KOOKIE_ROOM_CODE=4107
export KOOKIE_PLAYER_NAME_ID=1
export KOOKIE_TRANSPORT_KEY_HEX=00112233445566778899aabbccddeeff
./kookie
```

Use `Multiplayer > Host` on one client and `Multiplayer > Join` on the other.
After both clients show the peer as connected, select `READY` on both clients
to open gameplay. `Tab` opens the deterministic player screen; Escape returns
to the menu, and selecting `Play` starts a fresh local encounter.

The rendezvous authenticates the fixed UDP envelope, records each public UDP
endpoint, sends the peer endpoint, and stops relaying. Both clients then send
direct authenticated datagrams repeatedly for simple UDP hole punching. This is
best-effort: symmetric NAT, blocked UDP, or some CGNAT topologies require a
forwarded game port or a direct LAN address. It provides no relay, encryption,
identity service, or production DDoS protection. Leave
`KOOKIE_WAN_RENDEZVOUS` unset for direct LAN mode.

The gameplay path uses typed authoritative snapshots and fixed-tick input
bundles. Each bundle repeats up to three ordered inputs and carries the last
snapshot ACK; the host returns an input ACK. Newer ticks supersede older
snapshots, while a higher state sequence may replace the latest sample at the
same tick for lifecycle or stale-command diagnostics. This is the bounded
reliability layer used over the authenticated UDP envelope. It is not a
QUIC-compatible wire protocol.

The host retains a 12-tick bounded position history for hitscan lag
compensation. It derives a rewind tick from the acknowledged snapshot lag and
uses the historical source/target distance; clients render remote player
positions six ticks behind the live tick. These limits are deterministic and
do not provide sub-tick QUIC semantics.

Restoring an earlier replay checkpoint clears rewind samples from the discarded
future before fixed-tick advancement resumes.

The Linux package also contains `kookie-rendezvous.py`. The rendezvous can run
on Linux while both game clients run Linux or Windows.

### Run the currently published Linux dogfood

The latest published dogfood record is
[`0.1.0-dogfood.63`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.63).
It is a signed Linux/Windows x86-64 pre-release built from source commit
`3bd382a072817fe545ae9a80abfd1dd344878ada`. For a new candidate, use its
signed `RELEASE_QUALIFICATION.json` as the release identity. To verify the
published Linux package, download the release assets and run:

```bash
sha256sum --check SHA256SUMS
openssl pkeyutl -verify -rawin -pubin \
  -inkey kookie-0.1.0-dogfood.63-linux-x86_64.pub.pem \
  -in SHA256SUMS -sigfile SHA256SUMS.sig
openssl pkeyutl -verify -rawin -pubin \
  -inkey kookie-0.1.0-dogfood.63-linux-x86_64.pub.pem \
  -in kookie-0.1.0-dogfood.63-linux-x86_64.tar.gz \
  -sigfile kookie-0.1.0-dogfood.63-linux-x86_64.tar.gz.sig
tar -xzf kookie-0.1.0-dogfood.63-linux-x86_64.tar.gz
cd kookie-0.1.0-dogfood.63-linux-x86_64
./kookie
```

The archive bundles SDL3, SDL_mixer and the native adapters, but uses the host
dynamic loader/libc and requires a supported presentation-capable Linux GPU.
The package proves artifact integrity and package behavior; target-hardware
presentation evidence is authoritative only when the signed
`RELEASE_QUALIFICATION.json` retains it.


## Windows x86-64 packages

### Reachable Kof PE/COFF compiler


The pinned compiler bridge lowers the reachable optimized Kof IR graph to
deterministic C11, then uses Zig 0.17.0 to emit an AMD64 COFF object and
Windows PE:

```bash
scripts/kof_pe_build.sh path/to/main.kf --output build/kof-pe
scripts/verify_kof_pe_backend.sh
```

The standalone output is `kof-module.c`, `kof-module.obj` and
`kof-module.exe`. Add `--library` to emit the C/object module with the
exported `kookie_kof_gameplay_main` entry for a native host. The retained gate
builds twice, checks byte-for-byte reproducibility and PE/COFF headers,
compares generated-code output with the Kof JVM oracle, and proves unsupported
floating-point IR rejects with `PE001`.

The reachable target covers the current KOOKIE gameplay/presentation graph:
classes and fields, object and array allocation, integral/Boolean/String values,
locals, arithmetic, branches, loops, `print`/`println`, String `length` and
`charAt`, and integral FFI calls. It remains fail-closed for unsupported
floating-point IR, caught exceptions/concurrency, and non-integral FFI.
Generated allocations are process-lifetime; this target is for the bounded
gameplay workload, not an unbounded service.

The presentation probe uses `BoundedHostSessionSaveCoordinator` for the PE
reachable path. Kof encodes and validates the bounded wire; checked integral
FFI calls let the native persistence adapter stage/read schema bytes and run
the durable publish boundary without `File` or `String` FFI. The G7 native
probe and the G0 Play smoke verify fresh-session inventory restoration.

The no-SDL PE persistence qualification is:

```bash
bash scripts/verify_pe_durable_save.sh
```

### Native Kof SDL runtime

Build the native Kof SDL runtime from the official MinGW development packages
for SDL 3.4.18, SDL_mixer 3.2.4, FreeType and HarfBuzz:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/path/to/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/path/to/SDL3_mixer/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_FREETYPE_PREFIX=/path/to/freetype/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_HARFBUZZ_PREFIX=/path/to/harfbuzz/x86_64-w64-mingw32 \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target windows-x86_64
```

The package links the complete reachable `src/` Kof gameplay and presentation
object into `kookie.exe`, alongside the native SDL3/SDL_mixer adapter. Kof owns
the menu, lobby and gameplay policy. It contains `kookie.exe`, `SDL3.dll`,
`SDL3_mixer.dll`, licenses and provenance; it contains no JDK. The package
smoke prints
`KOOKIE native Kof PE gameplay verified` after SDL initialization.

With `KOOKIE_RUN_WINE=1`, the isolated presentation smoke also requires the
`KOOKIE G7 native presentation durable save verified` marker. This exercises
the PE-safe scalar save bridge through the packaged Play path; the G0 owner
publishes on gameplay exit/window close and restores on process start/re-entry.
It does not replace native Windows hardware/GPU evidence.
Use `--runtime presentation` for the shared Kof SDL loop: it renders the
three-bot encounter, maps input, and supports the same direct/WAN transport as
Linux. A fresh Windows package still needs native hardware presentation smoke
before public release.

### Bundled Kof JVM runtime

The compatibility profile packages the Kof JVM artifact with one exact Windows
x64 OpenJDK runtime:

```bash
KOOKIE_WINDOWS_JAVA_ARCHIVE=/path/to/OpenJDK27U-jre_x64_windows_hotspot_27_35.zip \
KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256=e9cf542d5ffe2a894637b18c27a7802853976deaa3abe3e04dfbb8a307a145dd \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
SOURCE_DATE_EPOCH=<unix-timestamp> \
scripts/package_kookie.sh --runtime jvm --target windows-x86_64
```

The builder verifies the archive digest, safe ZIP paths, Windows x86-64 release
metadata, PE `java.exe` and retained runtime legal files. It builds and smokes
the canonical `kookie.jar`, then writes a timestamp-normalized,
deterministically ordered signed ZIP. This remains a compatibility profile;
the native PE/SDL profiles do not depend on it.

### Native PE/SDL_GPU presentation package

The presentation profile lowers the native SDL presentation probe and its
reachable gameplay graph to PE, statically links the SDL3/SDL_mixer adapter,
and bundles both SPIR-V and DXIL shader products:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/path/to/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/path/to/SDL3_mixer/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_FREETYPE_PREFIX=/path/to/freetype/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_HARFBUZZ_PREFIX=/path/to/harfbuzz/x86_64-w64-mingw32 \
KOOKIE_DXC=/path/to/dxc \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
SOURCE_DATE_EPOCH=<unix-timestamp> \
scripts/package_kookie.sh --runtime presentation --target windows-x86_64
```

`glslc` and `spirv-val` must be on `PATH`. `scripts/verify_windows_presentation.sh`
rebuilds the signed package twice, compares every archive/signature, validates
safe ZIP paths and retained licenses, and checks the native PE, SDL import
libraries and SPIR-V/DXIL entries plus the reflected shader manifest.
smoke; it requires `wine` and `overzeer-isolated-display`.

For target-hardware evidence, set `KOOKIE_RUN_NATIVE_PRESENTATION=1` and
provide `KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER`. The reviewed wrapper
must provide a private Windows display/session, bounded timeout and complete
process-tree cleanup; the script launches the extracted `kookie.exe`, validates
the D1 markers and P6 screenshot, and retains `native-evidence.json`.
For the publishable Windows artifact, use the clean-tree deterministic builder:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/path/to/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/path/to/SDL3_mixer-3.2.4/x86_64-w64-mingw32 \
KOOKIE_DXC=/path/to/dxc \
KOOKIE_KOF_SOURCE_COMMIT=7c237861a9035d84b1f7ec4cfddd89daef4c6ddd \
KOOKIE_KOF_ARCHIVE_SHA256=<verified-distribution-sha256> \
KOOKIE_KOF_ARCHIVE=/secure/path/kof-0.6.6-linux-x86_64.tar.gz \
KOOKIE_SIGNING_KEY=/secure/path/kookie-ed25519.pem \
scripts/build_demo_release.sh \
  --target windows-x86_64 \
  --version 0.1.0-demo.N \
  --output /tmp/kookie-demo-windows
```

The historical `.38` qualification batch passed
`verify_windows_presentation.sh` with pinned MinGW SDL3/SDL_mixer prefixes and
DXC. This proves the reproducible signed PE/SDL/SPIR-V/DXIL artifact path only;
native Windows input/audio/GPU/driver evidence and outside-checkout interactive
smoke remain release gates for each candidate.

It writes the signed archive, package manifest, public key, detached signatures,
`SHA256SUMS`, `BUILD_SUMMARY.txt` and `QUALIFICATION_MANIFEST.json`. Native
Windows launch/input/audio/GPU evidence remains authoritative only when the
paired `RELEASE_QUALIFICATION.json` retains the target evidence.

On a supported Windows GPU with the reviewed native isolation wrapper, the full
smoke executes the same native Kof PE entry that owns the SDL window, GPU scene
staging, audio queue, kutter reload and gameplay markers. The package has no
JVM dependency. This remains target-specific evidence; it does not generalize
to other OS/GPU combinations or WAN/security qualification.

### Paired demo release workflow
For exact workstation paths, readiness checks, secret setup and dispatch commands, see [RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md).

`.github/workflows/release_demo.yml` is a manually dispatched, manually
approved workflow. It builds Linux and Windows packages independently, then
publishes them as one pre-release only after the `kookie-demo-release`
environment approves the publish job.

The workflow requires self-hosted runners with labels
`kookie-demo-release`, `linux`/`windows` and `x64`. The hosted `toolchain` job
builds Kof `0.6.6` from the pinned source commit, uploads the archive with
`SHA256SUMS` and `SOURCE_COMMIT`, and each self-hosted target job verifies and
uses that exact artifact. The runners do not need a preinstalled Kof archive,
Zig or a static Kof digest secret.

The Linux runner additionally needs pinned SDL3 development files,
`overzeer-isolated-display`, `gamescope`, a usable render node and its paired
primary DRM card. The tracked
`scripts/linux_gamescope_isolated_display` wrapper provides the private
headless Wayland/Xwayland compositor; the release smoke uses SDL's X11 backend
through Gamescope's Xwayland server inside it. The workflow bootstraps the
pinned SDL_mixer prefix when its `pkg-config` entry is absent. The Windows
SDL3/SDL_mixer prefixes, `KOOKIE_DXC`, Git Bash, Windows PowerShell 5 and
`pkg-config` are required; the configured FreeType/HarfBuzz prefixes must also
contain `freetype2.pc`, `harfbuzz.pc`, their MinGW import libraries, headers and
all text-runtime DLLs. The tracked Windows wrapper owns the private desktop,
timeout and process-tree cleanup. Native Windows smoke records the PCI adapter
PNP identity and driver version.

The hosted `verify.yml` workflow builds the pinned Kof archive once per run,
then runs static/JVM, native/package and Windows JVM jobs in parallel. The
static job has a 20-minute budget, the Windows JVM job 30 minutes and the
native/package job 90 minutes because Kof native code generation is materially
slower. Zig and Windows JRE archives are cached by SHA-256 and revalidated on
every use; the runner preflight records hardware and free-disk capacity.

Configure the `KOOKIE_SIGNING_KEY_PEM` repository secret. The Kof digest is
generated and verified from the per-run toolchain artifact; it is not a static
repository secret. Dispatch with `publish=false` for artifact-only
qualification. Set `publish=true` only after native Linux and Windows
launch/input/audio/GPU evidence has been retained with the release record.

### G6 bounded runtime probes

Run the non-graphical expansion qualification as one focused command:

```bash
bash scripts/verify_g6_runtime.sh
```

It compiles and executes safe worker publication, packaged KofScript/session
activation, persistent Kutter reopen/rollback and the fixed-window WAN channel.
The WAN result is limited to direct IPv4/UDP endpoints with a pre-shared key,
bounded retransmission and backpressure; it does not claim NAT traversal,
relay service, confidentiality or DDoS resistance.

## External-LAN qualification roles

Build the Windows JVM role bundle separately:

```bash
scripts/package_external_lan_roles.sh \
  --version 0.1.0-external-lan.1 \
  --build-id "${KOOKIE_BUILD_ID:-local}" \
  --output release/external-lan
```

The archive contains host/client JARs and Windows `.cmd` launchers, but no
transport key or run manifest. It is cross-host qualification tooling, not a
KOOKIE product package. Operational evidence stays outside this repository.
Revalidate a locally produced evidence bundle with:

```bash
python3 scripts/verify_external_lan_evidence_bundle.py \
  /path/to/external-lan-evidence.tar.gz
```

Run the same-host multi-process regression with:

```bash
KOOKIE_EXTERNAL_LAN_TARGET=jvm \
KOOKIE_EXTERNAL_LAN_MODE=processes \
bash scripts/verify_external_lan.sh
```

Use `KOOKIE_EXTERNAL_LAN_TARGET=native` for the native path. Same-host evidence
remains `externalHostExecution=unproven`.
The G3 acceptance path in this regression includes server-owned
kill→drop→pickup→equip, recipient kinds `7`/`8`, and a host schema-file
save/reload of currency, rolled item, equipment, skill and claimed reward.
The validator records that round trip in `g3SaveReload`; this does not promote
same-host evidence to a separate-physical-host claim.

### Editing G3 configuration

The authored G3 inputs live in `config/g3/demo.json` and
`config/g3/external_lan.json`. Edit these files directly for extension
metadata, enemy balance, weapons, encounters, loot/affix tables, skills,
statuses and bounded session capacities. The runtime loads the selected JSON
at startup; malformed, incomplete, duplicated or out-of-range fields fail
closed. `enemyKind` is the only string-valued field (`normal`, `elite` or
`boss`); all other authored values are bounded integers. The loaded checksum
participates in the compatibility identity, so all peers must use matching
content. Packaged builds preserve the same relative `config/g3` paths for
user/modder edits.


## Repository verification gate

The complete gate is final pre-commit verification. In Pi sessions it requires
the user's one-shot `/precommit-matrix` permission:

```bash
bash scripts/verify.sh
```

During implementation, run only the smallest focused check that proves the
changed behavior.

The hosted GitHub Actions gate also runs `scripts/verify_kof_pe_backend.sh`.
Its PE checks parse the COFF/PE headers directly; they do not depend on the
platform-specific wording emitted by `file` for an AMD64 COFF object.

## Graphical qualification isolation

Never run KOOKIE graphical checks against the active desktop or physical
monitors. Use the tracked `scripts/linux_gamescope_isolated_display` wrapper by
default, or set `KOOKIE_PRESENTATION_ISOLATION_WRAPPER` to a reviewed override;
either must provide private display/session sockets, a bounded timeout and
complete process-tree cleanup.
The tracked wrapper sets `OVERZEER_DISPLAY_PRESSURE_GATE=0` by default for
KOOKIE; set it to `1` to restore pressure deferral. Private display/session
isolation, render-node restrictions, bounded timeout and process cleanup remain
mandatory.

Offscreen SDL checks prove lifecycle and GPU-resource behavior, not real window
presentation. Use `KOOKIE_SDL_VIDEO_DRIVER=x11` only with an isolated
present-capable environment. Set
`KOOKIE_SCREENSHOT_PATH=/absolute/path.ppm` to retain a qualified frame.
