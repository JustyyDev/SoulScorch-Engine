package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.geom.Rectangle;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.actors.CharacterJson;
import soulscorch.gameplay.actors.HealthIcon;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.menus.editors.editorui.*;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class CharacterEditorState extends MusicBeatState {
    public var curCharacter:String = "dad";
    public var isPlayer:Bool = false;

    // --- Cameras ---
    private var camEditor:FlxCamera;
    private var camUI:FlxCamera;

    // --- Actors & Layers ---
    private var charLayer:Character;
    private var ghostChar:Character;
    private var stageBackdrop:FlxSprite;
    private var groundGrid:FlxSprite;
    private var crosshair:FlxSprite;
    private var camFollowMarker:FlxSprite;
    private var camFollow:FlxPoint;

    // --- HUD Health Preview ---
    private var previewHealthBarBG:FlxSprite;
    private var previewHealthBar:FlxBar;
    private var previewIcon:HealthIcon;

    // --- Windows & UI Panes ---
    private var topBar:EditorTopBar;
    private var animMatrixWindow:EditorWindow;
    private var propertiesWindow:EditorWindow;
    private var offsetsWindow:EditorWindow;
    private var colorPickerWindow:EditorWindow;
    private var newAnimWindow:EditorWindow;
    private var charPickerModal:EditorWindow;

    // --- Inspector Labels ---
    private var curAnimTxt:FlxText;
    private var offsetTxt:FlxText;
    private var animListTxt:FlxText;
    private var frameInfoTxt:FlxText;
    private var stageNameTxt:FlxText;

    // --- Input Controls ---
    private var inputAnimName:EditorInputText;
    private var inputAnimPrefix:EditorInputText;
    private var stepperAnimFPS:EditorNumericStepper;
    private var checkAnimLoop:EditorCheckbox;
    private var inputHealthIcon:EditorInputText;
    private var inputImageSheet:EditorInputText;

    // --- Color Steppers ---
    private var stepperColorR:EditorNumericStepper;
    private var stepperColorG:EditorNumericStepper;
    private var stepperColorB:EditorNumericStepper;
    private var colorPreviewBox:FlxSprite;

    // --- State Variables ---
    private var animList:Array<String> = [];
    private var curAnimIndex:Int = 0;
    private var ghostAnimIndex:Int = 0;
    private var showGhost:Bool = true;
    private var curStageBackdrop:String = "stage";
    private var availableStages:Array<String> = ["stage", "spooky", "philly", "limo", "mall", "school", "tank"];
    private var curStageIdx:Int = 0;

    // --- Drag Controls ---
    private var isDraggingCamAnchor:Bool = false;
    private var isDraggingCharOffset:Bool = false;
    private var dragStartOffset:FlxPoint;
    private var dragStartMouse:FlxPoint;

    // --- History Stack ---
    private var undoStack:Array<String> = [];
    private var redoStack:Array<String> = [];
    private static inline var MAX_UNDO_DEPTH:Int = 50;

    public function new(?char:String = "dad", ?isPlayer:Bool = false) {
        super();
        this.curCharacter = (char != null && char.trim().length > 0) ? char.trim() : "dad";
        this.isPlayer = isPlayer;
    }

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Actor Studio Ultra", 'Calibrating: ${curCharacter.toUpperCase()}');
        #end

        setupCameras();

        camFollow = FlxPoint.get(FlxG.width * 0.5, FlxG.height * 0.5);
        dragStartOffset = FlxPoint.get(0, 0);
        dragStartMouse = FlxPoint.get(0, 0);
        camEditor.zoom = 0.85;

        createEnvironment();
        reloadCharacters();
        setupHUDPreview();
        setupWindows();
        buildCharacterPickerModal();

        pushUndoSnapshot();
        add(new EditorToast());
        FlxG.mouse.visible = true;
    }

    override public function setupCameras():Void {
        camEditor = new FlxCamera();
        camUI = new FlxCamera();
        camUI.bgColor = FlxColor.TRANSPARENT;

        FlxG.cameras.reset(camEditor);
        FlxG.cameras.add(camUI, false);
        FlxG.cameras.setDefaultDrawTarget(camEditor, true);
    }

    private function createEnvironment():Void {
        var bgGrid = new FlxSprite().makeGraphic(Std.int(FlxG.width * 4), Std.int(FlxG.height * 4), EditorTheme.BG_DARK);
        bgGrid.screenCenter();
        bgGrid.scrollFactor.set(0, 0);
        add(bgGrid);

        stageBackdrop = new FlxSprite(-200, -100);
        loadStageGraphic(curStageBackdrop);
        stageBackdrop.scrollFactor.set(0.9, 0.9);
        stageBackdrop.alpha = 0.4;
        add(stageBackdrop);

        groundGrid = new FlxSprite(0, FlxG.height * 0.78).makeGraphic(Std.int(FlxG.width * 4), 3, EditorTheme.ACCENT_PURPLE);
        groundGrid.screenCenter(X);
        groundGrid.scrollFactor.set(1, 1);
        add(groundGrid);

        crosshair = new FlxSprite().makeGraphic(24, 24, FlxColor.TRANSPARENT);
        for (i in 0...24) {
            crosshair.pixels.setPixel32(i, 12, EditorTheme.ACCENT_MAGENTA);
            crosshair.pixels.setPixel32(12, i, EditorTheme.ACCENT_MAGENTA);
        }
        crosshair.dirty = true;
        crosshair.scrollFactor.set(1, 1);
        add(crosshair);

        camFollowMarker = new FlxSprite().makeGraphic(20, 20, EditorTheme.ACCENT_CYAN);
        camFollowMarker.scrollFactor.set(1, 1);
        add(camFollowMarker);
    }

    private function loadStageGraphic(stage:String):Void {
        var path = 'stages/default/stageback';
        switch (stage) {
            case "spooky": path = 'halloween_bg';
            case "philly": path = 'philly/city';
            case "limo": path = 'limo/limoSunset';
            case "mall": path = 'christmas/bgWalls';
            case "school": path = 'weeb/weebTrees';
            case "tank": path = 'tank/tankSky';
            default: path = 'stages/default/stageback';
        }
        AssetHelper.loadGraphicSafely(stageBackdrop, path);
        stageBackdrop.updateHitbox();
    }

    private function reloadCharacters():Void {
        if (ghostChar != null) { 
            remove(ghostChar, true); 
            ghostChar.destroy(); 
        }
        if (charLayer != null) { 
            remove(charLayer, true); 
            charLayer.destroy(); 
        }

        try {
            ghostChar = new Character(FlxG.width * 0.5 - 150, FlxG.height * 0.18, curCharacter, isPlayer);
        } catch (e:Dynamic) {
            ghostChar = new Character(FlxG.width * 0.5 - 150, FlxG.height * 0.18, "dad", isPlayer);
        }
        ghostChar.alpha = showGhost ? 0.35 : 0.0;
        ghostChar.color = EditorTheme.ACCENT_PURPLE;
        add(ghostChar);

        try {
            charLayer = new Character(FlxG.width * 0.5 - 150, FlxG.height * 0.18, curCharacter, isPlayer);
        } catch (e:Dynamic) {
            charLayer = new Character(FlxG.width * 0.5 - 150, FlxG.height * 0.18, "dad", isPlayer);
        }
        add(charLayer);

        animList = [];
        if (charLayer != null && charLayer.animation != null) {
            @:privateAccess
            if (charLayer.animation._animations != null) {
                for (key in charLayer.animation._animations.keys()) animList.push(key);
            }
        }
        if (animList.length == 0) animList = ["idle", "singUP", "singRIGHT", "singDOWN", "singLEFT"];

        curAnimIndex = 0;
        ghostAnimIndex = 0;
        playCurrentAnim();
        updateHealthColors();
    }

    private function setupHUDPreview():Void {
        previewHealthBarBG = new FlxSprite(FlxG.width * 0.5 - 200, FlxG.height - 55).makeGraphic(400, 18, 0xFF000000);
        previewHealthBarBG.cameras = [camUI];
        previewHealthBarBG.scrollFactor.set();
        add(previewHealthBarBG);

        var healthBarCol:FlxColor = (charLayer != null) ? charLayer.healthColor : 0xFF66FF33;
        previewHealthBar = new FlxBar(previewHealthBarBG.x + 2, previewHealthBarBG.y + 2, RIGHT_TO_LEFT, 396, 14);
        previewHealthBar.createFilledBar(0xFFFF0000, healthBarCol);
        previewHealthBar.cameras = [camUI];
        previewHealthBar.scrollFactor.set();
        add(previewHealthBar);

        var iconKey:String = (charLayer != null && charLayer.healthIcon != null) ? charLayer.healthIcon : "face";
        previewIcon = new HealthIcon(iconKey, isPlayer);
        previewIcon.cameras = [camUI];
        previewIcon.setPosition(previewHealthBar.x + (previewHealthBar.width * 0.5) - 40, previewHealthBar.y - 45);
        add(previewIcon);
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar('ACTOR STUDIO ULTRA // [${curCharacter.toUpperCase()}]');
        topBar.cameras = [camUI];
        topBar.addAction("Save (Ctrl+S)", saveOffsetsJson);
        topBar.addAction("Save .xmsoul", saveOffsetsXMSoul);
        topBar.addAction("Actors", function() charPickerModal.visible = !charPickerModal.visible);
        topBar.addAction("Colors", function() colorPickerWindow.visible = !colorPickerWindow.visible);
        topBar.addAction("Reset View", function() {
            if (charLayer != null) {
                camFollow.set(charLayer.getMidpoint().x, charLayer.getMidpoint().y);
                camEditor.zoom = 0.85;
            }
        });
        topBar.addAction("Exit (Esc)", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        // --- 1. Animation Matrix Panel (Left Top) ---
        animMatrixWindow = new EditorWindow(15, 45, 290, 420, "Animation Matrix");
        animMatrixWindow.cameras = [camUI];
        add(animMatrixWindow);

        curAnimTxt = new FlxText(10, 4, 270, "Anim: idle", 15);
        curAnimTxt.setFormat(Paths.font("vcr"), 15, EditorTheme.ACCENT_CYAN, LEFT);
        animMatrixWindow.addElement(curAnimTxt);

        offsetTxt = new FlxText(10, 26, 270, "Offset: [0, 0]", 13);
        offsetTxt.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_MUTED, LEFT);
        animMatrixWindow.addElement(offsetTxt);

        frameInfoTxt = new FlxText(10, 46, 270, "Frame: 0/0", 11);
        frameInfoTxt.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);
        animMatrixWindow.addElement(frameInfoTxt);

        animListTxt = new FlxText(10, 68, 270, "", 12);
        animListTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        animMatrixWindow.addElement(animListTxt);

        var btnAddAnim = new EditorButton(10, 345, 130, 26, "+ Add Anim", function() {
            newAnimWindow.visible = !newAnimWindow.visible;
        });
        animMatrixWindow.addElement(btnAddAnim);

        var btnDelAnim = new EditorButton(150, 345, 130, 26, "- Remove", removeCurrentAnimation);
        animMatrixWindow.addElement(btnDelAnim);

        var btnAlignIdle = new EditorButton(10, 380, 270, 26, "Align All to Idle Baseline", alignAllToIdle);
        animMatrixWindow.addElement(btnAlignIdle);

        // --- 2. Actor Settings Window (Right Top) ---
        propertiesWindow = new EditorWindow(FlxG.width - 305, 45, 290, 310, "Actor Settings");
        propertiesWindow.cameras = [camUI];
        add(propertiesWindow);

        var currentScale:Float = (charLayer != null && charLayer.scale != null) ? charLayer.scale.x : 1.0;
        var stepperScale = new EditorNumericStepper(10, 8, 270, "Scale Multiplier", currentScale, 0.1, 8.0, 0.05, 2, function(v) {
            pushUndoSnapshot();
            if (charLayer != null) {
                charLayer.scale.set(v, v);
                charLayer.updateHitbox();
            }
            if (ghostChar != null) {
                ghostChar.scale.set(v, v);
                ghostChar.updateHitbox();
            }
            updateCrosshair();
        });
        propertiesWindow.addElement(stepperScale);

        var currentSing:Float = (charLayer != null) ? charLayer.singDuration : 4.0;
        var stepperSing = new EditorNumericStepper(10, 46, 270, "Sing Hold Duration", currentSing, 0.5, 16.0, 0.5, 1, function(v) {
            pushUndoSnapshot();
            if (charLayer != null) charLayer.singDuration = v;
        });
        propertiesWindow.addElement(stepperSing);

        var curIconName:String = (charLayer != null && charLayer.healthIcon != null) ? charLayer.healthIcon : "face";
        inputHealthIcon = new EditorInputText(10, 86, 270, "Health Icon Key", curIconName, function(t) {
            if (previewIcon != null && t.trim().length > 0) previewIcon.changeIcon(t.trim());
        });
        propertiesWindow.addElement(inputHealthIcon);

        var checkGhost = new EditorCheckbox(10, 132, "Ghost Overlay (G)", showGhost, function(c) {
            showGhost = c;
            if (ghostChar != null) ghostChar.alpha = showGhost ? 0.35 : 0.0;
        });
        propertiesWindow.addElement(checkGhost);

        var isFlipped:Bool = (charLayer != null) ? charLayer.flipX : false;
        var checkFlip = new EditorCheckbox(150, 132, "Flip X Axis", isFlipped, function(c) {
            pushUndoSnapshot();
            if (charLayer != null) charLayer.flipX = c;
            if (ghostChar != null) ghostChar.flipX = c;
        });
        propertiesWindow.addElement(checkFlip);

        var isPlayerCheck = new EditorCheckbox(10, 162, "Player Orientation", isPlayer, function(c) {
            pushUndoSnapshot();
            isPlayer = c;
            reloadCharacters();
        });
        propertiesWindow.addElement(isPlayerCheck);

        var btnCycleStage = new EditorButton(10, 196, 270, 26, "Stage Backdrop: " + curStageBackdrop, function() {
            curStageIdx = (curStageIdx + 1) % availableStages.length;
            curStageBackdrop = availableStages[curStageIdx];
            loadStageGraphic(curStageBackdrop);
            EditorToast.show('Stage Backdrop: $curStageBackdrop');
        });
        propertiesWindow.addElement(btnCycleStage);

        // --- 3. Camera Focus Anchor Window (Right Bottom) ---
        offsetsWindow = new EditorWindow(FlxG.width - 305, 365, 290, 140, "Camera Focus Anchor");
        offsetsWindow.cameras = [camUI];
        add(offsetsWindow);

        var camXVal:Float = (charLayer != null && charLayer.cameraOffset != null && charLayer.cameraOffset.length > 0) ? charLayer.cameraOffset[0] : 0.0;
        var stepperCamX = new EditorNumericStepper(10, 8, 270, "Cam Offset X", camXVal, -900, 900, 5.0, 1, function(v) {
            pushUndoSnapshot();
            if (charLayer != null && charLayer.cameraOffset != null) charLayer.cameraOffset[0] = v;
            updateCrosshair();
        });
        offsetsWindow.addElement(stepperCamX);

        var camYVal:Float = (charLayer != null && charLayer.cameraOffset != null && charLayer.cameraOffset.length > 1) ? charLayer.cameraOffset[1] : 0.0;
        var stepperCamY = new EditorNumericStepper(10, 46, 270, "Cam Offset Y", camYVal, -900, 900, 5.0, 1, function(v) {
            pushUndoSnapshot();
            if (charLayer != null && charLayer.cameraOffset != null) charLayer.cameraOffset[1] = v;
            updateCrosshair();
        });
        offsetsWindow.addElement(stepperCamY);

        // --- 4. RGB Health Color Picker (Toggleable Center Modal) ---
        colorPickerWindow = new EditorWindow((FlxG.width - 300) * 0.5, 90, 300, 240, "Health Bar RGB Color Picker");
        colorPickerWindow.cameras = [camUI];
        colorPickerWindow.visible = false;
        add(colorPickerWindow);

        colorPreviewBox = new FlxSprite(10, 6).makeGraphic(280, 30, (charLayer != null) ? charLayer.healthColor : 0xFF66FF33);
        colorPickerWindow.addElement(colorPreviewBox);

        var initialR = charLayer != null ? charLayer.healthColor.red : 255;
        var initialG = charLayer != null ? charLayer.healthColor.green : 255;
        var initialB = charLayer != null ? charLayer.healthColor.blue : 255;

        stepperColorR = new EditorNumericStepper(10, 44, 280, "Red (0-255)", initialR, 0, 255, 5, 0, function(v) {
            applyHealthColorFromSteppers();
        });
        colorPickerWindow.addElement(stepperColorR);

        stepperColorG = new EditorNumericStepper(10, 82, 280, "Green (0-255)", initialG, 0, 255, 5, 0, function(v) {
            applyHealthColorFromSteppers();
        });
        colorPickerWindow.addElement(stepperColorG);

        stepperColorB = new EditorNumericStepper(10, 120, 280, "Blue (0-255)", initialB, 0, 255, 5, 0, function(v) {
            applyHealthColorFromSteppers();
        });
        colorPickerWindow.addElement(stepperColorB);

        var btnCloseColor = new EditorButton(10, 165, 280, 26, "Done & Apply Colors", function() {
            colorPickerWindow.visible = false;
        });
        colorPickerWindow.addElement(btnCloseColor);

        // --- 5. Add Animation Node Window ---
        newAnimWindow = new EditorWindow((FlxG.width - 320) * 0.5, (FlxG.height - 240) * 0.5, 320, 240, "Create Animation Node");
        newAnimWindow.cameras = [camUI];
        newAnimWindow.visible = false;
        add(newAnimWindow);

        inputAnimName = new EditorInputText(10, 4, 300, "Animation Key (e.g. singUP)", "singUP");
        newAnimWindow.addElement(inputAnimName);

        inputAnimPrefix = new EditorInputText(10, 48, 300, "Sparrow Prefix (XML)", "Dad Sing Note UP");
        newAnimWindow.addElement(inputAnimPrefix);

        stepperAnimFPS = new EditorNumericStepper(10, 92, 140, "Frame Rate", 24, 1, 60, 1, 0);
        newAnimWindow.addElement(stepperAnimFPS);

        checkAnimLoop = new EditorCheckbox(170, 110, "Looping", false);
        newAnimWindow.addElement(checkAnimLoop);

        var btnSubmitAnim = new EditorButton(10, 155, 300, 28, "Inject Animation", function() {
            if (inputAnimName.text.trim().length > 0 && inputAnimPrefix.text.trim().length > 0) {
                var animKey = inputAnimName.text.trim();
                pushUndoSnapshot();
                if (charLayer != null && charLayer.animation != null) {
                    charLayer.animation.addByPrefix(animKey, inputAnimPrefix.text.trim(), Std.int(stepperAnimFPS.value), checkAnimLoop.checked);
                    charLayer.addOffset(animKey, 0, 0);
                }
                if (!animList.contains(animKey)) animList.push(animKey);
                curAnimIndex = animList.indexOf(animKey);
                playCurrentAnim();
                newAnimWindow.visible = false;
                EditorToast.show('Injected animation: $animKey');
            }
        });
        newAnimWindow.addElement(btnSubmitAnim);

        updateHUDText();
        updateCrosshair();
    }

    private function buildCharacterPickerModal():Void {
        charPickerModal = new EditorWindow((FlxG.width - 440) * 0.5, (FlxG.height - 480) * 0.5, 440, 480, "Character Asset Library");
        charPickerModal.cameras = [camUI];
        charPickerModal.visible = false;
        add(charPickerModal);

        var charactersFound:Array<String> = [];
        #if sys
        var charDirs = ["assets/data/characters", "assets/preload/data/characters", "data/characters"];
        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) charDirs.unshift('mods/$m/data/characters');
        }

        for (dir in charDirs) {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                for (file in FileSystem.readDirectory(dir)) {
                    if (file.endsWith(".json")) {
                        var id = file.substr(0, file.length - 5);
                        if (!charactersFound.contains(id)) charactersFound.push(id);
                    }
                }
            }
        }
        #end
        if (!charactersFound.contains("dad")) charactersFound.push("dad");
        if (!charactersFound.contains("bf")) charactersFound.push("bf");

        var listTxt = new FlxText(10, 6, 420, "AVAILABLE CHARACTERS:", 12);
        listTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_CYAN, LEFT);
        charPickerModal.addElement(listTxt);

        for (i in 0...Std.int(Math.min(8, charactersFound.length))) {
            var c = charactersFound[i];
            var btn = new EditorButton(10, 30 + (i * 34), 420, 28, c.toUpperCase(), function() {
                curCharacter = c;
                reloadCharacters();
                charPickerModal.visible = false;
                EditorToast.show('Loaded character: $c');
            });
            charPickerModal.addElement(btn);
        }

        var btnClose = new EditorButton(10, 410, 420, 28, "Close Library", function() {
            charPickerModal.visible = false;
        });
        charPickerModal.addElement(btnClose);
    }

    private function applyHealthColorFromSteppers():Void {
        if (stepperColorR == null || stepperColorG == null || stepperColorB == null) return;
        var r = Std.int(stepperColorR.value);
        var g = Std.int(stepperColorG.value);
        var b = Std.int(stepperColorB.value);

        var newCol = FlxColor.fromRGB(r, g, b);
        if (charLayer != null) charLayer.healthColor = newCol;

        if (colorPreviewBox != null) colorPreviewBox.makeGraphic(280, 30, newCol);
        if (previewHealthBar != null) previewHealthBar.createFilledBar(0xFFFF0000, newCol);
    }

    private function updateHealthColors():Void {
        if (charLayer == null) return;
        var col = charLayer.healthColor;
        if (stepperColorR != null) stepperColorR.value = col.red;
        if (stepperColorG != null) stepperColorG.value = col.green;
        if (stepperColorB != null) stepperColorB.value = col.blue;
        if (colorPreviewBox != null) colorPreviewBox.makeGraphic(280, 30, col);
        if (previewHealthBar != null) previewHealthBar.createFilledBar(0xFFFF0000, col);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        handleCameraControls(elapsed);
        handleAnimationControls();
        handleOffsetControls();
        handleMouseDragControls();

        if (FlxG.keys.justPressed.G) cycleGhostAnimation();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveOffsetsJson();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z) undo();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Y) redo();
        if (FlxG.keys.justPressed.ESCAPE && !newAnimWindow.visible && !charPickerModal.visible) {
            MusicBeatState.switchState(new MainMenuState());
        }

        updateLiveHUDPreview();
    }

    private function handleCameraControls(elapsed:Float):Void {
        if (FlxG.keys.pressed.Q) camEditor.zoom += 0.8 * elapsed;
        if (FlxG.keys.pressed.E) camEditor.zoom = Math.max(0.2, camEditor.zoom - 0.8 * elapsed);

        var spd = FlxG.keys.pressed.SHIFT ? 1200.0 : 450.0;
        if (FlxG.keys.pressed.I) camFollow.y -= spd * elapsed;
        if (FlxG.keys.pressed.K) camFollow.y += spd * elapsed;
        if (FlxG.keys.pressed.J) camFollow.x -= spd * elapsed;
        if (FlxG.keys.pressed.L) camFollow.x += spd * elapsed;

        camEditor.focusOn(camFollow);
    }

    private function handleAnimationControls():Void {
        if (animList.length == 0 || newAnimWindow.visible || charPickerModal.visible) return;

        if (FlxG.keys.justPressed.W) {
            curAnimIndex = FlxMath.wrap(curAnimIndex - 1, 0, animList.length - 1);
            playCurrentAnim();
        }
        if (FlxG.keys.justPressed.S) {
            curAnimIndex = FlxMath.wrap(curAnimIndex + 1, 0, animList.length - 1);
            playCurrentAnim();
        }
        if (FlxG.keys.justPressed.SPACE) playCurrentAnim();

        if (FlxG.keys.justPressed.LBRACKET) stepAnimationFrame(-1);
        if (FlxG.keys.justPressed.RBRACKET) stepAnimationFrame(1);
    }

    private function handleOffsetControls():Void {
        if (charLayer == null || animList.length == 0 || curAnimIndex >= animList.length || newAnimWindow.visible || charPickerModal.visible) return;

        var anim = animList[curAnimIndex];
        var mult:Float = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
        var changed:Bool = false;

        var curOffset = charLayer.animOffsets.get(anim);
        if (curOffset == null) { 
            curOffset = [0.0, 0.0]; 
            charLayer.animOffsets.set(anim, curOffset); 
        }

        if (FlxG.keys.justPressed.LEFT) { curOffset[0] += mult; changed = true; }
        if (FlxG.keys.justPressed.RIGHT) { curOffset[0] -= mult; changed = true; }
        if (FlxG.keys.justPressed.UP) { curOffset[1] += mult; changed = true; }
        if (FlxG.keys.justPressed.DOWN) { curOffset[1] -= mult; changed = true; }

        if (changed) {
            charLayer.offset.set(curOffset[0], curOffset[1]);
            updateCrosshair();
            updateHUDText();
        }
    }

    private function handleMouseDragControls():Void {
        var worldMouse = FlxG.mouse.getWorldPosition(camEditor);

        if (FlxG.mouse.justPressed && camFollowMarker != null) {
            if (worldMouse.x >= camFollowMarker.x - 8 && worldMouse.x <= camFollowMarker.x + 28 &&
                worldMouse.y >= camFollowMarker.y - 8 && worldMouse.y <= camFollowMarker.y + 28) {
                isDraggingCamAnchor = true;
                pushUndoSnapshot();
            }
        }

        if (isDraggingCamAnchor && charLayer != null && charLayer.cameraOffset != null) {
            if (FlxG.mouse.pressed) {
                charLayer.cameraOffset[0] = Math.round(worldMouse.x - charLayer.getMidpoint().x);
                charLayer.cameraOffset[1] = Math.round(worldMouse.y - charLayer.getMidpoint().y);
                updateCrosshair();
            } else {
                isDraggingCamAnchor = false;
            }
        }

        if (FlxG.mouse.justPressedMiddle) {
            isDraggingCharOffset = true;
            pushUndoSnapshot();
            dragStartMouse.set(worldMouse.x, worldMouse.y);
            if (animList.length > 0 && curAnimIndex < animList.length && charLayer != null) {
                var anim = animList[curAnimIndex];
                var curOff = charLayer.animOffsets.get(anim);
                dragStartOffset.set(curOff != null ? curOff[0] : 0, curOff != null ? curOff[1] : 0);
            }
        }

        if (isDraggingCharOffset && charLayer != null && animList.length > 0 && curAnimIndex < animList.length) {
            if (FlxG.mouse.pressedMiddle) {
                var anim = animList[curAnimIndex];
                var dx = Math.round(dragStartMouse.x - worldMouse.x);
                var dy = Math.round(dragStartMouse.y - worldMouse.y);

                var newOffX = dragStartOffset.x + dx;
                var newOffY = dragStartOffset.y + dy;

                charLayer.addOffset(anim, newOffX, newOffY);
                charLayer.offset.set(newOffX, newOffY);
                updateCrosshair();
                updateHUDText();
            } else {
                isDraggingCharOffset = false;
            }
        }
    }

    private function cycleGhostAnimation():Void {
        if (animList.length == 0) return;
        ghostAnimIndex = (ghostAnimIndex + 1) % animList.length;
        var ghostAnim = animList[ghostAnimIndex];

        if (ghostChar != null) {
            ghostChar.playAnim(ghostAnim, true);
            var gOffset = ghostChar.animOffsets.get(ghostAnim);
            ghostChar.offset.set(gOffset != null ? gOffset[0] : 0, gOffset != null ? gOffset[1] : 0);
        }
        EditorToast.show('Ghost Overlay: $ghostAnim');
    }

    private function alignAllToIdle():Void {
        if (charLayer == null) return;
        var idleOff = charLayer.animOffsets.get("idle");
        if (idleOff == null) idleOff = [0.0, 0.0];

        pushUndoSnapshot();
        for (anim in animList) {
            if (anim != "idle") {
                charLayer.addOffset(anim, idleOff[0], idleOff[1]);
            }
        }
        playCurrentAnim();
        EditorToast.show("All animation offsets aligned to idle!");
    }

    private function stepAnimationFrame(delta:Int):Void {
        if (charLayer != null && charLayer.animation != null && charLayer.animation.curAnim != null) {
            charLayer.animation.curAnim.pause();
            var total = charLayer.animation.curAnim.numFrames;
            charLayer.animation.curAnim.curFrame = FlxMath.wrap(charLayer.animation.curAnim.curFrame + delta, 0, total - 1);
            if (frameInfoTxt != null) {
                frameInfoTxt.text = 'Frame: ${charLayer.animation.curAnim.curFrame + 1} / $total';
            }
        }
    }

    private function playCurrentAnim():Void {
        if (charLayer == null || animList.length == 0 || curAnimIndex >= animList.length) return;
        var anim = animList[curAnimIndex];
        charLayer.playAnim(anim, true);

        var curOffset = charLayer.animOffsets.get(anim);
        charLayer.offset.set(curOffset != null ? curOffset[0] : 0, curOffset != null ? curOffset[1] : 0);

        if (ghostChar != null && showGhost && ghostAnimIndex < animList.length) {
            var ghostAnim = animList[ghostAnimIndex];
            ghostChar.playAnim(ghostAnim, true);
            var gOffset = ghostChar.animOffsets.get(ghostAnim);
            ghostChar.offset.set(gOffset != null ? gOffset[0] : 0, gOffset != null ? gOffset[1] : 0);
        }

        if (frameInfoTxt != null && charLayer.animation != null && charLayer.animation.curAnim != null) {
            frameInfoTxt.text = 'Frame: ${charLayer.animation.curAnim.curFrame + 1} / ${charLayer.animation.curAnim.numFrames}';
        }

        updateCrosshair();
        updateHUDText();
    }

    private function removeCurrentAnimation():Void {
        if (animList.length <= 1) {
            EditorToast.show("Cannot remove the only remaining animation!", true);
            return;
        }
        pushUndoSnapshot();
        var anim = animList[curAnimIndex];
        animList.remove(anim);
        if (charLayer != null) charLayer.animOffsets.remove(anim);
        curAnimIndex = FlxMath.wrap(curAnimIndex, 0, animList.length - 1);
        playCurrentAnim();
        EditorToast.show('Removed animation: $anim');
    }

    private function pushUndoSnapshot():Void {
        var charJson = buildCharacterJsonObject();
        undoStack.push(Json.stringify(charJson));
        if (undoStack.length > MAX_UNDO_DEPTH) undoStack.shift();
        redoStack = [];
    }

    private function undo():Void {
        if (undoStack.length <= 1) {
            EditorToast.show("No more undos available.", true);
            return;
        }
        var current = undoStack.pop();
        redoStack.push(current);
        var prev = undoStack[undoStack.length - 1];
        applyCharacterJsonObject(Json.parse(prev));
        EditorToast.show("Undone action.");
    }

    private function redo():Void {
        if (redoStack.length == 0) {
            EditorToast.show("No redos available.", true);
            return;
        }
        var next = redoStack.pop();
        undoStack.push(next);
        applyCharacterJsonObject(Json.parse(next));
        EditorToast.show("Redone action.");
    }

    private function buildCharacterJsonObject():CharacterJson {
        var charJson:CharacterJson = {
            animations: [],
            image: 'characters/$curCharacter',
            scale: (charLayer != null && charLayer.scale != null) ? charLayer.scale.x : 1.0,
            sing_duration: (charLayer != null) ? charLayer.singDuration : 4.0,
            healthicon: (inputHealthIcon != null && inputHealthIcon.text.trim().length > 0) ? inputHealthIcon.text.trim() : ((charLayer != null && charLayer.healthIcon != null) ? charLayer.healthIcon : "face"),
            position: (charLayer != null && charLayer.positionOffset != null) ? charLayer.positionOffset : [0.0, 0.0],
            camera_position: (charLayer != null && charLayer.cameraOffset != null) ? charLayer.cameraOffset : [0.0, 0.0],
            flip_x: (charLayer != null) ? charLayer.flipX : false,
            no_antialiasing: (charLayer != null) ? !charLayer.antialiasing : false,
            healthbar_colors: (charLayer != null) ? [Std.int(charLayer.healthColor.red), Std.int(charLayer.healthColor.green), Std.int(charLayer.healthColor.blue)] : [255, 255, 255]
        };

        for (anim in animList) {
            var off = charLayer != null ? charLayer.animOffsets.get(anim) : null;
            charJson.animations.push({
                anim: anim,
                name: anim,
                fps: 24,
                loop: (anim == "idle"),
                offsets: off != null ? [off[0], off[1]] : [0.0, 0.0]
            });
        }
        return charJson;
    }

    private function applyCharacterJsonObject(json:CharacterJson):Void {
        if (charLayer == null || json == null) return;
        var s = (json.scale != null) ? json.scale : 1.0;
        charLayer.scale.set(s, s);
        charLayer.singDuration = (json.sing_duration != null) ? json.sing_duration : 4.0;
        charLayer.flipX = (json.flip_x == true);
        charLayer.cameraOffset = (json.camera_position != null) ? json.camera_position : [0.0, 0.0];

        if (json.healthbar_colors != null && json.healthbar_colors.length >= 3) {
            charLayer.healthColor = FlxColor.fromRGB(json.healthbar_colors[0], json.healthbar_colors[1], json.healthbar_colors[2]);
            updateHealthColors();
        }

        if (json.animations != null) {
            for (a in json.animations) {
                if (a != null && a.offsets != null && a.offsets.length >= 2) {
                    charLayer.addOffset(a.anim, a.offsets[0], a.offsets[1]);
                }
            }
        }
        playCurrentAnim();
    }

    private function updateLiveHUDPreview():Void {
        if (inputHealthIcon != null && inputHealthIcon.text.trim().length > 0) {
            var key = inputHealthIcon.text.trim();
            if (previewIcon != null && previewIcon.char != key) {
                previewIcon.changeIcon(key);
            }
        }
    }

    private function updateCrosshair():Void {
        if (charLayer != null && camFollowMarker != null) {
            crosshair.setPosition(charLayer.x, charLayer.y);
            var offX:Float = (charLayer.cameraOffset != null && charLayer.cameraOffset.length > 0) ? charLayer.cameraOffset[0] : 0.0;
            var offY:Float = (charLayer.cameraOffset != null && charLayer.cameraOffset.length > 1) ? charLayer.cameraOffset[1] : 0.0;

            camFollowMarker.setPosition(
                charLayer.getMidpoint().x + offX - 10,
                charLayer.getMidpoint().y + offY - 10
            );
        }
    }

    private function updateHUDText():Void {
        if (animList.length == 0 || curAnimIndex >= animList.length || charLayer == null) return;
        var anim = animList[curAnimIndex];
        if (curAnimTxt != null) {
            curAnimTxt.text = 'Anim: $anim (${curAnimIndex + 1}/${animList.length})';
        }

        var off = charLayer.animOffsets.get(anim);
        if (offsetTxt != null) {
            offsetTxt.text = off != null ? 'Offset: [${off[0]}, ${off[1]}]' : 'Offset: [0, 0]';
        }

        if (animListTxt != null) {
            var list = "";
            var start = Std.int(Math.max(0, curAnimIndex - 5));
            var end = Std.int(Math.min(animList.length, start + 11));

            for (i in start...end) {
                var name = animList[i];
                var aOff = charLayer.animOffsets.get(name);
                var str = aOff != null ? '[${aOff[0]}, ${aOff[1]}]' : '[0, 0]';
                list += (i == curAnimIndex ? '> $name: $str <\n' : '  $name: $str\n');
            }
            animListTxt.text = list;
        }
    }

    public function saveOffsetsXMSoul():Void {
        #if sys
        var targetDir = 'assets/data/characters';
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) {
            targetDir = 'mods/${ModManager.activeMods[0]}/data/characters';
        }
        var targetPath = '$targetDir/$curCharacter.xmsoul';

        var col = (charLayer != null) ? charLayer.healthColor : FlxColor.WHITE;
        var scaleVal = (charLayer != null && charLayer.scale != null) ? charLayer.scale.x : 1.0;
        var iconVal = (inputHealthIcon != null && inputHealthIcon.text.trim().length > 0) ? inputHealthIcon.text.trim() : "face";

        var xml = '<?xml version="1.0" encoding="utf-8"?>\n';
        xml += '<character name="$curCharacter" icon="$iconVal" scale="$scaleVal" singDuration="${charLayer.singDuration}" flipX="${charLayer.flipX}" healthColor="0xFF${col.toHexString(false)}">\n';
        xml += '    <camera offset="${charLayer.cameraOffset[0]},${charLayer.cameraOffset[1]}" />\n';
        xml += '    <animations>\n';

        for (anim in animList) {
            var off = charLayer.animOffsets.get(anim);
            var ox = off != null ? off[0] : 0.0;
            var oy = off != null ? off[1] : 0.0;
            xml += '        <anim name="$anim" prefix="$anim" fps="24" loop="${anim == "idle"}" x="$ox" y="$oy" />\n';
        }

        xml += '    </animations>\n</character>';

        try {
            if (!FileSystem.exists(targetDir)) FileSystem.createDirectory(targetDir);
            File.saveContent(targetPath, xml);
            EditorToast.show('Saved .xmsoul manifest: $curCharacter.xmsoul');
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            EditorToast.show("Failed writing .xmsoul manifest", true);
        }
        #end
    }

    private function saveOffsetsJson():Void {
        var charJson = buildCharacterJsonObject();
        var json = Json.stringify(charJson, "\t");

        #if sys
        var targetDir = 'assets/data/characters';
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) {
            targetDir = 'mods/${ModManager.activeMods[0]}/data/characters';
        }
        var targetFile = '$targetDir/$curCharacter.json';

        try {
            if (!FileSystem.exists(targetDir)) FileSystem.createDirectory(targetDir);
            File.saveContent(targetFile, json);
            EditorToast.show("Character JSON Saved Successfully!");
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            EditorToast.show("Save Failed!", true);
        }
        #else
        var ref = new FileReference();
        ref.save(json, '$curCharacter.json');
        EditorToast.show("Exported Character JSON!");
        #end
    }

    override public function destroy():Void {
        if (dragStartOffset != null) { dragStartOffset.put(); dragStartOffset = null; }
        if (dragStartMouse != null) { dragStartMouse.put(); dragStartMouse = null; }
        super.destroy();
    }
}