#!/usr/bin/env python3
"""Exercise external LAN key, manifest, and role-evidence boundaries."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
KEY = "0000000100000002000000030000000A"
CANONICAL_KEY = KEY.lower()
RUN_ID = "metadata-check-20250308"


def run_script(script: str, *args: str, env: dict[str, str], cwd: Path = ROOT):
    return subprocess.run(
        [sys.executable, str(ROOT / "scripts" / script), *args],
        cwd=cwd,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def assert_failed(result: subprocess.CompletedProcess[str], message: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"{message}: command unexpectedly passed")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="kookie-external-lan-metadata-") as raw:
        work = Path(raw)
        env = os.environ.copy()
        env.update(
            {
                "KOOKIE_TRANSPORT_KEY_HEX": KEY,
                "KOOKIE_EXTERNAL_LAN_RUN_ID": RUN_ID,
                "KOOKIE_EXTERNAL_LAN_SOURCE_REVISION": "test-revision",
                "KOOKIE_EXTERNAL_LAN_HOST_IPV4": "192.0.2.10",
            }
        )

        manifest_path = work / "run-manifest.json"
        result = run_script(
            "create_external_lan_run_manifest.py",
            str(manifest_path),
            RUN_ID,
            env=env,
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        expected_hash = hashlib.sha256(CANONICAL_KEY.encode("ascii")).hexdigest()
        assert manifest["transportKeySha256"] == expected_hash
        assert manifest["sourceRevision"] == "test-revision"

        zero_env = env | {"KOOKIE_TRANSPORT_KEY_HEX": "0" * 32}
        assert_failed(
            run_script(
                "create_external_lan_run_manifest.py",
                str(work / "zero-manifest.json"),
                RUN_ID,
                env=zero_env,
            ),
            "manifest all-zero key rejection",
        )

        missing_revision_env = env | {"KOOKIE_EXTERNAL_LAN_SOURCE_REVISION": ""}
        assert_failed(
            run_script(
                "create_external_lan_run_manifest.py",
                str(work / "missing-revision.json"),
                RUN_ID,
                env=missing_revision_env,
                cwd=work,
            ),
            "manifest source revision requirement",
        )

        log_path = work / "host.log"
        log_path.write_text("probe\n", encoding="utf-8")
        result = run_script(
            "record_external_lan_role_metadata.py",
            str(log_path),
            "host",
            "0",
            env=env,
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr)
        log = log_path.read_text(encoding="utf-8")
        assert f"external-role-key-sha256=host:{expected_hash}" in log
        assert "external-role-host-ipv4=host:192.0.2.10" in log

        assert_failed(
            run_script(
                "record_external_lan_role_metadata.py",
                str(work / "invalid-ip.log"),
                "host",
                "0",
                env=env | {"KOOKIE_EXTERNAL_LAN_HOST_IPV4": "localhost"},
            ),
            "role IPv4 literal requirement",
        )
        assert_failed(
            run_script(
                "record_external_lan_role_metadata.py",
                str(work / "zero-role.log"),
                "host",
                "0",
                env=zero_env,
            ),
            "role all-zero key rejection",
        )

        from validate_external_lan_evidence import read_run_manifest

        incomplete_manifest = work / "incomplete.json"
        incomplete_manifest.write_text(
            json.dumps(
                {
                    "kind": "kookie-g0-external-lan-run",
                    "version": 1,
                    "runId": RUN_ID,
                    "roles": ["host", "client-a", "client-b"],
                    "hostListenerPorts": [47101, 47102],
                    "transportKeySha256": expected_hash,
                    "sourceRevision": "",
                }
            ),
            encoding="utf-8",
        )
        _, _, error = read_run_manifest(
            str(incomplete_manifest), RUN_ID, expected_hash
        )
        assert error == "run manifest source revision is missing"

    print("KOOKIE external LAN metadata boundaries verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
