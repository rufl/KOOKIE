#!/usr/bin/env python3
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path


RUN_ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{7,127}")


def fail(message: str) -> int:
    print(f"external LAN run manifest failed: {message}", file=sys.stderr)
    return 1


def source_revision() -> str:
    configured = os.environ.get("KOOKIE_EXTERNAL_LAN_SOURCE_REVISION", "").strip()
    if configured:
        return configured
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def main() -> int:
    if len(sys.argv) not in (2, 3):
        return fail(
            "usage: create_external_lan_run_manifest.py OUTPUT_JSON [RUN_ID]"
        )
    manifest_path = Path(sys.argv[1])
    run_id = sys.argv[2] if len(sys.argv) == 3 else uuid.uuid4().hex
    if not RUN_ID_PATTERN.fullmatch(run_id):
        return fail("RUN_ID must be 8-128 safe identifier characters")

    key_hex = os.environ.get("KOOKIE_TRANSPORT_KEY_HEX", "")
    if len(key_hex) != 32:
        return fail("KOOKIE_TRANSPORT_KEY_HEX must be 32 characters")
    try:
        key_bytes = bytes.fromhex(key_hex)
    except ValueError:
        return fail("KOOKIE_TRANSPORT_KEY_HEX must be hexadecimal")
    if not any(key_bytes):
        return fail("KOOKIE_TRANSPORT_KEY_HEX must not be all zero")
    canonical_key_hex = key_bytes.hex()
    revision = source_revision()
    if not revision:
        return fail("source revision is unavailable")

    manifest = {
        "kind": "kookie-g0-external-lan-run",
        "version": 1,
        "runId": run_id,
        "roles": ["host", "client-a", "client-b"],
        "hostListenerPorts": [47101, 47102],
        "transportKeySha256": hashlib.sha256(
            canonical_key_hex.encode("ascii")
        ).hexdigest(),
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "sourceRevision": revision,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"export KOOKIE_EXTERNAL_LAN_RUN_ID={shlex.quote(run_id)}")
    print(
        "export KOOKIE_EXTERNAL_LAN_RUN_MANIFEST="
        f"{shlex.quote(str(manifest_path))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
