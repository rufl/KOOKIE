Int kookieUiScriptNodeText() { return 1 }
Int kookieUiScriptNodeAsset() { return 2 }
Int kookieUiScriptNodeIcon() { return 3 }
Int kookieUiScriptNodeSound() { return 4 }

Int kookieUiScriptAssetPng() { return 1 }
Int kookieUiScriptAssetSvg() { return 2 }
Int kookieUiScriptAssetSvgz() { return 3 }
Int kookieUiScriptSoundOgg() { return 4 }
Int kookieUiScriptSoundWav() { return 5 }

Int kookieUiScriptRoleBody() { return 0 }
Int kookieUiScriptRoleDisplay() { return 1 }
Int kookieUiScriptMaximumNodes() { return 32 }

Bool kookieUiScriptSupportedIcon(String name) {
    return name == "home" || name == "star" || name == "heart" ||
        name == "search" || name == "settings" || name == "user" ||
        name == "menu" || name == "close" || name == "check" ||
        name == "plus" || name == "minus" || name == "trash" ||
        name == "edit" || name == "share" || name == "download" ||
        name == "upload" || name == "mail" || name == "phone" ||
        name == "calendar" || name == "clock" || name == "eye" ||
        name == "lock"
}

Bool kookieUiScriptSha256(String value) {
    if (value.length() != 64) { return false }
    for (var index = 0; index < value.length(); index = index + 1) {
        var character = value.charAt(index) as Int
        if (!((character >= 48 && character <= 57) ||
            (character >= 97 && character <= 102))) {
            return false
        }
    }
    return true
}

Bool kookieUiScriptSafePath(String value) {
    if (value.length() == 0) { return false }
    var first = value.charAt(0) as Int
    if (first == 47 || first == 92 || first == 58) { return false }
    for (var index = 0; index < value.length(); index = index + 1) {
        var character = value.charAt(index) as Int
        if (character <= 32 || character == 35 || character == 58 ||
            character == 63 || character == 92) {
            return false
        }
        if (character == 47 &&
            (index + 1 == value.length() ||
                (index > 0 && (value.charAt(index - 1) as Int) == 47))) {
            return false
        }
        if (character == 46) {
            var atStart = index == 0 ||
                (value.charAt(index - 1) as Int) == 47
            var atEnd = index + 1 == value.length() ||
                (value.charAt(index + 1) as Int) == 47
            if (atStart && atEnd) { return false }
            if (index + 1 < value.length() &&
                (value.charAt(index + 1) as Int) == 46) {
                var parentAtEnd = index + 2 == value.length() ||
                    (value.charAt(index + 2) as Int) == 47
                if (atStart && parentAtEnd) { return false }
            }
        }
    }
    return true
}

Bool kookieUiScriptSafeMediaPath(String value) {
    if (value.length() == 0) { return false }
    var first = value.charAt(0) as Int
    if (first == 47 || first == 92 || first == 58) { return false }
    for (var index = 0; index < value.length(); index = index + 1) {
        var character = value.charAt(index) as Int
        if (character < 32 || character == 35 || character == 58 ||
            character == 63 || character == 92) {
            return false
        }
        if (character == 47 &&
            (index + 1 == value.length() ||
                (index > 0 && (value.charAt(index - 1) as Int) == 47))) {
            return false
        }
        if (character == 46) {
            var atStart = index == 0 ||
                (value.charAt(index - 1) as Int) == 47
            var atEnd = index + 1 == value.length() ||
                (value.charAt(index + 1) as Int) == 47
            if (atStart && atEnd) { return false }
            if (index + 1 < value.length() &&
                (value.charAt(index + 1) as Int) == 46) {
                var parentAtEnd = index + 2 == value.length() ||
                    (value.charAt(index + 2) as Int) == 47
                if (atStart && parentAtEnd) { return false }
            }
        }
    }
    return true
}

Bool kookieUiScriptHasSuffix(String value, String suffix) {
    if (suffix.length() == 0 || value.length() < suffix.length()) {
        return false
    }
    var start = value.length() - suffix.length()
    for (var index = 0; index < suffix.length(); index = index + 1) {
        if (value.charAt(start + index) != suffix.charAt(index)) {
            return false
        }
    }
    return true
}

Int kookieUiScriptStringScore(String value) {
    var result = 7
    for (var index = 0; index < value.length(); index = index + 1) {
        result = (result * 31 + (value.charAt(index) as Int)) % 1000003
    }
    return result
}

Int kookieUiScriptMix(Int state, Int value) {
    return (state * 31 + value) % 1000003
}

Bool kookieUiScriptAssetTypeValid(Int assetType, String source) {
    if (assetType == kookieUiScriptAssetPng()) {
        return kookieUiScriptHasSuffix(source, ".png")
    }
    if (assetType == kookieUiScriptAssetSvg()) {
        return kookieUiScriptHasSuffix(source, ".svg")
    }
    if (assetType == kookieUiScriptAssetSvgz()) {
        return kookieUiScriptHasSuffix(source, ".svgz")
    }
    return false
}

Bool kookieUiScriptSoundTypeValid(Int assetType, String source) {
    if (!kookieUiScriptSafeMediaPath(source)) { return false }
    if (assetType == kookieUiScriptSoundOgg()) {
        return kookieUiScriptHasSuffix(source, ".ogg")
    }
    if (assetType == kookieUiScriptSoundWav()) {
        return kookieUiScriptHasSuffix(source, ".wav")
    }
    return false
}


class KookieUiScriptDocument {
    Int[] kinds
    Int[] assetTypes
    Int[] roles
    Int[] sizes
    String[] ids
    String[] sources
    String[] alts
    String[] checksums
    Int[] clipIds
    Int[] gains
    Int nodeCountValue
    Bool shownValue
    Bool closedValue
    Bool validValue
    Int checksumValue

    public constructor(Int capacity) {
        var actualCapacity = capacity
        validValue = capacity > 0 && capacity <= kookieUiScriptMaximumNodes()
        if (actualCapacity <= 0) { actualCapacity = 1 }
        if (actualCapacity > kookieUiScriptMaximumNodes()) {
            actualCapacity = kookieUiScriptMaximumNodes()
        }
        kinds = new Int[actualCapacity]
        assetTypes = new Int[actualCapacity]
        roles = new Int[actualCapacity]
        sizes = new Int[actualCapacity]
        ids = new String[actualCapacity]
        sources = new String[actualCapacity]
        alts = new String[actualCapacity]
        checksums = new String[actualCapacity]
        clipIds = new Int[actualCapacity]
        gains = new Int[actualCapacity]
        nodeCountValue = 0
        shownValue = false
        closedValue = false
        checksumValue = 17
    }

    Bool appendNode(
        Int kind, Int assetType, String id, String source, String alt,
        String checksum, Int role, Int size, Int clipId, Int gain
    ) {
        var nodeValid = false
        if (kind == kookieUiScriptNodeText()) {
            nodeValid = source.length() > 0 &&
                (role == kookieUiScriptRoleBody() ||
                    role == kookieUiScriptRoleDisplay()) &&
                size >= 12 && size <= 48
        } else if (kind == kookieUiScriptNodeAsset()) {
            nodeValid = id.length() > 0 &&
                kookieUiScriptSafePath(source) &&
                kookieUiScriptAssetTypeValid(assetType, source) &&
                alt.length() > 0 && kookieUiScriptSha256(checksum)
        } else if (kind == kookieUiScriptNodeIcon()) {
            nodeValid = kookieUiScriptSupportedIcon(id) &&
                alt.length() > 0 && size >= 16 && size <= 48
        } else if (kind == kookieUiScriptNodeSound()) {
            nodeValid = id.length() > 0 &&
                kookieUiScriptSoundTypeValid(assetType, source) &&
                alt.length() > 0 && kookieUiScriptSha256(checksum) &&
                clipId > 0 && clipId <= 1000000 &&
                gain >= 0 && gain <= 100
        }
        if (!validValue || closedValue || shownValue ||
            nodeCountValue >= kinds.length || !nodeValid) {
            return false
        }
        kinds[nodeCountValue] = kind
        assetTypes[nodeCountValue] = assetType
        roles[nodeCountValue] = role
        sizes[nodeCountValue] = size
        clipIds[nodeCountValue] = clipId
        gains[nodeCountValue] = gain
        ids[nodeCountValue] = id
        sources[nodeCountValue] = source
        alts[nodeCountValue] = alt
        checksums[nodeCountValue] = checksum
        checksumValue = kookieUiScriptMix(checksumValue, kind)
        checksumValue = kookieUiScriptMix(checksumValue, assetType)
        checksumValue = kookieUiScriptMix(
            checksumValue, kookieUiScriptStringScore(id))
        checksumValue = kookieUiScriptMix(
            checksumValue, kookieUiScriptStringScore(source))
        checksumValue = kookieUiScriptMix(
            checksumValue, kookieUiScriptStringScore(alt))
        checksumValue = kookieUiScriptMix(
            checksumValue, kookieUiScriptStringScore(checksum))
        checksumValue = kookieUiScriptMix(checksumValue, role)
        checksumValue = kookieUiScriptMix(checksumValue, size)
        checksumValue = kookieUiScriptMix(checksumValue, clipId)
        checksumValue = kookieUiScriptMix(checksumValue, gain)
        nodeCountValue = nodeCountValue + 1
        return true
    }

    Bool bindText(String text, Int role, Int size) {
        var actualRole = role
        if (actualRole != kookieUiScriptRoleDisplay()) {
            actualRole = kookieUiScriptRoleBody()
        }
        var actualSize = size
        if (actualSize < 12) { actualSize = 12 }
        if (actualSize > 48) { actualSize = 48 }
        return appendNode(
            kookieUiScriptNodeText(), 0, "", text, "", "",
            actualRole, actualSize, 0, 0)
    }

    Bool bindAsset(
        String assetId, String source, Int assetType, String alt,
        String checksum
    ) {
        return appendNode(
            kookieUiScriptNodeAsset(), assetType, assetId, source, alt,
            checksum, 0, 0, 0, 0)
    }

    Bool bindIcon(String name, String alt, Int size) {
        var actualSize = size
        if (actualSize < 16) { actualSize = 16 }
        if (actualSize > 48) { actualSize = 48 }
        return appendNode(
            kookieUiScriptNodeIcon(), 0, name, "", alt, "", 0, actualSize, 0, 0)
    }

    Bool bindSound(
        String soundId, String source, Int soundType, String label,
        String checksum, Int clipId, Int defaultGain
    ) {
        return appendNode(
            kookieUiScriptNodeSound(), soundType, soundId, source, label,
            checksum, 0, 0, clipId, defaultGain)
    }

    Bool canBind(Int amount) {
        return amount > 0 && validValue && !closedValue && !shownValue &&
            nodeCountValue <= kinds.length - amount
    }

    Bool bindMenu(String title, String subtitle, String hint) {
        if (!canBind(3)) { return false }
        return bindText(title, kookieUiScriptRoleDisplay(), 32) &&
            bindText(subtitle, kookieUiScriptRoleBody(), 18) &&
            bindText(hint, kookieUiScriptRoleBody(), 14)
    }

    Bool bindHud(String health, String ammunition, String build, String xp) {
        if (!canBind(4)) { return false }
        return bindText(health, kookieUiScriptRoleBody(), 14) &&
            bindText(ammunition, kookieUiScriptRoleBody(), 14) &&
            bindText(build, kookieUiScriptRoleBody(), 14) &&
            bindText(xp, kookieUiScriptRoleBody(), 14)
    }

    Bool show() {
        if (!validValue || closedValue || shownValue || nodeCountValue == 0) {
            return false
        }
        shownValue = true
        checksumValue = kookieUiScriptMix(checksumValue, 9001)
        return true
    }

    Bool close() {
        if (!validValue || closedValue || !shownValue) { return false }
        shownValue = false
        closedValue = true
        checksumValue = kookieUiScriptMix(checksumValue, 9002)
        return true
    }

    Bool valid() { return validValue }
    Int boundCount() { return nodeCountValue }
    Bool shown() { return shownValue }
    Bool closed() { return closedValue }
    Int checksum() { return checksumValue }

    Int nodeKind(Int index) {
        if (index < 0 || index >= nodeCountValue) { return 0 }
        return kinds[index]
    }

    Int nodeAssetType(Int index) {
        if (index < 0 || index >= nodeCountValue) { return 0 }
        return assetTypes[index]
    }

    String nodeId(Int index) {
        if (index < 0 || index >= nodeCountValue) { return "" }
        return ids[index]
    }

    String nodeSource(Int index) {
        if (index < 0 || index >= nodeCountValue) { return "" }
        return sources[index]
    }

    String nodeAlt(Int index) {
        if (index < 0 || index >= nodeCountValue) { return "" }
        return alts[index]
    }

    String nodeChecksum(Int index) {
        if (index < 0 || index >= nodeCountValue) { return "" }
        return checksums[index]
    }

    Int nodeRole(Int index) {
        if (index < 0 || index >= nodeCountValue) { return 0 }
        return roles[index]
    }

    Int nodeSize(Int index) {
        if (index < 0 || index >= nodeCountValue) { return 0 }
        return sizes[index]
    }
    Int nodeClipId(Int index) {
        if (index < 0 || index >= nodeCountValue) { return 0 }
        return clipIds[index]
    }

    Int nodeGain(Int index) {
        if (index < 0 || index >= nodeCountValue) { return 0 }
        return gains[index]
    }
}

