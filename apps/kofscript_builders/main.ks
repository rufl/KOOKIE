Int[] behaviorWords() {
    var product = BoundedBehaviorProgram(16, 16, 4)
    if (!product.configureDefaultEnemyProgram(1) || !product.encode()) {
        return new Int[0]
    }
    var result = new Int[product.encodedLength()]
    for (var index = 0; index < result.length; index = index + 1) {
        result[index] = product.encodedWord(index)
    }
    return result
}

Bool buildBehavior(String outputPath) {
    var words = behaviorWords()
    var reopened = BoundedBehaviorProgram(16, 16, 4)
    if (words.length == 0 || !reopened.reopen(words)) { return false }
    var artifact = BoundedOfflineProductArtifact(256)
    if (!artifact.build(
            offlineArtifactBehaviorKind(), reopened.checksum(), words)) {
        return false
    }
    var text = artifact.encodeText()
    var output = Path(outputPath)
    output.parent().createDirectories()
    output.writeText(text)
    var written = output.readText()
    if (written == null) { return false }
    var verified = BoundedOfflineProductArtifact(256)
    if (!verified.decodeText(written) ||
        verified.checksum() != artifact.checksum() ||
        !BoundedBehaviorProgram(16, 16, 4).reopen(verified.wordsCopy())) {
        return false
    }
    println("built kind=behavior checksum=" + reopened.checksum() +
        " words=" + words.length + " path=" + outputPath)
    return true
}

Int[] animationWords() {
    var product = BoundedAnimationGraphProduct(4, 8)
    if (!product.configure(1, 1, 1, 10) ||
        !product.addState(10, 100, 60, true) ||
        !product.addState(20, 200, 30, true) ||
        !product.addState(30, 300, 20, false) ||
        !product.addTransition(
            1, 10, 20, animationConditionMovingBit(), 10, 6) ||
        !product.addTransition(
            2, 20, 10, animationConditionStoppedBit(), 10, 6) ||
        !product.addTransition(
            3, 10, 30, animationConditionAttackBit(), 100, 2) ||
        !product.addTransition(
            4, 20, 30, animationConditionAttackBit(), 100, 2) ||
        !product.addTransition(
            5, 30, 10, animationConditionFinishedBit(), 10, 3) ||
        !product.seal() || !product.encode()) {
        return new Int[0]
    }
    var result = new Int[product.encodedLength()]
    for (var index = 0; index < result.length; index = index + 1) {
        result[index] = product.encodedWord(index)
    }
    return result
}

Bool buildAnimation(String outputPath) {
    var words = animationWords()
    var reopened = BoundedAnimationGraphProduct(4, 8)
    if (words.length == 0 || !reopened.reopen(words)) { return false }
    var artifact = BoundedOfflineProductArtifact(256)
    if (!artifact.build(
            offlineArtifactAnimationKind(), reopened.checksum(), words)) {
        return false
    }
    var text = artifact.encodeText()
    var output = Path(outputPath)
    output.parent().createDirectories()
    output.writeText(text)
    var written = output.readText()
    if (written == null) { return false }
    var verified = BoundedOfflineProductArtifact(256)
    if (!verified.decodeText(written) ||
        verified.checksum() != artifact.checksum() ||
        !BoundedAnimationGraphProduct(4, 8).reopen(verified.wordsCopy())) {
        return false
    }
    println("built kind=animation checksum=" + reopened.checksum() +
        " words=" + words.length + " path=" + outputPath)
    return true
}
Int[] scriptWords() {
    var product = BoundedKofScriptProgram(4, 32)
    if (!product.configure(
            8, 1, 3002, 1, trustedDomainEventEnemyDefeated(),
            19, 3, 1, 1,
            kofScriptCommandGrantCurrencyBit(),
            kofScriptEventEliteBountyBit()) ||
        !product.addConstant(10) ||
        !product.addConstant(2) ||
        !product.addInstruction(
            kofScriptOpcodeLoadInput(), kofScriptInputValue()) ||
        !product.addInstruction(kofScriptOpcodePushConstant(), 0) ||
        !product.addInstruction(kofScriptOpcodeGreater(), 0) ||
        !product.addInstruction(kofScriptOpcodeJumpIfZero(), 18) ||
        !product.addInstruction(
            kofScriptOpcodeLoadInput(), kofScriptInputPlayerId()) ||
        !product.addInstruction(
            kofScriptOpcodeLoadInput(), kofScriptInputSubjectKind()) ||
        !product.addInstruction(kofScriptOpcodePushConstant(), 1) ||
        !product.addInstruction(kofScriptOpcodeMultiply(), 0) ||
        !product.addInstruction(
            kofScriptOpcodeLoadInput(), kofScriptInputValue()) ||
        !product.addInstruction(kofScriptOpcodeAdd(), 0) ||
        !product.addInstruction(
            kofScriptOpcodeEmitCommand(),
            trustedHookCommandGrantCurrency()) ||
        !product.addInstruction(
            kofScriptOpcodeLoadInput(), kofScriptInputSubjectId()) ||
        !product.addInstruction(
            kofScriptOpcodeLoadInput(), kofScriptInputSubjectKind()) ||
        !product.addInstruction(kofScriptOpcodePushConstant(), 1) ||
        !product.addInstruction(kofScriptOpcodeMultiply(), 0) ||
        !product.addInstruction(
            kofScriptOpcodeLoadInput(), kofScriptInputValue()) ||
        !product.addInstruction(kofScriptOpcodeAdd(), 0) ||
        !product.addInstruction(
            kofScriptOpcodeEmitEvent(), trustedHookEventEliteBounty()) ||
        !product.addInstruction(kofScriptOpcodeHalt(), 0) ||
        !product.seal() || !product.encode()) {
        return new Int[0]
    }
    var result = new Int[product.encodedLength()]
    for (var index = 0; index < result.length; index = index + 1) {
        result[index] = product.encodedWord(index)
    }
    return result
}

Bool buildScript(String outputPath) {
    var words = scriptWords()
    var reopened = BoundedKofScriptProgram(4, 32)
    if (words.length == 0 || !reopened.reopen(words)) { return false }
    var artifact = BoundedOfflineProductArtifact(256)
    if (!artifact.build(
            offlineArtifactKofScriptKind(), reopened.checksum(), words)) {
        return false
    }
    var text = artifact.encodeText()
    var output = Path(outputPath)
    output.parent().createDirectories()
    output.writeText(text)
    var written = output.readText()
    if (written == null) { return false }
    var verified = BoundedOfflineProductArtifact(256)
    if (!verified.decodeText(written) ||
        verified.checksum() != artifact.checksum() ||
        !BoundedKofScriptProgram(4, 32).reopen(verified.wordsCopy())) {
        return false
    }
    println("built kind=script checksum=" + reopened.checksum() +
        " words=" + words.length + " path=" + outputPath)
    return true
}


if (args.length != 2 ||
    (args[0] != "behavior" && args[0] != "animation" &&
        args[0] != "script")) {
    throw "usage: kookie-kofscript-builder <behavior|animation|script> <output>"
}

if (args[0] == "behavior") {
    if (!buildBehavior(args[1])) { throw "offline-builder-rejected" }
} else if (args[0] == "animation") {
    if (!buildAnimation(args[1])) { throw "offline-builder-rejected" }
} else {
    if (!buildScript(args[1])) { throw "offline-builder-rejected" }
}
