(() => {
  "use strict";
  const MAGIC = [0x4b, 0x57, 0x53, 0x31];
  const FRAME_VERSION = 1;
  const NETCODE_PROTOCOL_VERSION = 2;
  const MAX_WORDS = 320;
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
  const RCON_SUBPROTOCOL_PREFIX = "rcon.";
  const RCON_SECRET_MINIMUM_LENGTH = 32;
  const GAME_ADMIN_MARKER = 11;
  const GAME_ADMIN_RESPONSE_MARKER = 12;
  const GAME_ADMIN_STATUS = 1;
  const GAME_ADMIN_KICK = 2;
  const GAME_ADMIN_SET_TEAM = 3;
  const GAME_ADMIN_SAY = 4;
  const GAME_ADMIN_MAPVOTE_START = 5;
  const AUTH_TOKEN_MINIMUM_LENGTH = 8;
  const AUTH_TOKEN_MAXIMUM_LENGTH = 128;
  const GAME_COMMAND_MARKER = 1;
  const GAME_SNAPSHOT_MARKER = 2;
  const GAME_SCENE_SNAPSHOT_MARKER = 3;
  const GAME_FULL_SCENE_SNAPSHOT_MARKER = 4;
  const GAME_JOIN_REQUEST_MARKER = 5;
  const GAME_JOIN_RESPONSE_MARKER = 6;
  const GAME_MULTIPLAYER_SNAPSHOT_MARKER = 7;
  const GAME_CHAT_MARKER = 9;
  const GAME_MAP_VOTE_MARKER = 13;
  const GAME_CHAT_RESPONSE_MARKER = 10;
  const CHAT_GLOBAL = 0;
  const CHAT_TEAM = 1;
  const CHAT_WHISPER = 2;
  const GAME_ROLE_PLAYER = 1;
  const GAME_ROLE_SPECTATOR = 2;
  const GAME_ROLE_TRAINING = 3;
  const GAME_ROLE_ADMIN = 4;
  const GAME_MOVE_LEFT = 1;
  const GAME_MOVE_RIGHT = 2;
  const GAME_MELEE = 3;
  const GAME_SPECIAL = 4;
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
  const GAME_MAXIMUM_SEED_AMMO = 30;
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
  const GAME_MAXIMUM_ACTOR_STATE = 3959;

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
    ["training", "Training · Goose vs combat dolls"],
    ["admin", "Remote administrator"],
  ]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = label;
    roleSelect.appendChild(option);
  }
  const roleParam = params.get("kookie_role");
  roleSelect.value = ["player", "spectator", "training", "admin"].includes(roleParam)
    ? roleParam : "player";
  roleLabel.appendChild(roleSelect);
  const teamLabel = document.createElement("label");
  teamLabel.textContent = "Player team";
  const teamSelect = document.createElement("select");
  teamSelect.setAttribute("aria-label", "Player team");
  for (const [value, label] of [["0", "Free for all"], ["1", "Red team"], ["2", "Blue team"]]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = label;
    teamSelect.appendChild(option);
  }
  teamLabel.appendChild(teamSelect);
  const tokenLabel = document.createElement("label");
  const tokenLabelText = document.createElement("span");
  tokenLabelText.textContent = "Session token (optional)";
  tokenLabel.appendChild(tokenLabelText);
  const authToken = document.createElement("input");
  authToken.type = "password";
  authToken.value = params.get("kookie_token") || "";
  authToken.setAttribute("aria-label", "Session authentication token");
  authToken.setAttribute("autocomplete", "off");
  authToken.placeholder = "8-128 safe ASCII characters";
  function updateRoleCredentialLabel() {
    const admin = roleSelect.value === "admin";
    tokenLabelText.textContent = admin ? "Remote admin secret (required)"
      : "Session token (optional)";
    authToken.setAttribute("aria-label", admin
      ? "Remote administrator secret" : "Session authentication token");
    authToken.placeholder = admin ? "32-128 safe ASCII characters"
      : "8-128 safe ASCII characters";
  }
  roleSelect.addEventListener("change", updateRoleCredentialLabel);
  updateRoleCredentialLabel();
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
    showDamageNumbers: storedSettings.showDamageNumbers !== false,
    pointerLock: storedSettings.pointerLock !== false,
    reducedMotion: storedSettings.reducedMotion === true ||
      (typeof window.matchMedia === "function" &&
        window.matchMedia("(prefers-reduced-motion: reduce)").matches),
    movementSpeedPercent: boundedPercent(storedSettings.movementSpeedPercent, 25, 50),
    mouseCameraSensitivityPercent: Number.isInteger(storedSettings.mouseCameraSensitivityPercent) &&
      storedSettings.mouseCameraSensitivityPercent >= 25 &&
      storedSettings.mouseCameraSensitivityPercent <= 150
      ? storedSettings.mouseCameraSensitivityPercent : 50,
    playerName: typeof storedSettings.playerName === "string"
      ? storedSettings.playerName.slice(0, 24) : "",
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
      if (key === "showDamageNumbers" && !input.checked) clearDamageNumberLabels();
      if (key === "reducedMotion") {
        panel.dataset.reducedMotion = input.checked ? "true" : "false";
        updateHitFeedbackOverlay(performance.now());
      }
    });
    label.appendChild(input);
    label.appendChild(document.createTextNode(labelText));
    settingsGrid.appendChild(label);
  }
  addSettingToggle("autoReconnect", "Reconnect automatically");
  addSettingToggle("showMinimap", "Show small arena map");
  addSettingToggle("showDamageNumbers", "Show damage numbers");
  addSettingToggle("pointerLock", "Use pointer lock for mouse look");
  addSettingToggle("reducedMotion", "Reduce interface motion");
  const playerNameLabel = document.createElement("label");
  playerNameLabel.textContent = "Player name";
  const playerNameInput = document.createElement("input");
  playerNameInput.type = "text";
  playerNameInput.maxLength = 24;
  playerNameInput.value = clientSettings.playerName;
  playerNameInput.setAttribute("aria-label", "Player name");
  playerNameInput.addEventListener("input", () => {
    clientSettings.playerName = playerNameInput.value.slice(0, 24);
    saveStoredSettings();
    if (sceneState) updateProjectedLabels(sceneState);
  });
  playerNameLabel.appendChild(playerNameInput);
  settingsGrid.appendChild(playerNameLabel);
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
  addSettingRange("mouseCameraSensitivityPercent", "Camera sensitivity", 25, 150);
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
  settingsGrid.appendChild(teamLabel);
  settingsMenu.appendChild(endpointLabel);
  settingsMenu.appendChild(roleLabel);
  settingsMenu.appendChild(tokenLabel);
  settingsMenu.appendChild(settingsGrid);
  const gameConsoleButton = document.createElement("button");
  gameConsoleButton.type = "button";
  gameConsoleButton.textContent = "OPEN GAME CONSOLE";
  gameConsoleButton.setAttribute("aria-label", "Open game console");
  settingsGrid.appendChild(gameConsoleButton);

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
  sceneCanvasWrap.appendChild(sceneCanvas);
  const dealtHitFeedback = document.createElement("div");
  dealtHitFeedback.className = "kookie-dealt-hit-feedback";
  dealtHitFeedback.setAttribute("aria-hidden", "true");
  sceneCanvasWrap.appendChild(dealtHitFeedback);
  const labelOverlay = document.createElement("div");
  labelOverlay.id = "kookie-scene-labels";
  labelOverlay.className = "kookie-session-labels";
  labelOverlay.setAttribute("aria-label", "Visible player and animal labels");
  sceneCanvasWrap.appendChild(labelOverlay);
  const damageNumberLayer = document.createElement("div");
  damageNumberLayer.className = "kookie-damage-number-layer";
  damageNumberLayer.setAttribute("aria-hidden", "true");
  sceneCanvasWrap.appendChild(damageNumberLayer);
  const hitFeedbackLayer = document.createElement("div");
  hitFeedbackLayer.className = "kookie-hit-feedback-layer";
  hitFeedbackLayer.setAttribute("aria-hidden", "true");
  const hitFeedbackFlash = document.createElement("div");
  hitFeedbackFlash.className = "kookie-hit-feedback-flash";
  const hitDirectionIndicator = document.createElement("div");
  hitDirectionIndicator.className = "kookie-hit-direction";
  hitFeedbackLayer.appendChild(hitFeedbackFlash);
  hitFeedbackLayer.appendChild(hitDirectionIndicator);
  sceneCanvasWrap.appendChild(hitFeedbackLayer);
  const throwPrompt = document.createElement("span");
  throwPrompt.className = "kookie-throw-prompt";
  throwPrompt.hidden = true;
  throwPrompt.textContent = "PRESS T / PICK UP";
  throwPrompt.setAttribute("aria-hidden", "true");
  sceneCanvasWrap.appendChild(throwPrompt);
  const throwCharge = document.createElement("div");
  throwCharge.className = "kookie-throw-charge";
  throwCharge.hidden = true;
  throwCharge.setAttribute("role", "progressbar");
  throwCharge.setAttribute("aria-label", "Throw power");
  throwCharge.setAttribute("aria-valuemin", "0");
  throwCharge.setAttribute("aria-valuemax", "100");
  const chargeLabel = document.createElement("span");
  chargeLabel.textContent = "THROW";
  const chargeTrack = document.createElement("div");
  chargeTrack.className = "kookie-throw-charge-track";
  const chargeFill = document.createElement("div");
  chargeFill.className = "kookie-throw-charge-fill";
  chargeTrack.appendChild(chargeFill);
  const chargePercent = document.createElement("span");
  chargePercent.textContent = "0%";
  throwCharge.append(chargeLabel, chargeTrack, chargePercent);
  sceneCanvasWrap.appendChild(throwCharge);
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
  const hudLabels = {};
  const hudStats = {};
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
    hudLabels[key] = statLabel;
    hudStats[key] = stat;
  }
  addHudStat("tick", "TICK", "0");
  addHudStat("position", "PLAYER X / Z", "32 / 52");
  addHudStat("health", "HEALTH", "100");
  addHudStat("stamina", "STAMINA", "100");
  addHudStat("ammo", "AMMO", "24");
  addHudStat("combo", "COMBO", "0");
  addHudStat("actors", "ACTORS", "4");
  addHudStat("projectiles", "PROJECTILES", "0");
  addHudStat("oxygen", "OXYGEN", "--");
  addHudStat("ping", "PING", "--");
  addHudStat("match", "MATCH / MAP", "--");
  addHudStat("teams", "ALIVE · GEESE / CATS", "0 / 0");
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
  help.textContent = "Move/look: sticks or WASD/mouse · Hold T or PICK / THROW to charge, release to throw";
  sceneCanvasWrap.appendChild(help);
  const touchLookHint = document.createElement("span");
  touchLookHint.className = "kookie-session-touch-look";
  touchLookHint.setAttribute("aria-hidden", "true");
  touchLookHint.textContent = "RIGHT STICK TO LOOK";
  sceneCanvasWrap.appendChild(touchLookHint);
  const spectatorCameraControls = document.createElement("section");
  spectatorCameraControls.className = "kookie-spectator-camera";
  spectatorCameraControls.hidden = true;
  spectatorCameraControls.setAttribute("aria-label", "Spectator camera controls");
  const spectatorPreviousButton = document.createElement("button");
  spectatorPreviousButton.type = "button";
  spectatorPreviousButton.textContent = "PREV";
  spectatorPreviousButton.setAttribute("aria-label", "Follow previous player");
  const spectatorTargetLabel = document.createElement("span");
  spectatorTargetLabel.className = "kookie-spectator-target";
  spectatorTargetLabel.setAttribute("role", "status");
  spectatorTargetLabel.setAttribute("aria-live", "polite");
  spectatorTargetLabel.textContent = "FREE CAMERA";
  const spectatorNextButton = document.createElement("button");
  spectatorNextButton.type = "button";
  spectatorNextButton.textContent = "NEXT";
  spectatorNextButton.setAttribute("aria-label", "Follow next player");
  const spectatorFreeButton = document.createElement("button");
  spectatorFreeButton.type = "button";
  spectatorFreeButton.textContent = "FREE CAM";
  spectatorFreeButton.setAttribute("aria-label", "Switch to free camera");
  spectatorCameraControls.append(
    spectatorPreviousButton, spectatorTargetLabel, spectatorNextButton,
    spectatorFreeButton
  );
  sceneCanvasWrap.appendChild(spectatorCameraControls);
  const spectatorEventFeed = document.createElement("div");
  spectatorEventFeed.className = "kookie-spectator-events";
  spectatorEventFeed.hidden = true;
  spectatorEventFeed.setAttribute("aria-label", "Recent match events");
  spectatorEventFeed.setAttribute("aria-live", "polite");
  spectatorEventFeed.setAttribute("role", "status");
  sceneCanvasWrap.appendChild(spectatorEventFeed);
  spectatorPreviousButton.addEventListener("click", () => cycleSpectatorTarget(-1));
  spectatorNextButton.addEventListener("click", () => cycleSpectatorTarget(1));
  spectatorFreeButton.addEventListener("click", returnToFreeSpectatorCamera);
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
  const lookControls = document.createElement("div");
  lookControls.className = "kookie-session-stick";
  lookControls.setAttribute("role", "group");
  lookControls.setAttribute("aria-label", "Camera look analog stick. Mouse or touch-drag is also supported.");
  lookControls.setAttribute("data-analog-stick", "look");
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
    let frameHandle = 0;
    let lastFrameAt = 0;
    let vector = { x: 0, y: 0 };
    const wantsFrames = () =>
      pointerId !== null || Boolean(options.continueWhile?.());
    const schedule = () => {
      if (frameHandle !== 0 || !enabled || !wantsFrames()) return;
      frameHandle = window.requestAnimationFrame((timestamp) => {
        frameHandle = 0;
        if (!enabled) return;
        const deltaSeconds = lastFrameAt === 0 ? 1 / 60
          : Math.min(0.05, Math.max(0, (timestamp - lastFrameAt) / 1000));
        lastFrameAt = timestamp;
        onVector(vector, deltaSeconds);
        if (wantsFrames()) schedule();
        else lastFrameAt = 0;
      });
    };
    const reset = () => {
      if (pointerId !== null) onVector({ x: 0, y: 0 }, 0);
      pointerId = null;
      vector = { x: 0, y: 0 };
      knob.style.transform = "translate(0px, 0px)";
      destination.classList.remove("is-active");
      schedule();
    };
    const update = (event) => {
      const rect = base.getBoundingClientRect();
      const radius = Math.max(1, Math.min(rect.width, rect.height) * 0.38);
      let x = (event.clientX - (rect.left + rect.width / 2)) / radius;
      let y = (event.clientY - (rect.top + rect.height / 2)) / radius;
      const rawLength = Math.hypot(x, y);
      if (rawLength > 1) { x /= rawLength; y /= rawLength; }
      const length = Math.min(1, Math.hypot(x, y));
      const deadzone = 0.12;
      const outputLength = length <= deadzone ? 0
        : (length - deadzone) / (1 - deadzone);
      vector = length > 0
        ? { x: x / length * outputLength, y: y / length * outputLength }
        : { x: 0, y: 0 };
      knob.style.transform = "translate(" + (x * radius) + "px, " +
        (y * radius) + "px)";
      schedule();
    };
    base.addEventListener("pointerdown", (event) => {
      if (!enabled) return;
      event.preventDefault();
      pointerId = event.pointerId;
      destination.classList.add("is-active");
      if (typeof base.setPointerCapture === "function") base.setPointerCapture(pointerId);
      update(event);
      if (options.initialPulse) onVector(vector, 1 / 60);
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
  const movementSpeedScale = () => clientSettings.movementSpeedPercent / 100;
  addAnalogStick("MOVE", movementControls, (vector) => {
    const speed = joinedRole === GAME_ROLE_SPECTATOR ? 1 : movementSpeedScale();
    sendGameplayInput({
      moveX: Math.round(-vector.x * GAME_MAXIMUM_INPUT_AXIS * speed),
      moveZ: Math.round(-vector.y * GAME_MAXIMUM_INPUT_AXIS * speed),
    });
  }, { initialPulse: true });
  let lookStickVelocityX = 0;
  let lookStickVelocityY = 0;
  const lookStickSettling = () =>
    Math.abs(lookStickVelocityX) > 0.002 || Math.abs(lookStickVelocityY) > 0.002;
  addAnalogStick("LOOK", lookControls, (vector, deltaSeconds) => {
    const seconds = Math.max(1 / 240, Math.min(0.05, deltaSeconds || 1 / 60));
    const targetMagnitude = Math.hypot(vector.x, vector.y);
    const speedMagnitude = Math.hypot(lookStickVelocityX, lookStickVelocityY);
    const timeConstant = targetMagnitude > speedMagnitude ? 0.075 : 0.14;
    const blend = 1 - Math.exp(-seconds / timeConstant);
    lookStickVelocityX += (vector.x - lookStickVelocityX) * blend;
    lookStickVelocityY += (vector.y - lookStickVelocityY) * blend;
    if (targetMagnitude === 0 &&
        Math.abs(lookStickVelocityX) < 0.002 &&
        Math.abs(lookStickVelocityY) < 0.002) {
      lookStickVelocityX = 0;
      lookStickVelocityY = 0;
    }
    const sensitivity = clientSettings.mouseCameraSensitivityPercent / 100;
    const degreesPerSecond = 120 * sensitivity;
    sendGameplayInput({
      lookYaw: -lookStickVelocityX * degreesPerSecond * seconds,
      lookPitch: -lookStickVelocityY * degreesPerSecond * seconds,
    });
  }, { continueWhile: lookStickSettling });
  function addGameAction(label, command, value, destination, options = {}) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.disabled = true;
    button.setAttribute("aria-label", options.ariaLabel || label);
    if (options.action) button.setAttribute("data-action", options.action);
    const bit = options.bit || 0;
    let activePointer = null;
    if (bit) {
      const down = (event) => {
        if (button.disabled || activePointer !== null) return;
        event.preventDefault();
        activePointer = event.pointerId;
        if (options.held) gameplayHeldActions |= bit;
        if (options.held && typeof button.setPointerCapture === "function") {
          button.setPointerCapture(event.pointerId);
        }
        sendGameplayInput({ heldActions: gameplayHeldActions,
          edgeActions: options.edge ? bit : 0 });
      };
      const up = (event) => {
        if (activePointer !== null && event.pointerId !== undefined &&
            event.pointerId !== activePointer) return;
        activePointer = null;
        if (!options.held || !(gameplayHeldActions & bit)) return;
        gameplayHeldActions &= ~bit;
        sendGameplayInput({ heldActions: gameplayHeldActions });
      };
      button.addEventListener("pointerdown", down);
      button.addEventListener("pointerup", up);
      button.addEventListener("pointercancel", up);
      button.addEventListener("lostpointercapture", up);
      button.addEventListener("click", (event) => {
        if (event.detail !== 0) return;
        if (!options.held) {
          if (options.edge) sendGameplayInput({ edgeActions: bit });
          return;
        }
        if (!(gameplayHeldActions & bit)) {
          gameplayHeldActions |= bit;
          sendGameplayInput({ heldActions: gameplayHeldActions,
            edgeActions: options.edge ? bit : 0 });
          window.setTimeout(() => {
            gameplayHeldActions &= ~bit;
            sendGameplayInput({ heldActions: gameplayHeldActions });
          }, 100);
        }
      });
    } else {
      button.addEventListener("click", () => sendGameCommand(command, value));
    }
    gameActionButtons.push(button);
    destination.appendChild(button);
    return button;
  }
  addGameAction("JUMP", GAME_JUMP, 0, actionControls, { action: "jump", bit: ACTION_JUMP, edge: true, held: true });
  addGameAction("ROLL", 0, 0, actionControls, { action: "roll", bit: ACTION_ROLL, edge: true });
  addGameAction("DASH", 0, 0, actionControls, { action: "dash", bit: ACTION_DASH, edge: true });
  addGameAction("GLIDE", 0, 0, actionControls, { action: "glide", bit: ACTION_GLIDE, held: true });
  addGameAction("FLY", 0, 0, actionControls, { action: "fly", bit: ACTION_FLY, held: true });
  addGameAction("SHOOT", GAME_FIRE, 0, actionControls, { action: "shoot", bit: ACTION_SHOOT, held: true });
  addGameAction("MELEE", GAME_MELEE, 0, actionControls, { action: "melee", bit: ACTION_MELEE, edge: true });
  addGameAction("SPECIAL", GAME_SPECIAL, 0, actionControls, { action: "special", bit: ACTION_SPECIAL, edge: true });
  const throwableActionButton = addGameAction("PICK", 0, 0, actionControls, {
    action: "throwable", ariaLabel: "Pick up item; hold to charge, release to throw",
    bit: ACTION_THROWABLE, held: true,
  });
  gameControls.appendChild(movementControls);
  gameControls.appendChild(lookControls);
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
  const controlGroups = {
    move: movementControls, look: lookControls,
    ...Object.fromEntries([...actionControls.children].map((button) => [
      "action:" + button.dataset.action, button,
    ])),
  };
  const clampLayoutPoint = (point, fallback, element) => {
    const width = Math.max(1, window.innerWidth);
    const height = Math.max(1, window.innerHeight);
    const rect = element?.getBoundingClientRect();
    const horizontalMargin = Math.min(
      49, ((rect?.width || 0) / 2 + 6) / width * 100,
    );
    const verticalMargin = Math.min(
      49, ((rect?.height || 0) / 2 + 6) / height * 100,
    );
    const x = Number.isFinite(point?.x) ? point.x : fallback.x;
    const y = Number.isFinite(point?.y) ? point.y : fallback.y;
    return {
      x: Math.max(horizontalMargin, Math.min(100 - horizontalMargin, x)),
      y: Math.max(verticalMargin, Math.min(100 - verticalMargin, y)),
    };
  };
  const touchLayoutState = readTouchLayouts();
  const defaultTouchLayout = {
    move: { x: 12, y: 80 },
    look: { x: 78, y: 80 },
    ...Object.fromEntries([...actionControls.children].map((button, index) => [
      "action:" + button.dataset.action,
      { x: 89 + (index % 3 - 1) * 6, y: 57 + Math.floor(index / 3) * 7 },
    ])),
  };
  const validTouchLayout = (layout) => Object.fromEntries(
    Object.entries(controlGroups).map(([name, element]) => [
      name,
      clampLayoutPoint(
        layout?.[name] || (name.startsWith("action:") ? layout?.actions : null),
        defaultTouchLayout[name], element,
      ),
    ]),
  );
  const touchPresets = touchLayoutState.presets &&
    typeof touchLayoutState.presets === "object" ? touchLayoutState.presets : {};
  let activeTouchLayout = touchLayoutState.activeName &&
    touchPresets[touchLayoutState.activeName]
    ? validTouchLayout(touchPresets[touchLayoutState.activeName])
    : touchLayoutState.activeLayout ? validTouchLayout(touchLayoutState.activeLayout) : null;
  let touchLayoutEditing = false;
  const applyTouchLayout = (layout) => {
    for (const [name, element] of Object.entries(controlGroups)) {
      const point = layout?.[name]
        ? clampLayoutPoint(layout[name], defaultTouchLayout[name], element)
        : null;
      if (!point) {
        element.style.position = "";
        element.style.left = "";
        element.style.top = "";
        element.style.transform = "";
        continue;
      }
      layout[name] = point;
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
  window.addEventListener("resize", () => {
    if (!activeTouchLayout) return;
    activeTouchLayout = validTouchLayout(activeTouchLayout);
    applyTouchLayout(activeTouchLayout);
    persistTouchLayout();
    if (!layoutEditor.hidden) syncLayoutSliders();
  });
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
  for (const [value, label] of [
    ["move", "Movement stick"], ["look", "Camera look stick"],
    ...[...actionControls.children].map((button) => [
      "action:" + button.dataset.action, button.textContent,
    ]),
  ]) {
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
    for (const [name, element] of Object.entries(controlGroups)) {
      if (element !== movementControls && element !== lookControls) {
        element.dataset.layoutTarget = String(name === layoutMode.value);
      }
    }
  };
  const updateLayoutPoint = () => {
    const key = layoutMode.value;
    activeTouchLayout = activeTouchLayout || validTouchLayout(defaultTouchLayout);
    activeTouchLayout[key] = clampLayoutPoint(
      { x: Number(layoutX.value), y: Number(layoutY.value) },
      defaultTouchLayout[key],
      controlGroups[key],
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
    setTouchLayoutEditing(false, false);
  });
  layoutEditor.appendChild(doneLayout);
  refreshPresetSelect();
  syncLayoutSliders();
  sceneCanvasWrap.appendChild(layoutEditor);
  const touchLayoutToggle = document.createElement("button");
  touchLayoutToggle.type = "button";
  touchLayoutToggle.className = "kookie-touch-layout-toggle";
  touchLayoutToggle.textContent = "TOUCH OFF";
  touchLayoutToggle.setAttribute("aria-label", "Enable touch control repositioning");
  touchLayoutToggle.setAttribute("aria-pressed", "false");
  sceneCanvasWrap.appendChild(touchLayoutToggle);
  const setTouchLayoutEditing = (editing, showEditor) => {
    if (editing) {
      activeTouchLayout = activeTouchLayout ||
        validTouchLayout(defaultTouchLayout);
      applyTouchLayout(activeTouchLayout);
    } else {
      persistTouchLayout();
    }
    touchLayoutEditing = editing;
    layoutEditor.hidden = !editing || !showEditor;
    panel.dataset.layoutEditing = String(editing);
    touchLayoutToggle.setAttribute("aria-pressed", String(editing));
    touchLayoutToggle.textContent = editing ? "TOUCH ON" : "TOUCH OFF";
    touchLayoutToggle.setAttribute(
      "aria-label",
      editing ? "Lock touch control positions" : "Enable touch control repositioning",
    );
    if (editing && showEditor) syncLayoutSliders();
  };
  touchLayoutToggle.addEventListener("click", () => {
    setTouchLayoutEditing(!touchLayoutEditing, false);
  });
  const customizeLayout = document.createElement("button");
  customizeLayout.type = "button";
  customizeLayout.textContent = "Customize touch controls";
  customizeLayout.addEventListener("click", () => {
    setTouchLayoutEditing(true, true);
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
      }, defaultTouchLayout[name], element);
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
  let spectatorLookYawOffset = 0;
  let spectatorLookPitchOffset = 0;
  const spectatorCameraHome = {
    x: (GAME_WORLD_MINIMUM_X + GAME_WORLD_MAXIMUM_X) / 2,
    y: GAME_WORLD_MAXIMUM_Y * 0.8,
    z: (GAME_WORLD_MINIMUM_Z + GAME_WORLD_MAXIMUM_Z) / 2,
    yaw: 225,
    pitch: -27,
  };
  let spectatorCameraPosition = { ...spectatorCameraHome };
  let spectatorMoveX = 0;
  let spectatorMoveZ = 0;
  let spectatorVerticalKeys = new Set();
  let lastSpectatorCameraUpdateAt = 0;
  let spectatorFollowTargetId = 0;
  let spectatorFollowActive = false;
  let spectatorInitialFollowChosen = false;
  let spectatorHealthBaseline = false;
  const spectatorActorHealth = new Map();
  const spectatorEvents = [];
  let spectatorCameraYaw = spectatorCameraHome.yaw;
  let spectatorCameraPitch = spectatorCameraHome.pitch;
  function spectatorTargets() {
    return sceneState.actors
      .filter((actor) => actor.id > 0 && actor.health > 0)
      .sort((left, right) => left.id - right.id);
  }
  function updateSpectatorCameraControls() {
    const visible = authoritativeReady && joinedRole === GAME_ROLE_SPECTATOR;
    spectatorCameraControls.hidden = !visible;
    if (!visible) return;
    const targets = spectatorTargets();
    spectatorPreviousButton.disabled = targets.length < 1;
    spectatorNextButton.disabled = targets.length < 1;
    const target = targets.find((actor) => actor.id === spectatorFollowTargetId);
    const targetName = target
      ? (target.kind === 2 ? "CAT" : "GOOSE") + " #" + target.id : "";
    spectatorTargetLabel.textContent = spectatorFollowActive && target
      ? "FOLLOW " + targetName
      : targets.length ? "FREE CAMERA · " + targets.length + " PLAYERS"
        : "FREE CAMERA · NO PLAYERS";
    spectatorFreeButton.setAttribute(
      "aria-pressed", spectatorFollowActive ? "false" : "true"
    );
  }
  function cycleSpectatorTarget(direction) {
    const targets = spectatorTargets();
    if (!targets.length) {
      spectatorFollowActive = false;
      spectatorFollowTargetId = 0;
      updateSpectatorCameraControls();
      return;
    }
    const currentIndex = targets.findIndex(
      (actor) => actor.id === spectatorFollowTargetId
    );
    const nextIndex = currentIndex < 0
      ? direction > 0 ? 0 : targets.length - 1
      : (currentIndex + direction + targets.length) % targets.length;
    spectatorFollowTargetId = targets[nextIndex].id;
    spectatorFollowActive = true;
    spectatorLookYawOffset = 0;
    spectatorLookPitchOffset = 0;
    updateSpectatorCameraControls();
  }
  function returnToFreeSpectatorCamera() {
    if (spectatorFollowActive) {
      spectatorLookYawOffset =
        ((spectatorCameraYaw - spectatorCameraHome.yaw + 540) % 360) - 180;
      spectatorLookPitchOffset = Math.max(-80, Math.min(80,
        spectatorCameraPitch - spectatorCameraHome.pitch));
    }
    spectatorFollowActive = false;
    spectatorFollowTargetId = 0;
    updateSpectatorCameraControls();
  }
  let sceneRenderer = null;
  let renderFrameHandle = 0;
  let renderSceneState = null;
  const damageNumberLabels = new Map();
  const seenDamageImpactKeys = new Set();
  const damageImpactKeyOrder = [];
  let lastDamageNumberSceneTick = null;
  const seenLocalHitImpactKeys = new Set();
  const localHitImpactKeyOrder = [];
  let localHitFeedbackReady = false;
  let lastLocalHitSceneTick = null;
  let localHitFeedback = null;
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
  const localMovementVelocity = { x: 0, z: 0 };
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
  const gameConsoleDialog = document.createElement("dialog");
  gameConsoleDialog.className = "kookie-console-dialog";
  gameConsoleDialog.setAttribute("aria-labelledby", "kookie-console-heading");
  const gameConsoleHeading = document.createElement("h2");
  gameConsoleHeading.id = "kookie-console-heading";
  gameConsoleHeading.textContent = "Game console";
  const gameConsoleDescription = document.createElement("p");
  gameConsoleDescription.textContent =
    "Spectator bot commands, or remote admin commands after connecting as Remote administrator.";
  const gameConsoleOutput = document.createElement("pre");
  gameConsoleOutput.className = "kookie-console-output";
  gameConsoleOutput.setAttribute("role", "log");
  gameConsoleOutput.setAttribute("aria-live", "polite");
  const gameConsoleForm = document.createElement("form");
  gameConsoleForm.className = "kookie-console-form";
  const gameConsoleInput = document.createElement("input");
  gameConsoleInput.type = "text";
  gameConsoleInput.maxLength = 96;
  gameConsoleInput.setAttribute("aria-label", "Game console command");
  gameConsoleInput.placeholder = "/b2teams4";
  const gameConsoleSubmit = document.createElement("button");
  gameConsoleSubmit.type = "submit";
  gameConsoleSubmit.textContent = "Run";
  const gameConsoleClose = document.createElement("button");
  gameConsoleClose.type = "button";
  gameConsoleClose.textContent = "Close";
  gameConsoleClose.addEventListener("click", () => gameConsoleDialog.close());
  gameConsoleForm.appendChild(gameConsoleInput);
  gameConsoleForm.appendChild(gameConsoleSubmit);
  gameConsoleForm.appendChild(gameConsoleClose);
  gameConsoleDialog.appendChild(gameConsoleHeading);
  gameConsoleDialog.appendChild(gameConsoleDescription);
  gameConsoleDialog.appendChild(gameConsoleOutput);
  gameConsoleDialog.appendChild(gameConsoleForm);
  const lobbyChat = document.createElement("details");
  lobbyChat.className = "kookie-lobby-chat";
  const lobbyChatSummary = document.createElement("summary");
  lobbyChatSummary.textContent = "LOBBY CHAT";
  const lobbyChatOutput = document.createElement("pre");
  lobbyChatOutput.setAttribute("role", "log");
  lobbyChatOutput.setAttribute("aria-live", "polite");
  lobbyChatOutput.style.maxHeight = "120px";
  lobbyChatOutput.style.overflowY = "auto";
  const lobbyChatForm = document.createElement("form");
  const lobbyChatChannel = document.createElement("select");
  lobbyChatChannel.setAttribute("aria-label", "Chat channel");
  for (const [value, label] of [["0", "Global"], ["1", "Team"], ["2", "Whisper"]]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = label;
    lobbyChatChannel.appendChild(option);
  }
  const lobbyChatTarget = document.createElement("select");
  lobbyChatTarget.setAttribute("aria-label", "Whisper recipient");
  const noWhisperTarget = document.createElement("option");
  noWhisperTarget.value = "";
  noWhisperTarget.textContent = "Select player";
  lobbyChatTarget.appendChild(noWhisperTarget);
  lobbyChatTarget.hidden = true;
  lobbyChatChannel.addEventListener("change", () => {
    lobbyChatTarget.hidden = Number(lobbyChatChannel.value) !== CHAT_WHISPER;
  });
  const lobbyChatInput = document.createElement("input");
  lobbyChatInput.type = "text";
  lobbyChatInput.maxLength = 80;
  lobbyChatInput.setAttribute("aria-label", "Lobby chat message");
  lobbyChatInput.placeholder = "Message";
  const lobbyChatSend = document.createElement("button");
  lobbyChatSend.type = "submit";
  lobbyChatSend.textContent = "Send";
  lobbyChatSend.disabled = true;
  lobbyChatForm.append(lobbyChatChannel, lobbyChatTarget, lobbyChatInput, lobbyChatSend);
  lobbyChat.append(lobbyChatSummary, lobbyChatOutput, lobbyChatForm);
  lobbyChat.style.position = "absolute";
  lobbyChat.style.zIndex = "7";
  lobbyChat.style.left = "14px";
  lobbyChat.style.bottom = "52px";
  lobbyChat.style.width = "min(320px, calc(100% - 28px))";
  lobbyChat.style.padding = "8px 10px";
  lobbyChat.style.border = "1px solid #ffffff35";
  lobbyChat.style.borderRadius = "12px";
  lobbyChat.style.background = "#111c18e8";
  sceneCanvasWrap.appendChild(lobbyChat);
  const mapVotePanel = document.createElement("section");
  mapVotePanel.className = "kookie-map-vote";
  mapVotePanel.hidden = true;
  mapVotePanel.setAttribute("aria-live", "polite");
  const mapVoteHeading = document.createElement("h2");
  mapVoteHeading.textContent = "NEXT MATCH";
  const mapVoteStatus = document.createElement("p");
  const mapVoteButtons = document.createElement("div");
  const mapVoteControls = [];
  for (const [mapId, label] of [
    [1, "G1 · Central Pool"],
    [2, "G2 · Ruins"],
  ]) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.dataset.mapId = String(mapId);
    button.dataset.mapName = label;
    button.addEventListener("click", () => sendMapVote(mapId));
    mapVoteButtons.appendChild(button);
    mapVoteControls.push(button);
  }
  mapVotePanel.append(
    mapVoteHeading, mapVoteStatus, mapVoteButtons,
  );
  Object.assign(mapVotePanel.style, {
    position: "absolute",
    zIndex: "9",
    left: "50%",
    top: "50%",
    transform: "translate(-50%, -50%)",
    width: "min(360px, calc(100% - 28px))",
    padding: "16px",
    border: "1px solid #ffffff55",
    borderRadius: "14px",
    background: "#101b20ee",
    color: "#fff",
    textAlign: "center",
  });
  mapVoteButtons.style.display = "grid";
  mapVoteButtons.style.gridTemplateColumns = "1fr";
  mapVoteButtons.style.gap = "8px";
  sceneCanvasWrap.appendChild(mapVotePanel);
  const respawnNotice = document.createElement("section");
  respawnNotice.hidden = true;
  respawnNotice.className = "kookie-respawn-notice";
  respawnNotice.setAttribute("role", "status");
  respawnNotice.setAttribute("aria-live", "polite");
  Object.assign(respawnNotice.style, {
    position: "absolute",
    zIndex: "10",
    left: "50%",
    top: "42%",
    transform: "translate(-50%, -50%)",
    padding: "18px 24px",
    border: "1px solid #ffffff70",
    borderRadius: "14px",
    background: "#101b20e8",
    color: "#fff",
    font: "700 18px sans-serif",
    letterSpacing: "0.08em",
    textAlign: "center",
    pointerEvents: "none",
  });
  sceneCanvasWrap.appendChild(respawnNotice);
  panel.appendChild(gameConsoleDialog);
  function logGameConsole(message) {
    const lines = (gameConsoleOutput.textContent + String(message) + "\n")
      .split("\n").slice(-80);
    gameConsoleOutput.textContent = lines.join("\n");
    gameConsoleOutput.scrollTop = gameConsoleOutput.scrollHeight;
  }
  gameConsoleButton.addEventListener("click", () => {
    gameConsoleDialog.showModal();
    gameConsoleInput.focus();
  });
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
      minimapContext.fillStyle = actor.kind === 2 ? "#60a5fa" : "#ef5366";
      minimapContext.fillRect(mapX(actor.x) - 5, mapZ(actor.z) - 5, 10, 10);
    }
    if (scene.role === GAME_ROLE_SPECTATOR && spectatorFollowActive) {
      const target = scene.actors.find((actor) =>
        actor.id === spectatorFollowTargetId && actor.health > 0);
      if (target) {
        minimapContext.strokeStyle = "#fffbe9";
        minimapContext.lineWidth = 3;
        minimapContext.beginPath();
        minimapContext.arc(mapX(target.x), mapZ(target.z), 9, 0, Math.PI * 2);
        minimapContext.stroke();
      }
    }
    if (scene.pickup) {
      minimapContext.fillStyle = "#4ade80";
      minimapContext.fillRect(mapX(scene.pickup.x) - 4, mapZ(scene.pickup.z) - 4, 8, 8);
    }
    if (scene.role !== GAME_ROLE_SPECTATOR) {
      minimapContext.fillStyle = "#60a5fa";
      minimapContext.beginPath();
      minimapContext.arc(mapX(scene.playerX), mapZ(scene.playerZ), 7, 0, Math.PI * 2);
      minimapContext.fill();
    }
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
    const visibleActors = (scene.actors || []).filter((actor) =>
      actor.id > 0 && actor.health > 0
    );
    for (const actor of visibleActors) {
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
      const element = document.createElement("span");
      element.className = "kookie-scene-label";
      element.textContent = (actor.kind === 2 ? "CAT"
        : actor.kind === 3 ? "DUMMY" : "GOOSE") + " #" + actor.id;
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
    const localName = clientSettings.playerName.trim();
    const localActor = visibleActors.find((actor) =>
      actor.id === scene.playerId
    );
    if (spectatorFollowActive || !localName ||
        scene.playerId <= 0 || !localActor) return;
    const headHeight = localActor.kind === 2 ? 16 : 20;
    const projection = sceneRenderer?.projectWorld?.(
      scene, localActor.x, localActor.y + headHeight, localActor.z,
    );
    if (!projection || projection.x < 0 || projection.x > 1 ||
        projection.y < 0 || projection.y > 1) return;
    const element = document.createElement("span");
    element.className = "kookie-session-player-name";
    element.textContent = localName + " #" + scene.playerId;
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
  function advancePredictedHorizontalVelocity(
    velocityX, velocityZ, axisX, axisZ, grounded,
  ) {
    if (axisX !== 0 || axisZ !== 0) {
      const major = Math.max(Math.abs(axisX), Math.abs(axisZ));
      const minor = Math.min(Math.abs(axisX), Math.abs(axisZ));
      const magnitudeFixed = major * 1024 + minor * 384;
      const wishX = Math.trunc(axisX * 1024 * 1024 / magnitudeFixed);
      const wishZ = Math.trunc(axisZ * 1024 * 1024 / magnitudeFixed);
      const currentSpeed = Math.trunc(
        (velocityX * wishX + velocityZ * wishZ) / 1024,
      );
      const addSpeed = 8 - currentSpeed;
      const acceleration = grounded ? 3 : 1;
      if (addSpeed > 0) {
        const applied = Math.min(acceleration, addSpeed);
        velocityX += Math.trunc(wishX * applied / 1024);
        velocityZ += Math.trunc(wishZ * applied / 1024);
      }
    } else if (grounded) {
      const speed = Math.max(Math.abs(velocityX), Math.abs(velocityZ)) +
        Math.min(Math.abs(velocityX), Math.abs(velocityZ)) * 3 / 8;
      const nextSpeed = speed - 2;
      if (nextSpeed <= 0) {
        velocityX = 0;
        velocityZ = 0;
      } else {
        velocityX *= nextSpeed / speed;
        velocityZ *= nextSpeed / speed;
      }
    } else {
      velocityX = Math.abs(velocityX) <= 1 ? 0
        : velocityX - Math.sign(velocityX);
      velocityZ = Math.abs(velocityZ) <= 1 ? 0
        : velocityZ - Math.sign(velocityZ);
    }
    localMovementVelocity.x = velocityX;
    localMovementVelocity.z = velocityZ;
  }

  function predictPendingLocalMovement(now) {
    if (!sceneState || pendingInputFrames.size === 0 ||
        remoteSnapshots.length === 0) return false;
    let latestInput = null;
    for (const input of pendingInputFrames.values()) latestInput = input;
    if (!latestInput) return false;
    const latest = remoteSnapshots[remoteSnapshots.length - 1];
    const previous = remoteSnapshots[remoteSnapshots.length - 2];
    const latestActor = latest.actors.find(
      (actor) => actor.id === sceneState.playerId,
    );
    if (!latestActor) return false;
    let velocityX = 0;
    let velocityZ = 0;
    if (previous) {
      const previousActor = previous.actors.find(
        (actor) => actor.id === sceneState.playerId,
      );
      const tickSpan = latest.tick - previous.tick;
      if (previousActor && tickSpan > 0) {
        velocityX = (latestActor.x - previousActor.x) / tickSpan;
        velocityZ = (latestActor.z - previousActor.z) / tickSpan;
      }
    }
    const elapsedMs = Math.min(LOCAL_MAX_EXTRAPOLATION_MS,
      Math.max(0, now - Math.max(latest.receivedAt, latestInput.sentAt)));
    if (elapsedMs <= 0) return false;
    const axisX = Math.trunc(latestInput.moveX * 4 / GAME_MAXIMUM_INPUT_AXIS);
    const axisZ = Math.trunc(latestInput.moveZ * 4 / GAME_MAXIMUM_INPUT_AXIS);
    const grounded = latestActor.y <= 0.5;
    const elapsedTicks = elapsedMs / REMOTE_BASE_TICK_MS;
    const wholeTicks = Math.floor(elapsedTicks);
    let x = latestActor.x;
    let z = latestActor.z;
    for (let tick = 0; tick < wholeTicks; tick += 1) {
      advancePredictedHorizontalVelocity(
        velocityX, velocityZ, axisX, axisZ, grounded,
      );
      velocityX = localMovementVelocity.x;
      velocityZ = localMovementVelocity.z;
      x += velocityX;
      z += velocityZ;
    }
    const fraction = elapsedTicks - wholeTicks;
    if (fraction > 0) {
      advancePredictedHorizontalVelocity(
        velocityX, velocityZ, axisX, axisZ, grounded,
      );
      x += localMovementVelocity.x * fraction;
      z += localMovementVelocity.z * fraction;
    }
    localRenderPosition.x = Math.max(GAME_WORLD_MINIMUM_X,
      Math.min(GAME_WORLD_MAXIMUM_X, x));
    localRenderPosition.z = Math.max(GAME_WORLD_MINIMUM_Z,
      Math.min(GAME_WORLD_MAXIMUM_Z, z));
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
      const tickSpan = previous ? latest.tick - previous.tick : 0;
      const span = tickSpan > 0 ? tickSpan * REMOTE_BASE_TICK_MS : 0;
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
  let lastMapVoteSent = 0;
  function sendMapVote(mapId) {
    if (!connected || joinedRole !== GAME_ROLE_PLAYER || !socket ||
        socket.readyState !== WebSocket.OPEN || !sceneState ||
        sceneState.matchPhase !== 1 || (mapId !== 1 && mapId !== 2)) return;
    const frameSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, frameSequence,
      GAME_MAP_VOTE_MARKER, mapId];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, frameSequence, words));
    lastMapVoteSent = mapId;
  }
  function updateMapVotePanel(scene) {
    const inIntermission = scene.matchPhase === 1;
    mapVotePanel.hidden = !inIntermission;
    if (!inIntermission) {
      lastMapVoteSent = 0;
      return;
    }
    const remainingSeconds = Math.ceil(scene.matchTicksRemaining / 60);
    const currentMap = scene.mapId === 2 ? "G2 · Ruins" : "G1 · Central Pool";
    mapVoteStatus.textContent = "Current: " + currentMap +
      " · " + remainingSeconds + "s left · " +
      scene.mapVoteCounts[0] + " / " + scene.mapVoteCounts[1] + " votes" +
      (lastMapVoteSent ? " · Your vote: G" + lastMapVoteSent : "");
    for (const button of mapVoteControls) {
      const voteIndex = Number(button.dataset.mapId) - 1;
      button.textContent = button.dataset.mapName + " · " +
        scene.mapVoteCounts[voteIndex] + " votes";
      button.disabled = scene.role !== GAME_ROLE_PLAYER;
    }
  }
  function updateSpectatorMatchFeed(scene) {
    if (scene.role !== GAME_ROLE_SPECTATOR) return;
    if (!spectatorHealthBaseline) {
      spectatorActorHealth.clear();
      for (const actor of scene.actors) {
        spectatorActorHealth.set(actor.id, actor.health);
      }
      spectatorHealthBaseline = true;
      return;
    }
    for (const actor of scene.actors) {
      const previousHealth = spectatorActorHealth.get(actor.id);
      if (previousHealth > 0 && actor.health === 0) {
        const source = (scene.impacts || []).find((impact) =>
          impact.targetId === actor.id && impact.damage > 0);
        const actorName = (actor.kind === 2 ? "CAT"
          : actor.kind === 3 ? "DUMMY" : "GOOSE") + " #" + actor.id;
        const sourceActor = source
          ? scene.actors.find((candidate) => candidate.id === source.sourceId)
          : null;
        const sourceName = sourceActor
          ? (sourceActor.kind === 2 ? "CAT"
            : sourceActor.kind === 3 ? "DUMMY" : "GOOSE") +
              " #" + sourceActor.id + " → "
          : "";
        spectatorEvents.unshift(sourceName + actorName + " DOWN");
        if (spectatorEvents.length > 4) spectatorEvents.length = 4;
      }
      spectatorActorHealth.set(actor.id, actor.health);
    }
    spectatorEventFeed.hidden = spectatorEvents.length === 0;
    spectatorEventFeed.replaceChildren(...spectatorEvents.map((text) => {
      const event = document.createElement("span");
      event.textContent = text;
      return event;
    }));
  }

  function updateScene(scene) {
    const previousScene = sceneState;
    const isDead = scene.role === GAME_ROLE_PLAYER && scene.health === 0;
    const wasDead = previousScene?.role === GAME_ROLE_PLAYER &&
      previousScene.health === 0;
    if (isDead && !wasDead) {
      heldMovementKeys.clear();
      gameplayMoveX = 0;
      gameplayMoveZ = 0;
      gameplayHeldActions = 0;
      pendingInputFrames.clear();
      pendingMovement.clear();
    }
    if (scene.role === GAME_ROLE_PLAYER && isDead !== wasDead) {
      setGameControlsEnabled(!isDead);
    }
    respawnNotice.hidden = !isDead;
    if (isDead) {
      const seconds = Math.ceil(scene.respawnTicksRemaining / 60);
      const message = seconds > 0
        ? "KNOCKED OUT · RESPAWNING IN " + seconds + "s"
        : "KNOCKED OUT · RESPAWNING NEXT WAVE";
      if (respawnNotice.textContent !== message) {
        respawnNotice.textContent = message;
      }
    } else if (respawnNotice.textContent) {
      respawnNotice.textContent = "";
    }
    sceneState = scene;
    updateMapVotePanel(scene);
    const spectatorView = scene.role === GAME_ROLE_SPECTATOR;
    hud.dataset.role = spectatorView ? "spectator" : "player";
    sceneCanvasWrap.dataset.role = spectatorView ? "spectator" : "player";
    spectatorEventFeed.hidden = !spectatorView || spectatorEvents.length === 0;
    hudLabels.actors.textContent = spectatorView ? "FIGHTERS" : "ACTORS";
    if (spectatorView && !spectatorInitialFollowChosen) {
      const firstFighter = scene.actors.find((actor) =>
        actor.id > 0 && actor.health > 0);
      if (firstFighter) {
        spectatorFollowTargetId = firstFighter.id;
        spectatorFollowActive = true;
        spectatorInitialFollowChosen = true;
      }
    }
    renderSceneState = {
      ...scene,
      camera: { ...scene.camera },
      actors: scene.actors.map((actor) => ({ ...actor })),
    };
    const now = performance.now();
    updateLocalHitFeedback(scene, now);
    updateHitFeedbackOverlay(now);
    updateProjectedLabels(scene);
    drawMinimap(scene);
    hudValues.tick.textContent = String(scene.tick);
    hudValues.position.textContent = scene.playerX + " / " + scene.playerZ;
    const healthText = Number.isFinite(scene.health) ? String(scene.health) : "--";
    const staminaText = Number.isFinite(scene.stamina) ? String(scene.stamina) : "--";
    const ammoText = Number.isFinite(scene.ammo) ? String(scene.ammo) : "--";
    hudValues.health.textContent = healthText + " / " + GAME_MAXIMUM_HEALTH;
    hudValues.stamina.textContent = staminaText + " / 100";
    const localActor = scene.actors.find((actor) => actor.id === scene.playerId);
    hudStats.health.dataset.team = localActor?.kind === 2 ? "blue" : "red";
    const fireballsActive = localActor?.powerUp === 8;
    const seedAmmoAvailable = Number.isInteger(scene.seedAmmo) &&
      scene.seedAmmo > 0;
    const specialAmmoActive = fireballsActive || seedAmmoAvailable;
    hudLabels.ammo.textContent = fireballsActive ? "FIREBALLS"
      : seedAmmoAvailable ? "SEEDS" : "AMMO";
    hudValues.ammo.textContent = specialAmmoActive
      ? Number.isInteger(scene.seedAmmo) ? String(scene.seedAmmo) : "--"
      : ammoText;
    hudValues.combo.textContent = String(scene.combo ?? 0);
    const aliveActors = scene.actors.filter((actor) => actor.health > 0);
    hudValues.actors.textContent = spectatorView
      ? aliveActors.length + " / " + scene.actors.length
      : String(aliveActors.length);
    const geeseAlive = aliveActors.filter((actor) => actor.kind === 1).length;
    const catsAlive = aliveActors.filter((actor) => actor.kind === 2).length;
    const otherAlive = aliveActors.length - geeseAlive - catsAlive;
    const remainingTicks = scene.matchTicksRemaining;
    const remainingSeconds = Number.isFinite(remainingTicks)
      ? Math.max(0, Math.ceil(remainingTicks / 60)) : null;
    const timeText = remainingSeconds === null ? "--:--"
      : Math.floor(remainingSeconds / 60) + ":" +
        String(remainingSeconds % 60).padStart(2, "0");
    const mapName = scene.mapId === 2 ? "G2 RUINS" : "G1 POOL";
    const phaseName = scene.matchPhase === 1 ? "BREAK" : "FIGHT";
    hudValues.match.textContent = mapName + " · " + phaseName + " · " + timeText;
    hudValues.teams.textContent = geeseAlive + " / " + catsAlive +
      (otherAlive > 0 ? " · +" + otherAlive : "");
    hudValues.oxygen.textContent = localActor && Number.isInteger(localActor.oxygen)
      ? String(localActor.oxygen) : "--";
    hudValues.projectiles.textContent = String(scene.projectiles.length);
    remoteState.textContent = "AUTHORITATIVE STATE / tick=" + scene.tick +
      " position=" + scene.playerX + "," + scene.playerZ +
      " health=" + healthText + " stamina=" + staminaText +
      " ammo=" + ammoText + " combo=" + (scene.combo ?? 0) +
      " actors=" + scene.actors.length +
      " projectiles=" + scene.projectiles.length;
    sceneCanvas.setAttribute(
      "aria-label",
      "Authoritative WebGL2 scene tick " + scene.tick +
        ", player position " + scene.playerX + "," + scene.playerZ +
        ", health " + healthText + ", stamina " + staminaText +
        ", ammo " + ammoText + ", " + scene.actors.length + " actors"
    );
  }
  function applyAuthoritativeScene(scene, snapshotSequence) {
    if (snapshotSequence < lastSnapshotSequence) return;
    updateSpectatorMatchFeed(scene);
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
    let predictedYaw = scene.yaw;
    let predictedPitch = scene.pitch;
    for (const input of pendingInputFrames.values()) {
      predictedYaw += input.lookYaw || 0;
      predictedPitch += input.lookPitch || 0;
    }
    displayed.yaw = ((predictedYaw % 360) + 360) % 360;
    displayed.pitch = Math.max(-90, Math.min(90, predictedPitch));
    const cameraYaw = displayed.yaw * Math.PI / 180;
    displayed.camera = {
      x: displayed.playerX - Math.sin(cameraYaw) * 16,
      y: displayed.playerY + 8,
      z: displayed.playerZ - Math.cos(cameraYaw) * 16,
      yaw: displayed.yaw,
      pitch: displayed.pitch,
    };
    if (Math.abs(displayed.playerX - sceneState.playerX) > 0.01 ||
        Math.abs(displayed.playerZ - sceneState.playerZ) > 0.01) {
      beginLocalMovementBlend(displayed.playerX, displayed.playerZ, 90, now);
    }
    updateScene(displayed);
    updateSpectatorCameraControls();
    updateDamageNumbers(displayed, now);
  }
  function updateSpectatorCamera(now) {
    const deltaSeconds = lastSpectatorCameraUpdateAt === 0 ? 0
      : Math.min(0.05, Math.max(0, (now - lastSpectatorCameraUpdateAt) / 1000));
    lastSpectatorCameraUpdateAt = now;
    const followActor = spectatorFollowActive
      ? sceneState.actors.find((actor) =>
        actor.id === spectatorFollowTargetId && actor.health > 0)
      : null;
    if (spectatorFollowActive && !followActor) {
      const nextFighter = spectatorTargets()[0];
      if (nextFighter) {
        spectatorFollowTargetId = nextFighter.id;
      } else {
        spectatorFollowActive = false;
        spectatorFollowTargetId = 0;
      }
      updateSpectatorCameraControls();
    }
    const target = followActor
      ? sampleRemoteActor(followActor.id, now - remoteRenderDelayMs, 0) ||
        followActor
      : null;
    const desiredYaw = target
      ? (target.yaw + spectatorLookYawOffset + 360) % 360
      : (spectatorCameraHome.yaw + spectatorLookYawOffset + 360) % 360;
    const desiredPitch = target
      ? Math.max(-80, Math.min(80, -12 + spectatorLookPitchOffset))
      : Math.max(-80, Math.min(80,
        spectatorCameraHome.pitch + spectatorLookPitchOffset));
    const blend = 1 - Math.exp(-deltaSeconds / 0.14);
    const yawDelta = ((desiredYaw - spectatorCameraYaw + 540) % 360) - 180;
    spectatorCameraYaw =
      (spectatorCameraYaw + yawDelta * blend + 360) % 360;
    spectatorCameraPitch += (desiredPitch - spectatorCameraPitch) * blend;
    if (target) {
      const yaw = target.yaw * Math.PI / 180;
      const desiredPosition = {
        x: target.x - Math.sin(yaw) * 18,
        y: target.y + 9,
        z: target.z - Math.cos(yaw) * 18,
      };
      spectatorCameraPosition.x +=
        (desiredPosition.x - spectatorCameraPosition.x) * blend;
      spectatorCameraPosition.y +=
        (desiredPosition.y - spectatorCameraPosition.y) * blend;
      spectatorCameraPosition.z +=
        (desiredPosition.z - spectatorCameraPosition.z) * blend;
      spectatorCameraPosition.x = Math.max(GAME_WORLD_MINIMUM_X,
        Math.min(GAME_WORLD_MAXIMUM_X, spectatorCameraPosition.x));
      spectatorCameraPosition.z = Math.max(GAME_WORLD_MINIMUM_Z,
        Math.min(GAME_WORLD_MAXIMUM_Z, spectatorCameraPosition.z));
      spectatorCameraPosition.y = Math.max(2,
        Math.min(GAME_WORLD_MAXIMUM_Y + 20, spectatorCameraPosition.y));
      return;
    }
    const yaw = spectatorCameraYaw * Math.PI / 180;
    let forward = spectatorMoveZ / GAME_MAXIMUM_INPUT_AXIS;
    let strafe = spectatorMoveX / GAME_MAXIMUM_INPUT_AXIS;
    const horizontalMagnitude = Math.hypot(forward, strafe);
    if (horizontalMagnitude > 1) {
      forward /= horizontalMagnitude;
      strafe /= horizontalMagnitude;
    }
    const vertical =
      (spectatorVerticalKeys.has("Space") ? 1 : 0) -
      (spectatorVerticalKeys.has("ShiftLeft") ||
        spectatorVerticalKeys.has("ShiftRight") ? 1 : 0);
    const speed = 64 * movementSpeedScale() * deltaSeconds;
    spectatorCameraPosition.x = Math.max(GAME_WORLD_MINIMUM_X,
      Math.min(GAME_WORLD_MAXIMUM_X, spectatorCameraPosition.x +
        (forward * Math.sin(yaw) + strafe * Math.cos(yaw)) * speed));
    spectatorCameraPosition.z = Math.max(GAME_WORLD_MINIMUM_Z,
      Math.min(GAME_WORLD_MAXIMUM_Z, spectatorCameraPosition.z +
        (forward * Math.cos(yaw) - strafe * Math.sin(yaw)) * speed));
    spectatorCameraPosition.y = Math.max(2,
      Math.min(GAME_WORLD_MAXIMUM_Y + 20,
        spectatorCameraPosition.y + vertical * speed));
  }

  function removeDamageNumberLabel(element) {
    if (element.parentNode === damageNumberLayer) {
      damageNumberLayer.removeChild(element);
    }
  }
  function clearDamageNumberLabels() {
    for (const entry of damageNumberLabels.values()) {
      removeDamageNumberLabel(entry.element);
    }
    damageNumberLabels.clear();
  }
  function rememberLocalHitImpact(key) {
    seenLocalHitImpactKeys.add(key);
    localHitImpactKeyOrder.push(key);
    if (localHitImpactKeyOrder.length > 32) {
      seenLocalHitImpactKeys.delete(localHitImpactKeyOrder.shift());
    }
  }
  function updateLocalHitFeedback(scene, now) {
    if (lastLocalHitSceneTick !== null &&
        scene.tick < lastLocalHitSceneTick) {
      seenLocalHitImpactKeys.clear();
      localHitImpactKeyOrder.length = 0;
      localHitFeedbackReady = false;
      localHitFeedback = null;
    }
    lastLocalHitSceneTick = scene.tick;
    const impacts = scene.impacts || [];
    const feedbackTargetId = spectatorFollowActive
      ? spectatorFollowTargetId : scene.playerId;
    if (!localHitFeedbackReady) {
      for (const impact of impacts) {
        if (impact.targetId === feedbackTargetId && impact.damage > 0) {
          rememberLocalHitImpact([impact.sequence, impact.sourceId,
            impact.targetId, impact.kind, impact.x, impact.y, impact.z,
            impact.damage].join(":"));
        }
      }
      localHitFeedbackReady = true;
      return;
    }
    if (!(feedbackTargetId > 0)) return;
    const player = scene.actors.find((actor) => actor.id === feedbackTargetId);
    for (const impact of impacts) {
      if (impact.targetId !== feedbackTargetId || impact.damage <= 0) continue;
      const key = [impact.sequence, impact.sourceId, impact.targetId,
        impact.kind, impact.x, impact.y, impact.z, impact.damage].join(":");
      if (seenLocalHitImpactKeys.has(key)) continue;
      rememberLocalHitImpact(key);
      const source = scene.actors.find((actor) => actor.id === impact.sourceId);
      let directionAngle = null;
      if (source) {
        const playerX = player ? player.x : scene.playerX;
        const playerZ = player ? player.z : scene.playerZ;
        const directionX = source.x - playerX;
        const directionZ = source.z - playerZ;
        if (Math.hypot(directionX, directionZ) > 0.01) {
          directionAngle = Math.atan2(directionX, directionZ) -
            (Number.isFinite(scene.camera?.yaw) ? scene.camera.yaw : scene.yaw)
              * Math.PI / 180;
        }
      }
      localHitFeedback = { startedAt: now, directionAngle };
    }
  }
  function updateHitFeedbackOverlay(now) {
    if (!localHitFeedback) {
      hitFeedbackFlash.style.opacity = "0";
      hitDirectionIndicator.hidden = true;
      return;
    }
    const elapsed = now - localHitFeedback.startedAt;
    const flashDuration = 220;
    const flashAlpha = clientSettings.reducedMotion ? 0 : 0.28;
    const flashProgress = Math.max(0, 1 - elapsed / flashDuration);
    hitFeedbackFlash.style.opacity = String(flashAlpha * flashProgress);
    const directionDuration = 700;
    if (localHitFeedback.directionAngle === null ||
        elapsed >= directionDuration) {
      hitDirectionIndicator.hidden = true;
      return;
    }
    const angle = localHitFeedback.directionAngle;
    const radius = 40;
    hitDirectionIndicator.hidden = false;
    hitDirectionIndicator.style.left =
      (50 + Math.sin(angle) * radius) + "%";
    hitDirectionIndicator.style.top =
      (50 - Math.cos(angle) * radius) + "%";
    hitDirectionIndicator.style.transform =
      "translate(-50%, -50%) rotate(" + (angle * 180 / Math.PI) + "deg)";
    hitDirectionIndicator.style.opacity = clientSettings.reducedMotion
      ? "1" : String(1 - elapsed / directionDuration);
  }
  function updateDamageNumbers(scene, now) {
    if (lastDamageNumberSceneTick !== null &&
        scene.tick < lastDamageNumberSceneTick) {
      clearDamageNumberLabels();
      seenDamageImpactKeys.clear();
      damageImpactKeyOrder.length = 0;
    }
    lastDamageNumberSceneTick = scene.tick;
    for (const impact of scene.impacts || []) {
      if (impact.damage <= 0) continue;
      const key = [impact.sequence, impact.sourceId, impact.targetId,
        impact.kind, impact.x, impact.y, impact.z, impact.damage].join(":");
      if (seenDamageImpactKeys.has(key)) continue;
      seenDamageImpactKeys.add(key);
      damageImpactKeyOrder.push(key);
      if (damageImpactKeyOrder.length > 32) {
        seenDamageImpactKeys.delete(damageImpactKeyOrder.shift());
      }
      const feedbackSourceId = spectatorFollowActive
        ? spectatorFollowTargetId : scene.playerId;
      if (impact.sourceId === feedbackSourceId &&
          impact.targetId !== feedbackSourceId) {
        sceneCanvasWrap.dataset.dealtHit = "false";
        void sceneCanvasWrap.offsetWidth;
        sceneCanvasWrap.dataset.dealtHit = "true";
      }
      if (!clientSettings.showDamageNumbers) continue;
      const element = document.createElement("span");
      element.className = "kookie-damage-number";
      element.textContent = "-" + impact.damage;
      damageNumberLayer.appendChild(element);
      damageNumberLabels.set(key, {
        element, impact, startedAt: now,
      });
      if (damageNumberLabels.size > 24) {
        const oldest = damageNumberLabels.keys().next().value;
        removeDamageNumberLabel(damageNumberLabels.get(oldest).element);
        damageNumberLabels.delete(oldest);
      }
    }
    if (!clientSettings.showDamageNumbers) {
      clearDamageNumberLabels();
      return;
    }
    for (const [key, entry] of damageNumberLabels) {
      const progress = (now - entry.startedAt) / 950;
      if (progress >= 1) {
        removeDamageNumberLabel(entry.element);
        damageNumberLabels.delete(key);
        continue;
      }
      const projected = sceneRenderer.projectWorld(
        scene, entry.impact.x, entry.impact.y, entry.impact.z,
      );
      entry.element.hidden = !projected;
      if (!projected) continue;
      entry.element.style.left = (projected.x * 100) + "%";
      entry.element.style.top = (projected.y * 100) + "%";
      entry.element.style.opacity = String(1 - progress);
      entry.element.style.transform =
        "translate(-50%, calc(-50% - " + (progress * 38) + "px))";
    }
  }

  const THROWABLE_NAMES = Object.freeze({
    1: "bomb", 2: "flour package", 3: "watermelon", 4: "wooden crate",
    5: "boulder", 6: "wooden barrel",
  });
  const throwableName = (type) => THROWABLE_NAMES[type] || "throwable";
  const THROW_CHARGE_TICKS = 30;
  let carriedButtonState = null;
  let carriedButtonType = null;
  let pickupButtonType = null;
  function updateThrowableHud(scene) {
    const player = scene.playerId > 0
      ? scene.actors.find((actor) => actor.id === scene.playerId) : null;
    const dx = player && scene.pickup ? player.x - scene.pickup.x : Infinity;
    const dy = player && scene.pickup ? player.y - scene.pickup.y : Infinity;
    const dz = player && scene.pickup ? player.z - scene.pickup.z : Infinity;
    const canPickUp = joinedRole !== GAME_ROLE_SPECTATOR &&
      !scene.carriesThrowable && Boolean(scene.pickup) &&
      dx * dx + dy * dy + dz * dz <= 36;
    const name = throwableName(scene.pickup?.type);
    throwPrompt.textContent = "PRESS T / PICK UP " + name.toUpperCase();
    throwPrompt.hidden = !canPickUp;
    if (carriedButtonState !== scene.carriesThrowable ||
        carriedButtonType !== scene.carryType ||
        pickupButtonType !== scene.pickup?.type) {
      carriedButtonState = scene.carriesThrowable;
      carriedButtonType = scene.carryType;
      pickupButtonType = scene.pickup?.type;
      const carriedName = throwableName(scene.carryType);
      throwableActionButton.textContent = carriedButtonState
        ? "THROW " + carriedName.toUpperCase() : "PICK";
      throwableActionButton.setAttribute(
        "aria-label",
        carriedButtonState
          ? "Throw " + carriedName + "; hold to charge, release to throw"
          : "Pick up nearby " + name,
      );
    }
    const charging = joinedRole !== GAME_ROLE_SPECTATOR &&
      scene.carriesThrowable && (gameplayHeldActions & ACTION_THROWABLE) !== 0;
    const percent = Math.max(0, Math.min(100,
      Math.round(scene.throwableChargeTicks / THROW_CHARGE_TICKS * 100)));
    throwCharge.hidden = !charging;
    throwCharge.dataset.full = String(percent >= 100);
    throwCharge.setAttribute("aria-valuenow", String(percent));
    chargeFill.style.width = percent + "%";
    chargePercent.textContent = percent + "%";
    chargeLabel.textContent = percent >= 100
      ? "MAX " + throwableName(scene.carryType).toUpperCase()
      : "THROW " + throwableName(scene.carryType).toUpperCase();
  }
  function buildThrowPreview(scene) {
    if (joinedRole === GAME_ROLE_SPECTATOR || !scene.carriesThrowable ||
        !(gameplayHeldActions & ACTION_THROWABLE)) return null;
    const charge = Math.max(0, Math.min(THROW_CHARGE_TICKS,
      scene.throwableChargeTicks || 0));
    const speed = 167 + Math.trunc(charge * (360 - 167) / THROW_CHARGE_TICKS);
    const multiplier = speed / 167;
    const yaw = scene.yaw * Math.PI / 180;
    const pitch = scene.pitch * Math.PI / 180;
    let x = scene.playerX;
    let y = scene.playerY + 3;
    let z = scene.playerZ;
    let vx = Math.sin(yaw) * 1000 * multiplier;
    let vy = (167 - Math.sin(pitch) * 1000) * multiplier;
    let vz = Math.sin(yaw + Math.PI / 2) * 1000 * multiplier;
    const points = [];
    for (let tick = 1; tick <= 30; tick += 1) {
      vy -= 33;
      x += vx * 0.002;
      y += vy * 0.002;
      z += vz * 0.002;
      if (tick % 2 === 0 || y <= 0) points.push({ x, y: Math.max(0, y), z });
      if (y <= 0 || x < 0 || x > 320 || z < 0 || z > 280) break;
    }
    return points.length > 1 ? points : null;
  }

  function renderFrame(time) {
    if (!sceneRenderer) return;
    const now = performance.now();
    const position = currentLocalRenderPosition(now);
    renderSceneState.playerX = position.x;
    renderSceneState.playerZ = position.z;
    updateRemoteRenderActors(now);
    if (joinedRole === GAME_ROLE_SPECTATOR) {
      updateSpectatorCamera(now);
      const followedActor = spectatorFollowActive
        ? renderSceneState.actors.find((actor) =>
          actor.id === spectatorFollowTargetId && actor.health > 0)
        : null;
      if (followedActor) {
        renderSceneState.playerId = followedActor.id;
        renderSceneState.playerX = followedActor.x;
        renderSceneState.playerY = followedActor.y;
        renderSceneState.playerZ = followedActor.z;
        renderSceneState.yaw = followedActor.yaw;
        renderSceneState.pitch = followedActor.pitch || 0;
        const yaw = followedActor.yaw * Math.PI / 180;
        renderSceneState.camera = {
          x: followedActor.x - Math.sin(yaw) * 16,
          y: followedActor.y + 8,
          z: followedActor.z - Math.cos(yaw) * 16,
          yaw: followedActor.yaw,
          pitch: followedActor.pitch || 0,
        };
        renderSceneState.spectatorFollow = true;
      } else {
        renderSceneState.playerId = 0;
        renderSceneState.spectatorFollow = false;
        renderSceneState.camera.x = spectatorCameraPosition.x;
        renderSceneState.camera.y = spectatorCameraPosition.y;
        renderSceneState.camera.z = spectatorCameraPosition.z;
        renderSceneState.camera.yaw = spectatorCameraYaw;
        renderSceneState.camera.pitch = spectatorCameraPitch;
      }
    }
    updateThrowableHud(renderSceneState);
    renderSceneState.throwPreview = buildThrowPreview(renderSceneState);
    if (joinedRole !== GAME_ROLE_SPECTATOR) {
      renderSceneState.camera.x += position.x - sceneState.playerX;
      renderSceneState.camera.z += position.z - sceneState.playerZ;
    }
    updateProjectedLabels(renderSceneState);
    updateHitFeedbackOverlay(now);
    try {
      sceneRenderer.render(renderSceneState, time);
      updateDamageNumbers(renderSceneState, now);
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
      if (joinedRole !== GAME_ROLE_SPECTATOR) {
        renderSceneState.camera.x = sceneState.camera.x;
        renderSceneState.camera.z = sceneState.camera.z;
      }
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
  function setGameControlsEnabled(enabled, spectator = false) {
    for (const button of gameActionButtons) button.disabled = !enabled || spectator;
    actionControls.hidden = enabled && spectator;
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
      if (words.length === 10 && words[3] === GAME_ADMIN_RESPONSE_MARKER) {
        return words[4] >= GAME_ADMIN_STATUS && words[4] <= GAME_ADMIN_MAPVOTE_START &&
          words[5] >= 0 && words[5] <= 2 &&
          words[6] >= 0 && words[6] <= GAME_MAXIMUM_TICK &&
          words[7] >= 0 && words[7] <= 8 &&
          words[8] >= 0 && words[8] <= 4 &&
          words[9] === messageChecksum(words.slice(0, 9));
      }
      if (words.length >= 10 && words.length <= 89 &&
          (words[3] === GAME_CHAT_MARKER || words[3] === GAME_CHAT_RESPONSE_MARKER) &&
          words[4] >= CHAT_GLOBAL && words[4] <= CHAT_WHISPER &&
          words[6] >= 1 && words[6] <= 80 && words.length === 9 + words[6] &&
          ((words[4] === CHAT_GLOBAL && words[5] === 0) ||
            (words[4] === CHAT_TEAM && words[5] >= 1 && words[5] <= 2) ||
            (words[4] === CHAT_WHISPER && words[5] >= 1 && words[5] <= MAX_SEQUENCE)) &&
          (words[3] !== GAME_CHAT_RESPONSE_MARKER ||
            (words[7] >= 1 && words[7] <= MAX_SEQUENCE)) &&
          words.slice(8, 8 + words[6]).every((value) => value >= 32 && value <= 126) &&
          words[words.length - 1] === messageChecksum(words.slice(0, -1))) {
        return words[3] === GAME_CHAT_RESPONSE_MARKER;
      }
      if (words.length === 10 && words[3] === GAME_JOIN_RESPONSE_MARKER) {
        return (words[4] === 0 || words[4] === 1) &&
          (words[5] === GAME_ROLE_PLAYER || words[5] === GAME_ROLE_SPECTATOR ||
            words[5] === GAME_ROLE_TRAINING) &&
          words[6] >= 0 && words[6] <= 1000000 &&
          words[7] >= 0 && words[7] <= 8 &&
          words[8] >= 0 && words[8] <= 4 &&
          (words[4] === 0 || words[6] > 0) &&
          words[9] === messageChecksum(words.slice(0, 9));
      }
      if (words.length >= 19 && words[3] === GAME_MULTIPLAYER_SNAPSHOT_MARKER) {
        const actorCount = words[17];
        const trailer = 18 + actorCount * 8;
        const baseLength = 19 + actorCount * 8;
        if (!Number.isInteger(actorCount) || actorCount < 0 || actorCount > 8 ||
            words.length < baseLength || words.length > MAX_WORDS) return false;
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
          if ((actorKind === 3 ? id >= 0 || id < -4
                : id <= 0 || id > 1000000) || actorIds.has(id) ||
              x < GAME_WORLD_MINIMUM_X || x > GAME_WORLD_MAXIMUM_X ||
              y < GAME_WORLD_MINIMUM_Y || y > GAME_WORLD_MAXIMUM_Y ||
              z < GAME_WORLD_MINIMUM_Z || z > GAME_WORLD_MAXIMUM_Z ||
              health < 0 || health > GAME_MAXIMUM_HEALTH ||
              state < 0 || state > GAME_MAXIMUM_ACTOR_STATE ||
              Math.floor(state / 128) % 16 > 14 ||
              (actorKind !== 3 && (actorKind < 1 || actorKind > 2)) ||
              (actorKind === 3 && state !== 0) ||
              actorYaw < 0 || actorYaw > 359) {
            return false;
          }
          actorIds.add(id);
        }
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
          for (let index = 0; index < projectileCount; index += 1, offset += 8) {
            if (words[offset] <= 0 || words[offset + 1] < 0 ||
                words[offset + 1] > 1000000 || words[offset + 2] < 0 ||
                words[offset + 2] > 1000000 ||
                words[offset + 3] < GAME_WORLD_MINIMUM_X ||
                words[offset + 3] > GAME_WORLD_MAXIMUM_X ||
                words[offset + 4] < GAME_WORLD_MINIMUM_Y ||
                words[offset + 4] > GAME_WORLD_MAXIMUM_Y ||
                words[offset + 5] < GAME_WORLD_MINIMUM_Z ||
                words[offset + 5] > GAME_WORLD_MAXIMUM_Z ||
                words[offset + 6] < 0 || words[offset + 6] > GAME_MAXIMUM_TICK ||
                (words[offset + 7] !== 1 && words[offset + 7] !== 3)) {
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
                words[offset + 6] > 6 || words[offset + 7] < 0 ||
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
          const tailLength = words.length - offset - 1;
          const baseExtendedSuffixLength = 10 + words[offset + 9] * 4;
          const hasNoOxygenNewSuffix = tailLength >= 10 && tailLength <= 32 &&
            Number.isInteger(words[offset + 9]) &&
            words[offset + 9] >= 0 && words[offset + 9] <= 4 &&
            (tailLength === baseExtendedSuffixLength ||
              tailLength === baseExtendedSuffixLength + 6);
          const hasOxygen = !hasNoOxygenNewSuffix &&
            (tailLength === actorCount || tailLength === actorCount + 6 ||
              (tailLength >= actorCount + 10 && tailLength <= actorCount + 32 &&
                ((tailLength - actorCount - 10) % 4 === 0 ||
                  (tailLength - actorCount - 16) % 4 === 0)));
          const suffixOffset = offset + (hasOxygen ? actorCount : 0);
          const suffixLength = words.length - suffixOffset - 1;
          if (suffixLength !== 0 && suffixLength !== 6 &&
              !(suffixLength >= 10 && suffixLength <= 32 &&
                ((suffixLength - 10) % 4 === 0 ||
                  (suffixLength >= 16 && (suffixLength - 16) % 4 === 0))) &&
              !(suffixLength >= actorCount + 10 && suffixLength <= actorCount + 32)) return false;
          if (hasOxygen) {
            for (let index = 0; index < actorCount; index += 1) {
              if (!Number.isInteger(words[offset + index]) ||
                  words[offset + index] < 0 ||
                  words[offset + index] > 1000000) return false;
            }
          }
          if (suffixLength === 6) {
            if ((words[suffixOffset] !== 0 && words[suffixOffset] !== 1) ||
                words[suffixOffset + 1] < GAME_WORLD_MINIMUM_X ||
                words[suffixOffset + 1] > GAME_WORLD_MAXIMUM_X ||
                words[suffixOffset + 2] < GAME_WORLD_MINIMUM_Y ||
                words[suffixOffset + 2] > GAME_WORLD_MAXIMUM_Y ||
                words[suffixOffset + 3] < GAME_WORLD_MINIMUM_Z ||
                words[suffixOffset + 3] > GAME_WORLD_MAXIMUM_Z ||
                (words[suffixOffset + 4] !== 0 && words[suffixOffset + 4] !== 1) ||
                words[suffixOffset + 5] < 0 ||
                words[suffixOffset + 5] > THROW_CHARGE_TICKS) return false;
          } else if (suffixLength >= 10) {
            const sliceCount = words[suffixOffset + 9];
            if ((words[suffixOffset] !== 0 && words[suffixOffset] !== 1) ||
                words[suffixOffset + 1] < GAME_WORLD_MINIMUM_X ||
                words[suffixOffset + 1] > GAME_WORLD_MAXIMUM_X ||
                words[suffixOffset + 2] < GAME_WORLD_MINIMUM_Y ||
                words[suffixOffset + 2] > GAME_WORLD_MAXIMUM_Y ||
                words[suffixOffset + 3] < GAME_WORLD_MINIMUM_Z ||
                words[suffixOffset + 3] > GAME_WORLD_MAXIMUM_Z ||
                words[suffixOffset + 4] < 0 || words[suffixOffset + 4] > 6 ||
                (words[suffixOffset + 5] !== 0 && words[suffixOffset + 5] !== 1) ||
                words[suffixOffset + 6] < 0 ||
                words[suffixOffset + 6] > THROW_CHARGE_TICKS ||
                words[suffixOffset + 7] < 0 || words[suffixOffset + 7] > 6 ||
                words[suffixOffset + 8] < 0 ||
                words[suffixOffset + 8] > GAME_MAXIMUM_SEED_AMMO ||
                !Number.isInteger(sliceCount) || sliceCount < 0 || sliceCount > 4 ||
                (suffixLength !== 10 + sliceCount * 4 &&
                  suffixLength !== 16 + sliceCount * 4 &&
                  suffixLength !== 17 + sliceCount * 4)) return false;
            const sliceIds = new Set();
            for (let index = 0; index < sliceCount; index += 1) {
              const sliceOffset = suffixOffset + 10 + index * 4;
              if (words[sliceOffset] < 0 || words[sliceOffset] > 1000000 ||
                  sliceIds.has(words[sliceOffset]) ||
                  words[sliceOffset + 1] < GAME_WORLD_MINIMUM_X ||
                  words[sliceOffset + 1] > GAME_WORLD_MAXIMUM_X ||
                  words[sliceOffset + 2] < GAME_WORLD_MINIMUM_Y ||
                  words[sliceOffset + 2] > GAME_WORLD_MAXIMUM_Y ||
                  words[sliceOffset + 3] < GAME_WORLD_MINIMUM_Z ||
                  words[sliceOffset + 3] > GAME_WORLD_MAXIMUM_Z) return false;
              sliceIds.add(words[sliceOffset]);
            }
            if (suffixLength === 16 + sliceCount * 4 ||
                suffixLength === 17 + sliceCount * 4) {
              const metadata = suffixOffset + 10 + sliceCount * 4;
              const totalVotes = words[metadata + 3] + words[metadata + 4];
              if ((words[metadata] !== 1 && words[metadata] !== 2) ||
                  (words[metadata + 1] !== 0 && words[metadata + 1] !== 1) ||
                  words[metadata + 2] < 0 || words[metadata + 2] > 7200 ||
                  words[metadata + 3] < 0 || words[metadata + 3] > 8 ||
                  words[metadata + 4] < 0 || words[metadata + 4] > 8 ||
                  words[metadata + 5] !== totalVotes ||
                  (suffixLength === 17 + sliceCount * 4 &&
                    (words[metadata + 6] < 0 ||
                      words[metadata + 6] > 360))) return false;
            }
          }
        }
        const validSnapshot = words[4] >= 0 && words[4] <= GAME_MAXIMUM_TICK &&
          (words[5] === GAME_ROLE_PLAYER || words[5] === GAME_ROLE_SPECTATOR ||
            words[5] === GAME_ROLE_TRAINING) &&
          words[6] >= 0 && words[6] <= 1000000 &&
          ((words[5] === GAME_ROLE_SPECTATOR && words[6] === 0) ||
            (words[5] !== GAME_ROLE_SPECTATOR && words[6] > 0)) &&
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

  const browserBattleBots = [];
  const BOT_POWERUP_CONFIGS = [
    "coffee_mug", "jetpack", "megaphone", "scuba_kit", "watermelon",
    "wool_ball", "flour_bag", "multiplayer_coffee", "wizard_hat",
  ];
  let botPowerupWaypoints = null;
  let botAISettings = null;
  async function loadBrowserBotAIConfig() {
    if (botAISettings) return botAISettings;
    const url = "assets/prototype/runtime/bot_ai.json";
    const response = await fetch(url, { cache: "force-cache" });
    if (!response.ok) throw new Error("bot AI config HTTP " +
      response.status + " / " + url);
    const config = await response.json();
    const sections = ["planner", "combat", "runtime"];
    if (config.schema !== "kookie.bot-ai/v1" ||
        !Array.isArray(config.profileByBotIndex) ||
        !config.profileByBotIndex.length ||
        !config.profiles || sections.some((section) =>
          !config[section] || typeof config[section] !== "object")) {
      throw new Error("invalid bot AI config schema");
    }
    for (const name of config.profileByBotIndex) {
      const profile = config.profiles[name];
      if (!profile || ["aggression", "roaming", "scavenging", "survival",
        "teamwork", "riskTolerance"].some((key) =>
        !Number.isFinite(profile[key]) || profile[key] < 0 || profile[key] > 1)) {
        throw new Error("invalid bot AI profile: " + name);
      }
    }
    for (const section of sections) {
      for (const [key, value] of Object.entries(config[section])) {
        if (typeof value === "number" && !Number.isFinite(value)) {
          throw new Error("invalid bot AI setting: " + section + "." + key);
        }
      }
    }
    botAISettings = config;
    return config;
  }
  async function loadBotPowerupWaypoints() {
    if (botPowerupWaypoints) return botPowerupWaypoints;
    const definitions = await Promise.all(BOT_POWERUP_CONFIGS.map(async (name) => {
      const url = "assets/prototype/runtime/power_ups/" + name + ".json";
      const response = await fetch(url, { cache: "force-cache" });
      if (!response.ok) throw new Error("powerup config HTTP " + response.status + " / " + url);
      const config = await response.json();
      if (!Number.isInteger(config.kind) ||
          !Number.isInteger(config.x) || !Number.isInteger(config.y) ||
          !Number.isInteger(config.z)) {
        throw new Error("invalid bot powerup config: " + name);
      }
      return { kind: config.kind, x: config.x, y: config.y, z: config.z };
    }));
    botPowerupWaypoints = definitions;
    return definitions;
  }
  function botCanUsePowerup(animal, kind) {
    return (kind !== 3 && kind !== 5 || animal === 1) &&
      (kind !== 6 || animal === 2);
  }
  function botSceneData(words) {
    const trailer = 18 + words[17] * 8;
    if (words.length === 19 + words[17] * 8) {
      return {
        projectiles: [], pickup: null, carriesThrowable: false,
        chargeTicks: 0, carryType: 0, seedAmmo: 0,
      };
    }
    let cursor = trailer + 4;
    const projectileCount = words[trailer + 1];
    const throwableCount = words[trailer + 2];
    const impactCount = words[trailer + 3];
    const projectiles = [];
    for (let index = 0; index < projectileCount; index += 1, cursor += 8) {
      projectiles.push({
        targetId: words[cursor + 2], x: words[cursor + 3],
        y: words[cursor + 4], z: words[cursor + 5],
      });
    }
    cursor += throwableCount * 8 + impactCount * 8;
    let suffixLength = words.length - cursor - 1;
    const sliceCount = words[cursor + 9];
    const hasNewSuffix = suffixLength >= 10 && suffixLength <= 33 &&
      Number.isInteger(sliceCount) && sliceCount >= 0 && sliceCount <= 4 &&
      (suffixLength === 10 + sliceCount * 4 ||
        suffixLength === 16 + sliceCount * 4 ||
        suffixLength === 17 + sliceCount * 4);
    const isKnownSuffixLength = (length) => length === 0 || length === 6 ||
      (length >= 10 && length <= 33 &&
        ((length - 10) % 4 === 0 || (length >= 16 && (length - 16) % 4 === 0) ||
          (length >= 17 && (length - 17) % 4 === 0)));
    const hasOxygen = !hasNewSuffix && !isKnownSuffixLength(suffixLength) &&
      isKnownSuffixLength(suffixLength - words[17]);
    if (hasOxygen) {
      cursor += words[17];
      suffixLength -= words[17];
    }
    if (suffixLength === 6) {
      return {
        projectiles,
        pickup: words[cursor] === 1
          ? { x: words[cursor + 1], y: words[cursor + 2],
            z: words[cursor + 3], type: 0 }
          : null,
        carriesThrowable: words[cursor + 4] === 1,
        chargeTicks: words[cursor + 5],
        carryType: 0,
        seedAmmo: 0,
      };
    }
    if (suffixLength < 10) {
      return {
        projectiles, pickup: null, carriesThrowable: false,
        chargeTicks: 0, carryType: 0, seedAmmo: 0,
      };
    }
    return {
      projectiles,
      pickup: words[cursor] === 1
        ? { x: words[cursor + 1], y: words[cursor + 2],
          z: words[cursor + 3], type: words[cursor + 4] }
        : null,
      carriesThrowable: words[cursor + 5] === 1,
      chargeTicks: words[cursor + 6],
      carryType: words[cursor + 7],
      seedAmmo: words[cursor + 8],
    };
  }
  function botProfile(bot) {
    const names = botAISettings.profileByBotIndex;
    const name = names[(bot.index - 1) % names.length];
    return botAISettings.profiles[name];
  }
  function nearestBotPowerup(bot, own, now) {
    let best = null;
    let bestScore = -Infinity;
    const planner = botAISettings.planner;
    const profile = botProfile(bot);
    for (let index = 0; index < (botPowerupWaypoints?.length || 0); index += 1) {
      const pickup = botPowerupWaypoints[index];
      if (!botCanUsePowerup(bot.animal, pickup.kind) ||
          (bot.triedPickups.has(index) && now < bot.triedPickups.get(index))) {
        continue;
      }
      const distance = Math.hypot(
        pickup.x - own[1], pickup.y - own[2], pickup.z - own[3]
      );
      const itemValue = planner.powerupValueByKind[String(pickup.kind)] || 0;
      const healthNeed = Math.max(0,
        1 - own[4] / planner.healthMaximum);
      const activePowerup = Math.floor(own[5] / 8) % 16;
      const activePenalty = activePowerup === 0 ? 1
        : planner.activePowerupPenalty;
      const score = (itemValue * planner.pickupBaseUtility *
        (profile.scavenging + healthNeed * planner.healthUrgencyWeight) *
        activePenalty) / Math.max(1, distance);
      if (score > bestScore) {
        best = { ...pickup, index, score };
        bestScore = score;
      }
    }
    return best ? { ...best, distance: Math.hypot(
      best.x - own[1], best.y - own[2], best.z - own[3]) } : null;
  }
  function botMoveToward(dx, dz, distance) {
    if (distance <= 1) return { x: 0, z: 0 };
    const scale = botAISettings.combat.movementMax;
    return { x: Math.round(dx * scale / distance),
      z: Math.round(dz * scale / distance) };
  }
  function botAvoidProjectile(bot, own, projectiles) {
    const radius = botAISettings.planner.threatRadius;
    for (const projectile of projectiles) {
      if (projectile.targetId !== bot.playerId) continue;
      const dx = projectile.x - own[1];
      const dy = projectile.y - own[2];
      const dz = projectile.z - own[3];
      if (dx * dx + dy * dy + dz * dz > radius * radius) continue;
      const horizontal = Math.hypot(dx, dz) || 1;
      const scale = botAISettings.combat.movementMax;
      return { x: Math.round(dz * scale / horizontal),
        z: Math.round(-dx * scale / horizontal) };
    }
    return null;
  }
  function botPickupMovement(bot, own, now) {
    const pickup = nearestBotPowerup(bot, own, now);
    if (!pickup) return null;
    const planner = botAISettings.planner;
    if (pickup.distance <= planner.pickupReachDistance &&
        Math.abs(pickup.y - own[2]) <= planner.pickupVerticalTolerance) {
      bot.triedPickups.set(pickup.index, now + planner.pickupRetryMilliseconds);
      return null;
    }
    return { ...botMoveToward(pickup.x - own[1], pickup.z - own[3],
      pickup.distance), distance: pickup.distance, pickup };
  }
  function botShouldJump(bot, own, target, distance, now) {
    const combat = botAISettings.combat;
    if (now < bot.nextJumpAt) return false;
    if (Math.abs(target[2] - own[2]) > combat.jumpVerticalThreshold ||
        distance < combat.jumpCombatDistance || (own[5] & 1) !== 0) {
      bot.nextJumpAt = now + combat.jumpCooldownMilliseconds +
        bot.index * combat.jumpBotStaggerMilliseconds;
      return true;
    }
    return false;
  }
  let browserBattleTimer = null;
  let browserBattleStartedAt = 0;
  let browserBattleLastReportAt = 0;
  function stopBrowserBotBattle(reason = "Battle stopped.") {
    if (browserBattleTimer !== null) window.clearInterval(browserBattleTimer);
    browserBattleTimer = null;
    const bots = browserBattleBots.splice(0);
    for (const bot of bots) {
      bot.intentionalClose = true;
      if (bot.socket && bot.socket.readyState < WebSocket.CLOSING) bot.socket.close();
    }
    if (reason) logGameConsole(reason);
  }
  function sendBrowserBotFrame(bot, kind, buildWords) {
    if (!bot.socket || bot.socket.readyState !== WebSocket.OPEN) return false;
    bot.sequence = bot.sequence >= MAX_SEQUENCE ? 1 : bot.sequence + 1;
    const words = [NETCODE_PROTOCOL_VERSION, kind, bot.sequence, ...buildWords];
    words.push(messageChecksum(words));
    bot.socket.send(encodeFrame(kind, bot.sequence, words));
    return true;
  }
  function connectBrowserBattleBot(animal, team, index) {
    const bot = {
      animal, team, index, sequence: 0, joinSequence: 0, playerId: 0,
      joined: false, scene: null, socket: null, nextShotAt: 0,
      nextBurstAt: Date.now() + 300, nextMeleeAt: 0, nextSpecialAt: 0,
      nextJumpAt: 0, burstAction: ACTION_DASH,
      openingRollSent: false, throwPhase: 0, throwPhaseAt: 0,
      triedPickups: new Map(), intentionalClose: false,
      wanderTarget: null, nextWanderAt: 0, previousX: 0, previousZ: 0,
      lastProgressAt: Date.now(), evasiveUntil: 0,
    };
    browserBattleBots.push(bot);
    return new Promise((resolve, reject) => {
      let settled = false;
      const finish = (error) => {
        if (settled) return;
        settled = true;
        window.clearTimeout(timeout);
        if (error) reject(error);
        else resolve(bot);
      };
      const timeout = window.setTimeout(
        () => finish(new Error("bot admission timed out")), 10000);
      try {
        const url = new URL(endpoint.value.trim(), window.location.href);
        url.pathname = animal === 1 ? "/session/goose" : "/session/cat";
        const protocols = [WEBSOCKET_SUBPROTOCOL];
        const token = authToken.value.trim();
        if (token) protocols.push(AUTH_SUBPROTOCOL_PREFIX + token);
        bot.socket = new WebSocket(url.href, protocols);
        bot.socket.binaryType = "arraybuffer";
      } catch (error) {
        finish(error);
        return;
      }
      bot.socket.onopen = () => {
        sendBrowserBotFrame(bot, HELLO, [
          CLIENT_TARGET_BROWSER, AUTHORITY_REMOTE, GAME_WEBSOCKET,
          BROWSER_CAPABILITY,
        ]);
      };
      bot.socket.onmessage = async (event) => {
        try {
          const data = event.data instanceof ArrayBuffer
            ? event.data : await event.data.arrayBuffer();
          const frame = decodeFrame(data);
          if (frame.kind === ACK && frame.words[3] === 1) {
            if (!bot.joinSequence) {
              bot.joinSequence = bot.sequence >= MAX_SEQUENCE ? 1 : bot.sequence + 1;
              bot.sequence = bot.joinSequence;
              const words = [NETCODE_PROTOCOL_VERSION, GAME, bot.joinSequence,
                GAME_JOIN_REQUEST_MARKER, GAME_ROLE_PLAYER];
              words.push(messageChecksum(words));
              bot.socket.send(encodeFrame(GAME, bot.joinSequence, words));
            }
          } else if (frame.kind === GAME &&
              frame.words[3] === GAME_JOIN_RESPONSE_MARKER) {
            if (frame.sequence !== bot.joinSequence || frame.words[4] !== 1 ||
                frame.words[5] !== GAME_ROLE_PLAYER || frame.words[6] <= 0) {
              finish(new Error("server rejected a battle bot"));
              return;
            }
            bot.playerId = frame.words[6];
            bot.joined = true;
            logGameConsole((animal === 1 ? "Red goose " : "Blue cat ") +
              index + " joined as player " + bot.playerId + ".");
            finish();
          } else if (frame.kind === GAME &&
              frame.words[3] === GAME_MULTIPLAYER_SNAPSHOT_MARKER) {
            bot.scene = frame.words;
          } else if (frame.kind === ERROR) {
            throw new Error("bot server error " + frame.words[3]);
          }
        } catch (error) {
          finish(error);
          if (bot.joined) logGameConsole("Bot " + bot.playerId +
            " protocol error: " + error.message);
        }
      };
      bot.socket.onerror = () => finish(new Error("bot WebSocket connection failed"));
      bot.socket.onclose = () => {
        if (!bot.intentionalClose && bot.joined) {
          logGameConsole("Bot " + bot.playerId + " disconnected.");
        }
        finish(new Error("bot connection closed before admission"));
      };
    });
  }
  function updateBrowserBattleBot(bot, now) {
    const words = bot.scene;
    if (!bot.joined || !words ||
        words[3] !== GAME_MULTIPLAYER_SNAPSHOT_MARKER) return;
    const actors = [];
    let own = null;
    let redAlive = 0;
    let blueAlive = 0;
    for (let index = 0; index < words[17]; index += 1) {
      const offset = 18 + index * 8;
      const actor = words.slice(offset, offset + 8);
      actors.push(actor);
      if (actor[6] === 1 && actor[4] > 0) redAlive += 1;
      if (actor[6] === 2 && actor[4] > 0) blueAlive += 1;
      if (actor[0] === bot.playerId) own = actor;
    }
    if (redAlive === 0 || blueAlive === 0) {
      stopBrowserBotBattle((redAlive === 0 ? "Blue cats" : "Red geese") +
        " win; battle bots disconnected.");
      return;
    }
    if (now - browserBattleLastReportAt >=
        botAISettings.runtime.browserReportIntervalMilliseconds) {
      logGameConsole("tick " + words[4] + " / alive " + redAlive +
        " red geese, " + blueAlive + " blue cats");
      browserBattleLastReportAt = now;
    }
    const scene = botSceneData(words);
    const activePowerup = Math.floor(own[5] / 8) % 16;
    const planner = botAISettings.planner;
    const combat = botAISettings.combat;
    const profile = botProfile(bot);
    let target = null;
    let targetScore = Infinity;
    for (const actor of actors) {
      if (actor[4] <= 0 || actor[6] === bot.team) continue;
      const dx = actor[1] - own[1];
      const dy = actor[2] - own[2];
      const dz = actor[3] - own[3];
      const distance = Math.hypot(dx, dy, dz);
      const woundBias = Math.min(combat.woundedTargetScoreCap,
        Math.max(0, planner.healthMaximum - actor[4]) *
          combat.woundedTargetHealthWeight);
      const focusedByTeammates = browserBattleBots.filter((teammate) =>
        teammate !== bot && teammate.team === bot.team &&
        teammate.goalTargetId === actor[0]).length;
      let score = distance - woundBias * profile.aggression;
      score /= 1 + focusedByTeammates * profile.teamwork *
        planner.teamFocusBonusPerTeammate;
      if (actor[0] === bot.goalTargetId && now < bot.goalUntil) {
        score /= planner.goalSwitchAdvantage;
      }
      if (score < targetScore) {
        target = actor;
        targetScore = score;
      }
    }
    if (target && target[0] !== bot.goalTargetId) {
      bot.goalTargetId = target[0];
      bot.goalUntil = now + planner.goalHoldMilliseconds;
    }
    if (Math.hypot(own[1] - bot.previousX, own[3] - bot.previousZ) >
        botAISettings.runtime.moveProgressThreshold) {
      bot.previousX = own[1];
      bot.previousZ = own[3];
      bot.lastProgressAt = now;
    } else if (now - bot.lastProgressAt > planner.stuckMilliseconds) {
      bot.evasiveUntil = now + planner.evasionMilliseconds;
      bot.lastProgressAt = now;
    }
    let moveX = 0;
    let moveZ = 0;
    let targetDistance = Infinity;
    let combatDistance = Infinity;
    let enemyDx = 0;
    let enemyDy = 0;
    let enemyDz = 0;
    let retreating = false;
    if (target) {
      enemyDx = target[1] - own[1];
      enemyDy = target[2] - own[2];
      enemyDz = target[3] - own[3];
      targetDistance = Math.hypot(enemyDx, enemyDz);
      combatDistance = Math.abs(enemyDx) + Math.abs(enemyDy) + Math.abs(enemyDz);
      const healthFraction = own[4] / planner.healthMaximum;
      retreating = healthFraction <= planner.retreatHealthFraction *
        (0.5 + profile.survival) && targetDistance <= planner.threatRadius;
      const approach = botMoveToward(enemyDx, enemyDz, targetDistance);
      const orbitDirection = (bot.index +
        Math.floor(now / combat.orbitSidePeriodMilliseconds)) % 2 ? 1 : -1;
      const tangent = {
        x: -approach.z * orbitDirection,
        z: approach.x * orbitDirection,
      };
      const radial = retreating
        ? botMoveToward(-enemyDx, -enemyDz, targetDistance)
        : targetDistance > combat.approachRange
          ? approach : targetDistance < combat.retreatRange
            ? botMoveToward(-enemyDx, -enemyDz, targetDistance)
            : { x: 0, z: 0 };
      const radialWeight = retreating
        ? planner.retreatGoalMultiplier
        : targetDistance > combat.approachRange
          ? combat.approachWeight
          : targetDistance < combat.retreatRange
            ? combat.retreatWeight : 0;
      moveX = Math.round(radial.x * radialWeight +
        tangent.x * combat.orbitWeight);
      moveZ = Math.round(radial.z * radialWeight +
        tangent.z * combat.orbitWeight);
    } else {
      if (!bot.wanderTarget || now >= bot.nextWanderAt ||
          Math.hypot(bot.wanderTarget.x - own[1],
            bot.wanderTarget.z - own[3]) <
              planner.roamTargetReachDistance) {
        const phase = (now / planner.roamPhaseMilliseconds +
          bot.index * planner.roamPhaseByBotIndex +
          bot.team * planner.roamPhaseByTeam) % 6.28;
        bot.wanderTarget = {
          x: planner.roamTargetBaseX +
            ((bot.index * planner.roamTargetStrideXByBot +
              Math.floor(now / planner.roamTargetCycleMilliseconds) *
                planner.roamTargetStrideXByCycle) %
              planner.roamTargetSpanX),
          z: planner.roamTargetBaseZ +
            ((Math.round((Math.sin(phase) + 1) *
              planner.roamTargetWaveScale) +
              bot.index * planner.roamTargetStrideZByBot) %
              planner.roamTargetSpanZ),
        };
        bot.nextWanderAt = now + planner.roamTargetRefreshMilliseconds;
      }
      const wander = botMoveToward(bot.wanderTarget.x - own[1],
        bot.wanderTarget.z - own[3],
        Math.hypot(bot.wanderTarget.x - own[1],
          bot.wanderTarget.z - own[3]));
      moveX = wander.x * profile.roaming;
      moveZ = wander.z * profile.roaming;
    }
    const powerupMovement = activePowerup === 0
      ? botPickupMovement(bot, own, now) : null;
    const pickupWanted = powerupMovement &&
      (!target || powerupMovement.distance <
        targetDistance * planner.pickupDetourFactor ||
        own[4] / planner.healthMaximum < planner.lowHealthFraction);
    if (pickupWanted) {
      moveX = powerupMovement.x;
      moveZ = powerupMovement.z;
      bot.goalPickupIndex = powerupMovement.pickup.index;
      bot.goalUntil = now + planner.goalHoldMilliseconds;
    }
    const carrying = scene.carriesThrowable;
    if (bot.throwPhase === 4 && !carrying) bot.throwPhase = 0;
    if (bot.throwPhase === 1) {
      if (carrying) bot.throwPhase = 2;
      else if (now - bot.throwPhaseAt >
          combat.throwableChargeMilliseconds) bot.throwPhase = 0;
    }
    if (bot.throwPhase === 3 &&
        scene.chargeTicks >= combat.throwChargeTicks) {
      bot.throwPhase = 4;
      bot.throwPhaseAt = now;
    }
    if (!carrying && bot.throwPhase !== 1) bot.throwPhase = 0;
    if (scene.pickup && !carrying && bot.throwPhase === 0) {
      const dx = scene.pickup.x - own[1];
      const dz = scene.pickup.z - own[3];
      const distance = Math.hypot(dx, dz);
      if (distance > combat.throwPickupCombatDistance &&
          (!target || targetDistance > combat.throwCombatDistance)) {
        const itemRoute = botMoveToward(dx, dz, distance);
        moveX = itemRoute.x;
        moveZ = itemRoute.z;
      }
    }
    const boundaryPushX = own[1] < combat.worldMinX ? 1
      : own[1] > combat.worldMaxX ? -1 : 0;
    const boundaryPushZ = own[3] < combat.worldMinZ ? 1
      : own[3] > combat.worldMaxZ ? -1 : 0;
    const movementMax = combat.movementMax;
    moveX = Math.max(-movementMax, Math.min(movementMax,
      moveX + boundaryPushX * combat.worldBoundaryPush));
    moveZ = Math.max(-movementMax, Math.min(movementMax,
      moveZ + boundaryPushZ * combat.worldBoundaryPush));
    const evasion = botAvoidProjectile(bot, own, scene.projectiles);
    if (evasion) {
      moveX = evasion.x;
      moveZ = evasion.z;
      bot.evasiveUntil = now + planner.evasionMilliseconds;
    } else if (now < bot.evasiveUntil && !target) {
      moveX = Math.max(-movementMax, Math.min(movementMax,
        moveX + combat.evasionDriftWeight));
    }
    const moveMagnitude = Math.hypot(moveX, moveZ);
    if (moveMagnitude > movementMax) {
      moveX = Math.round(moveX * movementMax / moveMagnitude);
      moveZ = Math.round(moveZ * movementMax / moveMagnitude);
    }
    let yawDelta = 0;
    if (target) {
      const desiredYaw = Math.round(Math.atan2(enemyDx, enemyDz) *
        combat.yawHalfTurn / Math.PI);
      yawDelta = ((desiredYaw - own[7] + combat.yawWrapOffset) %
        combat.yawFullTurn) - combat.yawHalfTurn;
    } else if (moveMagnitude > botAISettings.runtime.movementFacingThreshold) {
      const desiredYaw = Math.round(Math.atan2(moveX, moveZ) *
        combat.yawHalfTurn / Math.PI);
      yawDelta = ((desiredYaw - own[7] + combat.yawWrapOffset) %
        combat.yawFullTurn) - combat.yawHalfTurn;
    }
    let held = 0;
    let edge = 0;
    const healthFraction = own[4] / planner.healthMaximum;
    const canAttack = !retreating &&
      healthFraction > planner.emergencyHealthFraction;
    if (target && canAttack && now >= bot.nextShotAt &&
        combatDistance <= combat.shootRange) {
      held |= ACTION_SHOOT;
      bot.nextShotAt = now + (combatDistance <= combat.closeShootRange
        ? combat.closeShootCooldownMilliseconds
        : combat.farShootCooldownMilliseconds);
    }
    if (target && canAttack && combatDistance <= combat.meleeRange &&
        now >= bot.nextMeleeAt) {
      edge |= ACTION_MELEE;
      bot.nextMeleeAt = now + combat.meleeCooldownMilliseconds;
    }
    if (target && canAttack && now >= bot.nextSpecialAt &&
        (combatDistance <= combat.specialRange ||
          combat.poweredSpecialIds.includes(activePowerup))) {
      edge |= ACTION_SPECIAL;
      bot.nextSpecialAt = now +
        (activePowerup === combat.fastSpecialPowerupId
          ? combat.poweredSpecialCooldownMilliseconds
          : combat.specialCooldownMilliseconds);
    }
    if (now >= bot.nextBurstAt) {
      edge |= evasion ? ACTION_ROLL : bot.burstAction;
      bot.burstAction = bot.burstAction === ACTION_DASH
        ? ACTION_ROLL : ACTION_DASH;
      bot.nextBurstAt = now + (evasion
        ? combat.evasiveBurstCooldownMilliseconds
        : combat.burstCooldownMilliseconds +
          bot.index * combat.burstBotStaggerMilliseconds);
    }
    if (target && botShouldJump(bot, own, target, targetDistance, now)) {
      edge |= ACTION_JUMP;
    }
    const airborne = (own[5] & 1) === 0 &&
      own[2] > combat.airborneHeightThreshold;
    if (bot.animal === combat.gooseAnimalId &&
        (airborne || enemyDy > combat.jumpVerticalThreshold ||
          activePowerup === combat.flightPowerupId &&
            targetDistance > combat.flightPowerupRange)) {
      held |= ACTION_FLY;
    } else if (bot.animal === combat.catAnimalId &&
        (airborne || enemyDy > combat.jumpVerticalThreshold)) {
      held |= ACTION_GLIDE;
    }
    if (carrying && bot.throwPhase === 2) {
      bot.throwPhase = 3;
      bot.throwPhaseAt = now;
    } else if (carrying && bot.throwPhase === 3) {
      held |= ACTION_THROWABLE;
    } else if (!carrying && scene.pickup && bot.throwPhase === 0) {
      const dx = scene.pickup.x - own[1];
      const dy = scene.pickup.y - own[2];
      const dz = scene.pickup.z - own[3];
      const pickupDistance = Math.hypot(dx, dy, dz);
      if (pickupDistance <= combat.throwPickupDistance) {
        held |= ACTION_THROWABLE;
        bot.throwPhase = 1;
        bot.throwPhaseAt = now;
      }
    }
    sendBrowserBotFrame(bot, GAME, [
      GAME_INPUT_MARKER, words[4],
      moveX, moveZ,
      Math.max(-combat.lookMax, Math.min(combat.lookMax,
        yawDelta * combat.lookScale)),
      Math.max(-combat.lookMax, Math.min(combat.lookMax,
        -enemyDy * combat.lookScale)), held, edge,
    ]);
  }
  async function startBrowserBotBattle() {
    if (!connected || joinedRole !== GAME_ROLE_SPECTATOR) {
      throw new Error("connect to the game as a spectator before starting bots");
    }
    if (browserBattleBots.length > 0) {
      throw new Error("battle bots are already running; use /stop first");
    }
    if (authToken.value.trim() && !validAuthToken(authToken.value.trim())) {
      throw new Error("session token must be 8-128 safe ASCII characters");
    }
    browserBattleLastReportAt = 0;
    logGameConsole("Starting 4v4 battle; connecting bot players...");
    try {
      await loadBrowserBotAIConfig();
      await loadBotPowerupWaypoints();
      await Promise.all(Array.from({ length: 4 }, (_, index) =>
        connectBrowserBattleBot(1, 1, index + 1)));
      await Promise.all(Array.from({ length: 4 }, (_, index) =>
        connectBrowserBattleBot(2, 2, index + 1)));
    } catch (error) {
      stopBrowserBotBattle("Battle setup failed: " + error.message);
      throw error;
    }
    browserBattleStartedAt = Date.now();
    browserBattleTimer = window.setInterval(() => {
      const now = Date.now();
      if (now - browserBattleStartedAt >=
          botAISettings.runtime.browserMatchDurationMilliseconds) {
        stopBrowserBotBattle("Battle time limit reached; bots disconnected.");
        return;
      }
      for (const bot of browserBattleBots) updateBrowserBattleBot(bot, now);
    }, botAISettings.runtime.browserDecisionIntervalMilliseconds);
    logGameConsole("Battle live: 4 red geese vs 4 blue cats. Spectate from this page.");
  }
  function runRemoteAdminCommand(command) {
    const normalized = command.toLowerCase();
    if (normalized === "/help") {
      logGameConsole("Remote commands: /status, /say <text>, /team <id> <free|red|blue>, /kick <id>, /mapvote start");
      return;
    }
    if (normalized === "/status") {
      sendAdminCommand(GAME_ADMIN_STATUS);
      return;
    }
    if (normalized === "/mapvote start") {
      sendAdminCommand(GAME_ADMIN_MAPVOTE_START);
      return;
    }
    if (normalized.startsWith("/say ")) {
      const text = command.slice(5).trim();
      if (!text || text.length > 80 ||
          Array.from(text).some((character) => {
            const code = character.charCodeAt(0);
            return code < 32 || code > 126;
          })) {
        throw new Error("say requires 1-80 printable ASCII characters");
      }
      sendAdminCommand(GAME_ADMIN_SAY,
        [text.length, ...Array.from(text, (character) => character.charCodeAt(0))]);
      return;
    }
    const fields = normalized.split(/\s+/);
    if (fields.length === 2 && fields[0] === "/kick") {
      const playerId = Number(fields[1]);
      if (!Number.isInteger(playerId) || playerId < 1 || playerId > MAX_SEQUENCE) {
        throw new Error("kick requires a numeric player ID");
      }
      sendAdminCommand(GAME_ADMIN_KICK, [playerId]);
      return;
    }
    if (fields.length === 3 && fields[0] === "/team") {
      const playerId = Number(fields[1]);
      const teams = { free: 0, red: 1, blue: 2 };
      if (!Number.isInteger(playerId) || playerId < 1 || playerId > MAX_SEQUENCE ||
          !Object.prototype.hasOwnProperty.call(teams, fields[2])) {
        throw new Error("team syntax: /team <player-id> <free|red|blue>");
      }
      sendAdminCommand(GAME_ADMIN_SET_TEAM, [playerId, teams[fields[2]]]);
      return;
    }
    throw new Error("unknown remote command; use /help");
  }
  async function runGameConsoleCommand(command) {
    if (joinedRole === GAME_ROLE_ADMIN) {
      try {
        runRemoteAdminCommand(command);
      } catch (error) {
        logGameConsole("Remote command rejected: " + error.message);
      }
      return;
    }
    const normalized = command.toLowerCase();
    if (normalized === "/help") {
      logGameConsole("Commands: /b2teams4, /stop, /help");
    } else if (normalized === "/stop") {
      if (browserBattleBots.length === 0) logGameConsole("No battle bots are running.");
      else stopBrowserBotBattle("Battle stopped by console command.");
    } else if (normalized === "/b2teams4") {
      try {
        await startBrowserBotBattle();
      } catch (error) {
        logGameConsole("Command failed: " + error.message);
      }
    } else {
      logGameConsole("Unknown command. Try /help.");
    }
  }
  gameConsoleForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const command = gameConsoleInput.value.trim();
    if (!command) return;
    logGameConsole("> " + command);
    gameConsoleInput.value = "";
    gameConsoleSubmit.disabled = true;
    Promise.resolve(runGameConsoleCommand(command))
      .finally(() => { gameConsoleSubmit.disabled = false; });
  });
  window.addEventListener("pagehide", () => stopBrowserBotBattle(""));
  let requestedRole = GAME_ROLE_PLAYER;
  let joinedRole = null;
  let joinSequence = 0;
  function sendJoinRequest() {
    if (!socket || socket.readyState !== WebSocket.OPEN || !connected) return;
    joinSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, joinSequence,
      GAME_JOIN_REQUEST_MARKER, requestedRole];
    if (requestedRole === GAME_ROLE_PLAYER) words.push(Number(teamSelect.value));
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, joinSequence, words));
    setRuntimeState("joining as " +
      (requestedRole === GAME_ROLE_SPECTATOR ? "spectator"
        : requestedRole === GAME_ROLE_TRAINING ? "training" : "player"));
  }
  function sendAdminCommand(operation, payload = []) {
    if (!connected || joinedRole !== GAME_ROLE_ADMIN || !socket ||
        socket.readyState !== WebSocket.OPEN) {
      throw new Error("connect as remote administrator first");
    }
    const frameSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, frameSequence,
      GAME_ADMIN_MARKER, operation, ...payload];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, frameSequence, words));
  }
  let joinedPlayerId = 0;
  function appendLobbyChat(channel, target, sender, text) {
    const label = channel === CHAT_TEAM ? "TEAM" :
      channel === CHAT_WHISPER ? "WHISPER" : "GLOBAL";
    const line = document.createElement("div");
    line.textContent = "[" + label + "] " + sender + ": " + text;
    lobbyChatOutput.appendChild(line);
    while (lobbyChatOutput.childElementCount > 60) {
      lobbyChatOutput.firstElementChild.remove();
    }
    lobbyChatOutput.scrollTop = lobbyChatOutput.scrollHeight;
    lobbyChat.open = true;
  }
  function syncWhisperRecipients(scene) {
    const previous = lobbyChatTarget.value;
    while (lobbyChatTarget.children.length > 1) {
      lobbyChatTarget.removeChild(lobbyChatTarget.children[1]);
    }
    for (const actor of scene.actors) {
      if (actor.id <= 0 || actor.id === joinedPlayerId || actor.kind === 3) continue;
      const option = document.createElement("option");
      option.value = String(actor.id);
      option.textContent = (actor.kind === 1 ? "Goose " : "Cat ") + actor.id;
      lobbyChatTarget.appendChild(option);
    }
    if ([...lobbyChatTarget.children].some((option) => option.value === previous)) {
      lobbyChatTarget.value = previous;
    }
  }
  lobbyChatForm.addEventListener("submit", (event) => {
    event.preventDefault();
    if (!socket || socket.readyState !== WebSocket.OPEN ||
        joinedRole === null || !authoritativeReady) return;
    const channel = Number(lobbyChatChannel.value);
    const target = channel === CHAT_GLOBAL ? 0 :
      channel === CHAT_TEAM ? Number(teamSelect.value) :
        Number(lobbyChatTarget.value);
    const message = lobbyChatInput.value.trim();
    if (!message || message.length > 80 ||
        Array.from(message).some((character) => {
          const value = character.charCodeAt(0);
          return value < 32 || value > 126;
        })) {
      appendLobbyChat(CHAT_GLOBAL, 0, "system", "Use 1-80 printable ASCII characters.");
      return;
    }
    if (channel === CHAT_TEAM &&
        (joinedRole === GAME_ROLE_SPECTATOR || target < 1 || target > 2)) {
      appendLobbyChat(CHAT_GLOBAL, 0, "system", "Select a team before using team chat.");
      return;
    }
    if (channel === CHAT_WHISPER &&
        (!Number.isInteger(target) || target < 1 || target > MAX_SEQUENCE ||
          target === joinedPlayerId)) {
      appendLobbyChat(CHAT_GLOBAL, 0, "system", "Enter another player's ID to whisper.");
      return;
    }
    const text = Array.from(message, (character) => character.charCodeAt(0));
    const frameSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, frameSequence,
      GAME_CHAT_MARKER, channel, target, text.length, 0, ...text];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, frameSequence, words));
    lobbyChatInput.value = "";
  });
  function parseMultiplayerScene(words) {
    const actors = [];
    for (let index = 0; index < words[17]; index += 1) {
      const offset = 18 + index * 8;
      const rawState = words[offset + 5];
      actors.push({
        id: words[offset],
        x: words[offset + 1],
        y: words[offset + 2],
        z: words[offset + 3],
        health: words[offset + 4],
        state: rawState % 8,
        powerUp: Math.floor(rawState / 8) % 16,
        animation: Math.floor(rawState / 128) % 16,
        dizzy: Math.floor(rawState / 2048) % 2 === 1,
        kind: words[offset + 6],
        yaw: words[offset + 7],
      });
    }
    const projectiles = [];
    const throwables = [];
    const impacts = [];
    let lastInputSequence = 0;
    let pickup = null;
    let carriesThrowable = false;
    let throwableChargeTicks = 0;
    const trailer = 18 + words[17] * 8;
    let carryType = 0;
    let seedAmmo = 0;
    let mapId = 1;
    let matchPhase = 0;
    let matchTicksRemaining = 0;
    let mapVoteCounts = [0, 0];
    let respawnTicksRemaining = 0;
    const slicePickups = [];

    if (words.length !== 19 + words[17] * 8) {
      lastInputSequence = words[trailer];
      let offset = trailer + 4;
      for (let index = 0; index < words[trailer + 1]; index += 1, offset += 8) {
        projectiles.push({ id: words[offset], sourceId: words[offset + 1],
          targetId: words[offset + 2], x: words[offset + 3], y: words[offset + 4],
          z: words[offset + 5], ttl: words[offset + 6], kind: words[offset + 7] });
      }
      for (let index = 0; index < words[trailer + 2]; index += 1, offset += 8) {
        throwables.push({ id: words[offset], sourceId: words[offset + 1],
          x: words[offset + 2], y: words[offset + 3], z: words[offset + 4],
          ttl: words[offset + 5], type: words[offset + 6],
          kind: words[offset + 6], fuseTicks: words[offset + 7] });
      }
      for (let index = 0; index < words[trailer + 3]; index += 1, offset += 8) {
        impacts.push({ sequence: words[offset], kind: words[offset + 1],
          sourceId: words[offset + 2], targetId: words[offset + 3],
          x: words[offset + 4], y: words[offset + 5], z: words[offset + 6],
          damage: words[offset + 7] });
      }
      let suffix = offset;
      const tailLength = words.length - suffix - 1;
      const isSuffixLength = (length) => length === 0 || length === 6 ||
        (length >= 10 && length <= 33 &&
          ((length - 10) % 4 === 0 ||
            (length >= 16 && (length - 16) % 4 === 0) ||
            (length >= 17 && (length - 17) % 4 === 0)));
      const hasNewSuffix = tailLength >= 10 && tailLength <= 33 &&
        Number.isInteger(words[suffix + 9]) &&
        words[suffix + 9] >= 0 && words[suffix + 9] <= 4 &&
        (tailLength === 10 + words[suffix + 9] * 4 ||
          tailLength === 16 + words[suffix + 9] * 4 ||
          tailLength === 17 + words[suffix + 9] * 4);
      const hasOxygen = !hasNewSuffix && !isSuffixLength(tailLength) &&
        isSuffixLength(tailLength - words[17]);
      if (hasOxygen) {
        for (let index = 0; index < words[17]; index += 1) {
          actors[index].oxygen = words[suffix + index];
        }
        suffix += words[17];
      }
      const suffixLength = words.length - suffix - 1;
      if (suffixLength === 6) {
        pickup = words[suffix] === 1
          ? { x: words[suffix + 1], y: words[suffix + 2],
            z: words[suffix + 3], type: 0 }
          : null;
        carriesThrowable = words[suffix + 4] === 1;
        throwableChargeTicks = words[suffix + 5];
      } else if (suffixLength >= 10) {
        pickup = words[suffix] === 1
          ? { x: words[suffix + 1], y: words[suffix + 2],
            z: words[suffix + 3], type: words[suffix + 4] }
          : null;
        carriesThrowable = words[suffix + 5] === 1;
        throwableChargeTicks = words[suffix + 6];
        carryType = words[suffix + 7];
        seedAmmo = words[suffix + 8];
        for (let index = 0; index < words[suffix + 9]; index += 1) {
          const sliceOffset = suffix + 10 + index * 4;
          slicePickups.push({ id: words[sliceOffset], x: words[sliceOffset + 1],
            y: words[sliceOffset + 2], z: words[sliceOffset + 3] });
        }
        const sliceCount = words[suffix + 9];
        if (suffixLength === 16 + sliceCount * 4 ||
            suffixLength === 17 + sliceCount * 4) {
          const metadata = suffix + 10 + sliceCount * 4;
          mapId = words[metadata];
          matchPhase = words[metadata + 1];
          matchTicksRemaining = words[metadata + 2];
          mapVoteCounts = [words[metadata + 3], words[metadata + 4]];
          if (suffixLength === 17 + sliceCount * 4) {
            respawnTicksRemaining = words[metadata + 6];
          }
        }
      }
    }
    const playerX = words[7];
    const playerY = words[8];
    const playerZ = words[9];
    const yaw = words[10];
    const pitch = words[11];
    const localActor = actors.find((actor) => actor.id === words[6]);
    const cameraYaw = yaw * Math.PI / 180;
    return {
      tick: words[4],
      mapId,
      matchPhase,
      matchTicksRemaining,
      mapVoteCounts,
      respawnTicksRemaining,
      role: words[5],
      training: words[5] === GAME_ROLE_TRAINING,
      playerId: words[6],
      health: localActor ? localActor.health : null,
      stamina: null,
      ammo: null,
      combo: 0,
      playerX,
      playerY,
      playerZ,
      yaw,
      pitch,
      camera: {
        x: playerX - Math.sin(cameraYaw) * 16,
        y: playerY + 8,
        z: playerZ - Math.cos(cameraYaw) * 16,
        yaw,
        pitch,
      },
      actors,
      projectiles,
      throwables,
      impacts,
      pickup,
      carriesThrowable,
      throwableChargeTicks,
      carryType,
      seedAmmo,
      slicePickups,
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
        !authoritativeReady) return;
    if (joinedRole !== GAME_ROLE_SPECTATOR && sceneState?.health === 0) {
      return;
    }
    if (joinedRole === GAME_ROLE_SPECTATOR) {
      if (Number.isFinite(changes.moveX)) {
        spectatorMoveX = Math.max(-1000, Math.min(1000, changes.moveX));
      }
      if (Number.isFinite(changes.moveZ)) {
        spectatorMoveZ = Math.max(-1000, Math.min(1000, changes.moveZ));
      }
      const lookYaw = Number.isFinite(changes.lookYaw) ? changes.lookYaw : 0;
      const lookPitch = Number.isFinite(changes.lookPitch) ? changes.lookPitch : 0;
      spectatorLookYawOffset = (spectatorLookYawOffset + lookYaw + 360) % 360;
      spectatorLookPitchOffset = Math.max(-80, Math.min(80,
        spectatorLookPitchOffset + lookPitch));
      return;
    }
    if (Number.isFinite(changes.moveX)) gameplayMoveX = Math.max(-1000, Math.min(1000, changes.moveX));
    if (Number.isFinite(changes.moveZ)) gameplayMoveZ = Math.max(-1000, Math.min(1000, changes.moveZ));
    const lookYaw = Math.round((changes.lookYaw || 0) * 10) / 10;
    const lookPitch = Math.round((changes.lookPitch || 0) * 10) / 10;
    const yaw = ((sceneState?.yaw || 0) + lookYaw) * Math.PI / 180;
    const cosine = Math.cos(yaw);
    const sine = Math.sin(yaw);
    const worldMoveX = Math.round(gameplayMoveX * cosine + gameplayMoveZ * sine);
    const worldMoveZ = Math.round(-gameplayMoveX * sine + gameplayMoveZ * cosine);
    const inputSequence = nextSequence();
    const words = [NETCODE_PROTOCOL_VERSION, GAME, inputSequence,
      GAME_INPUT_MARKER, Math.max(0, Math.min(GAME_MAXIMUM_TICK, sceneState?.tick || 0)),
      worldMoveX, worldMoveZ,
      Math.round(lookYaw * 10),
      Math.round(lookPitch * 10),
      changes.heldActions ?? gameplayHeldActions,
      changes.edgeActions || 0];
    words.push(messageChecksum(words));
    socket.send(encodeFrame(GAME, inputSequence, words));
    pendingInputFrames.set(inputSequence, {
      moveX: worldMoveX,
      moveZ: worldMoveZ,
      lookYaw,
      lookPitch,
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

  function disconnect(explicit = true, preserveScene = false) {
    if (browserBattleBots.length > 0) {
      stopBrowserBotBattle("Spectator disconnected; battle bots stopped.");
    }
    const activeSocket = socket;
    socket = null;
    joinedRole = null;
    joinedPlayerId = 0;
    lobbyChatSend.disabled = true;
    connected = false;
    authoritativeReady = false;
    if (pingTimer !== null) window.clearInterval(pingTimer);
    pingTimer = null;
    pingSentTimes.clear();
    pendingMovement.clear();
    pendingInputFrames.clear();
    if (!preserveScene) {
      spectatorFollowActive = false;
      spectatorFollowTargetId = 0;
      spectatorInitialFollowChosen = false;
    }
    lastSnapshotSequence = 0;
    spectatorMoveX = 0;
    spectatorMoveZ = 0;
    spectatorVerticalKeys.clear();
    joinSequence = 0;
    remoteSnapshots.length = 0;
    remoteArrivalJitterMs = 0;
    previousRemoteArrivalAt = 0;
    previousRemoteTick = -1;
    localMovementBlend = null;
    if (sceneState && !preserveScene) {
      const disconnectedScene = {
        ...sceneState,
        actors: [],
        projectiles: [],
        throwables: [],
        impacts: [],
        slicePickups: [],
        labels: [],
        sceneObjects: [],
      };
      updateScene(disconnectedScene);
      clearDamageNumberLabels();
    }
    intentionalDisconnect = explicit;
    if (explicit) {
      clearReconnectTimer();
      reconnectAttempt = 0;
      spectatorHealthBaseline = false;
      spectatorEvents.length = 0;
      spectatorEventFeed.replaceChildren();
      spectatorEventFeed.hidden = true;
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
    disconnect(false, isReconnect);
    intentionalDisconnect = false;
    let url;
    let token = "";
    try {
      url = new URL(endpoint.value.trim(), window.location.href);
      if (url.protocol !== "ws:" && url.protocol !== "wss:") {
        throw new Error("endpoint must use ws:// or wss://");
      }
      requestedRole = roleSelect.value === "spectator" ? GAME_ROLE_SPECTATOR
        : roleSelect.value === "training" ? GAME_ROLE_TRAINING
        : roleSelect.value === "admin" ? GAME_ROLE_ADMIN
        : GAME_ROLE_PLAYER;
      if (!isReconnect) {
        spectatorFollowActive = false;
        spectatorFollowTargetId = 0;
        spectatorInitialFollowChosen = false;
        spectatorHealthBaseline = false;
        spectatorActorHealth.clear();
        spectatorEvents.length = 0;
        spectatorEventFeed.replaceChildren();
        spectatorCameraYaw = spectatorCameraHome.yaw;
        spectatorCameraPitch = spectatorCameraHome.pitch;
        spectatorLookYawOffset = 0;
        spectatorLookPitchOffset = 0;
        spectatorCameraPosition = { ...spectatorCameraHome };
        spectatorMoveX = 0;
        spectatorMoveZ = 0;
        spectatorVerticalKeys.clear();
        lastSpectatorCameraUpdateAt = 0;
      }
      const expectedPath = requestedRole === GAME_ROLE_ADMIN ? "/admin"
        : requestedRole === GAME_ROLE_SPECTATOR ? "/spectate" : "/session";
      url.pathname = expectedPath;
      token = authToken.value.trim();
      if (requestedRole === GAME_ROLE_ADMIN) {
        if (token.length < RCON_SECRET_MINIMUM_LENGTH || token.length > 128 ||
            !/^[A-Za-z0-9._~-]+$/.test(token)) {
          throw new Error("remote admin secret must be 32-128 safe ASCII characters");
        }
      } else if (token && !validAuthToken(token)) {
        throw new Error("session token must be 8-128 safe ASCII characters");
      }
    } catch (error) {
      intentionalDisconnect = true;
      setRuntimeState("rejected / invalid endpoint", "#f87171");
      setStatus("REJECTED / " + error.message, "#f87171");
      return;
    }
    const protocols = [WEBSOCKET_SUBPROTOCOL];
    if (token) protocols.push(requestedRole === GAME_ROLE_ADMIN
      ? RCON_SUBPROTOCOL_PREFIX + token : AUTH_SUBPROTOCOL_PREFIX + token);
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
          if (requestedRole === GAME_ROLE_ADMIN) {
            joinedRole = GAME_ROLE_ADMIN;
            authoritativeReady = true;
            setAsyncButtonState(connectButton, "success", "LEAVE");
            setRuntimeState("remote administrator connected", "#4ade80");
            setStatus("");
          } else {
            sendJoinRequest();
          }
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
          if (frame.words[3] === GAME_ADMIN_RESPONSE_MARKER) {
            const operation = frame.words[4];
            const result = frame.words[5];
            if (result !== 0) {
              logGameConsole("Remote command failed: " +
                (result === 2 ? "player not found" : "invalid command"));
            } else if (operation === GAME_ADMIN_STATUS) {
              logGameConsole("tick=" + frame.words[6] +
                " players=" + frame.words[7] +
                " spectators=" + frame.words[8]);
            } else {
              logGameConsole("Remote command completed.");
            }
          } else if (frame.words[3] === GAME_CHAT_RESPONSE_MARKER) {
            const message = String.fromCharCode(...frame.words.slice(8, 8 + frame.words[6]));
            appendLobbyChat(frame.words[4], frame.words[5], frame.words[7], message);
          } else if (frame.words[3] === GAME_JOIN_RESPONSE_MARKER) {
            if (frame.sequence !== joinSequence || frame.words[4] !== 1 ||
                frame.words[5] !== requestedRole) {
              throw new Error("multiplayer join rejected");
            }
            lobbyChatSend.disabled = false;
            joinedPlayerId = frame.words[6];
            joinedRole = frame.words[5];
            setRuntimeState("joined / " +
              (joinedRole === GAME_ROLE_SPECTATOR ? "spectator"
                : joinedRole === GAME_ROLE_TRAINING ? "training" : "player"),
              "#4ade80");
            setStatus("JOINED / " +
              (joinedRole === GAME_ROLE_TRAINING ? "training / " : "") +
              "player=" + frame.words[6] +
              " players=" + frame.words[7] +
              " spectators=" + frame.words[8], "#4ade80");
          } else if (frame.words[3] === GAME_MULTIPLAYER_SNAPSHOT_MARKER) {
            const scene = parseMultiplayerScene(frame.words);
            syncWhisperRecipients(scene);
            if (joinedRole === null || scene.role !== joinedRole) {
              throw new Error("multiplayer snapshot role mismatch");
            }
            authoritativeReady = true;
            setGameControlsEnabled(true, joinedRole === GAME_ROLE_SPECTATOR);
            setAsyncButtonState(connectButton, "success", "LEAVE");
            applyAuthoritativeScene(scene, frame.sequence);
            setRuntimeState(joinedRole === GAME_ROLE_SPECTATOR
              ? "spectating" : joinedRole === GAME_ROLE_TRAINING
                ? "training" : "in game", "#4ade80");
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
      spectatorMoveX = 0;
      spectatorMoveZ = 0;
      spectatorVerticalKeys.clear();
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
      ? GAME_MAXIMUM_INPUT_AXIS *
        (joinedRole === GAME_ROLE_SPECTATOR
          ? 1 : clientSettings.movementSpeedPercent / 100) / magnitude
      : 0;
    sendGameplayInput({ moveX: Math.round(x * scale), moveZ: Math.round(z * scale) });
  }
  document.addEventListener("keydown", (event) => {
    if (!authoritativeReady || event.ctrlKey || event.metaKey || event.altKey) return;
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
    if (joinedRole === GAME_ROLE_SPECTATOR &&
        (event.code === "Space" || event.code === "ShiftLeft" ||
          event.code === "ShiftRight")) {
      event.preventDefault();
      spectatorVerticalKeys.add(event.code);
    }
    if (event.key === "q" || event.key === "Q") {
      event.preventDefault();
      sendGameplayInput({ lookYaw: -15 });
    } else if (event.key === "e" || event.key === "E") {
      event.preventDefault();
      sendGameplayInput({ lookYaw: 15 });
    }
  });
  document.addEventListener("keyup", (event) => {
    if (spectatorVerticalKeys.delete(event.code)) {
      event.preventDefault();
      return;
    }
    if (!heldMovementKeys.delete(event.code)) return;
    event.preventDefault();
    updateKeyboardMovement();
  });
  window.addEventListener("blur", () => {
    const hadMovement = heldMovementKeys.size > 0;
    const heldActions = gameplayHeldActions & (ACTION_JUMP | ACTION_GLIDE |
      ACTION_FLY | ACTION_SHOOT | ACTION_THROWABLE);
    heldMovementKeys.clear();
    spectatorVerticalKeys.clear();
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
    ["b", [ACTION_SHOOT, true]], ["t", [ACTION_THROWABLE, true]],
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
      const horizontalDirection = event.pointerType === "touch" ? -1 : 1;
      const lookYaw = Math.max(-180, Math.min(180,
        horizontalDirection * deltaX * sensitivity * 1.25));
      const lookPitch = Math.max(-180, Math.min(180, -deltaY * sensitivity * 1.25));
      if (lookYaw !== 0 || lookPitch !== 0) {
        const spectatorDirection = joinedRole === GAME_ROLE_SPECTATOR &&
          event.pointerType === "touch" ? -1 : 1;
        sendGameplayInput({
          lookYaw: lookYaw * spectatorDirection,
          lookPitch: lookPitch * spectatorDirection,
        });
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
    protocolVersion: NETCODE_PROTOCOL_VERSION,
    maxFrameBytes: MAX_FRAME_BYTES,
  });
})();
