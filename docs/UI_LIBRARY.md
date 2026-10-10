# KOOKIE UI library

`src/ui/kookie_ui.kf` is the first internal presentation slice for Kof and
KofJS. It is a small facade over `kof.ui`, not a replacement for the Kof
stdlib. The design borrows the useful boundaries from ZLAY, ZFONT, ZPIX, ZDOM
and ZWEB while keeping ownership in KOOKIE source.

The GUI contract has two source layers. `src/ui/kookie_ui.kf` owns the
handle-backed Kof/KofJS facade and rendering composition. `src/ui/kookie_ui.ks`
is the KofScript sandbox companion: it emits a bounded semantic
`KookieUiScriptDocument` descriptor with text, asset and icon nodes, publication
checksum/path/alternative-text validation, and deterministic lifecycle state.
Current KofScript runtimes do not expose `Window`, `Label`, `Image` or `Icon`
handles, so the script layer intentionally does not render or retain native
handles; a Kof/KofJS host consumes its descriptor.

Both layers expose `bindMenu` and `bindHud`: Kof/KofJS builds composed
`View`/`Column`/`Row` surfaces, while KofScript emits the corresponding
ordered text nodes for a host adapter.

## Contract

| Concern | KOOKIE surface | Owner |
| --- | --- | --- |
| Layout and surfaces | `kookieUi*Style`, `View`, `Column`, `Row` | Kof/KofJS DOM |
| Font roles | `kookieUiFontBody`, `kookieUiFontDisplay`, `KookieUiText` | Kof style + host CSS |
| SVG/PNG assets | `KookieUiAsset` | `Image` in KofJS; host/native adapter outside this slice |
| Built-in vector icons | `KookieUiIcon` | Kof intrinsic SVG icon registry |
| Accessibility text | non-empty `alt` constructor argument, `bindAssetDescription`, `bindIconDescription` | Kof label tree |
| Window composition | `KookieUiDocument` | Kof `Window` |
| Reusable menu/HUD views | `bindMenu`, `bindHud` | shared Kof/KofJS composition |
| Retained components | `KookieUiLayoutSpec`, `KookieUiPanel`, common controls and editor surfaces | shared Kof/KofJS composition |
| KofScript sandbox descriptor | `KookieUiScriptDocument` | bounded semantic descriptor consumed by a Kof/KofJS host |
| UI sound cues | `KookieUiSoundCue`, `KookieUiSoundBank` | bounded queue adapter over native audio |

The facade owns metadata, bounds and composition. It does not decode image
bytes, rasterize fonts, mutate gameplay state or retain native pointers.

## Example

```kof
import ui

main() {
    var document = KookieUiDocument("GatoGanso", 960, 540)
    var title = KookieUiText(
        "GATOGANSO", kookieUiTextRoleDisplay(), 32, true,
        kookieUiForeground())
    var logo = kookieUiPublishedUiGatogansoMark()
    var hearts = kookieUiPublishedUiPlayerHearts()

    document.bindText(title)
    document.bindAsset(logo, 32)
    document.bindAssetDescription(logo)
    document.bindAsset(hearts, 48)
    document.bindAssetDescription(hearts)
    document.show()
}
```

The published constructors in `src/ui/published_assets.kf` are generated from
`assets/ui/manifest.json`; callers should use them instead of copying IDs,
paths or digests into application code. The source is checked with:

```bash
python3 scripts/generate_ui_manifest_kf.py --check \
  assets/ui/manifest.json src/ui/published_assets.kf
```

`KookieUiAsset.accepted()` validates the asset reference shape: a non-empty ID,
safe package-relative runtime path, alternative text, kind/extension and a
lowercase 64-character SHA-256 string. It does not read bytes, consult the
manifest or verify file integrity.

`assets/ui/manifest.json` is the publication contract. The package and demo
verification gates resolve IDs through `runtime_path` entries and verify the
declared digest before serving or admitting content. A caller constructing
`KookieUiAsset` directly must still use a record from that verified publication
flow; `accepted()` alone is not proof that an ID is published or that bytes
match the declared digest. Prototype entries may be absent from a `none`
package, but they must be present and hash-verified in the `prototype` package.
The manifest separately declares that the isolated UI demo requires its
prototype entry; the demo gate therefore fails if the PNG is not staged.
The shared `scripts/verify_ui_manifest.py` gate validates the same manifest
against the staged runtime tree for the `none`, `prototype` and demo profiles.
The `none` profile may omit only the prototype heart PNG; the other profiles
must contain every declared runtime asset and match every digest.
`publication.optional_asset_ids` is the authoritative list for that exception.

The source tree can stage the manifest's authored assets at their runtime paths:

```bash
python3 scripts/stage_ui_manifest.py \
  assets/ui/manifest.json . build --profile prototype
```

Source assets must still pass the content pipeline before native publication:

```bash
scripts/kooker.sh cook png input.png output.rgba.png
scripts/kooker.sh cook svg input.svg output.svgc
scripts/kooker.sh cook svgz input.svgz output.svgzc
```

## Fonts and rendering

The shipped roles are:

- body: `Jared Lite`, `fonts/jared-lite.ttf`;
- display: `Pixand`, `fonts/pixand.ttf`.

Load `assets/ui/kookie-ui.css` in the KofJS host before the generated module.
Its relative font URLs work with the source tree (`assets/fonts`) and with a
package host that keeps the CSS under `assets/ui` and the bundled fonts under
`fonts`:

```html
<link rel="stylesheet" href="assets/ui/kookie-ui.css">
```

`KookieUiText` applies the family, line-height, size, weight and color to the
same Label handle. The current Kof 0.5.0-beta `Font` handle records metadata
but does not attach a CSS font to a Label; this slice therefore uses the
supported Label style path instead of claiming that assignment is rendered.

## Target boundary

- KofJS: `Window`, `Label`, `Image`, `Icon`, `View`, `Column` and `Row` become
  DOM nodes and render in the generated host page. SVG is browser-native via
  `Image` or the intrinsic icon path; PNG is browser-native via `Image`.
- JVM/native: the same source compiles and the facade retains deterministic
  metadata/state. `kof.ui` handles are no-op by Kof contract. The SDL native
  gameplay HUD continues to use `FrameStaging` and the checked native adapter;
  this library does not silently create a second native renderer.

- KofScript: `KookieUiScriptDocument` is the bounded semantic layer. It has no
  `kof.ui` handles and therefore cannot render on its own; the host must map
  its descriptors to the handle-backed Kof/KofJS facade.

### Native engine skin

`src/ui/kookie_ui_native.kf` is the native counterpart of the same palette,
font metrics and focus semantics. It does not create a second renderer:
`KookieUiNativeTheme` owns semantic colors/resources and the bounded helper
primitives write directly to the existing `FrameStaging` contract.

The engine menus (`GameShell`) now consume that skin for frame surfaces,
selection rails, text colors, volume bars and accessibility contrast. The
gameplay HUD adds stable `HP`, `AMMO`, `BAG` and `XP` labels to its existing
vital/build/encounter/combat layers; actor nameplates, minimap and scoreboard
use the same native primitives and contrast setting. Geometry remains
preallocated and bounded; the HUD budget is 438 vertices.

The native adapter atlas maps the same tokens to the package palette:
background `#0f172a`, surface `#0f1f2b`, accent `#d97706`, focus `#15803d`,
danger `#dc2626` and success `#22c55e`. This is presentation styling only;
simulation/session ownership remains unchanged.

### Render budget

`FrameStaging` writes quads and triangles in one bounded operation, preserving
the same vertex order and scalar budget while avoiding repeated per-vertex
validation. Native presentation uploads recognize those primitive spans and
use bulk scene calls. CPU/GPU scene capacities grow with headroom, so switching
between HUD states and menus does not rebuild GPU buffers for every small count
change. Gameplay UI remains one scene draw call; world geometry stays in its
separate depth-tested pass.

### Layout and component kit

`src/ui/kookie_ui_components.kf` adds a bounded retained component layer for
apps, games and Kutter/editor surfaces:

| Layer | Reusable surface |
| --- | --- |
| Layout | `KookieUiLayoutSpec`, `KookieUiLayout`, `KookieUiPanel` |
| Controls | `KookieUiButton`, `KookieUiTextField`, `KookieUiToggle`, `KookieUiSlider` |
| Feedback | `KookieUiProgressBar`, `KookieUiBadge` |
| Composition | `KookieUiToolbar`, `KookieUiTabs`, `KookieUiInspector` |

`KookieUiLayoutSpec` owns direction, bounded gap/padding, alignment, fill
semantics and a deterministic CSS description. `KookieUiLayout` applies it to
`Column`/`Row` children; `KookieUiPanel` adds surface variants without
introducing a second renderer. Common controls keep their state in Kof as well
as in the KofJS handle, so JVM/native contract probes do not depend on no-op
`kof.ui` properties. Buttons expose `pressed`/`consumePressed`, toggles expose
`checked`, sliders clamp to their declared range, tabs and inspectors reject
capacity overflow.

The component kit is intentionally host-neutral: KofJS renders the handles,
while the native gameplay path continues to use `kookie_ui_native.kf` and
`FrameStaging`. Controls keep a 44px minimum touch target, visible text labels
and the shared dark semantic palette. `KookieUiToolbar`, `KookieUiTabs` and
`KookieUiInspector` cover the common game-editor surfaces without importing
editor authority or native pointers into the UI package.

Example:

```kof
var layout = kookieUiColumnLayout(8, 12)
var panel = KookieUiPanel(kookieUiPanelRaised(), layout)
var play = KookieUiButton("PLAY", kookieUiButtonPrimary())
var health = KookieUiProgressBar(0, 100, 75)
var inspector = KookieUiInspector(8)
inspector.addEntry("Mode", "Play")
panel.bindColumn(Column(listOf(play.widget(), health.widget(), inspector.widget())))
document.bindView(panel.widget())
```

`kof.ui.Style` requires literal CSS declarations on the current compiler.
Layout state therefore remains exact in the bounded spec, while the rendered
KofJS presets use static tokenized styles; this keeps JVM/native/KofJS builds
deterministic instead of constructing an unverified dynamic CSS runtime.

Use `scripts/verify_ui_library.sh` for the focused contract check. It runs the
probe on JVM/native, runs the KofScript companion on JVM/native, and
type-checks/builds the KofJS artifact. An interactive KofJS window intentionally
remains alive until its host closes it, so the non-interactive check does not
pretend that a timed CLI exit is a rendering proof.

### Sound cues and the Kof4j boundary

`src/ui/kookie_ui_audio.kf` is the reusable audio slice. `KookieUiSoundCue`
keeps a package-relative `.ogg`/`.wav` path, lowercase SHA-256, semantic label,
native clip ID and gain. `KookieUiSoundBank` admits at most 32 cues before
opening, rejects duplicate IDs/clip IDs, queues FIFO or spatial playback
through `core.QueuedAudio`, and exposes consumed metadata for the native adapter.
It does not decode files or retain SDL handles.

`src/ui/kookie_ui_audio_catalog.kf` is the native publication boundary:
`kookieUiPublishedSoundCue` checks exact source/digest pairs for the 14 native UI
OGG clip IDs, and `kookieUiSoundBankAddPublished` admits only those cues.
Generic `KookieUiSoundBank.add()` remains available for generic WAV cues or a
future external adapter. The SHA-256 descriptor is not a substitute for a
release file-byte/license gate.

The native SDL adapter consumes the resulting gains through
`kookie_audio_play_ui_clip_spatial`, which applies `MIX_SetTrackStereo` to the
predecoded registered UI track. The KofScript companion exposes the same
semantic node with `bindSound(..., defaultGain)`, `nodeClipId()` and
`nodeGain()`. Both layers remain descriptors/adapters: `kof.media` owns file
and media handles, while a future upstream playback API must define ownership,
close, gain, looping, spatialization and target failure semantics before this
slice can move to Kof4j. See
[`KOF4J_UI_MIGRATION.md`](KOF4J_UI_MIGRATION.md) for the current 0.5.0-beta ABI
audit and the buffer migration boundary.


## Accessibility and style rules

- Every raster/vector asset admitted by this slice requires non-empty
  alternative text.
- This slice does not model decorative assets; use semantic assets only with
  meaningful text and mount the matching description label for content that
  conveys meaning.
- Keep the dark palette contrast and the visible focus ring from
  `assets/ui/kookie-ui.css`.
- Use the intrinsic SVG icon set instead of emoji or text glyphs for controls.
- Keep layout composition in `View`/`Column`/`Row`; do not put game authority
  or native handles into this package.

The component kit is the current retained layer; new surfaces should reuse
these contracts before introducing another renderer, authority state or native
pointer.
