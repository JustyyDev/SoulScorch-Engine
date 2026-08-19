package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.system.System;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.ui.menus.editors.editorui.EditorButton;
import soulscorch.ui.menus.editors.editorui.EditorCheckbox;
import soulscorch.ui.menus.editors.editorui.EditorNumericStepper;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.editors.editorui.EditorToast;
import soulscorch.ui.menus.editors.editorui.EditorTopBar;
import soulscorch.ui.menus.editors.editorui.EditorWindow;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class ModchartWorkspaceState extends MusicBeatState {
    private var camWorkspace:FlxCamera;
    private var camHUD:FlxCamera;

    private var playerStrumline:Strumline;
    private var opponentStrumline:Strumline;
    private var playerDefaultPositions:Array<Array<Float>> = [];
    private var opponentDefaultPositions:Array<Array<Float>> = [];
    private var fallingNotesGroup:FlxTypedGroup<Note>;

    // --- Math Matrix Modifiers ---
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
    private var scrollSpeed:Float = 2.0;

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
        "Scroll Speed"
    ];

    // --- UI Windows & Layout ---
    private var topBar:EditorTopBar;
    private var matrixWindow:EditorWindow;
    private var presetsWindow:EditorWindow;
    private var visualizerWindow:EditorWindow;

    private var modifierListTxt:FlxText;
    private var formulaTxt:FlxText;
    private var simSongTime:Float = 0.0;
    private var spawnTimer:Float = 0.0;
    private var checkDualStrums:EditorCheckbox;
    private var affectOpponent:Bool = true;

    override public function create():Void {
        super.create();

        camWorkspace = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camWorkspace);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camWorkspace, true);

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        bg.scrollFactor.set(0, 0);
        add(bg);

        // Center line & grid background
        var center = new FlxSprite(FlxG.width * 0.5 - 1, 0).makeGraphic(2, FlxG.height, EditorTheme.PANEL_BORDER);
        center.scrollFactor.set(0, 0);
        add(center);

        fallingNotesGroup = new FlxTypedGroup<Note>();
        add(fallingNotesGroup);

        createStrumMatrix();
        setupWindows();

        add(new EditorToast());
        FlxG.mouse.visible = true;
    }

    private function createStrumMatrix():Void {
        playerDefaultPositions = [];
        opponentDefaultPositions = [];

        var oppX = 90.0;
        var playerX = FlxG.width - (Strumline.STRUM_SPACING * 4) - 90;
        var startY = 80.0;

        opponentStrumline = new Strumline(oppX, startY, false, false);
        opponentStrumline.alpha = 0.55;
        add(opponentStrumline);

        playerStrumline = new Strumline(playerX, startY, true, false);
        add(playerStrumline);

        for (i in 0...4) {
            opponentDefaultPositions.push([oppX + (i * Strumline.STRUM_SPACING), startY]);
            playerDefaultPositions.push([playerX + (i * Strumline.STRUM_SPACING), startY]);
        }
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar("MODCHART MATRIX STUDIO");
        topBar.cameras = [camHUD];
        topBar.addAction("Copy SoulScript (C)", copySoulScript);
        topBar.addAction("Reset Matrix (R)", resetAllModifiers);
        topBar.addAction("Exit", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        // --- 1. Modifiers & Values Window ---
        matrixWindow = new EditorWindow(15, 45, 300, 390, "Matrix Parameters");
        matrixWindow.cameras = [camHUD];
        add(matrixWindow);

        modifierListTxt = new FlxText(10, 8, 280, "", 13);
        modifierListTxt.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        matrixWindow.addElement(modifierListTxt);

        checkDualStrums = new EditorCheckbox(10, 320, "Affect Opponent Strums", affectOpponent, function(c) {
            affectOpponent = c;
        });
        matrixWindow.addElement(checkDualStrums);

        // --- 2. Live Formula & Wave Math Visualizer ---
        visualizerWindow = new EditorWindow(15, 445, 300, 160, "Live Oscillator Math");
        visualizerWindow.cameras = [camHUD];
        add(visualizerWindow);

        formulaTxt = new FlxText(10, 8, 280, "", 12);
        formulaTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_CYAN, LEFT);
        visualizerWindow.addElement(formulaTxt);

        // --- 3. Presets & Quick Injections ---
        presetsWindow = new EditorWindow(FlxG.width - 315, 45, 300, 320, "Math Wave Presets");
        presetsWindow.cameras = [camHUD];
        add(presetsWindow);

        presetsWindow.addElement(new EditorButton(10, 8, 280, 26, "S-Curve Sine Wave (1)", function() {
            applyPreset(1.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, "Preset: S-Curve Wave Loaded");
        }));

        presetsWindow.addElement(new EditorButton(10, 38, 280, 26, "Cross-Over Wave (2)", function() {
            applyPreset(0.0, 0.8, 0.0, 0.0, 0.0, 0.0, 1.2, 0.0, 0.0, 0.0, 2.0, "Preset: Cross-Over Loaded");
        }));

        presetsWindow.addElement(new EditorButton(10, 68, 280, 26, "Chaos Vortex (3)", function() {
            applyPreset(1.4, 1.2, 1.0, 1.5, 0.2, 0.0, 0.5, 0.5, 0.8, 0.0, 2.2, "Preset: Chaos Vortex Loaded");
        }));

        presetsWindow.addElement(new EditorButton(10, 98, 280, 26, "Invert Splitter (4)", function() {
            applyPreset(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 2.0, "Preset: Invert Splitter Loaded");
        }));

        presetsWindow.addElement(new EditorButton(10, 128, 280, 26, "Bumpy Pulse (5)", function() {
            applyPreset(0.3, 0.0, 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 0.0, 2.0, "Preset: Bumpy Pulse Loaded");
        }));

        presetsWindow.addElement(new EditorButton(10, 158, 280, 26, "Stealth Inversion (6)", function() {
            applyPreset(0.5, 0.5, 0.0, 0.5, 0.65, 1.0, 0.0, 0.0, 0.0, 0.0, 2.0, "Preset: Stealth Inversion Loaded");
        }));

        presetsWindow.addElement(new EditorButton(10, 195, 280, 28, "Reset All Modifiers (R)", resetAllModifiers));

        updateDisplay();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        simSongTime += elapsed * 1000.0 * (scrollSpeed * 0.5);

        handleKeyboardNavigation();
        applyMatrixTransformations();
        spawnContinuousTestNotes(elapsed);
        updateLiveFormulaDisplay();
    }

    private function handleKeyboardNavigation():Void {
        if (FlxG.keys.justPressed.W) { selectedModIndex = FlxMath.wrap(selectedModIndex - 1, 0, modNames.length - 1); updateDisplay(); }
        if (FlxG.keys.justPressed.S) { selectedModIndex = FlxMath.wrap(selectedModIndex + 1, 0, modNames.length - 1); updateDisplay(); }

        var delta = FlxG.keys.pressed.SHIFT ? 0.25 : 0.05;
        if (FlxG.keys.justPressed.LEFT) adjustModifier(-delta);
        if (FlxG.keys.justPressed.RIGHT) adjustModifier(delta);

        // Preset hotkeys [1 - 6]
        if (FlxG.keys.justPressed.ONE) applyPreset(1.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, "Preset: S-Curve Wave Loaded");
        if (FlxG.keys.justPressed.TWO) applyPreset(0.0, 0.8, 0.0, 0.0, 0.0, 0.0, 1.2, 0.0, 0.0, 0.0, 2.0, "Preset: Cross-Over Loaded");
        if (FlxG.keys.justPressed.THREE) applyPreset(1.4, 1.2, 1.0, 1.5, 0.2, 0.0, 0.5, 0.5, 0.8, 0.0, 2.2, "Preset: Chaos Vortex Loaded");
        if (FlxG.keys.justPressed.FOUR) applyPreset(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 2.0, "Preset: Invert Splitter Loaded");
        if (FlxG.keys.justPressed.FIVE) applyPreset(0.3, 0.0, 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 0.0, 2.0, "Preset: Bumpy Pulse Loaded");
        if (FlxG.keys.justPressed.SIX) applyPreset(0.5, 0.5, 0.0, 0.5, 0.65, 1.0, 0.0, 0.0, 0.0, 0.0, 2.0, "Preset: Stealth Inversion Loaded");

        if (FlxG.keys.justPressed.R) resetAllModifiers();
        if (FlxG.keys.justPressed.C) copySoulScript();
        if (FlxG.keys.justPressed.ESCAPE) MusicBeatState.switchState(new MainMenuState());
    }

    private function adjustModifier(delta:Float):Void {
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
            case 10: scrollSpeed = Math.max(0.5, Math.min(5.0, roundMod(scrollSpeed + delta)));
        }
        updateDisplay();
    }

    private inline function roundMod(val:Float):Float {
        return Math.round(val * 100) / 100;
    }

    private function applyPreset(d:Float, t:Float, b:Float, c:Float, s:Float, rev:Float, cr:Float, alt:Float, bmp:Float, inv:Float, spd:Float, msg:String):Void {
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
        scrollSpeed = spd;
        updateDisplay();
        EditorToast.show(msg);
    }

    private function resetAllModifiers():Void {
        drunkIntensity = tipsyIntensity = beatIntensity = confusionIntensity = stealthIntensity = 0.0;
        reverseIntensity = crossIntensity = alternateIntensity = bumpyIntensity = invertIntensity = 0.0;
        scrollSpeed = 2.0;
        updateDisplay();
        EditorToast.show("All Modifiers Reset to 0");
    }

    private function applyMatrixTransformations():Void {
        // 1. Transform Player Strums
        for (i in 0...4) {
            var def = playerDefaultPositions[i];
            var trans = calculateModifiers(def[0], def[1], i, simSongTime, true);
            var spr = playerStrumline.receptors[i];
            if (spr != null) {
                spr.x = trans.x;
                spr.y = trans.y;
                spr.angle = trans.angle;
                spr.scale.set(trans.scale, trans.scale);
                spr.alpha = trans.alpha;
            }
        }

        // 2. Transform Opponent Strums
        for (i in 0...4) {
            var def = opponentDefaultPositions[i];
            var trans = calculateModifiers(def[0], def[1], i, simSongTime + 600, affectOpponent);
            var spr = opponentStrumline.receptors[i];
            if (spr != null) {
                spr.x = trans.x;
                spr.y = trans.y;
                spr.angle = trans.angle;
                spr.scale.set(trans.scale, trans.scale);
                spr.alpha = trans.alpha * 0.55;
            }
        }
    }

    private function calculateModifiers(baseX:Float, baseY:Float, lane:Int, time:Float, enabled:Bool):{x:Float, y:Float, angle:Float, scale:Float, alpha:Float} {
        var rx = baseX;
        var ry = baseY;
        var rAngle = 0.0;
        var rScale = 0.7;
        var rAlpha = 1.0;

        if (!enabled) return {x: rx, y: ry, angle: rAngle, scale: rScale, alpha: rAlpha};

        // Downscroll / Reverse
        if (reverseIntensity != 0) {
            ry = FlxMath.lerp(ry, FlxG.height - 150.0, reverseIntensity);
        }

        // Drunk: Sine wave horizontally offset per lane
        if (drunkIntensity != 0) {
            rx += Math.cos((time * 0.004) + (lane * 0.5)) * (drunkIntensity * 40.0);
        }

        // Tipsy: Sine wave vertically offset per lane
        if (tipsyIntensity != 0) {
            ry += Math.sin((time * 0.005) + (lane * 1.2)) * (tipsyIntensity * 35.0);
        }

        // Beat Pulse: Snappy expansion on quarter note intervals
        if (beatIntensity != 0) {
            var beatWave = Math.sin((time * 0.006) + (lane * 0.25));
            if (beatWave > 0) {
                rx += beatWave * (beatIntensity * 22.0);
                rScale += beatWave * (beatIntensity * 0.15);
            }
        }

        // Confusion: Continuous receptor rotation
        if (confusionIntensity != 0) {
            rAngle = ((time * 0.15 * confusionIntensity) + (lane * 45.0)) % 360.0;
        }

        // Cross: Swaps inner lanes 1 & 2 outward
        if (crossIntensity != 0) {
            var crossDist = (lane == 1) ? Strumline.STRUM_SPACING : ((lane == 2) ? -Strumline.STRUM_SPACING : 0.0);
            rx += crossDist * crossIntensity;
        }

        // Invert: Swaps lanes 0<->3 and 1<->2
        if (invertIntensity != 0) {
            var invDist = (lane == 0 ? Strumline.STRUM_SPACING * 3 : (lane == 1 ? Strumline.STRUM_SPACING : (lane == 2 ? -Strumline.STRUM_SPACING : -Strumline.STRUM_SPACING * 3)));
            rx += invDist * (invertIntensity * 0.5);
        }

        // Alternate: Alternate lanes shift up and down
        if (alternateIntensity != 0) {
            var altDir = (lane % 2 == 0) ? 1.0 : -1.0;
            ry += altDir * (alternateIntensity * 40.0);
        }

        // Bumpy: Simulates 3D perspective distortion
        if (bumpyIntensity != 0) {
            var bump = Math.sin((time * 0.008) + (lane * 0.7));
            ry += bump * (bumpyIntensity * 25.0);
            rScale += (bump * 0.12 * bumpyIntensity);
        }

        // Stealth: Hides opacity
        rAlpha = Math.max(0.0, 1.0 - stealthIntensity);

        return {x: rx, y: ry, angle: rAngle, scale: rScale, alpha: rAlpha};
    }

    private function spawnContinuousTestNotes(elapsed:Float):Void {
        spawnTimer += elapsed;
        if (spawnTimer >= (0.35 / scrollSpeed)) {
            spawnTimer = 0.0;
            var lane = FlxG.random.int(0, 3);
            var def = playerDefaultPositions[lane];

            var testNote = new Note(0, lane, 0.0, null, false, false, true, "default");
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
            n.scale.set(trans.scale, trans.scale);
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
        var values:Array<Float> = [
            drunkIntensity,
            tipsyIntensity,
            beatIntensity,
            confusionIntensity,
            stealthIntensity,
            reverseIntensity,
            crossIntensity,
            alternateIntensity,
            bumpyIntensity,
            invertIntensity,
            scrollSpeed
        ];

        var out = "MODIFIERS & MATRICES:\n\n";
        for (i in 0...modNames.length) {
            var sel = (i == selectedModIndex);
            var prefix = sel ? "> " : "  ";
            var suffix = sel ? " <" : "";
            out += '$prefix${modNames[i]}: ${values[i]}$suffix\n';
        }
        modifierListTxt.text = out;
    }

    private function updateLiveFormulaDisplay():Void {
        var timeSec = Math.round(simSongTime * 0.001 * 100) / 100;
        formulaTxt.text = 'TIME: ${timeSec}s | SPEED: ${scrollSpeed}x\n' +
            'Drunk(X): cos(t*0.004 + L*0.5) * ${drunkIntensity}\n' +
            'Tipsy(Y): sin(t*0.005 + L*1.2) * ${tipsyIntensity}\n' +
            'Confusion: (t*0.15*${confusionIntensity} + L*45) mod 360\n' +
            'Bumpy: sin(t*0.008 + L*0.7) * ${bumpyIntensity}';
    }

    private function copySoulScript():Void {
        var code = '# SoulScript Modchart Event Matrix\n' +
                   'on event("Matrix Pulse"):\n' +
                   '    modchart.drunk -> $drunkIntensity in 0.5s (cubeOut)\n' +
                   '    modchart.tipsy -> $tipsyIntensity in 0.5s (cubeOut)\n' +
                   '    modchart.beat -> $beatIntensity in 0.35s (bounceOut)\n' +
                   '    modchart.confusion -> $confusionIntensity in 0.5s (elasticOut)\n' +
                   '    modchart.stealth -> $stealthIntensity in 0.4s (quadOut)\n' +
                   '    modchart.reverse -> $reverseIntensity in 0.5s (cubeOut)\n' +
                   '    modchart.cross -> $crossIntensity in 0.4s (elasticOut)\n' +
                   '    modchart.bumpy -> $bumpyIntensity in 0.5s (cubeOut)\n' +
                   'end';

        System.setClipboard(code);
        EditorToast.show("SoulScript Matrix Event Copied to Clipboard!");
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }
}