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
    this.className = "";
    this.classList = { toggle: () => {} };
    this.textContent = "";
    this.value = "";
    this.checked = false;
    this.disabled = false;
    this.selected = false;
    this.id = "";
    this.width = 0;
    this.height = 0;
  }

  appendChild(child) {
    child.parentNode = this;
    this.children.push(child);
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
    return { width: this.width || 960, height: this.height || 480 };
  }

  getContext(type) {
    if (type !== "2d") return null;
    return {
      clearRect() {}, fillRect() {}, strokeRect() {}, beginPath() {},
      arc() {}, fill() {},
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
  createTextNode(text) {
    const node = new FakeElement("#text");
    node.textContent = String(text);
    return node;
  }
  addEventListener(name, handler) { this.listeners[name] = handler; }

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
let fullSceneSent = false;

class FakeWebSocket {
  static CONNECTING = 0;
  static OPEN = 1;
  static CLOSING = 2;
  static CLOSED = 3;

  constructor(url, protocols) {
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
    if (kind === 6 && view.getInt32(16 + 3 * 4, false) === 1 &&
        view.getInt32(16 + 4 * 4, false) === 7) {
      fullSceneSent = true;
      this.emit(encodeFrame(6, sequence, fullSceneWords(sequence)));
    }
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
  const frameCallbacks = [];
  const renderer = {
    supported: true,
    reason: "contract renderer",
    render(scene) { renderedScenes.push(scene); },
    getStatus() { return "contract renderer"; },
    projectWorld() { return { x: 0.5, y: 0.25, depth: 0.5 }; },
    captureScreenshot() {
      return { format: "P6", width: 1, height: 1, nonBlackPixels: 1, checksum: 1 };
    },
    destroy() {},
  };
  const window = {
    document,
    location: { href: "http://127.0.0.1:4178/index.html", search: "" },
    localStorage: { getItem: () => null, setItem: () => {} },
    matchMedia: () => ({ matches: false }),
    KookieWebRenderer: { create: () => renderer },
    requestAnimationFrame: (callback) => { frameCallbacks.push(callback); return frameCallbacks.length; },
    cancelAnimationFrame: () => {},
    setTimeout,
    clearTimeout,
    addEventListener: () => {},
  };
  const context = {
    window, document, WebSocket: FakeWebSocket, URL, URLSearchParams,
    ArrayBuffer, DataView, Uint8Array, TextEncoder, TextDecoder, Math, Number,
    Object, JSON, Promise, Error, TypeError, console, performance: { now: () => 0 },
    queueMicrotask, setTimeout, clearTimeout, setImmediate, btoa: () => "",
  };
  vm.runInNewContext(rendererSource, context, { filename: rendererPath });
  assert.equal(typeof window.KookieWebRenderer?.create, "function");
  assert.equal(typeof window.KookieWebRenderer?.encodeScreenshot, "function");
  assert.deepEqual(Array.from(window.KookieArenaGeometry.water[0].bounds), [96, 5, 96, 224, 208]);
  window.KookieWebRenderer = { create: () => renderer };
  vm.runInNewContext(transportSource, context, { filename: transportPath });
  assert.equal(typeof window.kookieSessionTransport.connect, "function");
  assert.equal(window.kookieSessionTransport.maxFrameBytes, 1104);
  assert.ok(document.getElementById("kookie-session-panel"));
  assert.ok(document.getElementById("kookie-authoritative-scene"));

  window.kookieSessionTransport.connect();
  await waitFor(() => fullSceneSent);
  if (frameCallbacks.length > 0) frameCallbacks.shift()(0);
  await waitFor(() => renderedScenes.some((scene) => scene.sceneObjects?.length === 10));

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
  assert.equal(document.getElementById("kookie-scene-labels").children.length, 4);
  assert.equal(document.getElementById("kookie-session-status").textContent,
    "AUTHORITATIVE 3D SCENE RECEIVED sequence=2");
  console.log(`KOOKIE browser contract smoke passed: dom=${document.body.children.length} objects=${authoritative.sceneObjects.length} labels=${authoritative.labels.length} frameBytes=${window.kookieSessionTransport.maxFrameBytes}`);
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
