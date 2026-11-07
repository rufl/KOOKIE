(() => {
  "use strict";

  const FRAME_VERSION = 1;
  const PROTOCOL_VERSION = 2;
  const KIND_HELLO = 1;
  const KIND_ACK = 2;
  const KIND_PING = 3;
  const KIND_PONG = 4;
  const KIND_GAME = 6;
  const KUTTER_REQUEST = 1987145331;
  const KUTTER_RESPONSE = 1987145332;
  const COMMAND = Object.freeze({
    get: 1, tool: 2, cursor: 3, apply: 4, select: 5, move: 6,
    rotate: 7, resize: 8, recolor: 9, duplicate: 10, remove: 11,
    group: 12, ungroup: 13, undo: 14, redo: 15, import: 16,
    grid: 17, update: 18, height: 19, preview: 20,
    behaviorCards: 21, installBehavior: 22,
  });
  const MAX_DOCUMENT_WORDS = 1779;
  const TRANSFER_WORDS = 256;
  const NODE_GROUP = 9;
  const NODE_LABELS = {
    1: "Select", 2: "Prop", 3: "Player spawn", 4: "Enemy spawn",
    5: "Encounter", 6: "Goal trigger", 7: "Light", 8: "Erase",
    9: "Group",
  };
  const MAX_SAVED_PROJECTS = 32;
  const MAX_PROJECT_LIBRARY_BYTES = 4 * 1024 * 1024;
  const PROJECT_STORAGE_KEY = "kookie.kutter.projects.v1";
  const PROJECT_LIBRARY_SCHEMA = "kookie.kutter-project-library/v1";
  const PANEL_LAYOUT_KEY = "kookie.kutter.panels.v1";
  const byId = (id) => document.getElementById(id);
  const canvas = byId("kutter-viewport");
  const connectionState = byId("connection-state");
  const message = byId("editor-message");
  const viewportInfo = byId("viewport-info");
  const nodeList = byId("node-list");
  const form = byId("inspector-form");
  let renderer = null;
  let previewRenderer = null;
  let ws = null;
  let requestSequence = 1;
  let documentState = null;
  let commandQueue = Promise.resolve();
  let rendererReady = false;
  let previewRendererReady = false;
  let pending = new Map();
  let incomingStates = new Map();
  let groupedSelection = new Set();
  let currentScene = null;
  let statusMessage = "Opening Kof editor session…";
  let reconnectTimer = null;
  let animationFrameHandle = 0;
  let shuttingDown = false;
  let refreshTimer = null;
  let refreshInFlight = false;
  let assetCatalog = [];
  let assetCatalogError = "";
  let previewActive = false;
  let previewedAssetToken = 0;
  let previewGeneration = 0;

  function checksum(words, length = words.length) {
    let result = 53;
    for (let i = 0; i < length; i += 1) {
      let value = words[i] % 1000003;
      if (value < 0) value += 1000003;
      result = (result * 31 + value) % 1000003;
    }
    return result;
  }

  function checksumWire(bytes) {
    let result = 0;
    for (let i = 0; i < bytes.length; i += 1) {
      const value = i === 14 || i === 15 ? 0 : bytes[i];
      result = (result + value * (i + 1)) % 65536;
    }
    return result;
  }

  function encodeFrame(kind, sequence, words) {
    const bytes = new Uint8Array(16 + words.length * 4);
    bytes.set([0x4b, 0x57, 0x53, 0x31, FRAME_VERSION, kind, 0, 0]);
    const view = new DataView(bytes.buffer);
    view.setUint32(8, sequence, false);
    view.setUint16(12, words.length, false);
    words.forEach((value, index) => view.setInt32(16 + index * 4, value, false));
    view.setUint16(14, checksumWire(bytes), false);
    return bytes.buffer;
  }

  function decodeFrame(buffer) {
    if (!(buffer instanceof ArrayBuffer) || buffer.byteLength < 16 ||
        buffer.byteLength > 16 + 320 * 4) throw new Error("Invalid Kof frame size");
    const bytes = new Uint8Array(buffer);
    const view = new DataView(buffer);
    if (bytes[0] !== 0x4b || bytes[1] !== 0x57 || bytes[2] !== 0x53 ||
        bytes[3] !== 0x31 || bytes[4] !== FRAME_VERSION || bytes[6] || bytes[7]) {
      throw new Error("Invalid Kof frame header");
    }
    const sequence = view.getUint32(8, false);
    const count = view.getUint16(12, false);
    if (!sequence || count < 1 || count > 320 || buffer.byteLength !== 16 + count * 4 ||
        checksumWire(bytes) !== view.getUint16(14, false)) {
      throw new Error("Invalid Kof frame checksum");
    }
    const words = new Int32Array(count);
    for (let i = 0; i < count; i += 1) words[i] = view.getInt32(16 + i * 4, false);
    if (words[0] !== PROTOCOL_VERSION || words[1] !== bytes[5] || words[2] !== sequence ||
        words[count - 1] !== checksum(words, count - 1)) {
      throw new Error("Invalid Kof message checksum");
    }
    return { kind: bytes[5], sequence, words };
  }

  function sendHello() {
    const seq = requestSequence;
    const words = [PROTOCOL_VERSION, KIND_HELLO, seq, 1, 1, 1, 1];
    words.push(checksum(words));
    ws.send(encodeFrame(KIND_HELLO, seq, words));
  }

  let heartbeatTimer = null;
  function sendHeartbeat() {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    const sequence = ++requestSequence;
    const words = [PROTOCOL_VERSION, KIND_PING, sequence];
    words.push(checksum(words));
    ws.send(encodeFrame(KIND_PING, sequence, words));
  }

  function receiveState(frame) {
    const words = frame.words;
    if (words.length < 16 || words[3] !== KUTTER_RESPONSE) {
      throw new Error("Invalid Kutter response");
    }
    const [,, , , command, status, generation, selected, tool, cursorX, cursorZ,
      grid, validation, offset, total] = words;
    if (status !== 0) {
      const error = new Error("Kof rejected Kutter operation (diagnostic " + status + ")");
      settle(frame.sequence, error);
      statusMessage = error.message;
      drawUi();
      return;
    }
    if (total === 0) {
      settle(frame.sequence, null, { command, uploadPending: true });
      return;
    }
    if (total < 11 || total > MAX_DOCUMENT_WORDS || offset < 0 || offset >= total) {
      throw new Error("Kof returned an out-of-bounds Kutter document");
    }
    let transfer = incomingStates.get(frame.sequence);
    if (!transfer || transfer.total !== total) {
      transfer = { total, data: new Int32Array(total), received: 0, metadata: null };
      incomingStates.set(frame.sequence, transfer);
    }
    const data = words.subarray(15, words.length - 1);
    if (offset + data.length > total) throw new Error("Kof Kutter chunk overflow");
    transfer.data.set(data, offset);
    transfer.received += data.length;
    transfer.metadata = { command, generation, selected, tool, cursorX, cursorZ, grid, validation,
      canUndo: (validation & 16) !== 0, canRedo: (validation & 32) !== 0 };
    if (transfer.received < total) return;
    incomingStates.delete(frame.sequence);
    const parsed = decodeDocument(transfer.data);
    previewActive = (validation & 8) !== 0;
    documentState = { ...transfer.metadata, ...parsed };
    statusMessage = "Connected · Kof Kutter document accepted";
    updateDocumentMeta();
    drawUi();
    settle(frame.sequence, null, documentState);
  }

  function settle(sequence, error, value) {
    const waiter = pending.get(sequence);
    if (!waiter) return;
    pending.delete(sequence);
    clearTimeout(waiter.timer);
    if (error) waiter.reject(error);
    else waiter.resolve(value);
  }
  function rejectPendingRequests(error) {
    for (const [sequence, waiter] of pending) {
      clearTimeout(waiter.timer);
      waiter.reject(error);
      pending.delete(sequence);
    }
    incomingStates.clear();
  }


  function decodeSigned(value) {
    return value % 2 === 0 ? value / 2 : -Math.floor(value / 2) - 1;
  }

  function decodeDocument(words) {
    const version = words[1];
    const nodeCount = words[7];
    const assetCount = words[8];
    const behaviorWordCount = version === 4 ? words[10] : 0;
    if (words[0] !== 126375140 || ![1, 2, 3, 4].includes(version) ||
        nodeCount < 1 || nodeCount > 64 || assetCount < 0 || assetCount > 32 ||
        (version < 4 && words[10] !== 0) ||
        behaviorWordCount < 0 || behaviorWordCount > 776 ||
        (behaviorWordCount > 0 && behaviorWordCount < 18) ||
        words[2] !== words.length) throw new Error("Unsupported Kutter document schema");
    const stride = version === 1 ? 8 : version === 2 ? 12 : 13;
    if (words.length !== 11 + nodeCount * stride + assetCount * 5 +
        behaviorWordCount) {
      throw new Error("Kutter document length does not match schema");
    }
    const nodes = [];
    let cursor = 11;
    for (let i = 0; i < nodeCount; i += 1) {
      const id = words[cursor];
      const parent = words[cursor + 1];
      const kind = words[cursor + 2];
      const x = decodeSigned(words[cursor + 3]);
      const y = decodeSigned(words[cursor + 4]);
      const z = decodeSigned(words[cursor + 5]);
      const rotation = decodeSigned(words[cursor + 6]);
      const scaleX = words[cursor + 7];
      const scaleY = version >= 2 ? words[cursor + 8] : scaleX;
      const scaleZ = version >= 2 ? words[cursor + 9] : scaleX;
      const color = version >= 2 ? words[cursor + 10] : 0xffffff;
      const asset = version >= 3 ? words[cursor + 12] : 0;
      nodes.push({ id, parent, kind, x, y, z, rotation, scaleX, scaleY, scaleZ, color, asset });
      cursor += stride;
    }
    const assets = [];
    for (let i = 0; i < assetCount; i += 1) {
      assets.push({ id: words[cursor], kind: words[cursor + 1], status: words[cursor + 2],
        checksum: words[cursor + 3], revision: words[cursor + 4] });
      cursor += 5;
    }
    const behaviorCards = { attack: 1, chase: 2, fallback: 3,
      hasProgram: behaviorWordCount > 0 };
    if (behaviorWordCount > 0) {
      const program = words.subarray(cursor);
      const programNodeCount = program[5];
      const edgeCount = program[6];
      const ruleCount = program[7];
      if (program[0] !== 1111839304 || program[1] !== 1 ||
          programNodeCount <= 0 || programNodeCount > 64 ||
          edgeCount <= 0 || edgeCount > 128 || ruleCount <= 0 ||
          ruleCount > 64 || program[9] !== program.length ||
          program.length !== 10 + programNodeCount * 2 + edgeCount * 3 +
            ruleCount * 3) {
        throw new Error("Kutter behavior program shape is invalid");
      }
      let ruleOffset = 10 + programNodeCount * 2 + edgeCount * 3;
      behaviorCards.attack = 0;
      behaviorCards.chase = 0;
      for (let index = 0; index < ruleCount; index += 1, ruleOffset += 3) {
        if (program[ruleOffset + 2] === 6) behaviorCards.attack = 1;
        else if (program[ruleOffset + 2] === 7) behaviorCards.chase = 2;
        else if (program[ruleOffset + 2] !== 8 && program[ruleOffset + 2] !== 9) {
          throw new Error("Kutter behavior card action is unsupported");
        }
      }
    }
    return { words, version, projectNamespace: words[4], projectId: words[5],
      projectRevision: words[6], generation: words[9], nodes, assets,
      checksum: words[3], behaviorWordCount, behaviorCards };
  }
  function calculateDocumentChecksum(words, document) {
    const mix = (state, value) => {
      let normalized = value % 1000003;
      if (normalized < 0) normalized += 1000003;
      return (state * 31 + normalized) % 1000003;
    };
    const version = document.version;
    let result = mix(137, version);
    result = mix(result, words[4]);
    result = mix(result, words[5]);
    result = mix(result, words[6]);
    result = mix(result, words[9]);
    result = mix(result, document.nodes.length);
    let cursor = 11;
    const stride = version === 1 ? 8 : version === 2 ? 12 : 13;
    for (const node of document.nodes) {
      if (version >= 2 && words[cursor + 11] !== 0) return -1;
      result = mix(result, node.id);
      result = mix(result, node.parent);
      result = mix(result, node.kind);
      result = mix(result, node.x);
      result = mix(result, node.y);
      result = mix(result, node.z);
      result = mix(result, node.rotation);
      result = mix(result, node.scaleX);
      if (version >= 2) {
        result = mix(result, node.scaleY);
        result = mix(result, node.scaleZ);
        result = mix(result, node.color);
      }
      if (version >= 3) result = mix(result, node.asset);
      cursor += stride;
    }
    result = mix(result, document.assets.length);
    for (const asset of document.assets) {
      result = mix(result, asset.id);
      result = mix(result, asset.kind);
      result = mix(result, asset.status);
      result = mix(result, asset.checksum);
      result = mix(result, asset.revision);
    }
    if (version === 4) {
      result = mix(result, document.behaviorWordCount);
      const behaviorStart = 11 + document.nodes.length * stride +
        document.assets.length * 5;
      for (let index = 0; index < document.behaviorWordCount; index += 1) {
        result = mix(result, words[behaviorStart + index]);
      }
    }
    return result > 0 ? result : 1;
  }

  function validateDocumentChecksum(words, document) {
    return calculateDocumentChecksum(words, document) === words[3];
  }

  function request(command, args = []) {
    const activeSocket = ws;
    if (shuttingDown || !activeSocket ||
        activeSocket.readyState !== WebSocket.OPEN) {
      return Promise.reject(new Error("Kof editor is disconnected"));
    }
    const sequence = ++requestSequence;
    const words = [PROTOCOL_VERSION, KIND_GAME, sequence, KUTTER_REQUEST, command, ...args];
    words.push(checksum(words));
    if (words.length > 320) return Promise.reject(new Error("Kutter request exceeds Kof frame bound"));
    const promise = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(sequence);
        reject(new Error("Kof Kutter request timed out"));
      }, 10000);
      pending.set(sequence, { resolve, reject, timer });
    });
    try {
      activeSocket.send(encodeFrame(KIND_GAME, sequence, words));
    } catch (error) {
      settle(sequence, error);
    }
    return promise;
  }

  function operate(command, args = []) {
    const task = commandQueue.then(async () => {
      const result = await request(command, args);
      if (result?.uploadPending) return result;
      return result;
    });
    commandQueue = task.catch(() => {});
    return task.catch((error) => {
      statusMessage = error.message;
      drawUi();
      throw error;
    });
  }

  function currentNode() {
    return documentState?.nodes.find((node) => node.id === documentState.selected) || null;
  }

  function renderHierarchy() {
    if (!documentState) return;
    nodeList.replaceChildren();
    for (const node of documentState.nodes) {
      const row = document.createElement("button");
      row.type = "button";
      row.className = "node-row";
      row.setAttribute("role", "option");
      row.setAttribute("aria-selected", String(node.id === documentState.selected));
      row.setAttribute("aria-current", String(node.id === documentState.selected));
      row.dataset.multi = String(groupedSelection.has(node.id));
      row.textContent = "#" + node.id + " · " + (NODE_LABELS[node.kind] || "Node") +
        (node.parent > 0 ? " ↳" + node.parent : "");
      row.addEventListener("click", async (event) => {
        if (event.ctrlKey || event.metaKey || event.shiftKey) {
          if (groupedSelection.has(node.id)) groupedSelection.delete(node.id);
          else groupedSelection.add(node.id);
          if (groupedSelection.size === 0) groupedSelection.add(documentState.selected);
          drawUi();
          return;
        }
        groupedSelection.clear();
        try { await operate(COMMAND.select, [node.id]); } catch (error) {}
      });
      nodeList.appendChild(row);
    }
    byId("node-count").textContent = String(documentState.nodes.length);
  }

  function setField(id, value) { byId(id).value = String(value); }
  function renderAssetPreview(asset) {
    const usable = asset?.runtime_ready === true && previewRendererReady &&
      typeof previewRenderer?.render === "function";
    byId("asset-preview").hidden = !usable;
    byId("asset-card-mark").hidden = usable;
    byId("asset-preview").setAttribute(
      "aria-label", asset ? asset.name + " 3D preview" : "3D model preview",
    );
    if (!usable) {
      if (previewedAssetToken && previewRendererReady &&
          typeof previewRenderer?.render === "function") {
        previewRenderer.render({
          kutterEditor: true,
          kutterAssetCatalog: assetCatalog,
          kutterGeneration: ++previewGeneration,
          kutterNodes: [],
          kutterSelected: 0,
          camera: { x: 0, y: 5, z: -9, yaw: 0, pitch: -20 },
          actors: [], sceneObjects: [], projectiles: [], labels: [],
        }, performance.now());
      }
      previewedAssetToken = 0;
      return;
    }
    if (previewedAssetToken === asset.asset_token) return;
    previewedAssetToken = asset.asset_token;
    const nodes = [{
      id: 1, parent: 0, kind: NODE_PROP, x: 0, y: 0, z: 0,
      rotation: 0, scaleX: 1000, scaleY: 1000, scaleZ: 1000,
      color: 0xffffff, asset: asset.asset_token,
    }];
    const scene = {
      kutterEditor: true,
      kutterAssetCatalog: assetCatalog,
      kutterGeneration: ++previewGeneration,
      kutterNodes: nodes,
      kutterSelected: 0,
      camera: { x: 0, y: 5, z: -9, yaw: 0, pitch: -20 },
      tick: 0,
      playerX: 0, playerY: 0, playerZ: 0, yaw: 0, pitch: -20,
      actors: [], sceneObjects: [], projectiles: [], labels: [],
    };
    previewRenderer.render(scene, performance.now());
    const preload = previewRenderer.prepareKutterPreview;
    if (typeof preload === "function") {
      preload.call(previewRenderer, scene).then(() => {
        if (!shuttingDown && previewedAssetToken === asset.asset_token) {
          previewRenderer.render(scene, performance.now());
        }
      });
    }
  }

  function renderAssetCatalog(node, preferNodeAsset = true) {
    const select = byId("asset-catalog");
    const previousToken = Number(select.value);
    const query = byId("asset-search").value.trim().toLocaleLowerCase();
    const kind = byId("asset-kind-filter").value;
    const matches = assetCatalog.filter((asset) =>
      (kind === "all" || (kind === "runtime" ? asset.runtime_ready :
        asset.collision === kind)) &&
      [asset.name, asset.asset_id, asset.source_path, asset.runtime_path,
        asset.kind, asset.collision]
        .some((value) => String(value || "").toLocaleLowerCase().includes(query)));
    select.replaceChildren();
    if (matches.length === 0) {
      const option = document.createElement("option");
      option.value = "";
      option.textContent = assetCatalogError ? "Library unavailable" :
        assetCatalogLoaded ? "No matching models" : "Loading internal library…";
      select.appendChild(option);
    } else {
      for (const asset of matches) {
        const option = document.createElement("option");
        option.value = String(asset.asset_token);
        option.textContent = asset.name + " · " + asset.kind;
        select.appendChild(option);
      }
    }
    let token = preferNodeAsset && node?.asset > 0 ? node.asset : previousToken;
    if (!matches.some((asset) => asset.asset_token === token)) {
      token = matches[0]?.asset_token || 0;
    }
    if (token) select.value = String(token);
    const selected = assetCatalog.find((asset) => asset.asset_token === token);
    const available = assetCatalogLoaded && matches.length > 0;
    select.disabled = !available;
    byId("asset-add-status").textContent = assetCatalogError ||
      (available ? matches.length + " of " + assetCatalog.length +
        " internal models · licensed metadata from the local catalog." :
        assetCatalogLoaded ? "No internal models match these filters." :
          "Loading the bundled internal model library…");
    byId("asset-card").hidden = !selected;
    if (selected) {
      byId("asset-card-name").textContent = selected.name;
      byId("asset-card-mark").textContent = selected.kind.toUpperCase();
      byId("asset-card-meta").textContent =
        selected.collision + " · " + selected.source_path + " · " +
        (selected.license || "license not listed") +
        (selected.runtime_ready ? " · runtime ready" : " · not runtime ready");
    }
    renderAssetPreview(selected);
    const hasSelection = Boolean(selected);
    byId("assign-asset").disabled = !node || node.kind !== 2 || !hasSelection;
    byId("add-asset").disabled = !documentState || !hasSelection;
  }

  let assetCatalogLoaded = false;
  async function loadAssetCatalog() {
    try {
      const response = await fetch("/assets/prototype/greybox_modules.json");
      if (!response.ok) throw new Error("HTTP " + response.status);
      const entries = await response.json();
      if (entries?.schema !== "kookie.greybox-module-catalog/v1" ||
          !Array.isArray(entries.modules)) {
        throw new Error("Unexpected catalog format");
      }
      assetCatalog = entries.modules.map((entry) => {
        const token = Number(entry?.asset_token);
        if (!Number.isInteger(token) || token <= 0 ||
            entry.module_id === undefined || entry.name === undefined || entry.kind === undefined) {
          throw new Error("Invalid catalog entry");
        }
        return { ...entry, asset_token: token };
      });
      assetCatalogError = "";
      assetCatalogLoaded = true;
    } catch (error) {
      assetCatalog = [];
      assetCatalogError = "Internal model library unavailable: " + error.message;
      assetCatalogLoaded = false;
    }
    renderAssetCatalog(currentNode());
  }


  function renderInspector() {
    const node = currentNode();
    const ids = ["node-x", "node-y", "node-z", "node-rotation", "node-sx", "node-sy",
      "node-sz", "node-color", "asset-token", "duplicate-node", "delete-node",
      "move-node", "reset-transform", "group-nodes", "ungroup-node", "rotate-down",
      "rotate-up", "scale-down", "scale-up", "height-down", "height-up", "assign-asset", "scale-axis"];
    for (const id of ids) {
      const element = byId(id);
      if (element) element.disabled = !node;
    }
    if (!node) {
      byId("selection-name").textContent = "No node selected";
      return;
    }
    byId("selection-name").textContent = "#" + node.id + " · " + (NODE_LABELS[node.kind] || "Node");
    setField("node-x", node.x); setField("node-y", node.y); setField("node-z", node.z);
    setField("node-rotation", node.rotation);
    setField("node-sx", node.scaleX); setField("node-sy", node.scaleY); setField("node-sz", node.scaleZ);
    setField("node-color", "#" + node.color.toString(16).padStart(6, "0"));
    setField("asset-token", node.asset);
    for (const id of ["node-x", "node-y", "node-z", "node-rotation", "node-sx", "node-sy", "node-sz", "node-color", "asset-token"]) {
      byId(id).disabled = node.kind === NODE_GROUP;
    }
    byId("delete-node").disabled = false;
    const groupNode = node.kind === NODE_GROUP;
    for (const id of ["rotate-down", "rotate-up", "scale-down", "scale-up",
      "height-down", "height-up"]) {
      byId(id).disabled = groupNode;
    }
    byId("scale-axis").disabled = groupNode;
    byId("height-down").disabled = groupNode || node.y - documentState.grid < -1000000;
    byId("height-up").disabled = groupNode || node.y + documentState.grid > 1000000;
    byId("duplicate-node").disabled = node.kind === NODE_GROUP;
    byId("ungroup-node").disabled = node.kind !== NODE_GROUP;
    byId("group-nodes").disabled = groupedSelection.size < 2;
  }

  function renderValidation() {
    if (!documentState) return;
    const issues = [];
    if (documentState.validation & 1) issues.push("Add one player spawn");
    if (documentState.validation & 2) issues.push("Only one player spawn is allowed");
    if (documentState.validation & 4) issues.push("Add a goal trigger");
    byId("validation").textContent = issues.length ? "Needs work: " + issues.join(" · ") : "Level validates for playtest";
    byId("viewport-info").textContent = "GEN " + documentState.generation + " · " +
      documentState.nodes.length + " NODES · CHECKSUM " + documentState.checksum;
    byId("document-meta").textContent = "KUTTER v" + documentState.version + " · " +
      documentState.nodes.length + " nodes · " + documentState.assets.length + " assets";
  }

  function drawUi() {
    connectionState.textContent = ws?.readyState === WebSocket.OPEN ? "KOF CONNECTED" : "DISCONNECTED";
    message.textContent = statusMessage;
    byId("preview-toggle").disabled = !documentState || ws?.readyState !== WebSocket.OPEN;
    byId("preview-toggle").setAttribute("aria-pressed", String(previewActive));
    byId("preview-toggle").textContent = previewActive ? "Preview on" : "Preview off";
    byId("preview-status").textContent = previewActive
      ? "Preview mode is on." : "Preview mode is off.";
    const behaviorCards = documentState?.behaviorCards;
    const connected = ws?.readyState === WebSocket.OPEN;
    byId("behavior-attack").disabled = !documentState || !connected;
    byId("behavior-chase").disabled = !documentState || !connected;
    byId("behavior-save").disabled = !documentState || !connected;
    byId("behavior-install").disabled =
      !documentState || !connected || !behaviorCards?.hasProgram;
    if (behaviorCards) {
      byId("behavior-attack").value = String(behaviorCards.attack);
      byId("behavior-chase").value = String(behaviorCards.chase);
      byId("behavior-status").textContent = behaviorCards.hasProgram
        ? "Saved bounded enemy cards · install to activate after reconnect."
        : "Unsaved default cards · saving will update the shared enemy AI.";
    }
    if (!documentState) {
      renderAssetCatalog(null);
      return;
    }
    renderHierarchy();
    renderInspector();
    renderAssetCatalog(currentNode());
    for (const button of document.querySelectorAll("[data-tool]")) {
      button.setAttribute("aria-pressed", String(Number(button.dataset.tool) === documentState.tool));
    }
    byId("undo").disabled = !connected || !documentState.canUndo;
    byId("redo").disabled = !connected || !documentState.canRedo;
    byId("grid-size").value = String(documentState.grid);
  }

  function sceneForRenderer() {
    const nodes = documentState?.nodes || [];
    const selected = currentNode();
    const targetX = (selected?.x || 0) / 100;
    const targetY = (selected?.y || 0) / 100;
    const targetZ = (selected?.z || 0) / 100;
    return {
      kutterEditor: true,
      kutterAssetCatalog: assetCatalog,
      kutterGeneration: documentState?.generation || 0,
      kutterNodes: nodes,
      kutterSelected: documentState?.selected || 0,
      camera: { x: targetX, y: targetY + 9, z: targetZ - 15, yaw: 0, pitch: -30 },
      tick: 0,
      playerX: 0, playerY: 0, playerZ: 0, yaw: 0, pitch: -30,
      actors: [], sceneObjects: [], projectiles: [], labels: [],
    };
  }

  function frame(now) {
    if (shuttingDown) return;
    if (rendererReady) {
      currentScene = sceneForRenderer();
      renderer.render(currentScene, now);
    }
    animationFrameHandle = requestAnimationFrame(frame);
  }

  function screenWorldPoint(event) {
    const rect = canvas.getBoundingClientRect();
    const target = currentNode();
    const centerX = target?.x || 0;
    const centerZ = target?.z || 0;
    const nx = (event.clientX - rect.left) / rect.width - 0.5;
    const ny = (event.clientY - rect.top) / rect.height - 0.5;
    return {
      x: Math.round((centerX + nx * 1800) / documentState.grid) * documentState.grid,
      z: Math.round((centerZ - ny * 1800) / documentState.grid) * documentState.grid,
    };
  }

  async function updateSelectedFromForm() {
    const node = currentNode();
    if (!node) return;
    const values = ["node-x", "node-y", "node-z", "node-rotation", "node-sx", "node-sy", "node-sz", "asset-token"]
      .map((id) => Number(byId(id).value));
    if (values.some((value) => !Number.isInteger(value))) {
      statusMessage = "Kof transforms require integer document units";
      drawUi();
      return;
    }
    const color = Number.parseInt(byId("node-color").value.slice(1), 16);
    try {
      await operate(COMMAND.update, [...values.slice(0, 7), color, values[7]]);
    } catch (error) {}
  }

  function downloadDocument(source = documentState, filename = null) {
    if (!source) return;
    const bytes = new Uint8Array(source.words.length * 4);
    const view = new DataView(bytes.buffer);
    source.words.forEach((word, index) => view.setInt32(index * 4, word, true));
    const url = URL.createObjectURL(new Blob([bytes], { type: "application/octet-stream" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = filename || "level-" + source.projectId + ".kutter";
    link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 0);
    statusMessage = "Exported canonical Kutter v" + source.version + " document";
    drawUi();
  }

  async function importWords(words, label) {
    if (!(words instanceof Int32Array)) words = Int32Array.from(words);
    if (words.length < 11 || words.length > MAX_DOCUMENT_WORDS ||
        words[2] !== words.length) {
      throw new Error("Kutter project has an invalid document length");
    }
    decodeDocument(words);
    for (let offset = 0; offset < words.length; offset += TRANSFER_WORDS) {
      const chunk = Array.from(words.subarray(offset, Math.min(words.length, offset + TRANSFER_WORDS)));
      await operate(COMMAND.import, [words.length, offset, ...chunk]);
    }
    statusMessage = "Kof loaded and validated " + label;
    drawUi();
  }
  function blankArenaDocument() {
    if (!documentState || documentState.projectNamespace <= 0) {
      throw new Error("Wait for Kof to provide a world before creating a project");
    }
    let projectId = 0;
    for (let attempt = 0; attempt < 8; attempt += 1) {
      projectId = Math.floor(Math.random() * 1000000) + 1;
      if (projectId !== documentState.projectId) break;
    }
    const words = new Int32Array([
      126375140, 3, 24, 0, documentState.projectNamespace, projectId,
      1, 1, 0, 1, 0,
      1, 0, 3, 0, 0, 0, 0, 1000, 1000, 1000, 16777215, 0, 0,
    ]);
    const fields = [3, documentState.projectNamespace, projectId, 1, 1, 1,
      1, 0, 3, 0, 0, 0, 0, 1000, 1000, 1000, 16777215, 0, 0];
    let checksumValue = 137;
    for (const value of fields) {
      checksumValue = (checksumValue * 31 + (value % 1000003 + 1000003) % 1000003) % 1000003;
    }
    words[3] = checksumValue > 0 ? checksumValue : 1;
    return words;
  }


  async function importDocument(file) {
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length % 4 !== 0 || bytes.length / 4 > MAX_DOCUMENT_WORDS) {
      throw new Error("Kutter file size is invalid or exceeds the document limit");
    }
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const words = new Int32Array(bytes.length / 4);
    for (let i = 0; i < words.length; i += 1) words[i] = view.getInt32(i * 4, true);
    await importWords(words, file.name);
  }

  let savedProjects = [];
  let selectedProjectId = "";
  function readSavedProjects() {
    const raw = localStorage.getItem(PROJECT_STORAGE_KEY);
    if (!raw) return [];
    const entries = JSON.parse(raw);
    if (!Array.isArray(entries) || entries.length > MAX_SAVED_PROJECTS ||
        entries.some((entry) =>
          !entry || typeof entry.id !== "string" || !entry.id ||
          typeof entry.name !== "string" || !entry.name || entry.name.length > 64 ||
          typeof entry.updatedAt !== "string" || !Number.isFinite(Date.parse(entry.updatedAt)) ||
          !Number.isInteger(entry.nodeCount) || entry.nodeCount < 1 || entry.nodeCount > 64 ||
          !Array.isArray(entry.words) || entry.words.length < 11 ||
          entry.words.length > MAX_DOCUMENT_WORDS ||
          entry.words.some((word) => !Number.isInteger(word) ||
            word < -2147483648 || word > 2147483647)) ||
        new Set(entries.map((entry) => entry.id)).size !== entries.length) {
      throw new Error("Saved project library is invalid");
    }
    return entries;
  }
  function validateProjectLibrary(entries) {
    if (!Array.isArray(entries) || entries.length > MAX_SAVED_PROJECTS) {
      throw new Error("Project library must contain at most 32 projects");
    }
    const ids = new Set();
    const names = new Set();
    const projects = [];
    for (const entry of entries) {
      if (!entry || typeof entry.id !== "string" || !entry.id ||
          entry.id.length > 64 || typeof entry.name !== "string" ||
          entry.name !== entry.name.trim() || !entry.name ||
          entry.name.length > 64 || typeof entry.updatedAt !== "string" ||
          !Number.isFinite(Date.parse(entry.updatedAt)) ||
          !Number.isInteger(entry.nodeCount) || entry.nodeCount < 1 ||
          entry.nodeCount > 64 || !Array.isArray(entry.words) ||
          entry.words.length < 11 || entry.words.length > MAX_DOCUMENT_WORDS ||
          entry.words.some((word) => !Number.isInteger(word) ||
            word < -2147483648 || word > 2147483647)) {
        throw new Error("Project library contains an invalid project");
      }
      const nameKey = entry.name.toLocaleLowerCase();
      if (ids.has(entry.id) || names.has(nameKey)) {
        throw new Error("Project library contains duplicate IDs or names");
      }
      const words = Int32Array.from(entry.words);
      const document = decodeDocument(words);
      if (document.nodes.length !== entry.nodeCount ||
          !validateDocumentChecksum(words, document)) {
        throw new Error("Project document checksum or node count is invalid");
      }
      ids.add(entry.id);
      names.add(nameKey);
      projects.push({
        id: entry.id, name: entry.name, updatedAt: entry.updatedAt,
        nodeCount: entry.nodeCount, words: Array.from(words),
      });
    }
    return projects;
  }

  function downloadProjectLibrary() {
    const payload = JSON.stringify({
      schema: PROJECT_LIBRARY_SCHEMA, projects: savedProjects,
    }, null, 2);
    const url = URL.createObjectURL(new Blob([payload], { type: "application/json" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = "kutter-project-library.json";
    link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 0);
    byId("project-message").textContent =
      "Exported " + savedProjects.length + " browser-local projects.";
  }

  async function importProjectLibrary(file) {
    if (file.size > MAX_PROJECT_LIBRARY_BYTES) {
      throw new Error("Project library backup exceeds the 4 MiB limit");
    }
    const backup = JSON.parse(await file.text());
    if (!backup || backup.schema !== PROJECT_LIBRARY_SCHEMA) {
      throw new Error("Unsupported project library backup schema");
    }
    const imported = validateProjectLibrary(backup.projects);
    const merged = savedProjects.slice();
    let added = 0;
    for (const project of imported) {
      const byId = merged.find((current) => current.id === project.id);
      if (byId) {
        const identical = byId.name === project.name &&
          byId.nodeCount === project.nodeCount &&
          byId.words.length === project.words.length &&
          byId.words.every((word, index) => word === project.words[index]);
        if (identical) continue;
        throw new Error("Project ID conflicts with an existing local project");
      }
      if (merged.some((current) =>
        current.name.toLocaleLowerCase() === project.name.toLocaleLowerCase())) {
        throw new Error("Project name conflicts with an existing local project");
      }
      if (merged.length >= MAX_SAVED_PROJECTS) {
        throw new Error("Project library is full (32 projects)");
      }
      merged.push(project);
      added += 1;
    }
    writeSavedProjects(merged);
    savedProjects = merged;
    if (added > 0) selectedProjectId = merged[merged.length - 1].id;
    renderProjectLibrary();
    byId("project-message").textContent =
      "Imported " + added + " project" + (added === 1 ? "" : "s") +
      "; existing projects were preserved.";
  }


  function writeSavedProjects(projects = savedProjects) {
    localStorage.setItem(PROJECT_STORAGE_KEY, JSON.stringify(projects));
  }

  function renderProjectLibrary() {
    const list = byId("project-list");
    list.replaceChildren();
    byId("project-empty").hidden = savedProjects.length > 0;
    for (const project of savedProjects) {
      const row = document.createElement("button");
      row.type = "button";
      row.className = "project-row";
      row.setAttribute("role", "option");
      row.setAttribute("aria-pressed", String(project.id === selectedProjectId));
      const details = document.createElement("span");
      const name = document.createElement("strong");
      name.textContent = project.name;
      const metadata = document.createElement("small");
      metadata.textContent = new Date(project.updatedAt).toLocaleString() +
        " · " + project.nodeCount + " nodes";
      details.append(name, metadata);
      row.appendChild(details);
      row.addEventListener("click", () => {
        selectedProjectId = project.id;
        renderProjectLibrary();
      });
      list.appendChild(row);
    }
    const selected = savedProjects.some((project) => project.id === selectedProjectId);
    for (const id of ["project-load", "project-update", "project-rename", "project-duplicate", "project-export", "project-delete"]) {
      byId(id).disabled = !selected;
    }

  }
  function saveProject(name, replaceId = "", source = documentState) {
    if (!source) throw new Error("Kof has not provided a world to save");
    const cleanName = name.trim();
    if (!cleanName || cleanName.length > 64) throw new Error("Project name must be 1–64 characters");
    const duplicate = savedProjects.find((project) =>
      project.name.toLocaleLowerCase() === cleanName.toLocaleLowerCase() &&
      project.id !== replaceId);
    if (duplicate) throw new Error("A project with that name already exists");
    const index = savedProjects.findIndex((project) => project.id === replaceId);
    if (index < 0 && savedProjects.length >= MAX_SAVED_PROJECTS) {
      throw new Error("Project library is full (32 projects)");
    }
    const project = {
      id: replaceId || (Date.now().toString(36) + Math.random().toString(36).slice(2, 8)),
      name: cleanName,
      updatedAt: new Date().toISOString(),
      nodeCount: source.nodes.length,
      words: Array.from(source.words),
    };
    const projects = savedProjects.slice();
    if (index < 0) projects.push(project);
    else projects[index] = project;
    writeSavedProjects(projects);
    savedProjects = projects;
    selectedProjectId = project.id;
    renderProjectLibrary();
  }
  function duplicateProject(project) {
    if (!project) throw new Error("Select a project to duplicate");
    if (savedProjects.length >= MAX_SAVED_PROJECTS) {
      throw new Error("Project library is full (32 projects)");
    }
    const words = Int32Array.from(project.words);
    const original = decodeDocument(words);
    if (original.nodes.length !== project.nodeCount ||
        !validateDocumentChecksum(words, original)) {
      throw new Error("Selected project document is invalid");
    }
    const usedDocumentIds = new Set(savedProjects.map((entry) => entry.words[5]));
    let newDocumentId = Math.floor(Math.random() * 1000000) + 1;
    for (let attempt = 0; attempt <= MAX_SAVED_PROJECTS; attempt += 1) {
      if (!usedDocumentIds.has(newDocumentId)) break;
      newDocumentId = newDocumentId === 1000000 ? 1 : newDocumentId + 1;
    }
    if (usedDocumentIds.has(newDocumentId)) {
      throw new Error("Could not allocate a unique document ID");
    }
    words[5] = newDocumentId;
    words[6] = 1;
    words[9] = 1;
    const duplicateDocument = decodeDocument(words);
    words[3] = calculateDocumentChecksum(words, duplicateDocument);
    if (!validateDocumentChecksum(words, duplicateDocument)) {
      throw new Error("Could not reseal duplicated project document");
    }
    const suffixes = Array.from({ length: MAX_SAVED_PROJECTS }, (_, index) =>
      index === 0 ? " copy" : " copy " + (index + 1));
    let name = "";
    for (const suffix of suffixes) {
      const candidate = project.name.slice(0, 64 - suffix.length) + suffix;
      if (!savedProjects.some((entry) =>
        entry.name.toLocaleLowerCase() === candidate.toLocaleLowerCase())) {
        name = candidate;
        break;
      }
    }
    if (!name) throw new Error("Could not allocate a unique project name");
    const localIdBase = Date.now().toString(36) +
      Math.random().toString(36).slice(2, 8);
    let localId = localIdBase;
    let localSuffix = 1;
    while (savedProjects.some((entry) => entry.id === localId)) {
      localId = localIdBase + "-" + localSuffix;
      localSuffix += 1;
    }
    const duplicate = {
      id: localId,
      name,
      updatedAt: new Date().toISOString(),
      nodeCount: original.nodes.length,
      words: Array.from(words),
    };
    const projects = [...savedProjects, duplicate];
    writeSavedProjects(projects);
    savedProjects = projects;
    selectedProjectId = duplicate.id;
    renderProjectLibrary();
    return duplicate;
  }

  try {
    savedProjects = readSavedProjects();
  } catch (error) {
    savedProjects = [];
    byId("project-message").textContent = "Could not read local projects: " + error.message;
  }

  document.querySelectorAll("[data-tool]").forEach((button) => {
    button.addEventListener("click", async () => {
      button.closest("details")?.removeAttribute("open");
      try { await operate(COMMAND.tool, [Number(button.dataset.tool)]); } catch (error) {}
    });
  });
  const layersToggle = byId("layers-toggle");
  const levelInspector = byId("level-inspector");
  const kutterWorkspace = byId("kutter-workspace");
  const buildToolsPanel = byId("build-tools-panel");
  const panelElements = {
    tools: buildToolsPanel,
    inspector: levelInspector,
  };
  const panelPositions = {};
  try {
    const savedLayout = JSON.parse(localStorage.getItem(PANEL_LAYOUT_KEY) || "null");
    if (savedLayout?.version === 1 && savedLayout.positions &&
        typeof savedLayout.positions === "object") {
      for (const name of Object.keys(panelElements)) {
        const position = savedLayout.positions[name];
        if (Number.isFinite(position?.x) && Number.isFinite(position?.y) &&
            Math.abs(position.x) <= 100000 && Math.abs(position.y) <= 100000) {
          panelPositions[name] = { x: position.x, y: position.y };
        }
      }
    }
  } catch (error) {}

  function savePanelPositions() {
    try {
      localStorage.setItem(PANEL_LAYOUT_KEY, JSON.stringify({
        version: 1, positions: panelPositions,
      }));
    } catch (error) {}
  }

  function applyPanelPosition(name, position) {
    const panel = panelElements[name];
    const bounds = kutterWorkspace.getBoundingClientRect();
    if (!panel || bounds.width <= 0 || bounds.height <= 0) return;
    const maxWidth = Math.max(0, bounds.width - 16);
    const inspectorWidth = Math.min(
      window.innerWidth <= 860 ? 360 : 340, maxWidth,
    );
    const width = Math.min(panel.offsetWidth ||
      (name === "inspector" ? inspectorWidth : maxWidth), maxWidth);
    const maxHeight = Math.max(0, bounds.height - 16);
    const height = Math.min(panel.offsetHeight ||
      (name === "inspector" ? maxHeight : 0), maxHeight);
    const x = Math.round(Math.max(0, Math.min(
      bounds.width - width, position.x,
    )));
    const y = Math.round(Math.max(0, Math.min(
      bounds.height - height, position.y,
    )));
    panel.style.left = x + "px";
    panel.style.top = y + "px";
    panel.style.right = "auto";
    panel.style.bottom = "auto";
    panel.style.transform = "none";
    if (name === "inspector") panel.style.height = height + "px";
    panelPositions[name] = { x, y };
  }

  function installPanelMovement(name, handle) {
    const panel = panelElements[name];
    let drag = null;
    handle.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      const panelBounds = panel.getBoundingClientRect();
      const workspaceBounds = kutterWorkspace.getBoundingClientRect();
      if (panelBounds.width <= 0 || panelBounds.height <= 0) return;
      drag = {
        pointerId: event.pointerId,
        offsetX: event.clientX - panelBounds.left,
        offsetY: event.clientY - panelBounds.top,
        workspaceLeft: workspaceBounds.left,
        workspaceTop: workspaceBounds.top,
      };
      try { handle.focus({ preventScroll: true }); } catch (error) { handle.focus(); }
      try { handle.setPointerCapture?.(event.pointerId); } catch (error) {}
      event.preventDefault();
    });
    handle.addEventListener("pointermove", (event) => {
      if (!drag || drag.pointerId !== event.pointerId) return;
      applyPanelPosition(name, {
        x: event.clientX - drag.workspaceLeft - drag.offsetX,
        y: event.clientY - drag.workspaceTop - drag.offsetY,
      });
    });
    const finishDrag = (event) => {
      if (!drag || drag.pointerId !== event.pointerId) return;
      drag = null;
      savePanelPositions();
    };
    handle.addEventListener("pointerup", finishDrag);
    handle.addEventListener("pointercancel", finishDrag);
    handle.addEventListener("keydown", (event) => {
      const step = event.shiftKey ? 48 : 16;
      const offsets = {
        ArrowLeft: [-step, 0], ArrowRight: [step, 0],
        ArrowUp: [0, -step], ArrowDown: [0, step],
      };
      const offset = offsets[event.key];
      if (!offset) return;
      const rect = panel.getBoundingClientRect();
      const bounds = kutterWorkspace.getBoundingClientRect();
      const position = panelPositions[name] || {
        x: rect.left - bounds.left, y: rect.top - bounds.top,
      };
      event.preventDefault();
      applyPanelPosition(name, {
        x: position.x + offset[0], y: position.y + offset[1],
      });
      savePanelPositions();
    });
  }

  installPanelMovement("tools", byId("move-build-tools"));
  installPanelMovement("inspector", byId("move-level-inspector"));
  if (panelPositions.tools) applyPanelPosition("tools", panelPositions.tools);
  if (panelPositions.inspector && !levelInspector.hidden) {
    applyPanelPosition("inspector", panelPositions.inspector);
  }
  window.addEventListener("resize", () => {
    for (const [name, position] of Object.entries(panelPositions)) {
      if (!panelElements[name].hidden) applyPanelPosition(name, position);
    }
    if (Object.keys(panelPositions).length > 0) savePanelPositions();
  });
  layersToggle.addEventListener("click", () => {
    levelInspector.hidden = !levelInspector.hidden;
    if (!levelInspector.hidden && panelPositions.inspector) {
      applyPanelPosition("inspector", panelPositions.inspector);
    }
    layersToggle.setAttribute("aria-expanded", String(!levelInspector.hidden));
    layersToggle.setAttribute(
      "aria-label",
      levelInspector.hidden ? "Show layers and properties" : "Hide layers and properties",
    );
    layersToggle.textContent = levelInspector.hidden ? "Layers" : "Close";
  });
  byId("reset-panel-layout").addEventListener("click", () => {
    for (const panel of Object.values(panelElements)) {
      panel.style.left = "";
      panel.style.top = "";
      panel.style.right = "";
      panel.style.bottom = "";
      panel.style.transform = "";
      panel.style.height = "";
    }
    for (const name of Object.keys(panelPositions)) delete panelPositions[name];
    try { localStorage.removeItem(PANEL_LAYOUT_KEY); } catch (error) {}
    byId("file-menu").removeAttribute("open");
  });
  byId("grid-size").addEventListener("change", async () => {
    try { await operate(COMMAND.grid, [Number(byId("grid-size").value)]); } catch (error) {}
  });
  byId("rotate-down").addEventListener("click", async () => {
    try { await operate(COMMAND.rotate, [-1]); } catch (error) {}
  });
  byId("rotate-up").addEventListener("click", async () => {
    try { await operate(COMMAND.rotate, [1]); } catch (error) {}
  });
  for (const [id, direction] of [["scale-down", -1], ["scale-up", 1]]) {
    byId(id).addEventListener("click", async () => {
      try {
        await operate(COMMAND.resize, [Number(byId("scale-axis").value), direction]);
      } catch (error) {}
    });
  }
  for (const [id, direction] of [["height-down", -1], ["height-up", 1]]) {
    byId(id).addEventListener("click", async () => {
      try { await operate(COMMAND.height, [direction]); } catch (error) {}
    });
  }
  byId("behavior-save").addEventListener("click", async () => {
    try {
      await operate(COMMAND.behaviorCards, [
        Number(byId("behavior-attack").value),
        Number(byId("behavior-chase").value),
        3,
      ]);
      byId("behavior-status").textContent =
        "Behavior cards saved and installed in the shared enemy runtime.";
    } catch (error) {
      byId("behavior-status").textContent = "Save failed: " + error.message;
    }
  });
  byId("behavior-install").addEventListener("click", async () => {
    try {
      await operate(COMMAND.installBehavior);
      byId("behavior-status").textContent =
        "Saved behavior cards installed in the shared enemy runtime.";
    } catch (error) {
      byId("behavior-status").textContent = "Install failed: " + error.message;
    }
  });
  byId("asset-catalog").addEventListener("change", () => {
    const node = currentNode();
    byId("asset-token").value = byId("asset-catalog").value;
    renderAssetCatalog(node, false);
  });
  for (const id of ["asset-search", "asset-kind-filter"]) {
    byId(id).addEventListener("input", () =>
      renderAssetCatalog(currentNode(), false));
    byId(id).addEventListener("change", () =>
      renderAssetCatalog(currentNode(), false));
  }
  byId("assign-asset").addEventListener("click", updateSelectedFromForm);
  byId("add-asset").addEventListener("click", async () => {
    const token = Number(byId("asset-catalog").value);
    if (!Number.isInteger(token) || token <= 0 || !documentState) return;
    try {
      await operate(COMMAND.tool, [2]);
      await operate(COMMAND.cursor, [documentState.cursorX, documentState.cursorZ]);
      await operate(COMMAND.apply);
      const node = currentNode();
      if (!node || node.kind !== 2) throw new Error("Kof did not select the new prop");
      setField("asset-token", token);
      await updateSelectedFromForm();
    } catch (error) {}
  });
  byId("preview-toggle").addEventListener("click", async () => {
    try {
      await operate(COMMAND.preview);
      previewActive = !previewActive;
      drawUi();
    } catch (error) {}
  });
  canvas.addEventListener("click", async (event) => {
    if (!documentState) return;
    const point = screenWorldPoint(event);
    const hit = currentScene && renderer?.projectWorld
      ? documentState.nodes.map((node) => ({ node, point: renderer.projectWorld(
          currentScene, node.x / 100, (node.y + node.scaleY / 500) / 100, node.z / 100,
        ) })).filter((entry) => entry.point)
        .map((entry) => ({ ...entry, distance: Math.hypot(
          (entry.point.x * canvas.clientWidth) - (event.clientX - canvas.getBoundingClientRect().left),
          (entry.point.y * canvas.clientHeight) - (event.clientY - canvas.getBoundingClientRect().top),
        ) })).sort((a, b) => a.distance - b.distance)[0]
      : null;
    if (documentState.tool === 1 && hit && hit.distance < 40) {
      try { await operate(COMMAND.select, [hit.node.id]); } catch (error) {}
      return;
    }
    if (documentState.tool === 8) {
      if (!hit || hit.distance >= 40) return;
      try {
        await operate(COMMAND.select, [hit.node.id]);
        await operate(COMMAND.apply);
      } catch (error) {}
      return;
    }
    try {
      await operate(COMMAND.cursor, [point.x, point.z]);
      await operate(COMMAND.apply);
    } catch (error) {}
  });
  byId("inspector-form").addEventListener("submit", (event) => event.preventDefault());
  for (const id of ["node-x", "node-y", "node-z", "node-rotation", "node-sx", "node-sy", "node-sz", "node-color", "asset-token"]) {
    byId(id).addEventListener("change", updateSelectedFromForm);
  }
  byId("duplicate-node").addEventListener("click", async () => {
    try { await operate(COMMAND.duplicate); } catch (error) {}
  });
  byId("delete-node").addEventListener("click", async () => {
    try { await operate(COMMAND.remove); } catch (error) {}
  });
  byId("move-node").addEventListener("click", async () => {
    const node = currentNode();
    if (!node) return;
    const point = screenWorldPoint({ clientX: canvas.getBoundingClientRect().left + canvas.clientWidth / 2,
      clientY: canvas.getBoundingClientRect().top + canvas.clientHeight / 2 });
    try { await operate(COMMAND.move, [point.x, point.z]); } catch (error) {}
  });
  byId("reset-transform").addEventListener("click", async () => {
    const node = currentNode();
    if (!node) return;
    try {
      await operate(COMMAND.update, [node.x, 0, node.z, 0, 1000, 1000, 1000, 0xffffff, 0]);
    } catch (error) {}
  });
  byId("group-nodes").addEventListener("click", async () => {
    const ids = Array.from(groupedSelection);
    if (ids.length < 2) return;
    try {
      await operate(COMMAND.select, [ids[0]]);
      await operate(COMMAND.group, [ids[1]]);
      groupedSelection.clear();
    } catch (error) {}
  });
  byId("ungroup-node").addEventListener("click", async () => {
    try { await operate(COMMAND.ungroup); } catch (error) {}
  });
  byId("undo").addEventListener("click", async () => {
    try { await operate(COMMAND.undo); } catch (error) {}
  });
  byId("redo").addEventListener("click", async () => {
    try { await operate(COMMAND.redo); } catch (error) {}
  });
  byId("refresh").addEventListener("click", async () => {
    try { await operate(COMMAND.get); } catch (error) {}
  });
  byId("save-file").addEventListener("click", downloadDocument);
  byId("open-file").addEventListener("click", () => byId("file-input").click());
  const projectDialog = byId("project-dialog");
  byId("projects-open").addEventListener("click", () => {
    byId("project-message").textContent = "";
    renderProjectLibrary();
    projectDialog.showModal();
  });
  byId("project-library-export").addEventListener("click", () => {
    try {
      downloadProjectLibrary();
    } catch (error) {
      byId("project-message").textContent = "Export failed: " + error.message;
    }
  });
  byId("project-library-import").addEventListener("click", () =>
    byId("project-library-file").click());
  byId("project-library-file").addEventListener("change", async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    try {
      await importProjectLibrary(file);
    } catch (error) {
      byId("project-message").textContent = "Import failed: " + error.message;
    } finally {
      event.target.value = "";
    }
  });
  byId("project-new").addEventListener("click", async () => {
    const name = byId("project-name").value.trim();
    if (!name) {
      byId("project-message").textContent = "Enter a name for the new arena.";
      byId("project-name").focus();
      return;
    }
    if (!documentState || ws?.readyState !== WebSocket.OPEN) {
      byId("project-message").textContent = "Connect to Kof before creating a new arena.";
      return;
    }
    if (!window.confirm("Create a blank arena and replace the shared Kof editor document for every connected editor?")) {
      return;
    }
    try {
      const words = blankArenaDocument();
      const source = decodeDocument(words);
      saveProject(name, "", source);
      await importWords(words, "new project “" + name + "”");
      byId("project-name").value = "";
      byId("project-message").textContent = "Blank arena created and saved in this browser.";
    } catch (error) {
      byId("project-message").textContent = "Could not create project: " + error.message;
    }
  });
  byId("project-save-as").addEventListener("click", () => {
    try {
      saveProject(byId("project-name").value);
      byId("project-name").value = "";
      byId("project-message").textContent = "Project saved in this browser.";
    } catch (error) {
      byId("project-message").textContent = error.message;
    }
  });
  byId("project-rename").addEventListener("click", () => {
    const selected = savedProjects.find((project) => project.id === selectedProjectId);
    if (!selected) return;
    const cleanName = byId("project-name").value.trim();
    if (!cleanName || cleanName.length > 64) {
      byId("project-message").textContent = "Project name must be 1–64 characters.";
      byId("project-name").focus();
      return;
    }
    if (savedProjects.some((project) =>
      project.id !== selected.id &&
      project.name.toLocaleLowerCase() === cleanName.toLocaleLowerCase())) {
      byId("project-message").textContent = "A project with that name already exists.";
      byId("project-name").focus();
      return;
    }
    const projects = savedProjects.map((project) => project.id === selected.id
      ? { ...project, name: cleanName, updatedAt: new Date().toISOString() }
      : project);
    try {
      writeSavedProjects(projects);
      savedProjects = projects;
      byId("project-name").value = "";
      byId("project-message").textContent = "Renamed project to “" + cleanName + "”.";
      renderProjectLibrary();
    } catch (error) {
      byId("project-message").textContent = "Rename failed: " + error.message;
    }
  });
  byId("project-duplicate").addEventListener("click", () => {
    const selected = savedProjects.find((project) => project.id === selectedProjectId);
    if (!selected) return;
    try {
      const duplicate = duplicateProject(selected);
      byId("project-message").textContent =
        "Created “" + duplicate.name + "” without changing the shared Kof document.";
    } catch (error) {
      byId("project-message").textContent = "Duplicate failed: " + error.message;
    }
  });
  byId("project-update").addEventListener("click", () => {
    const selected = savedProjects.find((project) => project.id === selectedProjectId);
    if (!selected) return;
    try {
      saveProject(selected.name, selected.id);
      byId("project-message").textContent = "Saved changes to “" + selected.name + "”.";
    } catch (error) {
      byId("project-message").textContent = error.message;
    }
  });
  byId("project-load").addEventListener("click", async () => {
    const selected = savedProjects.find((project) => project.id === selectedProjectId);
    if (!selected) return;
    if (!documentState || ws?.readyState !== WebSocket.OPEN) {
      byId("project-message").textContent = "Connect to Kof before loading a project.";
      return;
    }
    if (!window.confirm("Load “" + selected.name + "” and replace the shared Kof editor document for every connected editor?")) {
      return;
    }
    try {
      await importWords(selected.words, "project “" + selected.name + "”");
      projectDialog.close();
    } catch (error) {
      byId("project-message").textContent = "Load failed: " + error.message;
    }
  });
  byId("project-export").addEventListener("click", () => {
    const selected = savedProjects.find((project) => project.id === selectedProjectId);
    if (!selected) return;
    try {
      const source = decodeDocument(Int32Array.from(selected.words));
      downloadDocument(source, selected.name.replace(/[^a-z0-9_-]+/gi, "-") + ".kutter");
    } catch (error) {
      byId("project-message").textContent = "Export failed: " + error.message;
    }
  });
  byId("project-delete").addEventListener("click", () => {
    const selected = savedProjects.find((project) => project.id === selectedProjectId);
    if (!selected || !window.confirm("Delete “" + selected.name + "” from this browser?")) return;
    const projects = savedProjects.filter((project) => project.id !== selected.id);
    try {
      writeSavedProjects(projects);
      savedProjects = projects;
      selectedProjectId = "";
      byId("project-message").textContent = "Project deleted.";
    } catch (error) {
      byId("project-message").textContent = "Delete failed: " + error.message;
    }
    renderProjectLibrary();
  });
  projectDialog.addEventListener("click", (event) => {
    if (event.target === projectDialog) projectDialog.close();
  });
  const fullscreenButton = byId("fullscreen-button");
  const fullscreenStatus = byId("fullscreen-status");
  const fullscreenRoot = byId("kutter-app");
  function updateFullscreenButton() {
    const active = document.fullscreenElement === fullscreenRoot ||
      document.webkitFullscreenElement === fullscreenRoot;
    fullscreenButton.setAttribute("aria-pressed", String(active));
    fullscreenButton.setAttribute(
      "aria-label", active ? "Exit fullscreen" : "Enter fullscreen",
    );
    fullscreenButton.title = active ? "Exit fullscreen" : "Enter fullscreen";
    fullscreenButton.textContent = active ? "Exit fullscreen" : "Fullscreen";
  }
  async function toggleFullscreen() {
    const active = document.fullscreenElement === fullscreenRoot ||
      document.webkitFullscreenElement === fullscreenRoot;
    try {
      if (active) {
        const exit = document.exitFullscreen || document.webkitExitFullscreen;
        if (!exit) throw new Error("Fullscreen exit is unavailable in this browser");
        await exit.call(document);
      } else {
        const enter = fullscreenRoot.requestFullscreen ||
          fullscreenRoot.webkitRequestFullscreen;
        if (!enter) throw new Error("Fullscreen is unavailable in this browser");
        await enter.call(fullscreenRoot);
      }
      fullscreenStatus.textContent = "";
    } catch (error) {
      fullscreenStatus.textContent = error.message ||
        "Fullscreen was denied by the browser";
    }
    updateFullscreenButton();
  }
  fullscreenButton.addEventListener("click", toggleFullscreen);
  document.addEventListener("fullscreenchange", updateFullscreenButton);
  document.addEventListener("webkitfullscreenchange", updateFullscreenButton);
  byId("file-input").addEventListener("change", async () => {
    const file = byId("file-input").files[0];
    if (!file) return;
    try { await importDocument(file); }
    catch (error) { statusMessage = error.message; drawUi(); }
    byId("file-input").value = "";
  });

  function updateDocumentMeta() { renderValidation(); }

  async function refreshDocument() {
    if (refreshInFlight || shuttingDown || !ws || ws.readyState !== WebSocket.OPEN) return;
    refreshInFlight = true;
    try { await operate(COMMAND.get); } catch (error) {}
    finally { refreshInFlight = false; }
  }

  function startDocumentRefresh() {
    if (refreshTimer !== null) return;
    void refreshDocument();
    refreshTimer = window.setInterval(refreshDocument, 5000);
  }

  function connect() {
    if (shuttingDown) return;
    const scheme = location.protocol === "https:" ? "wss:" : "ws:";
    const clientSocket = new WebSocket(
      scheme + "//" + location.host + "/kutter/session",
      ["kookie.v1", "kutter.v1"],
    );
    ws = clientSocket;
    clientSocket.binaryType = "arraybuffer";
    clientSocket.addEventListener("open", () => {
      if (ws !== clientSocket || shuttingDown) return;
      connectionState.textContent = "CONNECTING";
      statusMessage = "Connected to Kof · waiting for canonical Kutter document";
      sendHello();
      heartbeatTimer = window.setInterval(sendHeartbeat, 1000);
      drawUi();
    });
    clientSocket.addEventListener("message", (event) => {
      if (ws !== clientSocket || shuttingDown) return;
      try {
        const frame = decodeFrame(event.data);
        if (frame.kind === KIND_ACK) {
          startDocumentRefresh();
          return;
        }
        if (frame.kind === KIND_PONG) return;
        if (frame.kind === KIND_GAME) receiveState(frame);
      } catch (error) {
        statusMessage = error.message;
        drawUi();
      }
    });
    clientSocket.addEventListener("close", (event) => {
      if (ws !== clientSocket) return;
      ws = null;
      if (heartbeatTimer !== null) window.clearInterval(heartbeatTimer);
      if (refreshTimer !== null) window.clearInterval(refreshTimer);
      refreshTimer = null;
      refreshInFlight = false;
      heartbeatTimer = null;
      rejectPendingRequests(new Error("Kof Kutter connection closed"));
      connectionState.textContent = "DISCONNECTED";
      statusMessage = shuttingDown
        ? "Kof connection closed"
        : "Kof connection closed (" + event.code +
          (event.reason ? ": " + event.reason : "") + ") · reconnecting in 2 seconds";
      drawUi();
      if (!shuttingDown) {
        reconnectTimer = window.setTimeout(() => {
          reconnectTimer = null;
          connect();
        }, 2000);
      }
    });
    clientSocket.addEventListener("error", () => {
      if (ws !== clientSocket || shuttingDown) return;
      connectionState.textContent = "CONNECTION ERROR";
      statusMessage = "Kof editor endpoint unavailable";
      drawUi();
    });
  }

  window.addEventListener("pagehide", () => {
    shuttingDown = true;
    if (reconnectTimer !== null) window.clearTimeout(reconnectTimer);
    reconnectTimer = null;
    if (heartbeatTimer !== null) window.clearInterval(heartbeatTimer);
    if (refreshTimer !== null) window.clearInterval(refreshTimer);
    refreshTimer = null;
    heartbeatTimer = null;
    rejectPendingRequests(new Error("Kutter editor page closed"));
    const activeSocket = ws;
    ws = null;
    if (activeSocket && activeSocket.readyState < WebSocket.CLOSING) {
      activeSocket.close();
    }
    if (animationFrameHandle) cancelAnimationFrame(animationFrameHandle);
    if (renderer && typeof renderer.destroy === "function") renderer.destroy();
    renderer = null;
    if (previewRenderer && typeof previewRenderer.destroy === "function") {
      previewRenderer.destroy();
    }
    previewRenderer = null;
  });
  async function start() {
    try {
      renderer = await window.KookieWebRenderer.create(canvas);
      rendererReady = Boolean(renderer?.supported);
      if (!rendererReady) throw new Error(renderer?.reason || "WebGL2 unavailable");
    } catch (error) {
      statusMessage = "Viewport unavailable: " + error.message;
      drawUi();
    }
    if (rendererReady && !shuttingDown) {
      try {
        previewRenderer = await window.KookieWebRenderer.create(
          byId("asset-preview"), { previewOnly: true },
        );
        previewRendererReady = Boolean(previewRenderer?.supported);
      } catch (error) {
        previewRendererReady = false;
      }
    }
    if (shuttingDown) {
      if (renderer && typeof renderer.destroy === "function") renderer.destroy();
      if (previewRenderer && typeof previewRenderer.destroy === "function") {
        previewRenderer.destroy();
      }
      renderer = null;
      previewRenderer = null;
      return;
    }
    renderAssetCatalog(currentNode(), false);
    animationFrameHandle = requestAnimationFrame(frame);
    connect();
  }

  loadAssetCatalog();
  start();
})();
