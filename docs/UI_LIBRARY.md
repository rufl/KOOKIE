# KOOKIE UI library

`src/ui/kookie_ui.kf` is the first internal presentation slice for Kof and
KofJS. It is a small facade over `kof.ui`, not a replacement for the Kof
stdlib. The design borrows the useful boundaries from ZLAY, ZFONT, ZPIX, ZDOM
and ZWEB while keeping ownership in KOOKIE source.

## Contract

| Concern | KOOKIE surface | Owner |
| --- | --- | --- |
| Layout and surfaces | `kookieUi*Style`, `View`, `Column`, `Row` | Kof/KofJS DOM |
| Font roles | `kookieUiFontBody`, `kookieUiFontDisplay`, `KookieUiText` | Kof style + host CSS |
| SVG/PNG assets | `KookieUiAsset` | `Image` in KofJS; host/native adapter outside this slice |
| Built-in vector icons | `KookieUiIcon` | Kof intrinsic SVG icon registry |
| Accessibility text | non-empty `alt` constructor argument, `bindAssetDescription`, `bindIconDescription` | Kof label tree |
| Window composition | `KookieUiDocument` | Kof `Window` |

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
    var logo = KookieUiAsset(
        "ui.gatoganso-mark", "assets/ui/gatoganso-mark.svg",
        kookieUiAssetSvg(), "GatoGanso mark",
        "b8a5fa320e49bf41d06969ae8d918a70a5525a9c7271fbe073c7878798b0f17e")
    var hearts = KookieUiAsset(
        "ui.player-hearts",
        "content/prototype/runtime/ui/hearts_0001.png",
        kookieUiAssetPng(), "Player health",
        "c468c974f5c044012c0d84ef57c6e3941f8472ab841fc030ea98d865013576d3")

    document.bindText(title)
    document.bindAsset(logo, 32)
    document.bindAssetDescription(logo)
    document.bindAsset(hearts, 48)
    document.bindAssetDescription(hearts)
    document.show()
}
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

The source tree can stage the authored prototype asset under the package path
used by the demo:

```bash
mkdir -p build/content/prototype/runtime/ui
cp assets/prototype/runtime/ui/hearts_0001.png \
  build/content/prototype/runtime/ui/hearts_0001.png
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

Use `scripts/verify_ui_library.sh` for the focused contract check. It runs the
probe on JVM/native and type-checks/builds the KofJS artifact. An interactive
KofJS window intentionally remains alive until its host closes it, so the
non-interactive check does not pretend that a timed CLI exit is a rendering
proof.

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

The next layer can add retained components and richer layout only after the
current handle, asset and target boundaries remain stable.
