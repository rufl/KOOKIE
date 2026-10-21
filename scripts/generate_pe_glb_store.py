#!/usr/bin/env python3
"""Embed bounded prototype GLBs compactly in the Windows PE module."""

from pathlib import Path
import sys


def main() -> None:
    asset_root = Path(sys.argv[1])
    output = Path(sys.argv[2])
    models = {
        1: asset_root / "models/goose/goose.glb",
        2: asset_root / "models/cat/cat.glb",
    }
    encoded = {}
    for model_id, path in models.items():
        data = path.read_bytes()
        if len(data) < 20 or len(data) > 1_048_576:
            raise SystemExit(f"invalid bounded GLB asset: {path} ({len(data)} bytes)")
        encoded[model_id] = data.hex()
    lines = [
        "package content",
        "class BoundedExternalGlbAssetStore {",
        "    String gooseHexValue",
        "    String catHexValue",
        "    Int[] gooseBytesValue",
        "    Int[] catBytesValue",
        "    public constructor() {",
    ]
    for model_id, field in ((1, "gooseHexValue"), (2, "catHexValue")):
        value = encoded[model_id]
        lines.append(f"        {field} = \"{value}\"")
        bytes_field = "gooseBytesValue" if model_id == 1 else "catBytesValue"
        lines.append(f"        {bytes_field} = decodeHex({field})")
    lines.extend([
        "    }",
        "    Int hexDigit(Int value) {",
        "        if (value >= 48 && value <= 57) { return value - 48 }",
        "        return value - 87",
        "    }",
        "    Int[] decodeHex(String value) {",
        "        var result = new Int[value.length() / 2]",
        "        for (var index = 0; index < result.length; index = index + 1) {",
        "            var high = value.charAt(index * 2) as Int",
        "            var low = value.charAt(index * 2 + 1) as Int",
        "            result[index] = hexDigit(high) * 16 + hexDigit(low)",
        "        }",
        "        return result",
        "    }",
        "    Bool required() { return true }",
        "    Bool available(Int model) { return model == 1 || model == 2 }",
        "    Int[] bytes(Int model) {",
        "        if (model == 1) { return gooseBytesValue }",
        "        if (model == 2) { return catBytesValue }",
        "        return new Int[0]",
        "    }",
        "}",
    ])
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
