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
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.stage.StageJson;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.menus.editors.editorui.*;
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
    private var camUI:FlxCamera;
    private var camFollow:FlxPoint;

    private var stageData:StageJson;
    private var stageLayers:Map<String, FlxSpriteGroup> = new Map<String, FlxSpriteGroup>();
    private var pieceSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    private var pieceDataMap:Map<String, StagePieceJson> = new Map<String, StagePieceJson>();

    private var dummyBF:Character;
    private var dummyDad:Character;
    private var dummyGF:Character;

    private var currentMode:SelectedTargetType = PIECE;
    private var curPieceIndex:Int = 0;
    private var pieceNames:Array<String> = [];

    // --- Layer Ordering Hierarchy ---
    private var layerOrder:Array<String> = ["background", "behindGF", "behindDad", "behindBF", "foreground"];

    // --- Selection Box & Multi-Selection ---
    private var selectionBox:FlxSprite;
    private var isBoxSelecting:Bool = false;
    private var boxStartPoint:FlxPoint;
    private var selectedPieces:Array<String> = [];
    private var selectionOutline:FlxSprite;

    // --- Parallax Testing Simulation ---
    private var isParallaxTesting:Bool = false;
    private var parallaxTimer:Float = 0.0;

    // --- Grid Snapping ---
    private var gridSnapEnabled:Bool = false;
    private var snapGridSize:Float = 20.0;

    // --- Windows & UI ---
    private var topBar:EditorTopBar;
    private var hierarchyWindow:EditorWindow;
    private var transformWindow:EditorWindow;
    private var stageSettingsWindow:EditorWindow;
    private var newPropWindow:EditorWindow;
    private var propExtrasWindow:EditorWindow;
    private var stagePickerModal:EditorWindow;

    private var infoTxt:FlxText;
    private var listTxt:FlxText;
    private var targetMarker:FlxSprite;
    private var layerIndicatorTxt:FlxText;

    private var stepperPieceScaleX:EditorNumericStepper;
    private var stepperPieceScaleY:EditorNumericStepper;
    private var stepperScrollX:EditorNumericStepper;
    private var stepperScrollY:EditorNumericStepper;
    private var stepperAlpha:EditorNumericStepper;
    private var checkAntialias:EditorCheckbox;
    private var checkIs3D:EditorCheckbox;
    private var checkGridSnap:EditorCheckbox;

    private var inputPropName:EditorInputText;
    private var inputPropImage:EditorInputText;
    private var input3DModel:EditorInputText;

    // --- Drag & Drop State ---
    private var isDraggingTarget:Bool = false;
    private var isMiddleDragging:Bool = false;
    private var dragStartOffset:FlxPoint;
    private var dragStartMouse:FlxPoint;

    // --- Undo / Redo History Stack ---
    private var undoStack:Array<String> = [];
    private var redoStack:Array<String> = [];
    private static inline var MAX_UNDO_DEPTH:Int = 50;

    public function new(?stageName:String = "stage") {
        super();
        if (stageName != null && stageName.trim().length > 0) curStage = stageName.trim();
    }

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Stage Architect Ultra", 'Constructing: ${curStage.toUpperCase()}');
        #end

        setupCameras();

        camFollow = FlxPoint.get(FlxG.width * 0.5, FlxG.height * 0.5);
        dragStartOffset = FlxPoint.get(0, 0);
        dragStartMouse = FlxPoint.get(0, 0);
        boxStartPoint = FlxPoint.get(0, 0);

        var bgGrid = new FlxSprite().makeGraphic(Std.int(FlxG.width * 4), Std.int(FlxG.height * 4), EditorTheme.BG_DARK);
        bgGrid.screenCenter();
        bgGrid.scrollFactor.set(0, 0);
        add(bgGrid);

        var ground = new FlxSprite(0, FlxG.height * 0.85).makeGraphic(Std.int(FlxG.width * 4), 3, EditorTheme.ACCENT_PURPLE);
        ground.screenCenter(X);
        ground.scrollFactor.set(1, 1);
        add(ground);

        for (l in layerOrder) {
            var group = new FlxSpriteGroup();
            stageLayers.set(l, group);
            add(group);
        }

        loadStageData();
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

        selectionOutline = new FlxSprite().makeGraphic(1, 1, 0x4400FFFF);
        selectionOutline.visible = false;
        add(selectionOutline);

        selectionBox = new FlxSprite().makeGraphic(1, 1, 0x3300FFFF);
        selectionBox.visible = false;
        add(selectionBox);

        setupWindows();
        buildStagePickerModal();
        updateHUD();

        pushUndoSnapshot();
        add(new EditorToast());
        FlxG.mouse.visible = true;
    }

    override public function setupCameras():Void {
        camStage = new FlxCamera();
        camUI = new FlxCamera();
        camUI.bgColor = FlxColor.TRANSPARENT;

        FlxG.cameras.reset(camStage);
        FlxG.cameras.add(camUI, false);
        FlxG.cameras.setDefaultDrawTarget(camStage, true);
    }

    private function loadStageData():Void {
        var candidates = [
            'stages/$curStage.json',
            'data/stages/$curStage.json',
            'assets/data/stages/$curStage.json',
            'assets/preload/data/stages/$curStage.json',
            'assets/preload/stages/$curStage.json'
        ];
        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                candidates.unshift('mods/$m/data/stages/$curStage.json');
            }
        }

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
        for (layer in stageLayers) layer.clear();
        pieceSprites.clear();
        pieceDataMap.clear();
        pieceNames = [];

        var list = stageData.pieces != null ? stageData.pieces : stageData.sprites;
        if (list != null) {
            for (p in list) {
                if (p == null) continue;
                var pName = (p.id != null) ? p.id : ((p.name != null) ? p.name : "piece_" + pieceNames.length);
                var posX:Float = 0.0;
                var posY:Float = 0.0;

                if (p.position != null && p.position.length >= 2) {
                    posX = p.position[0];
                    posY = p.position[1];
                } else {
                    posX = (p.x != null) ? p.x : 0.0;
                    posY = (p.y != null) ? p.y : 0.0;
                }

                var spr = new FlxSprite(posX, posY);
                var loaded = false;

                if (p.animated == true && p.animations != null && p.animations.length > 0) {
                    loaded = AssetHelper.loadSparrowSafely(spr, p.image);
                    if (loaded) {
                        for (anim in p.animations) {
                            spr.animation.addByPrefix(anim.anim, anim.name, anim.fps != null ? Std.int(anim.fps) : 24, anim.loop != null ? anim.loop : true);
                        }
                        if (p.animations.length > 0) spr.animation.play(p.animations[0].anim);
                    }
                } else if (p.image != null) {
                    loaded = AssetHelper.loadGraphicSafely(spr, p.image);
                }

                if (!loaded) {
                    spr.makeGraphic(400, 300, EditorTheme.PANEL_BORDER);
                }

                spr.scrollFactor.set(p.scroll != null && p.scroll.length >= 2 ? p.scroll[0] : 1.0, p.scroll != null && p.scroll.length >= 2 ? p.scroll[1] : 1.0);
                spr.scale.set(p.scale != null && p.scale.length >= 2 ? p.scale[0] : 1.0, p.scale != null && p.scale.length >= 2 ? p.scale[1] : 1.0);
                spr.alpha = p.alpha != null ? p.alpha : 1.0;
                spr.updateHitbox();
                spr.antialiasing = (p.antialiasing != null) ? p.antialiasing : true;

                var targetLayer = (p.layer != null && stageLayers.exists(p.layer)) ? p.layer : "background";
                if (stageLayers.exists(targetLayer)) {
                    stageLayers.get(targetLayer).add(spr);
                } else {
                    stageLayers.get("background").add(spr);
                }

                pieceSprites.set(pName, spr);
                pieceDataMap.set(pName, p);
                pieceNames.push(pName);
            }
        }
    }

    private function spawnDummies():Void {
        if (dummyGF != null) { stageLayers.get("behindGF").remove(dummyGF, true); dummyGF.destroy(); }
        if (dummyDad != null) { stageLayers.get("behindDad").remove(dummyDad, true); dummyDad.destroy(); }
        if (dummyBF != null) { stageLayers.get("behindBF").remove(dummyBF, true); dummyBF.destroy(); }

        var gfPos = getSpawnPos(stageData.girlfriend != null ? stageData.girlfriend : stageData.gf, [400.0, 130.0]);
        var dadPos = getSpawnPos(stageData.dad != null ? stageData.dad : stageData.opponent, [100.0, 100.0]);
        var bfPos = getSpawnPos(stageData.boyfriend != null ? stageData.boyfriend : stageData.player, [770.0, 450.0]);

        try {
            dummyGF = new Character(gfPos[0], gfPos[1], "gf", false);
        } catch (e:Dynamic) {
            dummyGF = new Character(gfPos[0], gfPos[1], "gf", false);
        }

        try {
            dummyDad = new Character(dadPos[0], dadPos[1], "dad", false);
        } catch (e:Dynamic) {
            dummyDad = new Character(dadPos[0], dadPos[1], "dad", false);
        }

        try {
            dummyBF = new Character(bfPos[0], bfPos[1], "bf", true);
        } catch (e:Dynamic) {
            dummyBF = new Character(bfPos[0], bfPos[1], "bf", true);
        }

        dummyGF.alpha = 0.85; dummyDad.alpha = 0.85; dummyBF.alpha = 0.85;
        dummyGF.visible = !(stageData.hideGirlfriend == true || stageData.hide_girlfriend == true);

        stageLayers.get("behindGF").add(dummyGF);
        stageLayers.get("behindDad").add(dummyDad);
        stageLayers.get("behindBF").add(dummyBF);
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
        topBar = new EditorTopBar('STAGE ARCHITECT ULTRA // [${curStage.toUpperCase()}]');
        topBar.cameras = [camUI];
        topBar.addAction("Save (Ctrl+S)", saveStageJson);
        topBar.addAction("Save .xmsoul", saveStageXMSoul);
        topBar.addAction("Stages", function() stagePickerModal.visible = !stagePickerModal.visible);
        topBar.addAction("Parallax Test (P)", toggleParallaxTest);
        topBar.addAction("Reset View", function() {
            if (dummyBF != null) camFollow.set(dummyBF.getMidpoint().x, dummyBF.getMidpoint().y);
            camStage.zoom = (stageData != null && stageData.defaultZoom != null) ? stageData.defaultZoom : 0.9;
        });
        topBar.addAction("Exit (Esc)", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        hierarchyWindow = new EditorWindow(15, 45, 290, 420, "Stage Tree & Props");
        hierarchyWindow.cameras = [camUI];
        add(hierarchyWindow);

        infoTxt = new FlxText(10, 4, 270, "", 14);
        infoTxt.setFormat(Paths.font("vcr"), 14, EditorTheme.ACCENT_CYAN, LEFT);
        hierarchyWindow.addElement(infoTxt);

        layerIndicatorTxt = new FlxText(10, 26, 270, "Layer: background", 12);
        layerIndicatorTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_YELLOW, LEFT);
        hierarchyWindow.addElement(layerIndicatorTxt);

        listTxt = new FlxText(10, 50, 270, "", 12);
        listTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        hierarchyWindow.addElement(listTxt);

        var btnAddProp = new EditorButton(10, 345, 130, 26, "+ Add Prop", function() {
            newPropWindow.visible = !newPropWindow.visible;
        });
        hierarchyWindow.addElement(btnAddProp);

        var btnDelProp = new EditorButton(150, 345, 130, 26, "- Remove", removeCurrentPiece);
        hierarchyWindow.addElement(btnDelProp);

        var btnDup = new EditorButton(10, 380, 270, 26, "Duplicate Prop (Ctrl+D)", duplicateCurrentProp);
        hierarchyWindow.addElement(btnDup);

        transformWindow = new EditorWindow(FlxG.width - 305, 45, 290, 240, "Transform & Parallax");
        transformWindow.cameras = [camUI];
        add(transformWindow);

        stepperPieceScaleX = new EditorNumericStepper(10, 8, 130, "Scale X", 1.0, 0.05, 10.0, 0.05, 2, function(v) {
            pushUndoSnapshot();
            updateCurrentPieceScale(v, true);
        });
        transformWindow.addElement(stepperPieceScaleX);

        stepperPieceScaleY = new EditorNumericStepper(150, 8, 130, "Scale Y", 1.0, 0.05, 10.0, 0.05, 2, function(v) {
            pushUndoSnapshot();
            updateCurrentPieceScale(v, false);
        });
        transformWindow.addElement(stepperPieceScaleY);

        stepperScrollX = new EditorNumericStepper(10, 46, 130, "Scroll X", 1.0, 0.0, 3.0, 0.05, 2, function(v) {
            pushUndoSnapshot();
            updateCurrentPieceScroll(v, true);
        });
        transformWindow.addElement(stepperScrollX);

        stepperScrollY = new EditorNumericStepper(150, 46, 130, "Scroll Y", 1.0, 0.0, 3.0, 0.05, 2, function(v) {
            pushUndoSnapshot();
            updateCurrentPieceScroll(v, false);
        });
        transformWindow.addElement(stepperScrollY);

        stepperAlpha = new EditorNumericStepper(10, 84, 130, "Alpha", 1.0, 0.0, 1.0, 0.05, 2, function(v) {
            pushUndoSnapshot();
            updateCurrentPieceAlpha(v);
        });
        transformWindow.addElement(stepperAlpha);

        checkAntialias = new EditorCheckbox(150, 98, "Antialiasing", true, function(c) {
            pushUndoSnapshot();
            updateCurrentPieceAntialiasing(c);
        });
        transformWindow.addElement(checkAntialias);

        var btnChangeLayer = new EditorButton(10, 135, 270, 26, "Cycle Layer (L Key)", cyclePieceLayer);
        transformWindow.addElement(btnChangeLayer);

        stageSettingsWindow = new EditorWindow(FlxG.width - 305, 295, 290, 200, "Global Environment");
        stageSettingsWindow.cameras = [camUI];
        add(stageSettingsWindow);

        var stepperZoom = new EditorNumericStepper(10, 8, 270, "Default Camera Zoom", stageData.defaultZoom != null ? stageData.defaultZoom : 0.9, 0.2, 3.0, 0.05, 2, function(v) {
            pushUndoSnapshot();
            stageData.defaultZoom = v;
            camStage.zoom = v;
            updateHUD();
        });
        stageSettingsWindow.addElement(stepperZoom);

        var stepperCamSpeed = new EditorNumericStepper(10, 46, 270, "Camera Pan Speed", stageData.cameraSpeed != null ? stageData.cameraSpeed : 1.0, 0.1, 5.0, 0.1, 2, function(v) {
            pushUndoSnapshot();
            stageData.cameraSpeed = v;
        });
        stageSettingsWindow.addElement(stepperCamSpeed);

        checkGridSnap = new EditorCheckbox(10, 88, "Grid Snap (20px)", gridSnapEnabled, function(c) {
            gridSnapEnabled = c;
        });
        stageSettingsWindow.addElement(checkGridSnap);

        var checkGF = new EditorCheckbox(150, 88, "Hide GF", stageData.hideGirlfriend == true, function(c) {
            pushUndoSnapshot();
            stageData.hideGirlfriend = c;
            if (dummyGF != null) dummyGF.visible = !c;
        });
        stageSettingsWindow.addElement(checkGF);

        propExtrasWindow = new EditorWindow(15, 475, 290, 135, "2.5D & 3D Extensions");
        propExtrasWindow.cameras = [camUI];
        add(propExtrasWindow);

        checkIs3D = new EditorCheckbox(10, 8, "Render as 3D Mesh", false, function(c) {
            if (currentMode == PIECE && pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
                var p = pieceDataMap.get(pieceNames[curPieceIndex]);
                if (p != null) p.is3D = c;
                EditorToast.show('3D Mode: $c');
            }
        });
        propExtrasWindow.addElement(checkIs3D);

        input3DModel = new EditorInputText(10, 36, 270, "3D Model Path (.obj/.awd)", "arena.obj");
        propExtrasWindow.addElement(input3DModel);

        var btnApply3D = new EditorButton(10, 78, 270, 26, "Bind 3D Model Path", function() {
            if (currentMode == PIECE && pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
                var p = pieceDataMap.get(pieceNames[curPieceIndex]);
                if (p != null) {
                    pushUndoSnapshot();
                    p.modelPath = input3DModel.text.trim();
                    p.is3D = true;
                    checkIs3D.checked = true;
                    EditorToast.show('Bound 3D Model: ${p.modelPath}');
                }
            }
        });
        propExtrasWindow.addElement(btnApply3D);

        newPropWindow = new EditorWindow((FlxG.width - 320) * 0.5, (FlxG.height - 240) * 0.5, 320, 240, "Inject Stage Prop");
        newPropWindow.cameras = [camUI];
        newPropWindow.visible = false;
        add(newPropWindow);

        inputPropName = new EditorInputText(10, 4, 300, "Prop ID (e.g. stageback)", "stageback");
        newPropWindow.addElement(inputPropName);

        inputPropImage = new EditorInputText(10, 48, 300, "Asset Path (images/)", "stages/default/stageback");
        newPropWindow.addElement(inputPropImage);

        var checkAnimated = new EditorCheckbox(10, 92, "Sparrow XML Animated", false);
        newPropWindow.addElement(checkAnimated);

        var btnSubmitProp = new EditorButton(10, 150, 300, 28, "Place on Stage", function() {
            var pId = inputPropName.text.trim();
            var pImg = inputPropImage.text.trim();

            if (pId.length > 0 && pImg.length > 0) {
                pushUndoSnapshot();
                var newPiece:StagePieceJson = {
                    name: pId,
                    image: pImg,
                    position: [0.0, 0.0],
                    scroll: [1.0, 1.0],
                    scale: [1.0, 1.0],
                    layer: "background",
                    animated: checkAnimated.checked,
                    antialiasing: true,
                    alpha: 1.0
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

    private function buildStagePickerModal():Void {
        stagePickerModal = new EditorWindow((FlxG.width - 440) * 0.5, (FlxG.height - 480) * 0.5, 440, 480, "Stage Asset Library");
        stagePickerModal.cameras = [camUI];
        stagePickerModal.visible = false;
        add(stagePickerModal);

        var stagesFound:Array<String> = [];
        #if sys
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
        #end
        if (!stagesFound.contains("stage")) stagesFound.push("stage");

        var listTxt = new FlxText(10, 6, 420, "AVAILABLE STAGES:", 12);
        listTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_CYAN, LEFT);
        stagePickerModal.addElement(listTxt);

        for (i in 0...Std.int(Math.min(8, stagesFound.length))) {
            var st = stagesFound[i];
            var btn = new EditorButton(10, 30 + (i * 34), 420, 28, st.toUpperCase(), function() {
                curStage = st;
                loadStageData();
                buildStagePieces();
                spawnDummies();
                updateHUD();
                stagePickerModal.visible = false;
                EditorToast.show('Loaded stage: $st');
            });
            stagePickerModal.addElement(btn);
        }

        var btnClose = new EditorButton(10, 410, 420, 28, "Close Library", function() {
            stagePickerModal.visible = false;
        });
        stagePickerModal.addElement(btnClose);
    }

    private function toggleParallaxTest():Void {
        isParallaxTesting = !isParallaxTesting;
        EditorToast.show(isParallaxTesting ? "Parallax Viewport Test Active" : "Parallax Test Stopped");
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (isParallaxTesting) {
            parallaxTimer += elapsed * 1.5;
            camFollow.x = (FlxG.width * 0.5) + (Math.sin(parallaxTimer) * 450.0);
            camFollow.y = (FlxG.height * 0.5) + (Math.cos(parallaxTimer * 0.8) * 180.0);
            camStage.focusOn(camFollow);
        } else {
            handleCameraControls(elapsed);
        }

        handleSelectionInput();
        handleTransformInput();
        handleMouseDragControls();
        handleMarqueeSelection();

        if (FlxG.keys.justPressed.P) toggleParallaxTest();
        if (FlxG.keys.justPressed.ONE && dummyBF != null) camFollow.set(dummyBF.getMidpoint().x, dummyBF.getMidpoint().y);
        if (FlxG.keys.justPressed.TWO && dummyDad != null) camFollow.set(dummyDad.getMidpoint().x, dummyDad.getMidpoint().y);
        if (FlxG.keys.justPressed.THREE && dummyGF != null) camFollow.set(dummyGF.getMidpoint().x, dummyGF.getMidpoint().y);

        if (FlxG.keys.justPressed.SPACE) {
            if (dummyBF != null) dummyBF.playSingAnim(FlxG.random.int(0, 3), true);
            if (dummyDad != null) dummyDad.playSingAnim(FlxG.random.int(0, 3), true);
        }

        if (FlxG.keys.justPressed.L) cyclePieceLayer();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.D) duplicateCurrentProp();

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveStageJson();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z) undo();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Y) redo();
        if (FlxG.keys.justPressed.ESCAPE && !newPropWindow.visible && !stagePickerModal.visible) {
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    private function handleCameraControls(elapsed:Float):Void {
        if (FlxG.keys.pressed.Q) camStage.zoom += 0.8 * elapsed;
        if (FlxG.keys.pressed.E) camStage.zoom = Math.max(0.15, camStage.zoom - 0.8 * elapsed);

        var spd = FlxG.keys.pressed.SHIFT ? 1400.0 : 550.0;
        if (FlxG.keys.pressed.I) camFollow.y -= spd * elapsed;
        if (FlxG.keys.pressed.K) camFollow.y += spd * elapsed;
        if (FlxG.keys.pressed.J) camFollow.x -= spd * elapsed;
        if (FlxG.keys.pressed.L && !FlxG.keys.justPressed.L) camFollow.x += spd * elapsed;

        camStage.focusOn(camFollow);
    }

    private function handleSelectionInput():Void {
        if (newPropWindow.visible || stagePickerModal.visible) return;

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
        if (newPropWindow.visible || stagePickerModal.visible) return;

        var mult = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
        var dx:Float = 0;
        var dy:Float = 0;

        if (FlxG.keys.justPressed.LEFT) dx -= mult;
        if (FlxG.keys.justPressed.RIGHT) dx += mult;
        if (FlxG.keys.justPressed.UP) dy -= mult;
        if (FlxG.keys.justPressed.DOWN) dy += mult;

        if (dx == 0 && dy == 0) return;

        pushUndoSnapshot();
        applyDeltaToCurrentTarget(dx, dy);
    }

    private function handleMouseDragControls():Void {
        var worldMouse = FlxG.mouse.getWorldPosition(camStage);

        if (FlxG.mouse.justPressed && !newPropWindow.visible && !stagePickerModal.visible && !FlxG.keys.pressed.SHIFT) {
            if (worldMouse.x >= targetMarker.x - 12 && worldMouse.x <= targetMarker.x + 36 &&
                worldMouse.y >= targetMarker.y - 12 && worldMouse.y <= targetMarker.y + 36) {
                isDraggingTarget = true;
                pushUndoSnapshot();
                dragStartOffset.set(worldMouse.x - targetMarker.x, worldMouse.y - targetMarker.y);
            }
        }

        if (isDraggingTarget) {
            if (FlxG.mouse.pressed) {
                var targetX = Math.round(worldMouse.x - dragStartOffset.x);
                var targetY = Math.round(worldMouse.y - dragStartOffset.y);
                if (gridSnapEnabled) {
                    targetX = Math.round(targetX / snapGridSize) * Std.int(snapGridSize);
                    targetY = Math.round(targetY / snapGridSize) * Std.int(snapGridSize);
                }
                setAbsoluteCurrentTarget(targetX, targetY);
            } else {
                isDraggingTarget = false;
            }
        }

        if (FlxG.mouse.justPressedMiddle && !newPropWindow.visible && !stagePickerModal.visible) {
            isMiddleDragging = true;
            pushUndoSnapshot();
            dragStartMouse.set(worldMouse.x, worldMouse.y);
            var curPos = getCurrentTargetPos();
            dragStartOffset.set(curPos[0], curPos[1]);
        }

        if (isMiddleDragging) {
            if (FlxG.mouse.pressedMiddle) {
                var dx = Math.round(worldMouse.x - dragStartMouse.x);
                var dy = Math.round(worldMouse.y - dragStartMouse.y);
                var targetX = dragStartOffset.x + dx;
                var targetY = dragStartOffset.y + dy;
                if (gridSnapEnabled) {
                    targetX = Math.round(targetX / snapGridSize) * snapGridSize;
                    targetY = Math.round(targetY / snapGridSize) * snapGridSize;
                }
                setAbsoluteCurrentTarget(targetX, targetY);
            } else {
                isMiddleDragging = false;
            }
        }
    }

    private function handleMarqueeSelection():Void {
        if (FlxG.keys.pressed.SHIFT && FlxG.mouse.justPressed && !newPropWindow.visible && !stagePickerModal.visible) {
            isBoxSelecting = true;
            boxStartPoint.set(FlxG.mouse.x, FlxG.mouse.y);
            selectionBox.visible = true;
        }

        if (isBoxSelecting) {
            var boxX = Math.min(boxStartPoint.x, FlxG.mouse.x);
            var boxY = Math.min(boxStartPoint.y, FlxG.mouse.y);
            var boxW = Math.abs(FlxG.mouse.x - boxStartPoint.x);
            var boxH = Math.abs(FlxG.mouse.y - boxStartPoint.y);

            selectionBox.setPosition(boxX, boxY);
            selectionBox.setGraphicSize(Std.int(Math.max(1, boxW)), Std.int(Math.max(1, boxH)));
            selectionBox.updateHitbox();

            if (FlxG.mouse.justReleased) {
                isBoxSelecting = false;
                selectionBox.visible = false;

                var bounds = new Rectangle(boxX, boxY, boxW, boxH);
                selectedPieces = [];
                for (pName in pieceNames) {
                    var spr = pieceSprites.get(pName);
                    if (spr != null && bounds.contains(spr.x, spr.y)) {
                        selectedPieces.push(pName);
                    }
                }
                EditorToast.show('Selected ${selectedPieces.length} stage props.');
            }
        }
    }

    private function duplicateCurrentProp():Void {
        if (currentMode != PIECE || pieceNames.length == 0 || curPieceIndex >= pieceNames.length) return;
        pushUndoSnapshot();

        var pName = pieceNames[curPieceIndex];
        var original = pieceDataMap.get(pName);
        if (original != null) {
            var cloneName = pName + "_copy";
            var clonePiece:StagePieceJson = {
                name: cloneName,
                image: original.image,
                position: [(original.position != null && original.position.length > 0 ? original.position[0] : 0.0) + 50, (original.position != null && original.position.length > 1 ? original.position[1] : 0.0) + 50],
                scroll: original.scroll,
                scale: original.scale,
                layer: original.layer,
                animated: original.animated,
                animations: original.animations,
                antialiasing: original.antialiasing,
                alpha: original.alpha
            };

            if (stageData.pieces == null) stageData.pieces = [];
            stageData.pieces.push(clonePiece);

            buildStagePieces();
            curPieceIndex = pieceNames.indexOf(cloneName);
            updateHUD();
            EditorToast.show('Duplicated prop -> $cloneName');
        }
    }

    private function getCurrentTargetPos():Array<Float> {
        return switch (currentMode) {
            case PIECE:
                if (pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
                    var spr = pieceSprites.get(pieceNames[curPieceIndex]);
                    return spr != null ? [spr.x, spr.y] : [0.0, 0.0];
                }
                [0.0, 0.0];
            case BF_SPAWN: getSpawnPos(stageData != null ? stageData.boyfriend : null, [770.0, 450.0]);
            case DAD_SPAWN: getSpawnPos(stageData != null ? (stageData.dad != null ? stageData.dad : stageData.opponent) : null, [100.0, 100.0]);
            case GF_SPAWN: getSpawnPos(stageData != null ? (stageData.girlfriend != null ? stageData.girlfriend : stageData.gf) : null, [400.0, 130.0]);
        };
    }

    private function applyDeltaToCurrentTarget(dx:Float, dy:Float):Void {
        switch (currentMode) {
            case PIECE:
                if (pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
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
                if (dummyBF != null) dummyBF.setPosition(pos[0], pos[1]);

            case DAD_SPAWN:
                var oppData = stageData.dad != null ? stageData.dad : stageData.opponent;
                var pos = getSpawnPos(oppData, [100.0, 100.0]);
                pos[0] += dx; pos[1] += dy;
                setSpawnPos(oppData, pos[0], pos[1]);
                if (dummyDad != null) dummyDad.setPosition(pos[0], pos[1]);

            case GF_SPAWN:
                var gfData = stageData.girlfriend != null ? stageData.girlfriend : stageData.gf;
                var pos = getSpawnPos(gfData, [400.0, 130.0]);
                pos[0] += dx; pos[1] += dy;
                setSpawnPos(gfData, pos[0], pos[1]);
                if (dummyGF != null) dummyGF.setPosition(pos[0], pos[1]);
        }
        updateHUD();
    }

    private function setAbsoluteCurrentTarget(x:Float, y:Float):Void {
        switch (currentMode) {
            case PIECE:
                if (pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
                    var pName = pieceNames[curPieceIndex];
                    var spr = pieceSprites.get(pName);
                    if (spr != null) {
                        spr.x = x; spr.y = y;
                        savePieceTransform(pName, x, y);
                    }
                }
            case BF_SPAWN:
                setSpawnPos(stageData.boyfriend, x, y);
                if (dummyBF != null) dummyBF.setPosition(x, y);
            case DAD_SPAWN:
                setSpawnPos(stageData.dad != null ? stageData.dad : stageData.opponent, x, y);
                if (dummyDad != null) dummyDad.setPosition(x, y);
            case GF_SPAWN:
                setSpawnPos(stageData.girlfriend != null ? stageData.girlfriend : stageData.gf, x, y);
                if (dummyGF != null) dummyGF.setPosition(x, y);
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

    private function cyclePieceLayer():Void {
        if (currentMode != PIECE || pieceNames.length == 0 || curPieceIndex >= pieceNames.length) return;
        var pName = pieceNames[curPieceIndex];
        var spr = pieceSprites.get(pName);
        var p = pieceDataMap.get(pName);

        if (spr != null && p != null) {
            pushUndoSnapshot();
            var curLayer = p.layer != null ? p.layer : "background";
            var nextLayerIdx = (layerOrder.indexOf(curLayer) + 1) % layerOrder.length;
            var nextLayer = layerOrder[nextLayerIdx];

            if (stageLayers.exists(curLayer)) stageLayers.get(curLayer).remove(spr, true);
            p.layer = nextLayer;
            if (stageLayers.exists(nextLayer)) stageLayers.get(nextLayer).add(spr);

            updateHUD();
            EditorToast.show('Moved $pName -> $nextLayer');
        }
    }

    private function updateCurrentPieceScale(val:Float, isX:Bool):Void {
        if (currentMode == PIECE && pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
            var pName = pieceNames[curPieceIndex];
            var spr = pieceSprites.get(pName);
            if (spr != null) {
                if (isX) spr.scale.x = val; else spr.scale.y = val;
                spr.updateHitbox();

                var p = pieceDataMap.get(pName);
                if (p != null) {
                    if (p.scale != null && p.scale.length >= 2) {
                        if (isX) p.scale[0] = val; else p.scale[1] = val;
                    } else {
                        p.scale = [spr.scale.x, spr.scale.y];
                    }
                }
            }
        }
    }

    private function updateCurrentPieceScroll(val:Float, isX:Bool):Void {
        if (currentMode == PIECE && pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
            var pName = pieceNames[curPieceIndex];
            var spr = pieceSprites.get(pName);
            if (spr != null) {
                if (isX) spr.scrollFactor.x = val; else spr.scrollFactor.y = val;

                var p = pieceDataMap.get(pName);
                if (p != null) {
                    if (p.scroll != null && p.scroll.length >= 2) {
                        if (isX) p.scroll[0] = val; else p.scroll[1] = val;
                    } else {
                        p.scroll = [spr.scrollFactor.x, spr.scrollFactor.y];
                    }
                }
            }
        }
    }

    private function updateCurrentPieceAlpha(val:Float):Void {
        if (currentMode == PIECE && pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
            var pName = pieceNames[curPieceIndex];
            var spr = pieceSprites.get(pName);
            if (spr != null) {
                spr.alpha = val;
                var p = pieceDataMap.get(pName);
                if (p != null) p.alpha = val;
            }
        }
    }

    private function updateCurrentPieceAntialiasing(val:Bool):Void {
        if (currentMode == PIECE && pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
            var pName = pieceNames[curPieceIndex];
            var spr = pieceSprites.get(pName);
            if (spr != null) {
                spr.antialiasing = val;
                var p = pieceDataMap.get(pName);
                if (p != null) p.antialiasing = val;
            }
        }
    }

    private function removeCurrentPiece():Void {
        if (currentMode != PIECE || pieceNames.length == 0 || curPieceIndex >= pieceNames.length) {
            EditorToast.show("Select a prop to delete!", true);
            return;
        }
        pushUndoSnapshot();

        var pName = pieceNames[curPieceIndex];
        var spr = pieceSprites.get(pName);
        var p = pieceDataMap.get(pName);

        if (spr != null && p != null) {
            var lyr = p.layer != null ? p.layer : "background";
            if (stageLayers.exists(lyr)) stageLayers.get(lyr).remove(spr, true);
            spr.destroy();
            pieceSprites.remove(pName);
            pieceDataMap.remove(pName);
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

    private function pushUndoSnapshot():Void {
        if (stageData == null) return;
        undoStack.push(Json.stringify(stageData));
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
        stageData = Json.parse(prev);
        buildStagePieces();
        spawnDummies();
        updateHUD();
        EditorToast.show("Undone action.");
    }

    private function redo():Void {
        if (redoStack.length == 0) {
            EditorToast.show("No redos available.", true);
            return;
        }
        var next = redoStack.pop();
        undoStack.push(next);
        stageData = Json.parse(next);
        buildStagePieces();
        spawnDummies();
        updateHUD();
        EditorToast.show("Redone action.");
    }

    private function updateHUD():Void {
        var targetName = switch (currentMode) {
            case PIECE: (pieceNames.length > 0 && curPieceIndex < pieceNames.length ? 'Prop: ${pieceNames[curPieceIndex]}' : "None");
            case BF_SPAWN: "Boyfriend Anchor";
            case DAD_SPAWN: "Dad Anchor";
            case GF_SPAWN: "Girlfriend Anchor";
        };

        var curPos:Array<Float> = [0.0, 0.0];
        switch (currentMode) {
            case PIECE:
                if (pieceNames.length > 0 && curPieceIndex < pieceNames.length) {
                    var pName = pieceNames[curPieceIndex];
                    var spr = pieceSprites.get(pName);
                    var p = pieceDataMap.get(pName);
                    if (spr != null) {
                        curPos = [spr.x, spr.y];
                        targetMarker.setPosition(spr.x, spr.y);
                        if (stepperPieceScaleX != null) stepperPieceScaleX.value = spr.scale.x;
                        if (stepperPieceScaleY != null) stepperPieceScaleY.value = spr.scale.y;
                        if (stepperScrollX != null) stepperScrollX.value = spr.scrollFactor.x;
                        if (stepperScrollY != null) stepperScrollY.value = spr.scrollFactor.y;
                        if (stepperAlpha != null) stepperAlpha.value = spr.alpha;
                        if (checkAntialias != null) checkAntialias.checked = spr.antialiasing;

                        if (selectionOutline != null) {
                            selectionOutline.setPosition(spr.x, spr.y);
                            selectionOutline.setGraphicSize(Std.int(Math.max(1, spr.width)), Std.int(Math.max(1, spr.height)));
                            selectionOutline.updateHitbox();
                            selectionOutline.visible = true;
                        }
                    }
                    if (p != null) {
                        if (layerIndicatorTxt != null) layerIndicatorTxt.text = 'Layer: ${p.layer != null ? p.layer : "background"}';
                        if (checkIs3D != null) checkIs3D.checked = p.is3D == true;
                        if (input3DModel != null) input3DModel.text = p.modelPath != null ? p.modelPath : "arena.obj";
                    }
                } else if (selectionOutline != null) {
                    selectionOutline.visible = false;
                }
            case BF_SPAWN:
                curPos = getSpawnPos(stageData != null ? stageData.boyfriend : null, [770.0, 450.0]);
                if (dummyBF != null) targetMarker.setPosition(dummyBF.x, dummyBF.y);
                if (layerIndicatorTxt != null) layerIndicatorTxt.text = "Layer: behindBF";
                if (selectionOutline != null) selectionOutline.visible = false;
            case DAD_SPAWN:
                curPos = getSpawnPos(stageData != null ? (stageData.dad != null ? stageData.dad : stageData.opponent) : null, [100.0, 100.0]);
                if (dummyDad != null) targetMarker.setPosition(dummyDad.x, dummyDad.y);
                if (layerIndicatorTxt != null) layerIndicatorTxt.text = "Layer: behindDad";
                if (selectionOutline != null) selectionOutline.visible = false;
            case GF_SPAWN:
                curPos = getSpawnPos(stageData != null ? (stageData.girlfriend != null ? stageData.girlfriend : stageData.gf) : null, [400.0, 130.0]);
                if (dummyGF != null) targetMarker.setPosition(dummyGF.x, dummyGF.y);
                if (layerIndicatorTxt != null) layerIndicatorTxt.text = "Layer: behindGF";
                if (selectionOutline != null) selectionOutline.visible = false;
        }

        var defaultZoomVal:Float = (stageData != null && stageData.defaultZoom != null) ? stageData.defaultZoom : 0.9;
        if (infoTxt != null) {
            infoTxt.text = 'Target: $targetName\nPos: [${Math.round(curPos[0])}, ${Math.round(curPos[1])}]\nZoom: ${Math.round(defaultZoomVal * 100) / 100}x';
        }

        if (listTxt != null) {
            var list = "";
            for (i in 0...pieceNames.length) {
                list += (currentMode == PIECE && i == curPieceIndex ? '> ' : '  ') + pieceNames[i] + '\n';
            }
            list += (currentMode == BF_SPAWN ? '> ' : '  ') + 'BF Spawn\n';
            list += (currentMode == DAD_SPAWN ? '> ' : '  ') + 'Dad Spawn\n';
            list += (currentMode == GF_SPAWN ? '> ' : '  ') + 'GF Spawn\n';
            listTxt.text = list;
        }
    }

    public function saveStageXMSoul():Void {
        #if sys
        var targetDir = 'assets/data/stages';
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) {
            targetDir = 'mods/${ModManager.activeMods[0]}/data/stages';
        }
        var targetPath = '$targetDir/$curStage.xmsoul';

        var zoomVal = stageData.defaultZoom != null ? stageData.defaultZoom : 0.9;
        var camSpd = stageData.cameraSpeed != null ? stageData.cameraSpeed : 1.0;
        var bf = getSpawnPos(stageData.boyfriend, [770.0, 450.0]);
        var dad = getSpawnPos(stageData.dad, [100.0, 100.0]);
        var gf = getSpawnPos(stageData.girlfriend, [400.0, 130.0]);

        var xml = '<?xml version="1.0" encoding="utf-8"?>\n';
        xml += '<stage name="$curStage" defaultZoom="$zoomVal" cameraSpeed="$camSpd" hideGirlfriend="${stageData.hideGirlfriend}">\n';
        xml += '    <spawns>\n';
        xml += '        <bf x="${bf[0]}" y="${bf[1]}" />\n';
        xml += '        <dad x="${dad[0]}" y="${dad[1]}" />\n';
        xml += '        <gf x="${gf[0]}" y="${gf[1]}" />\n';
        xml += '    </spawns>\n';
        xml += '    <pieces>\n';

        for (pName in pieceNames) {
            var p = pieceDataMap.get(pName);
            var spr = pieceSprites.get(pName);
            if (p != null && spr != null) {
                xml += '        <piece id="$pName" image="${p.image}" layer="${p.layer}" x="${spr.x}" y="${spr.y}" scrollX="${spr.scrollFactor.x}" scrollY="${spr.scrollFactor.y}" scaleX="${spr.scale.x}" scaleY="${spr.scale.y}" alpha="${spr.alpha}" />\n';
            }
        }

        xml += '    </pieces>\n</stage>';

        try {
            if (!FileSystem.exists(targetDir)) FileSystem.createDirectory(targetDir);
            File.saveContent(targetPath, xml);
            EditorToast.show('Saved .xmsoul manifest: $curStage.xmsoul');
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            EditorToast.show("Failed writing .xmsoul manifest", true);
        }
        #end
    }

    private function saveStageJson():Void {
        if (stageData == null) return;
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
        if (dragStartOffset != null) { dragStartOffset.put(); dragStartOffset = null; }
        if (dragStartMouse != null) { dragStartMouse.put(); dragStartMouse = null; }
        if (boxStartPoint != null) { boxStartPoint.put(); boxStartPoint = null; }
        super.destroy();
    }
}