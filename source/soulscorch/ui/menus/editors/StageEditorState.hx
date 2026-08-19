package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.stage.StageJson;
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

enum SelectedTargetType {
    PIECE;
    BF_SPAWN;
    DAD_SPAWN;
    GF_SPAWN;
}

class StageEditorState extends MusicBeatState {
    public static var curStage:String = "stage";

    private var camStage:FlxCamera;
    private var camHUD:FlxCamera;
    private var camFollow:FlxPoint;

    private var stageData:StageJson;
    private var stagePiecesGroup:FlxSpriteGroup;
    private var pieceSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();

    private var dummyBF:Character;
    private var dummyDad:Character;
    private var dummyGF:Character;

    private var currentMode:SelectedTargetType = PIECE;
    private var curPieceIndex:Int = 0;
    private var pieceNames:Array<String> = [];

    // --- Windows & UI ---
    private var topBar:EditorTopBar;
    private var hierarchyWindow:EditorWindow;
    private var transformWindow:EditorWindow;
    private var stageSettingsWindow:EditorWindow;
    private var newPropWindow:EditorWindow;

    private var infoTxt:FlxText;
    private var listTxt:FlxText;
    private var targetMarker:FlxSprite;

    private var stepperPieceScaleX:EditorNumericStepper;
    private var stepperPieceScaleY:EditorNumericStepper;
    private var stepperScrollX:EditorNumericStepper;
    private var stepperScrollY:EditorNumericStepper;

    private var inputPropName:EditorInputText;
    private var inputPropImage:EditorInputText;

    private var isDraggingTarget:Bool = false;
    private var dragStartOffset:FlxPoint;

    public function new(?stageName:String = "stage") {
        super();
        if (stageName != null && stageName.trim().length > 0) curStage = stageName.trim();
    }

    override public function create():Void {
        super.create();

        camStage = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camStage);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camStage, true);

        camFollow = FlxPoint.get(FlxG.width * 0.5, FlxG.height * 0.5);
        dragStartOffset = FlxPoint.get(0, 0);

        var bgGrid = new FlxSprite().makeGraphic(FlxG.width * 4, FlxG.height * 4, EditorTheme.BG_DARK);
        bgGrid.screenCenter();
        bgGrid.scrollFactor.set(0, 0);
        add(bgGrid);

        var ground = new FlxSprite(0, FlxG.height * 0.85).makeGraphic(FlxG.width * 4, 2, EditorTheme.ACCENT_PURPLE);
        ground.screenCenter(X);
        ground.scrollFactor.set(1, 1);
        add(ground);

        loadStageData();

        stagePiecesGroup = new FlxSpriteGroup();
        add(stagePiecesGroup);
        buildStagePieces();

        spawnDummies();

        targetMarker = new FlxSprite().makeGraphic(24, 24, FlxColor.TRANSPARENT);
        for (i in 0...24) {
            targetMarker.pixels.setPixel32(i, 12, EditorTheme.ACCENT_MAGENTA);
            targetMarker.pixels.setPixel32(12, i, EditorTheme.ACCENT_MAGENTA);
        }
        targetMarker.dirty = true;
        targetMarker.scrollFactor.set(1, 1);
        add(targetMarker);

        setupWindows();
        updateHUD();

        add(new EditorToast());
        FlxG.mouse.visible = true;
    }

    private function loadStageData():Void {
        var candidates = [
            'stages/$curStage.json',
            'data/stages/$curStage.json',
            'assets/data/stages/$curStage.json',
            'assets/preload/data/stages/$curStage.json',
            'assets/preload/stages/$curStage.json'
        ];
        for (c in candidates) {
            var res = AssetResolver.resolveFile(c, [".json", ""]);
            if (res != null) {
                try {
                    stageData = cast Json.parse(AssetResolver.getText(res));
                    break;
                } catch (e:Dynamic) {}
            }
        }

        if (stageData == null) {
            stageData = {
                name: curStage,
                defaultZoom: 0.9,
                cameraSpeed: 1.0,
                hideGirlfriend: false,
                boyfriend: [770.0, 450.0],
                dad: [100.0, 100.0],
                girlfriend: [400.0, 130.0],
                pieces: [
                    {
                        name: "stageback",
                        image: "stages/default/stageback",
                        position: [-600.0, -200.0],
                        scroll: [0.9, 0.9],
                        scale: [1.0, 1.0],
                        layer: "background"
                    },
                    {
                        name: "stagefront",
                        image: "stages/default/stagefront",
                        position: [-650.0, 600.0],
                        scroll: [1.0, 1.0],
                        scale: [1.1, 1.1],
                        layer: "behindDad"
                    }
                ]
            };
        }
        camStage.zoom = (stageData.defaultZoom != null && stageData.defaultZoom > 0) ? stageData.defaultZoom : 0.9;
    }

    private function buildStagePieces():Void {
        stagePiecesGroup.clear();
        pieceSprites.clear();
        pieceNames = [];

        var list = stageData.pieces != null ? stageData.pieces : stageData.sprites;
        if (list != null) {
            for (p in list) {
                var pName = (p.id != null) ? p.id : ((p.name != null) ? p.name : "piece_" + pieceNames.length);
                var posX = p.position != null && p.position.length > 0 ? p.position[0] : (p.x != null ? p.x : 0.0);
                var posY = p.position != null && p.position.length > 1 ? p.position[1] : (p.y != null ? p.y : 0.0);

                var spr = new FlxSprite(posX, posY);
                if (!AssetHelper.loadGraphicSafely(spr, p.image)) {
                    spr.makeGraphic(400, 300, EditorTheme.PANEL_BORDER);
                }

                spr.scrollFactor.set(p.scroll != null ? p.scroll[0] : 1.0, p.scroll != null ? p.scroll[1] : 1.0);
                spr.scale.set(p.scale != null ? p.scale[0] : 1.0, p.scale != null ? p.scale[1] : 1.0);
                spr.updateHitbox();
                spr.antialiasing = (p.antialiasing != null) ? p.antialiasing : true;

                pieceSprites.set(pName, spr);
                pieceNames.push(pName);
                stagePiecesGroup.add(spr);
            }
        }
    }

    private function spawnDummies():Void {
        if (dummyGF != null) { remove(dummyGF, true); dummyGF.destroy(); }
        if (dummyDad != null) { remove(dummyDad, true); dummyDad.destroy(); }
        if (dummyBF != null) { remove(dummyBF, true); dummyBF.destroy(); }

        var gfPos = getSpawnPos(stageData.girlfriend != null ? stageData.girlfriend : stageData.gf, [400.0, 130.0]);
        var dadPos = getSpawnPos(stageData.dad != null ? stageData.dad : stageData.opponent, [100.0, 100.0]);
        var bfPos = getSpawnPos(stageData.boyfriend != null ? stageData.boyfriend : stageData.player, [770.0, 450.0]);

        dummyGF = new Character(gfPos[0], gfPos[1], "gf", false);
        dummyDad = new Character(dadPos[0], dadPos[1], "dad", false);
        dummyBF = new Character(bfPos[0], bfPos[1], "bf", true);

        dummyGF.alpha = 0.85; dummyDad.alpha = 0.85; dummyBF.alpha = 0.85;
        dummyGF.visible = !(stageData.hideGirlfriend == true || stageData.hide_girlfriend == true);

        add(dummyGF);
        add(dummyDad);
        add(dummyBF);
    }

    private function getSpawnPos(raw:Dynamic, fallback:Array<Float>):Array<Float> {
        if (raw == null) return fallback;
        if (Std.isOfType(raw, Array)) {
            var a:Array<Dynamic> = cast raw;
            if (a.length >= 2) return [Std.parseFloat(Std.string(a[0])), Std.parseFloat(Std.string(a[1]))];
        } else if (Reflect.isObject(raw)) {
            if (Reflect.hasField(raw, "position")) {
                var p:Array<Dynamic> = cast Reflect.field(raw, "position");
                if (p != null && p.length >= 2) return [Std.parseFloat(Std.string(p[0])), Std.parseFloat(Std.string(p[1]))];
            } else if (Reflect.hasField(raw, "x") && Reflect.hasField(raw, "y")) {
                return [Std.parseFloat(Std.string(Reflect.field(raw, "x"))), Std.parseFloat(Std.string(Reflect.field(raw, "y")))];
            }
        }
        return fallback;
    }

    private function setSpawnPos(target:Dynamic, x:Float, y:Float):Void {
        if (Std.isOfType(target, Array)) {
            var a:Array<Float> = cast target;
            a[0] = x;
            a[1] = y;
        } else if (Reflect.isObject(target)) {
            if (Reflect.hasField(target, "position")) {
                var p:Array<Float> = cast Reflect.field(target, "position");
                p[0] = x;
                p[1] = y;
            } else {
                Reflect.setField(target, "x", x);
                Reflect.setField(target, "y", y);
            }
        }
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar('STAGE ARCHITECT // [${curStage.toUpperCase()}]');
        topBar.cameras = [camHUD];
        topBar.addAction("Save (Ctrl+S)", saveStageJson);
        topBar.addAction("Cycle Stage", promptCycleStage);
        topBar.addAction("Reset Camera", function() {
            camFollow.set(dummyBF.getMidpoint().x, dummyBF.getMidpoint().y);
            camStage.zoom = stageData.defaultZoom;
        });
        topBar.addAction("Exit", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        // --- 1. Hierarchy & Selection Window ---
        hierarchyWindow = new EditorWindow(15, 45, 300, 390, "Stage Tree & Pieces");
        hierarchyWindow.cameras = [camHUD];
        add(hierarchyWindow);

        infoTxt = new FlxText(10, 4, 280, "", 14);
        infoTxt.setFormat(Paths.font("vcr"), 14, EditorTheme.ACCENT_CYAN, LEFT);
        hierarchyWindow.addElement(infoTxt);

        listTxt = new FlxText(10, 48, 280, "", 12);
        listTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        hierarchyWindow.addElement(listTxt);

        var btnAddProp = new EditorButton(10, 320, 135, 26, "+ Add Prop", function() {
            newPropWindow.visible = !newPropWindow.visible;
        });
        hierarchyWindow.addElement(btnAddProp);

        var btnDelProp = new EditorButton(155, 320, 135, 26, "- Remove", removeCurrentPiece);
        hierarchyWindow.addElement(btnDelProp);

        // --- 2. Piece Transformation Window ---
        transformWindow = new EditorWindow(FlxG.width - 325, 45, 310, 220, "Transform & Parallax");
        transformWindow.cameras = [camHUD];
        add(transformWindow);

        stepperPieceScaleX = new EditorNumericStepper(10, 8, 135, "Scale X", 1.0, 0.05, 10.0, 0.05, 2, function(v) {
            updateCurrentPieceScale(v, true);
        });
        transformWindow.addElement(stepperPieceScaleX);

        stepperPieceScaleY = new EditorNumericStepper(160, 8, 135, "Scale Y", 1.0, 0.05, 10.0, 0.05, 2, function(v) {
            updateCurrentPieceScale(v, false);
        });
        transformWindow.addElement(stepperPieceScaleY);

        stepperScrollX = new EditorNumericStepper(10, 44, 135, "Scroll X", 1.0, 0.0, 3.0, 0.05, 2, function(v) {
            updateCurrentPieceScroll(v, true);
        });
        transformWindow.addElement(stepperScrollX);

        stepperScrollY = new EditorNumericStepper(160, 44, 135, "Scroll Y", 1.0, 0.0, 3.0, 0.05, 2, function(v) {
            updateCurrentPieceScroll(v, false);
        });
        transformWindow.addElement(stepperScrollY);

        // --- 3. Stage Global Properties Window ---
        stageSettingsWindow = new EditorWindow(FlxG.width - 325, 275, 310, 180, "Global Environment");
        stageSettingsWindow.cameras = [camHUD];
        add(stageSettingsWindow);

        var stepperZoom = new EditorNumericStepper(10, 8, 290, "Default Camera Zoom", stageData.defaultZoom != null ? stageData.defaultZoom : 0.9, 0.2, 3.0, 0.05, 2, function(v) {
            stageData.defaultZoom = v;
            camStage.zoom = v;
            updateHUD();
        });
        stageSettingsWindow.addElement(stepperZoom);

        var checkGF = new EditorCheckbox(10, 48, "Hide Girlfriend", stageData.hideGirlfriend == true, function(c) {
            stageData.hideGirlfriend = c;
            if (dummyGF != null) dummyGF.visible = !c;
        });
        stageSettingsWindow.addElement(checkGF);

        // --- 4. Add Prop Creation Window ---
        newPropWindow = new EditorWindow((FlxG.width - 320) * 0.5, (FlxG.height - 200) * 0.5, 320, 200, "Inject Stage Prop");
        newPropWindow.cameras = [camHUD];
        newPropWindow.visible = false;
        add(newPropWindow);

        inputPropName = new EditorInputText(10, 4, 300, "Prop ID (e.g. stageback)", "stageback");
        newPropWindow.addElement(inputPropName);

        inputPropImage = new EditorInputText(10, 48, 300, "Asset Path (images/)", "stages/default/stageback");
        newPropWindow.addElement(inputPropImage);

        var btnSubmitProp = new EditorButton(10, 120, 300, 28, "Place on Stage", function() {
            var pId = inputPropName.text.trim();
            var pImg = inputPropImage.text.trim();

            if (pId.length > 0 && pImg.length > 0) {
                var newPiece = {
                    name: pId,
                    image: pImg,
                    position: [0.0, 0.0],
                    scroll: [1.0, 1.0],
                    scale: [1.0, 1.0],
                    layer: "background"
                };
                if (stageData.pieces == null) stageData.pieces = [];
                stageData.pieces.push(newPiece);

                buildStagePieces();
                currentMode = PIECE;
                curPieceIndex = pieceNames.indexOf(pId);
                newPropWindow.visible = false;
                updateHUD();
                EditorToast.show('Injected prop: $pId');
            }
        });
        newPropWindow.addElement(btnSubmitProp);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        handleCameraControls(elapsed);
        handleSelectionInput();
        handleTransformInput();
        handleMouseDragTarget();

        // Hotkey camera focuses
        if (FlxG.keys.justPressed.ONE) camFollow.set(dummyBF.getMidpoint().x, dummyBF.getMidpoint().y);
        if (FlxG.keys.justPressed.TWO) camFollow.set(dummyDad.getMidpoint().x, dummyDad.getMidpoint().y);
        if (FlxG.keys.justPressed.THREE) camFollow.set(dummyGF.getMidpoint().x, dummyGF.getMidpoint().y);

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveStageJson();
        if (FlxG.keys.justPressed.ESCAPE && !newPropWindow.visible) MusicBeatState.switchState(new MainMenuState());
    }

    private function handleCameraControls(elapsed:Float):Void {
        if (FlxG.keys.pressed.Q) camStage.zoom += 0.8 * elapsed;
        if (FlxG.keys.pressed.E) camStage.zoom = Math.max(0.15, camStage.zoom - 0.8 * elapsed);

        var spd = FlxG.keys.pressed.SHIFT ? 1400.0 : 550.0;
        if (FlxG.keys.pressed.I) camFollow.y -= spd * elapsed;
        if (FlxG.keys.pressed.K) camFollow.y += spd * elapsed;
        if (FlxG.keys.pressed.J) camFollow.x -= spd * elapsed;
        if (FlxG.keys.pressed.L) camFollow.x += spd * elapsed;

        camStage.focusOn(camFollow);
    }

    private function handleSelectionInput():Void {
        if (newPropWindow.visible) return;

        if (FlxG.keys.justPressed.TAB) {
            currentMode = switch (currentMode) {
                case PIECE: BF_SPAWN;
                case BF_SPAWN: DAD_SPAWN;
                case DAD_SPAWN: GF_SPAWN;
                case GF_SPAWN: PIECE;
            };
            updateHUD();
        }

        if (currentMode == PIECE && pieceNames.length > 0) {
            if (FlxG.keys.justPressed.W) {
                curPieceIndex = FlxMath.wrap(curPieceIndex - 1, 0, pieceNames.length - 1);
                updateHUD();
            }
            if (FlxG.keys.justPressed.S) {
                curPieceIndex = FlxMath.wrap(curPieceIndex + 1, 0, pieceNames.length - 1);
                updateHUD();
            }
        }
    }

    private function handleTransformInput():Void {
        if (newPropWindow.visible) return;

        var mult = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
        var dx:Float = 0;
        var dy:Float = 0;

        if (FlxG.keys.justPressed.LEFT) dx -= mult;
        if (FlxG.keys.justPressed.RIGHT) dx += mult;
        if (FlxG.keys.justPressed.UP) dy -= mult;
        if (FlxG.keys.justPressed.DOWN) dy += mult;

        if (dx == 0 && dy == 0) return;

        applyDeltaToCurrentTarget(dx, dy);
    }

    private function handleMouseDragTarget():Void {
        var worldMouse = FlxG.mouse.getWorldPosition(camStage);

        if (FlxG.mouse.justPressed && !newPropWindow.visible) {
            if (worldMouse.x >= targetMarker.x - 12 && worldMouse.x <= targetMarker.x + 36 &&
                worldMouse.y >= targetMarker.y - 12 && worldMouse.y <= targetMarker.y + 36) {
                isDraggingTarget = true;
                dragStartOffset.set(worldMouse.x - targetMarker.x, worldMouse.y - targetMarker.y);
            }
        }

        if (isDraggingTarget) {
            if (FlxG.mouse.pressed) {
                var targetX = Math.round(worldMouse.x - dragStartOffset.x);
                var targetY = Math.round(worldMouse.y - dragStartOffset.y);
                setAbsoluteCurrentTarget(targetX, targetY);
            } else {
                isDraggingTarget = false;
            }
        }
    }

    private function applyDeltaToCurrentTarget(dx:Float, dy:Float):Void {
        switch (currentMode) {
            case PIECE:
                if (pieceNames.length > 0) {
                    var pName = pieceNames[curPieceIndex];
                    var spr = pieceSprites.get(pName);
                    if (spr != null) {
                        spr.x += dx;
                        spr.y += dy;
                        savePieceTransform(pName, spr.x, spr.y);
                    }
                }
            case BF_SPAWN:
                var pos = getSpawnPos(stageData.boyfriend, [770.0, 450.0]);
                pos[0] += dx; pos[1] += dy;
                setSpawnPos(stageData.boyfriend, pos[0], pos[1]);
                dummyBF.setPosition(pos[0], pos[1]);

            case DAD_SPAWN:
                var oppData = stageData.dad != null ? stageData.dad : stageData.opponent;
                var pos = getSpawnPos(oppData, [100.0, 100.0]);
                pos[0] += dx; pos[1] += dy;
                setSpawnPos(oppData, pos[0], pos[1]);
                dummyDad.setPosition(pos[0], pos[1]);

            case GF_SPAWN:
                var gfData = stageData.girlfriend != null ? stageData.girlfriend : stageData.gf;
                var pos = getSpawnPos(gfData, [400.0, 130.0]);
                pos[0] += dx; pos[1] += dy;
                setSpawnPos(gfData, pos[0], pos[1]);
                dummyGF.setPosition(pos[0], pos[1]);
        }
        updateHUD();
    }

    private function setAbsoluteCurrentTarget(x:Float, y:Float):Void {
        switch (currentMode) {
            case PIECE:
                if (pieceNames.length > 0) {
                    var pName = pieceNames[curPieceIndex];
                    var spr = pieceSprites.get(pName);
                    if (spr != null) {
                        spr.x = x; spr.y = y;
                        savePieceTransform(pName, x, y);
                    }
                }
            case BF_SPAWN:
                setSpawnPos(stageData.boyfriend, x, y);
                dummyBF.setPosition(x, y);
            case DAD_SPAWN:
                setSpawnPos(stageData.dad != null ? stageData.dad : stageData.opponent, x, y);
                dummyDad.setPosition(x, y);
            case GF_SPAWN:
                setSpawnPos(stageData.girlfriend != null ? stageData.girlfriend : stageData.gf, x, y);
                dummyGF.setPosition(x, y);
        }
        updateHUD();
    }

    private function savePieceTransform(pName:String, x:Float, y:Float):Void {
        var list = stageData.pieces != null ? stageData.pieces : stageData.sprites;
        if (list != null) {
            for (p in list) {
                if (p.name == pName || p.id == pName) {
                    if (p.position != null && p.position.length >= 2) {
                        p.position[0] = x;
                        p.position[1] = y;
                    } else {
                        p.x = x;
                        p.y = y;
                    }
                    break;
                }
            }
        }
    }

    private function updateCurrentPieceScale(val:Float, isX:Bool):Void {
        if (currentMode == PIECE && pieceNames.length > 0) {
            var pName = pieceNames[curPieceIndex];
            var spr = pieceSprites.get(pName);
            if (spr != null) {
                if (isX) spr.scale.x = val; else spr.scale.y = val;
                spr.updateHitbox();

                var list = stageData.pieces != null ? stageData.pieces : stageData.sprites;
                if (list != null) {
                    for (p in list) {
                        if (p.name == pName || p.id == pName) {
                            if (p.scale != null && p.scale.length >= 2) {
                                if (isX) p.scale[0] = val; else p.scale[1] = val;
                            } else {
                                p.scale = [spr.scale.x, spr.scale.y];
                            }
                            break;
                        }
                    }
                }
            }
        }
    }

    private function updateCurrentPieceScroll(val:Float, isX:Bool):Void {
        if (currentMode == PIECE && pieceNames.length > 0) {
            var pName = pieceNames[curPieceIndex];
            var spr = pieceSprites.get(pName);
            if (spr != null) {
                if (isX) spr.scrollFactor.x = val; else spr.scrollFactor.y = val;

                var list = stageData.pieces != null ? stageData.pieces : stageData.sprites;
                if (list != null) {
                    for (p in list) {
                        if (p.name == pName || p.id == pName) {
                            if (p.scroll != null && p.scroll.length >= 2) {
                                if (isX) p.scroll[0] = val; else p.scroll[1] = val;
                            } else {
                                p.scroll = [spr.scrollFactor.x, spr.scrollFactor.y];
                            }
                            break;
                        }
                    }
                }
            }
        }
    }

    private function removeCurrentPiece():Void {
        if (currentMode != PIECE || pieceNames.length == 0) {
            EditorToast.show("Select a prop to delete!", true);
            return;
        }

        var pName = pieceNames[curPieceIndex];
        var spr = pieceSprites.get(pName);
        if (spr != null) {
            stagePiecesGroup.remove(spr, true);
            spr.destroy();
            pieceSprites.remove(pName);
        }

        var list = stageData.pieces != null ? stageData.pieces : stageData.sprites;
        if (list != null) {
            for (i in 0...list.length) {
                if (list[i].name == pName || list[i].id == pName) {
                    list.splice(i, 1);
                    break;
                }
            }
        }

        pieceNames.remove(pName);
        curPieceIndex = FlxMath.wrap(curPieceIndex, 0, Std.int(Math.max(0, pieceNames.length - 1)));
        updateHUD();
        EditorToast.show('Removed prop: $pName');
    }

    private function promptCycleStage():Void {
        #if sys
        var stagesFound:Array<String> = [];
        var stageDirs = ["assets/data/stages", "assets/preload/data/stages", "data/stages"];
        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) stageDirs.unshift('mods/$m/data/stages');
        }

        for (dir in stageDirs) {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                for (file in FileSystem.readDirectory(dir)) {
                    if (file.endsWith(".json")) {
                        var id = file.substr(0, file.length - 5);
                        if (!stagesFound.contains(id)) stagesFound.push(id);
                    }
                }
            }
        }

        if (stagesFound.length > 0) {
            var nextIdx = (stagesFound.indexOf(curStage) + 1) % stagesFound.length;
            curStage = stagesFound[nextIdx];
            loadStageData();
            buildStagePieces();
            spawnDummies();
            updateHUD();
            EditorToast.show('Switched stage to: $curStage');
        }
        #end
    }

    private function updateHUD():Void {
        var targetName = switch (currentMode) {
            case PIECE: (pieceNames.length > 0 ? 'Prop: ${pieceNames[curPieceIndex]}' : "None");
            case BF_SPAWN: "Boyfriend Anchor";
            case DAD_SPAWN: "Dad Anchor";
            case GF_SPAWN: "Girlfriend Anchor";
        };

        var curPos:Array<Float> = [0.0, 0.0];
        switch (currentMode) {
            case PIECE:
                if (pieceNames.length > 0) {
                    var spr = pieceSprites.get(pieceNames[curPieceIndex]);
                    if (spr != null) {
                        curPos = [spr.x, spr.y];
                        targetMarker.setPosition(spr.x, spr.y);
                        stepperPieceScaleX.value = spr.scale.x;
                        stepperPieceScaleY.value = spr.scale.y;
                        stepperScrollX.value = spr.scrollFactor.x;
                        stepperScrollY.value = spr.scrollFactor.y;
                    }
                }
            case BF_SPAWN:
                curPos = getSpawnPos(stageData.boyfriend, [770.0, 450.0]);
                targetMarker.setPosition(dummyBF.x, dummyBF.y);
            case DAD_SPAWN:
                curPos = getSpawnPos(stageData.dad != null ? stageData.dad : stageData.opponent, [100.0, 100.0]);
                targetMarker.setPosition(dummyDad.x, dummyDad.y);
            case GF_SPAWN:
                curPos = getSpawnPos(stageData.girlfriend != null ? stageData.girlfriend : stageData.gf, [400.0, 130.0]);
                targetMarker.setPosition(dummyGF.x, dummyGF.y);
        }

        infoTxt.text = 'Target: $targetName\nPos: [${Math.round(curPos[0])}, ${Math.round(curPos[1])}]\nZoom: ${Math.round(stageData.defaultZoom * 100) / 100}x';

        var list = "";
        for (i in 0...pieceNames.length) {
            list += (currentMode == PIECE && i == curPieceIndex ? '> ' : '  ') + pieceNames[i] + '\n';
        }
        list += (currentMode == BF_SPAWN ? '> ' : '  ') + 'BF Spawn\n';
        list += (currentMode == DAD_SPAWN ? '> ' : '  ') + 'Dad Spawn\n';
        list += (currentMode == GF_SPAWN ? '> ' : '  ') + 'GF Spawn\n';
        listTxt.text = list;
    }

    private function saveStageJson():Void {
        var json = Json.stringify(stageData, "\t");
        var fileName = '$curStage.json';

        #if sys
        var targetDir = 'assets/data/stages';
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) {
            targetDir = 'mods/${ModManager.activeMods[0]}/data/stages';
        }

        try {
            if (!FileSystem.exists(targetDir)) FileSystem.createDirectory(targetDir);
            File.saveContent('$targetDir/$fileName', json);
            EditorToast.show("Stage Layout Exported Successfully!");
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            EditorToast.show("Save Failed!", true);
        }
        #else
        var ref = new FileReference();
        ref.save(json, fileName);
        EditorToast.show("Stage File Exported!");
        #end
    }

    override public function destroy():Void {
        if (dragStartOffset != null) dragStartOffset.put();
        super.destroy();
    }
}