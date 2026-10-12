#!/usr/bin/env python3
"""Build, reflect, validate, and package Kookie shader products."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path
from typing import Any


SCHEMA = "kookie.shader-manifest/v1"
CATALOG_SCHEMA = "kookie.shader-products/v1"
SPIRV_MAGIC = 0x07230203

OP_NAME = 5
OP_MEMBER_NAME = 6
OP_ENTRY_POINT = 15
OP_TYPE_VOID = 19
OP_TYPE_BOOL = 20
OP_TYPE_INT = 21
OP_TYPE_FLOAT = 22
OP_TYPE_VECTOR = 23
OP_TYPE_MATRIX = 24
OP_TYPE_IMAGE = 25
OP_TYPE_SAMPLER = 26
OP_TYPE_SAMPLED_IMAGE = 27
OP_TYPE_ARRAY = 28
OP_TYPE_RUNTIME_ARRAY = 29
OP_TYPE_STRUCT = 30
OP_TYPE_POINTER = 32
OP_CONSTANT = 43
OP_VARIABLE = 59
OP_DECORATE = 71
OP_MEMBER_DECORATE = 72

EXECUTION_MODELS = {
    0: "vertex",
    1: "tessellation_control",
    2: "tessellation_evaluation",
    3: "geometry",
    4: "fragment",
    5: "compute",
}

STAGE_FLAGS = {
    "vertex": "vert",
    "fragment": "frag",
    "compute": "comp",
}

DECORATION_BLOCK = 2
DECORATION_BUFFER_BLOCK = 3
DECORATION_MATRIX_STRIDE = 7
DECORATION_BUILT_IN = 11
DECORATION_LOCATION = 30
DECORATION_BINDING = 33
DECORATION_DESCRIPTOR_SET = 34
DECORATION_OFFSET = 35

STORAGE_UNIFORM_CONSTANT = 0
STORAGE_INPUT = 1
STORAGE_UNIFORM = 2
STORAGE_OUTPUT = 3
STORAGE_STORAGE_BUFFER = 12


class ShaderError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise ShaderError(message)


def command_path(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        fail(f"required shader tool is unavailable: {name}")
    return path


def run(command: list[str], *, cwd: Path | None = None) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        output = result.stdout.strip()
        detail = f": {output}" if output else ""
        fail(f"command failed ({result.returncode}): {' '.join(command)}{detail}")
    return result.stdout


def tool_version(path: str) -> str:
    result = subprocess.run(
        [path, "--version"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    return " ".join(result.stdout.split()) or "unreported"


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_json(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def decode_string(words: list[int]) -> tuple[str, int]:
    raw = bytearray()
    consumed = 0
    for word in words:
        consumed += 1
        raw.extend(struct.pack("<I", word))
        if 0 in struct.pack("<I", word):
            break
    return raw.split(b"\0", 1)[0].decode("utf-8", errors="replace"), consumed


def parse_spirv(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    if len(raw) % 4 != 0:
        fail(f"SPIR-V file is not word-aligned: {path}")
    words = list(struct.unpack(f"<{len(raw) // 4}I", raw))
    if len(words) < 5 or words[0] != SPIRV_MAGIC:
        fail(f"invalid SPIR-V magic: {path}")

    version = words[1]
    names: dict[int, str] = {}
    member_names: dict[tuple[int, int], str] = {}
    decorations: dict[int, dict[int, list[int]]] = {}
    member_decorations: dict[tuple[int, int], dict[int, list[int]]] = {}
    types: dict[int, tuple[Any, ...]] = {}
    variables: dict[int, tuple[int, int]] = {}
    constants: dict[int, int] = {}
    entry_points: list[dict[str, Any]] = []

    cursor = 5
    while cursor < len(words):
        first = words[cursor]
        word_count = first >> 16
        opcode = first & 0xFFFF
        if word_count == 0 or cursor + word_count > len(words):
            fail(f"invalid SPIR-V instruction at word {cursor}: {path}")
        operands = words[cursor + 1 : cursor + word_count]

        if opcode == OP_NAME and len(operands) >= 1:
            name, _ = decode_string(operands[1:])
            names[operands[0]] = name
        elif opcode == OP_MEMBER_NAME and len(operands) >= 2:
            name, _ = decode_string(operands[2:])
            member_names[(operands[0], operands[1])] = name
        elif opcode == OP_ENTRY_POINT and len(operands) >= 2:
            name, consumed = decode_string(operands[2:])
            entry_points.append(
                {
                    "stage": EXECUTION_MODELS.get(operands[0], f"execution_{operands[0]}"),
                    "id": operands[1],
                    "name": name,
                    "interfaces": operands[2 + consumed :],
                }
            )
        elif opcode == OP_DECORATE and len(operands) >= 2:
            target, decoration = operands[0], operands[1]
            decorations.setdefault(target, {})[decoration] = operands[2:]
        elif opcode == OP_MEMBER_DECORATE and len(operands) >= 3:
            target, member, decoration = operands[0], operands[1], operands[2]
            member_decorations.setdefault((target, member), {})[decoration] = operands[3:]
        elif opcode == OP_TYPE_VOID and len(operands) == 1:
            types[operands[0]] = ("void",)
        elif opcode == OP_TYPE_BOOL and len(operands) == 1:
            types[operands[0]] = ("bool",)
        elif opcode == OP_TYPE_INT and len(operands) >= 3:
            types[operands[0]] = ("int", operands[1], operands[2])
        elif opcode == OP_TYPE_FLOAT and len(operands) >= 2:
            types[operands[0]] = ("float", operands[1])
        elif opcode == OP_TYPE_VECTOR and len(operands) >= 3:
            types[operands[0]] = ("vector", operands[1], operands[2])
        elif opcode == OP_TYPE_MATRIX and len(operands) >= 3:
            types[operands[0]] = ("matrix", operands[1], operands[2])
        elif opcode == OP_TYPE_IMAGE and len(operands) >= 8:
            types[operands[0]] = ("image", *operands[1:])
        elif opcode == OP_TYPE_SAMPLER and len(operands) >= 2:
            types[operands[0]] = ("sampler", operands[1])
        elif opcode == OP_TYPE_SAMPLED_IMAGE and len(operands) >= 2:
            types[operands[0]] = ("sampled_image", operands[1])
        elif opcode == OP_TYPE_ARRAY and len(operands) >= 3:
            types[operands[0]] = ("array", operands[1], operands[2])
        elif opcode == OP_TYPE_RUNTIME_ARRAY and len(operands) >= 2:
            types[operands[0]] = ("runtime_array", operands[1])
        elif opcode == OP_TYPE_STRUCT:
            types[operands[0]] = ("struct", *operands[1:])
        elif opcode == OP_TYPE_POINTER and len(operands) >= 3:
            types[operands[0]] = ("pointer", operands[1], operands[2])
        elif opcode == OP_CONSTANT and len(operands) >= 3:
            constants[operands[1]] = operands[2]
        elif opcode == OP_VARIABLE and len(operands) >= 3:
            variables[operands[1]] = (operands[0], operands[2])

        cursor += word_count

    if not entry_points:
        fail(f"SPIR-V module has no entry point: {path}")
    if len(entry_points) != 1:
        fail(f"Kookie shader products must contain one entry point: {path}")

    def decoration(target: int, kind: int) -> list[int] | None:
        return decorations.get(target, {}).get(kind)

    def member_decoration(target: int, member: int, kind: int) -> list[int] | None:
        return member_decorations.get((target, member), {}).get(kind)

    def type_name(type_id: int) -> str:
        info = types.get(type_id)
        if info is None:
            return f"id_{type_id}"
        if info[0] == "float":
            return "float" if info[1] == 32 else f"float{info[1]}"
        if info[0] == "int":
            return ("int" if info[2] else "uint") + str(info[1])
        if info[0] == "bool":
            return "bool"
        if info[0] == "vector":
            component = type_name(info[1])
            if component == "float":
                return f"float{info[2]}"
            return f"{component}x{info[2]}"
        if info[0] == "matrix":
            column = type_name(info[1])
            return f"{column}x{info[2]}"
        return info[0]

    def type_size(type_id: int, parent: int | None = None, member: int | None = None) -> int:
        info = types.get(type_id)
        if info is None:
            return 0
        kind = info[0]
        if kind in {"float", "int"}:
            return info[1] // 8
        if kind == "bool":
            return 4
        if kind == "vector":
            return type_size(info[1]) * info[2]
        if kind == "matrix":
            stride_values = member_decoration(parent, member, DECORATION_MATRIX_STRIDE) if parent is not None and member is not None else None
            stride = stride_values[0] if stride_values else type_size(info[1])
            return stride * info[2]
        if kind == "array":
            stride_values = decoration(type_id, 6)
            stride = stride_values[0] if stride_values else type_size(info[1])
            return stride * constants.get(info[2], 0)
        if kind == "runtime_array":
            return 0
        if kind == "struct":
            end = 0
            for index, member_type in enumerate(info[1:]):
                offset_values = member_decoration(type_id, index, DECORATION_OFFSET)
                offset = offset_values[0] if offset_values else end
                end = max(end, offset + type_size(member_type, type_id, index))
            return end
        if kind == "pointer":
            return type_size(info[2])
        return 0

    def unpointer(type_id: int) -> int:
        info = types.get(type_id)
        if info and info[0] == "pointer":
            return info[2]
        return type_id

    def resource_kind(type_id: int, storage: int) -> str | None:
        base = unpointer(type_id)
        info = types.get(base)
        if storage == STORAGE_UNIFORM and info and info[0] == "struct":
            if DECORATION_BLOCK in decorations.get(base, {}) or DECORATION_BUFFER_BLOCK in decorations.get(base, {}):
                return "uniform_buffer"
        if storage == STORAGE_STORAGE_BUFFER:
            return "storage_buffer"
        if storage == STORAGE_UNIFORM_CONSTANT and info:
            if info[0] in {"sampled_image", "sampler"}:
                return "sampler"
            if info[0] == "image":
                return "storage_texture"
        return None

    resources: list[dict[str, Any]] = []
    inputs: list[dict[str, Any]] = []
    outputs: list[dict[str, Any]] = []
    for variable_id, (variable_type, storage) in variables.items():
        set_values = decoration(variable_id, DECORATION_DESCRIPTOR_SET)
        binding_values = decoration(variable_id, DECORATION_BINDING)
        kind = resource_kind(variable_type, storage)
        if kind is not None and set_values and binding_values:
            base = unpointer(variable_type)
            resource_name = names.get(variable_id) or names.get(base) or f"id_{variable_id}"
            resource: dict[str, Any] = {
                "name": resource_name,
                "set": set_values[0],
                "binding": binding_values[0],
                "kind": kind,
            }
            if kind == "uniform_buffer":
                resource["size"] = type_size(base)
            resources.append(resource)
        location_values = decoration(variable_id, DECORATION_LOCATION)
        if location_values and DECORATION_BUILT_IN not in decorations.get(variable_id, {}):
            io = {"location": location_values[0], "type": type_name(unpointer(variable_type))}
            if storage == STORAGE_INPUT:
                inputs.append(io)
            elif storage == STORAGE_OUTPUT:
                outputs.append(io)

    resources.sort(key=lambda item: (item["set"], item["binding"], item["name"]))
    inputs.sort(key=lambda item: item["location"])
    outputs.sort(key=lambda item: item["location"])
    entry = entry_points[0]
    reflection = {
        "version": f"{version >> 16}.{(version >> 8) & 0xFF}",
        "stage": entry["stage"],
        "entrypoint": entry["name"],
        "inputs": inputs,
        "outputs": outputs,
        "resources": resources,
        "num_samplers": sum(item["kind"] == "sampler" for item in resources),
        "num_storage_textures": sum(item["kind"] == "storage_texture" for item in resources),
        "num_storage_buffers": sum(item["kind"] == "storage_buffer" for item in resources),
        "num_uniform_buffers": sum(item["kind"] == "uniform_buffer" for item in resources),
    }
    reflection["interface_sha256"] = sha256_json(
        {key: value for key, value in reflection.items() if key != "interface_sha256"}
    )
    return reflection


def compare_contract(product: dict[str, Any], reflection: dict[str, Any]) -> None:
    for field in ("stage", "entrypoint"):
        if reflection[field] != product[field]:
            fail(
                f"{product['name']}: reflected {field}={reflection[field]!r}, "
                f"expected {product[field]!r}"
            )
    for field in ("inputs", "outputs"):
        expected = sorted(product[field], key=lambda item: item["location"])
        actual = reflection[field]
        if actual != expected:
            fail(f"{product['name']}: reflected {field} differs: {actual!r} != {expected!r}")
    expected_resources = sorted(product["resources"], key=lambda item: (item["set"], item["binding"], item["name"]))
    actual_resources = reflection["resources"]
    if actual_resources != expected_resources:
        fail(
            f"{product['name']}: reflected resources differ: "
            f"{actual_resources!r} != {expected_resources!r}"
        )


def source_tree_hash(root: Path, catalog_path: Path, products: list[dict[str, Any]]) -> str:
    digest = hashlib.sha256()
    paths = [catalog_path]
    for product in products:
        paths.append(root / product["glsl_source"])
        hlsl = root / product["hlsl_source"]
        if hlsl.is_file():
            paths.append(hlsl)
    for path in sorted(paths):
        relative = path.relative_to(root).as_posix().encode("utf-8")
        digest.update(len(relative).to_bytes(4, "little"))
        digest.update(relative)
        data = path.read_bytes()
        digest.update(len(data).to_bytes(8, "little"))
        digest.update(data)
    return digest.hexdigest()


def compile_product(
    root: Path,
    output: Path,
    product: dict[str, Any],
    glslc: str,
    spirv_val: str,
    spirv_target_env: str,
    target: str,
    dxc: str | None,
) -> dict[str, Any]:
    stage = STAGE_FLAGS[product["stage"]]
    source = root / product["glsl_source"]
    artifact_spv = output / f"{product['name']}.spv"
    run(
        [
            glslc,
            f"--target-env={spirv_target_env}",
            f"-fshader-stage={stage}",
            str(source),
            "-o",
            str(artifact_spv),
        ],
        cwd=root,
    )
    run([spirv_val, "--target-env", spirv_target_env, str(artifact_spv)], cwd=root)
    reflection = parse_spirv(artifact_spv)
    compare_contract(product, reflection)

    artifacts: list[dict[str, Any]] = [
        {
            "format": "spirv",
            "target_env": spirv_target_env,
            "path": artifact_spv.name,
            "sha256": sha256_path(artifact_spv),
        }
    ]
    if target == "windows":
        if dxc is None:
            fail("Windows shader products require KOOKIE_DXC or dxc")
        hlsl_source = root / product["hlsl_source"]
        artifact_dxil = output / f"{product['name']}.dxil"
        profile = "vs_6_0" if product["stage"] == "vertex" else "ps_6_0"
        run(
            [
                dxc,
                "-T",
                profile,
                "-E",
                product["entrypoint"],
                "-Fo",
                str(artifact_dxil),
                str(hlsl_source),
            ],
            cwd=root,
        )
        artifacts.append(
            {
                "format": "dxil",
                "profile": profile,
                "path": artifact_dxil.name,
                "source": product["hlsl_source"],
                "source_sha256": sha256_path(hlsl_source),
                "sha256": sha256_path(artifact_dxil),
            }
        )

    return {
        "name": product["name"],
        "stage": product["stage"],
        "entrypoint": product["entrypoint"],
        "glsl_source": product["glsl_source"],
        "glsl_source_sha256": sha256_path(source),
        "hlsl_source": product["hlsl_source"],
        "reflection": reflection,
        "interface_sha256": reflection["interface_sha256"],
        "artifacts": artifacts,
    }


def header_string(value: str) -> str:
    return json.dumps(value)


def write_header(path: Path, manifest: dict[str, Any]) -> None:
    rows = []
    for product in manifest["products"]:
        reflection = product["reflection"]
        rows.append(
            "    {"
            f"{header_string(product['name'])}, "
            f"{header_string(product['stage'])}, "
            f"{header_string(product['entrypoint'])}, "
            f"{header_string(product['interface_sha256'])}, "
            f"{reflection['num_samplers']}u, "
            f"{reflection['num_storage_textures']}u, "
            f"{reflection['num_storage_buffers']}u, "
            f"{reflection['num_uniform_buffers']}u"
            "}"
        )
    text = "\n".join(
        [
            "#ifndef KOOKIE_SHADER_MANIFEST_H",
            "#define KOOKIE_SHADER_MANIFEST_H",
            "",
            "#include <stddef.h>",
            "#include <string.h>",
            "",
            f"#define KOOKIE_SHADER_MANIFEST_SCHEMA {header_string(manifest['schema'])}",
            f"#define KOOKIE_SHADER_MANIFEST_TARGET {header_string(manifest['target'])}",
            f"#define KOOKIE_SHADER_MANIFEST_SOURCE_TREE_SHA256 {header_string(manifest['source_tree_sha256'])}",
            "",
            "typedef struct {",
            "    const char *name;",
            "    const char *stage;",
            "    const char *entrypoint;",
            "    const char *interface_sha256;",
            "    unsigned int num_samplers;",
            "    unsigned int num_storage_textures;",
            "    unsigned int num_storage_buffers;",
            "    unsigned int num_uniform_buffers;",
            "} KookieShaderMetadata;",
            "",
            "static const KookieShaderMetadata kookie_shader_metadata[] = {",
            ",\n".join(rows),
            "};",
            "",
            "static const size_t kookie_shader_metadata_count =",
            "    sizeof(kookie_shader_metadata) / sizeof(kookie_shader_metadata[0]);",
            "",
            "static inline const KookieShaderMetadata *",
            "kookie_shader_metadata_find(const char *name) {",
            "    if (name == NULL) {",
            "        return NULL;",
            "    }",
            "    for (size_t index = 0; index < kookie_shader_metadata_count; index += 1) {",
            "        if (strcmp(kookie_shader_metadata[index].name, name) == 0) {",
            "            return &kookie_shader_metadata[index];",
            "        }",
            "    }",
            "    return NULL;",
            "}",
            "",
            "#endif",
            "",
        ]
    )
    path.write_text(text, encoding="utf-8")


def build(args: argparse.Namespace) -> None:
    root = args.root.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    catalog_path = root / "native/shaders/kookie_shader_products.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    if catalog.get("schema") != CATALOG_SCHEMA:
        fail(f"unsupported shader catalog schema: {catalog.get('schema')!r}")
    products = catalog.get("products")
    if not isinstance(products, list) or not products:
        fail("shader catalog has no products")
    for pattern in (
        "*.spv", "*.dxil", "kookie_shader_manifest.json", "kookie_shader_manifest.h"
    ):
        for stale in output.glob(pattern):
            if stale.is_file() or stale.is_symlink():
                stale.unlink()

    glslc = command_path(os.environ.get("KOOKIE_GLSLC", "glslc"))
    spirv_val = command_path(os.environ.get("KOOKIE_SPIRV_VAL", "spirv-val"))
    dxc = None
    if args.target == "windows":
        dxc = os.environ.get("KOOKIE_DXC") or shutil.which("dxc")
        if not dxc:
            fail("Windows shader products require KOOKIE_DXC or dxc")
        if not Path(dxc).is_file() or not os.access(dxc, os.X_OK):
            fail(f"KOOKIE_DXC is not executable: {dxc}")

    manifest_products = []
    for product in products:
        manifest_products.append(
            compile_product(
                root,
                output,
                product,
                glslc,
                spirv_val,
                args.spirv_target_env,
                args.target,
                dxc,
            )
        )

    manifest = {
        "schema": SCHEMA,
        "catalog_schema": CATALOG_SCHEMA,
        "target": args.target,
        "spirv_target_env": args.spirv_target_env,
        "source_tree_sha256": source_tree_hash(root, catalog_path, products),
        "toolchain": {
            "glslc": tool_version(glslc),
            "spirv_val": tool_version(spirv_val),
            "dxc": tool_version(dxc) if dxc else "not-used",
        },
        "products": manifest_products,
        "header": "kookie_shader_manifest.h",
    }
    manifest_path = output / "kookie_shader_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    write_header(output / manifest["header"], manifest)


def manifest_child(base: Path, value: Any, label: str) -> Path:
    if not isinstance(value, str) or not value:
        fail(f"shader manifest {label} path is invalid")
    base = base.resolve()
    candidate = (base / value).resolve()
    try:
        candidate.relative_to(base)
    except ValueError:
        fail(f"shader manifest {label} path escapes its output directory: {value}")
    return candidate


def verify_manifest(path: Path) -> None:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schema") != SCHEMA:
        fail(f"unsupported shader manifest schema: {manifest.get('schema')!r}")
    if manifest.get("catalog_schema") != CATALOG_SCHEMA:
        fail(f"unsupported shader catalog schema: {manifest.get('catalog_schema')!r}")
    products = manifest.get("products")
    if not isinstance(products, list) or not products:
        fail("shader manifest has no products")
    spirv_val = command_path(os.environ.get("KOOKIE_SPIRV_VAL", "spirv-val"))
    base = path.parent.resolve()
    for product in products:
        reflection = product["reflection"]
        for artifact in product["artifacts"]:
            artifact_path = manifest_child(base, artifact["path"], "artifact")
            if not artifact_path.is_file():
                fail(f"shader artifact is missing: {artifact_path}")
            actual_hash = sha256_path(artifact_path)
            if actual_hash != artifact["sha256"]:
                fail(
                    f"shader artifact hash mismatch for {artifact['path']}: "
                    f"expected {artifact['sha256']}, found {actual_hash}"
                )
            if artifact["format"] == "spirv":
                run(
                    [
                        spirv_val,
                        "--target-env",
                        artifact["target_env"],
                        str(artifact_path),
                    ]
                )
                actual_reflection = parse_spirv(artifact_path)
                if actual_reflection["interface_sha256"] != reflection["interface_sha256"]:
                    fail(f"shader reflection changed for {product['name']}")
    header = manifest_child(base, manifest.get("header"), "header")
    if not header.is_file():
        fail(f"shader manifest header is missing: {header}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--target", choices=("linux", "windows"))
    parser.add_argument("--spirv-target-env", default=os.environ.get("KOOKIE_SPIRV_TARGET_ENV", "vulkan1.0"))
    parser.add_argument("--verify-manifest", type=Path)
    args = parser.parse_args()
    try:
        if args.verify_manifest is not None:
            verify_manifest(args.verify_manifest.resolve())
        else:
            if args.output is None or args.target is None:
                parser.error("--output and --target are required when building shaders")
            build(args)
    except ShaderError as error:
        print(f"shader-pipeline: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
