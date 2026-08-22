function onStepHit() {
    // Intro buildup sway (Step 32)
    if (curStep == 32) {
        FlxTween.tween(playerStrumline, {modX: 40.0, modAlpha: 0.8}, 0.6, {ease: FlxEase.quadOut});
        FlxTween.tween(opponentStrumline, {modX: -40.0, modAlpha: 0.8}, 0.6, {ease: FlxEase.quadOut});
    }

    // Tankman "Ugh!" slam (Step 64)
    if (curStep == 64) {
        FlxTween.tween(playerStrumline, {modY: 35.0, modAngle: 8.0}, 0.2, {ease: FlxEase.cubeOut});
        FlxTween.tween(opponentStrumline, {modY: -35.0, modAngle: -8.0}, 0.2, {ease: FlxEase.cubeOut});
        JuiceManager.bumpCamera(camGame, 0.06, 0.03);
    }

    // Return to baseline (Step 72)
    if (curStep == 72) {
        resetStrumPositions(0.35);
    }

    // Bridge bounce pulse (Step 128)
    if (curStep == 128) {
        FlxTween.tween(playerStrumline, {modX: -50.0, modY: 20.0}, 0.5, {ease: FlxEase.sineInOut});
        FlxTween.tween(opponentStrumline, {modX: 50.0, modY: -20.0}, 0.5, {ease: FlxEase.sineInOut});
    }

    // Final reset (Step 160)
    if (curStep == 160) {
        resetStrumPositions(0.4);
    }
}