#!/usr/bin/env python3
import hashlib
import json
import os
import platform
import re
import sys
from pathlib import Path

SOURCE_COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")
DIGEST_PATTERN = re.compile(r"[0-9a-f]{64}")


def fail(message: str) -> int:
    print(f"presentation evidence failed: {message}", file=sys.stderr)
    return 1


def ppm_dimensions(data: bytes):
    if not data.startswith(b"P6"):
        return None
    index = 0
    tokens = []
    while len(tokens) < 4:
        while index < len(data) and data[index] in b" \t\r\n":
            index += 1
        start = index
        while index < len(data) and data[index] not in b" \t\r\n":
            index += 1
        if start == index:
            return None
        tokens.append(data[start:index])
    if tokens[0] != b"P6":
        return None
    try:
        width = int(tokens[1])
        height = int(tokens[2])
        maximum = int(tokens[3])
    except ValueError:
        return None
    if index >= len(data) or data[index] not in b" \t\r\n":
        return None
    index += 1
    if width <= 0 or height <= 0 or width > 4096 or height > 4096 or maximum != 255:
        return None
    expected = width * height * 3
    if len(data) - index != expected:
        return None
    return width, height


def marker_value(log: str, marker: str):
    lines = log.splitlines()
    for index, line in enumerate(lines):
        if line.strip() != marker:
            continue
        for value_line in lines[index + 1:]:
            value = value_line.strip()
            if not value:
                continue
            try:
                return int(value)
            except ValueError:
                return None
    return None


def main() -> int:
    if len(sys.argv) not in (4, 5) or (
            len(sys.argv) == 5 and sys.argv[4] != "--require-hardware-metadata"):
        return fail(
            "usage: validate_presentation_evidence.py LOG PPM EVIDENCE_JSON "
            "[--require-hardware-metadata]"
        )
    require_hardware_metadata = len(sys.argv) == 5
    log_path = Path(sys.argv[1])
    ppm_path = Path(sys.argv[2])
    evidence_path = Path(sys.argv[3]) if sys.argv[3] else None
    if not log_path.is_file():
        return fail(f"missing adapter log: {log_path}")
    log_bytes = log_path.read_bytes()
    log = log_bytes.decode("utf-8", errors="replace")
    package_archive_sha = os.environ.get(
        "KOOKIE_PRESENTATION_PACKAGE_ARCHIVE_SHA256", "").strip()
    package_manifest_sha = os.environ.get(
        "KOOKIE_PRESENTATION_PACKAGE_MANIFEST_SHA256", "").strip()
    if require_hardware_metadata:
        if DIGEST_PATTERN.fullmatch(package_archive_sha) is None:
            return fail(
                "hardware evidence requires the package archive SHA-256")
        if DIGEST_PATTERN.fullmatch(package_manifest_sha) is None:
            return fail(
                "hardware evidence requires the package manifest SHA-256")
    elif package_archive_sha and DIGEST_PATTERN.fullmatch(package_archive_sha) is None:
        return fail("package archive SHA-256 is invalid")
    elif package_manifest_sha and DIGEST_PATTERN.fullmatch(package_manifest_sha) is None:
        return fail("package manifest SHA-256 is invalid")
    source_commit = os.environ.get(
        "KOOKIE_PRESENTATION_SOURCE_COMMIT", "").strip()
    if source_commit and SOURCE_COMMIT_PATTERN.fullmatch(source_commit) is None:
        return fail("presentation source commit is not a lowercase 40-character SHA")
    if require_hardware_metadata and not source_commit:
        return fail(
            "hardware evidence requires KOOKIE_PRESENTATION_SOURCE_COMMIT")
    required = (
        "gpu-open",
        "gpu-window-screenshot-checksum",
        "gpu-present-capabilities",
        "gpu-draw-us",
        "audio-open",
        "KOOKIE G0 native SDL adapter verified",
        "KOOKIE G1 native arena HUD verified",
        "KOOKIE D1 authoritative gameplay verified",
        "KOOKIE D1 Play restart exit verified",
        "KOOKIE G2 native 3D door verified",
        "KOOKIE G4 GPU-safe kutter reload verified",
        "KOOKIE native kutter screen verified",
        "KOOKIE native main menu verified",
    )
    for marker in required:
        if marker not in log:
            return fail(f"missing runtime marker: {marker}")
    if "gpu-unavailable" in log:
        return fail("runtime reported gpu-unavailable")
    if marker_value(log, "gpu-window-screenshot-checksum") is None or \
            marker_value(log, "gpu-window-screenshot-checksum") <= 0:
        return fail("runtime reported an invalid screenshot checksum")
    if marker_value(log, "gpu-present-capabilities") is None or \
            marker_value(log, "gpu-present-capabilities") < 1:
        return fail("runtime reported no present capability")
    if marker_value(log, "gpu-draw-us") is None or \
            marker_value(log, "gpu-draw-us") <= 0:
        return fail("runtime reported no positive GPU draw time")
    if not ppm_path.is_file():
        return fail(f"missing screenshot artifact: {ppm_path}")
    ppm = ppm_path.read_bytes()
    dimensions = ppm_dimensions(ppm)
    if dimensions is None:
        return fail("screenshot is not an exact bounded P6 PPM")
    width, height = dimensions
    evidence = {
        "kind": "kookie-g1-authoritative-presentation",
        "status": "passed",
        "exitStatus": 0,
        "host": platform.node(),
        "os": platform.system(),
        "osRelease": platform.release(),
        "machine": platform.machine(),
        "hardwareId": hardware_id,
        "gpuDriver": gpu_driver,
        "videoDriver": os.environ.get("KOOKIE_SDL_VIDEO_DRIVER", ""),
        "displayServer": os.environ.get(
            "KOOKIE_PRESENTATION_DISPLAY_SERVER", ""
        ),
        "renderNode": os.environ.get("KOOKIE_RENDER_NODE", ""),
        "isolationWrapper": os.environ.get(
            "KOOKIE_PRESENTATION_ISOLATION_WRAPPER",
            "",
        ),
        "command": os.environ.get("KOOKIE_PRESENTATION_COMMAND", ""),
        "packageArchiveSha256": package_archive_sha,
        "packageManifestSha256": package_manifest_sha,
        "adapterLog": log_path.name,
        "adapterLogSha256": hashlib.sha256(log_bytes).hexdigest(),
        "screenshot": ppm_path.name,
        "screenshotWidth": width,
        "screenshotHeight": height,
        "screenshotSha256": hashlib.sha256(ppm).hexdigest(),
        "gpuWindowScreenshotChecksum": marker_value(
            log, "gpu-window-screenshot-checksum"
        ),
        "gpuPresentCapabilities": marker_value(
            log, "gpu-present-capabilities"
        ),
        "gpuDrawUs": marker_value(log, "gpu-draw-us"),
        "gpuSafeKutterReload": True,
        "kutterScreen": True,
    }
    if source_commit:
        evidence["sourceCommit"] = source_commit
    if evidence_path is not None:
        evidence_path.parent.mkdir(parents=True, exist_ok=True)
        evidence_path.write_text(
            json.dumps(evidence, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    print(json.dumps(evidence, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
