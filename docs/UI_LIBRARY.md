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
| Accessibility text | required `alt`, `bindAssetDescription`, `bindIconDescription` | Kof label tree |
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
        "assets/ui/gatoganso-mark.svg", kookieUiAssetSvg(), "GatoGanso")
    var hearts = KookieUiAsset(
        "assets/prototype/runtime/ui/hearts_0001.png",
        kookieUiAssetPng(), "Health")

    document.bindText(title)
    document.bindAsset(logo, 32)
    document.bindAssetDescription(logo)
    document.bindAsset(hearts, 48)
    document.bindAssetDescription(hearts)
    document.show()
}
```

`KookieUiAsset.accepted()` is deliberately bounded metadata validation: the
source is non-empty, the alternative text is non-empty, and the declared kind
matches `.png`, `.svg` or `.svgz`. It is not a content decoder. Source assets
must still pass the content pipeline before publication:

```bash
scripts/kooker.sh cook png input.png output.rgba.png
scripts/kooker.sh cook svg input.svg output.svgc
scripts/kooker.sh cook svgz input.svgz output.svgzc
```

The UI host may serve the authored web asset for KofJS, while native/package
pipelines must use their own admitted/cooked representation. The UI facade
never treats an unvalidated path as published content.

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

- Every raster/vector asset requires non-empty alternative text.
- Mount the matching description label for icons and images that convey
  meaning; decorative assets should not be admitted as semantic content.
- Keep the dark palette contrast and the visible focus ring from
  `assets/ui/kookie-ui.css`.
- Use the intrinsic SVG icon set instead of emoji or text glyphs for controls.
- Keep layout composition in `View`/`Column`/`Row`; do not put game authority
  or native handles into this package.

The next layer can add retained components and richer layout only after the
current handle, asset and target boundaries remain stable.
