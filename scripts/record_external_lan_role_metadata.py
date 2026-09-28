#!/usr/bin/env python3
import hashlib
import json
import os
import platform
import re
import socket
import sys
from pathlib import Path

ROLES = {"host", "client-a", "client-b"}
RUN_ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{7,127}")


def fail(message: str) -> int:
    print(f"external LAN role metadata failed: {message}", file=sys.stderr)
    return 1


def machine_fingerprint(hostname: str) -> str:
    machine_id = ""
    for candidate in ("/etc/machine-id", "/var/lib/dbus/machine-id"):
        path = Path(candidate)
        if not path.is_file():
            continue
        machine_id = path.read_text(encoding="utf-8", errors="replace").strip()
        if machine_id:
            break
    source = machine_id or "|".join(
        (hostname, platform.system(), platform.release(), platform.machine())
    )
    return hashlib.sha256(f"kookie-machine:{source}".encode("utf-8")).hexdigest()


def main() -> int:
    if len(sys.argv) != 4:
        return fail(
            "usage: record_external_lan_role_metadata.py LOG ROLE EXIT_STATUS"
        )
    log_path = Path(sys.argv[1])
    role = sys.argv[2]
    if role not in ROLES:
        return fail(f"unsupported role: {role}")
    try:
        exit_status = int(sys.argv[3])
    except ValueError:
        return fail("exit status must be an integer")
    if not log_path.is_file():
        return fail(f"missing role log: {log_path}")

    run_id = os.environ.get("KOOKIE_EXTERNAL_LAN_RUN_ID", "").strip()
    if not RUN_ID_PATTERN.fullmatch(run_id):
        return fail(
            "KOOKIE_EXTERNAL_LAN_RUN_ID must be 8-128 safe identifier characters"
        )

    key_hex = os.environ.get("KOOKIE_TRANSPORT_KEY_HEX", "")
    if len(key_hex) != 32:
        return fail("KOOKIE_TRANSPORT_KEY_HEX must be 32 characters")
    try:
        bytes.fromhex(key_hex)
    except ValueError:
        return fail("KOOKIE_TRANSPORT_KEY_HEX must be hexadecimal")
    hostname = socket.gethostname().strip() or platform.node().strip() or "unknown"
    machine_digest = machine_fingerprint(hostname)
    key_digest = hashlib.sha256(key_hex.encode("ascii")).hexdigest()
    host_ipv4 = os.environ.get("KOOKIE_EXTERNAL_LAN_HOST_IPV4", "127.0.0.1")
    lines = (
        f"external-role-run-id={role}:{run_id}\n",
        f"external-role-identity={role}:{hostname}\n",
        f"external-role-machine-fingerprint={role}:{machine_digest}\n",
        f"external-role-key-sha256={role}:{key_digest}\n",
        f"external-role-host-ipv4={role}:{host_ipv4}\n",
        f"external-{role}-exit-status\n{exit_status}\n",
    )
    with log_path.open("a", encoding="utf-8") as stream:
        stream.writelines(lines)
    print(
        json.dumps(
            {
                "role": role,
                "runId": run_id,
                "manifest": os.environ.get("KOOKIE_EXTERNAL_LAN_RUN_MANIFEST", ""),
                "hostname": hostname,
                "machineFingerprint": machine_digest,
                "keySha256": key_digest,
                "hostIpv4": host_ipv4,
                "exitStatus": exit_status,
                "log": str(log_path),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
