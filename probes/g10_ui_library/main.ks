String svgId = kookieUiPublishedUiGatogansoMarkId()
String svgSource = kookieUiPublishedUiGatogansoMarkSource()
Int svgKind = kookieUiPublishedUiGatogansoMarkKind()
String svgAlt = kookieUiPublishedUiGatogansoMarkAlt()
String svgChecksum = kookieUiPublishedUiGatogansoMarkChecksum()
String pngId = kookieUiPublishedUiPlayerHeartsId()
String pngSource = kookieUiPublishedUiPlayerHeartsSource()
Int pngKind = kookieUiPublishedUiPlayerHeartsKind()
String pngAlt = kookieUiPublishedUiPlayerHeartsAlt()
String pngChecksum = kookieUiPublishedUiPlayerHeartsChecksum()
String soundId = "ui.cursor.1"
String soundSource = "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg"
Int soundKind = kookieUiScriptSoundOgg()
String soundLabel = "Menu cursor"
String soundChecksum = "5f3d6b0caf71a1321aa9dae650cb0761f5f183e508463343590997e282f74cf7"

assert(svgKind == kookieUiScriptAssetSvg() &&
    pngKind == kookieUiScriptAssetPng() &&
    soundKind == kookieUiScriptSoundOgg(),
    "KofScript UI bindings must retain manifest asset and sound kinds")

var invalid = KookieUiScriptDocument(33)
assert(!invalid.valid(),
    "KofScript UI document must reject capacities above the bounded limit")

var document = KookieUiScriptDocument(8)
assert(document.valid() && document.boundCount() == 0 && !document.shown(),
    "KofScript UI document must start empty and hidden")
assert(document.bindText(
        "GATOGANSO", kookieUiScriptRoleDisplay(), 36) &&
    document.bindAsset(svgId, svgSource, svgKind, svgAlt, svgChecksum) &&
    document.bindAsset(pngId, pngSource, pngKind, pngAlt, pngChecksum) &&
    document.bindIcon("heart", "Health", 48) &&
    document.bindSound(
        soundId, soundSource, soundKind, soundLabel, soundChecksum, 1001, 80) &&
    document.boundCount() == 5,
    "KofScript UI document must admit bounded semantic nodes")
assert(document.nodeKind(0) == kookieUiScriptNodeText() &&
    document.nodeKind(1) == kookieUiScriptNodeAsset() &&
    document.nodeKind(2) == kookieUiScriptNodeAsset() &&
    document.nodeKind(3) == kookieUiScriptNodeIcon() &&
    document.nodeKind(4) == kookieUiScriptNodeSound() &&
    document.nodeAssetType(1) == svgKind &&
    document.nodeAssetType(2) == pngKind &&
    document.nodeAssetType(4) == soundKind &&
    document.nodeId(1) == svgId && document.nodeSource(2) == pngSource &&
    document.nodeAlt(3) == "Health" && document.nodeSize(3) == 48 &&
    document.nodeId(4) == soundId &&
    document.nodeClipId(4) == 1001 && document.nodeGain(4) == 80,
    "KofScript UI nodes must expose deterministic asset and sound descriptors")
assert(!document.bindAsset(
        "", "../invalid.svg", kookieUiScriptAssetSvg(), "", "not-a-sha256"),
    "KofScript UI assets must reject invalid publication descriptors")
assert(!document.bindSound(
        "ui.invalid", "../audio/ui/cursor.ogg", soundKind, "Invalid",
        soundChecksum, 1002, 80) &&
    !document.bindSound(
        "ui.invalid-gain", soundSource, soundKind, "Invalid gain",
        soundChecksum, 1002, 101),
    "KofScript UI sounds must reject traversal paths and invalid gains")
var beforeShow = document.checksum()
assert(document.show() && document.shown() && document.checksum() != beforeShow,
    "KofScript UI document must transition to shown")
assert(!document.bindText("late", kookieUiScriptRoleBody(), 16),
    "shown KofScript UI documents must reject late mutation")
assert(document.close() && document.closed() && !document.shown(),
    "KofScript UI document must close deterministically")
var small = KookieUiScriptDocument(2)
assert(!small.bindMenu("GATOGANSO", "OLD SCHOOL COOP", "HINT") &&
    small.boundCount() == 0,
    "KofScript menu composition must reject capacity without partial nodes")
var screens = KookieUiScriptDocument(8)
assert(screens.bindMenu(
        "GATOGANSO", "OLD SCHOOL COOP", "ARROWS ENTER ESC") &&
    screens.bindHud("HP 100", "AMMO 3", "BAG 0/8", "XP 0/1") &&
    screens.boundCount() == 7 &&
    screens.nodeRole(0) == kookieUiScriptRoleDisplay() &&
    screens.nodeSource(3) == "HP 100" &&
    screens.show() && screens.close(),
    "KofScript UI must describe reusable menu and HUD nodes")
println("KOOKIE G10 KofScript UI library verified")
