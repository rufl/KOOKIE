#!/usr/bin/env python3
"""Build a deterministic, signed-release input qualification manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, NoReturn


SCHEMA = "kookie.release-qualification/v1"
PACKAGE_SCHEMA = "kookie.package-provenance/v2"
TARGETS = {"linux-x86_64", "windows-x86_64"}

COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")


def fail(message: str) -> NoReturn:
    raise SystemExit(f"release qualification failed: {message}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def public_key_sha256(path: Path, label: str) -> str:
    try:
        result = subprocess.run(
            [
                "openssl",
                "pkey",
                "-pubin",
                "-in",
                str(path),
                "-pubout",
                "-outform",
                "DER",
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError as error:
        fail(f"cannot run openssl for {label}: {error}")
    if result.returncode != 0:
        detail = result.stderr.decode(errors="replace").strip()
        suffix = f": {detail}" if detail else ""
        fail(f"cannot derive {label} digest{suffix}")
    return hashlib.sha256(result.stdout).hexdigest()


def require_regular(path: Path, label: str) -> None:
    if path.is_symlink() or not path.is_file():
        fail(f"{label} must be a regular file: {path}")


def verify_signature(
    public_key: Path, message: Path, signature: Path, label: str
) -> None:
    try:
        result = subprocess.run(
            [
                "openssl",
                "pkeyutl",
                "-verify",
                "-rawin",
                "-pubin",
                "-inkey",
                str(public_key),
                "-in",
                str(message),
                "-sigfile",
                str(signature),
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
    except OSError as error:
        fail(f"cannot run openssl for {label}: {error}")
    if result.returncode != 0:
        detail = result.stderr.strip()
        suffix = f": {detail}" if detail else ""
        fail(f"{label} signature verification failed{suffix}")


def validate_sha256(value: Any, label: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) != 64
        or any(character not in "0123456789abcdef" for character in value)
        or value == "0" * 64
    ):
        fail(f"{label} must be a nonzero lowercase SHA-256 digest")
    return value


def validate_digest_or_marker(value: Any, label: str, marker: str) -> str:
    if value == marker:
        return value
    return validate_sha256(value, label)


def validate_commit(value: Any, label: str) -> str:
    if not isinstance(value, str) or COMMIT_PATTERN.fullmatch(value) is None:
        fail(f"{label} must be a lowercase 40-character commit SHA")
    return value


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


def validate_package(
    target: str,
    path: Path,
    trusted_public_key: Path,
    trusted_public_key_sha: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    if path.is_symlink():
        fail(f"package manifest must not be a symlink: {path}")
    manifest_path = path.resolve()
    manifest = load_json(manifest_path)
    required = {
        "schema",
        "application",
        "channel",
        "version",
        "target",
        "runtime",
        "source_tree_state",
        "kof_version",
        "source_commit",
        "kof_source_commit",
        "kof_archive_sha256",
        "kof_compiler_sha256",
        "build_id",
        "archive",
        "sha256",
        "content_profile",
        "prototype_models_policy",
        "sdl3_archive_sha256",
        "sdl_mixer_archive_sha256",
        "sdl3_runtime_sha256",
        "sdl_mixer_runtime_sha256",
        "java_tool_version",
        "javac_tool_version",
        "java_tool_sha256",
        "javac_tool_sha256",
        "glslc_tool_version",
        "glslc_tool_sha256",
        "spirv_val_tool_version",
        "zig_version",
        "zig_archive_sha256",
        "zig_binary_sha256",
        "spirv_val_tool_sha256",
        "dxc_tool_sha256",
        "signing",
        "proof",
        "signature_encoding",
        "public_key",
        "public_key_sha256",
        "archive_signature",
        "manifest_signature",
        "checksums",
        "checksums_signature",
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
    if manifest["signing"] != "ed25519" or manifest["proof"] != "ed25519-signature-set":
        fail(f"{target} package does not declare the required Ed25519 proof")
    if manifest["signature_encoding"] != "binary":
        fail(f"{target} package uses an unsupported signature encoding")
    source_commit = validate_commit(
        manifest["source_commit"], f"{target} package source commit")
    kof_source_commit = validate_commit(
        manifest["kof_source_commit"], f"{target} package Kof source commit")
    kof_archive_sha256 = validate_sha256(
        manifest["kof_archive_sha256"], f"{target} Kof archive SHA-256"
    )
    kof_compiler_sha256 = validate_sha256(
        manifest["kof_compiler_sha256"], f"{target} Kof compiler SHA-256"
    )
    sdl3_archive_sha256 = validate_digest_or_marker(
        manifest["sdl3_archive_sha256"],
        f"{target} SDL3 archive SHA-256",
        "not-pinned",
    )
    sdl_mixer_archive_sha256 = validate_digest_or_marker(
        manifest["sdl_mixer_archive_sha256"],
        f"{target} SDL_mixer archive SHA-256",
        "not-pinned",
    )
    sdl3_runtime_sha256 = validate_sha256(
        manifest["sdl3_runtime_sha256"],
        f"{target} SDL3 runtime SHA-256",
    )
    sdl_mixer_runtime_sha256 = validate_sha256(
        manifest["sdl_mixer_runtime_sha256"],
        f"{target} SDL_mixer runtime SHA-256",
    )
    for field in (
        "java_tool_sha256",
        "javac_tool_sha256",
        "glslc_tool_sha256",
        "spirv_val_tool_sha256",
        "dxc_tool_sha256",
    ):
        value = manifest[field]
        if target == "windows-x86_64":
            validate_sha256(value, f"{target} {field}")
        elif value != "not-used":
            fail(f"{target} {field} must be not-used")
    if target == "windows-x86_64" and (
        sdl3_archive_sha256 == "not-pinned"
        or sdl_mixer_archive_sha256 == "not-pinned"
    ):
        fail(f"{target} package lacks pinned SDL archive provenance")
    zig_version = manifest["zig_version"]
    if not isinstance(zig_version, str) or not zig_version.strip():
        fail(f"{target} package lacks Zig version provenance")
    zig_archive_sha256 = validate_digest_or_marker(
        manifest["zig_archive_sha256"],
        f"{target} Zig archive SHA-256",
        "not-pinned",
    )
    zig_binary_sha256 = validate_sha256(
        manifest["zig_binary_sha256"],
        f"{target} Zig binary SHA-256",
    )
    if target == "windows-x86_64" and zig_archive_sha256 == "not-pinned":
        fail(f"{target} package lacks pinned Zig archive provenance")
    archive_name = manifest["archive"]
    if not isinstance(archive_name, str) or Path(archive_name).name != archive_name:
        fail(f"{target} package archive name is unsafe")
    manifest_name = manifest_path.name
    package_name = manifest_path.stem
    expected_package_name = f"kookie-{manifest['version']}-{target}"
    if package_name != expected_package_name:
        fail(f"{target} package manifest name is not {expected_package_name!r}")
    expected_archive_name = expected_package_name + (
        ".zip" if target == "windows-x86_64" else ".tar.gz"
    )
    if archive_name != expected_archive_name:
        fail(f"{target} package archive name is not {expected_archive_name!r}")
    expected_names = {
        "public_key": f"{package_name}.pub.pem",
        "archive_signature": f"{archive_name}.sig",
        "manifest_signature": f"{manifest_name}.sig",
        "checksums": "SHA256SUMS",
        "checksums_signature": "SHA256SUMS.sig",
    }
    for field, expected_name in expected_names.items():
        if manifest[field] != expected_name:
            fail(f"{target} package {field} name is not {expected_name!r}")
    public_key_name = manifest["public_key"]
    if not isinstance(public_key_name, str) or Path(public_key_name).name != public_key_name:
        fail(f"{target} package public key name is unsafe")
    public_key_path = manifest_path.parent / public_key_name
    archive_path = manifest_path.parent / archive_name
    archive_signature = manifest_path.parent / expected_names["archive_signature"]
    manifest_signature = manifest_path.parent / expected_names["manifest_signature"]
    checksums_path = manifest_path.parent / expected_names["checksums"]
    checksums_signature = manifest_path.parent / expected_names["checksums_signature"]
    for label, candidate in (
        ("public key", public_key_path),
        ("package archive", archive_path),
        ("archive signature", archive_signature),
        ("manifest signature", manifest_signature),
        ("SHA256SUMS", checksums_path),
        ("SHA256SUMS signature", checksums_signature),
    ):
        require_regular(candidate, f"{target} {label}")
    public_key_sha = validate_sha256(
        manifest["public_key_sha256"], f"{target} public key SHA-256")
    if public_key_sha256(public_key_path, f"{target} package public key") != public_key_sha:
        fail(f"{target} public key digest mismatch")
    if public_key_sha != trusted_public_key_sha:
        fail(f"{target} package is signed by an untrusted public key")
    archive_sha = sha256(archive_path)
    manifest_archive_sha = validate_sha256(
        manifest["sha256"], f"{target} package archive SHA-256")
    if archive_sha != manifest_archive_sha:
        fail(f"package archive digest mismatch for {target}")
    checksum_entries: dict[str, str] = {}
    for line in checksums_path.read_text(encoding="utf-8").splitlines():
        digest, separator, name = line.partition("  ")
        if not separator or name in checksum_entries:
            fail(f"{target} SHA256SUMS has an invalid entry")
        checksum_entries[name] = validate_sha256(
            digest, f"{target} SHA256SUMS entry")
        checksum_target = manifest_path.parent / name
        if Path(name).name != name:
            fail(f"{target} SHA256SUMS entry has an unsafe name")
        require_regular(checksum_target, f"{target} SHA256SUMS entry")
        if sha256(checksum_target) != checksum_entries[name]:
            fail(f"{target} SHA256SUMS digest mismatch for {name}")
    expected_checksum_entries = {
        archive_name,
        manifest_name,
        public_key_name,
        expected_names["archive_signature"],
        expected_names["manifest_signature"],
    }
    if set(checksum_entries) != expected_checksum_entries:
        fail(f"{target} SHA256SUMS entries do not match the package set")
    verify_signature(
        trusted_public_key, archive_path, archive_signature,
        f"{target} archive")
    verify_signature(
        trusted_public_key, manifest_path, manifest_signature,
        f"{target} manifest")
    verify_signature(
        trusted_public_key, checksums_path, checksums_signature,
        f"{target} SHA256SUMS")
    manifest_sha = sha256(manifest_path)
    artifact = {
        "manifest": manifest_name,
        "manifestSha256": manifest_sha,
        "archive": archive_name,
        "archiveSha256": archive_sha,
        "publicKeySha256": public_key_sha,
        "target": target,
        "runtime": manifest["runtime"],
        "version": manifest["version"],
        "sourceCommit": source_commit,
        "kofVersion": manifest["kof_version"],
        "kofSourceCommit": kof_source_commit,
        "kofArchiveSha256": kof_archive_sha256,
        "kofCompilerSha256": kof_compiler_sha256,
        "sdl3ArchiveSha256": sdl3_archive_sha256,
        "sdlMixerArchiveSha256": sdl_mixer_archive_sha256,
        "sdl3RuntimeSha256": sdl3_runtime_sha256,
        "sdlMixerRuntimeSha256": sdl_mixer_runtime_sha256,
        "javaToolVersion": manifest["java_tool_version"],
        "javacToolVersion": manifest["javac_tool_version"],
        "javaToolSha256": manifest["java_tool_sha256"],
        "javacToolSha256": manifest["javac_tool_sha256"],
        "glslcToolVersion": manifest["glslc_tool_version"],
        "glslcToolSha256": manifest["glslc_tool_sha256"],
        "spirvValToolVersion": manifest["spirv_val_tool_version"],
        "spirvValToolSha256": manifest["spirv_val_tool_sha256"],
        "dxcToolSha256": manifest["dxc_tool_sha256"],
        "zigVersion": zig_version,
        "zigArchiveSha256": zig_archive_sha256,
        "zigBinarySha256": zig_binary_sha256,
        "contentProfile": manifest["content_profile"],
    }
    return manifest, artifact


def validate_evidence(
    target: str,
    path: Path,
    expected_source_commit: str,
    expected_archive_sha: str,
    expected_manifest_sha: str,
) -> dict[str, Any]:
    require_regular(path, f"{target} evidence")
    evidence_path = path.resolve()
    evidence = load_json(evidence_path)
    evidence_source_commit = validate_commit(
        evidence.get("sourceCommit"), f"{target} evidence source commit")
    if evidence_source_commit != expected_source_commit:
        fail(f"{target} evidence source commit does not match its package")
    evidence_archive_sha = validate_sha256(
        evidence.get("packageArchiveSha256"),
        f"{target} evidence package archive SHA-256")
    evidence_manifest_sha = validate_sha256(
        evidence.get("packageManifestSha256"),
        f"{target} evidence package manifest SHA-256")
    if evidence_archive_sha != expected_archive_sha:
        fail(f"{target} evidence does not match its package archive")
    if evidence_manifest_sha != expected_manifest_sha:
        fail(f"{target} evidence does not match its package manifest")
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
    require_regular(screenshot_path, f"{target} presentation screenshot")
    require_regular(log_path, f"{target} presentation log")
    screenshot_sha = validate_sha256(
        evidence.get("screenshotSha256"),
        f"{target} presentation screenshot SHA-256")
    log_sha = validate_sha256(
        evidence.get("adapterLogSha256"),
        f"{target} presentation log SHA-256")
    if sha256(screenshot_path) != screenshot_sha:
        fail(f"presentation screenshot digest mismatch for {target}")
    if sha256(log_path) != log_sha:
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
        "sourceCommit": evidence_source_commit,
        "packageArchiveSha256": evidence_archive_sha,
        "packageManifestSha256": evidence_manifest_sha,
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
    parser.add_argument("--trusted-public-key", type=Path, required=True)
    parser.add_argument("--expected-source-commit")
    args = parser.parse_args()
    trusted_public_key = args.trusted_public_key.resolve()
    require_regular(trusted_public_key, "trusted release public key")
    trusted_public_key_sha = public_key_sha256(
        trusted_public_key, "trusted release public key")

    package_entries: dict[str, dict[str, Any]] = {}
    package_manifests: dict[str, dict[str, Any]] = {}
    for binding in args.package_manifest:
        target, path = parse_binding(binding, "--package-manifest")
        if target in package_entries:
            fail(f"duplicate package manifest for {target}")
        package_manifests[target], package_entries[target] = validate_package(
            target, path, trusted_public_key, trusted_public_key_sha)
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
    if args.expected_source_commit is not None:
        expected_source_commit = validate_commit(
            args.expected_source_commit, "expected source commit")
        if source_commits != {expected_source_commit}:
            fail("package manifests do not match the expected source commit")
    kof_commits = {manifest["kof_source_commit"] for manifest in package_manifests.values()}
    kof_versions = {manifest["kof_version"] for manifest in package_manifests.values()}
    kof_archives = {manifest["kof_archive_sha256"] for manifest in package_manifests.values()}
    kof_compilers = {manifest["kof_compiler_sha256"] for manifest in package_manifests.values()}
    profiles = {manifest["content_profile"] for manifest in package_manifests.values()}
    public_keys = {entry["publicKeySha256"] for entry in package_entries.values()}
    if len(versions) != 1:
        fail("package manifests disagree on release version")
    if len(source_commits) != 1:
        fail("package manifests disagree on source commit")
    if len(kof_commits) != 1 or len(kof_versions) != 1:
        fail("package manifests disagree on Kof toolchain identity")
    if len(kof_archives) != 1 or len(kof_compilers) != 1:
        fail("package manifests disagree on Kof artifact identity")
    if len(public_keys) != 1:
        fail("package manifests disagree on the release signing public key")
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
            hardware = validate_evidence(
                target,
                evidence_path,
                package_manifests[target]["source_commit"],
                package_entries[target]["archiveSha256"],
                package_entries[target]["manifestSha256"],
            )
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
        "kofArchiveSha256": next(iter(kof_archives)),
        "kofCompilerSha256": next(iter(kof_compilers)),
        "publicKeySha256": next(iter(public_keys)),
        "trustedPublicKeySha256": trusted_public_key_sha,
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
