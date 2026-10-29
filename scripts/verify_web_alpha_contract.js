#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const outputDir = path.resolve(process.argv[2] || process.env.KOOKIE_WEB_ALPHA_OUTPUT || "build/kookie-web-alpha");
const transportPath = path.join(outputDir, "kookie-session.js");
const rendererPath = path.join(outputDir, "kookie-webgl-renderer.js");
const rendererSource = fs.readFileSync(rendererPath, "utf8");
const transportSource = fs.readFileSync(transportPath, "utf8");

class FakeElement {
  constructor(tagName) {
    this.tagName = tagName.toUpperCase();
    this.children = [];
    this.parentNode = null;
    this.attributes = {};
    this.listeners = {};
    this.style = {};
    this.dataset = {};
    this.classList = { toggle: () => {}, add: () => {}, remove: () => {} };
    this.textContent = "";
    this.value = "";
    this.checked = false;
    this.disabled = false;
    this.selected = false;
    this.id = "";
    this.width = 0;
    this.height = 0;
  }
  showModal() { this.open = true; }
  close() { this.open = false; }
  focus() {}
  toBlob(callback, type) {
    callback(new Blob([Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10])], { type }));
  }

  appendChild(child) {
    child.parentNode = this;
    this.children.push(child);
    return child;
  }
  append(...children) {
    for (const child of children) this.appendChild(child);
  }
  removeChild(child) {
    const index = this.children.indexOf(child);
    if (index >= 0) this.children.splice(index, 1);
    child.parentNode = null;
    return child;
  }
  insertBefore(child, before) {
    const index = this.children.indexOf(before);
    if (index < 0) return this.appendChild(child);
    child.parentNode = this;
    this.children.splice(index, 0, child);
    return child;
  }

  setAttribute(name, value) {
    this.attributes[name] = String(value);
    if (name === "id") this.id = String(value);
  }

  addEventListener(name, handler) {
    this.listeners[name] = handler;
  }

  getBoundingClientRect() {
    return { left: 0, top: 0, width: this.width || 960, height: this.height || 480 };
  }

  getContext(type) {
    return {
      clearRect() {}, fillRect() {}, strokeRect() {}, beginPath() {},
      arc() {}, fill() {},
      createImageData(width, height) { return { data: new Uint8ClampedArray(width * height * 4) }; },
      putImageData() {},
    };
  }

  requestPointerLock() {}
}

class FakeDocument {
  constructor() {
    this.body = new FakeElement("body");
    this.head = new FakeElement("head");
    const root = new FakeElement("div");
    root.id = "kof-root";
    this.body.appendChild(root);
    this.pointerLockElement = null;
    this.listeners = {};
  }

  createElement(tagName) { return new FakeElement(tagName); }
  createElementNS(_namespace, tagName) { return new FakeElement(tagName); }
  createTextNode(text) {
    const node = new FakeElement("#text");
    node.textContent = String(text);
    return node;
  }
  addEventListener(name, handler) {
    const previous = this.listeners[name];
    this.listeners[name] = previous
      ? (event) => { previous(event); handler(event); }
      : handler;
  }

  getElementById(id) {
    const visit = (node) => {
      if (node.id === id) return node;
      for (const child of node.children) {
        const match = visit(child);
        if (match) return match;
      }
      return null;
    };
    return visit(this.body) || visit(this.head);
  }
}

function messageChecksum(words) {
  let result = 53;
  for (const value of words) {
    let normalized = value % 1000003;
    if (normalized < 0) normalized += 1000003;
    result = (result * 31 + normalized) % 1000003;
  }
  return result;
}

function wireChecksum(bytes) {
  let result = 0;
  for (let index = 0; index < bytes.length; index += 1) {
    result = (result + (index === 14 || index === 15 ? 0 : bytes[index]) * (index + 1)) % 65536;
  }
  return result;
}

function encodeFrame(kind, sequence, words) {
  const bytes = new Uint8Array(16 + words.length * 4);
  bytes.set([0x4b, 0x57, 0x53, 0x31, 1, kind, 0, 0]);
  const view = new DataView(bytes.buffer);
  view.setUint32(8, sequence, false);
  view.setUint16(12, words.length, false);
  words.forEach((value, index) => view.setInt32(16 + index * 4, value, false));
  view.setUint16(14, wireChecksum(bytes), false);
  return bytes.buffer;
}

function fullSceneWords(sequence) {
  const words = [
    2, 6, sequence, 4, 12,
    32, 1, 52, 0, -8, 100, 100, 24, 0, 0,
    32, 9, 36, 0, -8, 4,
  ];
  for (let index = 0; index < 4; index += 1) {
    words.push(index + 1, 96 + index * 24, 1, 80 + index * 24,
      100, index === 3 ? 3 : 1, index % 2 === 0 ? 1 : 2, index * 90);
  }
  words.push(0, 0, 0, 0, 0, 0, 1, 1, 128, 1, 112, 32, 3, 52, 3, 10);
  words.push(
    1, 2, 0, 5, 5, 5, 3, 5, 1,
    2, 1, 1, 150, 9, 140, 2, 2, 2,
    2, 2, 0, 180, 9, 150, 2, 2, 2,
    3, 1, 1, 32, 1, 52, 2, 2, 2,
    3, 2, 1, 72, 1, 64, 3, 3, 3,
    3, 3, 1, 120, 1, 96, 2, 2, 2,
    3, 4, 1, 150, 5, 140, 3, 3, 3,
    3, 5, 1, 260, 1, 60, 2, 2, 2,
    3, 6, 1, 200, 1, 120, 2, 2, 2,
    4, 100, 1, 128, 1, 112, 2, 4, 2,
    4,
    1, 1, 96, 1, 80, 1,
    2, 2, 208, 1, 160, 1,
    3, 3, 260, 1, 220, 1,
    4, 4, 150, 1, 210, 1,
  );
  words.push(messageChecksum(words));
  assert.equal(words.length, 185);
  return words;
}
function fullSceneAt(sequence, tick, actorX) {
  const words = fullSceneWords(sequence);
  words[4] = tick;
  words[22] = actorX;
  words[words.length - 1] = messageChecksum(words.slice(0, -1));
  return words;
}
function extendedMultiplayerWords(sequence, tick, localX = 32, lastInputSequence = 7) {
  const words = [
    2, 6, sequence, 7, tick,
    1, 1, 32, 32, 52, 0, 0, 100, 100, 30, 2, 0, 2,
    1, localX, 1, 52, 100, 1, 1, 0,
    2, 40, 1, 52, 80, 1, 2, 90,
    lastInputSequence, 1, 1, 1,
    11, 1, 2, 36, 4, 52, 20,
    12, 1, 36, 5, 52, 2, 2, 36,
    1, 3, 1, 2, 40, 4, 52, 20,
  ];
  words.push(messageChecksum(words));
  return words;
}
function multiplayerPositionWords(sequence, tick, localX) {
  const words = extendedMultiplayerWords(5, 15);
  words[2] = sequence;
  words[4] = tick;
  words[19] = localX;
  words.length = 34;
  words.push(messageChecksum(words));
  return words;
}


let fullSceneSent = false;
const sentGameCommands = [];
const sentInputFrames = [];

function collectElements(root) {
  return [root, ...root.children.flatMap(collectElements)];
}

class FakeWebSocket {
  static CONNECTING = 0;
  static OPEN = 1;
  static CLOSING = 2;
  static CLOSED = 3;
  static active = null;
  static connections = [];
  static nextPlayerId = 1;
  constructor(url, protocols) {
    FakeWebSocket.connections.push(this);
    FakeWebSocket.active = this;
    this.url = url;
    this.protocols = protocols;
    this.readyState = FakeWebSocket.CONNECTING;
    this.binaryType = "arraybuffer";
    this.onopen = null;
    this.onmessage = null;
    this.onerror = null;
    this.onclose = null;
    queueMicrotask(() => {
      this.readyState = FakeWebSocket.OPEN;
      if (this.onopen) this.onopen();
    });
  }

  send(buffer) {
    const view = new DataView(buffer);
    const kind = view.getUint8(5);
    const sequence = view.getUint32(8, false);
    if (kind === 1) {
      const words = [2, 2, sequence, 1, 1, 1];
      words.push(messageChecksum(words));
      this.emit(encodeFrame(2, sequence, words));
      return;
    }
    if (kind === 6 && view.getInt32(16 + 3 * 4, false) === 5) {
      const role = view.getInt32(16 + 4 * 4, false);
      this.joined = true;
      const playerId = FakeWebSocket.nextPlayerId++;
      const words = [2, 6, sequence, 6, 1, role, playerId,
        Math.min(8, FakeWebSocket.nextPlayerId - 1), 0];
      words.push(messageChecksum(words));
      this.emit(encodeFrame(6, sequence, words));
      return;
    }
    if (kind === 6 && view.getInt32(16 + 3 * 4, false) === 7127) {
      fullSceneSent = true;
      this.emit(encodeFrame(6, sequence, fullSceneWords(sequence)));
      return;
    }
    if (kind === 6 && view.getInt32(16 + 3 * 4, false) === 8) {
      sentInputFrames.push({
        sequence,
        moveX: view.getInt32(16 + 5 * 4, false),
        moveZ: view.getInt32(16 + 6 * 4, false),
        lookYaw: view.getInt32(16 + 7 * 4, false),
        lookPitch: view.getInt32(16 + 8 * 4, false),
        held: view.getInt32(16 + 9 * 4, false),
        edge: view.getInt32(16 + 10 * 4, false),
      });
      return;
    }
    if (kind === 6 && view.getInt32(16 + 3 * 4, false) === 1) {
      const command = view.getInt32(16 + 4 * 4, false);
      if (command === 7) {
        fullSceneSent = true;
        this.emit(encodeFrame(6, sequence, fullSceneWords(sequence)));
      } else {
        sentGameCommands.push({
          command,
          value: view.getInt32(16 + 5 * 4, false),
        });
      }
    }
    if (kind === 3) {
      const words = [2, 4, sequence];
      words.push(messageChecksum(words));
      this.emit(encodeFrame(4, sequence, words));
      return;
    }
  }


  emitScene(sequence, tick, actorX) {
    this.emit(encodeFrame(6, sequence, fullSceneAt(sequence, tick, actorX)));
  }

  emit(data) {
    queueMicrotask(() => {
      if (this.onmessage) this.onmessage({ data });
    });
  }

  close() {
    this.readyState = FakeWebSocket.CLOSED;
    if (this.onclose) this.onclose();
  }
}

async function waitFor(predicate) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await new Promise((resolve) => setImmediate(resolve));
  }
  throw new Error("browser contract smoke timed out");
}

async function main() {
  const document = new FakeDocument();
  const renderedScenes = [];
  const renderedActorXs = [];
  const frameCallbacks = [];
  const renderer = {
    supported: true,
    reason: "contract renderer",
    render(scene) {
      renderedScenes.push(scene);
      renderedActorXs.push(scene.actors[0].x);
    },
    getStatus() { return "contract renderer"; },
    projectWorld() { return { x: 0.5, y: 0.5, depth: 0.5 }; },
    captureScreenshot() {
      return {
        format: "P6", width: 1, height: 1, nonBlackPixels: 1, checksum: 1,
        pixels: new Uint8Array([255, 0, 0, 255]), flipY: false,
      };
    },
    destroy() {},
  };
  const savedSettings = [];
  let monotonicNow = 0;
  let bugfeedUploadCount = 0;
  let bugfeedEnvelope;
  const bugfeedId = "123e4567-e89b-42d3-a456-426614174000";
  const window = {
    document,
    location: {
      href: "https://game.internal/index.html?secret=must-not-upload",
      origin: "https://game.internal",
      pathname: "/index.html",
      search: "?secret=must-not-upload",
    },
    innerWidth: 800,
    innerHeight: 600,
    devicePixelRatio: 2,
    localStorage: {
      getItem: () => null,
      setItem: (key, value) => savedSettings.push({ key, value: JSON.parse(value) }),
    },
    matchMedia: () => ({ matches: false, addEventListener() {} }),
    KookieWebRenderer: { create: () => renderer },
    requestAnimationFrame: (callback) => { frameCallbacks.push(callback); return frameCallbacks.length; },
    cancelAnimationFrame: () => {},
    setTimeout,
    clearTimeout,
    setInterval: () => 1,
    clearInterval: () => {},
    addEventListener: () => {},
  };
  const context = {
    window, document, WebSocket: FakeWebSocket, URL, URLSearchParams,
    ArrayBuffer, DataView, Uint8Array, Uint8ClampedArray, TextEncoder, TextDecoder,
    Math, Number, Object, JSON, Promise, Error, TypeError, console,
    performance: { now: () => monotonicNow },
    navigator: { userAgent: "Bugfeed browser smoke", clipboard: { writeText: async () => {} } },
    fetch: async (url, options) => {
      if (url.startsWith("assets/prototype/runtime/power_ups/")) {
        const configPath = path.resolve(__dirname, "..", url);
        return {
          ok: true,
          status: 200,
          json: async () => JSON.parse(fs.readFileSync(configPath, "utf8")),
        };
      }
      assert.equal(url, "/bugfeed");
      bugfeedEnvelope = options.body;
      bugfeedUploadCount += 1;
      return { ok: true, status: 201, json: async () => ({ id: bugfeedId }) };
    },
    queueMicrotask, setTimeout, clearTimeout, setImmediate, btoa: () => "",
  };
  vm.runInNewContext(rendererSource, context, { filename: rendererPath });
  assert.equal(typeof window.KookieWebRenderer?.create, "function");
  assert.equal(typeof window.KookieWebRenderer?.encodeScreenshot, "function");
  const arenaGeometry = window.KookieArenaGeometry;
  const overlaps = (a, b) =>
    a[0] < b[3] && a[3] > b[0] && a[2] < b[5] && a[5] > b[2];
  for (let left = 0; left < arenaGeometry.solids.length; left += 1) {
    const a = arenaGeometry.solids[left].box;
    for (let right = left + 1; right < arenaGeometry.solids.length; right += 1) {
      const b = arenaGeometry.solids[right].box;
      assert.ok(!(a[4] === b[4] && overlaps(a, b)),
        "arena solids must not have overlapping coplanar top textures");
    }
    for (const water of arenaGeometry.water) {
      const bounds = water.bounds;
      assert.ok(!(bounds[1] === a[4] &&
        bounds[0] < a[3] && bounds[3] > a[0] &&
        bounds[2] < a[5] && bounds[4] > a[2]),
      "water and solid top textures must not occupy the same plane");
    }
  }
  window.KookieWebRenderer = { create: () => renderer };
  vm.runInNewContext(transportSource, context, { filename: transportPath });
  assert.equal(typeof window.kookieSessionTransport.connect, "function");
  assert.equal(window.kookieSessionTransport.maxFrameBytes, 1296);
  assert.ok(document.getElementById("kookie-session-panel"));
  assert.ok(document.getElementById("kookie-authoritative-scene"));

  window.kookieSessionTransport.connect();
  await waitFor(() => FakeWebSocket.active.joined === true);
  window.kookieSessionTransport.gameProbe();
  await waitFor(() => fullSceneSent);
  await waitFor(() => document.getElementById("kookie-authoritative-scene")
    .attributes["aria-label"].includes("tick 12"));
  if (frameCallbacks.length > 0) frameCallbacks.shift()(0);
  await waitFor(() => renderedScenes.some((scene) => scene.sceneObjects?.length === 10));
  monotonicNow = 20;
  FakeWebSocket.active.emitScene(3, 13, 100);
  await waitFor(() => document.getElementById("kookie-authoritative-scene")
    .attributes["aria-label"].includes("tick 13"));
  monotonicNow = 70;
  FakeWebSocket.active.emitScene(4, 14, 140);
  await waitFor(() => document.getElementById("kookie-authoritative-scene")
    .attributes["aria-label"].includes("tick 14"));
  monotonicNow = 100;
  if (frameCallbacks.length > 0) frameCallbacks.shift()(100);
  const jitterSample = renderedActorXs.at(-1);
  assert.ok(Math.abs(jitterSample - 180) < 1e-6,
    "remote interpolation follows authoritative ticks despite uneven packet arrival");
  FakeWebSocket.active.emitScene(3, 13, 300);
  monotonicNow = 110;
  if (frameCallbacks.length > 0) frameCallbacks.shift()(110);
  assert.ok(renderedActorXs.at(-1) >= jitterSample,
    "stale snapshots cannot roll remote rendering backward");
  monotonicNow = 500;
  if (frameCallbacks.length > 0) frameCallbacks.shift()(500);
  const cappedExtrapolation = 140 + 40 * 100 / (1000 / 60);
  assert.ok(Math.abs(renderedActorXs.at(-1) - cappedExtrapolation) < 1e-6,
    "remote extrapolation stops at its configured 100 ms horizon");
  monotonicNow = 800;
  if (frameCallbacks.length > 0) frameCallbacks.shift()(800);
  assert.equal(renderedActorXs.at(-1), cappedExtrapolation,
    "long snapshot gaps do not extend the extrapolation horizon");


  monotonicNow = 800;
  const pageElements = collectElements(document.body);
  const playButton = pageElements.find((element) => element.textContent === "LEAVE");
  assert.equal(playButton.dataset.asyncState, "success");
  assert.equal(playButton.attributes["aria-busy"], "false");
  window.kookieSessionTransport.ping();
  await waitFor(() => pageElements.some((element) =>
    element.attributes["data-stat"] === "ping" &&
    element.children[1]?.textContent === "0 ms"));
  const pingValue = pageElements.find((element) =>
    element.attributes["data-stat"] === "ping").children[1];
  assert.equal(pingValue.dataset.flashing, "true");
  const gameHeading = pageElements.filter((element) =>
    element.id === "kookie-session-heading");
  assert.equal(gameHeading.length, 1);
  assert.equal(gameHeading[0].textContent, "GATOGANSO");
  const sticks = pageElements.filter((element) =>
    element.attributes["data-analog-stick"]);
  assert.deepEqual(sticks.map((element) =>
    element.attributes["data-analog-stick"]), ["move", "look"]);
  const shootButton = pageElements.find((element) =>
    element.attributes["data-action"] === "shoot");
  assert.ok(shootButton);
  assert.equal(shootButton.disabled, false);
  for (const [action, bit, held, edge] of [
    ["jump", 1, 1, 1], ["roll", 2, 0, 2], ["dash", 4, 0, 4],
    ["glide", 8, 8, 0], ["fly", 16, 16, 0], ["shoot", 32, 32, 0],
    ["melee", 64, 0, 64], ["special", 128, 0, 128],
    ["throwable", 256, 0, 256],
  ]) {
    const button = pageElements.find((element) =>
      element.attributes["data-action"] === action);
    assert.ok(button && !button.disabled, action + " control is enabled");
    button.listeners.pointerdown({ preventDefault() {} });
    assert.equal(sentInputFrames.at(-1).held & bit, held,
      action + " held bit is encoded in the input frame");
    assert.equal(sentInputFrames.at(-1).edge, edge,
      action + " edge bit is encoded in the input frame");
    button.listeners.pointerup();
    if (held) assert.equal(sentInputFrames.at(-1).held & bit, 0,
      action + " release clears its held bit");
  }
  document.listeners.keydown({
    code: "Space", key: " ", target: null, preventDefault() {},
  });
  assert.equal(sentInputFrames.at(-1).held & 1, 1,
    "Space keeps jump held for jump height");
  assert.equal(sentInputFrames.at(-1).edge, 1,
    "Space sends the jump-start edge to authoritative simulation");
  document.listeners.keyup({
    code: "Space", key: " ", target: null, preventDefault() {},
  });
  const movementSpeed = pageElements.find((element) =>
    element.attributes["aria-label"] === "Movement speed");
  const mouseSensitivity = pageElements.find((element) =>
    element.attributes["aria-label"] === "Camera sensitivity");
  assert.equal(movementSpeed.value, "50");
  assert.equal(movementSpeed.min, "25");
  assert.equal(movementSpeed.max, "100");
  assert.equal(mouseSensitivity.value, "50");
  assert.equal(mouseSensitivity.min, "25");
  assert.equal(mouseSensitivity.max, "150");
  const playerName = pageElements.find((element) =>
    element.attributes["aria-label"] === "Player name");
  assert.ok(playerName);
  playerName.value = "Mango";
  playerName.listeners.input();
  assert.equal(savedSettings.at(-1).value.playerName, "Mango");
  const moveStickBase = sticks[0].children[0];
  moveStickBase.width = 100;
  moveStickBase.height = 100;
  moveStickBase.listeners.pointerdown({
    pointerId: 4, clientX: 88, clientY: 50, preventDefault() {},
  });
  assert.ok(sentInputFrames.at(-1).moveX <= -490 &&
    sentInputFrames.at(-1).moveX >= -510 &&
    sentInputFrames.at(-1).moveZ === 0,
  "right touch deflection moves right at the configured 50% movement speed");
  const movementCountAtDefault = sentInputFrames.length;
  moveStickBase.listeners.pointermove({
    pointerId: 4, clientX: 99, clientY: 50,
  });
  const pendingFrames = frameCallbacks.splice(0);
  for (const frame of pendingFrames) frame(1035);
  await new Promise((resolve) => setTimeout(resolve, 150));
  assert.equal(sentInputFrames.length, movementCountAtDefault + 1);
  moveStickBase.listeners.pointerup({ pointerId: 4 });
  movementSpeed.value = "100";
  movementSpeed.listeners.input();
  assert.equal(savedSettings.at(-1).value.movementSpeedPercent, 100);
  moveStickBase.listeners.pointerdown({
    pointerId: 6, clientX: 70, clientY: 50, preventDefault() {},
  });
  const partialDeflectionCount = sentInputFrames.length;
  await new Promise((resolve) => setTimeout(resolve, 150));
  assert.equal(sentInputFrames.length, partialDeflectionCount);
  moveStickBase.listeners.pointerup({ pointerId: 6 });
  moveStickBase.listeners.pointerdown({
    pointerId: 10, clientX: 88, clientY: 50, preventDefault() {},
  });
  await new Promise((resolve) => setTimeout(resolve, 150));
  assert.ok(sentInputFrames.length > partialDeflectionCount);
  moveStickBase.listeners.pointerup({ pointerId: 10 });
  const fastMovementCount = sentInputFrames.length;
  await new Promise((resolve) => setTimeout(resolve, 150));
  assert.equal(sentInputFrames.length, fastMovementCount);
  const beforeDeadzone = sentInputFrames.length;
  moveStickBase.listeners.pointerdown({
    pointerId: 7, clientX: 53, clientY: 50, preventDefault() {},
  });
  assert.equal(sentInputFrames.length, beforeDeadzone + 1);
  assert.equal(sentInputFrames.at(-1).moveX, 0);
  assert.equal(sentInputFrames.at(-1).moveZ, 0);
  moveStickBase.listeners.pointerup({ pointerId: 7 });
  document.listeners.keydown({
    key: "w", code: "KeyW", repeat: false, preventDefault() {},
  });
  assert.equal(sentInputFrames.at(-1).moveZ, 1000);
  const keyboardFrameCount = sentInputFrames.length;
  document.listeners.keydown({
    key: "w", code: "KeyW", repeat: true, preventDefault() {},
  });
  assert.equal(sentInputFrames.length, keyboardFrameCount,
    "key repeat does not create redundant movement frames");
  document.listeners.keydown({
    key: "d", code: "KeyD", repeat: false, preventDefault() {},
  });
  assert.ok(Math.abs(sentInputFrames.at(-1).moveX + 707) <= 1);
  assert.ok(Math.abs(sentInputFrames.at(-1).moveZ - 707) <= 1,
    "diagonal keyboard movement is normalized");
  document.listeners.keyup({ key: "d", code: "KeyD", preventDefault() {} });
  assert.equal(sentInputFrames.at(-1).moveX, 0);
  assert.equal(sentInputFrames.at(-1).moveZ, 1000);
  document.listeners.keyup({ key: "w", code: "KeyW", preventDefault() {} });
  assert.equal(sentInputFrames.at(-1).moveX, 0);
  assert.equal(sentInputFrames.at(-1).moveZ, 0);
  document.listeners.keydown({
    key: "a", code: "KeyA", repeat: false, preventDefault() {},
  });
  assert.equal(sentInputFrames.at(-1).moveX, 1000,
    "A moves left in the browser world's mirrored horizontal axis");
  document.listeners.keyup({ key: "a", code: "KeyA", preventDefault() {} });
  const lookStickBase = sticks[1].children[0];
  lookStickBase.width = 100;
  lookStickBase.height = 100;
  frameCallbacks.splice(0);
  lookStickBase.listeners.pointerdown({
    pointerId: 11, clientX: 88, clientY: 50, preventDefault() {},
  });
  const lookFrames = frameCallbacks.splice(0);
  lookFrames[0](1200);
  assert.ok(sentInputFrames.at(-1).lookYaw < 0,
    "right touch-stick deflection turns the camera right");
  lookStickBase.listeners.pointerup({ pointerId: 11 });
  frameCallbacks.splice(0);
  const sceneCanvas = document.getElementById("kookie-authoritative-scene");
  const beforeMouseLook = sentGameCommands.length;
  sceneCanvas.listeners.pointerdown({
    pointerId: 8, pointerType: "touch", clientX: 50, clientY: 50, preventDefault() {},
  });
  sceneCanvas.listeners.pointermove({ pointerId: 8, pointerType: "touch", clientX: 73, clientY: 50 });
  assert.equal(sentGameCommands.length, beforeMouseLook);
  assert.equal(sentInputFrames.at(-1).lookYaw, -144);
  assert.equal(sentInputFrames.at(-1).lookPitch, 0);
  sceneCanvas.listeners.pointermove({ pointerId: 8, pointerType: "touch", clientX: 74, clientY: 26 });
  assert.equal(sentGameCommands.length, beforeMouseLook);
  assert.equal(sentInputFrames.at(-1).lookYaw, -6);
  assert.equal(sentInputFrames.at(-1).lookPitch, 150);
  sceneCanvas.listeners.pointerup({ pointerId: 8 });
  mouseSensitivity.value = "100";
  mouseSensitivity.listeners.input();
  assert.equal(savedSettings.at(-1).value.mouseCameraSensitivityPercent, 100);
  sceneCanvas.listeners.pointerdown({
    pointerId: 9, pointerType: "touch", clientX: 50, clientY: 50, preventDefault() {},
  });
  sceneCanvas.listeners.pointermove({ pointerId: 9, pointerType: "touch", clientX: 62, clientY: 62 });
  assert.equal(sentInputFrames.at(-1).lookYaw, -150);
  sceneCanvas.listeners.pointerup({ pointerId: 9 });
  assert.equal(savedSettings.at(-1).key, "kookie.browser.settings.v1");
  const beforeLockedLook = sentInputFrames.length;
  document.pointerLockElement = sceneCanvas;
  sceneCanvas.listeners.pointermove({ movementX: 12 });
  assert.equal(sentInputFrames.at(-1).lookYaw, -150);
  assert.equal(sentInputFrames.at(-1).lookPitch, 0);
  assert.equal(sentInputFrames.length, beforeLockedLook + 1);
  document.pointerLockElement = null;
  const authoritative = renderedScenes.find((scene) => scene.sceneObjects?.length === 10);
  assert.equal(authoritative.sceneObjects[0].kind, 1);
  assert.equal(authoritative.sceneObjects[0].id, 2);
  assert.equal(authoritative.sceneObjects[0].state, 0);
  assert.equal(authoritative.sceneObjects[0].x, 5);
  assert.equal(authoritative.sceneObjects[0].y, 5);
  assert.equal(authoritative.sceneObjects[0].z, 5);
  assert.equal(authoritative.sceneObjects[0].sizeX, 3);
  assert.equal(authoritative.sceneObjects[0].sizeY, 5);
  assert.equal(authoritative.sceneObjects[0].sizeZ, 1);
  assert.equal(authoritative.sceneObjects.filter((object) => object.kind === 3).length, 6);
  assert.equal(authoritative.sceneObjects.filter((object) => object.kind === 4).length, 1);
  assert.equal(authoritative.labels.length, 4);
  assert.equal(authoritative.labels[1].textId, 2);
  assert.equal(authoritative.labels[1].visible, true);
  assert.equal(document.getElementById("kookie-scene-labels"), null,
    "world actors do not get text nameplates");
  const bugfeedButton = pageElements.find((element) =>
    element.attributes["aria-label"] === "Report a bug with screenshot and diagnostics");
  assert.ok(bugfeedButton);
  bugfeedButton.listeners.click();
  const bugfeedDialog = pageElements.find((element) => element.tagName === "DIALOG");
  assert.equal(bugfeedDialog.open, true);
  const notes = pageElements.find((element) => element.attributes["aria-label"] === "Bug report notes");
  notes.value = "The goose camera clips through the model";
  const saveBugfeed = pageElements.find((element) => element.textContent === "Save report");
  await saveBugfeed.listeners.click();
  assert.equal(saveBugfeed.dataset.asyncState, "success");
  assert.equal(saveBugfeed.attributes["aria-busy"], "false");
  assert.match(bugfeedDialog.children.find((element) =>
    element.attributes["aria-live"] === "polite").textContent, new RegExp(bugfeedId));
  const reportView = new DataView(bugfeedEnvelope.buffer, bugfeedEnvelope.byteOffset, bugfeedEnvelope.byteLength);
  assert.equal(new TextDecoder().decode(bugfeedEnvelope.subarray(0, 4)), "KBF1");
  const metadataLength = reportView.getUint32(5);
  const screenshotLength = reportView.getUint32(9);
  assert.ok(screenshotLength > 0);
  const report = JSON.parse(new TextDecoder().decode(
    bugfeedEnvelope.subarray(13, 13 + metadataLength)));
  assert.equal(report.notes, notes.value);
  assert.equal(report.screenshotAvailable, true);
  assert.equal(report.page, "https://game.internal/index.html");
  assert.equal(report.page.includes("secret"), false);
  assert.deepEqual(Array.from(bugfeedEnvelope.subarray(13 + metadataLength, 21 + metadataLength)),
    [137, 80, 78, 71, 13, 10, 26, 10]);
  bugfeedButton.listeners.click();
  assert.equal(saveBugfeed.disabled, false);
  notes.value = "A second report works after the first submission";
  await saveBugfeed.listeners.click();
  assert.equal(bugfeedUploadCount, 2);
  console.log(`KOOKIE browser contract smoke passed: dom=${document.body.children.length} objects=${authoritative.sceneObjects.length} labels=${authoritative.labels.length} frameBytes=${window.kookieSessionTransport.maxFrameBytes}`);
  const customizeTouch = pageElements.find((element) =>
    element.textContent === "Customize touch controls");
  assert.ok(customizeTouch);
  customizeTouch.listeners.click();
  const panel = document.getElementById("kookie-session-panel");
  assert.equal(panel.dataset.layoutEditing, "true");
  const controlsEditor = pageElements.find((element) =>
    element.attributes["aria-label"] === "Touch control layout editor");
  assert.ok(controlsEditor);
  const presetName = pageElements.find((element) =>
    element.attributes["aria-label"] === "Touch layout preset name");
  presetName.value = "Portrait";
  const horizontalPosition = pageElements.find((element) =>
    element.attributes["aria-label"] === "Selected control horizontal position");
  horizontalPosition.value = "22";
  horizontalPosition.listeners.input();
  const saveTouchPreset = pageElements.find((element) =>
    element.textContent === "Save preset");
  saveTouchPreset.listeners.click();
  const storedLayout = savedSettings.findLast((entry) =>
    entry.key === "kookie.browser.touch-layouts.v1");
  assert.equal(storedLayout.value.activeName, "Portrait");
  assert.equal(storedLayout.value.activeLayout.move.x, 22);
  horizontalPosition.value = "38";
  horizontalPosition.listeners.input();
  const presetPicker = pageElements.find((element) =>
    element.attributes["aria-label"] === "Saved touch layout presets");
  presetPicker.value = "Portrait";
  pageElements.find((element) => element.textContent === "Load preset").listeners.click();
  assert.equal(pageElements.find((element) =>
    element.attributes["data-analog-stick"] === "move").style.left, "22vw");
  pageElements.find((element) => element.textContent === "Done").listeners.click();
  assert.equal(panel.dataset.layoutEditing, "false");
  const touchToggle = pageElements.find((element) =>
    element.className === "kookie-touch-layout-toggle");
  assert.ok(touchToggle);
  assert.equal(touchToggle.textContent, "TOUCH OFF");
  touchToggle.listeners.click();
  assert.equal(touchToggle.attributes["aria-pressed"], "true");
  assert.equal(panel.dataset.layoutEditing, "true");
  const moveStick = pageElements.find((element) =>
    element.attributes["data-analog-stick"] === "move");
  moveStick.listeners.pointerdown({
    pointerId: 33, clientX: 100, clientY: 200,
    preventDefault() {}, stopPropagation() {},
  });
  moveStick.listeners.pointermove({
    pointerId: 33, clientX: 180, clientY: 200,
  });
  moveStick.listeners.pointerup({ pointerId: 33 });
  assert.equal(moveStick.style.left, "32vw");
  touchToggle.listeners.click();
  assert.equal(touchToggle.attributes["aria-pressed"], "false");
  assert.equal(panel.dataset.layoutEditing, "false");
  const persistedTouchLayout = savedSettings.findLast((entry) =>
    entry.key === "kookie.browser.touch-layouts.v1");
  assert.equal(persistedTouchLayout.value.activeLayout.move.x, 32,
    "turning layout editing off persists the dragged coordinates as JSON");
  monotonicNow = 1001;
  FakeWebSocket.active.emit(encodeFrame(
    6, 5, extendedMultiplayerWords(5, 15)));
  await new Promise((resolve) => setImmediate(resolve));
  assert.ok(document.getElementById("kookie-authoritative-scene")
    .attributes["aria-label"].includes("tick 15"),
  document.getElementById("kookie-session-status").textContent);
  if (frameCallbacks.length > 0) frameCallbacks.shift()(1001);
  assert.equal(document.getElementById("kookie-scene-labels"), null,
    "multiplayer players never get text or UID nameplates");
  for (const [stat, expected] of [
    ["health", "100 / 100"], ["stamina", "100 / 100"],
    ["ammo", "30"], ["combo", "--"],
  ]) {
    const value = pageElements.find((element) =>
      element.attributes["data-stat"] === stat)?.children[1]?.textContent;
    assert.equal(value, expected, "multiplayer snapshot updates " + stat + " HUD");
  }
  const healthStat = pageElements.find((element) =>
    element.attributes["data-stat"] === "health");
  assert.equal(healthStat.dataset.team, "red",
    "red players retain the original heart palette");
  const blueTeamSnapshot = extendedMultiplayerWords(16, 16);
  blueTeamSnapshot[24] = 2;
  blueTeamSnapshot[blueTeamSnapshot.length - 1] =
    messageChecksum(blueTeamSnapshot.slice(0, -1));
  FakeWebSocket.active.emit(encodeFrame(6, 16, blueTeamSnapshot));
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(healthStat.dataset.team, "blue",
    "blue player health HUD selects blue hearts from the actor kind");
  if (frameCallbacks.length > 0) frameCallbacks.shift()(1001);
  const replicatedCombatScene = renderedScenes.find((scene) =>
    scene.tick === 15 && scene.projectiles?.length === 1);
  assert.ok(replicatedCombatScene);
  assert.equal(replicatedCombatScene.throwables.length, 1);
  assert.equal(replicatedCombatScene.throwables[0].fuseTicks, 36);
  assert.equal(replicatedCombatScene.impacts.length, 1);
  assert.equal(replicatedCombatScene.impacts[0].damage, 20);
  assert.equal(replicatedCombatScene.playerCount, 2);
  assert.equal(replicatedCombatScene.spectatorCount, 0);
  moveStickBase.listeners.pointerdown({
    pointerId: 22, clientX: 88, clientY: 50, preventDefault() {},
  });
  const unacknowledgedInput = sentInputFrames.at(-1);
  assert.ok(unacknowledgedInput.moveX > 0);
  monotonicNow = 1018;
  FakeWebSocket.active.emit(encodeFrame(
    6, 17, multiplayerPositionWords(17, 17, 33)));
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(healthStat.dataset.team, "red",
    "red player heart palette is restored on the next snapshot");
  monotonicNow = 1035;
  if (frameCallbacks.length > 0) frameCallbacks.shift()(1035);
  assert.ok(document.getElementById("kookie-authoritative-scene")
    .attributes["aria-label"].includes("tick 17"),
    "tick 17 snapshot rejected: " + document.getElementById("kookie-session-status").textContent);
  assert.ok(renderedScenes.at(-1).playerX >= 32 &&
    renderedScenes.at(-1).playerX < 35,
  "local render remains near authoritative x=33 during reconciliation, got " +
    renderedScenes.at(-1).playerX);
  moveStickBase.listeners.pointerup({ pointerId: 22 });
  const turnedSnapshot = extendedMultiplayerWords(18, 18);
  turnedSnapshot[8] = 90;
  turnedSnapshot[turnedSnapshot.length - 1] =
    messageChecksum(turnedSnapshot.slice(0, -1));
  FakeWebSocket.active.emit(encodeFrame(6, 18, turnedSnapshot));
  await new Promise((resolve) => setImmediate(resolve));
  const keydown = document.listeners.keydown;
  keydown({ code: "KeyW", key: "w", target: null, preventDefault() {} });
  const forwardInput = sentInputFrames.at(-1);
  assert.ok(forwardInput.moveX >= 0 && forwardInput.moveX < 700 &&
    forwardInput.moveZ > 700 &&
    Math.hypot(forwardInput.moveX, forwardInput.moveZ) >= 990,
  `W follows the eased turn with normalized movement; got ${forwardInput.moveX},${forwardInput.moveZ}`);
  document.listeners.keyup({
    code: "KeyW", key: "w", target: null, preventDefault() {},
  });
  window.kookieSessionTransport.disconnect();
  assert.equal(document.getElementById("kookie-authoritative-scene")
    .attributes["aria-label"].includes("0 actors"), true);
  assert.equal(document.getElementById("kookie-scene-labels"), null);
  const roleSelect = collectElements(document.body).find((element) =>
    element.attributes["aria-label"] ===
      "Choose red team, blue team, or spectator");
  roleSelect.value = "spectator";
  window.kookieSessionTransport.connect();
  await waitFor(() => FakeWebSocket.connections.at(-1).joined === true);
  if (frameCallbacks.length > 0) frameCallbacks.shift()(1035);
  assert.ok(renderedScenes.at(-1).camera.y >= 120 &&
    renderedScenes.at(-1).camera.pitch <= -60,
  "spectator should start above arena geometry with an unobstructed overview camera");
  const consoleButton = collectElements(document.body).find((element) =>
    element.attributes["aria-label"] === "Open game console");
  consoleButton.listeners.click();
  const consoleDialog = collectElements(document.body).find((element) =>
    element.attributes["aria-labelledby"] === "kookie-console-heading");
  assert.equal(consoleDialog.open, true);
  const consoleInput = collectElements(consoleDialog).find((element) =>
    element.attributes["aria-label"] === "Game console command");
  const consoleForm = collectElements(consoleDialog).find((element) =>
    element.tagName === "FORM");
  consoleInput.value = "/b2teams4";
  consoleForm.listeners.submit({ preventDefault() {} });
  await waitFor(() => consoleDialog.children.some((element) =>
    element.tagName === "PRE" &&
    (element.textContent.includes("Battle live") ||
      element.textContent.includes("Battle setup failed") ||
      element.textContent.includes("Command failed"))));
  assert.match(consoleDialog.children.find((element) =>
    element.tagName === "PRE").textContent, /Battle live/);
  assert.equal(FakeWebSocket.connections.filter((connection) =>
    new URL(connection.url).pathname === "/session/goose").length, 4);
  assert.equal(FakeWebSocket.connections.filter((connection) =>
    new URL(connection.url).pathname === "/session/cat").length, 4);
  consoleInput.value = "/stop";
  consoleForm.listeners.submit({ preventDefault() {} });
  await waitFor(() => consoleDialog.children.some((element) =>
    element.tagName === "PRE" && element.textContent.includes("Battle stopped by console command.")));
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
