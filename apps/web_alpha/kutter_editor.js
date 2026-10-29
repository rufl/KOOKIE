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
  });
  const NODE_GROUP = 9;
  const NODE_LABELS = {
    1: "Select", 2: "Prop", 3: "Player spawn", 4: "Enemy spawn",
    5: "Encounter", 6: "Goal trigger", 7: "Light", 8: "Erase",
    9: "Group",
  };
  const TRANSFER_WORDS = 256;
  const MAX_DOCUMENT_WORDS = 11 + 64 * 13 + 32 * 5;
  const byId = (id) => document.getElementById(id);
  const canvas = byId("kutter-viewport");
  const connectionState = byId("connection-state");
  const message = byId("editor-message");
  const viewportInfo = byId("viewport-info");
  const nodeList = byId("node-list");
  const form = byId("inspector-form");
  let renderer = null;
  let ws = null;
  let requestSequence = 1;
  let documentState = null;
  let commandQueue = Promise.resolve();
  let rendererReady = false;
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
    transfer.metadata = { command, generation, selected, tool, cursorX, cursorZ, grid, validation };
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
    if (words[0] !== 126375140 || ![1, 2, 3].includes(version) ||
        nodeCount < 1 || nodeCount > 64 || assetCount < 0 || assetCount > 32 ||
        words[2] !== words.length) throw new Error("Unsupported Kutter document schema");
    const stride = version === 1 ? 8 : version === 2 ? 12 : 13;
    if (words.length !== 11 + nodeCount * stride + assetCount * 5) {
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
    return { words, version, projectNamespace: words[4], projectId: words[5],
      projectRevision: words[6], generation: words[9], nodes, assets,
      checksum: words[3] };
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
  function renderAssetCatalog(node) {
    const select = byId("asset-catalog");
    select.replaceChildren();
    if (assetCatalog.length === 0) {
      const option = document.createElement("option");
      option.value = "";
      option.textContent = assetCatalogError ? "Catalog unavailable" :
        assetCatalogLoaded ? "No catalog assets" : "Loading catalog…";
      select.appendChild(option);
    } else {
      for (const asset of assetCatalog) {
        const option = document.createElement("option");
        option.value = String(asset.asset_token);
        option.textContent = asset.module_id + " · " + asset.name + " · " + asset.kind;
        select.appendChild(option);
      }
    }
    const available = assetCatalogLoaded && assetCatalog.length > 0;
    select.disabled = !available;
    byId("asset-add-status").textContent = assetCatalogError ||
      (available ? "Assign to a selected prop or add at the cursor." :
        assetCatalogLoaded ? "No prototype assets are available." : "Loading prototype asset catalog…");
    if (node && node.asset > 0) {
      if (assetCatalog.some((asset) => asset.asset_token === node.asset)) {
        select.value = String(node.asset);
      } else {
        select.selectedIndex = -1;
      }
    } else if (assetCatalog.length) {
      select.selectedIndex = 0;
    }
    const hasSelection = assetCatalog.some((asset) =>
      asset.asset_token === Number(select.value));
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
      assetCatalogError = "Asset catalog unavailable: " + error.message;
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
    byId("undo").disabled = documentState.generation <= 1;
    byId("redo").disabled = documentState.generation <= 1;
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

  function downloadDocument() {
    if (!documentState) return;
    const bytes = new Uint8Array(documentState.words.length * 4);
    const view = new DataView(bytes.buffer);
    documentState.words.forEach((word, index) => view.setInt32(index * 4, word, true));
    const url = URL.createObjectURL(new Blob([bytes], { type: "application/octet-stream" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = "level-" + documentState.projectId + ".kutter";
    link.click();
    URL.revokeObjectURL(url);
    statusMessage = "Saved canonical Kutter v" + documentState.version + " document";
    drawUi();
  }

  async function importDocument(file) {
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length % 4 !== 0 || bytes.length / 4 > MAX_DOCUMENT_WORDS) {
      throw new Error("Kutter file size is invalid or exceeds the document limit");
    }
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const words = new Int32Array(bytes.length / 4);
    for (let i = 0; i < words.length; i += 1) words[i] = view.getInt32(i * 4, true);
    if (words.length < 11 || words[2] !== words.length) throw new Error("Invalid Kutter file header");
    for (let offset = 0; offset < words.length; offset += TRANSFER_WORDS) {
      const chunk = Array.from(words.subarray(offset, Math.min(words.length, offset + TRANSFER_WORDS)));
      await operate(COMMAND.import, [words.length, offset, ...chunk]);
    }
    statusMessage = "Kof loaded and validated " + file.name;
    drawUi();
  }

  document.querySelectorAll("[data-tool]").forEach((button) => {
    button.addEventListener("click", async () => {
      button.closest("details")?.removeAttribute("open");
      try { await operate(COMMAND.tool, [Number(button.dataset.tool)]); } catch (error) {}
    });
  });
  const layersToggle = byId("layers-toggle");
  const levelInspector = byId("level-inspector");
  layersToggle.addEventListener("click", () => {
    levelInspector.hidden = !levelInspector.hidden;
    layersToggle.setAttribute("aria-expanded", String(!levelInspector.hidden));
    layersToggle.setAttribute(
      "aria-label",
      levelInspector.hidden ? "Show layers and properties" : "Hide layers and properties",
    );
    layersToggle.textContent = levelInspector.hidden ? "Layers" : "Close";
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
  byId("asset-catalog").addEventListener("change", () => {
    const token = Number(byId("asset-catalog").value);
    const selected = assetCatalog.some((asset) => asset.asset_token === token);
    const node = currentNode();
    byId("asset-token").value = byId("asset-catalog").value;
    byId("assign-asset").disabled = !selected || !node || node.kind !== 2;
    byId("add-asset").disabled = !selected || !documentState;
  });
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
    animationFrameHandle = 0;
    if (renderer && typeof renderer.destroy === "function") renderer.destroy();
    renderer = null;
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
    if (shuttingDown) {
      if (renderer && typeof renderer.destroy === "function") renderer.destroy();
      renderer = null;
      return;
    }
    animationFrameHandle = requestAnimationFrame(frame);
    connect();
  }

  loadAssetCatalog();
  start();
})();
