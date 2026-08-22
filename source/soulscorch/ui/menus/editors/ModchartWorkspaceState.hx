package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.geom.Rectangle;
import openfl.system.System;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.StrumArrow;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.ui.menus.editors.editorui.*;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef ModchartKeyframe = {
    var step:Float;
    var modifier:String;
    var value:Float;
    var duration:Float;
    var ease:String;
    var target:String; // "player", "opponent", "both"
}

class ModchartWorkspaceState extends MusicBeatState {
    private var camWorkspace:FlxCamera;
    private var camUI:FlxCamera;

    private var playerStrumline:Strumline;
    private var opponentStrumline:Strumline;
    private var playerDefaultPositions:Array<Array<Float>> = [];
    private var opponentDefaultPositions:Array<Array<Float>> = [];
    private var fallingNotesGroup:FlxTypedGroup<Note>;

    // --- Math Matrix Modifiers (24 Extended Core Modifiers) ---
    private var drunkIntensity:Float = 0.0;
    private var tipsyIntensity:Float = 0.0;
    private var beatIntensity:Float = 0.0;
    private var confusionIntensity:Float = 0.0;
    private var stealthIntensity:Float = 0.0;
    private var reverseIntensity:Float = 0.0;
    private var crossIntensity:Float = 0.0;
    private var alternateIntensity:Float = 0.0;
    private var bumpyIntensity:Float = 0.0;
    private var invertIntensity:Float = 0.0;
    private var waveIntensity:Float = 0.0;
    private var bounceIntensity:Float = 0.0;
    private var digitalIntensity:Float = 0.0;
    private var zigzagIntensity:Float = 0.0;
    private var expandIntensity:Float = 0.0;
    private var dizzyIntensity:Float = 0.0;
    private var miniIntensity:Float = 0.0;
    private var scrollSpeed:Float = 2.2;
    private var tornadoIntensity:Float = 0.0;
    private var centeredIntensity:Float = 0.0;
    private var flipIntensity:Float = 0.0;
    private var spiralIntensity:Float = 0.0;
    private var squishIntensity:Float = 0.0;
    private var blackHoleIntensity:Float = 0.0;

    private var selectedModIndex:Int = 0;
    private var modNames:Array<String> = [
        "Drunk",
        "Tipsy",
        "Beat Pulse",
        "Confusion",
        "Stealth",
        "Reverse",
        "Cross",
        "Alternate",
        "Bumpy",
        "Invert",
        "Waveform",
        "Bounce",
        "Digital Glitch",
        "ZigZag",
        "Expand",
        "Dizzy Spin",
        "Mini Scale",
        "Scroll Speed",
        "Tornado Wave",
        "Centered Focus",
        "Flip Inversion",
        "3D Spiral",
        "Squish & Stretch",
        "Black Hole Vortex"
    ];

    // --- Timeline & Sequencer ---
    private var keyframes:Array<ModchartKeyframe> = [];
    private var selectedKeyframeIdx:Int = 0;
    private var curCurvedTime:Float = 0.0;
    private var simSongTime:Float = 0.0;
    private var spawnTimer:Float = 0.0;
    private var isPlayingSequence:Bool = false;

    // --- Ease Curve Types ---
    private var easeOptions:Array<String> = [
        "linear", "quadOut", "quadInOut", "cubeOut", "cubeInOut",
        "sineOut", "sineInOut", "bounceOut", "elasticOut", "backOut", "circOut"
    ];
    private var curEaseIdx:Int = 3;

    // --- UI Windows & Layout ---
    private var topBar:EditorTopBar;
    private var matrixWindow:EditorWindow;
    private var timelineWindow:EditorWindow;
    private var presetsWindow:EditorWindow;
    private var graphOscilloscopeWindow:EditorWindow;
    private var exportWindow:EditorWindow;

    private var modifierListTxt:FlxText;
    private var keyframeListTxt:FlxText;
    private var formulaTxt:FlxText;
    private var oscilloscopeGraph:FlxSprite;

    private var checkDualStrums:EditorCheckbox;
    private var affectOpponent:Bool = true;
    private var stepperKeyframeStep:EditorNumericStepper;
    private var stepperKeyframeVal:EditorNumericStepper;
    private var stepperKeyframeDur:EditorNumericStepper;

    // --- Undo / Redo Buffer ---
    private var undoStack:Array<String> = [];
    private var redoStack:Array<String> = [];
    private static inline var MAX_UNDO_DEPTH:Int = 50;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Modchart Matrix Ultra", "Designing Real-time Shaders & Waves");
        #end

        setupCameras();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        bg.scrollFactor.set(0, 0);
        add(bg);

        var centerLine = new FlxSprite(FlxG.width * 0.5 - 1, 0).makeGraphic(2, FlxG.height, EditorTheme.PANEL_BORDER);
        centerLine.scrollFactor.set(0, 0);
        add(centerLine);

        fallingNotesGroup = new FlxTypedGroup<Note>();
        add(fallingNotesGroup);

        createStrumMatrix();
        setupWindows();

        pushUndoSnapshot();
        updateDisplay();

        add(new EditorToast());
        FlxG.mouse.visible = true;
    }

    override public function setupCameras():Void {
        camWorkspace = new FlxCamera();
        camUI = new FlxCamera();
        camUI.bgColor = FlxColor.TRANSPARENT;

        FlxG.cameras.reset(camWorkspace);
        FlxG.cameras.add(camUI, false);
        FlxG.cameras.setDefaultDrawTarget(camWorkspace, true);
    }

    private function createStrumMatrix():Void {
        playerDefaultPositions = [];
        opponentDefaultPositions = [];

        var oppX = 85.0;
        var playerX = FlxG.width - (Strumline.STRUM_SPACING * 4) - 85;
        var startY = 80.0;

        opponentStrumline = new Strumline(oppX, startY, false, false);
        opponentStrumline.alpha = 0.55;
        add(opponentStrumline);

        playerStrumline = new Strumline(playerX, startY, true, false);
        playerStrumline.alpha = 1.0;
        add(playerStrumline);

        for (i in 0...4) {
            opponentDefaultPositions.push([oppX + (i * Strumline.STRUM_SPACING), startY]);
            playerDefaultPositions.push([playerX + (i * Strumline.STRUM_SPACING), startY]);
        }
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar("MODCHART MATRIX ULTRA // [MATHEMATICAL AUTOMATION SUITE]");
        topBar.cameras = [camUI];
        topBar.addAction("Play/Pause (Space)", togglePlayback);
        topBar.addAction("Record KF (K)", addCurrentAsKeyframe);
        topBar.addAction("Presets", function() presetsWindow.visible = !presetsWindow.visible);
        topBar.addAction("Export (Ctrl+E)", function() exportWindow.visible = !exportWindow.visible);
        topBar.addAction("Reset (R)", resetAllModifiers);
        topBar.addAction("Exit (Esc)", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        // --- 1. Parameter Matrix Panel (Left Top) ---
        matrixWindow = new EditorWindow(15, 45, 290, 390, "Matrix Parameters (W/S/Arrows)");
        matrixWindow.cameras = [camUI];
        add(matrixWindow);

        modifierListTxt = new FlxText(10, 6, 270, "", 12);
        modifierListTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        matrixWindow.addElement(modifierListTxt);

        checkDualStrums = new EditorCheckbox(10, 320, "Affect Opponent Strumline", affectOpponent, function(c) {
            affectOpponent = c;
        });
        matrixWindow.addElement(checkDualStrums);

        var btnAddKf = new EditorButton(10, 350, 270, 26, "+ Capture State as Keyframe", addCurrentAsKeyframe);
        matrixWindow.addElement(btnAddKf);

        // --- 2. Live Oscilloscope Graph (Left Bottom) ---
        graphOscilloscopeWindow = new EditorWindow(15, 445, 290, 185, "Live Waveform Oscilloscope");
        graphOscilloscopeWindow.cameras = [camUI];
        add(graphOscilloscopeWindow);

        oscilloscopeGraph = new FlxSprite(10, 8);
        oscilloscopeGraph.makeGraphic(270, 90, 0xFF111118);
        graphOscilloscopeWindow.addElement(oscilloscopeGraph);

        formulaTxt = new FlxText(10, 105, 270, "", 11);
        formulaTxt.setFormat(Paths.font("vcr"), 11, EditorTheme.ACCENT_CYAN, LEFT);
        graphOscilloscopeWindow.addElement(formulaTxt);

        // --- 3. Keyframe Sequencer & Timeline (Right Top) ---
        timelineWindow = new EditorWindow(FlxG.width - 325, 45, 310, 310, "Keyframe Sequencer");
        timelineWindow.cameras = [camUI];
        add(timelineWindow);

        keyframeListTxt = new FlxText(10, 4, 290, "", 12);
        keyframeListTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        timelineWindow.addElement(keyframeListTxt);

        stepperKeyframeStep = new EditorNumericStepper(10, 195, 135, "Step / Beat", 0, 0, 9999, 4, 0, function(v) {
            if (keyframes.length > selectedKeyframeIdx) keyframes[selectedKeyframeIdx].step = v;
            updateKeyframeDisplay();
        });
        timelineWindow.addElement(stepperKeyframeStep);

        stepperKeyframeVal = new EditorNumericStepper(160, 195, 135, "Value", 1.0, -10.0, 10.0, 0.1, 2, function(v) {
            if (keyframes.length > selectedKeyframeIdx) keyframes[selectedKeyframeIdx].value = v;
            updateKeyframeDisplay();
        });
        timelineWindow.addElement(stepperKeyframeVal);

        stepperKeyframeDur = new EditorNumericStepper(10, 235, 135, "Duration (Sec)", 1.0, 0.1, 16.0, 0.25, 2, function(v) {
            if (keyframes.length > selectedKeyframeIdx) keyframes[selectedKeyframeIdx].duration = v;
            updateKeyframeDisplay();
        });
        timelineWindow.addElement(stepperKeyframeDur);

        var btnCycleEase = new EditorButton(160, 252, 135, 26, "Ease: " + easeOptions[curEaseIdx], function() {
            curEaseIdx = (curEaseIdx + 1) % easeOptions.length;
            if (keyframes.length > selectedKeyframeIdx) keyframes[selectedKeyframeIdx].ease = easeOptions[curEaseIdx];
            updateKeyframeDisplay();
        });
        timelineWindow.addElement(btnCycleEase);

        var btnDelKf = new EditorButton(10, 275, 285, 24, "- Remove Selected Keyframe", removeSelectedKeyframe);
        timelineWindow.addElement(btnDelKf);

        // --- 4. Curated Presets Library (Right Bottom) ---
        presetsWindow = new EditorWindow(FlxG.width - 325, 365, 310, 265, "Curated Presets Library");
        presetsWindow.cameras = [camUI];
        add(presetsWindow);

        presetsWindow.addElement(new EditorButton(10, 6, 290, 22, "1. S-Curve Sine Surge", function() {
            applyFullPreset(1.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "Preset: S-Curve Surge");
        }));

        presetsWindow.addElement(new EditorButton(10, 30, 290, 22, "2. Cross-Over Splitter", function() {
            applyFullPreset(0.0, 0.8, 0.0, 0.0, 0.0, 0.0, 1.2, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "Preset: Cross-Over Splitter");
        }));

        presetsWindow.addElement(new EditorButton(10, 54, 290, 22, "3. Chaos Vortex Whirl", function() {
            applyFullPreset(1.4, 1.2, 1.0, 1.5, 0.2, 0.0, 0.5, 0.5, 0.8, 0.0, 1.2, 0.8, 0.3, 0.5, 0.4, 0.6, 0.0, 2.4, 0.8, 0.0, 0.0, 0.5, 0.0, 0.5, "Preset: Chaos Vortex Whirl");
        }));

        presetsWindow.addElement(new EditorButton(10, 78, 290, 22, "4. Digital Glitch Matrix", function() {
            applyFullPreset(0.2, 0.0, 1.5, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.8, 1.2, 0.5, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "Preset: Digital Glitch Matrix");
        }));

        presetsWindow.addElement(new EditorButton(10, 102, 290, 22, "5. Bumpy Pulse Drive", function() {
            applyFullPreset(0.4, 0.0, 1.4, 0.0, 0.0, 0.0, 0.0, 0.0, 1.6, 0.0, 0.0, 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "Preset: Bumpy Pulse Drive");
        }));

        presetsWindow.addElement(new EditorButton(10, 126, 290, 22, "6. Stealth Dive Shift", function() {
            applyFullPreset(0.5, 0.5, 0.0, 0.5, 0.75, 1.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "Preset: Stealth Dive Shift");
        }));

        presetsWindow.addElement(new EditorButton(10, 150, 290, 22, "7. Tornado Storm Orbit", function() {
            applyFullPreset(0.8, 0.0, 0.5, 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.8, 0.0, 2.2, 1.8, 0.0, 0.0, 0.0, 0.0, 0.0, "Preset: Tornado Storm Orbit");
        }));

        presetsWindow.addElement(new EditorButton(10, 174, 290, 22, "8. 3D Helix & Black Hole", function() {
            applyFullPreset(0.0, 0.0, 0.8, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 0.2, 2.4, 0.0, 0.8, 0.0, 1.5, 0.0, 1.2, "Preset: 3D Helix & Black Hole");
        }));

        presetsWindow.addElement(new EditorButton(10, 204, 290, 24, "Reset All Modifiers to Zero (R)", resetAllModifiers));

        // --- 5. Multi-Format Script Export Modal ---
        exportWindow = new EditorWindow((FlxG.width - 340) * 0.5, (FlxG.height - 240) * 0.5, 340, 240, "Export Modchart Code");
        exportWindow.cameras = [camUI];
        exportWindow.visible = false;
        add(exportWindow);

        exportWindow.addElement(new EditorButton(10, 10, 320, 28, "Export as SoulScript (.soul)", exportSoulScript));
        exportWindow.addElement(new EditorButton(10, 48, 320, 28, "Export as Lua Script (.lua)", exportLuaScript));
        exportWindow.addElement(new EditorButton(10, 86, 320, 28, "Export as HScript Iris (.hx)", exportHScript));
        exportWindow.addElement(new EditorButton(10, 124, 320, 28, "Export as Keyframe JSON (.json)", exportJsonData));
        exportWindow.addElement(new EditorButton(10, 168, 320, 26, "Close Modal", function() exportWindow.visible = false));

        updateKeyframeDisplay();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        simSongTime += elapsed * 1000.0 * (scrollSpeed * 0.5);

        handleKeyboardNavigation();
        if (isPlayingSequence) updateKeyframeSequence(elapsed);
        applyMatrixTransformations();
        spawnContinuousTestNotes(elapsed);
        renderOscilloscopeWaveform();
        updateLiveFormulaDisplay();
    }

    private function handleKeyboardNavigation():Void {
        if (exportWindow.visible) return;

        if (FlxG.keys.justPressed.W) { selectedModIndex = FlxMath.wrap(selectedModIndex - 1, 0, modNames.length - 1); updateDisplay(); }
        if (FlxG.keys.justPressed.S) { selectedModIndex = FlxMath.wrap(selectedModIndex + 1, 0, modNames.length - 1); updateDisplay(); }

        var delta = FlxG.keys.pressed.SHIFT ? 0.25 : 0.05;
        if (FlxG.keys.justPressed.LEFT) adjustModifier(-delta);
        if (FlxG.keys.justPressed.RIGHT) adjustModifier(delta);

        if (FlxG.keys.justPressed.K) addCurrentAsKeyframe();
        if (FlxG.keys.justPressed.R) resetAllModifiers();
        if (FlxG.keys.justPressed.SPACE) togglePlayback();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.E) exportWindow.visible = !exportWindow.visible;
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z) undo();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Y) redo();
        if (FlxG.keys.justPressed.ESCAPE) MusicBeatState.switchState(new MainMenuState());
    }

    private function adjustModifier(delta:Float):Void {
        pushUndoSnapshot();
        switch (selectedModIndex) {
            case 0: drunkIntensity = roundMod(drunkIntensity + delta);
            case 1: tipsyIntensity = roundMod(tipsyIntensity + delta);
            case 2: beatIntensity = roundMod(beatIntensity + delta);
            case 3: confusionIntensity = roundMod(confusionIntensity + delta);
            case 4: stealthIntensity = Math.min(1.0, Math.max(0.0, roundMod(stealthIntensity + delta)));
            case 5: reverseIntensity = Math.min(1.0, Math.max(0.0, roundMod(reverseIntensity + delta)));
            case 6: crossIntensity = roundMod(crossIntensity + delta);
            case 7: alternateIntensity = roundMod(alternateIntensity + delta);
            case 8: bumpyIntensity = roundMod(bumpyIntensity + delta);
            case 9: invertIntensity = roundMod(invertIntensity + delta);
            case 10: waveIntensity = roundMod(waveIntensity + delta);
            case 11: bounceIntensity = roundMod(bounceIntensity + delta);
            case 12: digitalIntensity = roundMod(digitalIntensity + delta);
            case 13: zigzagIntensity = roundMod(zigzagIntensity + delta);
            case 14: expandIntensity = roundMod(expandIntensity + delta);
            case 15: dizzyIntensity = roundMod(dizzyIntensity + delta);
            case 16: miniIntensity = Math.min(1.0, Math.max(0.0, roundMod(miniIntensity + delta)));
            case 17: scrollSpeed = Math.max(0.5, Math.min(6.0, roundMod(scrollSpeed + delta)));
            case 18: tornadoIntensity = roundMod(tornadoIntensity + delta);
            case 19: centeredIntensity = Math.min(1.0, Math.max(0.0, roundMod(centeredIntensity + delta)));
            case 20: flipIntensity = Math.min(1.0, Math.max(0.0, roundMod(flipIntensity + delta)));
            case 21: spiralIntensity = roundMod(spiralIntensity + delta);
            case 22: squishIntensity = roundMod(squishIntensity + delta);
            case 23: blackHoleIntensity = roundMod(blackHoleIntensity + delta);
        }
        updateDisplay();
    }

    private inline function roundMod(val:Float):Float {
        return Math.round(val * 100) / 100;
    }

    private function applyFullPreset(d:Float, t:Float, b:Float, c:Float, s:Float, rev:Float, cr:Float, alt:Float, bmp:Float, inv:Float, wav:Float, bnc:Float, dig:Float, zig:Float, exp:Float, diz:Float, min:Float, spd:Float, tor:Float, cen:Float, flp:Float, spi:Float, squ:Float, bh:Float, msg:String):Void {
        pushUndoSnapshot();
        drunkIntensity = d;
        tipsyIntensity = t;
        beatIntensity = b;
        confusionIntensity = c;
        stealthIntensity = s;
        reverseIntensity = rev;
        crossIntensity = cr;
        alternateIntensity = alt;
        bumpyIntensity = bmp;
        invertIntensity = inv;
        waveIntensity = wav;
        bounceIntensity = bnc;
        digitalIntensity = dig;
        zigzagIntensity = zig;
        expandIntensity = exp;
        dizzyIntensity = diz;
        miniIntensity = min;
        scrollSpeed = spd;
        tornadoIntensity = tor;
        centeredIntensity = cen;
        flipIntensity = flp;
        spiralIntensity = spi;
        squishIntensity = squ;
        blackHoleIntensity = bh;

        updateDisplay();
        EditorToast.show(msg);
    }

    private function resetAllModifiers():Void {
        pushUndoSnapshot();
        drunkIntensity = tipsyIntensity = beatIntensity = confusionIntensity = stealthIntensity = 0.0;
        reverseIntensity = crossIntensity = alternateIntensity = bumpyIntensity = invertIntensity = 0.0;
        waveIntensity = bounceIntensity = digitalIntensity = zigzagIntensity = expandIntensity = dizzyIntensity = miniIntensity = 0.0;
        tornadoIntensity = centeredIntensity = flipIntensity = spiralIntensity = squishIntensity = blackHoleIntensity = 0.0;
        scrollSpeed = 2.2;

        updateDisplay();
        EditorToast.show("Reset All Matrix Modifiers");
    }

    private function togglePlayback():Void {
        isPlayingSequence = !isPlayingSequence;
        EditorToast.show(isPlayingSequence ? "Started Sequence Simulation" : "Paused Sequence Simulation");
    }

    private function updateKeyframeSequence(elapsed:Float):Void {
        curCurvedTime += elapsed;
    }

    private function addCurrentAsKeyframe():Void {
        pushUndoSnapshot();
        var modName = modNames[selectedModIndex].toLowerCase().replace(" ", "");
        var curVal:Float = getModifierValueByIndex(selectedModIndex);

        var kf:ModchartKeyframe = {
            step: Math.floor(simSongTime / 100),
            modifier: modName,
            value: curVal,
            duration: 1.0,
            ease: easeOptions[curEaseIdx],
            target: affectOpponent ? "both" : "player"
        };
        keyframes.push(kf);
        selectedKeyframeIdx = keyframes.length - 1;
        updateKeyframeDisplay();
        EditorToast.show('Injected Keyframe: $modName ($curVal)');
    }

    private function removeSelectedKeyframe():Void {
        if (keyframes.length == 0) return;
        pushUndoSnapshot();
        keyframes.splice(selectedKeyframeIdx, 1);
        selectedKeyframeIdx = FlxMath.wrap(selectedKeyframeIdx, 0, Std.int(Math.max(0, keyframes.length - 1)));
        updateKeyframeDisplay();
        EditorToast.show("Removed Keyframe");
    }

    private function getModifierValueByIndex(idx:Int):Float {
        return switch (idx) {
            case 0: drunkIntensity;
            case 1: tipsyIntensity;
            case 2: beatIntensity;
            case 3: confusionIntensity;
            case 4: stealthIntensity;
            case 5: reverseIntensity;
            case 6: crossIntensity;
            case 7: alternateIntensity;
            case 8: bumpyIntensity;
            case 9: invertIntensity;
            case 10: waveIntensity;
            case 11: bounceIntensity;
            case 12: digitalIntensity;
            case 13: zigzagIntensity;
            case 14: expandIntensity;
            case 15: dizzyIntensity;
            case 16: miniIntensity;
            case 17: scrollSpeed;
            case 18: tornadoIntensity;
            case 19: centeredIntensity;
            case 20: flipIntensity;
            case 21: spiralIntensity;
            case 22: squishIntensity;
            case 23: blackHoleIntensity;
            default: 0.0;
        };
    }

    private function applyMatrixTransformations():Void {
        for (i in 0...4) {
            var def = playerDefaultPositions[i];
            var trans = calculateModifiers(def[0], def[1], i, simSongTime, true);
            var spr = playerStrumline.receptors[i];
            if (spr != null) {
                spr.x = trans.x;
                spr.y = trans.y;
                spr.angle = trans.angle;
                spr.scale.set(trans.scaleX, trans.scaleY);
                spr.alpha = trans.alpha;
            }
        }

        for (i in 0...4) {
            var def = opponentDefaultPositions[i];
            var trans = calculateModifiers(def[0], def[1], i, simSongTime + 600, affectOpponent);
            var spr = opponentStrumline.receptors[i];
            if (spr != null) {
                spr.x = trans.x;
                spr.y = trans.y;
                spr.angle = trans.angle;
                spr.scale.set(trans.scaleX, trans.scaleY);
                spr.alpha = trans.alpha * 0.55;
            }
        }
    }

    private function calculateModifiers(baseX:Float, baseY:Float, lane:Int, time:Float, enabled:Bool):{x:Float, y:Float, angle:Float, scaleX:Float, scaleY:Float, alpha:Float} {
        var rx = baseX;
        var ry = baseY;
        var rAngle = 0.0;
        var rScaleX = 0.7;
        var rScaleY = 0.7;
        var rAlpha = 1.0;

        if (!enabled) return {x: rx, y: ry, angle: rAngle, scaleX: rScaleX, scaleY: rScaleY, alpha: rAlpha};

        if (centeredIntensity != 0) {
            var centerX = (FlxG.width * 0.5) - ((4 * Strumline.STRUM_SPACING) * 0.5) + (lane * Strumline.STRUM_SPACING);
            rx = FlxMath.lerp(rx, centerX, centeredIntensity);
        }

        if (flipIntensity != 0) {
            var flippedX = baseX + ((3 - lane) - lane) * Strumline.STRUM_SPACING;
            rx = FlxMath.lerp(rx, flippedX, flipIntensity);
        }

        if (reverseIntensity != 0) {
            ry = FlxMath.lerp(ry, FlxG.height - 150.0, reverseIntensity);
        }

        if (drunkIntensity != 0) {
            rx += Math.cos((time * 0.004) + (lane * 0.5)) * (drunkIntensity * 40.0);
        }

        if (tipsyIntensity != 0) {
            ry += Math.sin((time * 0.005) + (lane * 1.2)) * (tipsyIntensity * 35.0);
        }

        if (beatIntensity != 0) {
            var beatWave = Math.sin((time * 0.006) + (lane * 0.25));
            if (beatWave > 0) {
                rx += beatWave * (beatIntensity * 22.0);
                rScaleX += beatWave * (beatIntensity * 0.15);
                rScaleY += beatWave * (beatIntensity * 0.15);
            }
        }

        if (tornadoIntensity != 0) {
            rx += Math.sin((time * 0.005) + (lane * 1.5)) * (tornadoIntensity * 55.0);
            rScaleX *= (1.0 + Math.cos((time * 0.005) + (lane * 1.5)) * 0.25 * tornadoIntensity);
        }

        if (spiralIntensity != 0) {
            var angleRad = (time * 0.004) + (lane * 0.8);
            rx += Math.cos(angleRad) * (spiralIntensity * 40.0);
            ry += Math.sin(angleRad) * (spiralIntensity * 40.0);
        }

        if (blackHoleIntensity != 0) {
            var distToCenter = ((FlxG.width * 0.5) - rx);
            rx += distToCenter * (blackHoleIntensity * 0.35);
        }

        if (squishIntensity != 0) {
            var pulse = Math.sin(time * 0.007);
            rScaleX += pulse * (squishIntensity * 0.25);
            rScaleY -= pulse * (squishIntensity * 0.25);
        }

        if (confusionIntensity != 0) {
            rAngle += ((time * 0.15 * confusionIntensity) + (lane * 45.0)) % 360.0;
        }

        if (crossIntensity != 0) {
            var crossDist = (lane == 1) ? Strumline.STRUM_SPACING : ((lane == 2) ? -Strumline.STRUM_SPACING : 0.0);
            rx += crossDist * crossIntensity;
        }

        if (invertIntensity != 0) {
            var invDist = (lane == 0 ? Strumline.STRUM_SPACING * 3 : (lane == 1 ? Strumline.STRUM_SPACING : (lane == 2 ? -Strumline.STRUM_SPACING : -Strumline.STRUM_SPACING * 3)));
            rx += invDist * (invertIntensity * 0.5);
        }

        if (alternateIntensity != 0) {
            var altDir = (lane % 2 == 0) ? 1.0 : -1.0;
            ry += altDir * (alternateIntensity * 40.0);
        }

        if (bumpyIntensity != 0) {
            var bump = Math.sin((time * 0.008) + (lane * 0.7));
            ry += bump * (bumpyIntensity * 25.0);
            rScaleX += (bump * 0.12 * bumpyIntensity);
            rScaleY += (bump * 0.12 * bumpyIntensity);
        }

        if (waveIntensity != 0) {
            rx += Math.sin((time * 0.007) + (ry * 0.015)) * (waveIntensity * 30.0);
        }

        if (bounceIntensity != 0) {
            ry -= Math.abs(Math.sin((time * 0.006) + (lane * 0.5))) * (bounceIntensity * 45.0);
        }

        if (digitalIntensity != 0) {
            var quant = Math.floor(time * 0.01) % 4;
            rx += (quant == lane ? digitalIntensity * 20.0 : 0.0);
        }

        if (zigzagIntensity != 0) {
            rx += ((Math.floor(time * 0.008 + lane) % 2 == 0) ? 1 : -1) * (zigzagIntensity * 25.0);
        }

        if (expandIntensity != 0) {
            var expDist = (lane - 1.5) * Strumline.STRUM_SPACING * expandIntensity;
            rx += expDist;
        }

        if (dizzyIntensity != 0) {
            rAngle += Math.sin((time * 0.005) + lane) * (dizzyIntensity * 90.0);
        }

        if (miniIntensity != 0) {
            var factor = Math.max(0.2, 1.0 - (miniIntensity * 0.5));
            rScaleX *= factor;
            rScaleY *= factor;
        }

        rAlpha = Math.max(0.0, 1.0 - stealthIntensity);

        return {x: rx, y: ry, angle: rAngle, scaleX: rScaleX, scaleY: rScaleY, alpha: rAlpha};
    }

    private function renderOscilloscopeWaveform():Void {
        oscilloscopeGraph.pixels.fillRect(new Rectangle(0, 0, 270, 90), 0xFF111118);

        var midY = 45.0;
        for (px in 0...270) {
            var sampleTime = simSongTime + (px * 12.0);
            var waveSample = Math.sin(sampleTime * 0.005) * drunkIntensity + Math.cos(sampleTime * 0.006) * tipsyIntensity + Math.sin(sampleTime * 0.008) * bumpyIntensity + Math.sin(sampleTime * 0.004) * tornadoIntensity;
            var py = Std.int(midY + (waveSample * 14.0));
            py = Std.int(Math.max(2, Math.min(88, py)));

            oscilloscopeGraph.pixels.setPixel32(px, py, 0xFF00FFCC);
        }
        oscilloscopeGraph.dirty = true;
    }

    private function spawnContinuousTestNotes(elapsed:Float):Void {
        spawnTimer += elapsed;
        if (spawnTimer >= (0.35 / scrollSpeed)) {
            spawnTimer = 0.0;
            var lane = FlxG.random.int(0, 3);
            var def = playerDefaultPositions[lane];

            var testNote = new Note(0, lane, 0.0, null, false, false, true, "normal");
            testNote.x = def[0];
            testNote.y = FlxG.height + 60;
            fallingNotesGroup.add(testNote);
        }

        fallingNotesGroup.forEachAlive(function(n:Note) {
            var lane = n.noteData % 4;
            var def = playerDefaultPositions[lane];

            n.y -= elapsed * 320.0 * scrollSpeed;

            var trans = calculateModifiers(def[0], n.y, lane, simSongTime + ((FlxG.height - n.y) * 0.8), true);
            n.x = trans.x;
            n.angle = trans.angle;
            n.scale.set(trans.scaleX, trans.scaleY);
            n.alpha = trans.alpha;

            var hitThreshold = (reverseIntensity > 0.5) ? FlxG.height - 160 : 80;
            var isArrived = (reverseIntensity > 0.5) ? (n.y >= hitThreshold) : (n.y <= hitThreshold);

            if (isArrived) {
                if (playerStrumline.receptors[lane] != null) {
                    playerStrumline.receptors[lane].playAnim("confirm", true);
                    playerStrumline.receptors[lane].resetAnim = 0.12;
                }
                n.kill();
                fallingNotesGroup.remove(n, true);
                n.destroy();
            }
        });
    }

    private function updateDisplay():Void {
        var out = "ACTIVE MATRIX MODIFIERS:\n\n";
        var start = Std.int(Math.max(0, selectedModIndex - 5));
        var end = Std.int(Math.min(modNames.length, start + 12));

        for (i in start...end) {
            var sel = (i == selectedModIndex);
            var prefix = sel ? "> " : "  ";
            var suffix = sel ? " <" : "";
            out += '$prefix${modNames[i]}: ${getModifierValueByIndex(i)}$suffix\n';
        }
        modifierListTxt.text = out;
    }

    private function updateKeyframeDisplay():Void {
        var out = 'KEYFRAME TIMELINE (${keyframes.length}):\n\n';
        var start = Std.int(Math.max(0, selectedKeyframeIdx - 3));
        var end = Std.int(Math.min(keyframes.length, start + 7));

        for (i in start...end) {
            var kf = keyframes[i];
            var isCur = (i == selectedKeyframeIdx);
            out += (isCur ? '> ' : '  ') + '[Step ${kf.step}] ${kf.modifier} -> ${kf.value} (${kf.ease})\n';
        }
        if (keyframes.length == 0) out += "  No keyframes defined yet.\n  Press (K) to record state.";
        keyframeListTxt.text = out;
    }

    private function updateLiveFormulaDisplay():Void {
        var timeSec = Math.round(simSongTime * 0.001 * 100) / 100;
        formulaTxt.text = 'SIM TIME: ${timeSec}s | SPEED: ${scrollSpeed}x\n' +
            'Active Modifiers: ${modNames.length} Registered\n' +
            'Timeline Keyframes: ${keyframes.length} Captured';
    }

    private function pushUndoSnapshot():Void {
        var data = {
            d: drunkIntensity, t: tipsyIntensity, b: beatIntensity, c: confusionIntensity,
            s: stealthIntensity, r: reverseIntensity, cr: crossIntensity, a: alternateIntensity,
            bmp: bumpyIntensity, inv: invertIntensity, w: waveIntensity, bnc: bounceIntensity,
            dig: digitalIntensity, zig: zigzagIntensity, exp: expandIntensity, diz: dizzyIntensity,
            min: miniIntensity, spd: scrollSpeed, tor: tornadoIntensity, cen: centeredIntensity,
            flp: flipIntensity, spi: spiralIntensity, squ: squishIntensity, bh: blackHoleIntensity,
            kfs: keyframes
        };
        undoStack.push(Json.stringify(data));
        if (undoStack.length > MAX_UNDO_DEPTH) undoStack.shift();
        redoStack = [];
    }

    private function undo():Void {
        if (undoStack.length <= 1) {
            EditorToast.show("No more undos available.", true);
            return;
        }
        var cur = undoStack.pop();
        redoStack.push(cur);
        var prev = undoStack[undoStack.length - 1];
        restoreSnapshot(prev);
        EditorToast.show("Undone matrix action.");
    }

    private function redo():Void {
        if (redoStack.length == 0) {
            EditorToast.show("No redos available.", true);
            return;
        }
        var next = redoStack.pop();
        undoStack.push(next);
        restoreSnapshot(next);
        EditorToast.show("Redone matrix action.");
    }

    private function restoreSnapshot(jsonStr:String):Void {
        var data:Dynamic = Json.parse(jsonStr);
        drunkIntensity = data.d; tipsyIntensity = data.t; beatIntensity = data.b;
        confusionIntensity = data.c; stealthIntensity = data.s; reverseIntensity = data.r;
        crossIntensity = data.cr; alternateIntensity = data.a; bumpyIntensity = data.bmp;
        invertIntensity = data.inv; waveIntensity = data.w; bounceIntensity = data.bnc;
        digitalIntensity = data.dig; zigzagIntensity = data.zig; expandIntensity = data.exp;
        dizzyIntensity = data.diz; miniIntensity = data.min; scrollSpeed = data.spd;
        tornadoIntensity = data.tor != null ? data.tor : 0.0;
        centeredIntensity = data.cen != null ? data.cen : 0.0;
        flipIntensity = data.flp != null ? data.flp : 0.0;
        spiralIntensity = data.spi != null ? data.spi : 0.0;
        squishIntensity = data.squ != null ? data.squ : 0.0;
        blackHoleIntensity = data.bh != null ? data.bh : 0.0;
        keyframes = data.kfs != null ? cast data.kfs : [];
        updateDisplay();
        updateKeyframeDisplay();
    }

    private function exportSoulScript():Void {
        var code = '# SoulScript Modchart Timeline Matrix\n';
        for (kf in keyframes) {
            code += 'on step(${kf.step}):\n' +
                    '    modchart.${kf.modifier} -> ${kf.value} in ${kf.duration}s (${kf.ease})\n' +
                    'end\n\n';
        }
        System.setClipboard(code);
        EditorToast.show("SoulScript Timeline Exported to Clipboard!");
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    private function exportLuaScript():Void {
        var code = '-- Lua Modchart Automation\nfunction onStepHit()\n';
        for (kf in keyframes) {
            code += '    if curStep == ${kf.step} then\n' +
                    '        doTweenMod("${kf.modifier}", "${kf.modifier}", ${kf.value}, ${kf.duration}, "${kf.ease}")\n' +
                    '    end\n';
        }
        code += 'end\n';
        System.setClipboard(code);
        EditorToast.show("Lua Modchart Script Exported to Clipboard!");
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    private function exportHScript():Void {
        var code = '// HScript Iris Modchart Pipeline\nfunction onStepHit(curStep) {\n';
        for (kf in keyframes) {
            code += '    if (curStep == ${kf.step}) {\n' +
                    '        modcharts.tweenModifier("${kf.modifier}", ${kf.value}, ${kf.duration}, FlxEase.${kf.ease});\n' +
                    '    }\n';
        }
        code += '}\n';
        System.setClipboard(code);
        EditorToast.show("HScript Code Exported to Clipboard!");
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    private function exportJsonData():Void {
        var formatted = Json.stringify({keyframes: keyframes}, "\t");
        System.setClipboard(formatted);
        EditorToast.show("Raw Keyframe JSON Copied to Clipboard!");
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }
}