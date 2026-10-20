#!/usr/bin/env python3
"""Bounded local WebSocket session gateway for the KofJS browser probe.

This process terminates a browser WebSocket, validates the bounded Kof session
handshake, and answers heartbeat/game-plane probe frames. It is deliberately a
local qualification gateway: TLS termination and token authentication are
optional qualification controls; authoritative production operations remain
outside this script.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import math
import os
import socket
import ssl
import stat
import struct

from dataclasses import dataclass, field

MAGIC = b"KWS1"
FRAME_VERSION = 1
NETCODE_PROTOCOL_VERSION = 2
MAX_WORDS = 272
MAX_FRAME_BYTES = 16 + MAX_WORDS * 4
MAX_HTTP_HEADER_BYTES = 8192
MAX_WEBSOCKET_PAYLOAD_BYTES = MAX_FRAME_BYTES
MAX_SEQUENCE = 1_000_000

HELLO = 1
ACK = 2
PING = 3
PONG = 4
ERROR = 5
GAME = 6

CLIENT_TARGET_BROWSER = 1
AUTHORITY_REMOTE = 1
GAME_WEBSOCKET = 1
BROWSER_CAPABILITY = 1
SERVER_CAPABILITY = 1

WEBSOCKET_SUBPROTOCOL = "kookie.v1"
AUTH_SUBPROTOCOL_PREFIX = "bearer."
AUTH_TOKEN_MINIMUM_LENGTH = 8
AUTH_TOKEN_MAXIMUM_LENGTH = 128
SESSION_ROUTE = "/session"
HEALTH_ROUTE = "/healthz"
METRICS_ROUTE = "/metrics"

GAME_PROBE_PAYLOAD = 7127
GAME_COMMAND_MARKER = 1
GAME_SNAPSHOT_MARKER = 2
GAME_SCENE_SNAPSHOT_MARKER = 3
GAME_FULL_SCENE_SNAPSHOT_MARKER = 4
GAME_MOVE_LEFT = 1
GAME_MOVE_RIGHT = 2
GAME_MELEE = 3
GAME_SPECIAL = 4
GAME_RESET = 5
GAME_SCENE_PROBE = 6
GAME_FULL_SCENE_PROBE = 7
GAME_MOVE_FORWARD = 8
GAME_MOVE_BACK = 9
GAME_STRAFE_LEFT = 10
GAME_STRAFE_RIGHT = 11
GAME_LOOK_LEFT = 12
GAME_LOOK_RIGHT = 13
GAME_FIRE = 14
GAME_JUMP = 15
GAME_MINIMUM_POSITION = -100
GAME_MAXIMUM_POSITION = 100
GAME_MINIMUM_DEPTH = -60
GAME_MAXIMUM_DEPTH = 60
GAME_WORLD_MINIMUM_X = 4
GAME_WORLD_MAXIMUM_X = 316
GAME_WORLD_MINIMUM_Y = 1
GAME_WORLD_MAXIMUM_Y = 20
GAME_WORLD_MINIMUM_Z = 4
GAME_WORLD_MAXIMUM_Z = 276
GAME_MAXIMUM_TICK = 10_000_000
GAME_MAXIMUM_HEALTH = 100
GAME_MAXIMUM_STAMINA = 100
GAME_MAXIMUM_AMMO = 99
GAME_MAXIMUM_COMBO = 1_000_000
GAME_MAXIMUM_VFX = 15
GAME_VFX_MELEE = 5
GAME_VFX_FIRE = 6
GAME_VFX_SPECIAL = 8
GAME_VFX_JUMP = 13
GAME_VFX_HIT = 15
GAME_VFX_DEATH = 12
GAME_VFX_LIQUID = 14
GAME_LIQUID_BOUNDS = (
    (96, 224, 96, 208, 5),
    (232, 304, 32, 112, 4),
)
GAME_MOVEMENT_GROUND_ACCELERATION = 3
GAME_MOVEMENT_AIR_ACCELERATION = 1
GAME_MOVEMENT_GROUND_BRAKING = 2
GAME_MOVEMENT_AIR_BRAKING = 1
GAME_MOVEMENT_GRAVITY = 1
GAME_MOVEMENT_JUMP_VELOCITY = 9
GAME_MOVEMENT_MAX_FALL_SPEED = 16
GAME_MOVEMENT_COYOTE_TICKS = 6
GAME_MOVEMENT_JUMP_BUFFER_TICKS = 6
GAME_MOVEMENT_MAXIMUM_AIR_JUMPS = 1
GAME_MOVEMENT_RADIUS = 2
GAME_MOVEMENT_HEIGHT = 4
GAME_MOVEMENT_BOXES = (
    (92, 6, 146, 228, 9, 158),
    (154, 6, 92, 166, 9, 212),
    (228, 6, 66, 308, 9, 78),
    (36, 8, 64, 96, 11, 216),
    (224, 8, 64, 284, 11, 216),
    (48, 16, 16, 272, 18, 48),
    (48, 16, 232, 272, 18, 264),
    (64, 0, 112, 88, 14, 136),
    (232, 0, 144, 256, 14, 168),
    (112, 0, 72, 132, 5, 92),
    (188, 0, 184, 208, 5, 204),
)
GAME_MOVEMENT_RAMPS = (
    (20, 0, 56, 40, 8, 80),
    (280, 8, 200, 300, 0, 224),
)

GAME_LEGACY_ACTORS = 3
GAME_FULL_ACTORS = 4
GAME_MAXIMUM_PROJECTILES = 1
GAME_MAXIMUM_PICKUP_KIND = 6
GAME_SCENE_OBJECT_ENTRY_WIDTH = 9
GAME_SCENE_LABEL_ENTRY_WIDTH = 6
GAME_SCENE_OBJECTS_OFFSET = 69
GAME_MAXIMUM_SCENE_OBJECTS = 17
GAME_MAXIMUM_SCENE_LABELS = 8
GAME_SCENE_OBJECT_DOOR = 1
GAME_SCENE_OBJECT_FLOATABLE = 2
GAME_SCENE_OBJECT_POWERUP = 3
GAME_SCENE_OBJECT_LOOT_BEAM = 4
GAME_STATIC_SCENE_OBJECTS = (
    (GAME_SCENE_OBJECT_DOOR, 2, 0, 5, 5, 5, 3, 5, 1),
    (GAME_SCENE_OBJECT_FLOATABLE, 1, 1, 150, 9, 140, 2, 2, 2),
    (GAME_SCENE_OBJECT_FLOATABLE, 2, 0, 180, 9, 150, 2, 2, 2),
    (GAME_SCENE_OBJECT_POWERUP, 1, 1, 32, 1, 52, 2, 2, 2),
    (GAME_SCENE_OBJECT_POWERUP, 2, 1, 72, 1, 64, 3, 3, 3),
    (GAME_SCENE_OBJECT_POWERUP, 3, 1, 120, 1, 96, 2, 2, 2),
    (GAME_SCENE_OBJECT_POWERUP, 4, 1, 150, 5, 140, 3, 3, 3),
    (GAME_SCENE_OBJECT_POWERUP, 5, 1, 260, 1, 60, 2, 2, 2),
    (GAME_SCENE_OBJECT_POWERUP, 6, 1, 200, 1, 120, 2, 2, 2),
)


class ProtocolError(ValueError):
    """The peer sent a frame outside the bounded session contract."""



class HttpUpgradeError(Exception):
    def __init__(self, status: int, reason: str):
        super().__init__(reason)
        self.status = status
        self.reason = reason


def valid_auth_token(token: str) -> bool:
    return (
        AUTH_TOKEN_MINIMUM_LENGTH <= len(token) <= AUTH_TOKEN_MAXIMUM_LENGTH
        and all(
            ord(character) < 128 and
            (character.isalnum() or character in "._~-")
            for character in token
        )
    )

def auth_source(
    auth_token: str | None, auth_token_file: str | None
) -> str:
    if auth_token_file is not None:
        return "file"
    if auth_token is not None:
        return "flag"
    return "none"


def load_auth_token(path: str) -> str:
    try:
        mode = os.stat(path).st_mode
        if not stat.S_ISREG(mode) or stat.S_IMODE(mode) & 0o077:
            raise OSError("credential file permissions")
        with open(path, "rb") as stream:
            raw = stream.read(AUTH_TOKEN_MAXIMUM_LENGTH + 2)
            if stream.read(1):
                raise OSError("credential file is too large")
    except (OSError, ValueError) as error:
        raise HttpUpgradeError(503, "Service Unavailable") from error
    if raw.endswith(b"\n"):
        raw = raw[:-1]
        if raw.endswith(b"\r"):
            raw = raw[:-1]
    try:
        token = raw.decode("ascii")
    except UnicodeDecodeError as error:
        raise HttpUpgradeError(503, "Service Unavailable") from error
    if not valid_auth_token(token):
        raise HttpUpgradeError(503, "Service Unavailable")
    return token



@dataclass
class GatewayMetrics:
    upgrade_attempts: int = 0
    upgrade_rejections: int = 0
    auth_rejections: int = 0
    websocket_sessions: int = 0
    active_sessions: int = 0
    received_frames: int = 0
    applied_commands: int = 0
    health_requests: int = 0
    metrics_requests: int = 0

    def health_payload(
        self, transport: str, credential_source: str
    ) -> dict[str, object]:
        return {
            "status": "ok",
            "protocol": WEBSOCKET_SUBPROTOCOL,
            "transport": transport,
            "auth_required": credential_source != "none",
            "auth_source": credential_source,
            "active_sessions": self.active_sessions,
        }

    def metrics_text(self, transport: str, credential_source: str) -> str:
        values = (
            ("upgrade_attempts", self.upgrade_attempts),
            ("upgrade_rejections", self.upgrade_rejections),
            ("auth_rejections", self.auth_rejections),
            ("websocket_sessions", self.websocket_sessions),
            ("received_frames", self.received_frames),
            ("applied_commands", self.applied_commands),
            ("health_requests", self.health_requests),
            ("metrics_requests", self.metrics_requests),
        )
        lines = [
            "# HELP kookie_gateway_transport Current gateway transport.",
            "# TYPE kookie_gateway_transport gauge",
            f'kookie_gateway_transport{{name="{transport}"}} 1',
            "# HELP kookie_gateway_auth_required Whether bearer admission is enabled.",
            "# TYPE kookie_gateway_auth_required gauge",
            f"kookie_gateway_auth_required {1 if credential_source != 'none' else 0}",
            "# HELP kookie_gateway_auth_source Configured credential source.",
            "# TYPE kookie_gateway_auth_source gauge",
            f'kookie_gateway_auth_source{{name="{credential_source}"}} 1',
            "# HELP kookie_gateway_active_sessions Current admitted sessions.",
            "# TYPE kookie_gateway_active_sessions gauge",
            f"kookie_gateway_active_sessions {self.active_sessions}",
        ]
        for name, value in values:
            lines.extend((
                f"# TYPE kookie_gateway_{name} counter",
                f"kookie_gateway_{name} {value}",
            ))
        return "\n".join(lines) + "\n"



@dataclass(frozen=True)
class SessionFrame:
    kind: int
    sequence: int
    words: tuple[int, ...]


@dataclass
class AuthoritativeGameState:
    tick: int = 0
    position: int = 0
    health: int = GAME_MAXIMUM_HEALTH
    stamina: int = GAME_MAXIMUM_STAMINA
    combo: int = 0
    vfx: int = 0
    vfx_x: int = 32
    vfx_y: int = 1
    vfx_z: int = 52
    player_x: int = 32
    player_y: int = 1
    player_z: int = 52
    player_yaw: int = 0
    player_pitch: int = -8
    player_state: int = 1
    ammo: int = 24
    full_mode: bool = False
    player_liquid: bool = False
    velocity_x: int = 0
    velocity_y: int = 0
    velocity_z: int = 0
    grounded: bool = True
    coyote_ticks: int = GAME_MOVEMENT_COYOTE_TICKS
    jump_buffer_ticks: int = 0
    air_jumps: int = 0
    actor_health: list[int] = field(
        default_factory=lambda: [GAME_MAXIMUM_HEALTH] * GAME_FULL_ACTORS
    )
    actor_x: list[int] = field(default_factory=lambda: [96, 208, 260, 150])
    actor_y: list[int] = field(default_factory=lambda: [1, 1, 1, 1])
    actor_z: list[int] = field(default_factory=lambda: [80, 160, 220, 210])
    actor_state: list[int] = field(default_factory=lambda: [1, 1, 2, 3])
    actor_kind: list[int] = field(default_factory=lambda: [1, 2, 1, 2])
    actor_yaw: list[int] = field(default_factory=lambda: [90, 180, 0, 270])
    projectile_x: int = 0
    projectile_y: int = 0
    projectile_z: int = 0
    projectile_dx: int = 0
    projectile_dz: int = 0
    projectile_ttl: int = 0
    pickup_active: bool = True
    pickup_kind: int = 1
    pickup_x: int = 128
    pickup_y: int = 1
    pickup_z: int = 112

    def _advance_projectile(self) -> None:
        if self.projectile_ttl <= 0:
            self.projectile_x = 0
            self.projectile_y = 0
            self.projectile_z = 0
            self.projectile_dx = 0
            self.projectile_dz = 0
            self.projectile_ttl = 0
            return
        self.projectile_x = max(
            GAME_WORLD_MINIMUM_X,
            min(GAME_WORLD_MAXIMUM_X, self.projectile_x + self.projectile_dx),
        )
        self.projectile_z = max(
            GAME_WORLD_MINIMUM_Z,
            min(GAME_WORLD_MAXIMUM_Z, self.projectile_z + self.projectile_dz),
        )
        self.projectile_ttl -= 1

    def _advance_legacy_vertical(self) -> None:
        if self.player_y > GAME_WORLD_MINIMUM_Y:
            self.player_y = max(GAME_WORLD_MINIMUM_Y, self.player_y - 1)

    def _movement_axes(self, command: int) -> tuple[int, int]:
        facing = int((self.player_yaw + 45) // 90) % 4
        forward_x, forward_z = ((0, 1), (1, 0), (0, -1), (-1, 0))[facing]
        right_x, right_z = forward_z, -forward_x
        if command in (GAME_MOVE_FORWARD,):
            return forward_x, forward_z
        if command in (GAME_MOVE_BACK,):
            return -forward_x, -forward_z
        if command in (GAME_MOVE_LEFT, GAME_STRAFE_LEFT):
            return -right_x, -right_z
        if command in (GAME_MOVE_RIGHT, GAME_STRAFE_RIGHT):
            return right_x, right_z
        return 0, 0

    def _horizontal_overlap(
        self, x: int, z: int, box: tuple[int, int, int, int, int, int]
    ) -> bool:
        left, _, front, right, _, back = box
        return (
            left - GAME_MOVEMENT_RADIUS <= x <= right + GAME_MOVEMENT_RADIUS
            and front - GAME_MOVEMENT_RADIUS <= z <= back + GAME_MOVEMENT_RADIUS
        )

    def _vertical_overlap(
        self, y: int, box: tuple[int, int, int, int, int, int]
    ) -> bool:
        _, bottom, _, _, top, _ = box
        return (
            y < top
            and y + GAME_MOVEMENT_HEIGHT > bottom
        )
    def _ramp_floor_y(self, x: int, z: int) -> int | None:
        floor: int | None = None
        for left, start_y, front, right, end_y, back in GAME_MOVEMENT_RAMPS:
            if not left <= x <= right or not front <= z <= back:
                continue
            span = right - left
            height = max(
                GAME_WORLD_MINIMUM_Y,
                start_y + (x - left) * (end_y - start_y) // span,
            )
            if floor is None or height > floor:
                floor = height
        return floor



    def _sweep_horizontal(self, axis: str, amount: int) -> int:
        if amount == 0:
            return self.player_x if axis == "x" else self.player_z
        current = self.player_x if axis == "x" else self.player_z
        other = self.player_z if axis == "x" else self.player_x
        target = current + amount
        for box in GAME_MOVEMENT_BOXES:
            left, _, front, right, top, back = box
            if not self._vertical_overlap(self.player_y, box):
                continue
            minimum = (left if axis == "x" else front) - GAME_MOVEMENT_RADIUS
            maximum = (right if axis == "x" else back) + GAME_MOVEMENT_RADIUS
            other_minimum = (
                front if axis == "x" else left
            ) - GAME_MOVEMENT_RADIUS
            other_maximum = (
                back if axis == "x" else right
            ) + GAME_MOVEMENT_RADIUS
            if not other_minimum <= other <= other_maximum:
                continue
            if minimum < current < maximum:
                target = current
            elif amount > 0 and current <= minimum <= target:
                target = minimum
            elif amount < 0 and current >= maximum >= target:
                target = maximum
        resolved = (
            max(GAME_WORLD_MINIMUM_X, min(GAME_WORLD_MAXIMUM_X, target))
            if axis == "x" else
            max(GAME_WORLD_MINIMUM_Z, min(GAME_WORLD_MAXIMUM_Z, target))
        )
        if resolved != current + amount:
            if axis == "x":
                self.velocity_x = 0
            else:
                self.velocity_z = 0
        return resolved

    def _step_full_physics(
        self, move_x: int, move_z: int, jump_pressed: bool
    ) -> None:
        was_grounded = self.grounded
        if was_grounded:
            self.coyote_ticks = GAME_MOVEMENT_COYOTE_TICKS
        elif self.coyote_ticks > 0:
            self.coyote_ticks -= 1
        if self.jump_buffer_ticks > 0:
            self.jump_buffer_ticks -= 1
        if jump_pressed:
            self.jump_buffer_ticks = GAME_MOVEMENT_JUMP_BUFFER_TICKS

        input_magnitude = math.isqrt(move_x * move_x + move_z * move_z)
        if input_magnitude > 0:
            wish_x = move_x * 1024 // input_magnitude
            wish_z = move_z * 1024 // input_magnitude
            current_speed = (
                self.velocity_x * wish_x + self.velocity_z * wish_z
            ) // 1024
            acceleration = (
                GAME_MOVEMENT_GROUND_ACCELERATION
                if was_grounded else GAME_MOVEMENT_AIR_ACCELERATION
            )
            add_speed = min(8 - current_speed, acceleration)
            if add_speed > 0:
                self.velocity_x += wish_x * add_speed // 1024
                self.velocity_z += wish_z * add_speed // 1024
        elif was_grounded:
            speed = math.isqrt(
                self.velocity_x * self.velocity_x +
                self.velocity_z * self.velocity_z
            )
            next_speed = max(0, speed - GAME_MOVEMENT_GROUND_BRAKING)
            if speed <= 0 or next_speed <= 0:
                self.velocity_x = 0
                self.velocity_z = 0
            else:
                self.velocity_x = self.velocity_x * next_speed // speed
                self.velocity_z = self.velocity_z * next_speed // speed
        else:
            self.velocity_x = self._approach(
                self.velocity_x, 0, GAME_MOVEMENT_AIR_BRAKING
            )
            self.velocity_z = self._approach(
                self.velocity_z, 0, GAME_MOVEMENT_AIR_BRAKING
            )

        jumped = False
        if self.jump_buffer_ticks > 0 and (
            was_grounded or self.coyote_ticks > 0
        ):
            self.velocity_y = GAME_MOVEMENT_JUMP_VELOCITY
            self.jump_buffer_ticks = 0
            self.coyote_ticks = 0
            self.air_jumps = 0
            self.grounded = False
            jumped = True
        elif (
            self.jump_buffer_ticks > 0 and
            not was_grounded and
            self.coyote_ticks <= 0 and
            self.air_jumps < GAME_MOVEMENT_MAXIMUM_AIR_JUMPS
        ):
            self.velocity_y = GAME_MOVEMENT_JUMP_VELOCITY
            self.jump_buffer_ticks = 0
            self.air_jumps += 1
            self.grounded = False
            jumped = True

        if not was_grounded or jumped:
            self.velocity_y = max(
                -GAME_MOVEMENT_MAX_FALL_SPEED,
                self.velocity_y - GAME_MOVEMENT_GRAVITY,
            )
        else:
            self.velocity_y = 0

        self.player_x = self._sweep_horizontal("x", self.velocity_x)
        self.player_z = self._sweep_horizontal("z", self.velocity_z)
        old_y = self.player_y
        target_y = old_y + self.velocity_y
        landing_y: list[int] = []
        ceiling_y: list[int] = []
        for box in GAME_MOVEMENT_BOXES:
            if not self._horizontal_overlap(self.player_x, self.player_z, box):
                continue
            _, bottom, _, _, top, _ = box
            if (
                self.velocity_y <= 0 and
                old_y >= top and
                target_y <= top
            ):
                landing_y.append(top)
            elif (
                self.velocity_y > 0 and
                old_y + GAME_MOVEMENT_HEIGHT <= bottom and
                target_y + GAME_MOVEMENT_HEIGHT >= bottom
            ):
                ceiling_y.append(bottom - GAME_MOVEMENT_HEIGHT)
        ramp_floor_y = self._ramp_floor_y(self.player_x, self.player_z)
        if (
            ramp_floor_y is not None and
            self.velocity_y <= 0 and
            target_y <= ramp_floor_y
        ):
            landing_y.append(ramp_floor_y)
        elif (
            ramp_floor_y is not None and
            was_grounded and
            self.velocity_y == 0 and
            ramp_floor_y < old_y
        ):
            landing_y.append(ramp_floor_y)
        if landing_y:
            self.player_y = max(landing_y)
            self.velocity_y = 0
            self.grounded = True
            self.air_jumps = 0
        elif target_y <= GAME_WORLD_MINIMUM_Y:
            self.player_y = GAME_WORLD_MINIMUM_Y
            self.velocity_y = 0
            self.grounded = True
            self.air_jumps = 0
        elif ceiling_y:
            self.player_y = min(ceiling_y)
            self.velocity_y = 0
            self.grounded = False
        else:
            self.player_y = min(GAME_WORLD_MAXIMUM_Y, target_y)
            self.grounded = False

    @staticmethod
    def _approach(value: int, target: int, delta: int) -> int:
        if value < target:
            return min(target, value + delta)
        if value > target:
            return max(target, value - delta)
        return value

    def _damage_nearest_actor(self, amount: int) -> None:
        actor_positions = (-70, 8, 72)
        nearest_index = min(
            range(GAME_LEGACY_ACTORS),
            key=lambda index: abs(actor_positions[index] - self.position),
        )
        if abs(actor_positions[nearest_index] - self.position) <= 32:
            self.actor_health[nearest_index] = max(
                0, self.actor_health[nearest_index] - amount
            )

    def _damage_nearest_world_actor(self, amount: int) -> tuple[int, int]:
        nearest_index = min(
            range(GAME_FULL_ACTORS),
            key=lambda index: (
                (self.actor_x[index] - self.player_x) ** 2 +
                (self.actor_z[index] - self.player_z) ** 2
            ),
        )
        distance_squared = (
            (self.actor_x[nearest_index] - self.player_x) ** 2 +
            (self.actor_z[nearest_index] - self.player_z) ** 2
        )
        if distance_squared > 42 ** 2:
            return -1, 0
        self.actor_health[nearest_index] = max(
            0, self.actor_health[nearest_index] - amount
        )
        if self.actor_health[nearest_index] == 0:
            self.actor_state[nearest_index] = 4
            return nearest_index, GAME_VFX_DEATH
        return nearest_index, GAME_VFX_HIT

    def _set_vfx(self, asset: int, x: int, y: int, z: int) -> None:
        self.vfx = asset
        self.vfx_x = x
        self.vfx_y = y
        self.vfx_z = z

    def _liquid_surface_y(self) -> int | None:
        for min_x, max_x, min_z, max_z, surface_y in GAME_LIQUID_BOUNDS:
            if min_x <= self.player_x <= max_x and min_z <= self.player_z <= max_z:
                return surface_y
        return None

    def _update_liquid_event(self) -> None:
        surface_y = self._liquid_surface_y()
        liquid = surface_y is not None and self.player_y <= surface_y
        if liquid and not self.player_liquid:
            self._set_vfx(
                GAME_VFX_LIQUID, self.player_x, surface_y, self.player_z
            )
        self.player_liquid = liquid

    def _facing_step(self) -> tuple[int, int]:
        facing = int((self.player_yaw + 45) // 90) % 4
        return ((0, 12), (12, 0), (0, -12), (-12, 0))[facing]

    def _collect_pickup(self) -> None:
        if not self.pickup_active:
            return
        if (
            abs(self.pickup_x - self.player_x) <= 12 and
            abs(self.pickup_z - self.player_z) <= 12
        ):
            self.pickup_active = False
            self.ammo = min(GAME_MAXIMUM_AMMO, self.ammo + 6)
            self.stamina = min(GAME_MAXIMUM_STAMINA, self.stamina + 20)

    def apply_command(self, command: int, value: int) -> None:
        self.player_state = 1
        self._advance_projectile()
        if self.full_mode and command != GAME_RESET:
            move_x, move_z = self._movement_axes(command)
            self._step_full_physics(
                move_x, move_z, command == GAME_JUMP and value == 0
            )
        elif not self.full_mode:
            self._advance_legacy_vertical()
        if command == GAME_MOVE_LEFT and value == -8:
            if not self.full_mode:
                self.position = max(GAME_MINIMUM_POSITION, self.position - 8)
                self.player_x = max(GAME_WORLD_MINIMUM_X, self.player_x - 8)
        elif command == GAME_MOVE_RIGHT and value == 8:
            if not self.full_mode:
                self.position = min(GAME_MAXIMUM_POSITION, self.position + 8)
                self.player_x = min(GAME_WORLD_MAXIMUM_X, self.player_x + 8)
        elif command == GAME_MOVE_FORWARD and value == 8:
            if not self.full_mode:
                self.player_z = min(GAME_WORLD_MAXIMUM_Z, self.player_z + 8)
        elif command == GAME_MOVE_BACK and value == -8:
            if not self.full_mode:
                self.player_z = max(GAME_WORLD_MINIMUM_Z, self.player_z - 8)
        elif command == GAME_STRAFE_LEFT and value == -8:
            if not self.full_mode:
                self.player_x = max(GAME_WORLD_MINIMUM_X, self.player_x - 8)
        elif command == GAME_STRAFE_RIGHT and value == 8:
            if not self.full_mode:
                self.player_x = min(GAME_WORLD_MAXIMUM_X, self.player_x + 8)
        elif command == GAME_LOOK_LEFT and value == -15:
            self.player_yaw = (self.player_yaw - 15) % 360
        elif command == GAME_LOOK_RIGHT and value == 15:
            self.player_yaw = (self.player_yaw + 15) % 360
        elif command == GAME_MELEE and value == 0:
            self.player_state = 3
            if self.stamina >= 10:
                self.stamina -= 10
                self.combo = min(GAME_MAXIMUM_COMBO, self.combo + 1)
                if self.full_mode:
                    actor_index, impact = self._damage_nearest_world_actor(18)
                    if impact:
                        self._set_vfx(
                            impact,
                            self.actor_x[actor_index],
                            min(GAME_WORLD_MAXIMUM_Y, self.actor_y[actor_index] + 2),
                            self.actor_z[actor_index],
                        )
                    else:
                        self._set_vfx(
                            GAME_VFX_MELEE,
                            self.player_x,
                            min(GAME_WORLD_MAXIMUM_Y, self.player_y + 2),
                            self.player_z,
                        )
                else:
                    self._set_vfx(
                        GAME_VFX_MELEE,
                        self.player_x,
                        min(GAME_WORLD_MAXIMUM_Y, self.player_y + 2),
                        self.player_z,
                    )
                    self._damage_nearest_actor(18)
        elif command == GAME_SPECIAL and value == 0:
            self.player_state = 3
            if self.stamina >= 25:
                self.stamina -= 25
                self.combo = 0
                self.vfx = GAME_VFX_SPECIAL
                if self.full_mode:
                    self.projectile_x = min(
                        GAME_WORLD_MAXIMUM_X, self.player_x + 12
                    )
                    self.projectile_y = min(
                        GAME_WORLD_MAXIMUM_Y, self.player_y + 4
                    )
                    self.projectile_z = self.player_z
                else:
                    self.projectile_x = min(
                        GAME_MAXIMUM_POSITION, self.position + 12
                    )
                    self.projectile_y = 0
                    self.projectile_z = 0
                self.vfx_x = self.projectile_x
                self.vfx_y = self.projectile_y
                self.vfx_z = self.projectile_z
                self.projectile_dx = 12
                self.projectile_dz = 0
                self.projectile_ttl = 6
        elif command == GAME_FIRE and value == 0:
            if self.ammo > 0:
                self.ammo -= 1
                self.vfx = GAME_VFX_FIRE
                self.projectile_dx, self.projectile_dz = self._facing_step()
                self.projectile_x = max(
                    GAME_WORLD_MINIMUM_X,
                    min(GAME_WORLD_MAXIMUM_X, self.player_x + self.projectile_dx),
                )
                self.projectile_y = min(
                    GAME_WORLD_MAXIMUM_Y, self.player_y + 4
                )
                self.projectile_z = max(
                    GAME_WORLD_MINIMUM_Z,
                    min(GAME_WORLD_MAXIMUM_Z, self.player_z + self.projectile_dz),
                )
                self.vfx_x = self.projectile_x
                self.vfx_y = self.projectile_y
                self.vfx_z = self.projectile_z
                self.projectile_ttl = 10
        elif command == GAME_JUMP and value == 0:
            if not self.full_mode:
                self.player_y = min(
                    GAME_WORLD_MAXIMUM_Y, self.player_y + 7
                )
            self._set_vfx(
                GAME_VFX_JUMP, self.player_x, self.player_y, self.player_z
            )
        elif command == GAME_RESET and value == 0:
            self.position = 0
            self.health = GAME_MAXIMUM_HEALTH
            self.stamina = GAME_MAXIMUM_STAMINA
            self.combo = 0
            self.vfx = 0
            self.vfx_x = 32
            self.vfx_y = 1
            self.vfx_z = 52
            self.player_x = 32
            self.player_y = 1
            self.player_z = 52
            self.player_yaw = 0
            self.player_pitch = -8
            self.ammo = 24
            self.player_state = 1
            self.actor_health = [GAME_MAXIMUM_HEALTH] * GAME_FULL_ACTORS
            self.actor_state = [1, 1, 2, 3]
            self.projectile_x = 0
            self.projectile_y = 0
            self.projectile_z = 0
            self.projectile_dx = 0
            self.projectile_dz = 0
            self.projectile_ttl = 0
            self.pickup_active = True
            self.pickup_kind = 1
            self.pickup_x = 128
            self.pickup_y = 1
            self.pickup_z = 112
            self.player_liquid = False
            self.velocity_x = 0
            self.velocity_y = 0
            self.velocity_z = 0
            self.grounded = True
            self.coyote_ticks = GAME_MOVEMENT_COYOTE_TICKS
            self.jump_buffer_ticks = 0
            self.air_jumps = 0
        else:
            raise ProtocolError("invalid authoritative game command")
        self._collect_pickup()
        self.tick += 1
        if command in (
            GAME_MOVE_LEFT, GAME_MOVE_RIGHT, GAME_MOVE_FORWARD,
            GAME_MOVE_BACK, GAME_STRAFE_LEFT, GAME_STRAFE_RIGHT,
        ):
            self.vfx = 0
            self.player_state = 2
            self.vfx_x = self.player_x
            self.vfx_y = self.player_y
            self.vfx_z = self.player_z
        self._update_liquid_event()
        if command == GAME_JUMP and value == 0:
            self.player_state = 2

    def snapshot_words(self, sequence: int) -> list[int]:
        words = [
            NETCODE_PROTOCOL_VERSION, GAME, sequence, GAME_SNAPSHOT_MARKER,
            self.tick, self.position, self.health, self.stamina,
            self.combo, self.vfx,
        ]
        words.append(message_checksum(words))
        return words

    def scene_snapshot_words(self, sequence: int) -> list[int]:
        words = [
            NETCODE_PROTOCOL_VERSION, GAME, sequence,
            GAME_SCENE_SNAPSHOT_MARKER, self.tick, self.position, 0, 0,
            self.health, self.stamina, self.combo, self.vfx,
            GAME_LEGACY_ACTORS,
        ]
        for actor_id, (actor_x, actor_z) in enumerate(
            ((-70, 24), (8, -26), (72, 18)), start=1
        ):
            words.extend((
                actor_id, actor_x, actor_z,
                self.actor_health[actor_id - 1],
            ))
        words.extend((
            1 if self.projectile_ttl > 0 else 0,
            self.projectile_x if self.projectile_ttl > 0 else 0,
            self.projectile_z if self.projectile_ttl > 0 else 0,
            self.projectile_ttl,
        ))
        words.append(message_checksum(words))
        return words

    def full_scene_snapshot_words(self, sequence: int) -> list[int]:
        words = [
            NETCODE_PROTOCOL_VERSION, GAME, sequence,
            GAME_FULL_SCENE_SNAPSHOT_MARKER, self.tick,
            self.player_x, self.player_y, self.player_z,
            self.player_yaw, self.player_pitch, self.health,
            self.stamina, self.ammo, self.combo, self.vfx,
            self.player_x, self.player_y + 8, self.player_z - 16,
            self.player_yaw, self.player_pitch, GAME_FULL_ACTORS,
        ]
        for actor_id in range(GAME_FULL_ACTORS):
            words.extend((
                actor_id + 1, self.actor_x[actor_id], self.actor_y[actor_id],
                self.actor_z[actor_id], self.actor_health[actor_id],
                self.actor_state[actor_id], self.actor_kind[actor_id],
                self.actor_yaw[actor_id],
            ))
        scene_objects = list(GAME_STATIC_SCENE_OBJECTS)
        if self.pickup_active:
            scene_objects.append((
                GAME_SCENE_OBJECT_LOOT_BEAM, 100,
                max(1, min(3, self.pickup_kind)),
                self.pickup_x, self.pickup_y, self.pickup_z, 2, 4, 2,
            ))
        labels = [
            (
                actor_id + 1, actor_id + 1,
                self.actor_x[actor_id], self.actor_y[actor_id],
                self.actor_z[actor_id],
                1 if self.actor_health[actor_id] > 0 else 0,
            )
            for actor_id in range(GAME_FULL_ACTORS)
        ]
        words.extend((
            1 if self.projectile_ttl > 0 else 0,
            1 if self.projectile_ttl > 0 else 0,
            self.projectile_x if self.projectile_ttl > 0 else 0,
            self.projectile_y if self.projectile_ttl > 0 else 0,
            self.projectile_z if self.projectile_ttl > 0 else 0,
            self.projectile_ttl,
            1 if self.pickup_active else 0, self.pickup_kind,
            self.pickup_x, self.pickup_y, self.pickup_z,
            self.vfx_x, self.vfx_y, self.vfx_z,
            self.player_state,
            len(scene_objects),
        ))
        for scene_object in scene_objects:
            words.extend(scene_object)
        words.append(len(labels))
        for label in labels:
            words.extend(label)
        words.append(message_checksum(words))
        return words


def checksum_mix(state: int, value: int) -> int:
    normalized = value % 1_000_003
    return (state * 31 + normalized) % 1_000_003


def message_checksum(words: list[int] | tuple[int, ...]) -> int:
    if not words:
        raise ProtocolError("empty message")
    result = 53
    for value in words:
        result = checksum_mix(result, value)
    return result


def wire_checksum(wire: bytes | bytearray) -> int:
    if len(wire) < 16:
        raise ProtocolError("short wire frame")
    result = 0
    for index, value in enumerate(wire):
        if index in (14, 15):
            value = 0
        result = (result + value * (index + 1)) % 65536
    return result


def encode_session_frame(kind: int, sequence: int, words: list[int]) -> bytes:
    if kind < HELLO or kind > GAME:
        raise ProtocolError("unknown message kind")
    if sequence <= 0 or sequence > MAX_SEQUENCE:
        raise ProtocolError("invalid sequence")
    if not 0 < len(words) <= MAX_WORDS:
        raise ProtocolError("word count outside limit")
    if words[0] != NETCODE_PROTOCOL_VERSION or words[1] != kind:
        raise ProtocolError("message/header kind mismatch")
    if words[2] != sequence:
        raise ProtocolError("message/header sequence mismatch")
    payload = b"".join(struct.pack(">i", value) for value in words)
    header = bytearray(
        MAGIC
        + bytes((FRAME_VERSION, kind, 0, 0))
        + struct.pack(">IHH", sequence, len(words), 0)
    )
    wire = header + payload
    wire[14:16] = struct.pack(">H", wire_checksum(wire))
    if len(wire) > MAX_FRAME_BYTES:
        raise ProtocolError("frame exceeds byte limit")
    return bytes(wire)


def _validate_message(frame_kind: int, sequence: int, words: tuple[int, ...]) -> None:
    if len(words) < 3 or words[0] != NETCODE_PROTOCOL_VERSION:
        raise ProtocolError("unsupported message protocol")
    if words[1] != frame_kind or words[2] != sequence:
        raise ProtocolError("message identity mismatch")
    if frame_kind == HELLO:
        if len(words) != 8 or tuple(words[:7]) != (
            NETCODE_PROTOCOL_VERSION,
            HELLO,
            sequence,
            CLIENT_TARGET_BROWSER,
            AUTHORITY_REMOTE,
            GAME_WEBSOCKET,
            BROWSER_CAPABILITY,
        ):
            raise ProtocolError("invalid browser hello")
    elif frame_kind == ACK:
        if len(words) != 7 or words[3] not in (0, 1) or \
                words[4] != GAME_WEBSOCKET or words[5] != SERVER_CAPABILITY:
            raise ProtocolError("invalid session acknowledgement")
    elif frame_kind in (PING, PONG):
        if len(words) != 4:
            raise ProtocolError("invalid heartbeat")
    elif frame_kind == GAME:
        if len(words) == 5:
            if words[3] != GAME_PROBE_PAYLOAD:
                raise ProtocolError("invalid game probe")
        elif len(words) == 7:
            if words[3] != GAME_COMMAND_MARKER or \
                    words[4] not in (
                        GAME_MOVE_LEFT, GAME_MOVE_RIGHT, GAME_MELEE,
                        GAME_SPECIAL, GAME_RESET, GAME_SCENE_PROBE,
                        GAME_FULL_SCENE_PROBE, GAME_MOVE_FORWARD,
                        GAME_MOVE_BACK, GAME_STRAFE_LEFT,
                        GAME_STRAFE_RIGHT, GAME_LOOK_LEFT,
                        GAME_LOOK_RIGHT, GAME_FIRE, GAME_JUMP,
                    ):
                raise ProtocolError("invalid authoritative game command")
            expected_value = 0
            if words[4] in (GAME_MOVE_LEFT, GAME_STRAFE_LEFT):
                expected_value = -8
            elif words[4] in (
                GAME_MOVE_RIGHT, GAME_MOVE_FORWARD, GAME_STRAFE_RIGHT
            ):
                expected_value = 8
            elif words[4] == GAME_MOVE_BACK:
                expected_value = -8
            elif words[4] == GAME_LOOK_LEFT:
                expected_value = -15
            elif words[4] == GAME_LOOK_RIGHT:
                expected_value = 15
            if words[5] != expected_value:
                raise ProtocolError("invalid authoritative game value")
        elif len(words) == 11:
            if words[3] != GAME_SNAPSHOT_MARKER or \
                    words[4] < 0 or words[4] > GAME_MAXIMUM_TICK or \
                    words[5] < GAME_MINIMUM_POSITION or \
                    words[5] > GAME_MAXIMUM_POSITION or \
                    words[6] < 0 or words[6] > GAME_MAXIMUM_HEALTH or \
                    words[7] < 0 or words[7] > GAME_MAXIMUM_STAMINA or \
                    words[8] < 0 or words[8] > GAME_MAXIMUM_COMBO or \
                    words[9] < 0 or words[9] > GAME_MAXIMUM_VFX:
                raise ProtocolError("invalid authoritative game snapshot")
        elif len(words) == 30:
            if words[3] != GAME_SCENE_SNAPSHOT_MARKER or \
                    words[4] < 0 or words[4] > GAME_MAXIMUM_TICK or \
                    words[5] < GAME_MINIMUM_POSITION or \
                    words[5] > GAME_MAXIMUM_POSITION or \
                    words[6] < GAME_MINIMUM_DEPTH or \
                    words[6] > GAME_MAXIMUM_DEPTH or \
                    words[8] < 0 or words[8] > GAME_MAXIMUM_HEALTH or \
                    words[9] < 0 or words[9] > GAME_MAXIMUM_STAMINA or \
                    words[10] < 0 or words[10] > GAME_MAXIMUM_COMBO or \
                    words[11] < 0 or words[11] > GAME_MAXIMUM_VFX or \
                    words[12] != GAME_LEGACY_ACTORS or \
                    any(
                        words[index] < 0 or
                        words[index] > GAME_MAXIMUM_HEALTH
                        for index in (16, 20, 24)
                    ) or \
                    words[25] < 0 or \
                    words[25] > GAME_MAXIMUM_PROJECTILES or \
                    words[26] < GAME_MINIMUM_POSITION or \
                    words[26] > GAME_MAXIMUM_POSITION or \
                    words[27] < GAME_MINIMUM_DEPTH or \
                    words[27] > GAME_MAXIMUM_DEPTH or \
                    words[28] < 0 or words[28] > 6:
                raise ProtocolError("invalid authoritative scene snapshot")
        elif len(words) >= 70:
            if words[3] != GAME_FULL_SCENE_SNAPSHOT_MARKER or \
                    words[4] < 0 or words[4] > GAME_MAXIMUM_TICK or \
                    words[5] < GAME_WORLD_MINIMUM_X or \
                    words[5] > GAME_WORLD_MAXIMUM_X or \
                    words[6] < GAME_WORLD_MINIMUM_Y or \
                    words[6] > GAME_WORLD_MAXIMUM_Y or \
                    words[7] < GAME_WORLD_MINIMUM_Z or \
                    words[7] > GAME_WORLD_MAXIMUM_Z or \
                    words[8] < 0 or words[8] > 359 or \
                    words[9] < -90 or words[9] > 90 or \
                    words[10] < 0 or words[10] > GAME_MAXIMUM_HEALTH or \
                    words[11] < 0 or words[11] > GAME_MAXIMUM_STAMINA or \
                    words[12] < 0 or words[12] > GAME_MAXIMUM_AMMO or \
                    words[13] < 0 or words[13] > GAME_MAXIMUM_COMBO or \
                    words[14] < 0 or words[14] > GAME_MAXIMUM_VFX or \
                    words[15] < GAME_WORLD_MINIMUM_X or \
                    words[15] > GAME_WORLD_MAXIMUM_X or \
                    words[16] < GAME_WORLD_MINIMUM_Y or \
                    words[16] > GAME_WORLD_MAXIMUM_Y + 16 or \
                    words[17] < GAME_WORLD_MINIMUM_Z - 16 or \
                    words[17] > GAME_WORLD_MAXIMUM_Z or \
                    words[18] < 0 or words[18] > 359 or \
                    words[19] < -90 or words[19] > 90 or \
                    words[20] != GAME_FULL_ACTORS:
                raise ProtocolError("invalid authoritative full scene snapshot")
            actor_offsets = tuple(21 + index * 8 for index in range(GAME_FULL_ACTORS))
            for offset in actor_offsets:
                if words[offset] <= 0 or \
                        not GAME_WORLD_MINIMUM_X <= words[offset + 1] <= GAME_WORLD_MAXIMUM_X or \
                        not GAME_WORLD_MINIMUM_Y <= words[offset + 2] <= GAME_WORLD_MAXIMUM_Y or \
                        not GAME_WORLD_MINIMUM_Z <= words[offset + 3] <= GAME_WORLD_MAXIMUM_Z or \
                        not 0 <= words[offset + 4] <= GAME_MAXIMUM_HEALTH or \
                        not 1 <= words[offset + 5] <= 4 or \
                        not 1 <= words[offset + 6] <= 2 or \
                        not 0 <= words[offset + 7] <= 359:
                    raise ProtocolError("invalid authoritative actor entry")
            if words[53] < 0 or words[53] > GAME_MAXIMUM_PROJECTILES or \
                    words[54] not in (0, 1):
                raise ProtocolError("invalid authoritative projectile state")
            if words[54] == 0 and any(
                    words[index] != 0 for index in (55, 56, 57, 58)):
                raise ProtocolError("invalid inactive projectile state")
            if words[54] == 1 and not (
                    GAME_WORLD_MINIMUM_X <= words[55] <= GAME_WORLD_MAXIMUM_X and
                    GAME_WORLD_MINIMUM_Y <= words[56] <= GAME_WORLD_MAXIMUM_Y and
                    GAME_WORLD_MINIMUM_Z <= words[57] <= GAME_WORLD_MAXIMUM_Z and
                    1 <= words[58] <= 10):
                raise ProtocolError("invalid active projectile state")
            if words[59] not in (0, 1) or \
                    not 0 <= words[60] <= GAME_MAXIMUM_PICKUP_KIND or \
                    not GAME_WORLD_MINIMUM_X <= words[61] <= GAME_WORLD_MAXIMUM_X or \
                    not GAME_WORLD_MINIMUM_Y <= words[62] <= GAME_WORLD_MAXIMUM_Y or \
                    not GAME_WORLD_MINIMUM_Z <= words[63] <= GAME_WORLD_MAXIMUM_Z:
                raise ProtocolError("invalid authoritative pickup state")
            if not GAME_WORLD_MINIMUM_X <= words[64] <= GAME_WORLD_MAXIMUM_X or \
                    not GAME_WORLD_MINIMUM_Y <= words[65] <= GAME_WORLD_MAXIMUM_Y or \
                    not GAME_WORLD_MINIMUM_Z <= words[66] <= GAME_WORLD_MAXIMUM_Z or \
                    not 1 <= words[67] <= 4:
                raise ProtocolError("invalid authoritative presentation state")
            object_count = words[68]
            if not 0 <= object_count <= GAME_MAXIMUM_SCENE_OBJECTS:
                raise ProtocolError("invalid authoritative scene object count")
            labels_offset = GAME_SCENE_OBJECTS_OFFSET + \
                object_count * GAME_SCENE_OBJECT_ENTRY_WIDTH
            if labels_offset >= len(words):
                raise ProtocolError("missing authoritative scene labels")
            label_count = words[labels_offset]
            expected_length = labels_offset + 1 + \
                label_count * GAME_SCENE_LABEL_ENTRY_WIDTH + 1
            if not 0 <= label_count <= GAME_MAXIMUM_SCENE_LABELS or \
                    len(words) != expected_length:
                raise ProtocolError("invalid authoritative scene label count")
            for index in range(object_count):
                offset = GAME_SCENE_OBJECTS_OFFSET + \
                    index * GAME_SCENE_OBJECT_ENTRY_WIDTH
                kind, object_id, state = words[offset : offset + 3]
                if not 1 <= kind <= GAME_SCENE_OBJECT_LOOT_BEAM or \
                        object_id <= 0 or \
                        not GAME_WORLD_MINIMUM_X <= words[offset + 3] <= GAME_WORLD_MAXIMUM_X or \
                        not GAME_WORLD_MINIMUM_Y <= words[offset + 4] <= GAME_WORLD_MAXIMUM_Y or \
                        not GAME_WORLD_MINIMUM_Z <= words[offset + 5] <= GAME_WORLD_MAXIMUM_Z or \
                        not 0 < words[offset + 6] <= 32 or \
                        not 0 < words[offset + 7] <= 32 or \
                        not 0 < words[offset + 8] <= 32:
                    raise ProtocolError("invalid authoritative scene object")
                if kind == GAME_SCENE_OBJECT_LOOT_BEAM:
                    if not 1 <= state <= 3:
                        raise ProtocolError("invalid authoritative loot beam rank")
                elif not 0 <= state <= 1:
                    raise ProtocolError("invalid authoritative scene object state")
            for index in range(label_count):
                offset = labels_offset + 1 + \
                    index * GAME_SCENE_LABEL_ENTRY_WIDTH
                label_id, text_id = words[offset : offset + 2]
                if label_id <= 0 or not 1 <= text_id <= 4 or \
                        not GAME_WORLD_MINIMUM_X <= words[offset + 2] <= GAME_WORLD_MAXIMUM_X or \
                        not GAME_WORLD_MINIMUM_Y <= words[offset + 3] <= GAME_WORLD_MAXIMUM_Y or \
                        not GAME_WORLD_MINIMUM_Z <= words[offset + 4] <= GAME_WORLD_MAXIMUM_Z or \
                        not 0 <= words[offset + 5] <= 1:
                    raise ProtocolError("invalid authoritative projected label")
        else:
            raise ProtocolError("game payload length outside contract")
    elif frame_kind != ERROR:
        raise ProtocolError("message kind is not accepted")
    if words[-1] != message_checksum(words[:-1]):
        raise ProtocolError("message checksum mismatch")


def decode_session_frame(wire: bytes) -> SessionFrame:
    if len(wire) < 16 or len(wire) > MAX_FRAME_BYTES:
        raise ProtocolError("frame size outside limit")
    if wire[:4] != MAGIC or wire[4] != FRAME_VERSION:
        raise ProtocolError("frame header mismatch")
    kind = wire[5]
    if wire[6] != 0 or wire[7] != 0:
        raise ProtocolError("frame flags are not supported")
    sequence, word_count, expected_wire_checksum = struct.unpack(">IHH", wire[8:16])
    if sequence <= 0 or sequence > MAX_SEQUENCE:
        raise ProtocolError("frame sequence outside limit")
    if word_count <= 0 or word_count > MAX_WORDS:
        raise ProtocolError("frame word count outside limit")
    if len(wire) != 16 + word_count * 4:
        raise ProtocolError("frame length mismatch")
    if wire_checksum(wire) != expected_wire_checksum:
        raise ProtocolError("wire checksum mismatch")
    words = tuple(
        struct.unpack(">i", wire[offset : offset + 4])[0]
        for offset in range(16, len(wire), 4)
    )
    _validate_message(kind, sequence, words)
    return SessionFrame(kind, sequence, words)


def new_ack(sequence: int, accepted: bool) -> bytes:
    words = [
        NETCODE_PROTOCOL_VERSION,
        ACK,
        sequence,
        1 if accepted else 0,
        GAME_WEBSOCKET,
        SERVER_CAPABILITY,
    ]
    words.append(message_checksum(words))
    return encode_session_frame(ACK, sequence, words)


def new_pong(sequence: int) -> bytes:
    words = [NETCODE_PROTOCOL_VERSION, PONG, sequence]
    words.append(message_checksum(words))
    return encode_session_frame(PONG, sequence, words)


def new_error(sequence: int, diagnostic: int) -> bytes:
    words = [NETCODE_PROTOCOL_VERSION, ERROR, sequence, diagnostic]
    words.append(message_checksum(words))
    return encode_session_frame(ERROR, sequence, words)


def new_game_snapshot(state: AuthoritativeGameState, sequence: int) -> bytes:
    return encode_session_frame(GAME, sequence, state.snapshot_words(sequence))
def new_game_scene_snapshot(
    state: AuthoritativeGameState, sequence: int
) -> bytes:
    return encode_session_frame(
        GAME, sequence, state.scene_snapshot_words(sequence)
    )
def new_game_full_scene_snapshot(
    state: AuthoritativeGameState, sequence: int
) -> bytes:
    return encode_session_frame(
        GAME, sequence, state.full_scene_snapshot_words(sequence)
    )


def recv_exact(sock: socket.socket, count: int) -> bytes:
    chunks: list[bytes] = []
    remaining = count
    while remaining:
        chunk = sock.recv(remaining)
        if not chunk:
            raise EOFError("peer closed")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def receive_http_headers(sock: socket.socket) -> bytes:
    data = bytearray()
    while b"\r\n\r\n" not in data:
        chunk = sock.recv(1024)
        if not chunk:
            raise EOFError("peer closed before WebSocket upgrade")
        data.extend(chunk)
        if len(data) > MAX_HTTP_HEADER_BYTES:
            raise ProtocolError("HTTP headers exceed limit")
    return bytes(data)


def parse_http_request(
    request: bytes,
) -> tuple[str, str, dict[str, str]]:
    header_block = request.split(b"\r\n\r\n", 1)[0]
    lines = header_block.decode("latin1").split("\r\n")
    request_parts = lines[0].split(" ") if lines else []
    if len(request_parts) != 3 or request_parts[2] != "HTTP/1.1":
        raise HttpUpgradeError(400, "Bad Request")
    headers: dict[str, str] = {}
    for line in lines[1:]:
        if ":" not in line:
            raise HttpUpgradeError(400, "Bad Request")
        name, value = line.split(":", 1)
        headers[name.strip().lower()] = value.strip()
    return request_parts[0], request_parts[1], headers


def send_http_response(
    sock: socket.socket,
    status: int,
    reason: str,
    body: bytes = b"",
    content_type: str = "text/plain; charset=utf-8",
) -> None:
    response = (
        f"HTTP/1.1 {status} {reason}\r\n"
        "Connection: close\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        f"Content-Type: {content_type}\r\n"
        f"Content-Length: {len(body)}\r\n\r\n"
    ).encode("ascii") + body
    try:
        sock.sendall(response)
    except OSError:
        pass


def send_http_rejection(
    sock: socket.socket, status: int, reason: str
) -> None:
    send_http_response(sock, status, reason)


def upgrade(
    sock: socket.socket,
    expected_auth_token: str | None,
    request: bytes | None = None,
) -> str | None:
    if request is None:
        request = receive_http_headers(sock)
    method, target, headers = parse_http_request(request)
    if method != "GET":
        raise HttpUpgradeError(400, "Bad Request")
    if target != SESSION_ROUTE:
        raise HttpUpgradeError(404, "Not Found")
    if headers.get("upgrade", "").lower() != "websocket":
        raise HttpUpgradeError(400, "Bad Request")
    if "upgrade" not in headers.get("connection", "").lower():
        raise HttpUpgradeError(400, "Bad Request")
    key = headers.get("sec-websocket-key", "")
    if not key:
        raise HttpUpgradeError(400, "Bad Request")
    try:
        base64.b64decode(key, validate=True)
    except ValueError as error:
        raise HttpUpgradeError(400, "Bad Request") from error
    protocols = tuple(
        value.strip()
        for value in headers.get("sec-websocket-protocol", "").split(",")
        if value.strip()
    )
    if protocols and WEBSOCKET_SUBPROTOCOL not in protocols:
        raise HttpUpgradeError(400, "Bad Request")
    if expected_auth_token is not None:
        expected_protocol = AUTH_SUBPROTOCOL_PREFIX + expected_auth_token
        if WEBSOCKET_SUBPROTOCOL not in protocols or not any(
            hmac.compare_digest(protocol, expected_protocol)
            for protocol in protocols
        ):
            raise HttpUpgradeError(401, "Unauthorized")
    accept = base64.b64encode(
        hashlib.sha1(
            key.encode("ascii") + b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        ).digest()
    ).decode("ascii")
    response_lines = [
        "HTTP/1.1 101 Switching Protocols",
        "Upgrade: websocket",
        "Connection: Upgrade",
        f"Sec-WebSocket-Accept: {accept}",
    ]
    if WEBSOCKET_SUBPROTOCOL in protocols:
        response_lines.append(
            f"Sec-WebSocket-Protocol: {WEBSOCKET_SUBPROTOCOL}"
        )
    sock.sendall(("\r\n".join(response_lines) + "\r\n\r\n").encode("ascii"))
    return WEBSOCKET_SUBPROTOCOL if WEBSOCKET_SUBPROTOCOL in protocols else None


def receive_websocket_frame(sock: socket.socket) -> tuple[int, bytes]:
    first, second = recv_exact(sock, 2)
    fin = first & 0x80
    if not fin or first & 0x70:
        raise ProtocolError("fragmented or extension WebSocket frame")
    opcode = first & 0x0F
    masked = second & 0x80
    length = second & 0x7F
    if length == 126:
        length = struct.unpack(">H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack(">Q", recv_exact(sock, 8))[0]
    if length > MAX_WEBSOCKET_PAYLOAD_BYTES:
        raise ProtocolError("WebSocket payload exceeds limit")
    if opcode >= 8 and (not fin or length > 125):
        raise ProtocolError("invalid control frame")
    if not masked:
        raise ProtocolError("client WebSocket frame is not masked")
    mask = recv_exact(sock, 4)
    payload = bytearray(recv_exact(sock, length))
    for index in range(length):
        payload[index] ^= mask[index % 4]
    return opcode, bytes(payload)


def send_websocket_frame(sock: socket.socket, opcode: int, payload: bytes) -> None:
    if opcode >= 8 and len(payload) > 125:
        raise ProtocolError("control payload exceeds limit")
    header = bytearray((0x80 | opcode,))
    length = len(payload)
    if length < 126:
        header.append(length)
    elif length <= 0xFFFF:
        header.append(126)
        header.extend(struct.pack(">H", length))
    else:
        header.append(127)
        header.extend(struct.pack(">Q", length))
    sock.sendall(bytes(header) + payload)


def send_close(sock: socket.socket, code: int = 1000) -> None:
    try:
        send_websocket_frame(sock, 8, struct.pack(">H", code))
    except (OSError, ProtocolError):
        pass


def serve_client(
    sock: socket.socket,
    address: tuple[object, ...],
    expected_auth_token: str | None,
    auth_token_file: str | None,
    metrics: GatewayMetrics,
    transport: str,
) -> None:
    handshake_complete = False
    websocket_admitted = False
    game_state = AuthoritativeGameState()
    scene_enabled = False
    full_scene_enabled = False
    last_game_sequence = 0
    try:
        sock.settimeout(30.0)
        request = receive_http_headers(sock)
        method, target, _ = parse_http_request(request)
        if method != "GET":
            raise HttpUpgradeError(400, "Bad Request")
        credential_source = auth_source(
            expected_auth_token, auth_token_file
        )
        if target == HEALTH_ROUTE:
            metrics.health_requests += 1
            body = json.dumps(
                metrics.health_payload(transport, credential_source),
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
            send_http_response(sock, 200, "OK", body, "application/json")
            return
        if target == METRICS_ROUTE:
            metrics.metrics_requests += 1
            body = metrics.metrics_text(
                transport, credential_source
            ).encode("utf-8")
            send_http_response(
                sock, 200, "OK", body, "text/plain; version=0.0.4"
            )
            return
        metrics.upgrade_attempts += 1
        if auth_token_file is not None:
            expected_auth_token = load_auth_token(auth_token_file)
        upgrade(sock, expected_auth_token, request)
        websocket_admitted = True
        metrics.websocket_sessions += 1
        metrics.active_sessions += 1
        print(f"websocket-upgrade peer={address[0]}:{address[1]}", flush=True)
        while True:
            opcode, payload = receive_websocket_frame(sock)
            metrics.received_frames += 1
            if opcode == 8:
                send_close(sock)
                return
            if opcode == 9:
                send_websocket_frame(sock, 10, payload)
                continue
            if opcode == 10:
                continue
            if opcode != 2:
                raise ProtocolError("only binary WebSocket frames are accepted")
            frame = decode_session_frame(payload)
            if not handshake_complete:
                if frame.kind != HELLO:
                    raise ProtocolError("hello is required before game traffic")
                send_websocket_frame(sock, 2, new_ack(frame.sequence, True))
                handshake_complete = True
                print(
                    f"session-accepted sequence={frame.sequence} "
                    "transport=websocket authority=bounded",
                    flush=True,
                )
                continue
            if frame.kind == PING:
                send_websocket_frame(sock, 2, new_pong(frame.sequence))
            elif frame.kind == GAME:
                if frame.sequence <= last_game_sequence:
                    raise ProtocolError("game sequence is not increasing")
                last_game_sequence = frame.sequence
                if len(frame.words) == 5:
                    response = encode_session_frame(
                        GAME, frame.sequence, list(frame.words)
                    )
                elif len(frame.words) == 7:
                    command = frame.words[4]
                    if command == GAME_SCENE_PROBE:
                        scene_enabled = True
                    elif command == GAME_FULL_SCENE_PROBE:
                        full_scene_enabled = True
                        game_state.full_mode = True
                    else:
                        game_state.apply_command(command, frame.words[5])
                        metrics.applied_commands += 1
                    if full_scene_enabled:
                        response = new_game_full_scene_snapshot(
                            game_state, frame.sequence
                        )
                    elif scene_enabled:
                        response = new_game_scene_snapshot(
                            game_state, frame.sequence
                        )
                    else:
                        response = new_game_snapshot(
                            game_state, frame.sequence
                        )
                else:
                    raise ProtocolError("client cannot send a game snapshot")
                send_websocket_frame(sock, 2, response)
            else:
                raise ProtocolError("unexpected post-handshake message")
    except (EOFError, OSError):
        return
    except HttpUpgradeError as error:
        metrics.upgrade_rejections += 1
        if error.status == 401:
            metrics.auth_rejections += 1
        print(f"upgrade-rejected status={error.status} reason={error.reason}",
              flush=True)
        send_http_rejection(sock, error.status, error.reason)
        return
    except ProtocolError as error:
        print(f"session-rejected reason={error}", flush=True)
        try:
            send_websocket_frame(sock, 2, new_error(1, 1))
        except (OSError, ProtocolError):
            pass
        send_close(sock, 1002)
    finally:
        if websocket_admitted:
            metrics.active_sessions -= 1
        sock.close()

def tls_context(certfile: str | None, keyfile: str | None) -> ssl.SSLContext | None:
    if (certfile is None) != (keyfile is None):
        raise SystemExit("--tls-certfile and --tls-keyfile must be provided together")
    if certfile is None or keyfile is None:
        return None
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(certfile, keyfile)
    return context


def serve(
    bind: str, port: int, once: bool,
    tls: ssl.SSLContext | None,
    auth_token: str | None,
    auth_token_file: str | None,
) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((bind, port))
        listener.listen(8)
        listener.settimeout(1.0)
        actual_port = listener.getsockname()[1]
        transport = "wss" if tls is not None else "ws"
        print(
            f"KOOKIE WebSocket session gateway listening on {bind}:{actual_port} "
            f"transport={transport}",
            flush=True,
        )
        metrics = GatewayMetrics()
        while True:
            try:
                raw_client, address = listener.accept()
            except socket.timeout:
                continue
            client = raw_client
            if tls is not None:
                try:
                    client = tls.wrap_socket(raw_client, server_side=True)
                except ssl.SSLError:
                    raw_client.close()
                    continue
            serve_client(
                client, address, auth_token, auth_token_file, metrics, transport
            )
            if once:
                return


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument(
        "--once", action="store_true", help="exit after the first client closes"
    )
    parser.add_argument("--tls-certfile")
    parser.add_argument("--tls-keyfile")
    auth_group = parser.add_mutually_exclusive_group()
    auth_group.add_argument("--auth-token")
    auth_group.add_argument("--auth-token-file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not 0 <= args.port <= 65535:
        raise SystemExit("port must be between 0 and 65535")
    if args.auth_token is not None and not valid_auth_token(args.auth_token):
        raise SystemExit(
            "auth token must be 8-128 ASCII letters, digits, '.', '_', '~' or '-'"
        )
    if args.auth_token_file is not None:
        try:
            load_auth_token(args.auth_token_file)
        except HttpUpgradeError as error:
            raise SystemExit(
                "auth token file must be a regular mode-0600-or-stricter file "
                "with one valid token"
            ) from error
    serve(
        args.bind, args.port, args.once,
        tls_context(args.tls_certfile, args.tls_keyfile),
        args.auth_token,
        args.auth_token_file,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
