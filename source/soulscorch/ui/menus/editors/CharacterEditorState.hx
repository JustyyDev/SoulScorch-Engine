package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.actors.CharacterJson;
import soulscorch.gameplay.actors.HealthIcon;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.menus.editors.editorui.EditorButton;
import soulscorch.ui.menus.editors.editorui.EditorCheckbox;
import soulscorch.ui.menus.editors.editorui.EditorInputText;
import soulscorch.ui.menus.editors.editorui.EditorNumericStepper;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.editors.editorui.EditorToast;
import soulscorch.ui.menus.editors.editorui.EditorTopBar;
import soulscorch.ui.menus.editors.editorui.EditorWindow;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class CharacterEditorState extends MusicBeatState {
    public var curCharacter:String = "dad";
    public var isPlayer:Bool = false;

    private var camEditor:FlxCamera;

    private var charLayer:Character;
    private var ghostChar:Character;
    private var crosshair:FlxSprite;
    private var camFollowMarker:FlxSprite;
    private var camFollow:FlxPoint;

    // --- Live In-Game HUD Preview ---
    private var previewHealthBarBG:FlxSprite;
    private var previewHealthBar:FlxBar;
    private var previewIcon:HealthIcon;
    private var previewIconGhost:HealthIcon;

    // --- Windows & UI Components ---
    private var topBar:EditorTopBar;
    private var animMatrixWindow:EditorWindow;
    private var propertiesWindow:EditorWindow;
    private var offsetsWindow:EditorWindow;
    private var newAnimWindow:EditorWindow;
    private var quickToolsWindow:EditorWindow;

    private var curAnimTxt:FlxText;
    private var offsetTxt:FlxText;
    private var animListTxt:FlxText;
    private var frameInfoTxt:FlxText;

    private var inputAnimName:EditorInputText;
    private var inputAnimPrefix:EditorInputText;
    private var stepperAnimFPS:EditorNumericStepper;
    private var checkAnimLoop:EditorCheckbox;
    private var inputHealthIcon:EditorInputText;

    private var animList:Array<String> = [];
    private var curAnimIndex:Int = 0;
    private var ghostAnimIndex:Int = 0;
    private var showGhost:Bool = true;

    // --- Drag & Drop State ---
    private var isDraggingCamAnchor:Bool = false;
    private var isDraggingCharOffset:Bool = false;
    private var dragStartOffset:FlxPoint;
    private var dragStartMouse:FlxPoint;

    // --- Undo / Redo History Stack ---
    private var undoStack:Array<String> = [];
    private var redoStack:Array<String> = [];
    private static inline var MAX_UNDO_DEPTH:Int = 40;

    public function new(?char:String = "dad", ?isPlayer:Bool = false) {
        super();
        this.curCharacter = (char != null && char.trim().length > 0) ? char.trim() : "dad";
        this.isPlayer = isPlayer;
    }

    override public function create():Void {
        super.create();

        camEditor = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camEditor);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camEditor, true);

        camFollow = FlxPoint.get(FlxG.width * 0.5, FlxG.height * 0.5);
        dragStartOffset = FlxPoint.get(0, 0);
        dragStartMouse = FlxPoint.get(0, 0);
        camEditor.zoom = 0.9;

        var bg = new FlxSprite().makeGraphic(FlxG.width * 4, FlxG.height * 4, EditorTheme.BG_DARK);
        bg.screenCenter();
        bg.scrollFactor.set(0, 0);
        add(bg);

        // Stage baseline indicator
        var ground = new FlxSprite(0, FlxG.height * 0.75).makeGraphic(FlxG.width * 4, 2, EditorTheme.ACCENT_PURPLE);
        ground.screenCenter(X);
        ground.scrollFactor.set(1, 1);
        add(ground);

        crosshair = new FlxSprite().makeGraphic(22, 22, FlxColor.TRANSPARENT);
        for (i in 0...22) {
            crosshair.pixels.setPixel32(i, 11, EditorTheme.ACCENT_MAGENTA);
            crosshair.pixels.setPixel32(11, i, EditorTheme.ACCENT_MAGENTA);
        }
        crosshair.dirty = true;
        crosshair.scrollFactor.set(1, 1);
        add(crosshair);

        camFollowMarker = new FlxSprite().makeGraphic(18, 18, EditorTheme.ACCENT_CYAN);
        camFollowMarker.scrollFactor.set(1, 1);
        add(camFollowMarker);

        reloadCharacters();
        setupHUDPreview();
        setupWindows();

        pushUndoSnapshot();
        add(new EditorToast());
        FlxG.mouse.visible = true;
    }

    private function reloadCharacters():Void {
        if (ghostChar != null) { remove(ghostChar, true); ghostChar.destroy(); }
        if (charLayer != null) { remove(charLayer, true); charLayer.destroy(); }

        ghostChar = new Character(FlxG.width * 0.5 - 150, FlxG.height * 0.2, curCharacter, isPlayer);
        ghostChar.alpha = showGhost ? 0.35 : 0.0;
        ghostChar.color = EditorTheme.ACCENT_PURPLE;
        add(ghostChar);

        charLayer = new Character(FlxG.width * 0.5 - 150, FlxG.height * 0.2, curCharacter, isPlayer);
        add(charLayer);

        animList = [];
        if (charLayer.animation != null) {
            @:privateAccess
            for (key in charLayer.animation._animations.keys()) animList.push(key);
        }
        if (animList.length == 0) animList = ["idle", "singUP", "singRIGHT", "singDOWN", "singLEFT"];

        curAnimIndex = 0;
        ghostAnimIndex = 0;
        playCurrentAnim();
    }

    private function setupHUDPreview():Void {
        previewHealthBarBG = new FlxSprite(FlxG.width * 0.5 - 200, FlxG.height - 55).makeGraphic(400, 18, 0xFF000000);
        previewHealthBarBG.cameras = [camHUD];
        previewHealthBarBG.scrollFactor.set();
        add(previewHealthBarBG);

        previewHealthBar = new FlxBar(previewHealthBarBG.x + 2, previewHealthBarBG.y + 2, RIGHT_TO_LEFT, 396, 14);
        previewHealthBar.createFilledBar(0xFFFF0000, charLayer != null ? charLayer.healthColor : 0xFF66FF33);
        previewHealthBar.cameras = [camHUD];
        previewHealthBar.scrollFactor.set();
        add(previewHealthBar);

        previewIcon = new HealthIcon(charLayer != null ? charLayer.healthIcon : "face", isPlayer);
        previewIcon.cameras = [camHUD];
        previewIcon.setPosition(previewHealthBar.x + (previewHealthBar.width * 0.5) - 40, previewHealthBar.y - 45);
        add(previewIcon);
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar('ACTOR STUDIO PRO // [${curCharacter.toUpperCase()}]');
        topBar.cameras = [camHUD];
        topBar.addAction("Save (Ctrl+S)", saveOffsetsJson);
        topBar.addAction("Undo (Ctrl+Z)", undo);
        topBar.addAction("Redo (Ctrl+Y)", redo);
        topBar.addAction("Load Character", promptLoadCharacter);
        topBar.addAction("Reset View", function() {
            camFollow.set(charLayer.getMidpoint().x, charLayer.getMidpoint().y);
            camEditor.zoom = 0.9;
        });
        topBar.addAction("Exit", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        // --- 1. Animation Matrix Window ---
        animMatrixWindow = new EditorWindow(15, 45, 300, 420, "Animation Matrix");
        animMatrixWindow.cameras = [camHUD];
        add(animMatrixWindow);

        curAnimTxt = new FlxText(10, 4, 280, "Anim: idle", 16);
        curAnimTxt.setFormat(Paths.font("vcr"), 16, EditorTheme.ACCENT_CYAN, LEFT);
        animMatrixWindow.addElement(curAnimTxt);

        offsetTxt = new FlxText(10, 26, 280, "Offset: [0, 0]", 14);
        offsetTxt.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_MUTED, LEFT);
        animMatrixWindow.addElement(offsetTxt);

        frameInfoTxt = new FlxText(10, 48, 280, "Frame: 0/0", 12);
        frameInfoTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_MUTED, LEFT);
        animMatrixWindow.addElement(frameInfoTxt);

        animListTxt = new FlxText(10, 72, 280, "", 12);
        animListTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        animMatrixWindow.addElement(animListTxt);

        var btnAddAnim = new EditorButton(10, 345, 135, 26, "+ Add Anim", function() {
            newAnimWindow.visible = !newAnimWindow.visible;
        });
        animMatrixWindow.addElement(btnAddAnim);

        var btnDelAnim = new EditorButton(155, 345, 135, 26, "- Remove", removeCurrentAnimation);
        animMatrixWindow.addElement(btnDelAnim);

        // --- 2. Actor Settings Window ---
        propertiesWindow = new EditorWindow(FlxG.width - 325, 45, 310, 270, "Actor Settings");
        propertiesWindow.cameras = [camHUD];
        add(propertiesWindow);

        var stepperScale = new EditorNumericStepper(10, 8, 290, "Scale Multiplier", charLayer.scale.x, 0.1, 8.0, 0.05, 2, function(v) {
            pushUndoSnapshot();
            charLayer.scale.set(v, v);
            charLayer.updateHitbox();
            if (ghostChar != null) { ghostChar.scale.set(v, v); ghostChar.updateHitbox(); }
            updateCrosshair();
        });
        propertiesWindow.addElement(stepperScale);

        var stepperSing = new EditorNumericStepper(10, 44, 290, "Sing Hold Duration", charLayer.singDuration, 0.5, 16.0, 0.5, 1, function(v) {
            pushUndoSnapshot();
            charLayer.singDuration = v;
        });
        propertiesWindow.addElement(stepperSing);

        inputHealthIcon = new EditorInputText(10, 84, 290, "Health Icon Key", charLayer.healthIcon);
        propertiesWindow.addElement(inputHealthIcon);

        var checkGhost = new EditorCheckbox(10, 128, "Ghost Overlay (G)", showGhost, function(c) {
            showGhost = c;
            if (ghostChar != null) ghostChar.alpha = showGhost ? 0.35 : 0.0;
        });
        propertiesWindow.addElement(checkGhost);

        var checkFlip = new EditorCheckbox(160, 128, "Flip X Axis", charLayer.flipX, function(c) {
            pushUndoSnapshot();
            charLayer.flipX = c;
            if (ghostChar != null) ghostChar.flipX = c;
        });
        propertiesWindow.addElement(checkFlip);

        // --- 3. Camera Anchor Window ---
        offsetsWindow = new EditorWindow(FlxG.width - 325, 325, 310, 150, "Camera Focus Anchor");
        offsetsWindow.cameras = [camHUD];
        add(offsetsWindow);

        var stepperCamX = new EditorNumericStepper(10, 8, 290, "Cam Offset X", charLayer.cameraOffset[0], -900, 900, 5.0, 1, function(v) {
            pushUndoSnapshot();
            charLayer.cameraOffset[0] = v;
            updateCrosshair();
        });
        offsetsWindow.addElement(stepperCamX);

        var stepperCamY = new EditorNumericStepper(10, 44, 290, "Cam Offset Y", charLayer.cameraOffset[1], -900, 900, 5.0, 1, function(v) {
            pushUndoSnapshot();
            charLayer.cameraOffset[1] = v;
            updateCrosshair();
        });
        offsetsWindow.addElement(stepperCamY);

        // --- 4. Quick Auto-Align Tools Window ---
        quickToolsWindow = new EditorWindow(15, 475, 300, 135, "Quick Offset Helpers");
        quickToolsWindow.cameras = [camHUD];
        add(quickToolsWindow);

        var btnZeroOffset = new EditorButton(10, 8, 280, 26, "Reset Current Offset to [0, 0]", function() {
            var anim = animList[curAnimIndex];
            pushUndoSnapshot();
            charLayer.addOffset(anim, 0, 0);
            playCurrentAnim();
            EditorToast.show('Zeroed offset for: $anim');
        });
        quickToolsWindow.addElement(btnZeroOffset);

        var btnAlignToIdle = new EditorButton(10, 38, 280, 26, "Align All to Idle Baseline", alignAllToIdle);
        quickToolsWindow.addElement(btnAlignToIdle);

        // --- 5. New Animation Creator Window ---
        newAnimWindow = new EditorWindow((FlxG.width - 320) * 0.5, (FlxG.height - 240) * 0.5, 320, 240, "Create Animation Node");
        newAnimWindow.cameras = [camHUD];
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
                charLayer.animation.addByPrefix(animKey, inputAnimPrefix.text.trim(), Std.int(stepperAnimFPS.value), checkAnimLoop.checked);
                charLayer.addOffset(animKey, 0, 0);
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

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        handleCameraControls(elapsed);
        handleAnimationControls();
        handleOffsetControls();
        handleMouseDragControls();

        // Hotkeys
        if (FlxG.keys.justPressed.G) cycleGhostAnimation();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveOffsetsJson();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z) undo();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Y) redo();
        if (FlxG.keys.justPressed.ESCAPE && !newAnimWindow.visible) MusicBeatState.switchState(new MainMenuState());

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
        if (animList.length == 0 || newAnimWindow.visible) return;

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
        if (charLayer == null || animList.length == 0 || newAnimWindow.visible) return;

        var anim = animList[curAnimIndex];
        var mult:Float = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
        var changed:Bool = false;

        var curOffset = charLayer.animOffsets.get(anim);
        if (curOffset == null) { curOffset = [0.0, 0.0]; charLayer.animOffsets.set(anim, curOffset); }

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

        // 1. Camera Anchor Dragging (Left Click)
        if (FlxG.mouse.justPressed) {
            if (worldMouse.x >= camFollowMarker.x - 8 && worldMouse.x <= camFollowMarker.x + 26 &&
                worldMouse.y >= camFollowMarker.y - 8 && worldMouse.y <= camFollowMarker.y + 26) {
                isDraggingCamAnchor = true;
                pushUndoSnapshot();
            }
        }

        if (isDraggingCamAnchor) {
            if (FlxG.mouse.pressed) {
                charLayer.cameraOffset[0] = Math.round(worldMouse.x - charLayer.getMidpoint().x);
                charLayer.cameraOffset[1] = Math.round(worldMouse.y - charLayer.getMidpoint().y);
                updateCrosshair();
            } else {
                isDraggingCamAnchor = false;
            }
        }

        // 2. Middle-Click Real-Time Character Offset Dragging
        if (FlxG.mouse.justPressedMiddle) {
            isDraggingCharOffset = true;
            pushUndoSnapshot();
            dragStartMouse.set(worldMouse.x, worldMouse.y);
            var anim = animList[curAnimIndex];
            var curOff = charLayer.animOffsets.get(anim);
            dragStartOffset.set(curOff != null ? curOff[0] : 0, curOff != null ? curOff[1] : 0);
        }

        if (isDraggingCharOffset) {
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
        if (charLayer != null && charLayer.animation.curAnim != null) {
            charLayer.animation.curAnim.pause();
            var total = charLayer.animation.curAnim.numFrames;
            charLayer.animation.curAnim.curFrame = FlxMath.wrap(charLayer.animation.curAnim.curFrame + delta, 0, total - 1);
            frameInfoTxt.text = 'Frame: ${charLayer.animation.curAnim.curFrame + 1} / $total';
        }
    }

    private function playCurrentAnim():Void {
        if (charLayer == null || animList.length == 0) return;
        var anim = animList[curAnimIndex];
        charLayer.playAnim(anim, true);

        var curOffset = charLayer.animOffsets.get(anim);
        charLayer.offset.set(curOffset != null ? curOffset[0] : 0, curOffset != null ? curOffset[1] : 0);

        if (ghostChar != null && showGhost) {
            var ghostAnim = animList[ghostAnimIndex];
            ghostChar.playAnim(ghostAnim, true);
            var gOffset = ghostChar.animOffsets.get(ghostAnim);
            ghostChar.offset.set(gOffset != null ? gOffset[0] : 0, gOffset != null ? gOffset[1] : 0);
        }

        if (charLayer.animation.curAnim != null) {
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
        charLayer.animOffsets.remove(anim);
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
            scale: charLayer.scale.x,
            sing_duration: charLayer.singDuration,
            healthicon: inputHealthIcon != null && inputHealthIcon.text.trim().length > 0 ? inputHealthIcon.text.trim() : charLayer.healthIcon,
            position: charLayer.positionOffset,
            camera_position: charLayer.cameraOffset,
            flip_x: charLayer.flipX,
            no_antialiasing: !charLayer.antialiasing,
            healthbar_colors: [Std.int(charLayer.healthColor.red), Std.int(charLayer.healthColor.green), Std.int(charLayer.healthColor.blue)]
        };

        for (anim in animList) {
            var off = charLayer.animOffsets.get(anim);
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
        charLayer.scale.set(json.scale != null ? json.scale : 1.0, json.scale != null ? json.scale : 1.0);
        charLayer.singDuration = json.sing_duration != null ? json.sing_duration : 4.0;
        charLayer.flipX = json.flip_x == true;
        charLayer.cameraOffset = json.camera_position != null ? json.camera_position : [0.0, 0.0];

        if (json.animations != null) {
            for (a in json.animations) {
                if (a.offsets != null) charLayer.addOffset(a.anim, a.offsets[0], a.offsets[1]);
            }
        }
        playCurrentAnim();
    }

    private function updateLiveHUDPreview():Void {
        if (inputHealthIcon != null && inputHealthIcon.text.trim().length > 0) {
            var key = inputHealthIcon.text.trim();
            if (previewIcon != null && previewIcon.curIcon != key) {
                previewIcon.changeIcon(key);
            }
        }
    }

    private function promptLoadCharacter():Void {
        #if sys
        var charactersFound:Array<String> = [];
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

        if (charactersFound.length > 0) {
            var nextIdx = (charactersFound.indexOf(curCharacter) + 1) % charactersFound.length;
            curCharacter = charactersFound[nextIdx];
            reloadCharacters();
            setupWindows();
            EditorToast.show('Loaded character: $curCharacter');
        }
        #end
    }

    private function updateCrosshair():Void {
        if (charLayer != null) {
            crosshair.setPosition(charLayer.x, charLayer.y);
            camFollowMarker.setPosition(
                charLayer.getMidpoint().x + charLayer.cameraOffset[0] - 9,
                charLayer.getMidpoint().y + charLayer.cameraOffset[1] - 9
            );
        }
    }

    private function updateHUDText():Void {
        if (animList.length == 0) return;
        var anim = animList[curAnimIndex];
        curAnimTxt.text = 'Anim: $anim (${curAnimIndex + 1}/${animList.length})';

        var off = charLayer.animOffsets.get(anim);
        offsetTxt.text = off != null ? 'Offset: [${off[0]}, ${off[1]}]' : 'Offset: [0, 0]';

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