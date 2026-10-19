#!/usr/bin/env python3
"""Run malformed GLB byte fixtures through the bounded Kof reader."""

from __future__ import annotations

import json
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PROBE = ROOT / "probes/g0_model_loader/main.kf"


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


def write_fixture(
    root: Path, data: bytes, relative: str = "models/goose/goose.glb"
) -> None:
    path = root / "content/prototype" / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def exercise(
    kof: str, root: Path, expected: int, cat_expected: int | None = None
) -> None:
    content_dir = root / "content"
    content_dir.mkdir(exist_ok=True)
    cat_path = content_dir / "prototype/models/cat/cat.glb"
    if not cat_path.exists():
        write_fixture(root, make_glb(), "models/cat/cat.glb")
    (content_dir / "glb_model.kf").symlink_to(ROOT / "src/content/glb_model.kf")
    shutil.copy2(PROBE, root / "main.kf")
    result = subprocess.run(
        [kof, "run", "main.kf", "--target", "jvm"],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr or result.stdout)
    lines = result.stdout.splitlines()
    marker = "model-valid=1" if expected else "model-valid=0"
    if marker not in lines:
        raise RuntimeError(
            f"expected {marker}, got {result.stdout.strip() or result.stderr.strip()}"
        )
    if cat_expected is not None:
        marker = "cat-model-valid=1" if cat_expected else "cat-model-valid=0"
        if marker not in lines:
            raise RuntimeError(
                f"expected {marker}, got {result.stdout.strip() or result.stderr.strip()}"
            )


def main() -> int:
    kof = shutil.which("kof")
    if kof is None:
        print("model loader Kof gate requires the kof executable", file=sys.stderr)
        return 75
    with tempfile.TemporaryDirectory(prefix="kookie-model-loader-") as raw:
        work = Path(raw)

        real_root = work / "real"
        write_fixture(
            real_root,
            (ROOT / "assets/prototype/models/goose/goose.glb").read_bytes(),
        )
        write_fixture(
            real_root,
            (ROOT / "assets/prototype/models/cat/cat.glb").read_bytes(),
            "models/cat/cat.glb",
        )
        exercise(kof, real_root, 1, 1)

        valid_root = work / "valid"
        write_fixture(valid_root, make_glb())
        exercise(kof, valid_root, 1)

        json_root = work / "json-boundary"
        json_data = make_glb().replace(
            b'"asset":{"version"', b'"asset":[{"version"', 1
        )
        write_fixture(json_root, json_data)
        exercise(kof, json_root, 0)

        bad_magic_root = work / "bad-magic"
        bad_magic = bytearray(make_glb())
        bad_magic[0] = 0
        write_fixture(bad_magic_root, bytes(bad_magic))
        exercise(kof, bad_magic_root, 0)

        bad_version_root = work / "bad-version"
        bad_version = bytearray(make_glb())
        struct.pack_into("<I", bad_version, 4, 1)
        write_fixture(bad_version_root, bytes(bad_version))
        exercise(kof, bad_version_root, 0)

        bad_length_root = work / "bad-length"
        bad_length = bytearray(make_glb())
        struct.pack_into("<I", bad_length, 8, len(bad_length) - 4)
        write_fixture(bad_length_root, bytes(bad_length))
        exercise(kof, bad_length_root, 0)

        truncated_root = work / "truncated"
        write_fixture(truncated_root, make_glb()[:-4])
        exercise(kof, truncated_root, 0)

        oversized_root = work / "oversized"
        oversized = bytearray(b"\0" * (16 * 1024 * 1024 + 1))
        struct.pack_into("<III", oversized, 0, 0x46546C67, 2, len(oversized))
        write_fixture(oversized_root, bytes(oversized))
        exercise(kof, oversized_root, 0)

    print("KOOKIE Kof GLB reader fixtures verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
