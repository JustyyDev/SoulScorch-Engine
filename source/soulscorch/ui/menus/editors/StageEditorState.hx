package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
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
import soulscorch.backend.input.Controls;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.stage.Stage;
import soulscorch.gameplay.stage.StageJson;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.menus.editors.editorui.EditorButton;
import soulscorch.ui.menus.editors.editorui.EditorCheckbox;
import soulscorch.ui.menus.editors.editorui.EditorNumericStepper;
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

    private var toolWindow:EditorWindow;
    private var stepperZoom:EditorNumericStepper;
    private var stepperSpeed:EditorNumericStepper;
    private var checkHideGF:EditorCheckbox;

    private var infoTxt:FlxText;
    private var listTxt:FlxText;
    private var helpTxt:FlxText;
    private var targetMarker:FlxSprite;

    public function new(?stageName:String = "stage") {
        super();
        if (stageName != null && stageName.trim().length > 0) {
            curStage = stageName.trim();
        }
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
        camStage.zoom = 0.9;

        var bgGrid = new FlxSprite().makeGraphic(FlxG.width * 4, FlxG.height * 4, 0xFF181520);
        bgGrid.screenCenter();
        bgGrid.scrollFactor.set(0, 0);
        add(bgGrid);

        var ground = new FlxSprite(0, FlxG.height * 0.85).makeGraphic(FlxG.width * 4, 4, 0xFF443D54);
        ground.screenCenter(X);
        ground.scrollFactor.set(1, 1);
        add(ground);

        loadStageData();

        stagePiecesGroup = new FlxSpriteGroup();
        add(stagePiecesGroup);
        buildStagePieces();

        spawnDummies();

        targetMarker = new FlxSprite().makeGraphic(24, 24, FlxColor.TRANSPARENT);
        targetMarker.pixels.lock();
        for (i in 0...24) {
            targetMarker.pixels.setPixel32(i, 12, 0xFFFF0055);
            targetMarker.pixels.setPixel32(12, i, 0xFFFF0055);
        }
        targetMarker.pixels.unlock();
        targetMarker.dirty = true;
        targetMarker.scrollFactor.set(1, 1);
        add(targetMarker);

        setupHUD();
        setupToolbox();
        updateHUD();

        FlxG.mouse.visible = true;
    }

    private function loadStageData():Void {
        var rawText:String = AssetResolver.getText('stages/$curStage');
        if (rawText.length == 0) rawText = AssetResolver.getText('data/stages/$curStage.json');
        if (rawText.length == 0) rawText = AssetResolver.getText('assets/stages/$curStage.json');

        if (rawText.trim().length > 0) {
            try {
                stageData = cast Json.parse(rawText);
            } catch (e:Dynamic) {
                Logger.error('Failed parsing stage JSON for $curStage: $e', "editor");
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

        var piecesList = (stageData.pieces != null) ? stageData.pieces : stageData.sprites;
        if (piecesList != null) {
            for (p in piecesList) {
                var pName = (p.id != null) ? p.id : ((p.name != null) ? p.name : "piece_" + pieceNames.length);
                var posX = (p.position != null && p.position.length > 0) ? p.position[0] : (p.x != null ? p.x : 0.0);
                var posY = (p.position != null && p.position.length > 1) ? p.position[1] : (p.y != null ? p.y : 0.0);

                var spr = new FlxSprite(posX, posY);
                if (!AssetHelper.loadGraphicSafely(spr, p.image)) {
                    spr.makeGraphic(400, 300, 0x88AA00FF);
                }

                var scX = (p.scroll != null && p.scroll.length > 0) ? p.scroll[0] : (p.scrollX != null ? p.scrollX : 1.0);
                var scY = (p.scroll != null && p.scroll.length > 1) ? p.scroll[1] : (p.scrollY != null ? p.scrollY : 1.0);
                var scaleX = (p.scale != null && p.scale.length > 0) ? p.scale[0] : (p.scaleX != null ? p.scaleX : 1.0);
                var scaleY = (p.scale != null && p.scale.length > 1) ? p.scale[1] : (p.scaleY != null ? p.scaleY : 1.0);

                spr.scrollFactor.set(scX, scY);
                spr.scale.set(scaleX, scaleY);
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
        var bfPos = getSpawnPos(stageData.boyfriend, [770.0, 450.0]);

        dummyGF = new Character(gfPos[0], gfPos[1], "gf", false);
        dummyDad = new Character(dadPos[0], dadPos[1], "dad", false);
        dummyBF = new Character(bfPos[0], bfPos[1], "bf", true);

        dummyGF.alpha = 0.85;
        dummyDad.alpha = 0.85;
        dummyBF.alpha = 0.85;

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
        } else if (Reflect.isObject(raw) && Reflect.hasField(raw, "position")) {
            var posArr:Array<Dynamic> = cast Reflect.field(raw, "position");
            if (posArr != null && posArr.length >= 2) return [Std.parseFloat(Std.string(posArr[0])), Std.parseFloat(Std.string(posArr[1]))];
        }
        return fallback;
    }

    private function setSpawnPos(target:Dynamic, x:Float, y:Float):Void {
        if (Std.isOfType(target, Array)) {
            var a:Array<Float> = cast target;
            a[0] = x;
            a[1] = y;
        } else if (Reflect.isObject(target) && Reflect.hasField(target, "position")) {
            var p:Array<Float> = cast Reflect.field(target, "position");
            p[0] = x;
            p[1] = y;
        }
    }

    private function setupHUD():Void {
        var hudBg = new FlxSprite(10, 10).makeGraphic(320, 360, 0xDD110E1A);
        hudBg.scrollFactor.set();
        hudBg.cameras = [camHUD];
        add(hudBg);

        infoTxt = new FlxText(20, 18, 300, "", 15);
        infoTxt.setFormat(Paths.font("vcr"), 15, FlxColor.WHITE, LEFT);
        infoTxt.scrollFactor.set();
        infoTxt.cameras = [camHUD];
        add(infoTxt);

        listTxt = new FlxText(20, 140, 300, "", 13);
        listTxt.setFormat(Paths.font("vcr"), 13, 0xFF00FFCC, LEFT);
        listTxt.scrollFactor.set();
        listTxt.cameras = [camHUD];
        add(listTxt);

        var helpBg = new FlxSprite(FlxG.width - 330, 10).makeGraphic(320, 320, 0xDD110E1A);
        helpBg.scrollFactor.set();
        helpBg.cameras = [camHUD];
        add(helpBg);

        helpTxt = new FlxText(FlxG.width - 320, 18, 300,
            "STAGE CONTROLS:\n\n" +
            "[TAB] - Cycle Selected Target\n" +
            "[W / S] - Next / Prev Stage Piece\n" +
            "[ARROWS] - Move Selected (1px)\n" +
            "[SHIFT + ARROWS] - Move Selected (10px)\n" +
            "[Q / E] - Zoom Cam In / Out\n" +
            "[I / J / K / L] - Pan Editor Camera\n" +
            "[CTRL + S] - Export Stage JSON\n" +
            "[ESCAPE] - Return to Main Menu",
            13
        );
        helpTxt.setFormat(Paths.font("vcr"), 13, 0xFFDDDDDD, LEFT);
        helpTxt.scrollFactor.set();
        helpTxt.cameras = [camHUD];
        add(helpTxt);
    }

    private function setupToolbox():Void {
        toolWindow = new EditorWindow(10, FlxG.height - 210, 320, 200, "Stage Settings");
        toolWindow.cameras = [camHUD];
        add(toolWindow);

        stepperZoom = new EditorNumericStepper(10, 10, 290, "Default Zoom", stageData.defaultZoom != null ? stageData.defaultZoom : 0.9, 0.3, 3.0, 0.05, 2, function(v) {
            stageData.defaultZoom = v;
            camStage.zoom = v;
            updateHUD();
        });
        toolWindow.addElement(stepperZoom);

        stepperSpeed = new EditorNumericStepper(10, 45, 290, "Cam Speed", stageData.cameraSpeed != null ? stageData.cameraSpeed : 1.0, 0.1, 5.0, 0.1, 2, function(v) {
            stageData.cameraSpeed = v;
        });
        toolWindow.addElement(stepperSpeed);

        checkHideGF = new EditorCheckbox(10, 85, "Hide Girlfriend", stageData.hideGirlfriend == true, function(checked) {
            stageData.hideGirlfriend = checked;
            if (dummyGF != null) dummyGF.visible = !checked;
        });
        toolWindow.addElement(checkHideGF);

        var btnSave = new EditorButton(10, 120, 290, 32, "Save Stage (Ctrl+S)", function() {
            saveStageJson();
        });
        toolWindow.addElement(btnSave);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        handleCameraControls(elapsed);
        handleSelectionInput();
        handleTransformInput();

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) {
            saveStageJson();
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    private function handleCameraControls(elapsed:Float):Void {
        if (FlxG.keys.pressed.Q) camStage.zoom += 0.8 * elapsed;
        if (FlxG.keys.pressed.E) camStage.zoom = Math.max(0.2, camStage.zoom - 0.8 * elapsed);

        var moveSpeed:Float = FlxG.keys.pressed.SHIFT ? 1200.0 : 500.0;
        if (FlxG.keys.pressed.I) camFollow.y -= moveSpeed * elapsed;
        if (FlxG.keys.pressed.K) camFollow.y += moveSpeed * elapsed;
        if (FlxG.keys.pressed.J) camFollow.x -= moveSpeed * elapsed;
        if (FlxG.keys.pressed.L) camFollow.x += moveSpeed * elapsed;

        camStage.focusOn(camFollow);
    }

    private function handleSelectionInput():Void {
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
        var multiplier:Float = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
        var dx:Float = 0;
        var dy:Float = 0;

        if (FlxG.keys.justPressed.LEFT) dx -= multiplier;
        if (FlxG.keys.justPressed.RIGHT) dx += multiplier;
        if (FlxG.keys.justPressed.UP) dy -= multiplier;
        if (FlxG.keys.justPressed.DOWN) dy += multiplier;

        if (dx == 0 && dy == 0) return;

        switch (currentMode) {
            case PIECE:
                if (pieceNames.length > 0) {
                    var pName = pieceNames[curPieceIndex];
                    var spr = pieceSprites.get(pName);
                    if (spr != null) {
                        spr.x += dx;
                        spr.y += dy;
                        var piecesList = (stageData.pieces != null) ? stageData.pieces : stageData.sprites;
                        if (piecesList != null) {
                            for (p in piecesList) {
                                if (p.name == pName || p.id == pName) {
                                    if (p.position != null && p.position.length >= 2) {
                                        p.position[0] = spr.x;
                                        p.position[1] = spr.y;
                                    } else {
                                        p.x = spr.x;
                                        p.y = spr.y;
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
            case BF_SPAWN:
                var pos = getSpawnPos(stageData.boyfriend, [770.0, 450.0]);
                pos[0] += dx;
                pos[1] += dy;
                setSpawnPos(stageData.boyfriend, pos[0], pos[1]);
                dummyBF.setPosition(pos[0], pos[1]);

            case DAD_SPAWN:
                var oppData = stageData.dad != null ? stageData.dad : stageData.opponent;
                var pos = getSpawnPos(oppData, [100.0, 100.0]);
                pos[0] += dx;
                pos[1] += dy;
                setSpawnPos(oppData, pos[0], pos[1]);
                dummyDad.setPosition(pos[0], pos[1]);

            case GF_SPAWN:
                var gfData = stageData.girlfriend != null ? stageData.girlfriend : stageData.gf;
                var pos = getSpawnPos(gfData, [400.0, 130.0]);
                pos[0] += dx;
                pos[1] += dy;
                setSpawnPos(gfData, pos[0], pos[1]);
                dummyGF.setPosition(pos[0], pos[1]);
        }

        updateHUD();
    }

    private function updateHUD():Void {
        var targetName = switch (currentMode) {
            case PIECE: (pieceNames.length > 0 ? 'Piece: ${pieceNames[curPieceIndex]}' : "None");
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

        infoTxt.text = 'STAGE EDITOR\n\n' +
            'Stage: $curStage\n' +
            'Target: $targetName\n' +
            'Pos: [${curPos[0]}, ${curPos[1]}]\n' +
            'Default Zoom: ${Math.round(stageData.defaultZoom * 100) / 100}x';

        var listStr = "PIECES & ANCHORS:\n";
        for (i in 0...pieceNames.length) {
            var isSel = (currentMode == PIECE && i == curPieceIndex);
            listStr += (isSel ? '> ' : '  ') + pieceNames[i] + '\n';
        }
        listStr += (currentMode == BF_SPAWN ? '> ' : '  ') + 'BF Spawn\n';
        listStr += (currentMode == DAD_SPAWN ? '> ' : '  ') + 'Dad Spawn\n';
        listStr += (currentMode == GF_SPAWN ? '> ' : '  ') + 'GF Spawn\n';
        listTxt.text = listStr;
    }

    private function saveStageJson():Void {
        var formatted = Json.stringify(stageData, "\t");
        var fileName = '$curStage.json';

        #if sys
        var targetDir = 'assets/data/stages';
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) {
            targetDir = 'mods/${ModManager.activeMods[0]}/data/stages';
        }

        var fullPath = '$targetDir/$fileName';

        try {
            if (!FileSystem.exists(targetDir)) {
                FileSystem.createDirectory(targetDir);
            }
            File.saveContent(fullPath, formatted);
            Logger.info('Saved stage definition to $fullPath', "editor");
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            Logger.error('Failed to save stage JSON: $e', "editor");
        }
        #else
        var fileRef = new FileReference();
        fileRef.save(formatted, fileName);
        #end
    }
}