(() => {
  "use strict";

  const VERTEX_SHADER = `#version 300 es
    precision highp float;
    layout(location = 0) in vec3 aPosition;
    layout(location = 1) in vec3 aNormal;
    uniform mat4 uViewProjection;
    uniform mat4 uModel;
    out vec3 vNormal;
    out vec3 vWorld;
    void main() {
      vec4 world = uModel * vec4(aPosition, 1.0);
      vWorld = world.xyz;
      vNormal = mat3(uModel) * aNormal;
      gl_Position = uViewProjection * world;
    }
  `;
  const FRAGMENT_SHADER = `#version 300 es
    precision highp float;
    in vec3 vNormal;
    in vec3 vWorld;
    uniform vec4 uColor;
    uniform vec3 uLight;
    uniform float uTime;
    out vec4 outColor;
    void main() {
      vec3 normal = normalize(vNormal);
      float diffuse = max(dot(normal, normalize(uLight)), 0.0);
      float heightFog = clamp((vWorld.y + 2.0) / 90.0, 0.0, 1.0);
      vec3 lit = uColor.rgb * (0.28 + diffuse * 0.72);
      lit += uColor.rgb * (0.08 * sin(uTime * 4.0 + vWorld.x * 0.04));
      lit = mix(lit, vec3(0.015, 0.035, 0.06), heightFog * 0.08);
      outColor = vec4(lit, uColor.a);
    }
  `;

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
  });

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

  function createMesh(gl, positions, normals, indices, color) {
    const vertexCount = positions.length / 3;
    const generatedNormals = normals && normals.length === positions.length
      ? normals : new Float32Array(positions.length);
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
    const interleaved = new Float32Array(vertexCount * 6);
    for (let index = 0; index < vertexCount; index += 1) {
      interleaved.set(positions.slice(index * 3, index * 3 + 3), index * 6);
      interleaved.set(generatedNormals.slice(index * 3, index * 3 + 3), index * 6 + 3);
    }
    const vao = gl.createVertexArray();
    const vbo = gl.createBuffer();
    const ibo = gl.createBuffer();
    if (!vao || !vbo || !ibo) throw new Error("WebGL mesh allocation failed");
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, interleaved, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 24, 0);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 24, 12);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint32Array(indices), gl.STATIC_DRAW);
    gl.bindVertexArray(null);
    return Object.freeze({ vao, ibo, count: indices.length, color: color || COLORS.wall });
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
    return createMesh(gl, positions, normals, indices, color);
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

  function accessorValues(json, binary, accessorIndex) {
    const accessor = json.accessors[accessorIndex];
    const bufferView = json.bufferViews[accessor.bufferView];
    const componentCount = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[accessor.type];
    if (!componentCount || !bufferView) throw new Error("invalid GLB accessor");
    const componentSize = { 5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4 }[accessor.componentType];
    const stride = bufferView.byteStride || componentSize * componentCount;
    const base = (bufferView.byteOffset || 0) + (accessor.byteOffset || 0);
    const view = new DataView(binary);
    const values = new Array(accessor.count * componentCount);
    for (let index = 0; index < accessor.count; index += 1) {
      for (let component = 0; component < componentCount; component += 1) {
        values[index * componentCount + component] = readComponent(
          view, base + index * stride + component * componentSize, accessor.componentType,
        );
      }
    }
    return values;
  }

  async function loadGlb(url, gl) {
    const response = await fetch(url, { cache: "force-cache" });
    if (!response.ok) throw new Error("GLB HTTP " + response.status + " / " + url);
    const buffer = await response.arrayBuffer();
    const data = new DataView(buffer);
    if (data.getUint32(0, true) !== 0x46546c67) throw new Error("GLB magic rejected");
    const jsonLength = data.getUint32(12, true);
    const json = JSON.parse(new TextDecoder().decode(new Uint8Array(buffer, 20, jsonLength)));
    let binaryOffset = 20 + jsonLength + 8;
    const binLength = data.getUint32(20 + jsonLength, true);
    const binary = buffer.slice(binaryOffset, binaryOffset + binLength);
    const meshes = [];
    for (const mesh of json.meshes || []) {
      for (const primitive of mesh.primitives || []) {
        if (primitive.mode !== undefined && primitive.mode !== 4) continue;
        const positions = accessorValues(json, binary, primitive.attributes.POSITION);
        const normals = primitive.attributes.NORMAL === undefined
          ? null : accessorValues(json, binary, primitive.attributes.NORMAL);
        let indices;
        if (primitive.indices === undefined) {
          indices = Array.from({ length: positions.length / 3 }, (_, index) => index);
        } else {
          indices = accessorValues(json, binary, primitive.indices);
        }
        const material = json.materials?.[primitive.material || 0];
        const factor = material?.pbrMetallicRoughness?.baseColorFactor || [1, 1, 1, 1];
        meshes.push(createMesh(gl, new Float32Array(positions), normals && new Float32Array(normals), indices, factor));
      }
    }
    return meshes;
  }

  function create(canvas) {
    let gl;
    try {
      gl = canvas.getContext("webgl2", { antialias: true, alpha: false });
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
    };
    const fallbackMeshes = {
      floor: boxGeometry(gl, [320, 1, 280], COLORS.floor),
      wall: boxGeometry(gl, [8, 18, 280], COLORS.wall),
      cover: boxGeometry(gl, [18, 8, 18], COLORS.cover),
      actor: boxGeometry(gl, [8, 14, 8], COLORS.actor),
      pickup: boxGeometry(gl, [5, 5, 5], COLORS.pickup),
      projectile: boxGeometry(gl, [2.5, 2.5, 2.5], COLORS.projectile),
      vfx: boxGeometry(gl, [12, 1, 12], COLORS.vfx),
    };
    const assets = { ground: null, wall: null, goose: null, cat: null };
    const assetFailures = [];
    const assetBase = "assets/prototype/models/";
    const assetLoads = [
      ["ground", assetBase + "modular/ground.glb"],
      ["wall", assetBase + "modular/wall.glb"],
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
    let assetReady = false;
    let contextLost = false;
    Promise.all(assetLoads).then(() => { assetReady = true; });
    function rendererStatus() {
      if (contextLost) return "WebGL2 / context lost";
      if (!assetReady) return "WebGL2 / loading GLB assets";
      if (assetFailures.length > 0) return "WebGL2 / fallback meshes (" + assetFailures.length + " asset failures)";
      return "WebGL2 / GLB scene renderer";
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

    function draw(meshes, model, tint, time, viewProjection) {
      for (const mesh of meshes || []) {
        gl.bindVertexArray(mesh.vao);
        gl.uniformMatrix4fv(locations.model, false, new Float32Array(model));
        const material = mesh.color || [1, 1, 1, 1];
        gl.uniform4f(
          locations.color,
          material[0] * tint[0], material[1] * tint[1], material[2] * tint[2], tint[3],
        );
        gl.drawElements(gl.TRIANGLES, mesh.count, gl.UNSIGNED_INT, 0);
      }
    }

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
        Math.cos(yaw) * Math.cos(pitch), Math.sin(pitch), Math.sin(yaw) * Math.cos(pitch),
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

      draw(fallbackMeshes.floor ? [fallbackMeshes.floor] : null, transform([160, -0.5, 140], [1, 1, 1]), COLORS.floor, time, viewProjection);
      draw(fallbackMeshes.wall ? [fallbackMeshes.wall] : null, transform([4, 9, 140], [1, 1, 1]), COLORS.wall, time, viewProjection);
      draw([fallbackMeshes.wall], transform([316, 9, 140], [1, 1, 1]), COLORS.wall, time, viewProjection);
      draw([fallbackMeshes.cover], transform([110, 4, 110], [1, 1, 1]), COLORS.cover, time, viewProjection);
      draw([fallbackMeshes.cover], transform([230, 4, 190], [1.3, 1, 0.8]), COLORS.cover, time, viewProjection);
      if (assets.ground) draw(assets.ground, transform([160, 0, 140], [160, 1, 140]), COLORS.floor, time, viewProjection);
      if (assets.wall) {
        draw(assets.wall, transform([24, 0, 32], [8, 8, 8], Math.PI / 2), COLORS.wall, time, viewProjection);
        draw(assets.wall, transform([288, 0, 220], [8, 8, 8], -Math.PI / 2), COLORS.wall, time, viewProjection);
      }

      const modelForActor = (actor) => actor.kind === 2 ? assets.cat : assets.goose;
      for (const actor of scene.actors || []) {
        if (actor.health <= 0) continue;
        const model = modelForActor(actor);
        const tint = actor.health < 50 ? COLORS.damaged : actor.kind === 2 ? COLORS.actorAlt : COLORS.actor;
        const scale = actor.kind === 2 ? [2.2, 2.2, 2.2] : [8, 8, 8];
        draw(model || [fallbackMeshes.actor], transform([actor.x, actor.y, actor.z], scale, actor.id), tint, time, viewProjection);
      }
      draw(assets.goose || [fallbackMeshes.actor], transform(
        [scene.playerX, scene.playerY, scene.playerZ], [8, 8, 8], yaw,
      ), COLORS.player, time, viewProjection);
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
      if (scene.vfx > 0) {
        draw([fallbackMeshes.vfx], transform(
          [scene.playerX, 0.5, scene.playerZ], [1 + scene.vfx * 0.2, 1, 1 + scene.vfx * 0.2], 0,
        ), COLORS.vfx, time, viewProjection);
      }
      gl.bindVertexArray(null);
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
      resize,
      destroy() {
        for (const mesh of Object.values(fallbackMeshes)) {
          gl.deleteBuffer(mesh.ibo);
          gl.deleteVertexArray(mesh.vao);
        }
        gl.deleteProgram(program);
      },
    });
  }

  window.KookieWebRenderer = Object.freeze({ create });
})();
