#!/usr/bin/env python3
"""Render the shipped GatoGanso fonts into the bounded native 7x7 atlas."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
GLYPH_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:-/%>+?"
FONT_SPECS = (
    ("JARED_LITE", "Jared Lite", ROOT / "assets/fonts/jared-lite.ttf"),
    ("PIXAND", "Pixand", ROOT / "assets/fonts/pixand.ttf"),
)
RENDER_SIZE = 32
GLYPH_WIDTH = 7
GLYPH_HEIGHT = 7
THRESHOLD = 96


def render_glyph(font: ImageFont.FreeTypeFont, value: str) -> tuple[int, ...]:
    bbox = font.getbbox(value)
    width = max(1, bbox[2] - bbox[0])
    height = max(1, bbox[3] - bbox[1])
    canvas = Image.new("L", (width + 4, height + 4), 0)
    ImageDraw.Draw(canvas).text(
        (2 - bbox[0], 2 - bbox[1]), value, font=font, fill=255
    )
    ink_bounds = canvas.getbbox()
    if ink_bounds is None:
        return (0,) * GLYPH_HEIGHT
    ink = canvas.crop(ink_bounds)
    scale = min(GLYPH_WIDTH / ink.width, GLYPH_HEIGHT / ink.height)
    resized = ink.resize(
        (max(1, round(ink.width * scale)), max(1, round(ink.height * scale))),
        Image.Resampling.LANCZOS,
    )
    cell = Image.new("L", (GLYPH_WIDTH, GLYPH_HEIGHT), 0)
    cell.paste(
        resized,
        ((GLYPH_WIDTH - resized.width) // 2,
         (GLYPH_HEIGHT - resized.height) // 2),
    )
    return tuple(
        sum(1 << (GLYPH_WIDTH - 1 - column)
            for column in range(GLYPH_WIDTH)
            if cell.getpixel((column, row)) >= THRESHOLD)
        for row in range(GLYPH_HEIGHT)
    )


def render_font(path: Path) -> tuple[tuple[int, ...], ...]:
    font = ImageFont.truetype(path, RENDER_SIZE)
    blank = (0,) * GLYPH_HEIGHT
    return (blank,) + tuple(render_glyph(font, value) for value in GLYPH_CHARS)


def format_rows(rows: tuple[tuple[int, ...], ...]) -> str:
    return "\n".join(
        "    {" + ", ".join(f"0x{value:02x}" for value in row) + "},"
        for row in rows
    )


def generate() -> str:
    rendered = tuple(render_font(path) for _, _, path in FONT_SPECS)
    lines = [
        "#ifndef KOOKIE_PIXEL_FONT_H",
        "#define KOOKIE_PIXEL_FONT_H",
        "",
        "#include <stdint.h>",
        "#include <stddef.h>",
        "",
        "#define KOOKIE_PIXEL_FONT_COUNT 2",
        "#define KOOKIE_PIXEL_FONT_JARED_LITE 0",
        "#define KOOKIE_PIXEL_FONT_PIXAND 1",
        "#define KOOKIE_PIXEL_GLYPH_COUNT 44",
        "#define KOOKIE_PIXEL_GLYPH_WIDTH 7",
        "#define KOOKIE_PIXEL_GLYPH_HEIGHT 7",
        "",
        "/*",
        " * Generated from the TTF files in assets/fonts by",
        " * scripts/generate_pixel_font_header.py.",
        " * The generated atlas is a Font Software derivative under SIL OFL 1.1;",
        " * see assets/fonts/OFL.txt. The original TTF files remain packaged for",
        " * users and future rasterizers.",
        " */",
        "static const uint8_t kookie_pixel_font_glyph_rows[",
        "    KOOKIE_PIXEL_FONT_COUNT][KOOKIE_PIXEL_GLYPH_COUNT + 1][",
        "    KOOKIE_PIXEL_GLYPH_HEIGHT] = {",
    ]
    for index, (constant, family, _) in enumerate(FONT_SPECS):
        lines.append(f"    /* {constant}: {family} */")
        lines.append("    {")
        rows = rendered[index]
        lines.extend(format_rows(rows).splitlines())
        lines.append("    }" + ("," if index + 1 < len(FONT_SPECS) else ""))
    lines.extend(
        [
            "};",
            "",
            "static inline const uint8_t *kookie_pixel_glyph_row(",
            "    int font, int glyph, int row",
            ") {",
            "    if (font < 0 || font >= KOOKIE_PIXEL_FONT_COUNT ||",
            "        glyph < 0 || glyph > KOOKIE_PIXEL_GLYPH_COUNT ||",
            "        row < 0 || row >= KOOKIE_PIXEL_GLYPH_HEIGHT) {",
            "        return NULL;",
            "    }",
            "    return &kookie_pixel_font_glyph_rows[font][glyph][row];",
            "}",
            "",
            "static inline int kookie_pixel_glyph_for_ascii(unsigned char value) {",
            "    if (value >= 'A' && value <= 'Z') return (int)(value - 'A') + 1;",
            "    if (value >= 'a' && value <= 'z') return (int)(value - 'a') + 1;",
            "    if (value >= '0' && value <= '9') return (int)(value - '0') + 27;",
            "    switch (value) {",
            "        case '.': return 37;",
            "        case ':': return 38;",
            "        case '-': return 39;",
            "        case '/': return 40;",
            "        case '%': return 41;",
            "        case '>': return 42;",
            "        case '+': return 43;",
            "        case '?': return 44;",
            "        default: return 0;",
            "    }",
            "}",
            "",
            "#endif",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "native/kookie_pixel_font.h",
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    expected = generate()
    if args.check:
        if not output.is_file() or output.read_text(encoding="utf-8") != expected:
            print(f"font atlas is stale: {output}")
            return 1
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(expected, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
