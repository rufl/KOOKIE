(() => {
  "use strict";

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
    uniform sampler2D uAlbedo;
    uniform bool uUseTexture;
    out vec4 outColor;
    void main() {
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
    actorAlt: [0.95, 0.62, 0.16, 1],
    damaged: [0.28, 0.32, 0.38, 1],
    projectile: [1.0, 0.88, 0.20, 1],
    pickup: [0.30, 1.0, 0.58, 1],
    vfx: [1.0, 0.35, 0.72, 1],
    water: [0.05, 0.34, 0.45, 0.72],
  });

  const ARENA_SOLIDS = Object.freeze([
    { box: [0, 0, 0, 4, 24, 280], color: COLORS.wall },
    { box: [316, 0, 0, 320, 24, 280], color: COLORS.wall },
    { box: [4, 0, 0, 316, 24, 4], color: COLORS.wall },
    { box: [4, 0, 276, 316, 24, 280], color: COLORS.wall },
    { box: [92, 6, 146, 228, 9, 158], color: [0.24, 0.30, 0.38, 1] },
    { box: [154, 6, 92, 166, 9, 212], color: [0.24, 0.30, 0.38, 1] },
    { box: [228, 6, 66, 308, 9, 78], color: [0.24, 0.30, 0.38, 1] },
    { box: [36, 8, 64, 96, 11, 216], color: [0.30, 0.36, 0.28, 1] },
    { box: [224, 8, 64, 284, 11, 216], color: [0.30, 0.36, 0.28, 1] },
    { box: [48, 16, 16, 272, 18, 48], color: [0.18, 0.25, 0.28, 1] },
    { box: [48, 16, 232, 272, 18, 264], color: [0.18, 0.25, 0.28, 1] },
    { box: [64, 0, 112, 88, 14, 136], color: [0.48, 0.18, 0.22, 1] },
    { box: [232, 0, 144, 256, 14, 168], color: [0.48, 0.18, 0.22, 1] },
    { box: [112, 0, 72, 132, 5, 92], color: COLORS.cover },
    { box: [188, 0, 184, 208, 5, 204], color: COLORS.cover },
  ]);
  const ARENA_WATER = Object.freeze([
    [96, 5, 96, 224, 208],
    [232, 4, 32, 304, 112],
  ]);
  const ARENA_RAMPS = Object.freeze([
    {
      vertices: [[20, 0, 56], [20, 0, 80], [40, 8, 80], [40, 8, 56]],
      color: [0.30, 0.38, 0.32, 1],
    },
    {
      vertices: [[280, 8, 200], [280, 8, 224], [300, 0, 224], [300, 0, 200]],
      color: [0.30, 0.38, 0.32, 1],
    },
  ]);

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
  ]);

  const VFX_LEGACY_STYLE_ASSET = Object.freeze({ 1: 5, 2: 8 });


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

  function transform(position, scale, rotationY = 0) {
    const c = Math.cos(rotationY);
    const s = Math.sin(rotationY);
    return [
      c * scale[0], 0, -s * scale[0], 0,
      0, scale[1], 0, 0,
      s * scale[2], 0, c * scale[2], 0,
      position[0], position[1], position[2], 1,
    ];
  }
  function actorAnimationLift(actor, tick) {
    const state = Number.isInteger(actor.state) ? actor.state : 1;
    const actorId = Number.isInteger(actor.id) ? actor.id : 0;
    const animationTick = Number.isFinite(tick) ? Math.trunc(tick) : 0;
    const phase = ((animationTick + actorId * 2) % 8 + 8) % 8;
    if (state === 3) return 2;
    if ((state === 1 || state === 2) && phase >= 4) return 1;
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

  function boxGeometry(gl, size, color) {
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
    const indices = [];
    for (let face = 0; face < 6; face += 1) {
      const offset = face * 4;
      indices.push(offset, offset + 1, offset + 2, offset, offset + 2, offset + 3);
    }
    return createMesh(gl, positions, normals, null, indices, color);
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

  function horizontalPlaneGeometry(gl, color) {
    const positions = new Float32Array([
      -0.5, 0, -0.5, 0.5, 0, -0.5, 0.5, 0, 0.5, -0.5, 0, 0.5,
    ]);
    const normals = new Float32Array([
      0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0,
    ]);
    const uvs = new Float32Array([0, 0, 1, 0, 1, 1, 0, 1]);
    return createMesh(
      gl, positions, normals, uvs, [0, 1, 2, 0, 2, 3], color,
    );
  }
  function rampGeometry(gl, top, color) {
    const bottom = top.map(([x, , z]) => [x, 0, z]);
    const positions = new Float32Array([...top, ...bottom].flat());
    const indices = [
      0, 1, 2, 0, 2, 3,
      4, 6, 5, 4, 7, 6,
      0, 4, 5, 0, 5, 1,
      1, 5, 6, 1, 6, 2,
      2, 6, 7, 2, 7, 3,
      3, 7, 4, 3, 4, 0,
    ];
    return createMesh(gl, positions, null, null, indices, color);
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
    const a00 = matrix[0], a01 = matrix[1], a02 = matrix[2], a03 = matrix[3];
    const a10 = matrix[4], a11 = matrix[5], a12 = matrix[6], a13 = matrix[7];
    const a20 = matrix[8], a21 = matrix[9], a22 = matrix[10], a23 = matrix[11];
    const a30 = matrix[12], a31 = matrix[13], a32 = matrix[14], a33 = matrix[15];
    const b00 = a00 * a11 - a01 * a10;
    const b01 = a00 * a12 - a02 * a10;
    const b02 = a00 * a13 - a03 * a10;
    const b03 = a01 * a12 - a02 * a11;
    const b04 = a01 * a13 - a03 * a11;
    const b05 = a02 * a13 - a03 * a12;
    const b06 = a20 * a31 - a21 * a30;
    const b07 = a20 * a32 - a22 * a30;
    const b08 = a20 * a33 - a23 * a30;
    const b09 = a21 * a32 - a22 * a31;
    const b10 = a21 * a33 - a23 * a31;
    const b11 = a22 * a33 - a23 * a32;
    const determinant =
      b00 * b11 - b01 * b10 + b02 * b09 +
      b03 * b08 - b04 * b07 + b05 * b06;
    if (Math.abs(determinant) < 1e-8) return null;
    const inverse = 1 / determinant;
    return [
      (a11 * b11 - a12 * b10 + a13 * b09) * inverse,
      (a02 * b10 - a01 * b11 - a03 * b09) * inverse,
      (a31 * b05 - a32 * b04 + a33 * b03) * inverse,
      (a22 * b04 - a21 * b05 - a23 * b03) * inverse,
      (a12 * b08 - a10 * b11 - a13 * b07) * inverse,
      (a00 * b11 - a02 * b08 + a03 * b07) * inverse,
      (a32 * b02 - a30 * b05 - a33 * b01) * inverse,
      (a20 * b05 - a22 * b02 + a23 * b01) * inverse,
      (a10 * b10 - a11 * b08 + a13 * b06) * inverse,
      (a30 * b04 - a31 * b02 + a33 * b00) * inverse,
      (a21 * b02 - a20 * b04 - a23 * b00) * inverse,
      (a20 * b03 - a21 * b01 + a22 * b00) * inverse,
      (a11 * b07 - a10 * b09 - a12 * b06) * inverse,
      (a01 * b09 - a00 * b07 + a02 * b06) * inverse,
      (a31 * b01 - a30 * b03 - a32 * b00) * inverse,
      (a30 * b02 - a31 * b00 + a32 * b01) * inverse,
    ];
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
    if (times.length === 0) return values.slice(0, components);
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

  async function loadGlb(url, gl) {
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
      const texture = textureIndex === undefined ? null : await loadTexture(textureIndex);
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
    const sampleSkinForState = (state, timeMs) => {
      if (skinnedNodes.length === 0 || skins.length === 0 || clips.length === 0) return null;
      const requested = state === 3 ? "attack" : state === 4 ? "death"
        : state === 2 ? "run" : "idle";
      const clip = clipsByName.get(requested) || clipsByName.get("walk") || clips[0];
      const seconds = Math.max(0, Number.isFinite(timeMs) ? timeMs : 0) / 1000;
      const sampleTime = clip.duration > 0 ? seconds % clip.duration : 0;
      const cacheKey = clip.fullName + ":" + Math.floor(seconds * 60);
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
      sampleSkinForState,
    });
  }
  async function loadTextureUrl(gl, url) {
    const response = await fetch(url, { cache: "force-cache" });
    if (!response.ok) throw new Error("texture HTTP " + response.status + " / " + url);
    return textureFromBlob(gl, await response.blob());
  }

  function encodeScreenshot(width, height, rgba, flipY, glError = 0) {
    const header = new TextEncoder().encode(`P6\n${width} ${height}\n255\n`);
    const ppm = new Uint8Array(header.length + width * height * 3);
    ppm.set(header);
    let offset = header.length;
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
        ppm[offset++] = red;
        ppm[offset++] = green;
        ppm[offset++] = blue;
        checksum = Math.imul(checksum ^ red, 16777619) >>> 0;
        checksum = Math.imul(checksum ^ green, 16777619) >>> 0;
        checksum = Math.imul(checksum ^ blue, 16777619) >>> 0;
      }
    }
    let binary = "";
    for (let start = 0; start < ppm.length; start += 0x8000) {
      binary += String.fromCharCode(...ppm.subarray(start, start + 0x8000));
    }
    return Object.freeze({
      format: "P6",
      mimeType: "image/x-portable-pixmap",
      width,
      height,
      byteLength: ppm.length,
      nonBlackPixels,
      checksum,
      glError,
      base64: btoa(binary),
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
    if (!gl) return { supported: false, reason: "WebGL2 unavailable; 2D fallback" };
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
      uvScale: gl.getUniformLocation(program, "uUvScale"),
      uvOffset: gl.getUniformLocation(program, "uUvOffset"),
      albedo: gl.getUniformLocation(program, "uAlbedo"),
      useTexture: gl.getUniformLocation(program, "uUseTexture"),
      joints: gl.getUniformLocation(program, "uJoints[0]"),
      useSkinning: gl.getUniformLocation(program, "uUseSkinning"),
    };
    const fallbackMeshes = {
      solid: boxGeometry(gl, [1, 1, 1], [1, 1, 1, 1]),
      water: horizontalPlaneGeometry(gl, [1, 1, 1, 1]),
      actor: boxGeometry(gl, [8, 14, 8], COLORS.actor),
      pickup: boxGeometry(gl, [5, 5, 5], COLORS.pickup),
      projectile: boxGeometry(gl, [2.5, 2.5, 2.5], COLORS.projectile),
      vfx: boxGeometry(gl, [12, 1, 12], COLORS.vfx),
    };
    const rampMeshes = ARENA_RAMPS.map((ramp) =>
      rampGeometry(gl, ramp.vertices, ramp.color));

    const assets = { goose: null, cat: null };
    const vfxTextures = new Array(VFX_ASSETS.length).fill(null);
    const vfxMeshes = new Array(VFX_ASSETS.length).fill(null);
    const assetFailures = [];
    const assetBase = "assets/prototype/models/";
    const assetLoads = [
      ["goose", assetBase + "goose/goose.glb"],
      ["cat", assetBase + "cat/cat.glb"],
    ].map(async ([name, url]) => {
      try {
        assets[name] = await loadGlb(url, gl);
      } catch (error) {
        assets[name] = null;
        assetFailures.push(name + ": " + error.message);
      }
    });
    const vfxLoads = VFX_ASSETS.map(async (asset) => {
      try {
        vfxTextures[asset.id] = await loadTextureUrl(gl, asset.path);
        vfxMeshes[asset.id] = planeGeometry(gl, COLORS.vfx, vfxTextures[asset.id]);
      } catch (error) {
        assetFailures.push(asset.name + ": " + error.message);
      }
    });
    let assetReady = false;
    let contextLost = false;
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
      skinMatricesByNode = null,
    ) {
      gl.uniform2f(locations.uvScale, uvRect[2], uvRect[3]);
      gl.uniform2f(locations.uvOffset, uvRect[0], uvRect[1]);
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

    let vfxKey = null;
    let vfxStartedAt = 0;
    function render(scene, time = 0) {
      if (contextLost || (typeof gl.isContextLost === "function" && gl.isContextLost())) return;
      resize();
      const camera = scene.camera || {
        x: scene.playerX, y: scene.playerY + 8, z: scene.playerZ - 16,
        yaw: scene.yaw, pitch: scene.pitch,
      };
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

      draw(
        [fallbackMeshes.solid],
        transform([160, -0.5, 140], [320, 1, 280]),
        COLORS.floor, time, viewProjection,
      );
      for (const entry of ARENA_SOLIDS) {
        const [left, bottom, front, right, top, back] = entry.box;
        draw(
          [fallbackMeshes.solid],
          transform(
            [(left + right) / 2, (bottom + top) / 2, (front + back) / 2],
            [right - left, top - bottom, back - front],
          ),
          entry.color, time, viewProjection,
        );
      }
      for (let index = 0; index < ARENA_RAMPS.length; index += 1) {
        draw(
          [rampMeshes[index]],
          identity(),
          ARENA_RAMPS[index].color, time, viewProjection,
        );
      }

      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      for (const [minX, surfaceY, minZ, maxX, maxZ] of ARENA_WATER) {
        draw(
          [fallbackMeshes.water],
          transform(
            [(minX + maxX) / 2, surfaceY, (minZ + maxZ) / 2],
            [maxX - minX, 1, maxZ - minZ],
          ),
          COLORS.water, time, viewProjection,
        );
      }
      gl.disable(gl.BLEND);

      const modelForActor = (actor) => actor.kind === 2 ? assets.cat : assets.goose;
      for (const actor of scene.actors || []) {
        if (actor.health <= 0) continue;
        const model = modelForActor(actor);
        const tint = actor.health < 50 ? COLORS.damaged : actor.kind === 2 ? COLORS.actorAlt : COLORS.actor;
        const scale = actor.kind === 2 ? [2.2, 2.2, 2.2] : [8, 8, 8];
        const actorYaw = actor.yaw === undefined ? 0 : actor.yaw * Math.PI / 180;
        const actorLift = actorAnimationLift(actor, scene.tick);
        const animationTime = time + (Number.isInteger(actor.id) ? actor.id * 137 : 0);
        const skinMatrices = model?.sampleSkinForState?.(actor.state, animationTime);
        draw(model?.meshes || [fallbackMeshes.actor], transform(
          [actor.x, actor.y + actorLift, actor.z], scale, actorYaw,
        ), tint, time, viewProjection, [0, 0, 1, 1], skinMatrices);
      }
      const playerModel = assets.goose;
      const playerSkinMatrices = playerModel?.sampleSkinForState?.(
        scene.playerState === undefined ? 1 : scene.playerState, time,
      );
      draw(playerModel?.meshes || [fallbackMeshes.actor], transform(
        [scene.playerX, scene.playerY, scene.playerZ], [8, 8, 8], yaw,
      ), COLORS.player, time, viewProjection, [0, 0, 1, 1], playerSkinMatrices);
      if (scene.pickup) {
        const bob = Math.sin(time * 0.004) * 0.7;
        draw([fallbackMeshes.pickup], transform(
          [scene.pickup.x, scene.pickup.y + 3 + bob, scene.pickup.z], [1, 1, 1], time * 0.001,
        ), COLORS.pickup, time, viewProjection);
      }
      for (const projectile of scene.projectiles || []) {
        draw([fallbackMeshes.projectile], transform(
          [projectile.x, projectile.y, projectile.z], [1, 1, 1], time * 0.003,
        ), COLORS.projectile, time, viewProjection);
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
          const frameCount = asset.columns * asset.rows;
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
      render,
      captureScreenshot,
      resize,
      destroy() {
        const meshes = [
          ...Object.values(fallbackMeshes),
          ...Object.values(assets).flatMap((value) => value?.meshes || []),
          ...Object.values(vfxMeshes).filter(Boolean),
          ...rampMeshes,

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
    water: Object.freeze(ARENA_WATER.map((entry) => Object.freeze(entry.slice()))),
    ramps: Object.freeze(ARENA_RAMPS.map((ramp) => Object.freeze({
      vertices: Object.freeze(ramp.vertices.map((vertex) => Object.freeze(vertex.slice()))),
    }))),
  });
  window.KookieWebRenderer = Object.freeze({ create, encodeScreenshot });
})();
