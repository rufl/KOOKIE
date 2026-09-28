#!/usr/bin/env python3
import hashlib
import json
import os
import platform
import sys
from pathlib import Path


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


def classify(log: str, requested_reason: str) -> str:
    if requested_reason:
        return requested_reason
    if "No DRI3 support detected" in log or "gpu-unavailable" in log:
        return "dri3-unavailable"
    if "offscreen" in log.lower():
        return "offscreen-video-driver"
    return "presentation-runtime-failed"


def drm_render_nodes():
    drm_directory = Path("/dev/dri")
    if not drm_directory.is_dir():
        return []
    return sorted(
        str(path)
        for path in drm_directory.glob("renderD*")
        if path.is_char_device()
    )


def main() -> int:
    if len(sys.argv) != 5:
        print(
            "usage: record_presentation_blocker.py LOG EVIDENCE_JSON EXIT_STATUS REASON",
            file=sys.stderr,
        )
        return 64
    log_path = Path(sys.argv[1])
    evidence_path = Path(sys.argv[2])
    try:
        exit_status = int(sys.argv[3])
    except ValueError:
        print("presentation blocker evidence: exit status must be an integer", file=sys.stderr)
        return 64
    requested_reason = sys.argv[4]
    log_bytes = log_path.read_bytes() if log_path.is_file() else b""
    log = log_bytes.decode("utf-8", errors="replace")
    evidence = {
        "kind": "kookie-g0-dri3-presentation-blocker",
        "status": "blocked",
        "reason": classify(log, requested_reason),
        "exitStatus": exit_status,
        "host": platform.node(),
        "os": platform.system(),
        "osRelease": platform.release(),
        "machine": platform.machine(),
        "videoDriver": os.environ.get("KOOKIE_SDL_VIDEO_DRIVER", ""),
        "renderNode": os.environ.get("KOOKIE_RENDER_NODE", ""),
        "renderNodeExists": (
            bool(os.environ.get("KOOKIE_RENDER_NODE"))
            and Path(os.environ["KOOKIE_RENDER_NODE"]).is_char_device()
        ),
        "drmRenderNodes": drm_render_nodes(),
        "display": os.environ.get("DISPLAY", ""),
        "waylandDisplay": os.environ.get("WAYLAND_DISPLAY", ""),
        "command": os.environ.get("KOOKIE_PRESENTATION_COMMAND", ""),
        "isolationWrapper": os.environ.get(
            "KOOKIE_PRESENTATION_ISOLATION_WRAPPER",
            "",
        ),
        "adapterLog": str(log_path),
        "adapterLogExists": log_path.is_file(),
        "adapterLogSha256": hashlib.sha256(log_bytes).hexdigest() if log_path.is_file() else "",
        "screenshot": os.environ.get("KOOKIE_SCREENSHOT_PATH", ""),
        "gpuUnavailable": "gpu-unavailable" in log,
        "dri3Unavailable": "No DRI3 support detected" in log,
        "gpuWindowScreenshotChecksum": marker_value(
            log, "gpu-window-screenshot-checksum"
        ),
        "presentCapabilities": marker_value(log, "gpu-present-capabilities"),
        "gpuDrawUs": marker_value(log, "gpu-draw-us"),
    }
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    evidence_path.write_text(
        json.dumps(evidence, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(evidence, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
