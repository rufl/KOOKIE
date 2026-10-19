(() => {
  "use strict";

  const MAGIC = [0x4b, 0x57, 0x53, 0x31];
  const FRAME_VERSION = 1;
  const NETCODE_PROTOCOL_VERSION = 2;
  const MAX_WORDS = 64;
  const MAX_FRAME_BYTES = 16 + MAX_WORDS * 4;
  const MAX_SEQUENCE = 1000000;
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
  const GAME_MAXIMUM_VFX = 2;
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

  function defaultScene() {
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
      actors: [
        { id: 1, x: 96, y: 1, z: 80, health: 100, state: 1, kind: 1 },
        { id: 2, x: 208, y: 1, z: 160, health: 100, state: 1, kind: 2 },
        { id: 3, x: 260, y: 1, z: 220, health: 100, state: 2, kind: 1 },
        { id: 4, x: 150, y: 1, z: 210, health: 100, state: 3, kind: 2 },
      ],
      projectiles: [],
      pickup: null,
    };
  }

  let sceneState = defaultScene();
  let sceneRenderer = null;
  let renderFrameHandle = 0;

  function createFallbackRenderer(canvas) {
    const context = typeof canvas.getContext === "function"
      ? canvas.getContext("2d") : null;
    return {
      supported: Boolean(context),
      reason: context ? "WebGL2 unavailable; 2D fallback" : "canvas unavailable",
      render(scene) {
        if (!context) return;
        const width = canvas.width;
        const height = canvas.height;
        context.clearRect(0, 0, width, height);
        context.fillStyle = "#081018";
        context.fillRect(0, 0, width, height);
        context.strokeStyle = "#1e3a4a";
        for (let x = 32; x < width - 32; x += 48) {
          context.beginPath();
          context.moveTo(x, 48);
          context.lineTo(x, height - 28);
          context.stroke();
        }
        const worldToCanvas = (x, z) => [
          width / 2 + (x - scene.playerX) * (width - 64) / 240,
          height / 2 + z * (height - 96) / 120,
        ];
        for (const actor of scene.actors) {
          if (actor.health <= 0) continue;
          const [x, z] = worldToCanvas(actor.x, actor.z);
          context.fillStyle = "#ef5366";
          context.beginPath();
          context.moveTo(x, z - 16);
          context.lineTo(x + 14, z);
          context.lineTo(x, z + 16);
          context.lineTo(x - 14, z);
          context.closePath();
          context.fill();
        }
        const [playerX, playerZ] = worldToCanvas(scene.playerX, scene.playerZ);
        context.fillStyle = "#60a5fa";
        context.fillRect(playerX - 13, playerZ - 13, 26, 26);
        context.fillStyle = "#f8fafc";
        context.fillRect(playerX - 7, playerZ - 28, 14, 10);
        context.fillStyle = "#e2e8f0";
        context.font = "12px monospace";
        context.fillText("WebGL2 unavailable", 16, 22);
      },
    };
  }
  let rendererFailureActive = false;
  function activateFallbackRenderer(reason) {
    if (rendererFailureActive) return;
    rendererFailureActive = true;
    const replacement = document.createElement("canvas");
    replacement.id = "kookie-authoritative-scene";
    replacement.width = sceneCanvas.width || 960;
    replacement.height = sceneCanvas.height || 480;
    replacement.setAttribute("role", "img");
    replacement.setAttribute("tabindex", "0");
    replacement.setAttribute("aria-label", "Authoritative 2D fallback game scene");
    if (typeof sceneCanvas.replaceWith === "function") {
      sceneCanvas.replaceWith(replacement);
      sceneCanvas = replacement;
    }
    try {
      if (sceneRenderer && typeof sceneRenderer.destroy === "function") sceneRenderer.destroy();
    } catch (error) {
      // Failed GPU cleanup must not hide the visible fallback surface.
    }
    sceneRenderer = createFallbackRenderer(sceneCanvas);
    hudValues.renderer.textContent = sceneRenderer.reason || "2D fallback";
    setRuntimeState("fallback / " + reason, "#fbbf24");
    setStatus("RENDERER FALLBACK / " + reason, "#fbbf24");
    bindSceneInput();
  }

  let rendererInitializationError = "";
  try {
    if (window.KookieWebRenderer && typeof window.KookieWebRenderer.create === "function") {
      sceneRenderer = window.KookieWebRenderer.create(sceneCanvas);
    }
  } catch (error) {
    rendererInitializationError = error.message;
    sceneRenderer = null;
  }
  if (!sceneRenderer || !sceneRenderer.supported) {
    sceneRenderer = createFallbackRenderer(sceneCanvas);
  }
  hudValues.renderer.textContent = sceneRenderer.reason || "WebGL2";
  setRuntimeState("idle / renderer ready");
  if (rendererInitializationError) {
    activateFallbackRenderer("initialization failed: " + rendererInitializationError);
  }


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

  function updateScene(scene) {
    sceneState = scene;
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
    try {
      if (sceneRenderer && typeof sceneRenderer.render === "function") {
        sceneRenderer.render(sceneState, time);
        if (typeof sceneRenderer.getStatus === "function") {
          const rendererStatus = sceneRenderer.getStatus();
          if (hudValues.renderer.textContent !== rendererStatus) {
            hudValues.renderer.textContent = rendererStatus;
          }
          if (rendererStatus.includes("context lost")) {
            activateFallbackRenderer("WebGL context lost");
          }
        }
      }
    } catch (error) {
      activateFallbackRenderer(error.message || "WebGL render failure");
    }
    renderFrameHandle = window.requestAnimationFrame(renderFrame);
  }
  updateScene(sceneState);
  renderFrameHandle = window.requestAnimationFrame(renderFrame);

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
      if (words.length === 61) {
        const actorHealthIndices = [25, 32, 39, 46];
        const actorStateIndices = [26, 33, 40, 47];
        const actorKindIndices = [27, 34, 41, 48];
        const projectileValid = words[50] === 0
          ? [51, 52, 53, 54].every((index) => words[index] === 0)
          : words[50] === 1 &&
            words[51] >= GAME_WORLD_MINIMUM_X && words[51] <= GAME_WORLD_MAXIMUM_X &&
            words[52] >= GAME_WORLD_MINIMUM_Y && words[52] <= GAME_WORLD_MAXIMUM_Y &&
            words[53] >= GAME_WORLD_MINIMUM_Z && words[53] <= GAME_WORLD_MAXIMUM_Z &&
            words[54] >= 1 && words[54] <= 10;
        return words[3] === GAME_FULL_SCENE_SNAPSHOT_MARKER &&
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
          actorHealthIndices.every((index) => words[index] >= 0 && words[index] <= GAME_MAXIMUM_HEALTH) &&
          actorStateIndices.every((index) => words[index] >= 1 && words[index] <= 4) &&
          actorKindIndices.every((index) => words[index] >= 1 && words[index] <= 2) &&
          words[49] >= 0 && words[49] <= 1 && projectileValid &&
          words[55] >= 0 && words[55] <= 1 &&
          words[56] >= 0 && words[56] <= 6 &&
          words[57] >= GAME_WORLD_MINIMUM_X && words[57] <= GAME_WORLD_MAXIMUM_X &&
          words[58] >= GAME_WORLD_MINIMUM_Y && words[58] <= GAME_WORLD_MAXIMUM_Y &&
          words[59] >= GAME_WORLD_MINIMUM_Z && words[59] <= GAME_WORLD_MAXIMUM_Z &&
          words[60] === messageChecksum(words.slice(0, 60));
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
    if (!socket || socket.readyState !== WebSocket.OPEN || !authoritativeReady) return;
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
      const offset = 21 + index * 7;
      actors.push({
        id: words[offset],
        x: words[offset + 1],
        y: words[offset + 2],
        z: words[offset + 3],
        health: words[offset + 4],
        state: words[offset + 5],
        kind: words[offset + 6],
      });
    }
    const projectiles = words[50] === 1
      ? [{ x: words[51], y: words[52], z: words[53], ttl: words[54] }]
      : [];
    const pickup = words[55] === 1
      ? { kind: words[56], x: words[57], y: words[58], z: words[59] }
      : null;
    return {
      tick: words[4],
      playerX: words[5],
      playerY: words[6],
      playerZ: words[7],
      yaw: words[8],
      pitch: words[9],
      health: words[10],
      stamina: words[11],
      ammo: words[12],
      combo: words[13],
      vfx: words[14],
      camera: { x: words[15], y: words[16], z: words[17], yaw: words[18], pitch: words[19] },
      actors,
      projectiles,
      pickup,
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
    setRuntimeState(explicit ? "idle / disconnected" : "disconnected");
    if (activeSocket &&
        (activeSocket.readyState === WebSocket.OPEN ||
          activeSocket.readyState === WebSocket.CONNECTING)) {
      activeSocket.close(1000, "client disconnect");
    }
    if (explicit) setStatus("IDLE / disconnected");
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
