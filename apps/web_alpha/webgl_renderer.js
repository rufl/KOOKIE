(() => {
  "use strict";

  const CAT_RENDER_SCALE = 1.14;
  const GOOSE_RENDER_SCALE = 4.8;
  const DUMMY_RENDER_SCALE = 0.35;

  const VERTEX_SHADER = `#version 300 es
    precision highp float;
    layout(location = 0) in vec3 aPosition;
    layout(location = 1) in vec3 aNormal;
    layout(location = 2) in vec2 aUv;
    layout(location = 3) in vec4 aJoints;
    layout(location = 4) in vec4 aWeights;
    uniform mat4 uViewProjection;
    uniform mat4 uModel;
    uniform mat4 uJoints[32];
    uniform vec2 uUvScale;
    uniform vec2 uUvOffset;
    uniform bool uUseSkinning;
    out vec3 vNormal;
    out vec3 vWorld;
    out vec2 vUv;
    void main() {
      vec4 localPosition = vec4(aPosition, 1.0);
      vec3 localNormal = aNormal;
      if (uUseSkinning) {
        mat4 skin = mat4(0.0);
        skin += aWeights.x * uJoints[int(clamp(aJoints.x, 0.0, 31.0))];
        skin += aWeights.y * uJoints[int(clamp(aJoints.y, 0.0, 31.0))];
        skin += aWeights.z * uJoints[int(clamp(aJoints.z, 0.0, 31.0))];
        skin += aWeights.w * uJoints[int(clamp(aJoints.w, 0.0, 31.0))];
        localPosition = skin * localPosition;
        localNormal = mat3(skin) * localNormal;
      }
      vec4 world = uModel * localPosition;
      vWorld = world.xyz;
      vNormal = mat3(uModel) * localNormal;
      vUv = aUv * uUvScale + uUvOffset;
      gl_Position = uViewProjection * world;
    }
  `;
  const FRAGMENT_SHADER = `#version 300 es
    precision highp float;
    in vec3 vNormal;
    in vec3 vWorld;
    in vec2 vUv;
    uniform vec4 uColor;
    uniform vec3 uLight;
    uniform float uTime;
    uniform float uWaterTime;
    uniform sampler2D uAlbedo;
    uniform bool uUseTexture;
    uniform bool uWater;
    uniform vec4 uWaterStyle;
    uniform vec4 uWaterTint;
    uniform vec4 uWaterToon;
    out vec4 outColor;
    void main() {
      if (uWater) {
        float phase = (vWorld.x + vWorld.z) * uWaterStyle.y +
          uWaterTime * uWaterStyle.z;
        float wave = sin(phase) * sin(phase * 0.73 + uWaterTime);
        float caustic = step(0.0, wave) * uWaterStyle.w;
        float toonLight = uWaterToon.x + caustic * uWaterToon.y;
        outColor = vec4(uWaterTint.rgb * toonLight, uWaterToon.z);
        return;
      }
      vec3 normal = normalize(vNormal);
      float diffuse = max(dot(normal, normalize(uLight)), 0.0);
      float toon = floor(clamp(diffuse * 0.86 + 0.14, 0.0, 1.0) * 3.0) / 3.0;
      vec4 albedo = uUseTexture ? texture(uAlbedo, vUv) : vec4(1.0);
      if (albedo.a < 0.08) discard;
      vec3 lit = uColor.rgb * albedo.rgb * (0.24 + toon * 0.76);
      lit += uColor.rgb * albedo.rgb *
        (0.04 * sin(uTime * 4.0 + vWorld.x * 0.04));
      float fog = clamp((length(vWorld - vec3(160.0, 0.0, 140.0)) - 80.0) / 600.0, 0.0, 1.0);
      lit = mix(lit, vec3(0.015, 0.035, 0.06), fog * 0.08);
      outColor = vec4(lit, albedo.a * uColor.a);
    }
  `;

  const MAX_SKIN_JOINTS = 32;
  const COLORS = Object.freeze({
    floor: [0.055, 0.14, 0.19, 1],
    wall: [0.12, 0.25, 0.30, 1],
    cover: [0.25, 0.35, 0.28, 1],
    player: [0.20, 0.70, 1.0, 1],
    actor: [0.92, 0.22, 0.34, 1],
    actorAlt: [0.20, 0.42, 1.0, 1],
    damaged: [0.28, 0.32, 0.38, 1],
    projectile: [1.0, 0.88, 0.20, 1],
    fireball: [1.0, 0.24, 0.035, 1],
    vfx: [1, 1, 1, 1],
    pickup: [0.30, 1.0, 0.58, 1],
    shadow: [0.015, 0.020, 0.025, 0.42],
    water: [0.05, 0.34, 0.45, 0.72],
  });
  const SCENE_OBJECT_KINDS = Object.freeze({
    door: 1,
    floatable: 2,
    powerup: 3,
    lootBeam: 4,
  });
  const SCENE_OBJECT_COLORS = Object.freeze({
    doorClosed: [0.76, 0.34, 0.16, 1],
    doorOpen: [0.30, 0.78, 0.44, 1],
    floatable: [0.44, 0.58, 0.70, 1],
    powerup: [0.30, 1.0, 0.58, 1],
    lootBeam: [1.0, 0.70, 0.22, 1],
  });

  const ARENA_SOLIDS = Object.freeze([
    { box: [0, 0, 0, 4, 24, 280], material: 8, color: COLORS.wall },
    { box: [316, 0, 0, 320, 24, 280], material: 8, color: COLORS.wall },
    { box: [4, 0, 0, 316, 24, 4], material: 8, color: COLORS.wall },
    { box: [4, 0, 276, 316, 24, 280], material: 8, color: COLORS.wall },
    { box: [92, 6, 146, 228, 9, 158], material: 5, color: [0.24, 0.30, 0.38, 1] },
    { box: [154, 6, 92, 166, 9, 146], material: 5, color: [0.24, 0.30, 0.38, 1] },
    { box: [154, 6, 158, 166, 9, 212], material: 5, color: [0.24, 0.30, 0.38, 1] },
    { box: [228, 6, 66, 308, 9, 78], material: 5, color: [0.24, 0.30, 0.38, 1] },
    { box: [36, 8, 64, 96, 11, 216], material: 6, color: [0.30, 0.36, 0.28, 1] },
    { box: [224, 8, 64, 284, 11, 216], material: 6, color: [0.30, 0.36, 0.28, 1] },
    { box: [48, 16, 16, 272, 18, 48], material: 7, color: [0.18, 0.25, 0.28, 1] },
    { box: [48, 16, 232, 272, 18, 264], material: 7, color: [0.18, 0.25, 0.28, 1] },
    { box: [64, 0, 112, 88, 14, 136], material: 4, color: [0.48, 0.18, 0.22, 1] },
    { box: [232, 0, 144, 256, 14, 168], material: 4, color: [0.48, 0.18, 0.22, 1] },
    { box: [112, 0, 72, 132, 5, 92], material: 3, color: COLORS.cover },
    { box: [188, 0, 184, 208, 5, 204], material: 3, color: COLORS.cover },
  ]);
  const WATER_STYLES = Object.freeze([
    Object.freeze({
      style: [1, 0.7, 0.12, 0.16],
      tint: [0.12, 0.56, 0.90, 1],
      toon: [0.68, 0.28, 0.84, 1],
    }),
    Object.freeze({
      style: [1, 0.9, 0.10, 0.12],
      tint: [0.09, 0.47, 0.82, 1],
      toon: [0.65, 0.25, 0.80, 1],
    }),
  ]);
  const ARENA_WATER = Object.freeze([
    Object.freeze({ bounds: [96, 5, 96, 188, 208], style: WATER_STYLES[0] }),
    Object.freeze({ bounds: [208, 5, 96, 224, 208], style: WATER_STYLES[0] }),
    Object.freeze({ bounds: [188, 5, 96, 208, 184], style: WATER_STYLES[0] }),
    Object.freeze({ bounds: [188, 5, 204, 208, 208], style: WATER_STYLES[0] }),
    Object.freeze({ bounds: [232, 4, 32, 304, 112], style: WATER_STYLES[1] }),
  ]);
  const ARENA_RAMPS = Object.freeze([
    {
      vertices: [[20, 0, 56], [20, 0, 80], [40, 8, 80], [40, 8, 56]],
      material: 6,
      color: [0.30, 0.38, 0.32, 1],
    },
    {
      vertices: [[280, 8, 200], [280, 8, 224], [300, 0, 224], [300, 0, 200]],
      material: 6,
      color: [0.30, 0.38, 0.32, 1],
    },
  ]);

  const ARENA_MAPS = Object.freeze({
    1: Object.freeze({ solids: ARENA_SOLIDS, ramps: ARENA_RAMPS }),
    2: Object.freeze({
      solids: Object.freeze([
        { box: [0, 0, 0, 4, 24, 280], material: 8, color: COLORS.wall },
        { box: [316, 0, 0, 320, 24, 280], material: 8, color: COLORS.wall },
        { box: [4, 0, 0, 316, 24, 4], material: 8, color: COLORS.wall },
        { box: [4, 0, 276, 316, 24, 280], material: 8, color: COLORS.wall },
        { box: [48, 0, 56, 76, 16, 84], material: 4, color: [0.48, 0.18, 0.22, 1] },
        { box: [244, 0, 196, 272, 16, 224], material: 4, color: [0.48, 0.18, 0.22, 1] },
        { box: [112, 4, 36, 208, 7, 52], material: 5, color: [0.24, 0.30, 0.38, 1] },
        { box: [112, 4, 228, 208, 7, 244], material: 5, color: [0.24, 0.30, 0.38, 1] },
        { box: [84, 8, 104, 100, 11, 176], material: 6, color: [0.30, 0.36, 0.28, 1] },
        { box: [220, 8, 104, 236, 11, 176], material: 6, color: [0.30, 0.36, 0.28, 1] },
        { box: [128, 0, 128, 192, 4, 152], material: 3, color: COLORS.cover },
        { box: [128, 0, 184, 192, 4, 208], material: 3, color: COLORS.cover },
      ]),
      ramps: Object.freeze([
        {
          vertices: [[76, 0, 60], [100, 0, 60], [100, 8, 104], [76, 8, 104]],
          material: 6,
          color: [0.30, 0.38, 0.32, 1],
        },
        {
          vertices: [[220, 8, 176], [244, 8, 176], [244, 0, 220], [220, 0, 220]],
          material: 6,
          color: [0.30, 0.38, 0.32, 1],
        },
      ]),
    }),
  });
  function arenaMap(mapId) {
    return ARENA_MAPS[mapId] || ARENA_MAPS[1];
  }

  const ARENA_RAMP_TRIANGLES = Object.freeze([[0, 1, 2], [0, 2, 3]]);

  const arenaGroundSample = { height: 0, slopeX: 0, slopeZ: 0 };
  function arenaGroundAt(x, z, actorY, mapId = 1) {
    arenaGroundSample.height = 0;
    arenaGroundSample.slopeX = 0;
    arenaGroundSample.slopeZ = 0;
    const geometry = arenaMap(mapId);
    for (const solid of geometry.solids) {
      const box = solid.box;
      if (x < box[0] || x > box[3] || z < box[2] || z > box[5] ||
          box[4] > actorY - 0.5 ||
          box[4] < arenaGroundSample.height) continue;
      arenaGroundSample.height = box[4];
      arenaGroundSample.slopeX = 0;
      arenaGroundSample.slopeZ = 0;
    }
    for (const ramp of geometry.ramps) {
      const vertices = ramp.vertices;
      for (const triangle of ARENA_RAMP_TRIANGLES) {
        const a = vertices[triangle[0]], b = vertices[triangle[1]],
          c = vertices[triangle[2]];
        const denominator = (b[2] - c[2]) * (a[0] - c[0]) +
          (c[0] - b[0]) * (a[2] - c[2]);
        if (Math.abs(denominator) < 1e-6) continue;
        const wa = ((b[2] - c[2]) * (x - c[0]) +
          (c[0] - b[0]) * (z - c[2])) / denominator;
        const wb = ((c[2] - a[2]) * (x - c[0]) +
          (a[0] - c[0]) * (z - c[2])) / denominator;
        const wc = 1 - wa - wb;
        if (wa < 0 || wb < 0 || wc < 0) continue;
        const height = wa * a[1] + wb * b[1] + wc * c[1];
        if (height > actorY - 0.5 ||
            height < arenaGroundSample.height) continue;
        const dx1 = b[0] - a[0], dz1 = b[2] - a[2];
        const dx2 = c[0] - a[0], dz2 = c[2] - a[2];
        const slopeDenominator = dx1 * dz2 - dx2 * dz1;
        arenaGroundSample.height = height;
        arenaGroundSample.slopeX = (
          (b[1] - a[1]) * dz2 - (c[1] - a[1]) * dz1
        ) / slopeDenominator;
        arenaGroundSample.slopeZ = (
          dx1 * (c[1] - a[1]) - dx2 * (b[1] - a[1])
        ) / slopeDenominator;
      }
    }
    return arenaGroundSample;
  }

  const VFX_ASSETS = Object.freeze([
    { id: 0, name: "circle", path: "assets/prototype/vfx/particles/circle_01_a.png", columns: 1, rows: 1, frameMs: 260, scale: 7 },
    { id: 1, name: "fire", path: "assets/prototype/vfx/particles/fire_01_a.png", columns: 1, rows: 1, frameMs: 260, scale: 7 },
    { id: 2, name: "smoke", path: "assets/prototype/vfx/particles/smoke_01_a.png", columns: 1, rows: 1, frameMs: 320, scale: 8 },
    { id: 3, name: "spark", path: "assets/prototype/vfx/particles/spark_01_a.png", columns: 1, rows: 1, frameMs: 180, scale: 6 },
    { id: 4, name: "magic", path: "assets/prototype/vfx/particles/magic_01_a.png", columns: 1, rows: 1, frameMs: 300, scale: 8 },
    { id: 5, name: "slash", path: "assets/prototype/vfx/particles/slash_01_a.png", columns: 1, rows: 1, frameMs: 260, scale: 7 },
    { id: 6, name: "flare", path: "assets/prototype/vfx/particles/flare_01_a.png", columns: 1, rows: 1, frameMs: 180, scale: 7 },
    { id: 7, name: "scorch", path: "assets/prototype/vfx/particles/scorch_01_a.png", columns: 1, rows: 1, frameMs: 420, scale: 7 },
    { id: 8, name: "explosion", path: "assets/prototype/vfx/flipbooks/explosion_01_8x8.png", columns: 8, rows: 8, frameMs: 55, scale: 10 },
    { id: 9, name: "explosion-smoke", path: "assets/prototype/vfx/flipbooks/explosion_smoke_01_8x8.png", columns: 8, rows: 8, frameMs: 55, scale: 10 },
    { id: 10, name: "fire-flipbook", path: "assets/prototype/vfx/flipbooks/fire_01_8x8.png", columns: 8, rows: 8, frameMs: 55, scale: 8 },
    { id: 11, name: "wispy-smoke", path: "assets/prototype/vfx/flipbooks/wispy_smoke_01_8x8.png", columns: 8, rows: 8, frameMs: 65, scale: 9 },
    { id: 12, name: "predrawn-explosion", path: "assets/prototype/vfx/predrawn/explosion_6x5.png", columns: 6, rows: 5, frameMs: 55, scale: 10 },
    { id: 13, name: "electric-ring", path: "assets/prototype/vfx/predrawn/electric_ring_6x5.png", columns: 6, rows: 5, frameMs: 55, scale: 9 },
    { id: 14, name: "fire-point", path: "assets/prototype/vfx/predrawn/fire_point_6x5.png", columns: 6, rows: 5, frameMs: 55, scale: 8 },
    { id: 15, name: "impact", path: "assets/prototype/vfx/predrawn/impact_white_6x4.png", columns: 6, rows: 4, frameMs: 55, scale: 7 },
    { id: 16, name: "melee-hit-spark", path: "assets/prototype/vfx/predrawn/hitspark_star3_7x1.png", columns: 7, rows: 1, frameCount: 7, frameMs: 40, scale: 9 },
    { id: 17, name: "movement-smoke", path: "assets/prototype/vfx/predrawn/smoke_ground_1a_1.png", columns: 9, rows: 1, frameCount: 9, frameMs: 60, scale: 8 },
  ]);

  const VFX_LEGACY_STYLE_ASSET = Object.freeze({ 1: 5, 2: 8 });
  const MULTIPLAYER_IMPACT_ASSET = Object.freeze({
    1: 15,
    2: 16,
    3: 15,
    4: 8,
    5: 8,
    6: 11,
    7: 16,
    8: 15,
  });
  const THROWABLE_VISUALS = Object.freeze({
    1: { mesh: "projectile", scale: [2.2, 2.2, 2.2], pickupScale: [4.0, 4.0, 4.0], color: [0.9, 0.12, 0.12, 1] },
    2: { mesh: "solid", scale: [2.2, 3.0, 2.2], pickupScale: [4.0, 5.4, 4.0], color: [0.94, 0.91, 0.8, 1] },
    3: { mesh: "pickup", scale: [2.8, 2.8, 2.8], pickupScale: [5.0, 5.0, 5.0], color: [0.12, 0.66, 0.23, 1] },
    4: { mesh: "solid", scale: [3.5, 3.0, 3.5], pickupScale: [6.3, 5.4, 6.3], color: [0.48, 0.25, 0.12, 1] },
    5: { mesh: "projectile", scale: [3.0, 2.4, 3.0], pickupScale: [5.4, 4.3, 5.4], color: [0.48, 0.52, 0.57, 1] },
  });

  const MAX_MULTIPLAYER_IMPACT_EFFECTS = 32;


  function compileShader(gl, type, source) {
    const shader = gl.createShader(type);
    if (!shader) throw new Error("WebGL shader allocation failed");
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      const log = gl.getShaderInfoLog(shader) || "unknown shader error";
      gl.deleteShader(shader);
      throw new Error(log);
    }
    return shader;
  }

  function createProgram(gl) {
    const program = gl.createProgram();
    if (!program) throw new Error("WebGL program allocation failed");
    const vertex = compileShader(gl, gl.VERTEX_SHADER, VERTEX_SHADER);
    const fragment = compileShader(gl, gl.FRAGMENT_SHADER, FRAGMENT_SHADER);
    gl.attachShader(program, vertex);
    gl.attachShader(program, fragment);
    gl.linkProgram(program);
    gl.deleteShader(vertex);
    gl.deleteShader(fragment);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      const log = gl.getProgramInfoLog(program) || "unknown program error";
      gl.deleteProgram(program);
      throw new Error(log);
    }
    return program;
  }

  function identity() {
    return [
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ];
  }

  function multiply(a, b) {
    const out = new Array(16).fill(0);
    for (let column = 0; column < 4; column += 1) {
      for (let row = 0; row < 4; row += 1) {
        for (let index = 0; index < 4; index += 1) {
          out[column * 4 + row] += a[index * 4 + row] * b[column * 4 + index];
        }
      }
    }
    return out;
  }

  function perspective(fov, aspect, near, far) {
    const f = 1 / Math.tan(fov / 2);
    const range = 1 / (near - far);
    return [
      f / aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (near + far) * range, -1,
      0, 0, near * far * 2 * range, 0,
    ];
  }

  function normalize(vector) {
    const length = Math.hypot(vector[0], vector[1], vector[2]) || 1;
    return vector.map((value) => value / length);
  }

  function cross(a, b) {
    return [
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0],
    ];
  }

  function lookAt(eye, target, up) {
    const forward = normalize([
      target[0] - eye[0], target[1] - eye[1], target[2] - eye[2],
    ]);
    const side = normalize(cross(forward, up));
    const correctedUp = cross(side, forward);
    return [
      side[0], correctedUp[0], -forward[0], 0,
      side[1], correctedUp[1], -forward[1], 0,
      side[2], correctedUp[2], -forward[2], 0,
      -side[0] * eye[0] - side[1] * eye[1] - side[2] * eye[2],
      -correctedUp[0] * eye[0] - correctedUp[1] * eye[1] - correctedUp[2] * eye[2],
      forward[0] * eye[0] + forward[1] * eye[1] + forward[2] * eye[2],
      1,
    ];
  }

  function transform(position, scale, rotationY = 0, rotationZ = 0, rotationX = 0) {
    const c = Math.cos(rotationY);
    const s = Math.sin(rotationY);
    const rzC = Math.cos(rotationZ);
    const rzS = Math.sin(rotationZ);
    const rxC = Math.cos(rotationX);
    const rxS = Math.sin(rotationX);
    return [
      c * rzC * scale[0], rzS * scale[0], -s * rzC * scale[0], 0,
      (-c * rzS * rxC + s * rxS) * scale[1],
      (rzC * rxC) * scale[1],
      (s * rzS * rxC + c * rxS) * scale[1], 0,
      (c * rzS * rxS + s * rxC) * scale[2],
      -rzC * rxS * scale[2],
      (-s * rzS * rxS + c * rxC) * scale[2], 0,
      position[0], position[1], position[2], 1,
    ];
  }
  function actorAnimationLift(actor, tick) {
    const action = Number.isInteger(actor.animation) ? actor.animation : 0;
    const actorId = Number.isInteger(actor.id) ? actor.id : 0;
    const animationTick = Number.isFinite(tick) ? Math.trunc(tick) : 0;
    const phase = ((animationTick + actorId * 2) % 8 + 8) % 8;
    if (action === 2) return 0.4;
    if ((action === 1 || action === 6 || action === 8 || action === 9) &&
        phase >= 4) return action === 8 ? 0.12 : 0.2;
    return 0;
  }


  function createMesh(
    gl, positions, normals, uvs, indices, color, texture = null, localModel = null,
    joints = null, weights = null, skinNode = null,
  ) {
    const vertexCount = positions.length / 3;
    if (!Number.isInteger(vertexCount) || vertexCount <= 0 ||
        positions.length !== vertexCount * 3 ||
        indices.length % 3 !== 0 ||
        indices.some((index) => index < 0 || index >= vertexCount)) {
      throw new Error("invalid WebGL mesh geometry");
    }
    const generatedNormals = normals && normals.length === positions.length
      ? new Float32Array(normals) : new Float32Array(positions.length);
    if (!normals || normals.length !== positions.length) {
      for (let index = 0; index < indices.length; index += 3) {
        const ia = indices[index] * 3;
        const ib = indices[index + 1] * 3;
        const ic = indices[index + 2] * 3;
        const a = [positions[ia], positions[ia + 1], positions[ia + 2]];
        const b = [positions[ib], positions[ib + 1], positions[ib + 2]];
        const c = [positions[ic], positions[ic + 1], positions[ic + 2]];
        const normal = normalize(cross(
          [b[0] - a[0], b[1] - a[1], b[2] - a[2]],
          [c[0] - a[0], c[1] - a[1], c[2] - a[2]],
        ));
        for (const vertex of [ia, ib, ic]) {
          generatedNormals[vertex] += normal[0];
          generatedNormals[vertex + 1] += normal[1];
          generatedNormals[vertex + 2] += normal[2];
        }
      }
      for (let index = 0; index < vertexCount; index += 1) {
        const offset = index * 3;
        const normal = normalize([
          generatedNormals[offset], generatedNormals[offset + 1], generatedNormals[offset + 2],
        ]);
        generatedNormals[offset] = normal[0];
        generatedNormals[offset + 1] = normal[1];
        generatedNormals[offset + 2] = normal[2];
      }
    }
    const generatedUvs = uvs && uvs.length === vertexCount * 2
      ? new Float32Array(uvs) : new Float32Array(vertexCount * 2);
    const interleaved = new Float32Array(vertexCount * 8);
    for (let index = 0; index < vertexCount; index += 1) {
      const vertexOffset = index * 8;
      interleaved.set(positions.slice(index * 3, index * 3 + 3), vertexOffset);
      interleaved.set(generatedNormals.slice(index * 3, index * 3 + 3), vertexOffset + 3);
      interleaved.set(generatedUvs.slice(index * 2, index * 2 + 2), vertexOffset + 6);
    }
    const hasJoints = joints !== null;
    const hasWeights = weights !== null;
    if (hasJoints !== hasWeights) throw new Error("incomplete WebGL skin attributes");
    const skinning = hasJoints &&
      joints.length === vertexCount * 4 && weights.length === vertexCount * 4;
    if (hasJoints && !skinning) throw new Error("invalid WebGL skin attributes");
    const skinInterleaved = skinning ? new Float32Array(vertexCount * 8) : null;
    if (skinning) {
      for (let index = 0; index < vertexCount; index += 1) {
        const vertexOffset = index * 8;
        skinInterleaved.set(joints.slice(index * 4, index * 4 + 4), vertexOffset);
        skinInterleaved.set(weights.slice(index * 4, index * 4 + 4), vertexOffset + 4);
      }
    }
    const vao = gl.createVertexArray();
    const vbo = gl.createBuffer();
    const skinVbo = skinning ? gl.createBuffer() : null;
    const ibo = gl.createBuffer();
    if (!vao || !vbo || !ibo || (skinning && !skinVbo)) {
      throw new Error("WebGL mesh allocation failed");
    }
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, interleaved, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 32, 0);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 32, 12);
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 2, gl.FLOAT, false, 32, 24);
    if (skinning) {
      gl.bindBuffer(gl.ARRAY_BUFFER, skinVbo);
      gl.bufferData(gl.ARRAY_BUFFER, skinInterleaved, gl.STATIC_DRAW);
      gl.enableVertexAttribArray(3);
      gl.vertexAttribPointer(3, 4, gl.FLOAT, false, 32, 0);
      gl.enableVertexAttribArray(4);
      gl.vertexAttribPointer(4, 4, gl.FLOAT, false, 32, 16);
    }
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint32Array(indices), gl.STATIC_DRAW);
    gl.bindVertexArray(null);
    return Object.freeze({
      vao, vbo, skinVbo, ibo, count: indices.length, color: color || COLORS.wall,
      texture, localModel: localModel || identity(),
      skinned: Boolean(skinning && skinNode !== null), skinNode,
    });
  }

  function boxGeometry(gl, size, color, texture = null, omitBottom = false) {
    const [width, height, depth] = size.map((value) => value / 2);
    const positions = new Float32Array([
      -width, -height, depth, width, -height, depth, width, height, depth, -width, height, depth,
      width, -height, -depth, -width, -height, -depth, -width, height, -depth, width, height, -depth,
      -width, -height, -depth, -width, -height, depth, -width, height, depth, -width, height, -depth,
      width, -height, depth, width, -height, -depth, width, height, -depth, width, height, depth,
      -width, height, depth, width, height, depth, width, height, -depth, -width, height, -depth,
      -width, -height, -depth, width, -height, -depth, width, -height, depth, -width, -height, depth,
    ]);
    const normals = new Float32Array([
      0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1,
      0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1,
      -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0,
      1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0,
      0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0,
      0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0,
    ]);
    const uvs = new Float32Array([
      0, 0, 1, 0, 1, 1, 0, 1,
      0, 0, 1, 0, 1, 1, 0, 1,
      0, 0, 1, 0, 1, 1, 0, 1,
      0, 0, 1, 0, 1, 1, 0, 1,
      0, 0, 1, 0, 1, 1, 0, 1,
      0, 0, 1, 0, 1, 1, 0, 1,
    ]);
    const indices = [];
    for (let face = 0; face < 6; face += 1) {
      if (omitBottom && face === 5) continue;
      const offset = face * 4;
      indices.push(offset, offset + 1, offset + 2, offset, offset + 2, offset + 3);
    }
    return createMesh(gl, positions, normals, uvs, indices, color, texture);
  }
  function diamondGeometry(gl, color) {
    const positions = new Float32Array([
      0, 0.5, 0, 0.5, 0, 0, 0, 0, 0.5,
      -0.5, 0, 0, 0, -0.5, 0, 0, 0, -0.5,
    ]);
    const indices = [
      0, 4, 1, 0, 1, 5, 0, 5, 3, 0, 3, 4,
      2, 1, 4, 2, 5, 1, 2, 3, 5, 2, 4, 3,
    ];
    return createMesh(gl, positions, null, null, indices, color);
  }
  function createWorldMaterialTexture(gl) {
    const width = 256;
    const height = 128;
    const tileSize = 64;
    const colors = [
      [92, 102, 112], [42, 118, 156], [156, 68, 52], [126, 116, 88],
      [54, 124, 74], [172, 128, 42], [86, 68, 142], [36, 42, 50],
    ];
    const pixels = new Uint8Array(width * height * 4);
    for (let material = 0; material < colors.length; material += 1) {
      const tileX = (material % 4) * tileSize;
      const tileY = Math.floor(material / 4) * tileSize;
      for (let y = 0; y < tileSize; y += 1) {
        for (let x = 0; x < tileSize; x += 1) {
          let shade = -8;
          if ((Math.floor(x / 8) + Math.floor(y / 8) + material) % 2 === 0) {
            shade = 14;
          }
          if (material === 2 &&
              (y % 16 < 2 || (x + Math.floor(y / 16) * 12) % 32 < 2)) {
            shade = -30;
          }
          if (material === 5 && (x + y) % 20 < 8) shade = 26;
          if (material === 7 && (x % 16 < 2 || y % 16 < 2)) shade = 28;
          const offset = ((tileY + y) * width + tileX + x) * 4;
          pixels[offset] = Math.max(0, Math.min(255, colors[material][0] + shade));
          pixels[offset + 1] = Math.max(0, Math.min(255, colors[material][1] + shade));
          pixels[offset + 2] = Math.max(0, Math.min(255, colors[material][2] + shade));
          pixels[offset + 3] = 255;
        }
      }
    }
    const texture = gl.createTexture();
    if (!texture) return null;
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
    gl.texImage2D(
      gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0,
      gl.RGBA, gl.UNSIGNED_BYTE, pixels,
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.bindTexture(gl.TEXTURE_2D, null);
    return texture;
  }
  function createBlobShadowTexture(gl) {
    const size = 64;
    const pixels = new Uint8Array(size * size * 4);
    for (let y = 0; y < size; y += 1) {
      for (let x = 0; x < size; x += 1) {
        const dx = (x + 0.5 - size / 2) / (size / 2);
        const dy = (y + 0.5 - size / 2) / (size / 2);
        const radius = Math.min(1, Math.hypot(dx, dy));
        const edge = 1 - radius;
        const alpha = Math.round(255 * edge * edge * (1 + 2 * radius));
        const offset = (y * size + x) * 4;
        pixels[offset] = pixels[offset + 1] = pixels[offset + 2] = 255;
        pixels[offset + 3] = alpha;
      }
    }
    const texture = gl.createTexture();
    if (!texture) return null;
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, size, size, 0,
      gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.bindTexture(gl.TEXTURE_2D, null);
    return texture;
  }

  const WORLD_MATERIAL_UVS = Object.freeze([
    [0, 0.5, 0.25, 0.5], [0.25, 0.5, 0.25, 0.5],
    [0.5, 0.5, 0.25, 0.5], [0.75, 0.5, 0.25, 0.5],
    [0, 0, 0.25, 0.5], [0.25, 0, 0.25, 0.5],
    [0.5, 0, 0.25, 0.5], [0.75, 0, 0.25, 0.5],
  ]);
  function worldMaterialUv(resource) {
    const tile = Math.max(0, Math.min(7, resource - 1));
    return WORLD_MATERIAL_UVS[tile];
  }
  function planeGeometry(gl, color, texture) {
    const positions = new Float32Array([
      -0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0,
    ]);
    const normals = new Float32Array([
      0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1,
    ]);
    const uvs = new Float32Array([0, 0, 1, 0, 1, 1, 0, 1]);
    return createMesh(
      gl, positions, normals, uvs, [0, 1, 2, 0, 2, 3], color, texture,
    );
  }

  function horizontalPlaneGeometry(gl, color, texture = null) {
    const positions = new Float32Array([
      -0.5, 0, -0.5, 0.5, 0, -0.5, 0.5, 0, 0.5, -0.5, 0, 0.5,
    ]);
    const normals = new Float32Array([
      0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0,
    ]);
    const uvs = new Float32Array([0, 0, 1, 0, 1, 1, 0, 1]);
    return createMesh(
      gl, positions, normals, uvs, [0, 1, 2, 0, 2, 3], color, texture,
    );
  }
  function rampGeometry(gl, top, color, texture = null) {
    const bottom = top.map(([x, , z]) => [x, 0, z]);
    const positions = new Float32Array([...top, ...bottom].flat());
    const uvs = new Float32Array([
      0, 0, 1, 0, 1, 1, 0, 1,
      0, 0, 1, 0, 1, 1, 0, 1,
    ]);
    const indices = [
      0, 1, 2, 0, 2, 3,
      0, 4, 5, 0, 5, 1,
      1, 5, 6, 1, 6, 2,
      2, 6, 7, 2, 7, 3,
      3, 7, 4, 3, 4, 0,
    ];
    return createMesh(gl, positions, null, uvs, indices, color, texture);
  }


  function readComponent(view, offset, componentType) {
    if (componentType === 5126) return view.getFloat32(offset, true);
    if (componentType === 5125) return view.getUint32(offset, true);
    if (componentType === 5123) return view.getUint16(offset, true);
    if (componentType === 5122) return view.getInt16(offset, true);
    if (componentType === 5121) return view.getUint8(offset);
    if (componentType === 5120) return view.getInt8(offset);
    throw new Error("unsupported GLB accessor component");
  }

  function normalizeAccessorComponent(value, componentType, normalized) {
    if (!normalized || componentType === 5126) return value;
    if (componentType === 5120) return Math.max(value / 127, -1);
    if (componentType === 5121) return value / 255;
    if (componentType === 5122) return Math.max(value / 32767, -1);
    if (componentType === 5123) return value / 65535;
    if (componentType === 5125) return value / 4294967295;
    return value;
  }

  function accessorValues(json, binary, accessorIndex) {
    const accessor = json.accessors?.[accessorIndex];
    const bufferView = accessor && json.bufferViews?.[accessor.bufferView];
    const componentCount = {
      SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16,
    }[accessor?.type];
    const componentSize = {
      5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4,
    }[accessor?.componentType];
    if (!accessor || !bufferView || !componentCount || !componentSize ||
        !Number.isInteger(accessor.count) || accessor.count < 0) {
      throw new Error("invalid GLB accessor");
    }
    const stride = bufferView.byteStride || componentSize * componentCount;
    const base = (bufferView.byteOffset || 0) + (accessor.byteOffset || 0);
    const view = new DataView(binary);
    const end = base + Math.max(0, accessor.count - 1) * stride +
      componentSize * componentCount;
    if (base < 0 || end > binary.byteLength) throw new Error("GLB accessor bounds");
    const values = new Array(accessor.count * componentCount);
    for (let index = 0; index < accessor.count; index += 1) {
      for (let component = 0; component < componentCount; component += 1) {
        const value = readComponent(
          view, base + index * stride + component * componentSize,
          accessor.componentType,
        );
        values[index * componentCount + component] =
          normalizeAccessorComponent(value, accessor.componentType, accessor.normalized);
      }
    }
    return values;
  }

  function parseGlb(buffer) {
    if (buffer.byteLength < 20) throw new Error("GLB header truncated");
    const data = new DataView(buffer);
    if (data.getUint32(0, true) !== 0x46546c67 ||
        data.getUint32(4, true) !== 2 ||
        data.getUint32(8, true) !== buffer.byteLength) {
      throw new Error("GLB header rejected");
    }
    let cursor = 12;
    let jsonText = null;
    let binary = new ArrayBuffer(0);
    while (cursor + 8 <= buffer.byteLength) {
      const length = data.getUint32(cursor, true);
      const type = data.getUint32(cursor + 4, true);
      const start = cursor + 8;
      const end = start + length;
      if (end > buffer.byteLength || (length & 3) !== 0) {
        throw new Error("GLB chunk bounds rejected");
      }
      if (type === 0x4e4f534a) {
        if (jsonText !== null) throw new Error("duplicate GLB JSON chunk");
        jsonText = new TextDecoder().decode(new Uint8Array(buffer, start, length))
          .replace(/\u0000+$/, "").trim();
      } else if (type === 0x004e4942) {
        if (binary.byteLength !== 0) throw new Error("duplicate GLB BIN chunk");
        binary = buffer.slice(start, end);
      } else if (cursor === 12) {
        throw new Error("GLB JSON chunk missing");
      }
      cursor = end;
    }
    if (cursor !== buffer.byteLength || jsonText === null) {
      throw new Error("GLB chunks truncated");
    }
    return { json: JSON.parse(jsonText), binary };
  }

  async function imageFromBlob(blob) {
    if (typeof createImageBitmap === "function") return createImageBitmap(blob);
    if (typeof Image === "undefined" || typeof URL === "undefined") {
      throw new Error("browser image decoder unavailable");
    }
    const objectUrl = URL.createObjectURL(blob);
    try {
      return await new Promise((resolve, reject) => {
        const image = new Image();
        image.onload = () => resolve(image);
        image.onerror = () => reject(new Error("image decode failed"));
        image.src = objectUrl;
      });
    } finally {
      URL.revokeObjectURL(objectUrl);
    }
  }

  async function textureFromBlob(gl, blob) {
    const image = await imageFromBlob(blob);
    const texture = gl.createTexture();
    if (!texture) throw new Error("WebGL texture allocation failed");
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.bindTexture(gl.TEXTURE_2D, null);
    if (typeof image.close === "function") image.close();
    return texture;
  }

  function nodeMatrix(node) {
    if (Array.isArray(node.matrix) && node.matrix.length === 16) return node.matrix.slice();
    const translation = node.translation || [0, 0, 0];
    const rotation = node.rotation || [0, 0, 0, 1];
    const scale = node.scale || [1, 1, 1];
    const [x, y, z, w] = rotation;
    const xx = x * x;
    const yy = y * y;
    const zz = z * z;
    const xy = x * y;
    const xz = x * z;
    const yz = y * z;
    const wx = w * x;
    const wy = w * y;
    const wz = w * z;
    return [
      (1 - 2 * (yy + zz)) * scale[0], (2 * (xy + wz)) * scale[0],
      (2 * (xz - wy)) * scale[0], 0,
      (2 * (xy - wz)) * scale[1], (1 - 2 * (xx + zz)) * scale[1],
      (2 * (yz + wx)) * scale[1], 0,
      (2 * (xz + wy)) * scale[2], (2 * (yz - wx)) * scale[2],
      (1 - 2 * (xx + yy)) * scale[2], 0,
      translation[0], translation[1], translation[2], 1,
    ];
  }

  function composeNodeMatrix(translation, rotation, scale) {
    return nodeMatrix({ translation, rotation, scale });
  }

  function invertMatrix(matrix) {
    const rows = Array.from({ length: 4 }, (_, row) => [
      matrix[row], matrix[4 + row], matrix[8 + row], matrix[12 + row],
      row === 0 ? 1 : 0, row === 1 ? 1 : 0,
      row === 2 ? 1 : 0, row === 3 ? 1 : 0,
    ]);
    for (let column = 0; column < 4; column += 1) {
      let pivotRow = column;
      for (let row = column + 1; row < 4; row += 1) {
        if (Math.abs(rows[row][column]) >
            Math.abs(rows[pivotRow][column])) {
          pivotRow = row;
        }
      }
      const pivot = rows[pivotRow][column];
      if (!Number.isFinite(pivot) || Math.abs(pivot) < 1e-8) return null;
      if (pivotRow !== column) {
        [rows[column], rows[pivotRow]] = [rows[pivotRow], rows[column]];
      }
      const pivotValues = rows[column];
      for (let entry = 0; entry < 8; entry += 1) {
        pivotValues[entry] /= pivot;
      }
      for (let row = 0; row < 4; row += 1) {
        if (row === column) continue;
        const values = rows[row];
        const factor = values[column];
        if (factor === 0) continue;
        for (let entry = 0; entry < 8; entry += 1) {
          values[entry] -= factor * pivotValues[entry];
        }
      }
    }
    const inverse = new Array(16);
    for (let row = 0; row < 4; row += 1) {
      for (let column = 0; column < 4; column += 1) {
        inverse[column * 4 + row] = rows[row][4 + column];
      }
    }
    return inverse;
  }

  function normalizeQuaternion(quaternion) {
    const length = Math.hypot(
      quaternion[0], quaternion[1], quaternion[2], quaternion[3],
    );
    if (!Number.isFinite(length) || length < 1e-8) return [0, 0, 0, 1];
    return quaternion.map((value) => value / length);
  }

  function slerpQuaternion(first, second, amount) {
    let b = second;
    let cosine = first[0] * second[0] + first[1] * second[1] +
      first[2] * second[2] + first[3] * second[3];
    if (cosine < 0) {
      cosine = -cosine;
      b = second.map((value) => -value);
    }
    if (cosine > 0.9995) {
      return normalizeQuaternion(first.map((value, index) =>
        value + (b[index] - value) * amount));
    }
    const angle = Math.acos(Math.max(-1, Math.min(1, cosine)));
    const sine = Math.sin(angle) || 1;
    const firstScale = Math.sin((1 - amount) * angle) / sine;
    const secondScale = Math.sin(amount * angle) / sine;
    return [
      first[0] * firstScale + b[0] * secondScale,
      first[1] * firstScale + b[1] * secondScale,
      first[2] * firstScale + b[2] * secondScale,
      first[3] * firstScale + b[3] * secondScale,
    ];
  }

  function sampleAnimationChannel(channel, time) {
    const times = channel.times;
    const values = channel.values;
    const components = channel.components;
    if (time <= times[0]) return values.slice(0, components);
    if (time >= times[times.length - 1]) {
      const lastOffset = (times.length - 1) * components;
      return values.slice(lastOffset, lastOffset + components);
    }
    let index = times.length - 1;
    for (let candidate = 0; candidate < times.length - 1; candidate += 1) {
      if (time < times[candidate + 1]) {
        index = candidate;
        break;
      }
    }
    const firstOffset = index * components;
    if (index === times.length - 1) {
      return values.slice(firstOffset, firstOffset + components);
    }
    const nextOffset = (index + 1) * components;
    const span = times[index + 1] - times[index];
    const amount = span > 0 ? (time - times[index]) / span : 0;
    if (channel.interpolation === "STEP") {
      return values.slice(firstOffset, firstOffset + components);
    }
    const first = values.slice(firstOffset, firstOffset + components);
    const second = values.slice(nextOffset, nextOffset + components);
    if (channel.path === "rotation") return slerpQuaternion(first, second, amount);
    return first.map((value, component) =>
      value + (second[component] - value) * amount);
  }

  async function loadGlb(url, gl, fallbackTexture = null) {
    const response = await fetch(url, { cache: "force-cache" });
    if (!response.ok) throw new Error("GLB HTTP " + response.status + " / " + url);
    const { json, binary } = parseGlb(await response.arrayBuffer());
    if (!Array.isArray(json.accessors) || !Array.isArray(json.bufferViews) ||
        !Array.isArray(json.meshes)) {
      throw new Error("GLB scene arrays missing");
    }
    const textureCache = new Map();
    const loadTexture = async (textureIndex) => {
      if (textureCache.has(textureIndex)) return textureCache.get(textureIndex);
      const promise = (async () => {
        const texture = json.textures?.[textureIndex];
        const image = texture && json.images?.[texture.source];
        if (!image) throw new Error("GLB base-color image missing");
        let blob;
        if (image.bufferView !== undefined) {
          const view = json.bufferViews[image.bufferView];
          if (!view) throw new Error("GLB image bufferView missing");
          const start = view.byteOffset || 0;
          const end = start + view.byteLength;
          if (start < 0 || end > binary.byteLength) throw new Error("GLB image bounds");
          blob = new Blob([binary.slice(start, end)], { type: image.mimeType || "" });
        } else if (typeof image.uri === "string") {
          const baseUrl = typeof document !== "undefined" && document.baseURI
            ? new URL(url, document.baseURI) : url;
          const imageResponse = await fetch(new URL(image.uri, baseUrl), { cache: "force-cache" });
          if (!imageResponse.ok) throw new Error("GLB image HTTP " + imageResponse.status);
          blob = await imageResponse.blob();
        } else {
          throw new Error("GLB image source missing");
        }
        return textureFromBlob(gl, blob);
      })();
      textureCache.set(textureIndex, promise);
      return promise;
    };
    const nodes = Array.isArray(json.nodes) ? json.nodes : [];
    const nodeParents = new Array(nodes.length).fill(undefined);
    nodes.forEach((node, parent) => (node.children || []).forEach((child) => {
      if (!Number.isInteger(child) || child < 0 || child >= nodes.length) {
        throw new Error("GLB child node index invalid");
      }
      if (nodeParents[child] !== undefined) throw new Error("GLB multiple node parents");
      nodeParents[child] = parent;
    }));
    const resolveWorldMatrices = (localMatrices) => {
      const worldMatrices = new Array(nodes.length);
      const resolveNode = (index, visiting = new Set()) => {
        if (worldMatrices[index]) return worldMatrices[index];
        if (visiting.has(index)) throw new Error("GLB node cycle");
        visiting.add(index);
        const node = nodes[index];
        if (!node) throw new Error("GLB node missing");
        const parent = nodeParents[index] === undefined
          ? identity() : resolveNode(nodeParents[index], visiting);
        const result = multiply(parent, localMatrices[index]);
        worldMatrices[index] = result;
        visiting.delete(index);
        return result;
      };
      for (let index = 0; index < nodes.length; index += 1) resolveNode(index);
      return worldMatrices;
    };
    const baseLocalMatrices = nodes.map((node) => nodeMatrix(node));
    const baseWorldMatrices = resolveWorldMatrices(baseLocalMatrices);
    const skins = (json.skins || []).map((skin) => {
      if (!Array.isArray(skin.joints) || skin.joints.length === 0 ||
          skin.joints.length > MAX_SKIN_JOINTS) {
        throw new Error("GLB skin joint count exceeds WebGL limit");
      }
      for (const joint of skin.joints) {
        if (!Number.isInteger(joint) || joint < 0 || joint >= nodes.length) {
          throw new Error("GLB skin joint index invalid");
        }
      }
      const inverseValues = skin.inverseBindMatrices === undefined
        ? null : accessorValues(json, binary, skin.inverseBindMatrices);
      if (inverseValues && inverseValues.length !== skin.joints.length * 16) {
        throw new Error("GLB inverse bind matrix count mismatch");
      }
      const inverseBindMatrices = skin.joints.map((_, index) =>
        inverseValues ? inverseValues.slice(index * 16, index * 16 + 16) : identity());
      return Object.freeze({
        joints: Object.freeze(skin.joints.slice()),
        inverseBindMatrices: Object.freeze(inverseBindMatrices),
      });
    });
    const clips = (json.animations || []).map((animation, animationIndex) => {
      const channels = [];
      let duration = 0;
      for (const channel of animation.channels || []) {
        const sampler = animation.samplers?.[channel.sampler];
        const target = channel.target;
        if (!sampler || !target || !Number.isInteger(target.node) ||
            target.node < 0 || target.node >= nodes.length ||
            !["translation", "rotation", "scale"].includes(target.path)) {
          throw new Error("GLB animation target rejected");
        }
        const inputAccessor = json.accessors?.[sampler.input];
        const outputAccessor = json.accessors?.[sampler.output];
        if (!inputAccessor || inputAccessor.type !== "SCALAR" ||
            !outputAccessor || (target.path === "rotation"
              ? outputAccessor.type !== "VEC4" : outputAccessor.type !== "VEC3")) {
          throw new Error("GLB animation accessor rejected");
        }
        const interpolation = sampler.interpolation || "LINEAR";
        if (interpolation !== "LINEAR" && interpolation !== "STEP") {
          throw new Error("GLB animation interpolation rejected");
        }
        const times = accessorValues(json, binary, sampler.input);
        const components = target.path === "rotation" ? 4 : 3;
        const values = accessorValues(json, binary, sampler.output);
        if (times.length === 0 ||
            times.length !== inputAccessor.count ||
            values.length !== outputAccessor.count * components ||
            outputAccessor.count !== inputAccessor.count) {
          throw new Error("GLB animation key count mismatch");
        }
        if (times.some((time, index) =>
          !Number.isFinite(time) || time < 0 ||
          (index > 0 && time < times[index - 1])) ||
            values.some((value) => !Number.isFinite(value))) {
          throw new Error("GLB animation values rejected");
        }
        duration = Math.max(duration, times[times.length - 1] || 0);
        channels.push(Object.freeze({
          node: target.node,
          path: target.path,
          times: Object.freeze(times),
          values: Object.freeze(values),
          components,
          interpolation,
        }));
      }
      const fullName = typeof animation.name === "string" && animation.name.length > 0
        ? animation.name : "animation-" + animationIndex;
      const separator = fullName.lastIndexOf("|");
      const shortName = separator >= 0 ? fullName.slice(separator + 1) : fullName;
      return Object.freeze({
        name: shortName,
        fullName,
        duration,
        channels: Object.freeze(channels),
      });
    });
    const clipsByName = new Map();
    for (const clip of clips) if (!clipsByName.has(clip.name)) clipsByName.set(clip.name, clip);
    const meshNodes = [];
    for (let index = 0; index < nodes.length; index += 1) {
      const node = nodes[index];
      if (node.mesh === undefined) continue;
      const mesh = json.meshes[node.mesh];
      if (!mesh) throw new Error("GLB node mesh missing");
      if (node.skin !== undefined &&
          (!Number.isInteger(node.skin) || !skins[node.skin])) {
        throw new Error("GLB node skin missing");
      }
      meshNodes.push({ index, node, mesh });
    }
    const meshForPrimitive = async (primitive, localModel, skinNode) => {
      if (primitive.mode !== undefined && primitive.mode !== 4) return null;
      if (primitive.attributes?.POSITION === undefined) {
        throw new Error("GLB primitive POSITION missing");
      }
      const positions = accessorValues(json, binary, primitive.attributes.POSITION);
      const normals = primitive.attributes.NORMAL === undefined
        ? null : accessorValues(json, binary, primitive.attributes.NORMAL);
      const uvs = primitive.attributes.TEXCOORD_0 === undefined
        ? null : accessorValues(json, binary, primitive.attributes.TEXCOORD_0);
      const indices = primitive.indices === undefined
        ? Array.from({ length: positions.length / 3 }, (_, index) => index)
        : accessorValues(json, binary, primitive.indices);
      const jointsIndex = primitive.attributes?.JOINTS_0;
      const weightsIndex = primitive.attributes?.WEIGHTS_0;
      if ((jointsIndex === undefined) !== (weightsIndex === undefined)) {
        throw new Error("GLB skin attributes incomplete");
      }
      if (skinNode !== null && jointsIndex === undefined) {
        throw new Error("GLB skinned primitive attributes missing");
      }
      const jointsAccessor = jointsIndex === undefined
        ? null : json.accessors?.[jointsIndex];
      const weightsAccessor = weightsIndex === undefined
        ? null : json.accessors?.[weightsIndex];
      if (jointsAccessor && jointsAccessor.type !== "VEC4") {
        throw new Error("GLB JOINTS_0 accessor rejected");
      }
      if (weightsAccessor && weightsAccessor.type !== "VEC4") {
        throw new Error("GLB WEIGHTS_0 accessor rejected");
      }
      const joints = skinNode === null || jointsIndex === undefined
        ? null : accessorValues(json, binary, jointsIndex);
      const weights = skinNode === null || weightsIndex === undefined
        ? null : accessorValues(json, binary, weightsIndex);
      if (skinNode !== null) {
        const skin = skins[nodes[skinNode].skin];
        if (joints.some((joint) =>
          !Number.isInteger(joint) || joint < 0 || joint >= skin.joints.length)) {
          throw new Error("GLB JOINTS_0 value rejected");
        }
        if (weights.some((weight) => !Number.isFinite(weight) || weight < 0)) {
          throw new Error("GLB WEIGHTS_0 value rejected");
        }
      }
      const material = json.materials?.[primitive.material || 0];
      const pbr = material?.pbrMetallicRoughness;
      const factor = pbr?.baseColorFactor || [1, 1, 1, 1];
      const textureIndex = pbr?.baseColorTexture?.index;
      const texture = textureIndex === undefined
        ? fallbackTexture : await loadTexture(textureIndex);
      return createMesh(
        gl, new Float32Array(positions), normals && new Float32Array(normals),
        uvs && new Float32Array(uvs), indices, factor, texture, localModel,
        joints && new Float32Array(joints), weights && new Float32Array(weights), skinNode,
      );
    };
    const meshes = [];
    for (const meshNode of meshNodes) {
      for (const primitive of meshNode.mesh.primitives || []) {
        const loaded = await meshForPrimitive(
          primitive, baseWorldMatrices[meshNode.index],
          meshNode.node.skin === undefined ? null : meshNode.index,
        );
        if (loaded) meshes.push(loaded);
      }
    }
    if (meshes.length === 0) {
      for (const mesh of json.meshes) {
        for (const primitive of mesh.primitives || []) {
          const loaded = await meshForPrimitive(primitive, identity(), null);
          if (loaded) meshes.push(loaded);
        }
      }
    }
    const skinnedNodes = Object.freeze(meshes.filter((mesh) =>
      mesh.skinned && mesh.skinNode !== null)
      .map((mesh) => mesh.skinNode).filter((node, index, all) => all.indexOf(node) === index));
    const skinCache = new Map();
    const sampleSkinForAction = (action, timeMs) => {
      if (skinnedNodes.length === 0 || skins.length === 0 || clips.length === 0) return null;
      const requested = action === 2 ? "attack"
        : action === 3 ? "death"
        : action === 4 ? "damage_taken"
        : action === 5 ? "eat"
        : action === 1 ? "run"
        : action === 8 ? "swim"
        : action === 6 || action === 7 || action === 9 ? "walk" : "idle";
      const fallback = action === 3 ? ["damage_taken", "idle"]
        : action === 2 ? ["walk", "idle"]
        : action === 4 ? ["attack", "idle"]
        : action === 5 ? ["idle"]
        : ["walk", "idle"];
      const clip = clipsByName.get(requested) ||
        fallback.map((name) => clipsByName.get(name)).find(Boolean) || clips[0];
      const seconds = Math.max(0, Number.isFinite(timeMs) ? timeMs : 0) / 1000;
      const looping = action === 0 || action === 1 || action === 6 ||
        action === 7 || action === 8 || action === 9;
      const sampleTime = clip.duration > 0
        ? looping ? seconds % clip.duration : Math.min(seconds, clip.duration)
        : 0;
      const cacheKey = clip.fullName + ":" + Math.floor(sampleTime * 60);
      if (skinCache.has(cacheKey)) return skinCache.get(cacheKey);
      const translations = nodes.map((node) =>
        (node.translation || [0, 0, 0]).slice());
      const rotations = nodes.map((node) =>
        normalizeQuaternion((node.rotation || [0, 0, 0, 1]).slice()));
      const scales = nodes.map((node) => (node.scale || [1, 1, 1]).slice());
      for (const channel of clip.channels) {
        const value = sampleAnimationChannel(channel, sampleTime);
        if (channel.path === "translation") translations[channel.node] = value;
        if (channel.path === "rotation") rotations[channel.node] = normalizeQuaternion(value);
        if (channel.path === "scale") scales[channel.node] = value;
      }
      const localMatrices = nodes.map((node, index) =>
        clip.channels.some((channel) => channel.node === index)
          ? composeNodeMatrix(translations[index], rotations[index], scales[index])
          : baseLocalMatrices[index]);
      const worldMatrices = resolveWorldMatrices(localMatrices);
      const matricesByNode = new Array(nodes.length);
      for (const nodeIndex of skinnedNodes) {
        const node = nodes[nodeIndex];
        const skin = skins[node.skin];
        const meshInverse = invertMatrix(worldMatrices[nodeIndex]);
        if (!meshInverse) throw new Error("GLB skinned mesh transform is singular");
        const matrices = new Float32Array(skin.joints.length * 16);
        skin.joints.forEach((joint, jointIndex) => {
          const matrix = multiply(
            multiply(meshInverse, worldMatrices[joint]),
            skin.inverseBindMatrices[jointIndex],
          );
          matrices.set(matrix, jointIndex * 16);
        });
        matricesByNode[nodeIndex] = matrices;
      }
      if (skinCache.size >= 32) skinCache.delete(skinCache.keys().next().value);
      skinCache.set(cacheKey, matricesByNode);
      return matricesByNode;
    };
    return Object.freeze({
      meshes: Object.freeze(meshes),
      skinned: skinnedNodes.length > 0,
      animationNames: Object.freeze(clips.map((clip) => clip.name)),
      defaultAnimation: clipsByName.has("idle") ? "idle" : clips[0]?.name || null,
      sampleSkinForAction,
    });
  }
  async function loadTextureUrl(gl, url) {
    const response = await fetch(url, { cache: "force-cache" });
    if (!response.ok) throw new Error("texture HTTP " + response.status + " / " + url);
    return textureFromBlob(gl, await response.blob());
  }

  function encodeScreenshot(width, height, rgba, flipY, glError = 0) {
    let checksum = 2166136261;
    let nonBlackPixels = 0;
    for (let y = 0; y < height; y += 1) {
      const sourceY = flipY ? height - y - 1 : y;
      for (let x = 0; x < width; x += 1) {
        const source = (sourceY * width + x) * 4;
        const red = rgba[source];
        const green = rgba[source + 1];
        const blue = rgba[source + 2];
        if (red || green || blue) nonBlackPixels += 1;
        checksum = Math.imul(checksum ^ red, 16777619) >>> 0;
        checksum = Math.imul(checksum ^ green, 16777619) >>> 0;
        checksum = Math.imul(checksum ^ blue, 16777619) >>> 0;
    }
    }
    return Object.freeze({
      format: "RGBA8",
      mimeType: "application/octet-stream",
      width,
      height,
      byteLength: rgba.byteLength,
      nonBlackPixels,
      checksum,
      glError,
      pixels: rgba,
      flipY,
    });
  }

  function create(canvas) {
    let gl;
    try {
      gl = canvas.getContext("webgl2", {
        antialias: true, alpha: false, preserveDrawingBuffer: true,
      });
    } catch (error) {
      return { supported: false, reason: "WebGL2 unavailable: " + error.message };
    }
    if (!gl) return { supported: false, reason: "WebGL2 unavailable" };
    let program;
    try {
      program = createProgram(gl);
    } catch (error) {
      return { supported: false, reason: "WebGL2 shader failure: " + error.message };
    }
    const locations = {
      viewProjection: gl.getUniformLocation(program, "uViewProjection"),
      model: gl.getUniformLocation(program, "uModel"),
      color: gl.getUniformLocation(program, "uColor"),
      light: gl.getUniformLocation(program, "uLight"),
      time: gl.getUniformLocation(program, "uTime"),
      waterTime: gl.getUniformLocation(program, "uWaterTime"),
      uvScale: gl.getUniformLocation(program, "uUvScale"),
      uvOffset: gl.getUniformLocation(program, "uUvOffset"),
      albedo: gl.getUniformLocation(program, "uAlbedo"),
      useTexture: gl.getUniformLocation(program, "uUseTexture"),
      water: gl.getUniformLocation(program, "uWater"),
      waterStyle: gl.getUniformLocation(program, "uWaterStyle"),
      waterTint: gl.getUniformLocation(program, "uWaterTint"),
      waterToon: gl.getUniformLocation(program, "uWaterToon"),
      joints: gl.getUniformLocation(program, "uJoints[0]"),
      useSkinning: gl.getUniformLocation(program, "uUseSkinning"),
    };
    const worldMaterialTexture = createWorldMaterialTexture(gl);
    const blobShadowTexture = createBlobShadowTexture(gl);
    const fallbackMeshes = {
      solid: boxGeometry(
        gl, [1, 1, 1], [1, 1, 1, 1], worldMaterialTexture, true,
      ),
      water: horizontalPlaneGeometry(gl, [1, 1, 1, 1]),
      shadow: horizontalPlaneGeometry(gl, COLORS.shadow, blobShadowTexture),
      actor: boxGeometry(gl, [8, 14, 8], COLORS.actor),
      pickup: diamondGeometry(gl, COLORS.pickup),
      projectile: boxGeometry(gl, [2.5, 2.5, 2.5], COLORS.projectile),
      vfx: boxGeometry(gl, [12, 1, 12], COLORS.vfx),
    };
    const shadowMesh = [fallbackMeshes.shadow];
    const shadowTint = [
      COLORS.shadow[0], COLORS.shadow[1], COLORS.shadow[2], COLORS.shadow[3],
    ];
    const rampMeshes = Object.fromEntries(
      Object.entries(ARENA_MAPS).map(([mapId, map]) => [
        mapId,
        map.ramps.map((ramp) =>
          rampGeometry(gl, ramp.vertices, [1, 1, 1, 1], worldMaterialTexture)),
      ]),
    );

    const assets = {
      goose: null, cat: null, hearts: null, heartsBlue: null,
    };
    const vfxTextures = new Array(VFX_ASSETS.length).fill(null);
    const vfxMeshes = new Array(VFX_ASSETS.length).fill(null);
    let playerCameraZoom = 1.5;
    let playerCameraActive = false;
    const handleCameraWheel = (event) => {
      if (!playerCameraActive) return;
      event.preventDefault();
      playerCameraZoom = Math.max(1.3, Math.min(1.8,
        playerCameraZoom + Math.sign(event.deltaY) * 0.05));
    };
    canvas.addEventListener("wheel", handleCameraWheel, { passive: false });
    const assetFailures = [];
    const assetBase = "assets/prototype/models/";
    const assetLoads = [
      ["goose", assetBase + "goose/goose.glb"],
      ["cat", assetBase + "cat/cat.glb"],
      ["hearts", "assets/prototype/runtime/ui/hearts_0001.png"],
      ["heartsBlue", "assets/prototype/runtime/ui/hearts_blue.png"],
    ].map(async ([name, url]) => {
      try {
        if (name === "hearts" || name === "heartsBlue") {
          assets[name] = await loadTextureUrl(gl, url);
        } else if (name === "goose") {
          const fallbackTexture = await loadTextureUrl(
            gl, assetBase + "goose/goose_albedo.png",
          );
          assets[name] = await loadGlb(url, gl, fallbackTexture);
        } else {
          assets[name] = await loadGlb(url, gl);
        }
      } catch (error) {
        assets[name] = null;
        assetFailures.push(name + ": " + error.message);
      }
    });
    const vfxLoads = VFX_ASSETS.map(async (asset) => {
      try {
        vfxTextures[asset.id] = await loadTextureUrl(gl, asset.path);
        vfxMeshes[asset.id] = planeGeometry(gl,
          asset.id === 17 ? [1, 1, 1, 1] : COLORS.vfx,
          vfxTextures[asset.id]);
      } catch (error) {
        assetFailures.push(asset.name + ": " + error.message);
      }
    });
    let assetReady = false;
    let contextLost = false;
    let heartMesh = null;
    let blueHeartMesh = null;
    Promise.all([...assetLoads, ...vfxLoads]).then(() => { assetReady = true; });
    function rendererStatus() {
      if (contextLost) return "WebGL2 / context lost";
      if (!assetReady) return "WebGL2 / loading GLB assets";
      if (assetFailures.length > 0) return "WebGL2 / fallback meshes (" + assetFailures.length + " asset failures)";
      return "WebGL2 / GLB actors + canonical arena";
    }

    function resize() {
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      const rect = typeof canvas.getBoundingClientRect === "function"
        ? canvas.getBoundingClientRect() : { width: canvas.width, height: canvas.height };
      const width = Math.max(1, Math.floor((rect.width || canvas.width || 960) * ratio));
      const height = Math.max(1, Math.floor((rect.height || canvas.height || 480) * ratio));
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }
      gl.viewport(0, 0, canvas.width, canvas.height);
    }

    function draw(
      meshes, model, tint, time, viewProjection, uvRect = [0, 0, 1, 1],
      skinMatricesByNode = null, waterStyle = null,
    ) {
      gl.uniform2f(locations.uvScale, uvRect[2], uvRect[3]);
      gl.uniform2f(locations.uvOffset, uvRect[0], uvRect[1]);
      gl.uniform1i(locations.water, waterStyle ? 1 : 0);
      if (waterStyle) {
        gl.uniform4f(
          locations.waterStyle, waterStyle.style[0], waterStyle.style[1],
          waterStyle.style[2], waterStyle.style[3],
        );
        gl.uniform4f(
          locations.waterTint, waterStyle.tint[0], waterStyle.tint[1],
          waterStyle.tint[2], waterStyle.tint[3],
        );
        gl.uniform4f(
          locations.waterToon, waterStyle.toon[0], waterStyle.toon[1],
          waterStyle.toon[2], waterStyle.toon[3],
        );
      }
      for (const mesh of meshes || []) {
        const skinMatrices = mesh.skinned && skinMatricesByNode
          ? skinMatricesByNode[mesh.skinNode] : null;
        gl.bindVertexArray(mesh.vao);
        gl.uniform1i(locations.useSkinning, skinMatrices ? 1 : 0);
        if (skinMatrices) gl.uniformMatrix4fv(locations.joints, false, skinMatrices);
        gl.uniformMatrix4fv(
          locations.model, false, new Float32Array(multiply(model, mesh.localModel)),
        );
        const material = mesh.color || [1, 1, 1, 1];
        gl.uniform4f(
          locations.color,
          material[0] * tint[0], material[1] * tint[1], material[2] * tint[2], tint[3],
        );
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, mesh.texture || null);
        gl.uniform1i(locations.albedo, 0);
        gl.uniform1i(locations.useTexture, mesh.texture ? 1 : 0);
        gl.drawElements(gl.TRIANGLES, mesh.count, gl.UNSIGNED_INT, 0);
      }
    }

    let filteredCamera = null;
    let filteredPlayerFocus = null;
    let filteredPlayerId = null;
    let lastCameraFrameAt = 0;
    const wrapDegrees = (degrees) =>
      ((degrees + 180) % 360 + 360) % 360 - 180;
    function smoothCamera(target, time, scene = null) {
      const followsPlayer = scene?.playerId > 0;
      if (!filteredCamera) {
        filteredCamera = { ...target };
        if (followsPlayer) {
          filteredPlayerFocus = {
            x: scene.playerX, y: scene.playerY, z: scene.playerZ,
          };
          filteredPlayerId = scene.playerId;
        }
        lastCameraFrameAt = time;
        return filteredCamera;
      }
      const deltaSeconds = Math.max(0, Math.min(0.1,
        (time - lastCameraFrameAt) / 1000));
      lastCameraFrameAt = time;
      const yawBlend = 1 - Math.exp(-deltaSeconds / 0.1);
      const pitchBlend = 1 - Math.exp(-deltaSeconds / 0.08);
      filteredCamera.yaw += wrapDegrees(target.yaw - filteredCamera.yaw) * yawBlend;
      filteredCamera.pitch += (target.pitch - filteredCamera.pitch) * pitchBlend;
      if (followsPlayer) {
        if (!filteredPlayerFocus || filteredPlayerId !== scene.playerId) {
          filteredPlayerFocus = {
            x: scene.playerX, y: scene.playerY, z: scene.playerZ,
          };
          filteredPlayerId = scene.playerId;
        } else if (Math.hypot(
          scene.playerX - filteredPlayerFocus.x,
          scene.playerZ - filteredPlayerFocus.z,
        ) > 60) {
          filteredPlayerFocus = {
            x: scene.playerX, y: scene.playerY, z: scene.playerZ,
          };
          filteredCamera = { ...target };
          return filteredCamera;
        } else {
          const followBlend = 1 - Math.exp(-deltaSeconds / 0.09);
          filteredPlayerFocus.x +=
            (scene.playerX - filteredPlayerFocus.x) * followBlend;
          filteredPlayerFocus.y +=
            (scene.playerY - filteredPlayerFocus.y) * followBlend;
          filteredPlayerFocus.z +=
            (scene.playerZ - filteredPlayerFocus.z) * followBlend;
        }
        const yaw = filteredCamera.yaw * Math.PI / 180;
        const followDistance = Math.hypot(
          target.x - scene.playerX, target.z - scene.playerZ,
        );
        filteredCamera.x = filteredPlayerFocus.x - Math.sin(yaw) * followDistance;
        filteredCamera.y = filteredPlayerFocus.y + target.y - scene.playerY;
        filteredCamera.z = filteredPlayerFocus.z - Math.cos(yaw) * followDistance;
      } else {
        filteredPlayerFocus = null;
        filteredPlayerId = null;
        const distance = Math.hypot(
          target.x - filteredCamera.x,
          target.y - filteredCamera.y,
          target.z - filteredCamera.z,
        );
        if (distance > 60) {
          filteredCamera = { ...target };
          return filteredCamera;
        }
        const positionBlend = 1 - Math.exp(-deltaSeconds / 0.1);
        filteredCamera.x += (target.x - filteredCamera.x) * positionBlend;
        filteredCamera.y += (target.y - filteredCamera.y) * positionBlend;
        filteredCamera.z += (target.z - filteredCamera.z) * positionBlend;
      }
      return filteredCamera;
    }
    let vfxKey = null;
    let vfxStartedAt = 0;
    let lastImpactSceneTick = null;
    const impactEffects = new Map();
    const movementSmokeEffects = new Map();
    const actorMovementStates = new Map();
    const actorHitFlinches = new Map();
    const actorHitFlashStarts = new Map();
    const seenHitImpactKeys = new Set();
    const hitImpactKeyOrder = [];
    const actorAnimationStarts = new Map();
    const rollDurationMs = 12 * (1000 / 60);

    function emitMovementSmoke(actor, time, scale) {
      if (movementSmokeEffects.size >= 24) {
        movementSmokeEffects.delete(movementSmokeEffects.keys().next().value);
      }
      movementSmokeEffects.set(
        `${actor.id}:${time}:${movementSmokeEffects.size}`,
        { x: actor.x, y: actor.y + 1, z: actor.z, startedAt: time, scale },
      );
    }
    function updateMovementSmoke(actors, time) {
      for (const actor of actors) {
        if (actor.kind === 3 || !Number.isInteger(actor.id)) continue;
        const grounded = (actor.state & 1) !== 0;
        const previous = actorMovementStates.get(actor.id);
        if (previous) {
          if (previous.grounded && !grounded) {
            emitMovementSmoke(actor, time, 7);
          } else if (!previous.grounded && grounded) {
            emitMovementSmoke(actor, time, 9.5);
          } else if (grounded &&
              Math.hypot(actor.x - previous.x, actor.z - previous.z) > 0.12 &&
              time - previous.lastRunPuffAt >= 125) {
            emitMovementSmoke(actor, time, 6.5);
            previous.lastRunPuffAt = time;
          }
          previous.x = actor.x;
          previous.y = actor.y;
          previous.z = actor.z;
          previous.grounded = grounded;
          previous.lastSeenAt = time;
        } else {
          actorMovementStates.set(actor.id, {
            x: actor.x, y: actor.y, z: actor.z,
            grounded, lastRunPuffAt: time, lastSeenAt: time,
          });
        }
      }
      for (const [actorId, state] of actorMovementStates) {
        if (time - state.lastSeenAt > 2500) actorMovementStates.delete(actorId);
      }
    }
    function updateActorHitFlinches(scene, time) {
      const actors = scene.actors || [];
      for (const impact of scene.impacts || []) {
        if (impact.damage <= 0) continue;
        const key = [impact.sequence, impact.sourceId, impact.targetId,
          impact.kind, impact.x, impact.y, impact.z, impact.damage].join(":");
        if (seenHitImpactKeys.has(key)) continue;
        seenHitImpactKeys.add(key);
        hitImpactKeyOrder.push(key);
        if (hitImpactKeyOrder.length > 32) {
          seenHitImpactKeys.delete(hitImpactKeyOrder.shift());
        }
        let target = actors.find((actor) => actor.id === impact.targetId);
        if (!target && impact.targetId === 0) {
          let closestDistanceSquared = 25;
          for (const actor of actors) {
            if (actor.kind !== 3) continue;
            const dx = actor.x - impact.x;
            const dz = actor.z - impact.z;
            const distanceSquared = dx * dx + dz * dz;
            if (distanceSquared < closestDistanceSquared) {
              target = actor;
              closestDistanceSquared = distanceSquared;
            }
          }
        }
        if (!target || !Number.isInteger(target.id)) continue;
        if (target.id !== scene.playerId) {
          actorHitFlashStarts.set(target.id, time);
        }
        const source = actors.find((actor) => actor.id === impact.sourceId);
        if (!source) continue;
        let directionX = target.x - source.x;
        let directionZ = target.z - source.z;
        let distance = Math.hypot(directionX, directionZ);
        if (distance < 0.001) {
          const yaw = (source.yaw || 0) * Math.PI / 180;
          directionX = Math.sin(yaw);
          directionZ = Math.cos(yaw);
          distance = 1;
        }
        actorHitFlinches.set(target.id, {
          x: directionX / distance,
          z: directionZ / distance,
          startedAt: time,
        });
      }
      for (const [actorId, flinch] of actorHitFlinches) {
        if (time - flinch.startedAt >= 160) actorHitFlinches.delete(actorId);
      }
      for (const [actorId, startedAt] of actorHitFlashStarts) {
        if (time - startedAt >= 120) actorHitFlashStarts.delete(actorId);
      }
    }
    function actorHitFlinchOffset(actorId, time) {
      const flinch = actorHitFlinches.get(actorId);
      if (!flinch) return null;
      const progress = (time - flinch.startedAt) / 160;
      if (progress >= 1) {
        actorHitFlinches.delete(actorId);
        return null;
      }
      const distance = Math.sin(Math.max(0, progress) * Math.PI) * 1.5;
      return [flinch.x * distance, flinch.z * distance];
    }
    function actorHitFlashTint(color, actorId, time) {
      const startedAt = actorHitFlashStarts.get(actorId);
      if (startedAt === undefined) return color;
      const progress = (time - startedAt) / 120;
      if (progress >= 1) {
        actorHitFlashStarts.delete(actorId);
        return color;
      }
      const brightness = Math.max(0, 1 - progress) * 0.9;
      return [
        color[0] + (1 - color[0]) * brightness,
        color[1] + (1 - color[1]) * brightness,
        color[2] + (1 - color[2]) * brightness,
        color[3],
      ];
    }
    function actorAnimationElapsed(actor, time) {
      const id = Number.isInteger(actor.id) ? actor.id : 0;
      const action = Number.isInteger(actor.animation) ? actor.animation : 0;
      let state = actorAnimationStarts.get(id);
      if (!state || state.action !== action) {
        state = { action, startedAt: time };
        actorAnimationStarts.set(id, state);
      }
      return Math.max(0, time - state.startedAt);
    }
    function actorRollAngle(actor, time) {
      if (actor.animation !== 7) return 0;
      const progress = Math.min(1, actorAnimationElapsed(actor, time) / rollDurationMs);
      const eased = progress * progress * (3 - 2 * progress);
      return eased * Math.PI * 2 *
        (actor.rollDirection === -1 ? -1 : 1);
    }
    function cameraTargetForScene(scene) {
      const target = scene.camera || {
        x: scene.playerX, y: scene.playerY + 8, z: scene.playerZ - 16,
        yaw: scene.yaw, pitch: scene.pitch,
      };
      if (!(scene.playerId > 0)) return target;
      return {
        ...target,
        x: scene.playerX + (target.x - scene.playerX) * playerCameraZoom,
        z: scene.playerZ + (target.z - scene.playerZ) * playerCameraZoom,
      };
    }
    function projectWorld(scene, x, y, z) {
      const camera = scene.playerId > 0 && filteredCamera
        ? filteredCamera : cameraTargetForScene(scene);
      const yaw = (camera.yaw || 0) * Math.PI / 180;
      const pitch = (camera.pitch || 0) * Math.PI / 180;
      const direction = [
        Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), Math.cos(yaw) * Math.cos(pitch),
      ];
      const eye = [camera.x, camera.y, camera.z];
      const target = [
        eye[0] + direction[0] * 30,
        eye[1] + direction[1] * 30,
        eye[2] + direction[2] * 30,
      ];
      const viewProjection = multiply(
        perspective(Math.PI / 3, canvas.width / Math.max(1, canvas.height), 0.2, 900),
        lookAt(eye, target, [0, 1, 0]),
      );
      const clip = [
        viewProjection[0] * x + viewProjection[4] * y +
          viewProjection[8] * z + viewProjection[12],
        viewProjection[1] * x + viewProjection[5] * y +
          viewProjection[9] * z + viewProjection[13],
        viewProjection[2] * x + viewProjection[6] * y +
          viewProjection[10] * z + viewProjection[14],
        viewProjection[3] * x + viewProjection[7] * y +
          viewProjection[11] * z + viewProjection[15],
      ];
      if (!clip.every(Number.isFinite) || clip[3] <= 0) return null;
      const normalized = [clip[0] / clip[3], clip[1] / clip[3], clip[2] / clip[3]];
      if (normalized[2] < -1 || normalized[2] > 1) return null;
      return Object.freeze({
        x: normalized[0] * 0.5 + 0.5,
        y: 0.5 - normalized[1] * 0.5,
        depth: normalized[2],
      });
    }
 
    function render(scene, time = 0) {
      if (Number.isInteger(scene.tick)) {
        if (lastImpactSceneTick !== null && scene.tick < lastImpactSceneTick) {
          impactEffects.clear();
          movementSmokeEffects.clear();
          actorMovementStates.clear();
          actorHitFlinches.clear();
          actorHitFlashStarts.clear();
          seenHitImpactKeys.clear();
          hitImpactKeyOrder.length = 0;
        }
        lastImpactSceneTick = scene.tick;
      }
      updateMovementSmoke(scene.actors || [], time);
      updateActorHitFlinches(scene, time);
      if (contextLost || (typeof gl.isContextLost === "function" && gl.isContextLost())) return;
      resize();
      const targetCamera = cameraTargetForScene(scene);
      playerCameraActive = scene.playerId > 0;
      const camera = smoothCamera(targetCamera, time, scene);
      const yaw = (camera.yaw || 0) * Math.PI / 180;
      const pitch = (camera.pitch || 0) * Math.PI / 180;
      const direction = [
        Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), Math.cos(yaw) * Math.cos(pitch),
      ];
      const eye = [camera.x, camera.y, camera.z];
      const target = [
        eye[0] + direction[0] * 30,
        eye[1] + direction[1] * 30,
        eye[2] + direction[2] * 30,
      ];
      const viewProjection = multiply(
        perspective(Math.PI / 3, canvas.width / Math.max(1, canvas.height), 0.2, 900),
        lookAt(eye, target, [0, 1, 0]),
      );
      gl.enable(gl.DEPTH_TEST);
      gl.disable(gl.CULL_FACE);
      gl.depthFunc(gl.LEQUAL);
      gl.clearColor(0.025, 0.075, 0.105, 1);
      gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
      gl.useProgram(program);
      gl.uniformMatrix4fv(locations.viewProjection, false, new Float32Array(viewProjection));
      gl.uniform3f(locations.light, -0.45, 0.9, 0.35);
      gl.uniform1f(locations.time, time * 0.001);
      gl.uniform1f(
        locations.waterTime,
        Number.isFinite(scene.tick) ? Math.max(0, scene.tick) / 60 : time * 0.001,
      );

      if (scene.kutterEditor === true) {
        draw(
          [fallbackMeshes.solid],
          transform([0, -0.5, 0], [24, 1, 24]),
          [1, 1, 1, 1], time, viewProjection, worldMaterialUv(1),
        );
        for (const node of scene.kutterNodes || []) {
          if (node.kind === 9) continue;
          const height = node.scaleY / 250;
          const red = ((node.color >>> 16) & 255) / 255;
          const green = ((node.color >>> 8) & 255) / 255;
          const blue = (node.color & 255) / 255;
          const tint = node.id === scene.kutterSelected
            ? [Math.min(1, red * 0.65 + 0.35),
              Math.min(1, green * 0.65 + 0.35),
              Math.min(1, blue * 0.65 + 0.35), 1]
            : [red, green, blue, 1];
          draw(
            [fallbackMeshes.solid],
            transform(
              [node.x / 100, (node.y + height / 2) / 100, node.z / 100],
              [node.scaleX / 250, height, node.scaleZ / 250],
              node.rotation / 1000 * Math.PI / 180,
            ),
            tint, time, viewProjection, worldMaterialUv(node.kind),
          );
        }
        return;
      }
      draw(
        [fallbackMeshes.solid],
        transform([160, -0.5, 140], [320, 1, 280]),
        [1, 1, 1, 1], time, viewProjection, worldMaterialUv(1),
      );
      const mapGeometry = arenaMap(scene.mapId);
      const mapRamps = rampMeshes[scene.mapId] || rampMeshes[1];
      for (const entry of mapGeometry.solids) {
        const [left, bottom, front, right, top, back] = entry.box;
        draw(
          [fallbackMeshes.solid],
          transform(
            [(left + right) / 2, (bottom + top) / 2, (front + back) / 2],
            [right - left, top - bottom, back - front],
          ),
          [1, 1, 1, 1], time, viewProjection, worldMaterialUv(entry.material),
        );
      }
      for (let index = 0; index < mapGeometry.ramps.length; index += 1) {
        draw(
          [mapRamps[index]],
          identity(),
          [1, 1, 1, 1], time, viewProjection,
          worldMaterialUv(mapGeometry.ramps[index].material),
        );
      }

      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      for (const entry of ARENA_WATER) {
        const [minX, surfaceY, minZ, maxX, maxZ] = entry.bounds;
        draw(
          [fallbackMeshes.water],
          transform(
            [(minX + maxX) / 2, surfaceY, (minZ + maxZ) / 2],
            [maxX - minX, 1, maxZ - minZ],
          ),
          [1, 1, 1, 1], time, viewProjection, undefined, null, entry.style,
        );
      }
      gl.disable(gl.BLEND);
      for (const object of scene.sceneObjects || []) {
        const width = Math.max(0.5, object.sizeX * 2);
        const height = Math.max(0.5, object.sizeY * 2);
        const depth = Math.max(0.5, object.sizeZ * 2);
        if (object.kind === SCENE_OBJECT_KINDS.door) {
          draw(
            [fallbackMeshes.solid],
            transform([object.x, object.y, object.z], [width, height, depth]),
            object.state > 0 ? SCENE_OBJECT_COLORS.doorOpen : SCENE_OBJECT_COLORS.doorClosed,
            time, viewProjection,
          );
        } else if (object.kind === SCENE_OBJECT_KINDS.floatable) {
          const bob = object.state > 0 ? Math.sin(time * 0.003 + object.id) * 0.45 : 0;
          draw(
            [fallbackMeshes.solid],
            transform([object.x, object.y + bob, object.z], [width, height, depth]),
            SCENE_OBJECT_COLORS.floatable, time, viewProjection,
          );
        } else if (object.kind === SCENE_OBJECT_KINDS.powerup) {
          const bob = Math.sin(time * 0.004 + object.id) * 0.65;
          draw(
            [fallbackMeshes.pickup],
            transform(
              [object.x, object.y + object.sizeY + bob, object.z],
              [Math.max(2, width), Math.max(2, height), Math.max(2, depth)],
              time * 0.001,
            ),
            SCENE_OBJECT_COLORS.powerup, time, viewProjection,
          );
        } else if (object.kind === SCENE_OBJECT_KINDS.lootBeam) {
          draw(
            [fallbackMeshes.solid],
            transform(
              [object.x, object.y + object.sizeY / 2, object.z],
              [width, Math.max(1, object.sizeY), depth],
            ),
            SCENE_OBJECT_COLORS.lootBeam, time, viewProjection,
          );
          draw(
            [fallbackMeshes.pickup],
            transform(
              [object.x, object.y + object.sizeY + 1, object.z],
              [Math.max(2, width), Math.max(2, height), Math.max(2, depth)],
              time * 0.001,
            ),
            SCENE_OBJECT_COLORS.lootBeam, time, viewProjection,
          );
        }
      }

      const actors = scene.actors || [];
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      function drawBlobShadow(x, y, z, flinchOffset) {
        const centerX = x + (flinchOffset ? flinchOffset[0] : 0);
        const centerZ = z + (flinchOffset ? flinchOffset[1] : 0);
        const ground = arenaGroundAt(centerX, centerZ, y, scene.mapId);
        const height = Math.max(0, y - ground.height - 1);
        const airFactor = Math.min(1, height / 24);
        const sizeFactor = 1 - airFactor * 0.55;
        const rotationZ = Math.atan(ground.slopeX);
        const rotationX = Math.atan(-ground.slopeZ * Math.cos(rotationZ));
        shadowTint[3] = COLORS.shadow[3] * (1 - airFactor * 0.78);
        draw(
          shadowMesh,
          transform(
            [centerX, ground.height + 0.05, centerZ],
            [8 * sizeFactor, 1, 6 * sizeFactor], 0, rotationZ, rotationX,
          ),
          shadowTint, time, viewProjection,
        );
      }

      for (const actor of actors) {
        if (actor.health <= 0 || (scene.playerId > 0 && actor.id === scene.playerId)) continue;
        drawBlobShadow(
          actor.x, actor.y, actor.z, actorHitFlinchOffset(actor.id, time),
        );
      }
      if (scene.playerId === undefined || scene.playerId > 0) {
        drawBlobShadow(
          scene.playerX, scene.playerY, scene.playerZ,
          actorHitFlinchOffset(scene.playerId, time),
        );
      }
      gl.disable(gl.BLEND);

      const modelForActor = (actor) => actor.kind === 2 ? assets.cat : assets.goose;
      const renderYawForActor = (actor, fallbackYaw = 0) =>
        (actor.yaw === undefined ? fallbackYaw : actor.yaw * Math.PI / 180) +
        (actor.kind === 2 ? Math.PI : 0);
      for (const actor of actors) {
        const model = modelForActor(actor);
        if (scene.playerId > 0 && actor.id === scene.playerId) continue;
        const flinchOffset = actorHitFlinchOffset(actor.id, time);
        if (actor.kind === 3) {
          const x = actor.x + (flinchOffset ? flinchOffset[0] : 0);
          const y = actor.y;
          const z = actor.z + (flinchOffset ? flinchOffset[1] : 0);
          const straw = actorHitFlashTint(
            actor.health > 0 ? [0.92, 0.64, 0.2, 1] : COLORS.damaged,
            actor.id, time,
          );
          const dummyScale = DUMMY_RENDER_SCALE;
          draw([fallbackMeshes.solid],
            transform([x, y + 6 * dummyScale, z],
              [1.2 * dummyScale, 12 * dummyScale, 1.2 * dummyScale]),
            actorHitFlashTint([0.28, 0.19, 0.1, 1], actor.id, time),
            time, viewProjection);
          draw([fallbackMeshes.solid],
            transform([x, y + 9 * dummyScale, z],
              [6 * dummyScale, 5 * dummyScale, 3 * dummyScale]),
            straw, time, viewProjection);
          draw([fallbackMeshes.solid],
            transform([x, y + 14 * dummyScale, z],
              [4 * dummyScale, 4 * dummyScale, 4 * dummyScale]),
            actorHitFlashTint([0.96, 0.78, 0.4, 1], actor.id, time),
            time, viewProjection);
          draw([fallbackMeshes.solid],
            transform([x, y + 10 * dummyScale, z],
              [13 * dummyScale, 2 * dummyScale, 2 * dummyScale]),
            straw, time, viewProjection);
          continue;
        }
        const tint = actorHitFlashTint(
          actor.health <= 0 ? COLORS.damaged
            : actor.powerUp > 0 ? COLORS.pickup
            : actor.health < 50 ? COLORS.damaged
            : actor.kind === 2 ? COLORS.actorAlt : COLORS.actor,
          actor.id, time,
        );
        const scale = actor.kind === 2
          ? [CAT_RENDER_SCALE, CAT_RENDER_SCALE, CAT_RENDER_SCALE]
          : [GOOSE_RENDER_SCALE, GOOSE_RENDER_SCALE, GOOSE_RENDER_SCALE];
        const actorYaw = renderYawForActor(actor);
        const actorLift = actorAnimationLift(actor, scene.tick);
        const actorAnimation = Number.isInteger(actor.animation) ? actor.animation : 0;
        const actorAnimationTime = actorAnimationElapsed(actor, time);
        const skinMatrices = model?.sampleSkinForAction?.(
          actorAnimation, actorAnimationTime,
        );
        draw(model?.meshes || [fallbackMeshes.actor], transform(
          [actor.x + (flinchOffset ? flinchOffset[0] : 0),
            actor.y + actorLift,
            actor.z + (flinchOffset ? flinchOffset[1] : 0)], scale, actorYaw, 0,
        ), tint, time, viewProjection, [0, 0, 1, 1], skinMatrices);
      }
      const playerActor = actors.find((actor) => actor.id === scene.playerId) ||
        { id: scene.playerId, kind: 1, animation: 0 };
      const playerFlinchOffset = actorHitFlinchOffset(playerActor.id, time);
      const playerModel = modelForActor(playerActor);
      const playerScale = playerActor.kind === 2
        ? [CAT_RENDER_SCALE, CAT_RENDER_SCALE, CAT_RENDER_SCALE]
        : [GOOSE_RENDER_SCALE, GOOSE_RENDER_SCALE, GOOSE_RENDER_SCALE];
      const playerLift = actorAnimationLift(playerActor, scene.tick);
      const playerAnimationTime = actorAnimationElapsed(playerActor, time);
      const playerSkinMatrices = playerModel?.sampleSkinForAction?.(
        playerActor.animation, playerAnimationTime,
      );
      if (scene.playerId === undefined || scene.playerId > 0) {
        draw(playerModel?.meshes || [fallbackMeshes.actor], transform(
          [scene.playerX + (playerFlinchOffset ? playerFlinchOffset[0] : 0),
            scene.playerY + playerLift,
            scene.playerZ + (playerFlinchOffset ? playerFlinchOffset[1] : 0)],
          playerScale,
          actorRollAngle(playerActor, time),
        ), COLORS.player, time, viewProjection, [0, 0, 1, 1], playerSkinMatrices);
      }

      if (assets.hearts || assets.heartsBlue) {
        if (assets.hearts && !heartMesh) {
          heartMesh = planeGeometry(gl, [1, 1, 1, 1], assets.hearts);
        }
        if (assets.heartsBlue && !blueHeartMesh) {
          blueHeartMesh = planeGeometry(gl, [1, 1, 1, 1], assets.heartsBlue);
        }
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.depthMask(false);
        for (const actor of actors) {
          if (actor.health <= 0 || actor.id === scene.playerId) continue;
          const flinchOffset = actorHitFlinchOffset(actor.id, time);
          const health = Math.max(0, Math.min(100, actor.health));
          const heartState = Math.max(0, Math.min(4, Math.floor(health * 4 / 100)));
          const actorLift = actorAnimationLift(actor, scene.tick);
          const heartHeight = actor.kind === 2 ? 9 : 19;
          const teamHeartMesh = actor.kind === 2 && blueHeartMesh
            ? blueHeartMesh : heartMesh;
          if (!teamHeartMesh) continue;
          draw(
            [teamHeartMesh],
            transform(
              [actor.x + (flinchOffset ? flinchOffset[0] : 0),
                actor.y + actorLift + heartHeight,
                actor.z + (flinchOffset ? flinchOffset[1] : 0)],
              [2.8, 2.8, 1], yaw,
            ),
            [1, 1, 1, 1], time, viewProjection,
            [heartState / 5, 1, 1 / 5, -1],
          );
        }
        gl.depthMask(true);
      }
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      gl.depthMask(false);
      for (const actor of actors) {
        if (!actor.dizzy || actor.health <= 0) continue;
        const actorLift = actorAnimationLift(actor, scene.tick);
        const starCount = 3;
        const orbit = time * 0.004 + actor.id * 0.7;
        const starHeight = actor.kind === 2 ? 12 : 24;
        for (let star = 0; star < starCount; star += 1) {
          const angle = orbit + star * Math.PI * 2 / starCount;
          const starX = actor.x + Math.cos(angle) * 4.2;
          const starZ = actor.z + Math.sin(angle) * 4.2;
          const starY = actor.y + actorLift + starHeight +
            Math.sin(orbit * 1.7 + star) * 0.7;
          draw(vfxMeshes[3] ? [vfxMeshes[3]] : [fallbackMeshes.vfx],
            transform([starX, starY, starZ], [2.1, 2.1, 1], -angle),
            [1, 0.88, 0.18, 1], time, viewProjection, [0, 0, 1, 1]);
        }
      }
      gl.depthMask(true);
      gl.disable(gl.BLEND);
      if (scene.carriesThrowable && scene.playerId > 0) {
        const playerYaw = (scene.yaw || 0) * Math.PI / 180;
        const heldX = scene.playerX + Math.sin(playerYaw) * 2.5;
        const heldZ = scene.playerZ + Math.cos(playerYaw) * 2.5;
        const visual = THROWABLE_VISUALS[scene.carryType] ||
          THROWABLE_VISUALS[1];
        draw([fallbackMeshes[visual.mesh]], transform(
          [heldX, scene.playerY + 2.8, heldZ], visual.scale,
          time * 0.002,
        ), visual.color, time, viewProjection);
      }
      if (scene.pickup) {
        const bob = Math.sin(time * 0.004) * 0.7;
        const visual = THROWABLE_VISUALS[scene.pickup.type] ||
          THROWABLE_VISUALS[1];
        draw([fallbackMeshes[visual.mesh]], transform(
          [scene.pickup.x, scene.pickup.y + 3 + bob, scene.pickup.z],
          visual.pickupScale, time * 0.001,
        ), visual.color, time, viewProjection);
      }
      for (const slice of scene.slicePickups || []) {
        const bob = Math.sin(time * 0.005 + slice.id) * 0.3;
        draw([fallbackMeshes.solid], transform(
          [slice.x, slice.y + 1.1 + bob, slice.z], [2.4, 1.1, 1.5],
          time * 0.002,
        ), [0.92, 0.08, 0.13, 1], time, viewProjection);
        draw([fallbackMeshes.solid], transform(
          [slice.x, slice.y + 1.7 + bob, slice.z], [2.5, 0.35, 1.6],
          time * 0.002,
        ), [0.2, 0.62, 0.22, 1], time, viewProjection);
      }
      if (Array.isArray(scene.throwPreview)) {
        for (let index = 0; index < scene.throwPreview.length; index += 1) {
          const point = scene.throwPreview[index];
          const terminal = index === scene.throwPreview.length - 1;
          const size = terminal ? 1.7 : 0.65;
          draw([fallbackMeshes.solid], transform(
            [point.x, point.y, point.z],
            terminal ? [3.2, 0.16, 3.2] : [size, size, size],
          ), terminal ? [1, 0.68, 0.2, 1] : [0.98, 0.86, 0.42, 0.9],
          time, viewProjection);
        }
      }

      for (const projectile of scene.projectiles || []) {
        const fireball = projectile.kind === 3;
        draw([fallbackMeshes.projectile], transform(
          [projectile.x, projectile.y, projectile.z],
          fireball ? [1.7, 1.7, 1.7] : [1, 1, 1], time * 0.003,
        ), fireball ? COLORS.fireball : COLORS.projectile, time, viewProjection);
      }
      for (const throwable of scene.throwables || []) {
        const type = throwable.type || throwable.kind;
        const visual = THROWABLE_VISUALS[type] || THROWABLE_VISUALS[1];
        const melonSpin = type === 3;
        const phase = time * (melonSpin ? 0.012 : 0.004) +
          (melonSpin ? throwable.id * 0.7 : 0);
        const tumbleZ = melonSpin ? Math.sin(phase * 0.7) * 0.65 : 0;
        const tumbleX = melonSpin ? Math.cos(phase * 0.9) * 0.55 : 0;
        draw([fallbackMeshes[visual.mesh]], transform(
          [throwable.x, throwable.y, throwable.z], visual.scale,
          phase, tumbleZ, tumbleX,
        ), visual.color, time, viewProjection);
      }
      for (const impact of scene.impacts || []) {
        const assetId = MULTIPLAYER_IMPACT_ASSET[impact.kind];
        if (!Number.isInteger(assetId)) continue;
        const key = [impact.sequence, impact.sourceId, impact.targetId,
          impact.kind, impact.x, impact.y, impact.z].join(":");
        if (!impactEffects.has(key)) {
          if (impactEffects.size >= MAX_MULTIPLAYER_IMPACT_EFFECTS) {
            impactEffects.delete(impactEffects.keys().next().value);
          }
          impactEffects.set(key, { impact, assetId, startedAt: time });
        }
      }
      for (const [key, effect] of impactEffects) {
        const asset = VFX_ASSETS[effect.assetId];
        const frameCount = asset.frameCount || asset.columns * asset.rows;
        const age = time - effect.startedAt;
        if (age >= frameCount * asset.frameMs) {
          impactEffects.delete(key);
          continue;
        }
        const frame = Math.floor(age / asset.frameMs);
        const uvRect = [
          (frame % asset.columns) / asset.columns,
          (asset.rows - 1 - Math.floor(frame / asset.columns)) / asset.rows,
          1 / asset.columns,
          1 / asset.rows,
        ];
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        draw(
          vfxMeshes[asset.id] ? [vfxMeshes[asset.id]] : [fallbackMeshes.vfx],
          transform([effect.impact.x, effect.impact.y, effect.impact.z],
            [asset.scale, asset.scale, 1], yaw + Math.PI / 2),
          COLORS.vfx, time, viewProjection, uvRect,
        );
        gl.disable(gl.BLEND);
      }
      const movementSmokeAsset = VFX_ASSETS[17];
      for (const [key, effect] of movementSmokeEffects) {
        const age = time - effect.startedAt;
        const frameCount = movementSmokeAsset.frameCount;
        if (age >= frameCount * movementSmokeAsset.frameMs) {
          movementSmokeEffects.delete(key);
          continue;
        }
        const frame = Math.floor(age / movementSmokeAsset.frameMs);
        const progress = age / (frameCount * movementSmokeAsset.frameMs);
        const frameWidth = 1 / movementSmokeAsset.columns;
        const uvRect = [
          frame / movementSmokeAsset.columns, 0, frameWidth, 1,
        ];
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        draw(
          vfxMeshes[movementSmokeAsset.id]
            ? [vfxMeshes[movementSmokeAsset.id]] : [fallbackMeshes.vfx],
          transform(
            [effect.x, effect.y, effect.z],
            [effect.scale * (0.8 + progress * 0.6),
              effect.scale * (0.8 + progress * 0.6), 1],
            yaw,
          ),
          [1, 1, 1, 0.96], time, viewProjection, uvRect,
        );
        gl.disable(gl.BLEND);
      }
      const event = scene.vfxEvent || (scene.vfx > 0
        ? { style: scene.vfx, x: scene.playerX, y: scene.playerY + 2, z: scene.playerZ, tick: scene.tick }
        : null);
      if (event) {
        const requestedAssetId = Number.isInteger(event.assetId)
          ? event.assetId : VFX_LEGACY_STYLE_ASSET[event.style];
        const asset = Number.isInteger(requestedAssetId)
          ? VFX_ASSETS[requestedAssetId] : null;
        if (asset) {
          const key = [event.tick, asset.id, event.x, event.y, event.z].join(":");
          if (key !== vfxKey) {
            vfxKey = key;
            vfxStartedAt = time;
          }
          const age = time - vfxStartedAt;
          const frameCount = asset.frameCount || asset.columns * asset.rows;
          const frame = Math.min(frameCount - 1, Math.floor(age / asset.frameMs));
          const uvRect = [
            (frame % asset.columns) / asset.columns,
            (asset.rows - 1 - Math.floor(frame / asset.columns)) / asset.rows,
            1 / asset.columns,
            1 / asset.rows,
          ];
          if (age < frameCount * asset.frameMs) {
            const mesh = vfxMeshes[asset.id];
            const size = Number.isFinite(event.scale) ? event.scale : asset.scale;
            gl.enable(gl.BLEND);
            gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
            draw(mesh ? [mesh] : [fallbackMeshes.vfx], transform(
              [event.x, event.y, event.z], [size, size, 1], yaw + Math.PI / 2,
            ), COLORS.vfx, time, viewProjection, uvRect);
            gl.disable(gl.BLEND);
          }
        }
      }
      gl.bindVertexArray(null);
    }

    function captureScreenshot() {
      if (contextLost || (typeof gl.isContextLost === "function" && gl.isContextLost())) {
        throw new Error("WebGL context lost");
      }
      resize();
      gl.finish();
      const rgba = new Uint8Array(canvas.width * canvas.height * 4);
      gl.readPixels(
        0, 0, canvas.width, canvas.height, gl.RGBA, gl.UNSIGNED_BYTE, rgba,
      );
      return encodeScreenshot(canvas.width, canvas.height, rgba, true, gl.getError());
    }

    canvas.addEventListener("webglcontextlost", (event) => {
      event.preventDefault();
      contextLost = true;
    });
    canvas.addEventListener("webglcontextrestored", () => {
      contextLost = true;
    });
    resize();
    return Object.freeze({
      supported: true,
      reason: rendererStatus(),
      getStatus: rendererStatus,
      projectWorld,
      render,
      captureScreenshot,
      resize,
      destroy() {
        canvas.removeEventListener("wheel", handleCameraWheel);
        const meshes = [
          ...Object.values(fallbackMeshes),
          ...Object.values(assets).flatMap((value) => value?.meshes || []),
          ...Object.values(vfxMeshes).filter(Boolean),
          ...Object.values(rampMeshes).flat(),
        ];
        const textures = new Set();
        for (const mesh of meshes) {
          if (!mesh) continue;
          gl.deleteBuffer(mesh.vbo);
          if (mesh.skinVbo) gl.deleteBuffer(mesh.skinVbo);
          gl.deleteBuffer(mesh.ibo);
          gl.deleteVertexArray(mesh.vao);
          if (mesh.texture) textures.add(mesh.texture);
        }
        for (const texture of vfxTextures) {
          if (texture) textures.add(texture);
        }
        for (const texture of textures) gl.deleteTexture(texture);
        gl.deleteProgram(program);
      },
    });
  }

  window.KookieArenaGeometry = Object.freeze({
    solids: Object.freeze(ARENA_SOLIDS.map((entry) => Object.freeze({
      box: Object.freeze(entry.box.slice()),
    }))),
    water: Object.freeze(ARENA_WATER.map((entry) => Object.freeze({
      bounds: Object.freeze(entry.bounds.slice()),
      style: Object.freeze({
        style: Object.freeze(entry.style.style.slice()),
        tint: Object.freeze(entry.style.tint.slice()),
        toon: Object.freeze(entry.style.toon.slice()),
      }),
    }))),
    ramps: Object.freeze(ARENA_RAMPS.map((ramp) => Object.freeze({
      vertices: Object.freeze(ramp.vertices.map((vertex) => Object.freeze(vertex.slice()))),
    }))),
    maps: Object.freeze(Object.fromEntries(
      Object.entries(ARENA_MAPS).map(([mapId, map]) => [mapId, Object.freeze({
        name: mapId === "1" ? "G1 Central Pool" : "G2 Ruins",
        solids: Object.freeze(map.solids.map((entry) =>
          Object.freeze({ box: Object.freeze(entry.box.slice()) }))),
        ramps: Object.freeze(map.ramps.map((ramp) =>
          Object.freeze({ vertices: Object.freeze(
            ramp.vertices.map((vertex) => Object.freeze(vertex.slice())),
          ) }))),
      })]),
    )),
  });
  window.KookieWebRenderer = Object.freeze({ create, encodeScreenshot });
})();
