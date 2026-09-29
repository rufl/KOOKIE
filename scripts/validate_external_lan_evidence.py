#!/usr/bin/env python3
import hashlib
import ipaddress
import json
import os
import platform
import re
import sys
from pathlib import Path


def fail(message: str) -> int:
    print(f"external LAN evidence failed: {message}", file=sys.stderr)
    return 1


def marker_value(lines, marker: str):
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


RUN_ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{7,127}")
ROLE_NAMES = ("host", "client-a", "client-b")


def role_marker_values(lines, marker: str):
    values = {}
    duplicates = set()
    prefix = f"{marker}="
    for line in lines:
        if not line.startswith(prefix):
            continue
        role, separator, value = line[len(prefix):].partition(":")
        if role not in ROLE_NAMES or not separator or not value:
            continue
        if role in values:
            duplicates.add(role)
        values[role] = value
    return values, duplicates


def is_sha256(value: str) -> bool:
    return len(value) == 64 and all(
        character in "0123456789abcdef" for character in value
    )


def is_run_id(value: str) -> bool:
    return RUN_ID_PATTERN.fullmatch(value) is not None


def read_run_manifest(
    manifest_text: str, run_id: str, key_hash: str
):
    if not manifest_text:
        return None, None, ""
    path = Path(manifest_text)
    if not path.is_file():
        return None, None, f"missing run manifest: {path}"
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None, None, f"invalid run manifest: {path}"
    if manifest.get("kind") != "kookie-g0-external-lan-run":
        return None, None, "run manifest kind is invalid"
    if manifest.get("version") != 1:
        return None, None, "run manifest version is invalid"
    if manifest.get("runId") != run_id:
        return None, None, "run manifest run ID does not match role logs"
    if manifest.get("roles") != list(ROLE_NAMES):
        return None, None, "run manifest roles are invalid"
    if manifest.get("hostListenerPorts") != [47101, 47102]:
        return None, None, "run manifest listener ports are invalid"
    if manifest.get("transportKeySha256") != key_hash:
        return None, None, "run manifest key fingerprint does not match evidence"
    return path, manifest, ""


def main() -> int:
    if len(sys.argv) != 3:
        return fail("usage: validate_external_lan_evidence.py LOG EVIDENCE_JSON")
    log_path = Path(sys.argv[1])
    evidence_path = Path(sys.argv[2])
    if not log_path.is_file():
        return fail(f"missing probe log: {log_path}")
    output = log_path.read_bytes()
    log = output.decode("utf-8", errors="replace")
    lines = log.splitlines()
    topology = os.environ.get(
        "KOOKIE_EXTERNAL_LAN_TOPOLOGY", "same-host-external-style")
    required = (
        "external-gameplay",
        "external-combat-death",
        "external-arena-triangles",
        "external-combat-reward",
        "external-enemy-encounter",
        "external-enemy-state",
        "external-enemy-health",
        "external-impact-sequence",
        "external-player-position",
        "external-reconnect-generation",
        "external-stale-diagnostic",
        "external-host-reconnect",
        "external-authenticated-two-clients",
        "external-stale-rejection",
        "external-authentication-status",
        "external-transport-sequence-a",
        "external-transport-sequence-b",
        "external-player-authority-kind",
        "external-world-loot-kind",
        "external-client-g3-item",
        "external-client-g3-equipment",
        "external-client-g3-skill-rank",
        "external-client-g3-world-loot-count",
        "KOOKIE external-style authenticated host/two-client transport verified",
    )
    for marker in required:
        if marker not in log:
            return fail(f"missing runtime marker: {marker}")
    if topology == "same-host-multi-process":
        for marker in (
            "external-role-processes",
            "external-role-host",
            "external-role-client-a",
            "external-role-client-b",
        ):
            if marker not in log:
                return fail(f"missing multi-process role marker: {marker}")
    host_port_a = marker_value(lines, "external-host-port-a")
    host_port_b = marker_value(lines, "external-host-port-b")
    combat_damage = marker_value(lines, "external-combat-damage")
    combat_death = marker_value(lines, "external-combat-death")
    arena_triangles = marker_value(lines, "external-arena-triangles")
    combat_reward = marker_value(lines, "external-combat-reward")
    player_position = marker_value(lines, "external-player-position")
    enemy_encounter_active = marker_value(
        lines, "external-enemy-encounter")
    enemy_state = marker_value(lines, "external-enemy-state")
    enemy_health = marker_value(lines, "external-enemy-health")
    impact_sequence = marker_value(lines, "external-impact-sequence")
    reconnect_generation = marker_value(
        lines, "external-reconnect-generation")
    stale_diagnostic = marker_value(lines, "external-stale-diagnostic")
    interaction_revision = marker_value(lines, "external-interaction-revision")
    authentication_status = marker_value(
        lines, "external-authentication-status")
    transport_sequence_a = marker_value(
        lines, "external-transport-sequence-a")
    transport_sequence_b = marker_value(
        lines, "external-transport-sequence-b")
    player_authority_kind = marker_value(
        lines, "external-player-authority-kind")
    world_loot_kind = marker_value(lines, "external-world-loot-kind")
    g3_item = marker_value(lines, "external-client-g3-item")
    g3_equipment = marker_value(
        lines, "external-client-g3-equipment")
    g3_skill_rank = marker_value(
        lines, "external-client-g3-skill-rank")
    g3_world_loot_count = marker_value(
        lines, "external-client-g3-world-loot-count")
    if host_port_a is None or not 1 <= host_port_a <= 65535:
        return fail("invalid host listener port A")
    if host_port_b is None or not 1 <= host_port_b <= 65535:
        return fail("invalid host listener port B")
    if combat_damage is None or combat_damage <= 0:
        return fail("server-owned combat damage was not positive")
    if combat_death != 1:
        return fail("server-owned combat death was not terminal")
    if arena_triangles != 26:
        return fail("complete authored arena did not traverse transport")
    if combat_reward != 25:
        return fail("server-owned combat reward was not replicated")
    if enemy_encounter_active != 0:
        return fail("replicated enemy encounter did not reach terminal state")
    if enemy_state != 7:
        return fail("replicated enemy state was not terminal")
    if enemy_health != 0:
        return fail("replicated enemy health was not zero")
    if impact_sequence is None or impact_sequence < 2:
        return fail("latest confirmed enemy impact did not replicate")
    if player_position != 2:
        return fail("authoritative player movement was not replicated")
    if reconnect_generation != 2:
        return fail("reconnect generation was not diagnosed")
    if stale_diagnostic != 6:
        return fail("stale command diagnostic was not explicit")
    if interaction_revision != 4:
        return fail("key-door-secret-exit revision was not 4")
    if authentication_status != 1:
        return fail("authenticated transport status was not passed")
    if transport_sequence_a is None or transport_sequence_a <= 0:
        return fail("missing positive transport sequence for client A")
    if transport_sequence_b is None or transport_sequence_b <= 0:
        return fail("missing positive transport sequence for client B")
    if player_authority_kind != 7:
        return fail("player-authority state kind 7 did not traverse transport")
    if world_loot_kind != 8:
        return fail("world-loot state kind 8 did not traverse transport")
    if g3_item != 900:
        return fail("authoritative picked-up item did not reach client A")
    if g3_equipment != 900:
        return fail("authoritative equipment did not reach client A")
    if g3_skill_rank != 1:
        return fail("authoritative skill rank did not reach client A")
    if g3_world_loot_count != 0:
        return fail("picked-up world loot did not disappear for client A")
    key_hex = os.environ.get("KOOKIE_TRANSPORT_KEY_HEX", "")
    if len(key_hex) != 32:
        return fail("transport key evidence is not a 32-character boundary")
    try:
        bytes.fromhex(key_hex)
    except ValueError:
        return fail("transport key evidence is not hexadecimal")
    expected_key_hash = hashlib.sha256(key_hex.encode("ascii")).hexdigest()
    process_exit_statuses = {}
    if topology in ("same-host-multi-process", "separate-hosts"):
        for role in ROLE_NAMES:
            status = marker_value(
                lines, f"external-{role}-exit-status")
            if status is None:
                return fail(f"missing {role} process exit status")
            process_exit_statuses[role] = status
    else:
        status = marker_value(lines, "external-process-exit-status")
        if status is None:
            return fail("missing single-process exit status")
        process_exit_statuses["single"] = status
    if any(status != 0 for status in process_exit_statuses.values()):
        return fail("one or more qualification processes exited non-zero")

    role_identities = {}
    role_machine_fingerprints = {}
    role_key_hashes = {}
    role_host_ipv4 = {}
    role_run_ids = {}
    run_id = os.environ.get("KOOKIE_EXTERNAL_LAN_RUN_ID", "").strip()
    run_manifest_path = None
    run_manifest = None
    external_host_execution = "unproven"
    if topology in ("same-host-multi-process", "separate-hosts"):
        role_identities, identity_duplicates = role_marker_values(
            lines, "external-role-identity")
        role_machine_fingerprints, machine_duplicates = role_marker_values(
            lines, "external-role-machine-fingerprint")
        role_key_hashes, key_duplicates = role_marker_values(
            lines, "external-role-key-sha256")
        role_host_ipv4, host_ipv4_duplicates = role_marker_values(
            lines, "external-role-host-ipv4")
        role_run_ids, run_id_duplicates = role_marker_values(
            lines, "external-role-run-id")
        for role in ROLE_NAMES:
            if role in identity_duplicates:
                return fail(f"duplicate identity marker for {role}")
            if role in machine_duplicates:
                return fail(f"duplicate machine fingerprint for {role}")
            if role in key_duplicates:
                return fail(f"duplicate key fingerprint for {role}")
            if role in run_id_duplicates:
                return fail(f"duplicate run ID marker for {role}")
            if role in host_ipv4_duplicates:
                return fail(f"duplicate host IPv4 marker for {role}")
            if role not in role_identities:
                return fail(f"missing identity marker for {role}")
            if role not in role_run_ids:
                return fail(f"missing run ID marker for {role}")
            if not is_run_id(role_run_ids[role]):
                return fail(f"invalid run ID marker for {role}")
            if role not in role_machine_fingerprints:
                return fail(f"missing machine fingerprint for {role}")
            if not is_sha256(role_machine_fingerprints[role]):
                return fail(f"invalid machine fingerprint for {role}")
            if role not in role_key_hashes:
                return fail(f"missing key fingerprint for {role}")
            if role not in role_host_ipv4:
                return fail(f"missing host IPv4 marker for {role}")
            try:
                if ipaddress.ip_address(role_host_ipv4[role]).version != 4:
                    return fail(f"host IPv4 marker for {role} is not IPv4")
            except ValueError:
                return fail(f"invalid host IPv4 marker for {role}")
        run_id_values = set(role_run_ids.values())
        if len(run_id_values) != 1:
            return fail("role logs do not share one run ID")
        log_run_id = next(iter(run_id_values))
        if run_id and run_id != log_run_id:
            return fail("KOOKIE_EXTERNAL_LAN_RUN_ID does not match role logs")
        run_id = log_run_id
        if any(
            role_key_hashes[role] != expected_key_hash
            for role in ROLE_NAMES
        ):
            return fail("role key fingerprints do not match the supplied key")
        if topology == "separate-hosts":
            if len(set(role_machine_fingerprints.values())) != len(ROLE_NAMES):
                return fail(
                    "separate-hosts evidence requires three distinct machine fingerprints"
                )
            external_host_execution = "proven"
    manifest_text = os.environ.get("KOOKIE_EXTERNAL_LAN_RUN_MANIFEST", "").strip()
    if topology == "separate-hosts" and not manifest_text:
        return fail("separate-hosts evidence requires a run manifest")
    run_manifest_path, run_manifest, manifest_error = read_run_manifest(
        manifest_text, run_id, expected_key_hash
    )
    if manifest_error:
        return fail(manifest_error)
    host_identity = (
        os.environ.get("KOOKIE_EXTERNAL_LAN_HOST_IDENTITY", "").strip()
        or role_identities.get("host", "")
        or platform.node()
    )
    client_identity_text = os.environ.get(
        "KOOKIE_EXTERNAL_LAN_CLIENT_IDENTITIES", "")
    client_identities = [
        identity.strip()
        for identity in client_identity_text.split(",")
        if identity.strip()
    ]
    if not client_identities:
        client_identities = [
            role_identities.get("client-a", ""),
            role_identities.get("client-b", ""),
        ]
        client_identities = [identity for identity in client_identities if identity]
    if not client_identities:
        client_identities = [host_identity, host_identity]
    if client_identity_text and len(client_identities) != 2:
        return fail("external LAN evidence requires two client identities")
    evidence = {
        "kind": "kookie-g0-external-lan",
        "status": "passed",
        "topology": topology,
        "externalHostExecution": external_host_execution,
        "runId": run_id,
        "runManifest": str(run_manifest_path) if run_manifest_path else "",
        "runManifestSha256": (
            hashlib.sha256(run_manifest_path.read_bytes()).hexdigest()
            if run_manifest_path
            else ""
        ),
        "runManifestSourceRevision": (
            run_manifest.get("sourceRevision", "") if run_manifest else ""
        ),
        "hostIdentity": host_identity,
        "clientIdentities": client_identities,
        "roleIdentities": role_identities,
        "roleMachineFingerprints": role_machine_fingerprints,
        "roleKeySha256": role_key_hashes,
        "roleHostIpv4": role_host_ipv4,
        "os": platform.system(),
        "osRelease": platform.release(),
        "machine": platform.machine(),
        "authenticatedClientCount": 2,
        "authenticationStatus": "passed",
        "hostListenerPorts": [host_port_a, host_port_b],
        "transportSequences": {
            "clientA": transport_sequence_a,
            "clientB": transport_sequence_b,
        },
        "processExitStatuses": process_exit_statuses,
        "combatDamage": combat_damage,
        "combatDeath": combat_death == 1,
        "arenaTriangleCount": arena_triangles,
        "combatReward": combat_reward,
        "enemyEncounterActive": enemy_encounter_active,
        "enemyState": enemy_state,
        "enemyHealth": enemy_health,
        "impactSequence": impact_sequence,
        "playerPosition": player_position,
        "reconnectGeneration": reconnect_generation,
        "staleDiagnostic": stale_diagnostic,
        "interactionRevision": interaction_revision,
        "g3Replication": {
            "playerAuthorityKind": player_authority_kind,
            "worldLootKind": world_loot_kind,
            "itemId": g3_item,
            "equipmentItemId": g3_equipment,
            "skillRank": g3_skill_rank,
            "worldLootCountAfterPickup": g3_world_loot_count,
        },
        "transportKeySha256": hashlib.sha256(key_hex.encode("ascii")).hexdigest(),
        "probeLog": str(log_path),
        "probeOutputSha256": hashlib.sha256(output).hexdigest(),
        "command": os.environ.get("KOOKIE_EXTERNAL_LAN_COMMAND", ""),
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
