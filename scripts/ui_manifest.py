"""Shared validation for the published GatoGanso UI asset manifest."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import re
from typing import Any


KIND_SUFFIXES = {"png": ".png", "svg": ".svg", "svgz": ".svgz"}


def _fail(message: str) -> None:
    raise ValueError(f"UI manifest: {message}")


def _string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value:
        _fail(f"{field} must be a non-empty string")
    if any(ord(character) < 32 for character in value):
        _fail(f"{field} contains a control character")
    if '"' in value or "\\" in value:
        _fail(f"{field} contains an unsupported Kof string delimiter")
    return value


def _path(value: Any, field: str, suffix: str | None = None) -> str:
    value = _string(value, field)
    path = PurePosixPath(value)
    if path.is_absolute() or value != path.as_posix():
        _fail(f"{field} must be a canonical relative POSIX path")
    if any(part in {"", ".", ".."} for part in path.parts):
        _fail(f"{field} contains an unsafe path segment")
    if any(ord(character) <= 32 or character in "#?" for character in value):
        _fail(f"{field} contains an unsafe character")
    if suffix is not None and not value.endswith(suffix):
        _fail(f"{field} must end with {suffix}")
    return value


def load_ui_manifest(manifest_path: Path) -> tuple[dict[str, Any], list[dict[str, str]]]:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        _fail(f"cannot read {manifest_path}: {error}")
    if not isinstance(manifest, dict):
        _fail("root must be an object")
    if manifest.get("schema") != "kookie.gatoganso-ui/v1":
        _fail("unsupported schema")
    publication = manifest.get("publication")
    if not isinstance(publication, dict):
        _fail("publication must be an object")
    if publication.get("runtime_paths_are_package_relative") is not True:
        _fail("runtime paths must be package-relative")
    if publication.get("sha256_required") is not True:
        _fail("SHA-256 must be required")
    if publication.get("prototype_assets_are_optional") is not True:
        _fail("prototype asset optionality must be explicit")
    optional_asset_ids = publication.get("optional_asset_ids")
    if not isinstance(optional_asset_ids, list):
        _fail("optional_asset_ids must be a list")
    if any(
        not isinstance(asset_id, str) or not asset_id
        for asset_id in optional_asset_ids
    ):
        _fail("optional_asset_ids must contain non-empty strings")
    if len(optional_asset_ids) != len(set(optional_asset_ids)):
        _fail("optional_asset_ids must not contain duplicates")
    if publication.get("demo_requires_prototype_assets") is not True:
        _fail("the demo must require prototype assets")

    raw_assets = manifest.get("assets")
    if not isinstance(raw_assets, list) or not raw_assets:
        _fail("assets must be a non-empty list")
    assets: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    for index, raw_asset in enumerate(raw_assets):
        if not isinstance(raw_asset, dict):
            _fail(f"asset {index} must be an object")
        asset_id = _string(raw_asset.get("id"), f"asset {index} id")
        if asset_id != asset_id.strip() or any(ord(character) <= 32 for character in asset_id):
            _fail(f"asset {asset_id} id contains whitespace")
        if asset_id in seen_ids:
            _fail(f"duplicate asset id: {asset_id}")
        seen_ids.add(asset_id)
        kind = raw_asset.get("kind")
        if kind not in KIND_SUFFIXES:
            _fail(f"asset {asset_id} has unsupported kind: {kind}")
        alt = _string(raw_asset.get("alt"), f"asset {asset_id} alt")
        authored_path = _path(
            raw_asset.get("authored_path"),
            f"asset {asset_id} authored_path",
            KIND_SUFFIXES[kind],
        )
        runtime_path = _path(
            raw_asset.get("runtime_path"),
            f"asset {asset_id} runtime_path",
            KIND_SUFFIXES[kind],
        )
        digest = _string(raw_asset.get("sha256"), f"asset {asset_id} sha256")
        if re.fullmatch(r"[0-9a-f]{64}", digest) is None:
            _fail(f"asset {asset_id} has an invalid lowercase SHA-256 digest")
        assets.append(
            {
                "id": asset_id,
                "kind": kind,
                "alt": alt,
                "authored_path": authored_path,
                "runtime_path": runtime_path,
                "sha256": digest,
            }
        )
    if not set(optional_asset_ids).issubset(seen_ids):
        _fail("optional_asset_ids must refer to declared assets")
    return manifest, assets


def verify_staged_ui_assets(
    manifest_path: Path, root: Path, profile: str
) -> tuple[dict[str, Any], list[dict[str, str]]]:
    if profile not in {"none", "prototype", "demo"}:
        raise ValueError(f"UI manifest: unsupported staging profile: {profile}")
    manifest, assets = load_ui_manifest(manifest_path)
    for asset in assets:
        path = root.joinpath(*PurePosixPath(asset["runtime_path"]).parts)
        if not path.is_file():
            optional = (
                profile == "none"
                and asset["id"] in manifest["publication"]["optional_asset_ids"]
            )
            if optional:
                continue
            _fail(f"missing staged asset for {profile}: {asset['id']}: {path}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != asset["sha256"]:
            _fail(f"digest mismatch for {asset['id']}: {path}")
    return manifest, assets
