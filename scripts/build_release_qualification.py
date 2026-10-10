#!/usr/bin/env python3
"""Build a deterministic, signed-release input qualification manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, NoReturn


SCHEMA = "kookie.release-qualification/v1"
PACKAGE_SCHEMA = "kookie.package-provenance/v2"
TARGETS = {"linux-x86_64", "windows-x86_64"}


def fail(message: str) -> NoReturn:
    raise SystemExit(f"release qualification failed: {message}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        fail(f"missing JSON file: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid JSON file {path}: {error}")
    if not isinstance(value, dict):
        fail(f"JSON root is not an object: {path}")
    return value


def parse_binding(value: str, kind: str) -> tuple[str, Path]:
    target, separator, raw_path = value.partition("=")
    if not separator or target not in TARGETS or not raw_path:
        fail(f"{kind} must use TARGET=PATH for a supported target: {value!r}")
    return target, Path(raw_path)


def validate_package(target: str, path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest_path = path.resolve()
    manifest = load_json(manifest_path)
    required = {
        "schema",
        "application",
        "channel",
        "version",
        "target",
        "runtime",
        "source_commit",
        "source_tree_state",
        "kof_version",
        "kof_source_commit",
        "build_id",
        "archive",
        "sha256",
        "content_profile",
        "prototype_models_policy",
    }
    missing = sorted(required - manifest.keys())
    if missing:
        fail(f"package manifest {manifest_path} lacks: {', '.join(missing)}")
    if manifest["schema"] != PACKAGE_SCHEMA:
        fail(f"unsupported package manifest schema: {manifest['schema']!r}")
    if manifest["application"] != "kookie" or manifest["channel"] != "dogfood":
        fail(f"package manifest is not a KOOKIE dogfood artifact: {manifest_path}")
    if manifest["target"] != target:
        fail(f"package target mismatch for {target}: {manifest['target']!r}")
    if manifest["runtime"] != "presentation":
        fail(f"{target} package is not a presentation runtime")
    if manifest["source_tree_state"] != "clean":
        fail(f"{target} package was not built from a clean tree")
    if manifest["content_profile"] != "none":
        fail(f"release qualification requires content_profile=none, got {manifest['content_profile']!r}")
    if manifest["prototype_models_policy"] != "fallback-allowed":
        fail(f"{target} package has an invalid none-profile model policy")
    if manifest["signing"] != "ed25519":
        fail(f"{target} package is not Ed25519 signed")
    if not isinstance(manifest["source_commit"], str) or len(manifest["source_commit"]) != 40:
        fail(f"{target} package has an invalid source commit")
    if not isinstance(manifest["kof_source_commit"], str) or len(manifest["kof_source_commit"]) != 40:
        fail(f"{target} package has an invalid Kof source commit")
    archive_name = manifest["archive"]
    if not isinstance(archive_name, str) or Path(archive_name).name != archive_name:
        fail(f"{target} package archive name is unsafe")
    archive_path = manifest_path.parent / archive_name
    if not archive_path.is_file():
        fail(f"missing package archive for {target}: {archive_path}")
    archive_sha = sha256(archive_path)
    if archive_sha != manifest["sha256"]:
        fail(f"package archive digest mismatch for {target}")
    manifest_sha = sha256(manifest_path)
    artifact = {
        "manifest": manifest_path.name,
        "manifestSha256": manifest_sha,
        "archive": archive_name,
        "archiveSha256": archive_sha,
        "target": target,
        "runtime": manifest["runtime"],
        "version": manifest["version"],
        "buildId": manifest["build_id"],
        "sourceCommit": manifest["source_commit"],
        "kofVersion": manifest["kof_version"],
        "kofSourceCommit": manifest["kof_source_commit"],
        "contentProfile": manifest["content_profile"],
    }
    return manifest, artifact


def validate_evidence(target: str, path: Path) -> dict[str, Any]:
    evidence_path = path.resolve()
    evidence = load_json(evidence_path)
    if evidence.get("kind") != "kookie-g1-authoritative-presentation":
        fail(f"unsupported presentation evidence kind for {target}")
    if evidence.get("status") != "passed" or evidence.get("exitStatus") != 0:
        fail(f"presentation evidence did not pass for {target}")
    if evidence.get("gpuWindowScreenshotChecksum", 0) <= 0:
        fail(f"presentation evidence has no positive screenshot checksum for {target}")
    if evidence.get("gpuPresentCapabilities", 0) < 1:
        fail(f"presentation evidence has no present capability for {target}")
    if evidence.get("gpuDrawUs", 0) <= 0:
        fail(f"presentation evidence has no positive GPU draw time for {target}")
    screenshot_name = Path(str(evidence.get("screenshot", ""))).name
    log_name = Path(str(evidence.get("adapterLog", ""))).name
    if not screenshot_name or not log_name:
        fail(f"presentation evidence lacks portable artifact names for {target}")
    screenshot_path = evidence_path.parent / screenshot_name
    log_path = evidence_path.parent / log_name
    if not screenshot_path.is_file():
        fail(f"presentation screenshot is not retained for {target}: {screenshot_name}")
    if not log_path.is_file():
        fail(f"presentation log is not retained for {target}: {log_name}")
    if sha256(screenshot_path) != evidence.get("screenshotSha256"):
        fail(f"presentation screenshot digest mismatch for {target}")
    if sha256(log_path) != evidence.get("adapterLogSha256"):
        fail(f"presentation log digest mismatch for {target}")
    hardware_id = evidence.get("hardwareId")
    gpu_driver = evidence.get("gpuDriver")
    if (
        not isinstance(hardware_id, str)
        or not hardware_id.strip()
        or not isinstance(gpu_driver, str)
        or not gpu_driver.strip()
    ):
        fail(f"presentation evidence lacks target hardware metadata for {target}")
    return {
        "status": "passed",
        "evidence": evidence_path.name,
        "evidenceSha256": sha256(evidence_path),
        "host": evidence.get("host", ""),
        "os": evidence.get("os", ""),
        "osRelease": evidence.get("osRelease", ""),
        "machine": evidence.get("machine", ""),
        "hardwareId": evidence["hardwareId"],
        "gpuDriver": evidence["gpuDriver"],
        "videoDriver": evidence.get("videoDriver", ""),
        "displayServer": evidence.get("displayServer", ""),
        "renderNode": evidence.get("renderNode", ""),
        "isolationWrapper": evidence.get("isolationWrapper", ""),
        "command": evidence.get("command", ""),
        "adapterLog": log_name,
        "screenshot": screenshot_name,
        "screenshotSha256": evidence["screenshotSha256"],
        "screenshotWidth": evidence["screenshotWidth"],
        "screenshotHeight": evidence["screenshotHeight"],
        "gpuWindowScreenshotChecksum": evidence["gpuWindowScreenshotChecksum"],
        "gpuPresentCapabilities": evidence["gpuPresentCapabilities"],
        "gpuDrawUs": evidence["gpuDrawUs"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build a canonical KOOKIE release qualification manifest."
    )
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--package-manifest",
        action="append",
        required=True,
        metavar="TARGET=PATH",
    )
    parser.add_argument(
        "--evidence",
        action="append",
        default=[],
        metavar="TARGET=PATH",
    )
    parser.add_argument("--require-hardware", action="store_true")
    args = parser.parse_args()

    package_entries: dict[str, dict[str, Any]] = {}
    package_manifests: dict[str, dict[str, Any]] = {}
    for binding in args.package_manifest:
        target, path = parse_binding(binding, "--package-manifest")
        if target in package_entries:
            fail(f"duplicate package manifest for {target}")
        package_manifests[target], package_entries[target] = validate_package(target, path)
    evidence_paths: dict[str, Path] = {}
    for binding in args.evidence:
        target, path = parse_binding(binding, "--evidence")
        if target in evidence_paths:
            fail(f"duplicate evidence for {target}")
        evidence_paths[target] = path
    unknown_evidence = sorted(set(evidence_paths) - set(package_entries))
    if unknown_evidence:
        fail(f"evidence has no package manifest: {', '.join(unknown_evidence)}")

    versions = {manifest["version"] for manifest in package_manifests.values()}
    source_commits = {manifest["source_commit"] for manifest in package_manifests.values()}
    kof_commits = {manifest["kof_source_commit"] for manifest in package_manifests.values()}
    kof_versions = {manifest["kof_version"] for manifest in package_manifests.values()}
    profiles = {manifest["content_profile"] for manifest in package_manifests.values()}
    if len(versions) != 1:
        fail("package manifests disagree on release version")
    if len(source_commits) != 1:
        fail("package manifests disagree on source commit")
    if len(kof_commits) != 1 or len(kof_versions) != 1:
        fail("package manifests disagree on Kof toolchain identity")
    if len(profiles) != 1:
        fail("package manifests disagree on content profile")
    if args.require_hardware and set(package_entries) != TARGETS:
        fail("hardware-qualified release requires Linux and Windows package manifests")

    targets: dict[str, Any] = {}
    hardware_passed = True
    for target in sorted(package_entries):
        evidence_path = evidence_paths.get(target)
        if evidence_path is None:
            hardware_passed = False
            hardware = {"status": "not-run"}
        else:
            hardware = validate_evidence(target, evidence_path)
        targets[target] = {
            "artifact": package_entries[target],
            "hardwarePresentation": hardware,
        }

    if args.require_hardware and not hardware_passed:
        fail("hardware evidence is required for every target")
    status = "hardware-qualified" if hardware_passed else "artifact-qualified"
    output = args.output.resolve()
    manifest = {
        "schema": SCHEMA,
        "application": "kookie",
        "channel": "dogfood",
        "version": next(iter(versions)),
        "runtime": "presentation",
        "contentProfile": next(iter(profiles)),
        "sourceCommit": next(iter(source_commits)),
        "kofVersion": next(iter(kof_versions)),
        "kofSourceCommit": next(iter(kof_commits)),
        "status": status,
        "releaseEligible": status == "hardware-qualified" and set(targets) == TARGETS,
        "targets": targets,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"release qualification: {status} ({output})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
