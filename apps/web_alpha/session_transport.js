(() => {
  "use strict";

  const MAGIC = [0x4b, 0x57, 0x53, 0x31];
  const FRAME_VERSION = 1;
  const NETCODE_PROTOCOL_VERSION = 2;
  const MAX_WORDS = 272;
  const MAX_FRAME_BYTES = 16 + MAX_WORDS * 4;
  const MAX_SEQUENCE = 1000000;
  const SCENE_OBJECT_ENTRY_WIDTH = 9;
  const SCENE_LABEL_ENTRY_WIDTH = 6;
  const SCENE_OBJECTS_OFFSET = 69;
  const MAX_SCENE_OBJECTS = 17;
  const MAX_SCENE_LABELS = 8;
  const SCENE_LABEL_TEXT = Object.freeze({
    1: "GOOSE",
    2: "BOT WADDLE",
    3: "BOT HONK",
    4: "BOT POND",
  });
  const SCENE_OBJECT_DOOR = 1;
  const SCENE_OBJECT_FLOATABLE = 2;
  const SCENE_OBJECT_POWERUP = 3;
  const SCENE_OBJECT_LOOT_BEAM = 4;
  const HELLO = 1;
  const ACK = 2;
  const PING = 3;
  const PONG = 4;
  const ERROR = 5;
  const GAME = 6;
  const CLIENT_TARGET_BROWSER = 1;
  const AUTHORITY_REMOTE = 1;
  const GAME_WEBSOCKET = 1;
  const BROWSER_CAPABILITY = 1;
  const SERVER_CAPABILITY = 1;
  const GAME_PROBE_PAYLOAD = 7127;
  const WEBSOCKET_SUBPROTOCOL = "kookie.v1";
  const AUTH_SUBPROTOCOL_PREFIX = "bearer.";
  const AUTH_TOKEN_MINIMUM_LENGTH = 8;
  const AUTH_TOKEN_MAXIMUM_LENGTH = 128;
  const GAME_COMMAND_MARKER = 1;
  const GAME_SNAPSHOT_MARKER = 2;
  const GAME_SCENE_SNAPSHOT_MARKER = 3;
  const GAME_FULL_SCENE_SNAPSHOT_MARKER = 4;
  const GAME_MOVE_LEFT = 1;
  const GAME_MOVE_RIGHT = 2;
  const GAME_MELEE = 3;
  const GAME_SPECIAL = 4;
  const GAME_RESET = 5;
  const GAME_SCENE_PROBE = 6;
  const GAME_FULL_SCENE_PROBE = 7;
  const GAME_MOVE_FORWARD = 8;
  const GAME_MOVE_BACK = 9;
  const GAME_STRAFE_LEFT = 10;
  const GAME_STRAFE_RIGHT = 11;
  const GAME_LOOK_LEFT = 12;
  const GAME_LOOK_RIGHT = 13;
  const GAME_FIRE = 14;
  const GAME_JUMP = 15;
  const GAME_MINIMUM_POSITION = -100;
  const GAME_MAXIMUM_POSITION = 100;
  const GAME_MINIMUM_DEPTH = -60;
  const GAME_MAXIMUM_DEPTH = 60;
  const GAME_WORLD_MINIMUM_X = 4;
  const GAME_WORLD_MAXIMUM_X = 316;
  const GAME_WORLD_MINIMUM_Y = 1;
  const GAME_WORLD_MAXIMUM_Y = 20;
  const GAME_WORLD_MINIMUM_Z = 4;
  const GAME_WORLD_MAXIMUM_Z = 276;
  const GAME_MAXIMUM_TICK = 10000000;
  const GAME_MAXIMUM_HEALTH = 100;
  const GAME_MAXIMUM_STAMINA = 100;
  const GAME_MAXIMUM_AMMO = 99;
  const GAME_MAXIMUM_COMBO = 1000000;
  const GAME_MAXIMUM_VFX = 15;
  const GAME_VFX_LIQUID = 14;
  const GAME_MAXIMUM_ACTORS = 4;

  const root = document.getElementById("kof-root") || document.body;
  const panel = document.createElement("section");
  panel.id = "kookie-session-panel";
  panel.setAttribute("aria-labelledby", "kookie-session-heading");
  panel.style.cssText = [
    "margin-top:16px;padding:16px;border:1px solid #334155;border-radius:12px",
    "background:linear-gradient(145deg,#0b1720,#102532);color:#e2e8f0",
    "font-family:Pixand,sans-serif;display:flex;flex-direction:column;gap:12px",
    "width:calc(100% - 32px);max-width:980px;box-sizing:border-box",
  ].join(";");

  const style = document.createElement("style");
  style.textContent = `
    #kookie-session-panel * { box-sizing: border-box; }
    #kookie-session-panel button,
    #kookie-session-panel input,
    #kookie-session-panel select { font: inherit; }
    #kookie-session-panel button {
      min-height: 44px; padding: 10px 14px; border: 1px solid #475569;
      border-radius: 8px; background: #162a37; color: #f8fafc; cursor: pointer;
    }
    #kookie-session-panel canvas { display: block; width: 100%; min-height: 220px; aspect-ratio: 16 / 8; border: 1px solid #334155; border-radius: 8px; background: #050c12; }
    #kookie-session-panel .kookie-session-minimap { position: absolute; right: 12px; bottom: 12px; width: 180px; height: 120px; min-height: 0; aspect-ratio: auto; border-color: #7dd3fc; background: rgba(2, 12, 18, .92); }
    #kookie-session-panel .kookie-session-hud { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; align-content: start; }
    #kookie-session-panel .kookie-session-stat { padding: 10px; border: 1px solid #2a4351; border-radius: 8px; background: rgba(4, 15, 23, .72); }
    #kookie-session-panel .kookie-session-stat-label { display: block; color: #94a3b8; font-size: 11px; letter-spacing: .06em; }
    #kookie-session-panel .kookie-session-stat-value { display: block; margin-top: 4px; color: #f8fafc; font: 15px monospace; }
    #kookie-session-panel button:hover:not(:disabled) { background: #1f4659; border-color: #93c5fd; }
    #kookie-session-panel button:active:not(:disabled) { transform: translateY(1px); }
    #kookie-session-panel button:focus-visible,
    #kookie-session-panel input:focus-visible,
    #kookie-session-panel select:focus-visible,
    #kookie-session-panel summary:focus-visible { outline: 3px solid #facc15; outline-offset: 2px; }
    #kookie-session-panel button:disabled { cursor: not-allowed; opacity: .45; }
    #kookie-session-panel label { display: flex; flex-direction: column; gap: 5px; color: #cbd5e1; font-size: 12px; }
    #kookie-session-panel input,
    #kookie-session-panel select {
      min-height: 44px; padding: 9px 10px; border: 1px solid #475569; border-radius: 8px;
      background: #0a1b25; color: #f8fafc; font: 13px monospace;
    }
    #kookie-session-panel input[type="checkbox"] { min-height: 20px; width: 20px; accent-color: #38bdf8; }
    #kookie-session-panel .kookie-session-grid { display: grid; grid-template-columns: minmax(0, 1fr) 220px; gap: 12px; align-items: stretch; }
    #kookie-session-panel .kookie-session-canvas-wrap { min-width: 0; position: relative; }
    #kookie-session-panel .kookie-session-hud { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; align-content: start; }
    #kookie-session-panel .kookie-session-stat { padding: 10px; border: 1px solid #2a4351; border-radius: 8px; background: rgba(4, 15, 23, .72); }
    #kookie-session-panel .kookie-session-stat-label { display: block; color: #94a3b8; font-size: 11px; letter-spacing: .06em; }
    #kookie-session-panel .kookie-session-stat-value { display: block; margin-top: 4px; color: #f8fafc; font: 15px monospace; }
    #kookie-session-panel .kookie-session-help { color: #94a3b8; font-size: 12px; line-height: 1.4; }
    #kookie-session-panel .kookie-session-settings { border: 1px solid #2a4351; border-radius: 8px; padding: 8px 10px; background: rgba(4, 15, 23, .52); }
    #kookie-session-panel .kookie-session-settings summary { cursor: pointer; color: #bae6fd; font-size: 13px; font-weight: 700; }
    #kookie-session-panel .kookie-session-settings-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; margin-top: 10px; }
    #kookie-session-panel .kookie-session-setting { display: flex; flex-direction: row; align-items: center; gap: 8px; min-height: 44px; }
    #kookie-session-panel .kookie-session-runtime { color: #93c5fd; font: 12px monospace; }
    #kookie-session-panel .kookie-session-error { color: #fca5a5; }
    @media (max-width: 720px) {
      #kookie-session-panel { width: calc(100% - 20px); padding: 12px; }
      #kookie-session-panel .kookie-session-grid { grid-template-columns: 1fr; }
      #kookie-session-panel .kookie-session-settings-grid { grid-template-columns: 1fr; }
      #kookie-session-panel canvas { min-height: 180px; }
    }
    @media (prefers-reduced-motion: reduce) {
      #kookie-session-panel button { transition: none; }
    }
  `;
  document.head.appendChild(style);

  const heading = document.createElement("strong");
  heading.id = "kookie-session-heading";
  heading.textContent = "REMOTE SESSION / WEBGL2 CLIENT";
  heading.style.cssText = "font-family:'Jared Lite',Pixand,sans-serif;font-size:18px;color:#f8fafc";
  panel.appendChild(heading);

  const explanation = document.createElement("span");
  explanation.textContent =
    "The browser renders the bounded authoritative scene locally. Use ws:// for qualification; hosted sessions require WSS.";
  explanation.style.cssText = "font-size:13px;line-height:1.4;color:#cbd5e1";
  panel.appendChild(explanation);

  const endpointLabel = document.createElement("label");
  endpointLabel.textContent = "SESSION ENDPOINT";
  const endpoint = document.createElement("input");
  endpoint.type = "url";
  endpoint.value = new URLSearchParams(window.location.search).get("kookie_ws") ||
    "ws://127.0.0.1:8765/session";
  endpoint.setAttribute("aria-label", "WebSocket session endpoint");
  endpointLabel.appendChild(endpoint);
  panel.appendChild(endpointLabel);

  const tokenLabel = document.createElement("label");
  tokenLabel.textContent = "AUTHENTICATION TOKEN (OPTIONAL)";
  const authToken = document.createElement("input");
  authToken.type = "password";
  authToken.value = new URLSearchParams(window.location.search).get("kookie_token") || "";
  authToken.setAttribute("aria-label", "Session authentication token");
  authToken.setAttribute("autocomplete", "off");
  authToken.placeholder = "8-128 safe ASCII characters";
  tokenLabel.appendChild(authToken);
  panel.appendChild(tokenLabel);
  const SETTINGS_STORAGE_KEY = "kookie.browser.settings.v1";
  function readStoredSettings() {
    try {
      const value = JSON.parse(window.localStorage.getItem(SETTINGS_STORAGE_KEY) || "{}");
      return value && typeof value === "object" ? value : {};
    } catch (error) {
      return {};
    }
  }
  function saveStoredSettings() {
    try {
      window.localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(clientSettings));
    } catch (error) {
      // Storage is optional; the session remains usable in private contexts.
    }
  }
  const storedSettings = readStoredSettings();
  const clientSettings = {
    autoReconnect: storedSettings.autoReconnect !== false,
    reconnectDelayMs: [250, 500, 1000, 2000].includes(storedSettings.reconnectDelayMs)
      ? storedSettings.reconnectDelayMs : 500,
    showMinimap: storedSettings.showMinimap !== false,
    pointerLock: storedSettings.pointerLock !== false,
    reducedMotion: storedSettings.reducedMotion === true ||
      (typeof window.matchMedia === "function" &&
        window.matchMedia("(prefers-reduced-motion: reduce)").matches),
  };
  const settingsMenu = document.createElement("details");
  settingsMenu.className = "kookie-session-settings";
  const settingsSummary = document.createElement("summary");
  settingsSummary.textContent = "SESSION SETTINGS";
  settingsMenu.appendChild(settingsSummary);
  const settingsGrid = document.createElement("div");
  settingsGrid.className = "kookie-session-settings-grid";
  function addSettingToggle(key, labelText) {
    const label = document.createElement("label");
    label.className = "kookie-session-setting";
    const input = document.createElement("input");
    input.type = "checkbox";
    input.checked = clientSettings[key];
    input.setAttribute("aria-label", labelText);
    input.addEventListener("change", () => {
      clientSettings[key] = input.checked;
      saveStoredSettings();
      if (key === "showMinimap") setMinimapVisibility(input.checked);
      if (key === "reducedMotion") panel.dataset.reducedMotion = input.checked ? "true" : "false";
    });
    label.appendChild(input);
    label.appendChild(document.createTextNode(labelText));
    settingsGrid.appendChild(label);
  }
  addSettingToggle("autoReconnect", "Reconnect bounded sessions automatically");
  addSettingToggle("showMinimap", "Show arena minimap");
  addSettingToggle("pointerLock", "Capture pointer lock for mouse look");
  addSettingToggle("reducedMotion", "Reduce interface motion");
  const reconnectDelayLabel = document.createElement("label");
  reconnectDelayLabel.textContent = "RECONNECT DELAY";
  const reconnectDelay = document.createElement("select");
  reconnectDelay.setAttribute("aria-label", "Reconnect delay");
  for (const delay of [250, 500, 1000, 2000]) {
    const option = document.createElement("option");
    option.value = String(delay);
    option.textContent = delay + " ms";
    option.selected = delay === clientSettings.reconnectDelayMs;
    reconnectDelay.appendChild(option);
  }
  reconnectDelay.addEventListener("change", () => {
    clientSettings.reconnectDelayMs = Number(reconnectDelay.value);
    saveStoredSettings();
  });
  reconnectDelayLabel.appendChild(reconnectDelay);
  settingsGrid.appendChild(reconnectDelayLabel);
  settingsMenu.appendChild(settingsGrid);
  panel.appendChild(settingsMenu);

  const controls = document.createElement("div");
  controls.style.cssText = "display:flex;flex-wrap:wrap;gap:8px";
  panel.appendChild(controls);

  function createButton(label, disabled = false) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.disabled = disabled;
    controls.appendChild(button);
    return button;
  }

  const connectButton = createButton("CONNECT");
  const pingButton = createButton("PING", true);
  const gameButton = createButton("PROTOCOL ECHO", true);
  const healthButton = createButton("CHECK GATEWAY");
  const captureButton = createButton("CAPTURE SCREENSHOT");
  const gameControls = document.createElement("div");
  gameControls.style.cssText = "display:flex;flex-wrap:wrap;gap:8px";
  const gameActionButtons = [];
  function addGameAction(label, command, value) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.disabled = true;
    button.setAttribute("aria-label", label + " authoritative game action");
    button.addEventListener("click", () => sendGameCommand(command, value));
    gameActionButtons.push(button);
    gameControls.appendChild(button);
  }
  addGameAction("MOVE LEFT", GAME_MOVE_LEFT, -8);
  addGameAction("MOVE RIGHT", GAME_MOVE_RIGHT, 8);
  addGameAction("FORWARD", GAME_MOVE_FORWARD, 8);
  addGameAction("BACK", GAME_MOVE_BACK, -8);
  addGameAction("STRAFE LEFT", GAME_STRAFE_LEFT, -8);
  addGameAction("STRAFE RIGHT", GAME_STRAFE_RIGHT, 8);
  addGameAction("JUMP", GAME_JUMP, 0);
  addGameAction("FIRE", GAME_FIRE, 0);
  addGameAction("MELEE", GAME_MELEE, 0);
  addGameAction("SPECIAL", GAME_SPECIAL, 0);
  addGameAction("RESET", GAME_RESET, 0);
  panel.appendChild(gameControls);

  const remoteState = document.createElement("span");
  remoteState.id = "kookie-session-authoritative-state";
  remoteState.setAttribute("role", "status");
  remoteState.setAttribute("aria-live", "polite");
  remoteState.style.cssText = "font-size:13px;line-height:1.4;color:#cbd5e1";
  remoteState.textContent = "AUTHORITATIVE STATE / disconnected";
  panel.appendChild(remoteState);
  const runtimeState = document.createElement("span");
  runtimeState.className = "kookie-session-runtime";
  runtimeState.setAttribute("role", "status");
  runtimeState.setAttribute("aria-live", "polite");
  runtimeState.textContent = "RUNTIME / idle";
  panel.appendChild(runtimeState);

  const sceneGrid = document.createElement("div");
  sceneGrid.className = "kookie-session-grid";
  const sceneCanvasWrap = document.createElement("div");
  sceneCanvasWrap.className = "kookie-session-canvas-wrap";
  let sceneCanvas = document.createElement("canvas");
  sceneCanvas.id = "kookie-authoritative-scene";
  sceneCanvas.width = 960;
  sceneCanvas.height = 480;
  sceneCanvas.setAttribute("role", "img");
  sceneCanvas.setAttribute("tabindex", "0");
  sceneCanvas.setAttribute("aria-label", "Authoritative WebGL2 game scene");
  sceneCanvasWrap.appendChild(sceneCanvas);
  const labelOverlay = document.createElement("div");
  labelOverlay.id = "kookie-scene-labels";
  labelOverlay.setAttribute("aria-label", "Projected authoritative actor labels");
  labelOverlay.style.cssText = [
    "position:absolute;inset:0;pointer-events:none;overflow:hidden",
  ].join(";");
  sceneCanvasWrap.appendChild(labelOverlay);
  const minimapCanvas = document.createElement("canvas");
  minimapCanvas.className = "kookie-session-minimap";
  minimapCanvas.width = 360;
  minimapCanvas.height = 240;
  minimapCanvas.setAttribute("role", "img");
  minimapCanvas.setAttribute("aria-label", "Top-down authoritative arena minimap");
  function setMinimapVisibility(visible) {
    minimapCanvas.hidden = !visible;
    minimapCanvas.setAttribute("aria-hidden", visible ? "false" : "true");
  }
  setMinimapVisibility(clientSettings.showMinimap);
  sceneCanvasWrap.appendChild(minimapCanvas);
  sceneGrid.appendChild(sceneCanvasWrap);

  const hud = document.createElement("div");
  hud.className = "kookie-session-hud";
  const hudValues = {};
  function addHudStat(key, label, value) {
    const stat = document.createElement("div");
    stat.className = "kookie-session-stat";
    const statLabel = document.createElement("span");
    statLabel.className = "kookie-session-stat-label";
    statLabel.textContent = label;
    const statValue = document.createElement("span");
    statValue.className = "kookie-session-stat-value";
    statValue.textContent = value;
    stat.appendChild(statLabel);
    stat.appendChild(statValue);
    hud.appendChild(stat);
    hudValues[key] = statValue;
  }
  addHudStat("tick", "TICK", "0");
  addHudStat("position", "PLAYER X / Z", "32 / 52");
  addHudStat("health", "HEALTH", "100 / 100");
  addHudStat("stamina", "STAMINA", "100 / 100");
  addHudStat("ammo", "AMMO", "24");
  addHudStat("combo", "COMBO", "0");
  addHudStat("actors", "ACTORS", "4");
  addHudStat("projectiles", "PROJECTILES", "0");
  addHudStat("ping", "PING", "--");
  addHudStat("renderer", "RENDERER", "starting");
  sceneGrid.appendChild(hud);
  panel.appendChild(sceneGrid);

  const help = document.createElement("span");
  help.className = "kookie-session-help";
  help.textContent = "Keyboard: WASD / arrows move · Q/E look · Space jump · F fire · mouse look on canvas · M melee · X special · R reset. Focus a text field to keep its normal editing keys.";
  panel.appendChild(help);

  const status = document.createElement("span");
  status.id = "kookie-session-status";
  status.setAttribute("role", "status");
  status.setAttribute("aria-live", "polite");
  status.style.cssText = "font-size:13px;line-height:1.4;color:#fbbf24";
  panel.appendChild(status);
  root.appendChild(panel);

  function previewScene() {
    return {
      tick: 0,
      playerX: 32,
      playerY: 1,
      playerZ: 52,
      yaw: 0,
      pitch: -8,
      camera: { x: 32, y: 9, z: 36, yaw: 0, pitch: -8 },
      health: GAME_MAXIMUM_HEALTH,
      stamina: GAME_MAXIMUM_STAMINA,
      ammo: 24,
      combo: 0,
      vfx: 0,
      vfxEvent: null,
      actors: [
        { id: 1, x: 96, y: 1, z: 80, health: 100, state: 1, kind: 1 },
        { id: 2, x: 208, y: 1, z: 160, health: 100, state: 1, kind: 2 },
        { id: 3, x: 260, y: 1, z: 220, health: 100, state: 2, kind: 1 },
        { id: 4, x: 150, y: 1, z: 210, health: 100, state: 3, kind: 2 },
      ],
      labels: [
        { id: 1, textId: 1, x: 96, y: 1, z: 80, visible: true },
        { id: 2, textId: 2, x: 208, y: 1, z: 160, visible: true },
        { id: 3, textId: 3, x: 260, y: 1, z: 220, visible: true },
        { id: 4, textId: 4, x: 150, y: 1, z: 210, visible: true },
      ],
      projectiles: [],
      pickup: null,
    };
  }

  let sceneState = previewScene();
  let sceneRenderer = null;
  let renderFrameHandle = 0;

  let rendererFailureActive = false;
  function failRenderer(reason) {
    if (rendererFailureActive) return;
    rendererFailureActive = true;
    rendererInitializationError = reason;
    try {
      if (sceneRenderer && typeof sceneRenderer.destroy === "function") sceneRenderer.destroy();
    } catch (error) {
      // GPU cleanup failure cannot restore a valid 3D renderer.
    }
    sceneRenderer = null;
    captureButton.disabled = true;
    pingButton.disabled = true;
    gameButton.disabled = true;
    setGameControlsEnabled(false);
    hudValues.renderer.textContent = "WebGL2 unavailable";
    sceneCanvas.setAttribute("aria-label", "WebGL2 3D renderer unavailable");
    setRuntimeState("failed / WebGL2 3D renderer required", "#f87171");
    setStatus("3D RENDERER REQUIRED / " + reason, "#f87171");
  }

  let rendererInitializationError = "";
  try {
    if (!window.KookieWebRenderer ||
        typeof window.KookieWebRenderer.create !== "function") {
      throw new Error("WebGL2 renderer unavailable");
    }
    sceneRenderer = window.KookieWebRenderer.create(sceneCanvas);
    if (!sceneRenderer || !sceneRenderer.supported) {
      throw new Error(sceneRenderer?.reason || "WebGL2 unavailable");
    }
  } catch (error) {
    rendererInitializationError = error.message;
    sceneRenderer = null;
  }
  if (sceneRenderer) {
    hudValues.renderer.textContent = sceneRenderer.reason || "WebGL2";
    setRuntimeState("idle / preview WebGL2 renderer ready");
  } else {
    failRenderer(rendererInitializationError || "WebGL2 unavailable");
  }

  function annotateScreenshot(capture, renderer) {
    return Object.freeze({
      ...capture,
      renderer,
      authoritative: authoritativeReady,
      sceneSource: authoritativeReady ? "authoritative" : "preview",
      sceneTick: sceneState.tick,
    });
  }
  let lastScreenshot = null;
  function captureScreenshot() {
    if (!sceneRenderer || typeof sceneRenderer.captureScreenshot !== "function") {
      throw new Error("WebGL2 3D screenshot capture unavailable");
    }
    const renderer = typeof sceneRenderer.getStatus === "function"
      ? sceneRenderer.getStatus() : sceneRenderer.reason || "unavailable";
    lastScreenshot = annotateScreenshot(sceneRenderer.captureScreenshot(), renderer);
    const captureLabel = authoritativeReady
      ? "SCREENSHOT CAPTURED" : "PREVIEW SCREENSHOT CAPTURED";
    const captureColor = authoritativeReady ? "#4ade80" : "#fbbf24";
    setRuntimeState(
      (authoritativeReady ? "ready" : "preview") +
        " / screenshot " + lastScreenshot.width + "x" + lastScreenshot.height,
      captureColor,
    );
    setStatus(
      captureLabel + " / P6 / checksum=" + lastScreenshot.checksum,
      captureColor,
    );
    return lastScreenshot;
  }
  captureButton.addEventListener("click", () => {
    try {
      captureScreenshot();
    } catch (error) {
      setStatus("SCREENSHOT FAILED / " + error.message, "#f87171");
    }
  });
  window.KookieBrowserCapture = Object.freeze({
    captureScreenshot,
    getLastScreenshot: () => lastScreenshot,
    getRenderer: () => typeof sceneRenderer?.getStatus === "function"
      ? sceneRenderer.getStatus() : sceneRenderer?.reason || "unavailable",
  });



  function setStatus(value, color) {
    status.textContent = value;
    status.classList.toggle("kookie-session-error", Boolean(color === "#f87171"));
    status.style.color = color || "#fbbf24";
  }
  function setRuntimeState(value, color) {
    runtimeState.textContent = "RUNTIME / " + value;
    runtimeState.style.color = color || "#93c5fd";
  }

  const minimapContext = typeof minimapCanvas.getContext === "function"
    ? minimapCanvas.getContext("2d") : null;
  function drawMinimap(scene) {
    if (!minimapContext) return;
    const width = minimapCanvas.width;
    const height = minimapCanvas.height;
    const mapX = (x) => 8 + Math.max(0, Math.min(320, x)) * (width - 16) / 320;
    const mapZ = (z) => 8 + Math.max(0, Math.min(280, z)) * (height - 16) / 280;
    minimapContext.clearRect(0, 0, width, height);
    minimapContext.fillStyle = "#06151d";
    minimapContext.fillRect(0, 0, width, height);
    minimapContext.strokeStyle = "#24566b";
    minimapContext.strokeRect(8, 8, width - 16, height - 16);
    for (const actor of scene.actors) {
      if (actor.health <= 0) continue;
      minimapContext.fillStyle = actor.kind === 2 ? "#f59e0b" : "#ef5366";
      minimapContext.fillRect(mapX(actor.x) - 5, mapZ(actor.z) - 5, 10, 10);
    }
    if (scene.pickup) {
      minimapContext.fillStyle = "#4ade80";
      minimapContext.fillRect(mapX(scene.pickup.x) - 4, mapZ(scene.pickup.z) - 4, 8, 8);
    }
    minimapContext.fillStyle = "#60a5fa";
    minimapContext.beginPath();
    minimapContext.arc(mapX(scene.playerX), mapZ(scene.playerZ), 7, 0, Math.PI * 2);
    minimapContext.fill();
    minimapContext.fillStyle = "#facc15";
    for (const projectile of scene.projectiles) {
      minimapContext.fillRect(mapX(projectile.x) - 3, mapZ(projectile.z) - 3, 6, 6);
    }
  }

  function updateProjectedLabels(scene) {
    if (typeof labelOverlay.replaceChildren === "function") {
      labelOverlay.replaceChildren();
    } else {
      labelOverlay.children.length = 0;
    }
    const bounds = typeof labelOverlay.getBoundingClientRect === "function"
      ? labelOverlay.getBoundingClientRect()
      : { width: sceneCanvas.width, height: sceneCanvas.height };
    for (const label of scene.labels || []) {
      if (!label.visible) continue;
      const projection = sceneRenderer?.projectWorld?.(
        scene, label.x, label.y + 8, label.z,
      );
      if (!projection || projection.x < 0 || projection.x > 1 ||
          projection.y < 0 || projection.y > 1) continue;
      const element = document.createElement("span");
      element.className = "kookie-scene-label";
      element.textContent = SCENE_LABEL_TEXT[label.textId] || "ACTOR";
      element.setAttribute("aria-label", element.textContent);
      element.style.cssText = [
        "position:absolute;transform:translate(-50%,-100%)",
        "padding:2px 5px;border-radius:4px",
        "background:rgba(4,15,23,.82);color:#f8fafc",
        "font:600 11px/1.2 monospace;white-space:nowrap",
        "text-shadow:0 1px 2px #000",
        `left:${projection.x * bounds.width}px`,
        `top:${projection.y * bounds.height}px`,
      ].join(";");
      labelOverlay.appendChild(element);
    }
  }

  function updateScene(scene) {
    sceneState = scene;
    updateProjectedLabels(scene);
    drawMinimap(scene);
    hudValues.tick.textContent = String(scene.tick);
    hudValues.position.textContent = scene.playerX + " / " + scene.playerZ;
    hudValues.health.textContent = scene.health + " / 100";
    hudValues.stamina.textContent = scene.stamina + " / 100";
    hudValues.ammo.textContent = String(scene.ammo);
    hudValues.combo.textContent = String(scene.combo);
    hudValues.actors.textContent = String(
      scene.actors.filter((actor) => actor.health > 0).length
    );
    hudValues.projectiles.textContent = String(scene.projectiles.length);
    remoteState.textContent = "AUTHORITATIVE STATE / tick=" + scene.tick +
      " position=" + scene.playerX + "," + scene.playerZ +
      " health=" + scene.health + " stamina=" + scene.stamina +
      " ammo=" + scene.ammo + " combo=" + scene.combo +
      " actors=" + scene.actors.length +
      " projectiles=" + scene.projectiles.length;
    sceneCanvas.setAttribute(
      "aria-label",
      "Authoritative WebGL2 scene tick " + scene.tick +
        ", player position " + scene.playerX + "," + scene.playerZ +
        ", health " + scene.health + ", stamina " + scene.stamina +
        ", ammo " + scene.ammo + ", " + scene.actors.length + " actors"
    );
  }

  function renderFrame(time) {
    if (!sceneRenderer) return;
    try {
      sceneRenderer.render(sceneState, time);
      if (typeof sceneRenderer.getStatus === "function") {
        const rendererStatus = sceneRenderer.getStatus();
        if (hudValues.renderer.textContent !== rendererStatus) {
          hudValues.renderer.textContent = rendererStatus;
        }
        if (rendererStatus.includes("context lost")) {
          failRenderer("WebGL context lost");
        }
      }
    } catch (error) {
      failRenderer(error.message || "WebGL render failure");
    }
    if (sceneRenderer) renderFrameHandle = window.requestAnimationFrame(renderFrame);
  }
  updateScene(sceneState);
  if (sceneRenderer) renderFrameHandle = window.requestAnimationFrame(renderFrame);

  function validAuthToken(value) {
    return value.length >= AUTH_TOKEN_MINIMUM_LENGTH &&
      value.length <= AUTH_TOKEN_MAXIMUM_LENGTH &&
      [...value].every((character) => /^[A-Za-z0-9._~-]$/.test(character));
  }

  async function checkGateway() {
    let url;
    try {
      url = new URL(endpoint.value.trim(), window.location.href);
      if (url.protocol !== "ws:" && url.protocol !== "wss:") {
        throw new Error("endpoint must use ws:// or wss://");
      }
      url.protocol = url.protocol === "wss:" ? "https:" : "http:";
      url.pathname = "/healthz";
      url.search = "";
      url.hash = "";
      const response = await fetch(url.href, { headers: { Accept: "application/json" } });
      if (!response.ok) throw new Error("health HTTP " + response.status);
      const health = await response.json();
      if (health.status !== "ok") throw new Error("gateway is not ready");
      setStatus(
        "HEALTH / " + health.transport + " / auth=" +
          (health.auth_required ? "required" : "open") +
          " / sessions=" + health.active_sessions,
        "#4ade80",
      );
    } catch (error) {
      setStatus("HEALTH REJECTED / " + error.message, "#f87171");
    }
  }

  let socket = null;
  let sequence = 0;
  let connected = false;
  let authoritativeReady = false;
  let pingSentAt = 0;
  let reconnectTimer = null;
  let reconnectAttempt = 0;
  let shuttingDown = false;
  let intentionalDisconnect = false;
  const MAX_RECONNECT_ATTEMPTS = 5;
  function setGameControlsEnabled(enabled) {
    for (const button of gameActionButtons) button.disabled = !enabled;
  }
  function clearReconnectTimer() {
    if (reconnectTimer !== null) window.clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  function nextSequence() {
    sequence += 1;
    if (sequence > MAX_SEQUENCE) sequence = 1;
    return sequence;
  }

  function checksumMix(state, value) {
    let normalized = value % 1000003;
    if (normalized < 0) normalized += 1000003;
    return (state * 31 + normalized) % 1000003;
  }

  function messageChecksum(words) {
    let result = 53;
    for (const value of words) result = checksumMix(result, value);
    return result;
  }

  function wireChecksum(bytes) {
    let result = 0;
    for (let index = 0; index < bytes.length; index += 1) {
      const value = index === 14 || index === 15 ? 0 : bytes[index];
      result = (result + value * (index + 1)) % 65536;
    }
    return result;
  }

  function validateWords(kind, frameSequence, words) {
    if (words.length < 3 || words[0] !== NETCODE_PROTOCOL_VERSION ||
        words[1] !== kind || words[2] !== frameSequence) return false;
    if (kind === ACK) {
      return words.length === 7 && (words[3] === 0 || words[3] === 1) &&
        words[4] === GAME_WEBSOCKET && words[5] === SERVER_CAPABILITY &&
        words[6] === messageChecksum(words.slice(0, 6));
    }
    if (kind === PONG) {
      return words.length === 4 && words[3] === messageChecksum(words.slice(0, 3));
    }
    if (kind === GAME) {
      if (words.length === 5) {
        return words[3] === GAME_PROBE_PAYLOAD &&
          words[4] === messageChecksum(words.slice(0, 4));
      }
      if (words.length === 7) {
        const validCommand = words[3] === GAME_COMMAND_MARKER &&
          ((words[4] === GAME_MOVE_LEFT && words[5] === -8) ||
            (words[4] === GAME_MOVE_RIGHT && words[5] === 8) ||
            (words[4] === GAME_MOVE_BACK && words[5] === -8) ||
            (words[4] === GAME_MOVE_FORWARD && words[5] === 8) ||
            (words[4] === GAME_STRAFE_LEFT && words[5] === -8) ||
            (words[4] === GAME_STRAFE_RIGHT && words[5] === 8) ||
            (words[4] === GAME_LOOK_LEFT && words[5] === -15) ||
            (words[4] === GAME_LOOK_RIGHT && words[5] === 15) ||
            (words[4] >= GAME_MELEE && words[4] <= GAME_JUMP &&
              words[5] === 0));
        return validCommand && words[6] === messageChecksum(words.slice(0, 6));
      }
      if (words.length === 11) {
        return words[3] === GAME_SNAPSHOT_MARKER &&
          words[4] >= 0 && words[4] <= GAME_MAXIMUM_TICK &&
          words[5] >= GAME_MINIMUM_POSITION && words[5] <= GAME_MAXIMUM_POSITION &&
          words[6] >= 0 && words[6] <= GAME_MAXIMUM_HEALTH &&
          words[7] >= 0 && words[7] <= GAME_MAXIMUM_STAMINA &&
          words[8] >= 0 && words[8] <= GAME_MAXIMUM_COMBO &&
          words[9] >= 0 && words[9] <= GAME_MAXIMUM_VFX &&
          words[10] === messageChecksum(words.slice(0, 10));
      }
      if (words.length === 30) {
        return words[3] === GAME_SCENE_SNAPSHOT_MARKER &&
          words[4] >= 0 && words[4] <= GAME_MAXIMUM_TICK &&
          words[5] >= GAME_MINIMUM_POSITION && words[5] <= GAME_MAXIMUM_POSITION &&
          words[6] >= GAME_MINIMUM_DEPTH && words[6] <= GAME_MAXIMUM_DEPTH &&
          words[8] >= 0 && words[8] <= GAME_MAXIMUM_HEALTH &&
          words[9] >= 0 && words[9] <= GAME_MAXIMUM_STAMINA &&
          words[10] >= 0 && words[10] <= GAME_MAXIMUM_COMBO &&
          words[11] >= 0 && words[11] <= GAME_MAXIMUM_VFX &&
          words[12] === 3 &&
          [16, 20, 24].every((index) => words[index] >= 0 && words[index] <= GAME_MAXIMUM_HEALTH) &&
          words[25] >= 0 && words[25] <= 1 &&
          words[26] >= GAME_MINIMUM_POSITION && words[26] <= GAME_MAXIMUM_POSITION &&
          words[27] >= GAME_MINIMUM_DEPTH && words[27] <= GAME_MAXIMUM_DEPTH &&
          words[28] >= 0 && words[28] <= 6 &&
          words[29] === messageChecksum(words.slice(0, 29));
      }
      if (words.length >= 70) {
        const actorXIndices = [22, 30, 38, 46];
        const actorYIndices = [23, 31, 39, 47];
        const actorZIndices = [24, 32, 40, 48];
        const actorHealthIndices = [25, 33, 41, 49];
        const actorStateIndices = [26, 34, 42, 50];
        const actorKindIndices = [27, 35, 43, 51];
        const actorYawIndices = [28, 36, 44, 52];
        const projectileValid = words[54] === 0
          ? [55, 56, 57, 58].every((index) => words[index] === 0)
          : words[54] === 1 &&
            words[55] >= GAME_WORLD_MINIMUM_X && words[55] <= GAME_WORLD_MAXIMUM_X &&
            words[56] >= GAME_WORLD_MINIMUM_Y && words[56] <= GAME_WORLD_MAXIMUM_Y &&
            words[57] >= GAME_WORLD_MINIMUM_Z && words[57] <= GAME_WORLD_MAXIMUM_Z &&
            words[58] >= 1 && words[58] <= 10;
        if (!(words[3] === GAME_FULL_SCENE_SNAPSHOT_MARKER &&
            words[4] >= 0 && words[4] <= GAME_MAXIMUM_TICK &&
            words[5] >= GAME_WORLD_MINIMUM_X && words[5] <= GAME_WORLD_MAXIMUM_X &&
            words[6] >= GAME_WORLD_MINIMUM_Y && words[6] <= GAME_WORLD_MAXIMUM_Y &&
            words[7] >= GAME_WORLD_MINIMUM_Z && words[7] <= GAME_WORLD_MAXIMUM_Z &&
            words[8] >= 0 && words[8] <= 359 &&
            words[9] >= -90 && words[9] <= 90 &&
            words[10] >= 0 && words[10] <= GAME_MAXIMUM_HEALTH &&
            words[11] >= 0 && words[11] <= GAME_MAXIMUM_STAMINA &&
            words[12] >= 0 && words[12] <= GAME_MAXIMUM_AMMO &&
            words[13] >= 0 && words[13] <= GAME_MAXIMUM_COMBO &&
            words[14] >= 0 && words[14] <= GAME_MAXIMUM_VFX &&
            words[20] === GAME_MAXIMUM_ACTORS &&
            actorXIndices.every((index) => words[index] >= GAME_WORLD_MINIMUM_X &&
              words[index] <= GAME_WORLD_MAXIMUM_X) &&
            actorYIndices.every((index) => words[index] >= GAME_WORLD_MINIMUM_Y &&
              words[index] <= GAME_WORLD_MAXIMUM_Y) &&
            actorZIndices.every((index) => words[index] >= GAME_WORLD_MINIMUM_Z &&
              words[index] <= GAME_WORLD_MAXIMUM_Z) &&
            actorHealthIndices.every((index) => words[index] >= 0 &&
              words[index] <= GAME_MAXIMUM_HEALTH) &&
            actorStateIndices.every((index) => words[index] >= 1 && words[index] <= 4) &&
            actorKindIndices.every((index) => words[index] >= 1 && words[index] <= 2) &&
            actorYawIndices.every((index) => words[index] >= 0 && words[index] <= 359) &&
            words[53] >= 0 && words[53] <= 1 && projectileValid &&
            words[59] >= 0 && words[59] <= 1 &&
            words[60] >= 0 && words[60] <= 6 &&
            words[61] >= GAME_WORLD_MINIMUM_X && words[61] <= GAME_WORLD_MAXIMUM_X &&
            words[62] >= GAME_WORLD_MINIMUM_Y && words[62] <= GAME_WORLD_MAXIMUM_Y &&
            words[63] >= GAME_WORLD_MINIMUM_Z && words[63] <= GAME_WORLD_MAXIMUM_Z &&
            words[64] >= GAME_WORLD_MINIMUM_X && words[64] <= GAME_WORLD_MAXIMUM_X &&
            words[65] >= GAME_WORLD_MINIMUM_Y && words[65] <= GAME_WORLD_MAXIMUM_Y &&
            words[66] >= GAME_WORLD_MINIMUM_Z && words[66] <= GAME_WORLD_MAXIMUM_Z &&
            words[67] >= 1 && words[67] <= 4)) {
          return false;
        }
        const objectCount = words[68];
        if (!Number.isInteger(objectCount) || objectCount < 0 ||
            objectCount > MAX_SCENE_OBJECTS) {
          return false;
        }
        const labelsOffset = SCENE_OBJECTS_OFFSET +
          objectCount * SCENE_OBJECT_ENTRY_WIDTH;
        if (labelsOffset >= words.length) return false;
        const labelCount = words[labelsOffset];
        if (!Number.isInteger(labelCount) || labelCount < 0 ||
            labelCount > MAX_SCENE_LABELS ||
            words.length !== labelsOffset + 1 +
              labelCount * SCENE_LABEL_ENTRY_WIDTH + 1) {
          return false;
        }
        for (let index = 0; index < objectCount; index += 1) {
          const offset = SCENE_OBJECTS_OFFSET + index * SCENE_OBJECT_ENTRY_WIDTH;
          const kind = words[offset];
          const state = words[offset + 2];
          if (kind < SCENE_OBJECT_DOOR || kind > SCENE_OBJECT_LOOT_BEAM ||
              words[offset + 1] <= 0 ||
              words[offset + 3] < GAME_WORLD_MINIMUM_X ||
              words[offset + 3] > GAME_WORLD_MAXIMUM_X ||
              words[offset + 4] < GAME_WORLD_MINIMUM_Y ||
              words[offset + 4] > GAME_WORLD_MAXIMUM_Y ||
              words[offset + 5] < GAME_WORLD_MINIMUM_Z ||
              words[offset + 5] > GAME_WORLD_MAXIMUM_Z ||
              words[offset + 6] <= 0 || words[offset + 6] > 32 ||
              words[offset + 7] <= 0 || words[offset + 7] > 32 ||
              words[offset + 8] <= 0 || words[offset + 8] > 32 ||
              (kind === SCENE_OBJECT_LOOT_BEAM
                ? state < 1 || state > 3 : state < 0 || state > 1)) {
            return false;
          }
        }
        for (let index = 0; index < labelCount; index += 1) {
          const offset = labelsOffset + 1 + index * SCENE_LABEL_ENTRY_WIDTH;
          if (words[offset] <= 0 || words[offset + 1] < 1 ||
              words[offset + 1] > 4 ||
              words[offset + 2] < GAME_WORLD_MINIMUM_X ||
              words[offset + 2] > GAME_WORLD_MAXIMUM_X ||
              words[offset + 3] < GAME_WORLD_MINIMUM_Y ||
              words[offset + 3] > GAME_WORLD_MAXIMUM_Y ||
              words[offset + 4] < GAME_WORLD_MINIMUM_Z ||
              words[offset + 4] > GAME_WORLD_MAXIMUM_Z ||
              words[offset + 5] < 0 || words[offset + 5] > 1) {
            return false;
          }
        }
        return words[words.length - 1] ===
          messageChecksum(words.slice(0, -1));
      }
    }
    if (kind === ERROR) {
      return words.length === 5 && words[3] > 0 &&
        words[4] === messageChecksum(words.slice(0, 4));
    }
    return false;
  }

  function encodeFrame(kind, frameSequence, words) {
    if (words.length === 0 || words.length > MAX_WORDS ||
        words[0] !== NETCODE_PROTOCOL_VERSION || words[1] !== kind ||
        words[2] !== frameSequence) throw new Error("invalid session message");
    const buffer = new ArrayBuffer(16 + words.length * 4);
    const bytes = new Uint8Array(buffer);
    const view = new DataView(buffer);
    MAGIC.forEach((value, index) => { bytes[index] = value; });
    bytes[4] = FRAME_VERSION;
    bytes[5] = kind;
    view.setUint32(8, frameSequence, false);
    view.setUint16(12, words.length, false);
    view.setUint16(14, 0, false);
    words.forEach((value, index) => view.setInt32(16 + index * 4, value, false));
    view.setUint16(14, wireChecksum(bytes), false);
    if (buffer.byteLength > MAX_FRAME_BYTES) throw new Error("frame too large");
    return buffer;
  }

  function decodeFrame(input) {
    const bytes = new Uint8Array(input);
    if (bytes.length < 16 || bytes.length > MAX_FRAME_BYTES ||
        !MAGIC.every((value, index) => bytes[index] === value) ||
        bytes[4] !== FRAME_VERSION || bytes[6] !== 0 || bytes[7] !== 0) {
      throw new Error("session frame header rejected");
    }
    const view = new DataView(input);
    const frameKind = bytes[5];
    const frameSequence = view.getUint32(8, false);
    const wordCount = view.getUint16(12, false);
    const expectedChecksum = view.getUint16(14, false);
    if (frameSequence <= 0 || frameSequence > MAX_SEQUENCE ||
        wordCount <= 0 || wordCount > MAX_WORDS ||
        bytes.length !== 16 + wordCount * 4 || wireChecksum(bytes) !== expectedChecksum) {
      throw new Error("session frame bounds or checksum rejected");
    }
    const words = [];
    for (let index = 0; index < wordCount; index += 1) {
      words.push(view.getInt32(16 + index * 4, false));
    }
    if (!validateWords(frameKind, frameSequence, words)) throw new Error("session message rejected");
    return { kind: frameKind, sequence: frameSequence, words };
  }

  function sendHello() {
    const helloSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, HELLO, helloSequence,
      CLIENT_TARGET_BROWSER, AUTHORITY_REMOTE, GAME_WEBSOCKET, BROWSER_CAPABILITY];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(HELLO, helloSequence, words));
    setRuntimeState("handshaking");
    setStatus("CONNECTING / HELLO sequence=" + helloSequence);
  }

  function sendPing() {
    if (!socket || socket.readyState !== WebSocket.OPEN || !connected) return;
    const pingSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, PING, pingSequence];
    words.push(messageChecksum(words));
    pingSentAt = performance.now();
    socket.send(encodeFrame(PING, pingSequence, words));
    setStatus("PING SENT sequence=" + pingSequence, "#93c5fd");
  }

  function sendGameProbe() {
    if (!socket || socket.readyState !== WebSocket.OPEN || !connected) return;
    const gameSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, gameSequence, GAME_PROBE_PAYLOAD];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, gameSequence, words));
    setStatus("PROTOCOL ECHO SENT sequence=" + gameSequence, "#93c5fd");
  }

  function sendSceneProbe() {
    if (!socket || socket.readyState !== WebSocket.OPEN || !connected) return;
    const gameSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, gameSequence,
      GAME_COMMAND_MARKER, GAME_FULL_SCENE_PROBE, 0];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, gameSequence, words));
    setRuntimeState("loading authoritative scene");
    setStatus("FULL SCENE STREAM REQUESTED sequence=" + gameSequence, "#93c5fd");
  }

  function sendGameCommand(command, value) {
    if (!sceneRenderer || !socket || socket.readyState !== WebSocket.OPEN ||
        !authoritativeReady) return;
    const gameSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, gameSequence,
      GAME_COMMAND_MARKER, command, value];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, gameSequence, words));
    setStatus("COMMAND SENT sequence=" + gameSequence, "#93c5fd");
  }

  function parseScene(words) {
    const actors = [];
    for (let index = 0; index < GAME_MAXIMUM_ACTORS; index += 1) {
      const offset = 21 + index * 8;
      actors.push({
        id: words[offset],
        x: words[offset + 1],
        y: words[offset + 2],
        z: words[offset + 3],
        health: words[offset + 4],
        state: words[offset + 5],
        kind: words[offset + 6],
        yaw: words[offset + 7],
      });
    }
    const projectiles = words[54] === 1
      ? [{ x: words[55], y: words[56], z: words[57], ttl: words[58] }]
      : [];
    const pickup = words[59] === 1
      ? { kind: words[60], x: words[61], y: words[62], z: words[63] }
      : null;
    const sceneObjects = [];
    for (let index = 0; index < words[68]; index += 1) {
      const offset = SCENE_OBJECTS_OFFSET + index * SCENE_OBJECT_ENTRY_WIDTH;
      sceneObjects.push({
        kind: words[offset],
        id: words[offset + 1],
        state: words[offset + 2],
        x: words[offset + 3],
        y: words[offset + 4],
        z: words[offset + 5],
        sizeX: words[offset + 6],
        sizeY: words[offset + 7],
        sizeZ: words[offset + 8],
      });
    }
    const labels = [];
    const labelsOffset = SCENE_OBJECTS_OFFSET +
      words[68] * SCENE_OBJECT_ENTRY_WIDTH;
    for (let index = 0; index < words[labelsOffset]; index += 1) {
      const offset = labelsOffset + 1 + index * SCENE_LABEL_ENTRY_WIDTH;
      labels.push({
        id: words[offset],
        textId: words[offset + 1],
        x: words[offset + 2],
        y: words[offset + 3],
        z: words[offset + 4],
        visible: words[offset + 5] === 1,
      });
    }
    return {
      tick: words[4],
      playerX: words[5],
      playerY: words[6],
      playerZ: words[7],
      playerState: words[67],
      yaw: words[8],
      pitch: words[9],
      health: words[10],
      stamina: words[11],
      ammo: words[12],
      combo: words[13],
      vfx: words[14],
      vfxEvent: words[14] > 0
        ? {
          style: words[14],
          assetId: words[14] === GAME_VFX_LIQUID ? 0
            : words[14] > 2 ? words[14] : undefined,
          x: words[64], y: words[65], z: words[66], tick: words[4],
        }
        : null,
      camera: { x: words[15], y: words[16], z: words[17], yaw: words[18], pitch: words[19] },
      actors,
      projectiles,
      pickup,
      sceneObjects,
      labels,
    };
  }

  function parseLegacyScene(words) {
    const actors = [];
    for (let index = 0; index < 3; index += 1) {
      const offset = 13 + index * 4;
      actors.push({
        id: words[offset], x: words[offset + 1], y: 1,
        z: words[offset + 2], health: words[offset + 3], state: 1, kind: 1,
      });
    }
    const projectiles = words[25] === 1
      ? [{ x: words[26], y: 1, z: words[27], ttl: words[28] }]
      : [];
    return {
      tick: words[4], playerX: words[5], playerY: 1, playerZ: words[6],
      yaw: words[7], pitch: 0, health: words[8], stamina: words[9],
      ammo: 0, combo: words[10], vfx: words[11],
      camera: { x: words[5], y: 9, z: words[6] - 16, yaw: words[7], pitch: 0 },
      actors, projectiles, pickup: null,
    };
  }

  function disconnect(explicit = true) {
    const activeSocket = socket;
    socket = null;
    connected = false;
    authoritativeReady = false;
    intentionalDisconnect = explicit;
    if (explicit) {
      clearReconnectTimer();
      reconnectAttempt = 0;
    }
    connectButton.textContent = "CONNECT";
    pingButton.disabled = true;
    gameButton.disabled = true;
    setGameControlsEnabled(false);
    remoteState.textContent = "AUTHORITATIVE STATE / disconnected";
    if (rendererFailureActive) {
      setRuntimeState("failed / WebGL2 3D renderer required", "#f87171");
      setStatus(
        "3D RENDERER REQUIRED / " +
          (rendererInitializationError || "WebGL2 renderer unavailable"),
        "#f87171",
      );
    } else {
      setRuntimeState(explicit ? "idle / disconnected" : "disconnected");
      if (explicit) setStatus("IDLE / disconnected");
    }
  }

  function scheduleReconnect(reason) {
    if (shuttingDown || intentionalDisconnect || !clientSettings.autoReconnect) {
      setRuntimeState("offline / reconnect disabled", "#fbbf24");
      return;
    }
    if (reconnectAttempt >= MAX_RECONNECT_ATTEMPTS) {
      setRuntimeState("failed / retry limit reached", "#f87171");
      setStatus("CLOSED / reconnect limit reached", "#f87171");
      return;
    }
    clearReconnectTimer();
    reconnectAttempt += 1;
    const delay = clientSettings.reconnectDelayMs * reconnectAttempt;
    setRuntimeState("reconnecting " + reconnectAttempt + "/" + MAX_RECONNECT_ATTEMPTS);
    setStatus("RECONNECTING / " + reason + " in " + delay + " ms", "#fbbf24");
    reconnectTimer = window.setTimeout(() => {
      reconnectTimer = null;
      connect(true);
    }, delay);
  }

  function connect(isReconnect = false) {
    if (!sceneRenderer) {
      failRenderer(rendererInitializationError || "WebGL2 unavailable");
      return;
    }
    clearReconnectTimer();
    intentionalDisconnect = false;
    if (!isReconnect) reconnectAttempt = 0;
    disconnect(false);
    intentionalDisconnect = false;
    let url;
    let token = "";
    try {
      url = new URL(endpoint.value.trim(), window.location.href);
      if (url.protocol !== "ws:" && url.protocol !== "wss:") {
        throw new Error("endpoint must use ws:// or wss://");
      }
      if (url.pathname === "/" || url.pathname === "") url.pathname = "/session";
      token = authToken.value.trim();
      if (token && !validAuthToken(token)) {
        throw new Error("session token must be 8-128 safe ASCII characters");
      }
    } catch (error) {
      intentionalDisconnect = true;
      setRuntimeState("rejected / invalid endpoint", "#f87171");
      setStatus("REJECTED / " + error.message, "#f87171");
      return;
    }
    const protocols = [WEBSOCKET_SUBPROTOCOL];
    if (token) protocols.push(AUTH_SUBPROTOCOL_PREFIX + token);
    try {
      socket = new WebSocket(url.href, protocols);
    } catch (error) {
      setRuntimeState("failed / WebSocket constructor", "#f87171");
      setStatus("REJECTED / " + error.message, "#f87171");
      scheduleReconnect("constructor failure");
      return;
    }
    const clientSocket = socket;
    socket.binaryType = "arraybuffer";
    connectButton.textContent = "DISCONNECT";
    connectButton.disabled = false;
    setRuntimeState(isReconnect ? "reconnecting / connecting" : "connecting");
    clientSocket.onopen = sendHello;
    clientSocket.onmessage = async (event) => {
      if (socket !== clientSocket) return;
      try {
        const data = event.data instanceof ArrayBuffer
          ? event.data : await event.data.arrayBuffer();
        const frame = decodeFrame(data);
        if (frame.kind === ACK && frame.words[3] === 1) {
          connected = true;
          authoritativeReady = false;
          reconnectAttempt = 0;
          pingButton.disabled = false;
          gameButton.disabled = false;
          setGameControlsEnabled(false);
          setRuntimeState("connected / loading authoritative scene", "#4ade80");
          setStatus("CONNECTED / requesting authoritative 3D scene", "#4ade80");
          sendSceneProbe();
        } else if (frame.kind === PONG) {
          const latency = pingSentAt > 0
            ? Math.round(performance.now() - pingSentAt) : 0;
          hudValues.ping.textContent = latency + " ms";
          setRuntimeState("ready / heartbeat " + latency + " ms", "#4ade80");
          setStatus("PONG sequence=" + frame.sequence + " / " + latency + " ms", "#4ade80");
        } else if (frame.kind === GAME) {
          if (frame.words[3] === GAME_PROBE_PAYLOAD) {
            setStatus("PROTOCOL ECHO RECEIVED sequence=" + frame.sequence, "#4ade80");
          } else if (frame.words[3] === GAME_SNAPSHOT_MARKER) {
            authoritativeReady = true;
            setGameControlsEnabled(true);
            updateScene({
              ...sceneState,
              tick: frame.words[4], playerX: frame.words[5], health: frame.words[6],
              stamina: frame.words[7], combo: frame.words[8], vfx: frame.words[9],
            });
            setRuntimeState("ready / legacy snapshot", "#4ade80");
            setStatus("LEGACY STATE RECEIVED sequence=" + frame.sequence, "#4ade80");
          } else if (frame.words[3] === GAME_FULL_SCENE_SNAPSHOT_MARKER) {
            authoritativeReady = true;
            setGameControlsEnabled(true);
            updateScene(parseScene(frame.words));
            setRuntimeState("ready / authoritative scene", "#4ade80");
            setStatus("AUTHORITATIVE 3D SCENE RECEIVED sequence=" + frame.sequence, "#4ade80");
          } else if (frame.words[3] === GAME_SCENE_SNAPSHOT_MARKER) {
            authoritativeReady = true;
            setGameControlsEnabled(true);
            updateScene(parseLegacyScene(frame.words));
            setRuntimeState("ready / legacy scene", "#4ade80");
            setStatus("LEGACY SCENE RECEIVED sequence=" + frame.sequence, "#4ade80");
          } else {
            throw new Error("unexpected game response");
          }
        } else if (frame.kind === ERROR) {
          throw new Error("gateway diagnostic=" + frame.words[3]);
        }
      } catch (error) {
        setRuntimeState("failed / protocol rejection", "#f87171");
        setStatus("REJECTED / " + error.message, "#f87171");
        disconnect(false);
        scheduleReconnect("protocol rejection");
      }
    };
    clientSocket.onerror = () => {
      setRuntimeState("failed / WebSocket unavailable", "#f87171");
      setStatus("ERROR / WebSocket unavailable", "#f87171");
    };
    clientSocket.onclose = () => {
      if (socket !== clientSocket) return;
      const wasReady = authoritativeReady;
      socket = null;
      connected = false;
      authoritativeReady = false;
      pingButton.disabled = true;
      gameButton.disabled = true;
      setGameControlsEnabled(false);
      remoteState.textContent = "AUTHORITATIVE STATE / disconnected";
      connectButton.textContent = "CONNECT";
      if (rendererFailureActive) {
        failRenderer(rendererInitializationError || "WebGL2 renderer unavailable");
        return;
      }
      if (intentionalDisconnect || shuttingDown) {
        setRuntimeState("idle / disconnected");
        return;
      }
      scheduleReconnect(wasReady ? "authoritative session lost" : "admission failed");
    };
  }

  connectButton.addEventListener("click", () => {
    if (connected || (socket && socket.readyState === WebSocket.CONNECTING)) {
      disconnect();
    } else {
      connect();
    }
  });
  pingButton.addEventListener("click", sendPing);
  gameButton.addEventListener("click", sendGameProbe);
  healthButton.addEventListener("click", checkGateway);
  if (new URLSearchParams(window.location.search).get("kookie_autoconnect") === "1") {
    connect();
  }

  document.addEventListener("keydown", (event) => {
    if (!authoritativeReady || event.ctrlKey || event.metaKey || event.altKey) return;
    const target = event.target;
    if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable)) return;
    let command = null;
    let value = 0;
    if (event.key === "a" || event.key === "A" || event.key === "ArrowLeft") {
      command = GAME_STRAFE_LEFT;
      value = -8;
    } else if (event.key === "d" || event.key === "D" || event.key === "ArrowRight") {
      command = GAME_STRAFE_RIGHT;
      value = 8;
    } else if (event.key === "w" || event.key === "W" || event.key === "ArrowUp") {
      command = GAME_MOVE_FORWARD;
      value = 8;
    } else if (event.key === "s" || event.key === "S" || event.key === "ArrowDown") {
      command = GAME_MOVE_BACK;
      value = -8;
    } else if (event.key === "q" || event.key === "Q") {
      command = GAME_LOOK_LEFT;
      value = -15;
    } else if (event.key === "e" || event.key === "E") {
      command = GAME_LOOK_RIGHT;
      value = 15;
    } else if (event.key === " ") {
      command = GAME_JUMP;
    } else if (event.key === "f" || event.key === "F") {
      command = GAME_FIRE;
    } else if (event.key === "m" || event.key === "M") {
      command = GAME_MELEE;
    } else if (event.key === "x" || event.key === "X") {
      command = GAME_SPECIAL;
    } else if (event.key === "r" || event.key === "R") {
      command = GAME_RESET;
    }

    if (command !== null) {
      event.preventDefault();
      sendGameCommand(command, value);
    }
  });
  function bindSceneInput() {
    sceneCanvas.addEventListener("click", () => {
      if (authoritativeReady && clientSettings.pointerLock &&
          typeof sceneCanvas.requestPointerLock === "function") {
        sceneCanvas.requestPointerLock();
      }
    });
    sceneCanvas.addEventListener("mousemove", (event) => {
      if (authoritativeReady && document.pointerLockElement === sceneCanvas) {
        if (event.movementX > 3) sendGameCommand(GAME_LOOK_RIGHT, 15);
        if (event.movementX < -3) sendGameCommand(GAME_LOOK_LEFT, -15);
      }
    });
  }
  bindSceneInput();

  window.addEventListener("beforeunload", () => {
    shuttingDown = true;
    if (renderFrameHandle) window.cancelAnimationFrame(renderFrameHandle);
    if (sceneRenderer && typeof sceneRenderer.destroy === "function") sceneRenderer.destroy();
    disconnect(false);
  });

  window.kookieSessionTransport = Object.freeze({
    connect,
    disconnect,
    ping: sendPing,
    gameProbe: sendGameProbe,
    sceneProbe: sendSceneProbe,
    moveLeft: () => sendGameCommand(GAME_STRAFE_LEFT, -8),
    moveRight: () => sendGameCommand(GAME_STRAFE_RIGHT, 8),
    forward: () => sendGameCommand(GAME_MOVE_FORWARD, 8),
    back: () => sendGameCommand(GAME_MOVE_BACK, -8),
    jump: () => sendGameCommand(GAME_JUMP, 0),
    fire: () => sendGameCommand(GAME_FIRE, 0),
    melee: () => sendGameCommand(GAME_MELEE, 0),
    special: () => sendGameCommand(GAME_SPECIAL, 0),
    reset: () => sendGameCommand(GAME_RESET, 0),
    protocolVersion: NETCODE_PROTOCOL_VERSION,
    maxFrameBytes: MAX_FRAME_BYTES,
  });
})();
