(() => {
  "use strict";

  const MAGIC = [0x4b, 0x57, 0x53, 0x31];
  const FRAME_VERSION = 1;
  const NETCODE_PROTOCOL_VERSION = 2;
  const MAX_WORDS = 272;
  const MAX_FRAME_BYTES = 16 + MAX_WORDS * 4;
  const MAX_SEQUENCE = 1000000;
  const MAX_PENDING_INPUT_FRAMES = 64;
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
  const GAME_JOIN_REQUEST_MARKER = 5;
  const GAME_JOIN_RESPONSE_MARKER = 6;
  const GAME_MULTIPLAYER_SNAPSHOT_MARKER = 7;
  const GAME_ROLE_PLAYER = 1;
  const GAME_ROLE_SPECTATOR = 2;
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
  const GAME_LOOK_UP = 16;
  const GAME_INPUT_MARKER = 8;
  const ACTION_JUMP = 1 << 0;
  const ACTION_ROLL = 1 << 1;
  const ACTION_DASH = 1 << 2;
  const ACTION_GLIDE = 1 << 3;
  const ACTION_FLY = 1 << 4;
  const ACTION_SHOOT = 1 << 5;
  const ACTION_MELEE = 1 << 6;
  const ACTION_SPECIAL = 1 << 7;
  const ACTION_THROWABLE = 1 << 8;
  const GAME_MAXIMUM_INPUT_AXIS = 1000;
  const GAME_MAXIMUM_LOOK_DELTA = 1800;
  const GAME_LOOK_DOWN = 17;
  const GAME_MINIMUM_POSITION = -100;
  const GAME_MAXIMUM_POSITION = 100;
  const GAME_MINIMUM_DEPTH = -60;
  const GAME_MAXIMUM_DEPTH = 60;
  const GAME_WORLD_MINIMUM_X = 4;
  const GAME_WORLD_MAXIMUM_X = 316;
  const GAME_WORLD_MINIMUM_Y = 0;
  const GAME_WORLD_MAXIMUM_Y = 100;
  const GAME_WORLD_MINIMUM_Z = 4;
  const GAME_WORLD_MAXIMUM_Z = 276;
  const GAME_MAXIMUM_TICK = 10000000;
  const GAME_MAXIMUM_THROWABLE_FUSE_TICKS = 36;
  const GAME_MAXIMUM_HEALTH = 100;
  const GAME_MAXIMUM_STAMINA = 100;
  const GAME_MAXIMUM_AMMO = 99;
  const GAME_MAXIMUM_COMBO = 1000000;
  const GAME_MAXIMUM_VFX = 15;
  const GAME_VFX_LIQUID = 14;
  const GAME_MAXIMUM_ACTORS = 4;

  const root = document.getElementById("kof-root") || document.body;
  let statusTimer = null;
  let pingFlashTimer = null;
  const panel = document.createElement("section");
  panel.id = "kookie-session-panel";
  panel.className = "kookie-session-panel";
  panel.setAttribute("aria-labelledby", "kookie-session-heading");

  const header = document.createElement("header");
  header.className = "kookie-session-header";
  const brand = document.createElement("div");
  brand.className = "kookie-session-brand";
  const heading = document.createElement("strong");
  heading.id = "kookie-session-heading";
  heading.textContent = "GATOGANSO";
  const tagline = document.createElement("span");
  tagline.textContent = "A wild little arena adventure";
  brand.appendChild(heading);
  brand.appendChild(tagline);
  header.appendChild(brand);

  const params = new URLSearchParams(window.location.search);
  const endpointLabel = document.createElement("label");
  endpointLabel.textContent = "Game server address";
  const endpoint = document.createElement("input");
  endpoint.type = "url";
  endpoint.value = params.get("kookie_ws") || "ws://127.0.0.1:8765/session";
  endpoint.setAttribute("aria-label", "WebSocket game server address");
  endpointLabel.appendChild(endpoint);
  const roleLabel = document.createElement("label");
  roleLabel.textContent = "Session role";
  const roleSelect = document.createElement("select");
  roleSelect.setAttribute("aria-label", "Multiplayer session role");
  for (const [value, label] of [
    ["player", "Player"],
    ["spectator", "Spectator"],
  ]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = label;
    roleSelect.appendChild(option);
  }
  roleSelect.value = params.get("kookie_role") === "spectator"
    ? "spectator" : "player";
  roleLabel.appendChild(roleSelect);
  const tokenLabel = document.createElement("label");
  tokenLabel.textContent = "Session token (optional)";
  const authToken = document.createElement("input");
  authToken.type = "password";
  authToken.value = params.get("kookie_token") || "";
  authToken.setAttribute("aria-label", "Session authentication token");
  authToken.setAttribute("autocomplete", "off");
  authToken.placeholder = "8-128 safe ASCII characters";
  tokenLabel.appendChild(authToken);

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
  const boundedPercent = (value, minimum, fallback) =>
    Number.isInteger(value) && value >= minimum && value <= 100 ? value : fallback;
  const clientSettings = {
    autoReconnect: storedSettings.autoReconnect !== false,
    reconnectDelayMs: [250, 500, 1000, 2000].includes(storedSettings.reconnectDelayMs)
      ? storedSettings.reconnectDelayMs : 500,
    showMinimap: storedSettings.showMinimap !== false,
    pointerLock: storedSettings.pointerLock !== false,
    reducedMotion: storedSettings.reducedMotion === true ||
      (typeof window.matchMedia === "function" &&
        window.matchMedia("(prefers-reduced-motion: reduce)").matches),
    movementSpeedPercent: boundedPercent(storedSettings.movementSpeedPercent, 25, 50),
    mouseCameraSensitivityPercent: Number.isInteger(storedSettings.mouseCameraSensitivityPercent) &&
      storedSettings.mouseCameraSensitivityPercent >= 25 &&
      storedSettings.mouseCameraSensitivityPercent <= 150
      ? storedSettings.mouseCameraSensitivityPercent : 50,
  };
  const settingsMenu = document.createElement("details");
  settingsMenu.className = "kookie-session-settings";
  const settingsSummary = document.createElement("summary");
  settingsSummary.setAttribute("aria-label", "Settings");
  const settingsLabel = window.matchMedia("(max-width: 700px)");
  const updateSettingsLabel = () => {
    settingsSummary.textContent = settingsLabel.matches ? "SET" : "SETTINGS";
  };
  updateSettingsLabel();
  settingsLabel.addEventListener("change", updateSettingsLabel);
  settingsMenu.appendChild(settingsSummary);
  const settingsGrid = document.createElement("div");
  settingsGrid.className = "kookie-session-settings-grid";
  function addSettingToggle(key, labelText) {
    const label = document.createElement("label");
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
  addSettingToggle("autoReconnect", "Reconnect automatically");
  addSettingToggle("showMinimap", "Show small arena map");
  addSettingToggle("pointerLock", "Use pointer lock for mouse look");
  addSettingToggle("reducedMotion", "Reduce interface motion");
  function addSettingRange(key, labelText, minimum, maximum) {
    const label = document.createElement("label");
    label.className = "kookie-session-range";
    const text = document.createElement("span");
    text.textContent = labelText;
    const input = document.createElement("input");
    input.type = "range";
    input.min = String(minimum);
    input.max = String(maximum);
    input.step = "5";
    input.value = String(clientSettings[key]);
    input.setAttribute("aria-label", labelText);
    const output = document.createElement("output");
    output.textContent = input.value + "%";
    input.addEventListener("input", () => {
      const value = Number(input.value);
      if (!Number.isInteger(value) || value < minimum || value > maximum) return;
      clientSettings[key] = value;
      output.textContent = value + "%";
      saveStoredSettings();
    });
    label.appendChild(text);
    label.appendChild(input);
    label.appendChild(output);
    settingsGrid.appendChild(label);
  }
  addSettingRange("movementSpeedPercent", "Movement speed", 25, 100);
  addSettingRange("mouseCameraSensitivityPercent", "Mouse camera sensitivity", 25, 150);
  const reconnectDelayLabel = document.createElement("label");
  reconnectDelayLabel.textContent = "Reconnect delay";
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
  settingsMenu.appendChild(endpointLabel);
  settingsMenu.appendChild(roleLabel);
  settingsMenu.appendChild(tokenLabel);
  settingsMenu.appendChild(settingsGrid);

  const controls = document.createElement("div");
  controls.className = "kookie-session-controls";
  const connectButton = document.createElement("button");
  connectButton.type = "button";
  connectButton.className = "kookie-primary";
  connectButton.textContent = "PLAY";
  connectButton.dataset.asyncState = "idle";
  controls.appendChild(connectButton);
  function setAsyncButtonState(button, state, label) {
    button.dataset.asyncState = state;
    button.setAttribute("aria-busy", state === "pending" ? "true" : "false");
    if (label) button.textContent = label;
  }
  header.appendChild(controls);
  const bugfeedButton = document.createElement("button");
  bugfeedButton.type = "button";
  bugfeedButton.className = "kookie-session-bugfeed";
  bugfeedButton.textContent = "BUGFEED";
  bugfeedButton.setAttribute("aria-label", "Report a bug with screenshot and diagnostics");
  controls.appendChild(bugfeedButton);
  const kutterLink = document.createElement("a");
  kutterLink.href = "kutter.html";
  kutterLink.textContent = "KUTTER";
  kutterLink.setAttribute("aria-label", "Open Kutter level editor");
  kutterLink.className = "kookie-session-editor-link";
  controls.appendChild(kutterLink);
  const fullscreenButton = document.createElement("button");
  fullscreenButton.type = "button";
  fullscreenButton.className = "kookie-session-fullscreen";
  fullscreenButton.setAttribute("aria-label", "Enter fullscreen");
  fullscreenButton.setAttribute("title", "Enter fullscreen");
  fullscreenButton.setAttribute("aria-pressed", "false");
  const fullscreenIcon = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  fullscreenIcon.setAttribute("viewBox", "0 0 24 24");
  fullscreenIcon.setAttribute("aria-hidden", "true");
  fullscreenIcon.setAttribute("focusable", "false");
  const fullscreenPath = document.createElementNS("http://www.w3.org/2000/svg", "path");
  fullscreenPath.setAttribute("d", "M8 3H5a2 2 0 0 0-2 2v3m13-5h3a2 2 0 0 1 2 2v3M3 16v3a2 2 0 0 0 2 2h3m13-5v3a2 2 0 0 1-2 2h-3");
  fullscreenPath.setAttribute("fill", "none");
  fullscreenPath.setAttribute("stroke", "currentColor");
  fullscreenPath.setAttribute("stroke-width", "2");
  fullscreenPath.setAttribute("stroke-linecap", "round");
  fullscreenPath.setAttribute("stroke-linejoin", "round");
  fullscreenIcon.appendChild(fullscreenPath);
  fullscreenButton.appendChild(fullscreenIcon);
  controls.appendChild(fullscreenButton);
  const fullscreenStatus = document.createElement("span");
  fullscreenStatus.className = "kookie-session-status-text";
  fullscreenStatus.setAttribute("role", "status");
  fullscreenStatus.setAttribute("aria-live", "polite");
  header.appendChild(fullscreenStatus);
  function updateFullscreenButton() {
    const active = document.fullscreenElement === panel ||
      document.webkitFullscreenElement === panel;
    fullscreenButton.setAttribute("aria-pressed", String(active));
    fullscreenButton.setAttribute(
      "aria-label", active ? "Exit fullscreen" : "Enter fullscreen",
    );
    fullscreenButton.title = active ? "Exit fullscreen" : "Enter fullscreen";
  }
  fullscreenButton.addEventListener("click", async () => {
    const active = document.fullscreenElement === panel ||
      document.webkitFullscreenElement === panel;
    try {
      if (active) {
        const exit = document.exitFullscreen || document.webkitExitFullscreen;
        if (!exit) throw new Error("Fullscreen exit is unavailable in this browser");
        await exit.call(document);
      } else {
        const enter = panel.requestFullscreen || panel.webkitRequestFullscreen;
        if (!enter) throw new Error("Fullscreen is unavailable in this browser");
        await enter.call(panel);
      }
      fullscreenStatus.textContent = "";
    } catch (error) {
      fullscreenStatus.textContent = error.message ||
        "Fullscreen was denied by the browser";
    }
    updateFullscreenButton();
  });
  document.addEventListener("fullscreenchange", updateFullscreenButton);
  document.addEventListener("webkitfullscreenchange", updateFullscreenButton);
  header.appendChild(settingsMenu);
  panel.appendChild(header);

  const sceneGrid = document.createElement("div");
  sceneGrid.className = "kookie-session-stage";
  const sceneCanvasWrap = document.createElement("div");
  sceneCanvasWrap.className = "kookie-session-canvas-wrap";
  let sceneCanvas = document.createElement("canvas");
  sceneCanvas.id = "kookie-authoritative-scene";
  sceneCanvas.width = 960;
  sceneCanvas.height = 480;
  sceneCanvas.setAttribute("role", "img");
  sceneCanvas.setAttribute("tabindex", "0");
  sceneCanvas.setAttribute("aria-label", "GatoGanso game scene. Use the on-screen controls or keyboard.");
  sceneCanvasWrap.appendChild(sceneCanvas);
  const labelOverlay = document.createElement("div");
  labelOverlay.id = "kookie-scene-labels";
  labelOverlay.className = "kookie-session-labels";
  labelOverlay.setAttribute("aria-label", "Visible player and animal labels");
  sceneCanvasWrap.appendChild(labelOverlay);
  const minimapCanvas = document.createElement("canvas");
  minimapCanvas.className = "kookie-session-minimap";
  minimapCanvas.width = 360;
  minimapCanvas.height = 240;
  minimapCanvas.setAttribute("role", "img");
  minimapCanvas.setAttribute("aria-label", "Arena map");
  function setMinimapVisibility(visible) {
    minimapCanvas.hidden = !visible;
    minimapCanvas.setAttribute("aria-hidden", visible ? "false" : "true");
  }
  setMinimapVisibility(clientSettings.showMinimap);
  sceneCanvasWrap.appendChild(minimapCanvas);

  const hud = document.createElement("div");
  hud.className = "kookie-session-hud";
  const hudValues = {};
  function addHudStat(key, label, value) {
    const stat = document.createElement("div");
    stat.className = "kookie-session-stat";
    stat.setAttribute("data-stat", key);
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
  addHudStat("health", "HEALTH", "100");
  addHudStat("stamina", "STAMINA", "100");
  addHudStat("ammo", "AMMO", "24");
  addHudStat("combo", "COMBO", "0");
  addHudStat("actors", "ACTORS", "4");
  addHudStat("projectiles", "PROJECTILES", "0");
  addHudStat("ping", "PING", "--");
  addHudStat("renderer", "RENDERER", "starting");
  sceneCanvasWrap.appendChild(hud);

  const runtimeState = document.createElement("span");
  runtimeState.className = "kookie-session-runtime";
  runtimeState.setAttribute("role", "status");
  runtimeState.setAttribute("aria-live", "polite");
  runtimeState.textContent = "READY TO PLAY";
  sceneCanvasWrap.appendChild(runtimeState);
  const remoteState = document.createElement("span");
  remoteState.id = "kookie-session-authoritative-state";
  remoteState.className = "kookie-session-status-text";
  remoteState.setAttribute("role", "status");
  remoteState.setAttribute("aria-live", "polite");
  remoteState.textContent = "Not connected";
  sceneCanvasWrap.appendChild(remoteState);
  const status = document.createElement("span");
  status.id = "kookie-session-status";
  status.className = "kookie-session-status";
  status.setAttribute("role", "status");
  status.setAttribute("aria-live", "polite");
  sceneCanvasWrap.appendChild(status);
  const help = document.createElement("span");
  help.className = "kookie-session-help";
  help.textContent = "Move with the left stick · drag the game view to look · WASD / mouse also supported";
  sceneCanvasWrap.appendChild(help);
  const touchLookHint = document.createElement("span");
  touchLookHint.className = "kookie-session-touch-look";
  touchLookHint.setAttribute("aria-hidden", "true");
  touchLookHint.textContent = "DRAG TO LOOK";
  sceneCanvasWrap.appendChild(touchLookHint);
  sceneGrid.appendChild(sceneCanvasWrap);
  panel.appendChild(sceneGrid);

  let gameplayHeldActions = 0;
  let gameplayMoveX = 0;
  let gameplayMoveZ = 0;
  const footer = document.createElement("footer");
  footer.className = "kookie-session-footer";
  const gameControls = document.createElement("div");
  gameControls.className = "kookie-session-game-controls";
  const movementControls = document.createElement("div");
  movementControls.className = "kookie-session-stick";
  movementControls.setAttribute("role", "group");
  movementControls.setAttribute("aria-label", "Movement analog stick. WASD is the keyboard alternative.");
  movementControls.setAttribute("data-analog-stick", "move");
  const actionControls = document.createElement("div");
  actionControls.className = "kookie-session-actions";
  const gameActionButtons = [];
  const analogSticks = [];
  function addAnalogStick(label, destination, onVector, options = {}) {
    const base = document.createElement("div");
    base.className = "kookie-stick-base";
    base.setAttribute("aria-hidden", "true");
    const knob = document.createElement("span");
    knob.className = "kookie-stick-knob";
    base.appendChild(knob);
    const caption = document.createElement("span");
    caption.className = "kookie-stick-label";
    caption.textContent = label;
    destination.appendChild(base);
    destination.appendChild(caption);
    let enabled = false;
    let pointerId = null;
    let timer = null;
    let vector = { x: 0, y: 0 };
    const reset = () => {
      if (pointerId !== null) onVector({ x: 0, y: 0 });
      if (timer !== null) window.clearTimeout(timer);
      timer = null;
      pointerId = null;
      vector = { x: 0, y: 0 };
      knob.style.transform = "translate(0px, 0px)";
      destination.classList.remove("is-active");
    };
    const schedule = () => {
      if (timer !== null || pointerId === null || !enabled) return;
      timer = window.setTimeout(() => {
        timer = null;
        if (pointerId === null || !enabled) return;
        onVector(vector);
        schedule();
      }, options.repeatDelay ? options.repeatDelay(vector) :
        Math.round((300 - Math.max(Math.abs(vector.x), Math.abs(vector.y)) * 190) *
          100 / clientSettings.movementSpeedPercent));
    };
    const update = (event) => {
      const rect = base.getBoundingClientRect();
      const radius = Math.max(1, Math.min(rect.width, rect.height) * 0.38);
      let x = (event.clientX - (rect.left + rect.width / 2)) / radius;
      let y = (event.clientY - (rect.top + rect.height / 2)) / radius;
      const length = Math.hypot(x, y);
      if (length > 1) { x /= length; y /= length; }
      const magnitude = Math.hypot(x, y);
      if (magnitude < 0.18) { x = 0; y = 0; }
      vector = { x, y };
      knob.style.transform = "translate(" + (x * radius) + "px, " + (y * radius) + "px)";
      if (options.immediate !== false && (x || y)) onVector(vector);
      if (x || y) schedule();
      else if (timer !== null) { window.clearTimeout(timer); timer = null; }
    };
    base.addEventListener("pointerdown", (event) => {
      if (!enabled) return;
      event.preventDefault();
      pointerId = event.pointerId;
      destination.classList.add("is-active");
      if (typeof base.setPointerCapture === "function") base.setPointerCapture(pointerId);
      update(event);
      if (options.initialPulse && (vector.x || vector.y)) onVector(vector);
    });
    base.addEventListener("pointermove", (event) => {
      if (event.pointerId === pointerId) update(event);
    });
    for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) {
      base.addEventListener(name, (event) => {
        if (pointerId !== null && (event.pointerId === undefined || event.pointerId === pointerId)) reset();
      });
    }
    analogSticks.push({ setEnabled(value) {
      enabled = value;
      destination.setAttribute("aria-disabled", String(!value));
      if (!value) reset();
    } });
  }
  const movementRepeatDelay = (vector) =>
    Math.round((300 - Math.max(Math.abs(vector.x), Math.abs(vector.y)) * 190) *
      100 / clientSettings.movementSpeedPercent);
  addAnalogStick("MOVE", movementControls, (vector) => {
    sendGameplayInput({
      moveX: Math.round(vector.x * GAME_MAXIMUM_INPUT_AXIS),
      moveZ: Math.round(-vector.y * GAME_MAXIMUM_INPUT_AXIS),
    });
  }, { immediate: true, initialPulse: true });
  function addGameAction(label, command, value, destination, options = {}) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.disabled = true;
    button.setAttribute("aria-label", options.ariaLabel || label);
    if (options.action) button.setAttribute("data-action", options.action);
    const bit = options.bit || 0;
    if (bit) {
      const down = (event) => {
        if (button.disabled) return;
        event.preventDefault();
        if (options.held) gameplayHeldActions |= bit;
        sendGameplayInput({ heldActions: gameplayHeldActions,
          edgeActions: options.edge ? bit : 0 });
      };
      const up = () => {
        if (!options.held || !(gameplayHeldActions & bit)) return;
        gameplayHeldActions &= ~bit;
        sendGameplayInput({ heldActions: gameplayHeldActions });
      };
      button.addEventListener("pointerdown", down);
      button.addEventListener("pointerup", up);
      button.addEventListener("pointercancel", up);
      button.addEventListener("pointerleave", up);
      button.addEventListener("click", (event) => {
        if (event.detail === 0 && options.edge) sendGameplayInput({ edgeActions: bit });
      });
    } else {
      button.addEventListener("click", () => sendGameCommand(command, value));
    }
    gameActionButtons.push(button);
    destination.appendChild(button);
  }
  addGameAction("JUMP", GAME_JUMP, 0, actionControls, { action: "jump", bit: ACTION_JUMP, edge: true, held: true });
  addGameAction("ROLL", 0, 0, actionControls, { action: "roll", bit: ACTION_ROLL, edge: true });
  addGameAction("DASH", 0, 0, actionControls, { action: "dash", bit: ACTION_DASH, edge: true });
  addGameAction("GLIDE", 0, 0, actionControls, { action: "glide", bit: ACTION_GLIDE, held: true });
  addGameAction("FLY", 0, 0, actionControls, { action: "fly", bit: ACTION_FLY, held: true });
  addGameAction("SHOOT", GAME_FIRE, 0, actionControls, { action: "shoot", bit: ACTION_SHOOT, held: true });
  addGameAction("MELEE", GAME_MELEE, 0, actionControls, { action: "melee", bit: ACTION_MELEE, edge: true });
  addGameAction("SPECIAL", GAME_SPECIAL, 0, actionControls, { action: "special", bit: ACTION_SPECIAL, edge: true });
  addGameAction("THROW", 0, 0, actionControls, { action: "throwable", bit: ACTION_THROWABLE, edge: true });
  gameControls.appendChild(movementControls);
  gameControls.appendChild(actionControls);
  footer.appendChild(gameControls);
  panel.appendChild(footer);
  const TOUCH_LAYOUT_KEY = "kookie.browser.touch-layouts.v1";
  const readTouchLayouts = () => {
    try {
      const value = JSON.parse(window.localStorage.getItem(TOUCH_LAYOUT_KEY) || "{}");
      return value && typeof value === "object" ? value : {};
    } catch (error) {
      return {};
    }
  };
  const clampLayoutPoint = (point, fallback) => ({
    x: Number.isFinite(point?.x) ? Math.max(6, Math.min(94, point.x)) : fallback.x,
    y: Number.isFinite(point?.y) ? Math.max(8, Math.min(92, point.y)) : fallback.y,
  });
  const touchLayoutState = readTouchLayouts();
  const defaultTouchLayout = {
    move: { x: 12, y: 78 },
    actions: { x: 88, y: 78 },
  };
  const validTouchLayout = (layout) => ({
    move: clampLayoutPoint(layout?.move, defaultTouchLayout.move),
    actions: clampLayoutPoint(layout?.actions, defaultTouchLayout.actions),
  });
  const touchPresets = touchLayoutState.presets &&
    typeof touchLayoutState.presets === "object" ? touchLayoutState.presets : {};
  let activeTouchLayout = touchLayoutState.activeName &&
    touchPresets[touchLayoutState.activeName]
    ? validTouchLayout(touchPresets[touchLayoutState.activeName])
    : touchLayoutState.activeLayout ? validTouchLayout(touchLayoutState.activeLayout) : null;
  let touchLayoutEditing = false;
  const controlGroups = { move: movementControls, actions: actionControls };
  const applyTouchLayout = (layout) => {
    for (const [name, element] of Object.entries(controlGroups)) {
      const point = layout?.[name];
      if (!point) {
        element.style.position = "";
        element.style.left = "";
        element.style.top = "";
        element.style.transform = "";
        continue;
      }
      element.style.position = "fixed";
      element.style.left = point.x + "vw";
      element.style.top = point.y + "vh";
      element.style.transform = "translate(-50%, -50%)";
    }
  };
  const persistTouchLayout = () => {
    try {
      window.localStorage.setItem(TOUCH_LAYOUT_KEY, JSON.stringify({
        activeName: touchLayoutState.activeName || "",
        activeLayout: activeTouchLayout,
        presets: touchPresets,
      }));
    } catch (error) {
      // Layout remains usable for this session when storage is unavailable.
    }
  };
  if (activeTouchLayout) applyTouchLayout(activeTouchLayout);
  const layoutEditor = document.createElement("div");
  layoutEditor.className = "kookie-touch-layout-editor";
  layoutEditor.hidden = true;
  layoutEditor.setAttribute("aria-label", "Touch control layout editor");
  const layoutTitle = document.createElement("strong");
  layoutTitle.textContent = "TOUCH LAYOUT";
  layoutEditor.appendChild(layoutTitle);
  const layoutMode = document.createElement("select");
  layoutMode.setAttribute("aria-label", "Control to reposition");
  for (const [value, label] of [["move", "Movement stick"], ["actions", "Action buttons"]]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = label;
    layoutMode.appendChild(option);
  }
  layoutMode.value = "move";
  layoutEditor.appendChild(layoutMode);
  const layoutX = document.createElement("input");
  layoutX.type = "range";
  layoutX.min = "6";
  layoutX.max = "94";
  layoutX.setAttribute("aria-label", "Selected control horizontal position");
  const layoutY = document.createElement("input");
  layoutY.type = "range";
  layoutY.min = "8";
  layoutY.max = "92";
  layoutY.setAttribute("aria-label", "Selected control vertical position");
  layoutEditor.appendChild(layoutX);
  layoutEditor.appendChild(layoutY);
  const layoutName = document.createElement("input");
  layoutName.type = "text";
  layoutName.maxLength = 24;
  layoutName.placeholder = "Preset name";
  layoutName.setAttribute("aria-label", "Touch layout preset name");
  layoutEditor.appendChild(layoutName);
  const presetSelect = document.createElement("select");
  presetSelect.setAttribute("aria-label", "Saved touch layout presets");
  layoutEditor.appendChild(presetSelect);
  const refreshPresetSelect = () => {
    while (presetSelect.children.length > 0) {
      presetSelect.removeChild(presetSelect.children[0]);
    }
    for (const name of Object.keys(touchPresets).sort()) {
      const option = document.createElement("option");
      option.value = name;
      option.textContent = name;
      option.selected = name === touchLayoutState.activeName;
      presetSelect.appendChild(option);
    }
  };
  const syncLayoutSliders = () => {
    const point = activeTouchLayout?.[layoutMode.value] ||
      defaultTouchLayout[layoutMode.value];
    layoutX.value = String(Math.round(point.x));
    layoutY.value = String(Math.round(point.y));
  };
  const updateLayoutPoint = () => {
    const key = layoutMode.value;
    activeTouchLayout = activeTouchLayout || validTouchLayout(defaultTouchLayout);
    activeTouchLayout[key] = clampLayoutPoint(
      { x: Number(layoutX.value), y: Number(layoutY.value) },
      defaultTouchLayout[key],
    );
    touchLayoutState.activeName = "";
    applyTouchLayout(activeTouchLayout);
    persistTouchLayout();
  };
  layoutMode.addEventListener("change", syncLayoutSliders);
  layoutX.addEventListener("input", updateLayoutPoint);
  layoutY.addEventListener("input", updateLayoutPoint);
  const savePreset = document.createElement("button");
  savePreset.type = "button";
  savePreset.textContent = "Save preset";
  savePreset.addEventListener("click", () => {
    const name = layoutName.value.trim().slice(0, 24);
    if (!name || !activeTouchLayout) return;
    touchPresets[name] = validTouchLayout(activeTouchLayout);
    touchLayoutState.activeName = name;
    activeTouchLayout = validTouchLayout(touchPresets[name]);
    refreshPresetSelect();
    persistTouchLayout();
  });
  layoutEditor.appendChild(savePreset);
  const loadPreset = document.createElement("button");
  loadPreset.type = "button";
  loadPreset.textContent = "Load preset";
  loadPreset.addEventListener("click", () => {
    const name = presetSelect.value;
    if (!touchPresets[name]) return;
    touchLayoutState.activeName = name;
    activeTouchLayout = validTouchLayout(touchPresets[name]);
    applyTouchLayout(activeTouchLayout);
    syncLayoutSliders();
    persistTouchLayout();
  });
  layoutEditor.appendChild(loadPreset);
  const resetLayout = document.createElement("button");
  resetLayout.type = "button";
  resetLayout.textContent = "Reset layout";
  resetLayout.addEventListener("click", () => {
    activeTouchLayout = null;
    touchLayoutState.activeName = "";
    applyTouchLayout(null);
    persistTouchLayout();
    syncLayoutSliders();
  });
  layoutEditor.appendChild(resetLayout);
  const doneLayout = document.createElement("button");
  doneLayout.type = "button";
  doneLayout.textContent = "Done";
  doneLayout.addEventListener("click", () => {
    touchLayoutEditing = false;
    layoutEditor.hidden = true;
    panel.dataset.layoutEditing = "false";
  });
  layoutEditor.appendChild(doneLayout);
  refreshPresetSelect();
  syncLayoutSliders();
  sceneCanvasWrap.appendChild(layoutEditor);
  const customizeLayout = document.createElement("button");
  customizeLayout.type = "button";
  customizeLayout.textContent = "Customize touch controls";
  customizeLayout.addEventListener("click", () => {
    activeTouchLayout = activeTouchLayout || validTouchLayout(defaultTouchLayout);
    applyTouchLayout(activeTouchLayout);
    touchLayoutEditing = true;
    layoutEditor.hidden = false;
    panel.dataset.layoutEditing = "true";
    syncLayoutSliders();
  });
  settingsGrid.appendChild(customizeLayout);
  for (const [name, element] of Object.entries(controlGroups)) {
    let drag = null;
    element.addEventListener("pointerdown", (event) => {
      if (!touchLayoutEditing) return;
      event.preventDefault();
      event.stopPropagation();
      const point = activeTouchLayout?.[name] || defaultTouchLayout[name];
      drag = { id: event.pointerId, x: point.x, y: point.y, startX: event.clientX, startY: event.clientY };
      if (typeof element.setPointerCapture === "function") element.setPointerCapture(event.pointerId);
    }, true);
    element.addEventListener("pointermove", (event) => {
      if (!drag || drag.id !== event.pointerId) return;
      const width = Math.max(1, window.innerWidth);
      const height = Math.max(1, window.innerHeight);
      const point = clampLayoutPoint({
        x: drag.x + (event.clientX - drag.startX) / width * 100,
        y: drag.y + (event.clientY - drag.startY) / height * 100,
      }, defaultTouchLayout[name]);
      activeTouchLayout = activeTouchLayout || validTouchLayout(defaultTouchLayout);
      activeTouchLayout[name] = point;
      touchLayoutState.activeName = "";
      applyTouchLayout(activeTouchLayout);
      if (layoutMode.value === name) syncLayoutSliders();
      persistTouchLayout();
    }, true);
    for (const eventName of ["pointerup", "pointercancel", "lostpointercapture"]) {
      element.addEventListener(eventName, (event) => {
        if (drag && (event.pointerId === undefined || event.pointerId === drag.id)) drag = null;
      }, true);
    }
  }


  const advancedControls = document.createElement("div");
  advancedControls.className = "kookie-session-advanced";
  function createButton(label, disabled = false) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.disabled = disabled;
    advancedControls.appendChild(button);
    return button;
  }
  const pingButton = createButton("Ping server", true);
  const gameButton = createButton("Protocol echo", true);
  const healthButton = createButton("Check connection");
  const captureButton = createButton("Capture screenshot");
  const resetButton = createButton("Reset game", true);
  gameActionButtons.push(resetButton);
  resetButton.addEventListener("click", () => sendGameCommand(GAME_RESET, 0));
  settingsMenu.appendChild(advancedControls);

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
  let renderSceneState = null;
  const remoteSnapshots = [];
  const REMOTE_SNAPSHOT_HISTORY = 16;
  const REMOTE_BASE_TICK_MS = 1000 / 60;
  const REMOTE_MIN_RENDER_DELAY_MS = 50;
  const REMOTE_MAX_RENDER_DELAY_MS = 150;
  const REMOTE_MAX_EXTRAPOLATION_MS = 100;
  const LOCAL_MAX_EXTRAPOLATION_MS = 50;
  let remoteRenderDelayMs = 2 * REMOTE_BASE_TICK_MS;
  let remoteArrivalJitterMs = 0;
  let previousRemoteArrivalAt = 0;
  let previousRemoteTick = -1;
  let localMovementBlend = null;
  const localRenderPosition = { x: 0, z: 0 };
  const remoteRenderPosition = { x: 0, y: 0, z: 0, yaw: 0 };
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
      captureLabel + " / RGBA checksum=" + lastScreenshot.checksum,
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
  const bugfeedDialog = document.createElement("dialog");
  bugfeedDialog.className = "kookie-bugfeed-dialog";
  bugfeedDialog.setAttribute("aria-labelledby", "kookie-bugfeed-heading");
  const bugfeedHeading = document.createElement("h2");
  bugfeedHeading.id = "kookie-bugfeed-heading";
  bugfeedHeading.textContent = "Send bug report";
  const bugfeedHelp = document.createElement("p");
  bugfeedHelp.textContent =
    "A game screenshot and technical diagnostics will be saved to the private KOOKIE tailnet. Do not include passwords or private information in notes.";
  const bugfeedNotesLabel = document.createElement("label");
  bugfeedNotesLabel.textContent = "What happened?";
  const bugfeedNotes = document.createElement("textarea");
  bugfeedNotes.maxLength = 4000;
  bugfeedNotes.rows = 5;
  bugfeedNotes.setAttribute("aria-label", "Bug report notes");
  bugfeedNotesLabel.appendChild(bugfeedNotes);
  const bugfeedResult = document.createElement("p");
  bugfeedResult.setAttribute("role", "status");
  bugfeedResult.setAttribute("aria-live", "polite");
  const bugfeedActions = document.createElement("div");
  bugfeedActions.className = "kookie-bugfeed-actions";
  const bugfeedSubmit = document.createElement("button");
  bugfeedSubmit.type = "button";
  bugfeedSubmit.textContent = "Save report";
  bugfeedSubmit.dataset.asyncState = "idle";
  const bugfeedCancel = document.createElement("button");
  bugfeedCancel.type = "button";
  bugfeedCancel.textContent = "Cancel";
  bugfeedActions.appendChild(bugfeedSubmit);
  bugfeedActions.appendChild(bugfeedCancel);
  bugfeedDialog.appendChild(bugfeedHeading);
  bugfeedDialog.appendChild(bugfeedHelp);
  bugfeedDialog.appendChild(bugfeedNotesLabel);
  bugfeedDialog.appendChild(bugfeedResult);
  bugfeedDialog.appendChild(bugfeedActions);
  panel.appendChild(bugfeedDialog);
  let bugfeedCopyButton = null;

  const bugfeedErrors = [];
  function rememberBugfeedError(value) {
    const message = String(value || "unknown error").slice(0, 500);
    bugfeedErrors.push({ at: new Date().toISOString(), message });
    if (bugfeedErrors.length > 40) bugfeedErrors.shift();
  }
  window.addEventListener("error", (event) => {
    rememberBugfeedError(event.message || event.error?.message);
  });
  window.addEventListener("unhandledrejection", (event) => {
    rememberBugfeedError(event.reason?.message || event.reason);
  });

  let bugfeedScreenshot = null;
  let bugfeedCaptureStatus = "";
  let bugfeedCaptureSize = null;
  function screenshotBlob(capture) {
    if (!capture?.pixels || !capture.width || !capture.height ||
        capture.pixels.length !== capture.width * capture.height * 4) {
      return Promise.reject(new Error("renderer returned no RGBA pixels"));
    }
    const canvas = document.createElement("canvas");
    canvas.width = capture.width;
    canvas.height = capture.height;
    const context = canvas.getContext("2d");
    if (!context || typeof canvas.toBlob !== "function") {
      return Promise.reject(new Error("PNG encoding is unavailable"));
    }
    const image = context.createImageData(capture.width, capture.height);
    for (let y = 0; y < capture.height; y += 1) {
      const sourceY = capture.flipY ? capture.height - y - 1 : y;
      const source = sourceY * capture.width * 4;
      image.data.set(capture.pixels.subarray(source, source + capture.width * 4),
        y * capture.width * 4);
    }
    context.putImageData(image, 0, 0);
    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => blob ? resolve(blob) : reject(new Error("PNG encoding failed")),
        "image/png");
    });
  }

  function bugfeedMetadata(screenshotAvailable) {
    return {
      reportVersion: 1,
      notes: bugfeedNotes.value.slice(0, 4000),
      screenshotAvailable,
      screenshot: screenshotAvailable ? bugfeedCaptureSize : null,
      page: window.location.origin + window.location.pathname,
      browser: navigator.userAgent.slice(0, 500),
      viewport: {
        width: window.innerWidth,
        height: window.innerHeight,
        devicePixelRatio: window.devicePixelRatio || 1,
      },
      runtime: runtimeState.textContent,
      status: bugfeedCaptureStatus,
      authoritativeState: remoteState.textContent,
      ping: hudValues.ping.textContent,
      renderer: window.KookieBrowserCapture.getRenderer(),
      scene: {
        tick: sceneState.tick,
        player: [sceneState.playerX, sceneState.playerY, sceneState.playerZ],
        actors: sceneState.actors.length,
        projectiles: sceneState.projectiles.length,
      },
      recentErrors: bugfeedErrors.slice(),
    };
  }

  async function saveBugfeedReport() {
    setAsyncButtonState(bugfeedSubmit, "pending", "Saving…");
    bugfeedSubmit.disabled = true;
    bugfeedResult.textContent = "Saving private report…";
    try {
      let image = new Uint8Array();
      const pendingScreenshot = bugfeedScreenshot ? await bugfeedScreenshot : null;
      if (pendingScreenshot) image = new Uint8Array(await pendingScreenshot.arrayBuffer());
      const metadata = new TextEncoder().encode(JSON.stringify(bugfeedMetadata(image.length > 0)));
      const envelope = new Uint8Array(13 + metadata.length + image.length);
      envelope.set([0x4b, 0x42, 0x46, 0x31, 1]);
      const view = new DataView(envelope.buffer);
      view.setUint32(5, metadata.length);
      view.setUint32(9, image.length);
      envelope.set(metadata, 13);
      envelope.set(image, 13 + metadata.length);
      const response = await fetch("/bugfeed", {
        method: "POST",
        headers: { "Content-Type": "application/octet-stream" },
        body: envelope,
      });
      if (!response.ok) throw new Error("Bugfeed upload failed (HTTP " + response.status + ")");
      const result = await response.json();
      if (!/^[0-9a-f-]{36}$/.test(result.id || "")) throw new Error("invalid Bugfeed report ID");
      bugfeedResult.textContent = "Report ID: " + result.id + " — paste this ID to retrieve it.";
      bugfeedSubmit.disabled = true;
      setAsyncButtonState(bugfeedSubmit, "success", "Saved");
      if (bugfeedCopyButton) bugfeedActions.removeChild(bugfeedCopyButton);
      const copyButton = document.createElement("button");
      copyButton.type = "button";
      copyButton.textContent = "Copy ID";
      copyButton.addEventListener("click", async () => {
        try {
          await navigator.clipboard.writeText(result.id);
          bugfeedResult.textContent = "Copied report ID: " + result.id;
        } catch {
          bugfeedResult.textContent = "Report ID: " + result.id + " (select and copy)";
        }
      });
      bugfeedCopyButton = copyButton;
      bugfeedActions.insertBefore(copyButton, bugfeedCancel);
    } catch (error) {
      setAsyncButtonState(bugfeedSubmit, "error", "Retry");
      bugfeedSubmit.disabled = false;
    }
  }
  bugfeedButton.addEventListener("click", () => {
    bugfeedNotes.value = "";
    bugfeedResult.textContent = "Capturing screenshot…";
    bugfeedScreenshot = null;
    bugfeedCaptureStatus = status.textContent;
    bugfeedCaptureSize = null;
    try {
      const capture = captureScreenshot();
      bugfeedCaptureSize = { width: capture.width, height: capture.height };
      bugfeedScreenshot = screenshotBlob(capture).catch((error) => {
        bugfeedResult.textContent =
          "Screenshot unavailable; notes and diagnostics can still be saved. " + error.message;
        return null;
      });
      bugfeedScreenshot.then((image) => {
        if (image) bugfeedResult.textContent = "Screenshot captured. Add notes and save.";
      });
    } catch (error) {
      bugfeedResult.textContent =
        "Screenshot unavailable; notes and diagnostics can still be saved. " + error.message;
    }
    bugfeedSubmit.disabled = false;
    bugfeedSubmit.textContent = "Save report";
    if (bugfeedCopyButton) {
      bugfeedActions.removeChild(bugfeedCopyButton);
      bugfeedCopyButton = null;
    }
    bugfeedDialog.showModal();
    bugfeedNotes.focus();
  });
  bugfeedCancel.addEventListener("click", () => bugfeedDialog.close());
  bugfeedSubmit.addEventListener("click", saveBugfeedReport);




  function setStatus(value, color) {
    status.textContent = value;
    status.classList.toggle("kookie-session-error", Boolean(color === "#f87171"));
    status.style.color = color || "#f4d26d";
    if (statusTimer !== null) window.clearTimeout(statusTimer);
    statusTimer = window.setTimeout(() => {
      status.textContent = "";
      statusTimer = null;
    }, color === "#f87171" ? 5000 : 2400);
  }
  function setRuntimeState(value, color) {
    const state = value.split(" / ")[0].toLowerCase();
    runtimeState.textContent = state === "ready" ? "PLAYING"
      : state === "idle" ? "READY TO PLAY"
      : state === "failed" || state === "rejected" ? "CONNECTION LOST"
      : state.toUpperCase();
    runtimeState.style.color = color || "#dce8cc";
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
      const actor = (scene.actors || []).find((candidate) =>
        candidate.id === label.id && candidate.health > 0
      );
      if (!actor) continue;
      const headHeight = actor.kind === 2 ? 16 : 20;
      const projection = sceneRenderer?.projectWorld?.(
        scene, actor.x, actor.y + headHeight, actor.z,
      );
      if (!projection || projection.x < 0 || projection.x > 1 ||
          projection.y < 0 || projection.y > 1) continue;
      const dxCamera = actor.x - (scene.camera?.x ?? scene.playerX);
      const dyCamera = actor.y + headHeight -
        (scene.camera?.y ?? scene.playerY + 8);
      const dzCamera = actor.z - (scene.camera?.z ?? scene.playerZ - 16);
      if (dxCamera * dxCamera + dyCamera * dyCamera +
          dzCamera * dzCamera > 180 * 180) continue;
      // Tags are target cues, not persistent overhead clutter.
      if (Math.abs(projection.x - 0.5) > 0.09 ||
          Math.abs(projection.y - 0.5) > 0.16) continue;
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
  function predictPendingLocalMovement(now) {
    if (!sceneState || pendingInputFrames.size === 0 ||
        remoteSnapshots.length < 2) return false;
    let latestInput = null;
    for (const input of pendingInputFrames.values()) latestInput = input;
    if (!latestInput || (latestInput.moveX === 0 && latestInput.moveZ === 0)) return false;
    const latest = remoteSnapshots[remoteSnapshots.length - 1];
    const previous = remoteSnapshots[remoteSnapshots.length - 2];
    const span = latest.receivedAt - previous.receivedAt;
    if (span <= 0) return false;
    let latestActor = null;
    let previousActor = null;
    for (const actor of latest.actors) {
      if (actor.id === sceneState.playerId) { latestActor = actor; break; }
    }
    for (const actor of previous.actors) {
      if (actor.id === sceneState.playerId) { previousActor = actor; break; }
    }
    if (!latestActor || !previousActor) return false;
    const velocityX = (latestActor.x - previousActor.x) / span;
    const velocityZ = (latestActor.z - previousActor.z) / span;
    const speed = Math.hypot(velocityX, velocityZ);
    const elapsed = Math.min(LOCAL_MAX_EXTRAPOLATION_MS,
      Math.max(0, now - Math.max(latest.receivedAt, latestInput.sentAt)));
    if (speed <= 0 || elapsed <= 0) return false;
    const magnitude = Math.hypot(latestInput.moveX, latestInput.moveZ);
    localRenderPosition.x = Math.max(GAME_WORLD_MINIMUM_X,
      Math.min(GAME_WORLD_MAXIMUM_X,
        latestActor.x + latestInput.moveX / magnitude * speed * elapsed));
    localRenderPosition.z = Math.max(GAME_WORLD_MINIMUM_Z,
      Math.min(GAME_WORLD_MAXIMUM_Z,
        latestActor.z + latestInput.moveZ / magnitude * speed * elapsed));
    return true;
  }

  function currentLocalRenderPosition(now) {
    if (sceneState && Number.isInteger(sceneState.playerId) &&
        sceneState.playerId > 0) {
      if (predictPendingLocalMovement(now)) {
        localMovementBlend = null;
        return localRenderPosition;
      }
      const player = sampleRemoteActor(
        sceneState.playerId, now, LOCAL_MAX_EXTRAPOLATION_MS,
      );
      if (player) {
        localMovementBlend = null;
        localRenderPosition.x = player.x;
        localRenderPosition.z = player.z;
        return localRenderPosition;
      }
    }
    const blend = localMovementBlend;
    if (!blend) {
      localRenderPosition.x = sceneState.playerX;
      localRenderPosition.z = sceneState.playerZ;
      return localRenderPosition;
    }
    const amount = Math.max(0, Math.min(1,
      (now - blend.startedAt) / blend.duration));
    localRenderPosition.x = blend.startX +
      (blend.endX - blend.startX) * amount;
    localRenderPosition.z = blend.startZ +
      (blend.endZ - blend.startZ) * amount;
    if (amount >= 1) localMovementBlend = null;
    return localRenderPosition;
  }

  function beginLocalMovementBlend(endX, endZ, duration, now) {
    const current = currentLocalRenderPosition(now);
    localMovementBlend = {
      startX: current.x,
      startZ: current.z,
      endX,
      endZ,
      startedAt: now,
      duration: Math.max(1, duration),
    };
  }

  function recordRemoteSnapshot(scene, receivedAt) {
    if (!Array.isArray(scene.actors)) return;
    const last = remoteSnapshots[remoteSnapshots.length - 1];
    if (last && (scene.tick <= last.tick || receivedAt <= last.receivedAt)) return;
    if (previousRemoteArrivalAt > 0 && previousRemoteTick >= 0) {
      const elapsed = receivedAt - previousRemoteArrivalAt;
      const tickSpan = Math.max(1, scene.tick - previousRemoteTick);
      const deviation = Math.abs(elapsed - tickSpan * REMOTE_BASE_TICK_MS);
      remoteArrivalJitterMs += (deviation - remoteArrivalJitterMs) / 16;
      const desiredDelay = 2 * REMOTE_BASE_TICK_MS +
        Math.min(REMOTE_MAX_RENDER_DELAY_MS / 2, remoteArrivalJitterMs * 2);
      remoteRenderDelayMs = Math.max(REMOTE_MIN_RENDER_DELAY_MS,
        Math.min(REMOTE_MAX_RENDER_DELAY_MS,
          remoteRenderDelayMs + (desiredDelay - remoteRenderDelayMs) * 0.1));
    }
    previousRemoteArrivalAt = receivedAt;
    previousRemoteTick = scene.tick;
    remoteSnapshots.push({
      tick: scene.tick,
      receivedAt,
      actors: scene.actors,
    });
    if (remoteSnapshots.length > REMOTE_SNAPSHOT_HISTORY) remoteSnapshots.shift();
  }


  function sampleRemoteActor(actorId, renderAt, maxExtrapolationMs = REMOTE_MAX_EXTRAPOLATION_MS) {
    if (remoteSnapshots.length === 0) return null;
    let from = remoteSnapshots[0];
    let to = null;
    for (const snapshot of remoteSnapshots) {
      if (snapshot.receivedAt <= renderAt) {
        from = snapshot;
      } else {
        to = snapshot;
        break;
      }
    }
    const fromActor = from.actors.find((actor) => actor.id === actorId);
    if (!fromActor) return null;
    let x = fromActor.x;
    let y = fromActor.y;
    let z = fromActor.z;
    let yaw = fromActor.yaw;
    if (to) {
      const toActor = to.actors.find((actor) => actor.id === actorId);
      if (!toActor) return null;
      const span = to.receivedAt - from.receivedAt;
      const amount = span > 0
        ? Math.max(0, Math.min(1, (renderAt - from.receivedAt) / span))
        : 1;
      x += (toActor.x - x) * amount;
      y += (toActor.y - y) * amount;
      z += (toActor.z - z) * amount;
      const yawDelta = ((toActor.yaw - yaw + 540) % 360) - 180;
      yaw = (yaw + yawDelta * amount + 360) % 360;
    } else {
      const latest = remoteSnapshots[remoteSnapshots.length - 1];
      const previous = remoteSnapshots[remoteSnapshots.length - 2];
      const latestActor = latest.actors.find((actor) => actor.id === actorId);
      const previousActor = previous?.actors.find((actor) => actor.id === actorId);
      const span = previous ? latest.receivedAt - previous.receivedAt : 0;
      const ahead = Math.min(
        maxExtrapolationMs,
        Math.max(0, renderAt - latest.receivedAt),
      );
      if (latestActor && previousActor && span > 0) {
        const amount = ahead / span;
        x = latestActor.x + (latestActor.x - previousActor.x) * amount;
        y = latestActor.y + (latestActor.y - previousActor.y) * amount;
        z = latestActor.z + (latestActor.z - previousActor.z) * amount;
        const yawDelta = ((latestActor.yaw - previousActor.yaw + 540) % 360) - 180;
        yaw = (latestActor.yaw + yawDelta * amount + 360) % 360;
      } else if (latestActor) {
        x = latestActor.x;
        y = latestActor.y;
        z = latestActor.z;
        yaw = latestActor.yaw;
      }
    }
    remoteRenderPosition.x = x;
    remoteRenderPosition.y = y;
    remoteRenderPosition.z = z;
    remoteRenderPosition.yaw = yaw;
    return remoteRenderPosition;
  }

  function updateRemoteRenderActors(renderAt) {
    if (!renderSceneState) return;
    const sampleAt = renderAt - remoteRenderDelayMs;
    for (const actor of renderSceneState.actors) {
      const position = sampleRemoteActor(actor.id, sampleAt);
      if (!position) continue;
      actor.x = position.x;
      actor.y = position.y;
      actor.z = position.z;
      actor.yaw = position.yaw;
    }
  }
  function updateScene(scene) {
    sceneState = scene;
    renderSceneState = {
      ...scene,
      camera: { ...scene.camera },
      actors: scene.actors.map((actor) => ({ ...actor })),
    };
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
  function applyAuthoritativeScene(scene, snapshotSequence) {
    if (snapshotSequence < lastSnapshotSequence) return;
    lastSnapshotSequence = snapshotSequence;
    const now = performance.now();
    recordRemoteSnapshot(scene, now);
    const acknowledgedSequence = scene.lastInputSequence || 0;
    for (const sequenceNumber of pendingMovement.keys()) {
      if (sequenceNumber <= acknowledgedSequence) pendingMovement.delete(sequenceNumber);
    }
    for (const sequenceNumber of pendingInputFrames.keys()) {
      if (sequenceNumber <= acknowledgedSequence) pendingInputFrames.delete(sequenceNumber);
    }
    const displayed = { ...scene, camera: { ...scene.camera } };
    for (const [sequenceNumber, command] of pendingMovement) {
      if (sequenceNumber <= acknowledgedSequence) continue;
      let deltaX = 0;
      let deltaZ = 0;
      if (command === GAME_MOVE_LEFT || command === GAME_STRAFE_LEFT) deltaX = -8;
      else if (command === GAME_MOVE_RIGHT || command === GAME_STRAFE_RIGHT) deltaX = 8;
      else if (command === GAME_MOVE_FORWARD) deltaZ = 8;
      else if (command === GAME_MOVE_BACK) deltaZ = -8;
      displayed.playerX = Math.max(GAME_WORLD_MINIMUM_X,
        Math.min(GAME_WORLD_MAXIMUM_X, displayed.playerX + deltaX));
      displayed.playerZ = Math.max(GAME_WORLD_MINIMUM_Z,
        Math.min(GAME_WORLD_MAXIMUM_Z, displayed.playerZ + deltaZ));
      displayed.camera.x += deltaX;
      displayed.camera.z += deltaZ;
    }
    if (Math.abs(displayed.playerX - sceneState.playerX) > 0.01 ||
        Math.abs(displayed.playerZ - sceneState.playerZ) > 0.01) {
      beginLocalMovementBlend(displayed.playerX, displayed.playerZ, 90, now);
    }
    updateScene(displayed);
  }

  function renderFrame(time) {
    if (!sceneRenderer) return;
    const now = performance.now();
    const position = currentLocalRenderPosition(now);
    renderSceneState.playerX = position.x;
    renderSceneState.playerZ = position.z;
    renderSceneState.camera.x += position.x - sceneState.playerX;
    renderSceneState.camera.z += position.z - sceneState.playerZ;
    updateRemoteRenderActors(now);
    try {
      sceneRenderer.render(renderSceneState, time);
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
    } finally {
      renderSceneState.camera.x = sceneState.camera.x;
      renderSceneState.camera.z = sceneState.camera.z;
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
  let pingTimer = null;
  const pingSentTimes = new Map();
  const pendingMovement = new Map();
  const pendingInputFrames = new Map();
  let lastSnapshotSequence = 0;
  let reconnectTimer = null;
  let reconnectAttempt = 0;
  let shuttingDown = false;
  let intentionalDisconnect = false;
  const MAX_RECONNECT_ATTEMPTS = 5;
  function setGameControlsEnabled(enabled) {
    for (const button of gameActionButtons) button.disabled = !enabled;
    for (const stick of analogSticks) stick.setEnabled(enabled);
  }
  function clearReconnectTimer() {
    if (reconnectTimer !== null) window.clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  function nextSequence() {
    sequence += 1;
    if (sequence > MAX_SEQUENCE) {
      sequence = 1;
      pendingMovement.clear();
      pendingInputFrames.clear();
      pingSentTimes.clear();
      lastSnapshotSequence = 0;
    }
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
      if (words.length === 10 && words[3] === GAME_JOIN_RESPONSE_MARKER) {
        return (words[4] === 0 || words[4] === 1) &&
          (words[5] === GAME_ROLE_PLAYER || words[5] === GAME_ROLE_SPECTATOR) &&
          words[6] >= 0 && words[6] <= 1000000 &&
          words[7] >= 0 && words[7] <= 8 &&
          words[8] >= 0 && words[8] <= 4 &&
          (words[4] === 0 || words[6] > 0) &&
          words[9] === messageChecksum(words.slice(0, 9));
      }
      if (words.length >= 19 && words[3] === GAME_MULTIPLAYER_SNAPSHOT_MARKER) {
        const actorCount = words[17];
        if (!Number.isInteger(actorCount) || actorCount < 0 || actorCount > 8 ||
            (words.length !== 19 + actorCount * 8 &&
              words.length !== 23 + actorCount * 8 +
                words[19 + actorCount * 8] * 7 +
                words[20 + actorCount * 8] * 8 +
                words[21 + actorCount * 8] * 8)) {
          return false;
        }
        const actorIds = new Set();
        for (let index = 0; index < actorCount; index += 1) {
          const offset = 18 + index * 8;
          const id = words[offset];
          const x = words[offset + 1];
          const y = words[offset + 2];
          const z = words[offset + 3];
          const health = words[offset + 4];
          const state = words[offset + 5];
          const actorKind = words[offset + 6];
          const actorYaw = words[offset + 7];
          if (id <= 0 || id > 1000000 || actorIds.has(id) ||
              x < GAME_WORLD_MINIMUM_X || x > GAME_WORLD_MAXIMUM_X ||
              y < GAME_WORLD_MINIMUM_Y || y > GAME_WORLD_MAXIMUM_Y ||
              z < GAME_WORLD_MINIMUM_Z || z > GAME_WORLD_MAXIMUM_Z ||
              health < 0 || health > GAME_MAXIMUM_HEALTH ||
              state < 0 || state > 7 || actorKind < 1 || actorKind > 2 ||
              actorYaw < 0 || actorYaw > 359) {
            return false;
          }
          actorIds.add(id);
        }
        const trailer = 18 + actorCount * 8;
        if (words.length !== 19 + actorCount * 8) {
          const projectileCount = words[trailer + 1];
          const throwableCount = words[trailer + 2];
          const impactCount = words[trailer + 3];
          if (!Number.isInteger(words[trailer]) || words[trailer] < 0 ||
              words[trailer] > MAX_SEQUENCE ||
              !Number.isInteger(projectileCount) || projectileCount < 0 ||
              projectileCount > 12 || !Number.isInteger(throwableCount) ||
              throwableCount < 0 || throwableCount > 4 ||
              !Number.isInteger(impactCount) || impactCount < 0 ||
              impactCount > 8 || words.length > MAX_WORDS) {
            return false;
          }
          let offset = trailer + 4;
          for (let index = 0; index < projectileCount; index += 1, offset += 7) {
            if (words[offset] <= 0 || words[offset + 1] < 0 ||
                words[offset + 1] > 1000000 || words[offset + 2] < 0 ||
                words[offset + 2] > 1000000 ||
                words[offset + 3] < GAME_WORLD_MINIMUM_X ||
                words[offset + 3] > GAME_WORLD_MAXIMUM_X ||
                words[offset + 4] < GAME_WORLD_MINIMUM_Y ||
                words[offset + 4] > GAME_WORLD_MAXIMUM_Y ||
                words[offset + 5] < GAME_WORLD_MINIMUM_Z ||
                words[offset + 5] > GAME_WORLD_MAXIMUM_Z ||
                words[offset + 6] < 0 || words[offset + 6] > GAME_MAXIMUM_TICK) {
              return false;
            }
          }
          for (let index = 0; index < throwableCount; index += 1, offset += 8) {
            if (words[offset] <= 0 || words[offset + 1] < 0 ||
                words[offset + 1] > 1000000 ||
                words[offset + 2] < GAME_WORLD_MINIMUM_X ||
                words[offset + 2] > GAME_WORLD_MAXIMUM_X ||
                words[offset + 3] < GAME_WORLD_MINIMUM_Y ||
                words[offset + 3] > GAME_WORLD_MAXIMUM_Y ||
                words[offset + 4] < GAME_WORLD_MINIMUM_Z ||
                words[offset + 4] > GAME_WORLD_MAXIMUM_Z ||
                words[offset + 5] < 0 || words[offset + 6] < 1 ||
                words[offset + 6] > 4 ||
                words[offset + 7] < 0 ||
                words[offset + 7] > GAME_MAXIMUM_THROWABLE_FUSE_TICKS) return false;
          }
          for (let index = 0; index < impactCount; index += 1, offset += 8) {
            if (words[offset] < 0 || words[offset + 1] < 1 ||
                words[offset + 1] > 8 || words[offset + 2] < 0 ||
                words[offset + 2] > 1000000 || words[offset + 3] < 0 ||
                words[offset + 3] > 1000000 ||
                words[offset + 4] < GAME_WORLD_MINIMUM_X ||
                words[offset + 4] > GAME_WORLD_MAXIMUM_X ||
                words[offset + 5] < GAME_WORLD_MINIMUM_Y ||
                words[offset + 5] > GAME_WORLD_MAXIMUM_Y ||
                words[offset + 6] < GAME_WORLD_MINIMUM_Z ||
                words[offset + 6] > GAME_WORLD_MAXIMUM_Z ||
                words[offset + 7] < 0 || words[offset + 7] > GAME_MAXIMUM_HEALTH) return false;
          }
          if (offset + 1 !== words.length) return false;
        }
        const validSnapshot = words[4] >= 0 && words[4] <= GAME_MAXIMUM_TICK &&
          (words[5] === GAME_ROLE_PLAYER || words[5] === GAME_ROLE_SPECTATOR) &&
          words[6] >= 0 && words[6] <= 1000000 &&
          ((words[5] === GAME_ROLE_PLAYER && words[6] > 0) ||
            (words[5] === GAME_ROLE_SPECTATOR && words[6] === 0)) &&
          words[7] >= GAME_WORLD_MINIMUM_X && words[7] <= GAME_WORLD_MAXIMUM_X &&
          words[8] >= GAME_WORLD_MINIMUM_Y && words[8] <= GAME_WORLD_MAXIMUM_Y &&
          words[9] >= GAME_WORLD_MINIMUM_Z && words[9] <= GAME_WORLD_MAXIMUM_Z &&
          words[10] >= 0 && words[10] <= 359 &&
          words[11] >= -90 && words[11] <= 90 &&
          words[12] >= 0 && words[12] <= GAME_MAXIMUM_HEALTH &&
          words[13] >= 0 && words[13] <= GAME_MAXIMUM_STAMINA &&
          words[14] >= 0 && words[14] <= GAME_MAXIMUM_AMMO &&
          words[15] >= 0 && words[15] <= 8 &&
          words[16] >= 0 && words[16] <= 4 &&
          words[words.length - 1] === messageChecksum(words.slice(0, -1));
        return validSnapshot;
      }
      if (words.length === 5) {
        return words[3] === GAME_PROBE_PAYLOAD &&
          words[4] === messageChecksum(words.slice(0, 4));
      }
      if (words.length === 12 && words[3] === GAME_INPUT_MARKER) {
        return words[4] >= 0 && words[4] <= GAME_MAXIMUM_TICK &&
          words[5] >= -1000 && words[5] <= 1000 &&
          words[6] >= -1000 && words[6] <= 1000 &&
          words[7] >= -1800 && words[7] <= 1800 &&
          words[8] >= -1800 && words[8] <= 1800 &&
          words[9] >= 0 && words[9] <= 511 &&
          words[10] >= 0 && words[10] <= 511 &&
          words[11] === messageChecksum(words.slice(0, 11));
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
            (words[4] === GAME_LOOK_UP && words[5] === 15) ||
            (words[4] === GAME_LOOK_DOWN && words[5] === -15) ||
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

  let requestedRole = GAME_ROLE_PLAYER;
  let joinedRole = null;
  let joinSequence = 0;
  function sendJoinRequest() {
    if (!socket || socket.readyState !== WebSocket.OPEN || !connected) return;
    joinSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, joinSequence,
      GAME_JOIN_REQUEST_MARKER, requestedRole];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, joinSequence, words));
    setRuntimeState("joining as " +
      (requestedRole === GAME_ROLE_SPECTATOR ? "spectator" : "player"));
  }
  function parseMultiplayerScene(words) {
    const actors = [];
    for (let index = 0; index < words[17]; index += 1) {
      const offset = 18 + index * 8;
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
    const projectiles = [];
    const throwables = [];
    const impacts = [];
    let lastInputSequence = 0;
    const trailer = 18 + words[17] * 8;
    if (words.length !== 19 + words[17] * 8) {
      lastInputSequence = words[trailer];
      let offset = trailer + 4;
      for (let index = 0; index < words[trailer + 1]; index += 1, offset += 7) {
        projectiles.push({ id: words[offset], sourceId: words[offset + 1],
          targetId: words[offset + 2], x: words[offset + 3], y: words[offset + 4],
          z: words[offset + 5], ttl: words[offset + 6] });
      }
      for (let index = 0; index < words[trailer + 2]; index += 1, offset += 8) {
        throwables.push({ id: words[offset], sourceId: words[offset + 1],
          x: words[offset + 2], y: words[offset + 3], z: words[offset + 4],
          ttl: words[offset + 5], kind: words[offset + 6], fuseTicks: words[offset + 7] });
      }
      for (let index = 0; index < words[trailer + 3]; index += 1, offset += 8) {
        impacts.push({ sequence: words[offset], kind: words[offset + 1],
          sourceId: words[offset + 2], targetId: words[offset + 3],
          x: words[offset + 4], y: words[offset + 5], z: words[offset + 6],
          damage: words[offset + 7] });
      }
    }
    const playerX = words[7];
    const playerY = words[8];
    const playerZ = words[9];
    return {
      tick: words[4],
      lastInputSequence,
      role: words[5],
      playerId: words[6],
      playerX,
      playerY,
      playerZ,
      yaw: words[10],
      pitch: words[11],
      health: words[12],
      stamina: words[13],
      ammo: words[14],
      combo: 0,
      vfx: 0,
      camera: {
        x: playerX,
        y: playerY + 8,
        z: playerZ - 16,
        yaw: words[10],
        pitch: words[11],
      },
      actors,
      projectiles,
      throwables,
      impacts,
      pickup: null,
      sceneObjects: [],
      labels: [],
    };
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
    pingSentTimes.set(pingSequence, pingSentAt);
    while (pingSentTimes.size > 4) {
      pingSentTimes.delete(pingSentTimes.keys().next().value);
    }
    socket.send(encodeFrame(PING, pingSequence, words));
  }

  function sendGameProbe() {
    if (!socket || socket.readyState !== WebSocket.OPEN || !connected) return;
    const gameSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, gameSequence, GAME_PROBE_PAYLOAD];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, gameSequence, words));
    setStatus("PROTOCOL ECHO SENT sequence=" + gameSequence, "#93c5fd");
  }


  function sendGameplayInput(changes = {}) {
    if (!sceneRenderer || !socket || socket.readyState !== WebSocket.OPEN ||
        !authoritativeReady || joinedRole === GAME_ROLE_SPECTATOR) return;
    if (Number.isFinite(changes.moveX)) gameplayMoveX = Math.max(-1000, Math.min(1000, changes.moveX));
    if (Number.isFinite(changes.moveZ)) gameplayMoveZ = Math.max(-1000, Math.min(1000, changes.moveZ));
    const inputSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, inputSequence,
      GAME_INPUT_MARKER, Math.max(0, Math.min(GAME_MAXIMUM_TICK, sceneState?.tick || 0)),
      gameplayMoveX, gameplayMoveZ,
      Math.round((changes.lookYaw || 0) * 10),
      Math.round((changes.lookPitch || 0) * 10),
      changes.heldActions ?? gameplayHeldActions,
      changes.edgeActions || 0];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, inputSequence, words));
    pendingInputFrames.set(inputSequence, {
      moveX: gameplayMoveX,
      moveZ: gameplayMoveZ,
      sentAt: performance.now(),
    });
    if (pendingInputFrames.size > MAX_PENDING_INPUT_FRAMES) {
      pendingInputFrames.delete(pendingInputFrames.keys().next().value);
    }
  }
  function sendGameCommand(command, value, predictionDurationMs = 180) {
    if (!sceneRenderer || !socket || socket.readyState !== WebSocket.OPEN ||
        !authoritativeReady || joinedRole === GAME_ROLE_SPECTATOR) return;
    const gameSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, gameSequence,
      GAME_COMMAND_MARKER, command, value];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, gameSequence, words));
    if ([GAME_MOVE_LEFT, GAME_MOVE_RIGHT, GAME_MOVE_FORWARD, GAME_MOVE_BACK,
      GAME_STRAFE_LEFT, GAME_STRAFE_RIGHT].includes(command) &&
        pendingMovement.size < 128) {
      pendingMovement.set(gameSequence, command);
      const predicted = { ...sceneState, camera: { ...sceneState.camera } };
      let deltaX = 0;
      let deltaZ = 0;
      if (command === GAME_MOVE_LEFT || command === GAME_STRAFE_LEFT) deltaX = -8;
      else if (command === GAME_MOVE_RIGHT || command === GAME_STRAFE_RIGHT) deltaX = 8;
      else if (command === GAME_MOVE_FORWARD) deltaZ = 8;
      else if (command === GAME_MOVE_BACK) deltaZ = -8;
      predicted.playerX = Math.max(GAME_WORLD_MINIMUM_X,
        Math.min(GAME_WORLD_MAXIMUM_X, predicted.playerX + deltaX));
      predicted.playerZ = Math.max(GAME_WORLD_MINIMUM_Z,
        Math.min(GAME_WORLD_MAXIMUM_Z, predicted.playerZ + deltaZ));
      predicted.camera.x += deltaX;
      predicted.camera.z += deltaZ;
      beginLocalMovementBlend(
        predicted.playerX, predicted.playerZ,
        predictionDurationMs, performance.now(),
      );
      updateScene(predicted);
    }
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
    if (pingTimer !== null) window.clearInterval(pingTimer);
    pingTimer = null;
    pingSentTimes.clear();
    pendingMovement.clear();
    pendingInputFrames.clear();
    lastSnapshotSequence = 0;
    joinedRole = null;
    joinSequence = 0;
    remoteSnapshots.length = 0;
    remoteArrivalJitterMs = 0;
    previousRemoteArrivalAt = 0;
    previousRemoteTick = -1;
    localMovementBlend = null;
    intentionalDisconnect = explicit;
    if (explicit) {
      clearReconnectTimer();
      reconnectAttempt = 0;
    }
    setAsyncButtonState(connectButton, "idle", "PLAY");
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
      requestedRole = roleSelect.value === "spectator"
        ? GAME_ROLE_SPECTATOR : GAME_ROLE_PLAYER;
      const expectedPath = requestedRole === GAME_ROLE_SPECTATOR
        ? "/spectate" : "/session";
      url.pathname = expectedPath;
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
    connectButton.textContent = "LEAVE";
    setAsyncButtonState(connectButton, "pending", "LEAVE");
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
          if (pingTimer !== null) window.clearInterval(pingTimer);
          pingTimer = window.setInterval(sendPing, 2000);
          sendJoinRequest();
        } else if (frame.kind === PONG) {
          const sentAt = pingSentTimes.get(frame.sequence);
          if (sentAt !== undefined) {
            const latency = Math.round(performance.now() - sentAt);
            pingSentTimes.delete(frame.sequence);
            const previousLatency = Number.parseInt(hudValues.ping.textContent, 10);
            const pingValue = hudValues.ping;
            pingValue.dataset.trend = Number.isFinite(previousLatency) && latency < previousLatency
              ? "up" : Number.isFinite(previousLatency) && latency > previousLatency
                ? "down" : "";
            pingValue.dataset.flashing = "true";
            pingValue.textContent = latency + " ms";
            if (pingFlashTimer !== null) window.clearTimeout(pingFlashTimer);
            pingFlashTimer = window.setTimeout(() => {
              pingValue.dataset.flashing = "false";
              pingFlashTimer = null;
            }, 450);
          }
        } else if (frame.kind === GAME) {
          if (frame.words[3] === GAME_JOIN_RESPONSE_MARKER) {
            if (frame.sequence !== joinSequence || frame.words[4] !== 1 ||
                frame.words[5] !== requestedRole) {
              throw new Error("multiplayer join rejected");
            }
            joinedRole = frame.words[5];
            setRuntimeState("joined / " +
              (joinedRole === GAME_ROLE_SPECTATOR ? "spectator" : "player"),
              "#4ade80");
            setStatus("JOINED / player=" + frame.words[6] +
              " players=" + frame.words[7] +
              " spectators=" + frame.words[8], "#4ade80");
          } else if (frame.words[3] === GAME_MULTIPLAYER_SNAPSHOT_MARKER) {
            const scene = parseMultiplayerScene(frame.words);
            if (joinedRole === null || scene.role !== joinedRole) {
              throw new Error("multiplayer snapshot role mismatch");
            }
            authoritativeReady = true;
            setGameControlsEnabled(joinedRole === GAME_ROLE_PLAYER);
            setAsyncButtonState(connectButton, "success", "LEAVE");
            applyAuthoritativeScene(scene, frame.sequence);
            setRuntimeState(joinedRole === GAME_ROLE_SPECTATOR
              ? "spectating" : "in game", "#4ade80");
            setStatus("");
          } else if (frame.words[3] === GAME_PROBE_PAYLOAD) {
            setStatus("PROTOCOL ECHO RECEIVED sequence=" + frame.sequence, "#4ade80");
          } else if (frame.words[3] === GAME_SNAPSHOT_MARKER) {
            authoritativeReady = true;
            setGameControlsEnabled(true);
            setAsyncButtonState(connectButton, "success", "LEAVE");
            applyAuthoritativeScene({
              ...sceneState,
              tick: frame.words[4], playerX: frame.words[5], health: frame.words[6],
              stamina: frame.words[7], combo: frame.words[8], vfx: frame.words[9],
            }, frame.sequence);
            setRuntimeState("in game", "#4ade80");
            setStatus("");
          } else if (frame.words[3] === GAME_FULL_SCENE_SNAPSHOT_MARKER) {
            authoritativeReady = true;
            setGameControlsEnabled(true);
            setAsyncButtonState(connectButton, "success", "LEAVE");
            applyAuthoritativeScene(parseScene(frame.words), frame.sequence);
            setRuntimeState("in game", "#4ade80");
            setStatus("");
          } else if (frame.words[3] === GAME_SCENE_SNAPSHOT_MARKER) {
            authoritativeReady = true;
            setGameControlsEnabled(true);
            applyAuthoritativeScene(parseLegacyScene(frame.words), frame.sequence);
            setRuntimeState("in game", "#4ade80");
            setStatus("");
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
      connectButton.textContent = "PLAY";
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

  const heldMovementKeys = new Set();
  const movementKeys = new Map([
    ["KeyW", [0, 1]], ["ArrowUp", [0, 1]],
    ["KeyS", [0, -1]], ["ArrowDown", [0, -1]],
    ["KeyA", [-1, 0]], ["ArrowLeft", [-1, 0]],
    ["KeyD", [1, 0]], ["ArrowRight", [1, 0]],
  ]);
  function updateKeyboardMovement() {
    let x = 0;
    let z = 0;
    for (const code of heldMovementKeys) {
      const axis = movementKeys.get(code);
      if (axis) { x += axis[0]; z += axis[1]; }
    }
    const magnitude = Math.hypot(x, z);
    const scale = magnitude > 0
      ? GAME_MAXIMUM_INPUT_AXIS * clientSettings.movementSpeedPercent / 100 / magnitude
      : 0;
    sendGameplayInput({ moveX: Math.round(x * scale), moveZ: Math.round(z * scale) });
  }
  document.addEventListener("keydown", (event) => {
    if (!authoritativeReady || joinedRole === GAME_ROLE_SPECTATOR ||
        event.ctrlKey || event.metaKey || event.altKey) return;
    const target = event.target;
    if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable)) return;
    const axis = movementKeys.get(event.code);
    if (axis) {
      event.preventDefault();
      if (!heldMovementKeys.has(event.code)) {
        heldMovementKeys.add(event.code);
        updateKeyboardMovement();
      }
      return;
    }
    if (event.key === "q" || event.key === "Q") {
      event.preventDefault();
      sendGameplayInput({ lookYaw: -15 });
    } else if (event.key === "e" || event.key === "E") {
      event.preventDefault();
      sendGameplayInput({ lookYaw: 15 });
    } else if (event.key === "r" || event.key === "R") {
      event.preventDefault();
      sendGameCommand(GAME_RESET, 0);
    }
  });
  document.addEventListener("keyup", (event) => {
    if (!heldMovementKeys.delete(event.code)) return;
    event.preventDefault();
    updateKeyboardMovement();
  });
  window.addEventListener("blur", () => {
    const hadMovement = heldMovementKeys.size > 0;
    const heldActions = gameplayHeldActions & (ACTION_JUMP | ACTION_GLIDE |
      ACTION_FLY | ACTION_SHOOT);
    heldMovementKeys.clear();
    gameplayHeldActions &= ~heldActions;
    if (hadMovement || heldActions !== 0) {
      updateKeyboardMovement();
      sendGameplayInput({ heldActions: gameplayHeldActions });
    }
  });

  const keyboardActionBits = new Map([
    [" ", [ACTION_JUMP, true]],
    ["shift", [ACTION_ROLL, false]], ["c", [ACTION_DASH, false]],
    ["g", [ACTION_GLIDE, true]], ["v", [ACTION_FLY, true]],
    ["b", [ACTION_SHOOT, true]], ["t", [ACTION_THROWABLE, false]],
  ]);
  document.addEventListener("keydown", (event) => {
    if (!authoritativeReady || joinedRole === GAME_ROLE_SPECTATOR) return;
    const action = keyboardActionBits.get(event.key.toLowerCase());
    if (!action || (action[1] && (gameplayHeldActions & action[0]))) return;
    if (action[1]) gameplayHeldActions |= action[0];
    event.preventDefault();
    sendGameplayInput({ heldActions: gameplayHeldActions,
      edgeActions: action[1] ? 0 : action[0] });
  });
  document.addEventListener("keyup", (event) => {
    const action = keyboardActionBits.get(event.key.toLowerCase());
    if (!action || !action[1] || !(gameplayHeldActions & action[0])) return;
    gameplayHeldActions &= ~action[0];
    sendGameplayInput({ heldActions: gameplayHeldActions });
  });
  function bindSceneInput() {
    let lookPointer = null;
    let lastLookX = 0;
    let lastLookY = 0;
    sceneCanvas.addEventListener("pointerdown", (event) => {
      if (!authoritativeReady) return;
      if (event.pointerType === "mouse" && clientSettings.pointerLock &&
          typeof sceneCanvas.requestPointerLock === "function") {
        sceneCanvas.requestPointerLock();
        return;
      }
      lookPointer = event.pointerId;
      lastLookX = event.clientX;
      lastLookY = event.clientY;
      if (typeof sceneCanvas.setPointerCapture === "function") {
        sceneCanvas.setPointerCapture(event.pointerId);
      }
      event.preventDefault();
    });
    sceneCanvas.addEventListener("pointermove", (event) => {
      if (!authoritativeReady) return;
      let deltaX = 0;
      let deltaY = 0;
      if (clientSettings.pointerLock && document.pointerLockElement === sceneCanvas) {
        deltaX = event.movementX;
        deltaY = event.movementY;
      } else if (event.pointerId === lookPointer) {
        deltaX = event.clientX - lastLookX;
        deltaY = event.clientY - lastLookY;
        lastLookX = event.clientX;
        lastLookY = event.clientY;
        if (event.pointerType === "touch") {
          sceneCanvasWrap.setAttribute("data-touch-look-started", "true");
        }
      }
      const sensitivity = clientSettings.mouseCameraSensitivityPercent / 100;
      const lookYaw = Math.max(-180, Math.min(180, deltaX * sensitivity * 1.25));
      const lookPitch = Math.max(-180, Math.min(180, -deltaY * sensitivity * 1.25));
      if (lookYaw !== 0 || lookPitch !== 0) {
        sendGameplayInput({ lookYaw, lookPitch });
      }
    });
    const releaseLook = (event) => {
      if (event.pointerId === lookPointer) {
        lookPointer = null;
      }
    };
    sceneCanvas.addEventListener("pointerup", releaseLook);
    sceneCanvas.addEventListener("pointercancel", releaseLook);
    sceneCanvas.addEventListener("lostpointercapture", releaseLook);
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
