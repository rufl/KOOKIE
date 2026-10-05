#!/usr/bin/env python3
import hashlib
import json
import re
import sys
import tarfile
import tempfile
from pathlib import Path


EXPECTED_FILES = {
    "evidence/SHA256SUMS",
    "evidence/run-manifest.json",
    "evidence/host.log",
    "evidence/client-a.log",
    "evidence/client-b.log",
    "evidence/external-lan-combined.log",
    "evidence/evidence.json",
}
ROLES = ("host", "client-a", "client-b")
EXPECTED_ARENA_TRIANGLES = 178


RUN_ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{7,127}")


def is_sha256(value) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(
        character in "0123456789abcdef" for character in value
    )


def fail(message: str) -> int:
    print(f"external LAN evidence bundle failed: {message}", file=sys.stderr)
    return 1


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def verify_checksums(root: Path) -> str:
    checksum_path = root / "evidence/SHA256SUMS"
    expected = {}
    for line in checksum_path.read_text(encoding="utf-8").splitlines():
        fields = line.split(maxsplit=1)
        if len(fields) != 2 or not is_sha256(fields[0]):
            return "invalid SHA256SUMS line"
        if fields[1] in expected:
            return "duplicate SHA256SUMS entry"
        expected[fields[1]] = fields[0]
    expected_names = {
        name.removeprefix("evidence/")
        for name in EXPECTED_FILES
        if name != "evidence/SHA256SUMS"
    }
    if set(expected) != expected_names:
        return "SHA256SUMS does not cover the expected files"
    for name, digest in expected.items():
        actual = sha256(root / "evidence" / name)
        if actual != digest:
            return f"checksum mismatch: {name}"
    return ""


def verify_bundle(bundle_path: Path) -> tuple[dict | None, str]:
    if not bundle_path.is_file():
        return None, f"missing bundle: {bundle_path}"
    with tempfile.TemporaryDirectory(prefix="kookie-lan-bundle-verify-") as temp:
        root = Path(temp)
        try:
            with tarfile.open(bundle_path, "r:gz") as archive:
                names = set()
                for member in archive.getmembers():
                    name = member.name.rstrip("/")
                    if name == "" or name == "evidence":
                        continue
                    if name not in EXPECTED_FILES or not member.isfile():
                        return None, f"unexpected bundle member: {member.name}"
                    if name in names:
                        return None, f"duplicate bundle member: {member.name}"
                    names.add(name)
                if names != EXPECTED_FILES:
                    return None, "bundle file set is incomplete"
                archive.extractall(root)
        except (OSError, tarfile.TarError) as error:
            return None, f"invalid tarball: {error}"

        checksum_error = verify_checksums(root)
        if checksum_error:
            return None, checksum_error
        manifest = load_json(root / "evidence/run-manifest.json")
        evidence = load_json(root / "evidence/evidence.json")
        if manifest is None or evidence is None:
            return None, "manifest or evidence JSON is invalid"
        if manifest.get("kind") != "kookie-g0-external-lan-run":
            return None, "manifest kind is invalid"
        if manifest.get("version") != 1:
            return None, "manifest version is invalid"
        if manifest.get("roles") != list(ROLES):
            return None, "manifest role set is invalid"
        run_id = manifest.get("runId", "")
        if not isinstance(run_id, str) or RUN_ID_PATTERN.fullmatch(run_id) is None:
            return None, "manifest run ID is invalid"
        if evidence.get("kind") != "kookie-g0-external-lan":
            return None, "evidence kind is invalid"
        if evidence.get("status") != "passed":
            return None, "evidence status is not passed"
        if evidence.get("topology") != "separate-hosts":
            return None, "evidence topology is not separate-hosts"
        if evidence.get("externalHostExecution") != "proven":
            return None, "evidence does not prove external-host execution"
        if evidence.get("runId") != run_id:
            return None, "evidence run ID does not match manifest"
        manifest_hash = sha256(root / "evidence/run-manifest.json")
        if evidence.get("runManifestSha256") != manifest_hash:
            return None, "evidence manifest hash does not match bundle manifest"
        manifest_key_hash = manifest.get("transportKeySha256")
        if not is_sha256(manifest_key_hash):
            return None, "manifest key hash is invalid"
        if evidence.get("transportKeySha256") != manifest_key_hash:
            return None, "evidence key hash does not match manifest"
        role_keys = evidence.get("roleKeySha256")
        if not isinstance(role_keys, dict) or set(role_keys) != set(ROLES):
            return None, "evidence role key hashes are incomplete"
        if any(not is_sha256(role_keys[role]) for role in ROLES):
            return None, "evidence role key hash is invalid"
        if set(role_keys.values()) != {manifest_key_hash}:
            return None, "role key hashes do not match manifest"
        machine_fingerprints = evidence.get("roleMachineFingerprints")
        if not isinstance(machine_fingerprints, dict) or set(machine_fingerprints) != set(ROLES):
            return None, "evidence machine fingerprints are incomplete"
        if any(
            not is_sha256(machine_fingerprints[role]) for role in ROLES
        ):
            return None, "evidence machine fingerprint is invalid"
        if len(set(machine_fingerprints.values())) != len(ROLES):
            return None, "evidence machine fingerprints are not distinct"
        if evidence.get("authenticationStatus") != "passed":
            return None, "authentication evidence is not passed"
        if evidence.get("authenticatedClientCount") != 2:
            return None, "authenticated client count is not two"
        if evidence.get("interactionRevision") != 4:
            return None, "interaction revision is not complete"
        if not isinstance(evidence.get("combatDamage"), int) or evidence["combatDamage"] <= 0:
            return None, "combat damage evidence is not positive"
        if evidence.get("combatDeath") is not True:
            return None, "combat death evidence is not terminal"
        if evidence.get("arenaTriangleCount") != EXPECTED_ARENA_TRIANGLES:
            return None, "authored arena evidence is incomplete"
        if evidence.get("combatReward") != 25:
            return None, "combat reward evidence is incomplete"
        if evidence.get("playerPosition") != 2:
            return None, "authoritative movement evidence is incomplete"
        if evidence.get("reconnectGeneration") != 2:
            return None, "reconnect generation evidence is incomplete"
        if evidence.get("staleDiagnostic") != 6:
            return None, "stale diagnostic evidence is incomplete"
        sequences = evidence.get("transportSequences")
        if not isinstance(sequences, dict) or any(
            not isinstance(sequences.get(name), int) or sequences[name] <= 0
            for name in ("clientA", "clientB")
        ):
            return None, "transport sequence evidence is incomplete"
        process_statuses = evidence.get("processExitStatuses")
        if not isinstance(process_statuses, dict) or any(
            process_statuses.get(role) != 0 for role in ROLES
        ):
            return None, "process exit evidence is not clean"
        combined_log_hash = sha256(root / "evidence/external-lan-combined.log")
        if evidence.get("probeOutputSha256") != combined_log_hash:
            return None, "combined log hash does not match evidence"
        return {
            "bundle": str(bundle_path),
            "bundleSha256": sha256(bundle_path),
            "runId": run_id,
            "sourceRevision": manifest.get("sourceRevision", ""),
            "status": "verified",
        }, ""


def main() -> int:
    if len(sys.argv) != 2:
        return fail("usage: verify_external_lan_evidence_bundle.py BUNDLE_TAR_GZ")
    summary, error = verify_bundle(Path(sys.argv[1]))
    if error:
        return fail(error)
    print(json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
