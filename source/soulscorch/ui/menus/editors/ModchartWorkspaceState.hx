package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.system.System;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.modchart.ModchartWorkspaceMath;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class ModchartWorkspaceState extends MusicBeatState {
    private var camWorkspace:FlxCamera;
    private var camHUD:FlxCamera;

    // --- Mock Strums & Test Notes ---
    private var playerStrums:Array<FlxSprite> = [];
    private var opponentStrums:Array<FlxSprite> = [];
    private var defaultPositions:Array<Array<Float>> = [];
    private var fallingNotesGroup:FlxSpriteGroup;

    // --- Modchart Parameters ---
    private var drunkIntensity:Float = 0.0;
    private var tipsyIntensity:Float = 0.0;
    private var beatIntensity:Float = 0.0;
    private var confusionIntensity:Float = 0.0;
    private var stealthIntensity:Float = 0.0;
    private var strumSpeed:Float = 2.0;

    // --- UI State ---
    private var selectedModIndex:Int = 0;
    private var modNames:Array<String> = ["Drunk", "Tipsy", "Beat Pulse", "Confusion (Spin)", "Stealth", "Scroll Speed"];
    
    // --- HUD Displays ---
    private var infoBox:FlxSprite;
    private var modifierListTxt:FlxText;
    private var generatedCodeTxt:FlxText;
    private var toastTxt:FlxText;
    private var simSongTime:Float = 0.0;

    override public function create():Void {
        super.create();

        // 1. Setup Camera Layers
        camWorkspace = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camWorkspace);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camWorkspace, true);

        // Dark Canvas Background
        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF14101E);
        bg.scrollFactor.set();
        add(bg);

        var centerLine = new FlxSprite(FlxG.width * 0.5 - 1, 0).makeGraphic(2, FlxG.height, 0xFF282038);
        add(centerLine);

        fallingNotesGroup = new FlxSpriteGroup();
        add(fallingNotesGroup);

        // 2. Build Mock Receptors
        createMockStrumlines();

        // 3. Setup Workspace HUD
        setupHUD();

        updateModifierDisplay();
        FlxG.mouse.visible = true;
    }

    private function createMockStrumlines():Void {
        var noteColors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
        defaultPositions = [];

        // Opponent Strums (Left)
        for (i in 0...4) {
            var xPos:Float = 120 + (i * 110);
            var yPos:Float = 80;
            defaultPositions.push([xPos, yPos]);

            var strum = new FlxSprite(xPos, yPos).makeGraphic(90, 90, noteColors[i]);
            strum.alpha = 0.55;
            opponentStrums.push(strum);
            add(strum);
        }

        // Player Strums (Right)
        for (i in 0...4) {
            var xPos:Float = (FlxG.width * 0.5) + 80 + (i * 110);
            var yPos:Float = 80;
            defaultPositions.push([xPos, yPos]);

            var strum = new FlxSprite(xPos, yPos).makeGraphic(90, 90, noteColors[i]);
            playerStrums.push(strum);
            add(strum);
        }
    }

    private function setupHUD():Void {
        // Controls Sidebar (Left)
        infoBox = new FlxSprite(15, 15).makeGraphic(340, 360, 0xDD0D0A14);
        infoBox.scrollFactor.set();
        infoBox.cameras = [camHUD];
        add(infoBox);

        var titleTxt = new FlxText(25, 25, 320, "MODCHART WORKSPACE", 18);
        titleTxt.setFormat(Paths.font("vcr"), 18, 0xFF00FFCC, LEFT);
        titleTxt.scrollFactor.set();
        titleTxt.cameras = [camHUD];
        add(titleTxt);

        modifierListTxt = new FlxText(25, 65, 320, "", 14);
        modifierListTxt.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, LEFT);
        modifierListTxt.scrollFactor.set();
        modifierListTxt.cameras = [camHUD];
        add(modifierListTxt);

        // Help Instructions (Right)
        var helpBox = new FlxSprite(FlxG.width - 355, 15).makeGraphic(340, 360, 0xDD0D0A14);
        helpBox.scrollFactor.set();
        helpBox.cameras = [camHUD];
        add(helpBox);

        var helpTxt = new FlxText(FlxG.width - 345, 25, 320,
            "HOTKEYS & PRESETS:\n\n" +
            "[W / S] - Select Modifier\n" +
            "[LEFT / RIGHT] - Adjust Value\n" +
            "[SHIFT + ARROWS] - 5x Value Jump\n" +
            "[R] - Reset Modifiers to 0\n" +
            "[1] - Preset: S-Curve Wave\n" +
            "[2] - Preset: Side Shuffle\n" +
            "[3] - Preset: Chaos Pulse\n" +
            "[C] - Copy SoulScript Code\n" +
            "[ESCAPE] - Exit to Menu",
            13
        );
        helpTxt.setFormat(Paths.font("vcr"), 13, 0xFFCCCCCC, LEFT);
        helpTxt.scrollFactor.set();
        helpTxt.cameras = [camHUD];
        add(helpTxt);

        // Toast Feedback Alert
        toastTxt = new FlxText(0, FlxG.height - 50, FlxG.width, "", 16);
        toastTxt.setFormat(Paths.font("vcr"), 16, 0xFF00FF44, CENTER, OUTLINE, FlxColor.BLACK);
        toastTxt.scrollFactor.set();
        toastTxt.cameras = [camHUD];
        add(toastTxt);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        simSongTime += elapsed * 1000.0 * strumSpeed;

        handleInput();
        applyLiveModcharts();
        spawnContinuousTestNotes(elapsed);
    }

    private function handleInput():Void {
        // Selection Navigation
        if (FlxG.keys.justPressed.W) {
            selectedModIndex = FlxMath.wrap(selectedModIndex - 1, 0, modNames.length - 1);
            updateModifierDisplay();
            AssetHelper.playSoundSafely("scrollMenu", 0.6);
        }
        if (FlxG.keys.justPressed.S) {
            selectedModIndex = FlxMath.wrap(selectedModIndex + 1, 0, modNames.length - 1);
            updateModifierDisplay();
            AssetHelper.playSoundSafely("scrollMenu", 0.6);
        }

        // Value Tuning
        var step:Float = FlxG.keys.pressed.SHIFT ? 0.25 : 0.05;
        if (FlxG.keys.justPressed.LEFT || FlxG.keys.pressed.LEFT && FlxG.keys.pressed.CONTROL) {
            adjustModifier(selectedModIndex, -step);
        }
        if (FlxG.keys.justPressed.RIGHT || FlxG.keys.pressed.RIGHT && FlxG.keys.pressed.CONTROL) {
            adjustModifier(selectedModIndex, step);
        }

        // Reset
        if (FlxG.keys.justPressed.R) {
            drunkIntensity = tipsyIntensity = beatIntensity = confusionIntensity = stealthIntensity = 0.0;
            strumSpeed = 2.0;
            updateModifierDisplay();
            showToast("Modifiers Reset to Default!");
        }

        // Presets
        if (FlxG.keys.justPressed.ONE) applyPreset(1.0, 0.4, 0.0, 0.0, 0.0, "Preset 1: S-Curve Wave Loaded!");
        if (FlxG.keys.justPressed.TWO) applyPreset(0.0, 1.2, 0.8, 0.5, 0.0, "Preset 2: Side Shuffle Loaded!");
        if (FlxG.keys.justPressed.THREE) applyPreset(1.5, 1.5, 1.2, 2.0, 0.3, "Preset 3: Chaos Pulse Loaded!");

        // Export Code to Clipboard
        if (FlxG.keys.justPressed.C) {
            copySoulScriptToClipboard();
        }

        // Exit
        if (FlxG.keys.justPressed.ESCAPE) {
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    private function adjustModifier(index:Int, delta:Float):Void {
        switch (index) {
            case 0: drunkIntensity = Math.round((drunkIntensity + delta) * 100) / 100;
            case 1: tipsyIntensity = Math.round((tipsyIntensity + delta) * 100) / 100;
            case 2: beatIntensity = Math.round((beatIntensity + delta) * 100) / 100;
            case 3: confusionIntensity = Math.round((confusionIntensity + delta) * 100) / 100;
            case 4: stealthIntensity = Math.min(1.0, Math.max(0.0, Math.round((stealthIntensity + delta) * 100) / 100));
            case 5: strumSpeed = Math.max(0.5, Math.round((strumSpeed + delta) * 100) / 100);
        }
        updateModifierDisplay();
    }

    private function applyPreset(d:Float, t:Float, b:Float, c:Float, s:Float, msg:String):Void {
        drunkIntensity = d;
        tipsyIntensity = t;
        beatIntensity = b;
        confusionIntensity = c;
        stealthIntensity = s;
        updateModifierDisplay();
        showToast(msg);
    }

    private function applyLiveModcharts():Void {
        // Update Player Strum positions
        for (i in 0...4) {
            var def = defaultPositions[i + 4];
            var transformed = ModchartWorkspaceMath.applyModifiers(
                def[0], def[1], i, simSongTime, 
                drunkIntensity, tipsyIntensity, beatIntensity, confusionIntensity, stealthIntensity
            );

            var spr = playerStrums[i];
            spr.x = transformed.x;
            spr.y = transformed.y;
            spr.angle = transformed.angle;
            spr.alpha = transformed.alpha;
        }

        // Update Opponent Strum positions (mild counter-balance)
        for (i in 0...4) {
            var def = defaultPositions[i];
            var transformed = ModchartWorkspaceMath.applyModifiers(
                def[0], def[1], i, simSongTime + 500, 
                drunkIntensity * 0.5, tipsyIntensity * 0.5, beatIntensity * 0.5, confusionIntensity * 0.2, 0.0
            );

            var spr = opponentStrums[i];
            spr.x = transformed.x;
            spr.y = transformed.y;
            spr.angle = transformed.angle;
        }
    }

    private function spawnContinuousTestNotes(elapsed:Float):Void {
        // Clean up notes off-screen
        fallingNotesGroup.forEachAlive(function(note:FlxSprite) {
            note.y -= elapsed * 400.0 * strumSpeed;
            if (note.y < -100) {
                note.kill();
                fallingNotesGroup.remove(note, true);
                note.destroy();
            }
        });
    }

    private function updateModifierDisplay():Void {
        var values:Array<Float> = [drunkIntensity, tipsyIntensity, beatIntensity, confusionIntensity, stealthIntensity, strumSpeed];
        var out = "CURRENT PARAMETERS:\n\n";

        for (i in 0...modNames.length) {
            var isSel = (i == selectedModIndex);
            var prefix = isSel ? "> " : "  ";
            var suffix = isSel ? " <" : "";
            out += '$prefix${modNames[i]}: ${values[i]}$suffix\n';
        }

        modifierListTxt.text = out;
    }

    private function copySoulScriptToClipboard():Void {
        var code = '# Generated by SoulScorch Modchart Workspace\n' +
                   'on event("Modchart Pulse"):\n' +
                   '    # Apply live workspace values\n' +
                   '    modchart.drunk -> $drunkIntensity in 0.5s (cubeOut)\n' +
                   '    modchart.tipsy -> $tipsyIntensity in 0.5s (cubeOut)\n' +
                   '    modchart.confusion -> $confusionIntensity in 0.5s (elasticOut)\n' +
                   '    strumline.player.teleport(0.35s, elasticOut)\n' +
                   'end';

        System.setClipboard(code);
        showToast("SoulScript Event Copied to Clipboard!");
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    private function showToast(msg:String):Void {
        toastTxt.text = msg;
        toastTxt.alpha = 1.0;
        flixel.tweens.FlxTween.cancelTweensOf(toastTxt);
        flixel.tweens.FlxTween.tween(toastTxt, {alpha: 0.0}, 2.0, {startDelay: 1.0});
    }
}