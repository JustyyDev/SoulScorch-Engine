package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.system.System;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.ui.menus.editors.editorui.EditorButton;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.editors.editorui.EditorToast;
import soulscorch.ui.menus.editors.editorui.EditorTopBar;
import soulscorch.ui.menus.editors.editorui.EditorWindow;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class ModchartWorkspaceState extends MusicBeatState {
    private var camWorkspace:FlxCamera;
    private var camHUD:FlxCamera;

    private var playerStrums:Array<FlxSprite> = [];
    private var defaultPositions:Array<Array<Float>> = [];
    private var fallingNotesGroup:FlxTypedGroup<FlxSprite>;

    private var drunkIntensity:Float = 0.0;
    private var tipsyIntensity:Float = 0.0;
    private var beatIntensity:Float = 0.0;
    private var confusionIntensity:Float = 0.0;
    private var stealthIntensity:Float = 0.0;

    private var selectedModIndex:Int = 0;
    private var modNames:Array<String> = ["Drunk", "Tipsy", "Beat Pulse", "Confusion (Spin)", "Stealth"];

    private var topBar:EditorTopBar;
    private var modifierListTxt:FlxText;
    private var simSongTime:Float = 0.0;
    private var spawnTimer:Float = 0.0;

    override public function create():Void {
        super.create();

        camWorkspace = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camWorkspace);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camWorkspace, true);

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        add(bg);

        var center = new FlxSprite(FlxG.width * 0.5 - 1, 0).makeGraphic(2, FlxG.height, EditorTheme.PANEL_BORDER);
        add(center);

        fallingNotesGroup = new FlxTypedGroup<FlxSprite>();
        add(fallingNotesGroup);

        createStrumMatrix();
        setupWindows();

        add(new EditorToast());
        FlxG.mouse.visible = true;
    }

    private function createStrumMatrix():Void {
        var noteColors = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
        defaultPositions = [];

        for (i in 0...4) {
            var xPos:Float = (FlxG.width * 0.5) - 220 + (i * 110);
            var yPos:Float = 100;
            defaultPositions.push([xPos, yPos]);

            var strum = new FlxSprite(xPos, yPos).makeGraphic(90, 90, noteColors[i]);
            playerStrums.push(strum);
            add(strum);
        }
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar("MODCHART MATRIX");
        topBar.cameras = [camHUD];
        topBar.addAction("Copy SoulScript (C)", copySoulScript);
        topBar.addAction("Exit", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        var modWindow = new EditorWindow(15, 45, 300, 260, "Modifier Parameters");
        modWindow.cameras = [camHUD];
        add(modWindow);

        modifierListTxt = new FlxText(10, 8, 280, "", 13);
        modifierListTxt.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        modWindow.addElement(modifierListTxt);

        var presetWindow = new EditorWindow(FlxG.width - 315, 45, 300, 200, "Math Presets");
        presetWindow.cameras = [camHUD];
        add(presetWindow);

        presetWindow.addElement(new EditorButton(10, 8, 280, 28, "S-Curve Sine Wave", function() {
            drunkIntensity = 1.0; tipsyIntensity = 0.4; beatIntensity = confusionIntensity = stealthIntensity = 0.0;
            EditorToast.show("Preset: S-Curve Loaded");
            updateDisplay();
        }));

        presetWindow.addElement(new EditorButton(10, 44, 280, 28, "Chaos Vortex", function() {
            drunkIntensity = 1.5; tipsyIntensity = 1.5; beatIntensity = 1.2; confusionIntensity = 2.0; stealthIntensity = 0.2;
            EditorToast.show("Preset: Chaos Vortex Loaded");
            updateDisplay();
        }));

        presetWindow.addElement(new EditorButton(10, 80, 280, 28, "Reset Parameters", function() {
            drunkIntensity = tipsyIntensity = beatIntensity = confusionIntensity = stealthIntensity = 0.0;
            EditorToast.show("Modifiers Reset");
            updateDisplay();
        }));

        updateDisplay();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        simSongTime += elapsed * 1000.0;

        if (FlxG.keys.justPressed.W) { selectedModIndex = FlxMath.wrap(selectedModIndex - 1, 0, modNames.length - 1); updateDisplay(); }
        if (FlxG.keys.justPressed.S) { selectedModIndex = FlxMath.wrap(selectedModIndex + 1, 0, modNames.length - 1); updateDisplay(); }

        var delta = FlxG.keys.pressed.SHIFT ? 0.25 : 0.05;
        if (FlxG.keys.justPressed.LEFT) adjustModifier(-delta);
        if (FlxG.keys.justPressed.RIGHT) adjustModifier(delta);
        if (FlxG.keys.justPressed.C) copySoulScript();
        if (FlxG.keys.justPressed.ESCAPE) MusicBeatState.switchState(new MainMenuState());

        applyModcharts();
        spawnContinuousTestNotes(elapsed);
    }

    private function adjustModifier(delta:Float):Void {
        switch (selectedModIndex) {
            case 0: drunkIntensity = Math.round((drunkIntensity + delta) * 100) / 100;
            case 1: tipsyIntensity = Math.round((tipsyIntensity + delta) * 100) / 100;
            case 2: beatIntensity = Math.round((beatIntensity + delta) * 100) / 100;
            case 3: confusionIntensity = Math.round((confusionIntensity + delta) * 100) / 100;
            case 4: stealthIntensity = Math.min(1.0, Math.max(0.0, Math.round((stealthIntensity + delta) * 100) / 100));
        }
        updateDisplay();
    }

    private function applyModcharts():Void {
        for (i in 0...4) {
            var def = defaultPositions[i];
            var spr = playerStrums[i];

            var rx = def[0] + (drunkIntensity != 0 ? Math.cos((simSongTime * 0.004) + (i * 0.5)) * (drunkIntensity * 35.0) : 0);
            var ry = def[1] + (tipsyIntensity != 0 ? Math.sin((simSongTime * 0.005) + (i * 1.2)) * (tipsyIntensity * 30.0) : 0);
            var rAngle = confusionIntensity != 0 ? ((simSongTime * 0.15 * confusionIntensity) + (i * 45.0)) % 360.0 : 0.0;

            spr.x = rx;
            spr.y = ry;
            spr.angle = rAngle;
            spr.alpha = 1.0 - stealthIntensity;
        }
    }

    private function spawnContinuousTestNotes(elapsed:Float):Void {
        spawnTimer += elapsed;
        if (spawnTimer >= 0.25) {
            spawnTimer = 0.0;
            var lane = FlxG.random.int(0, 3);
            var noteColors = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
            var def = defaultPositions[lane];

            var note = new FlxSprite(def[0] + 15, FlxG.height + 50).makeGraphic(60, 60, noteColors[lane]);
            note.alpha = 0.8;
            fallingNotesGroup.add(note);
        }

        fallingNotesGroup.forEachAlive(function(n) {
            n.y -= elapsed * 650.0;
            if (n.y < -100) { n.kill(); fallingNotesGroup.remove(n, true); n.destroy(); }
        });
    }

    private function updateDisplay():Void {
        var values = [drunkIntensity, tipsyIntensity, beatIntensity, confusionIntensity, stealthIntensity];
        var out = "ACTIVE MATRICES:\n\n";
        for (i in 0...modNames.length) {
            out += (i == selectedModIndex ? '> ' : '  ') + '${modNames[i]}: ${values[i]}' + (i == selectedModIndex ? ' <\n' : '\n');
        }
        modifierListTxt.text = out;
    }

    private function copySoulScript():Void {
        var code = '# SoulScript Modchart Event Trigger\n' +
                   'on event("Modchart Wave"):\n' +
                   '    modchart.drunk -> $drunkIntensity in 0.5s (cubeOut)\n' +
                   '    modchart.tipsy -> $tipsyIntensity in 0.5s (cubeOut)\n' +
                   '    modchart.confusion -> $confusionIntensity in 0.5s (elasticOut)\n' +
                   'end';

        System.setClipboard(code);
        EditorToast.show("SoulScript Event Copied!");
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }
}