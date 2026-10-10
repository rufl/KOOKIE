#!/usr/bin/env python3
"""Run malformed native GLB fixtures through ASan and UBSan."""

from __future__ import annotations

import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def make_glb(
    positions: list[tuple[float, float, float]] | None = None,
    node_count: int = 1,
    extra: object | None = None,
) -> bytes:
    if positions is None:
        positions = [(0.0, 0.0, 0.0), (1.0, 1.0, 0.0), (0.0, 2.0, 0.0)]
    binary = bytearray()
    for position in positions:
        binary.extend(struct.pack("<3f", *position))
    binary.extend(struct.pack("<3H", 0, 1, 2))
    binary.extend(struct.pack("<6f", 0.0, 0.0, 1.0, 0.0, 0.0, 1.0))
    while len(binary) % 4:
        binary.append(0)

    document = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": 36},
            {"buffer": 0, "byteOffset": 36, "byteLength": 6},
            {"buffer": 0, "byteOffset": 42, "byteLength": 24},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"},
            {"bufferView": 1, "componentType": 5123, "count": 3, "type": "SCALAR"},
            {"bufferView": 2, "componentType": 5126, "count": 3, "type": "VEC2"},
        ],
        "meshes": [
            {
                "primitives": [
                    {
                        "attributes": {"POSITION": 0, "TEXCOORD_0": 2},
                        "indices": 1,
                        "mode": 4,
                        "material": 0,
                    }
                ]
            }
        ],
        "nodes": [{"mesh": 0} for _ in range(node_count)],
    }
    if extra is not None:
        document["extras"] = extra
    encoded = json.dumps(document, separators=(",", ":")).encode("utf-8")
    encoded += b" " * ((-len(encoded)) % 4)
    header_length = 12 + 8 + len(encoded) + 8 + len(binary)
    return (
        struct.pack("<III", 0x46546C67, 2, header_length)
        + struct.pack("<II", len(encoded), 0x4E4F534A)
        + encoded
        + struct.pack("<II", len(binary), 0x004E4942)
        + binary
    )


def write_fixture(root: Path, data: bytes) -> Path:
    path = root / "models" / "goose" / "goose.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def build_harness(work: Path) -> Path:
    source = work / "loader_harness.c"
    source.write_text(
        """
#include "kookie_model_assets.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    if (setenv("KOOKIE_PROTOTYPE_CONTENT_ROOT", argv[1], 1) != 0) return 3;
    int expected = atoi(argv[2]);
    int actual = kookie_model_assets_available(KOOKIE_MODEL_GOOSE) ? 1 : 0;
    if (actual != expected) {
        fprintf(stderr, "expected %d, got %d\\n", expected, actual);
        return 4;
    }
    return 0;
}
""",
        encoding="utf-8",
    )
    binary = work / "loader_harness"
    command = [
        os.environ.get("CC", "cc"),
        "-D_POSIX_C_SOURCE=200809L",
        "-std=c11",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-O1",
        "-g",
        "-fno-omit-frame-pointer",
        "-fsanitize=address,undefined",
        "-I",
        str(ROOT / "native"),
        str(source),
        str(ROOT / "native" / "kookie_model_assets.c"),
        "-lm",
        "-o",
        str(binary),
    ]
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(result.stderr or result.stdout)
    return binary


def exercise(binary: Path, root: Path, expected: int) -> None:
    environment = os.environ.copy()
    environment.update(
        {
            "ASAN_OPTIONS": "detect_leaks=1:halt_on_error=1",
            "UBSAN_OPTIONS": "halt_on_error=1:print_stacktrace=1",
        }
    )
    result = subprocess.run(
        [str(binary), str(root), str(expected)],
        cwd=root.parent,
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr or result.stdout)


def main() -> int:
    if shutil.which(os.environ.get("CC", "cc")) is None:
        print("model loader sanitizer gate requires a C compiler", file=sys.stderr)
        return 75
    with tempfile.TemporaryDirectory(prefix="kookie-model-loader-") as raw:
        work = Path(raw)
        binary = build_harness(work)

        real_root = work / "real"
        write_fixture(
            real_root,
            (ROOT / "assets/prototype/models/cat/cat.glb").read_bytes(),
        )
        exercise(binary, real_root, 1)

        valid_root = work / "valid"
        write_fixture(valid_root, make_glb())
        exercise(binary, valid_root, 1)
        metadata_root = work / "buffer-metadata"
        metadata = make_glb().replace(
            b'"byteLength":68', b'"byteLength":67', 1
        )
        write_fixture(metadata_root, metadata)
        exercise(binary, metadata_root, 0)
        array_limit_root = work / "array-limit"
        write_fixture(array_limit_root, make_glb(node_count=4097))
        exercise(binary, array_limit_root, 0)
        deep_value: object = 0
        for _ in range(256):
            deep_value = [deep_value]
        deep_root = work / "deep-json"
        write_fixture(deep_root, make_glb(extra=deep_value))
        exercise(binary, deep_root, 0)

        suffix_root = work / "numeric-suffix"
        suffix = make_glb().replace(b'"count":3', b'"count":3e0', 1)
        write_fixture(suffix_root, suffix)
        exercise(binary, suffix_root, 0)

        overflow_root = work / "transform-overflow"
        write_fixture(
            overflow_root,
            make_glb(
                [
                    (3.402823466e38, 0.0, 0.0),
                    (3.402823466e38, 1.0, 0.0),
                    (3.402823466e38, 2.0, 0.0),
                ]
            ),
        )
        exercise(binary, overflow_root, 0)

        huge_uv_root = work / "huge-uv"
        huge_uv = bytearray(make_glb())
        uv_bytes = struct.pack("<6f", 0.0, 0.0, 1.0, 0.0, 0.0, 1.0)
        uv_offset = huge_uv.find(uv_bytes)
        assert uv_offset >= 0
        struct.pack_into("<f", huge_uv, uv_offset, 3.402823466e38)
        write_fixture(huge_uv_root, bytes(huge_uv))
        exercise(binary, huge_uv_root, 1)

        out_of_range_root = work / "out-of-range-index"
        out_of_range = bytearray(make_glb())
        json_length = struct.unpack_from("<I", out_of_range, 12)[0]
        indices_offset = 12 + 8 + json_length + 8 + 36
        struct.pack_into("<H", out_of_range, indices_offset, 9)
        write_fixture(out_of_range_root, bytes(out_of_range))
        exercise(binary, out_of_range_root, 0)

        duplicate_root = work / "duplicate-json"
        duplicate = make_glb()
        json_length = struct.unpack_from("<I", duplicate, 12)[0]
        json_chunk = duplicate[20 : 20 + json_length]
        duplicate += struct.pack("<II", json_length, 0x4E4F534A) + json_chunk
        duplicate = bytearray(duplicate)
        struct.pack_into("<I", duplicate, 8, len(duplicate))
        write_fixture(duplicate_root, bytes(duplicate))
        exercise(binary, duplicate_root, 0)

        oversized_root = work / "oversized"
        write_fixture(oversized_root, b"\0" * (16 * 1024 * 1024 + 1))
        exercise(binary, oversized_root, 0)

    print("KOOKIE native GLB loader ASan/UBSan fixtures verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
