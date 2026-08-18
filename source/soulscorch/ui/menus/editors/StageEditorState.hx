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
import soulscorch.gameplay.stage.StageData;
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

    // --- Cameras ---
    private var camStage:FlxCamera;
    private var camHUD:FlxCamera;
    private var camFollow:FlxPoint;

    // --- Stage Data ---
    private var stageData:StageJson;
    private var stagePiecesGroup:FlxSpriteGroup;
    private var pieceSprites:Map<String, FlxSprite> = new Map();

    // --- Actor Dummies ---
    private var dummyBF:Character;
    private var dummyDad:Character;
    private var dummyGF:Character;

    // --- Selection State ---
    private var currentMode:SelectedTargetType = PIECE;
    private var curPieceIndex:Int = 0;
    private var pieceNames:Array<String> = [];

    // --- HUD Overlays ---
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
        updateHUD();

        FlxG.mouse.visible = true;
    }

    private function loadStageData():Void {
        var rawText:String = AssetResolver.getText('stages/$curStage');
        if (rawText.length == 0) {
            rawText = AssetResolver.getText('assets/stages/$curStage.json');
        }
        if (rawText.length == 0) {
            rawText = AssetResolver.getText('data/stages/$curStage.json');
        }

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
                boyfriend: {position: [770.0, 450.0], scale: 1.0, cameraOffset: [0.0, 0.0]},
                dad: {position: [100.0, 100.0], scale: 1.0, cameraOffset: [0.0, 0.0]},
                girlfriend: {position: [400.0, 130.0], scale: 1.0, cameraOffset: [0.0, 0.0]},
                pieces: [
                    {
                        name: "stageback",
                        image: "stages/stageback",
                        position: [-600.0, -200.0],
                        scroll: [0.9, 0.9],
                        scale: [1.0, 1.0],
                        layer: "behindGF"
                    },
                    {
                        name: "stagefront",
                        image: "stages/stagefront",
                        position: [-650.0, 600.0],
                        scroll: [1.0, 1.0],
                        scale: [1.1, 1.1],
                        layer: "behindDad"
                    }
                ]
            };
        }

        camStage.zoom = stageData.defaultZoom;
    }

    private function buildStagePieces():Void {
        stagePiecesGroup.clear();
        pieceSprites.clear();
        pieceNames = [];

        if (stageData.pieces != null) {
            for (p in stageData.pieces) {
                var spr = new FlxSprite(p.position[0], p.position[1]);
                if (!AssetHelper.loadGraphicSafely(spr, p.image)) {
                    spr.makeGraphic(400, 300, 0x88AA00FF);
                }
                
                // Safe JSON Fallbacks
                var scX = (p.scroll != null && p.scroll.length > 0) ? p.scroll[0] : 1.0;
                var scY = (p.scroll != null && p.scroll.length > 1) ? p.scroll[1] : 1.0;
                var scaleX = (p.scale != null && p.scale.length > 0) ? p.scale[0] : 1.0;
                var scaleY = (p.scale != null && p.scale.length > 1) ? p.scale[1] : 1.0;
                
                spr.scrollFactor.set(scX, scY);
                spr.scale.set(scaleX, scaleY);
                spr.updateHitbox();
                spr.antialiasing = (p.antialiasing != null) ? p.antialiasing : true;

                pieceSprites.set(p.name, spr);
                pieceNames.push(p.name);
                stagePiecesGroup.add(spr);
            }
        }
    }

    private function spawnDummies():Void {
        if (dummyGF != null) { remove(dummyGF, true); dummyGF.destroy(); }
        if (dummyDad != null) { remove(dummyDad, true); dummyDad.destroy(); }
        if (dummyBF != null) { remove(dummyBF, true); dummyBF.destroy(); }

        dummyGF = new Character(stageData.girlfriend.position[0], stageData.girlfriend.position[1], "gf", false);
        dummyDad = new Character(stageData.dad.position[0], stageData.dad.position[1], "dad", false);
        dummyBF = new Character(stageData.boyfriend.position[0], stageData.boyfriend.position[1], "bf", true);

        dummyGF.alpha = 0.85;
        dummyDad.alpha = 0.85;
        dummyBF.alpha = 0.85;

        add(dummyGF);
        add(dummyDad);
        add(dummyBF);
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
            "[TAB] - Switch Target (Piece/BF/Dad/GF)\n" +
            "[W / S] - Next / Prev Stage Piece\n" +
            "[ARROWS] - Move Selected (1px)\n" +
            "[SHIFT + ARROWS] - Move Selected (10px)\n" +
            "[Q / E] - Zoom Cam In / Out\n" +
            "[I / J / K / L] - Pan Editor Camera\n" +
            "[Z / X] - Stage Zoom Preset (+/-)\n" +
            "[CTRL + S] - Export Stage JSON\n" +
            "[ESCAPE] - Exit to Menu",
            13
        );
        helpTxt.setFormat(Paths.font("vcr"), 13, 0xFFDDDDDD, LEFT);
        helpTxt.scrollFactor.set();
        helpTxt.cameras = [camHUD];
        add(helpTxt);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        handleCameraControls(elapsed);
        handleSelectionInput();
        handleTransformInput();

        if (FlxG.keys.justPressed.Z) {
            stageData.defaultZoom = Math.min(2.0, stageData.defaultZoom + 0.05);
            camStage.zoom = stageData.defaultZoom;
            updateHUD();
        }
        if (FlxG.keys.justPressed.X) {
            stageData.defaultZoom = Math.max(0.4, stageData.defaultZoom - 0.05);
            camStage.zoom = stageData.defaultZoom;
            updateHUD();
        }

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
                        for (p in stageData.pieces) {
                            if (p.name == pName) {
                                p.position[0] = spr.x;
                                p.position[1] = spr.y;
                                break;
                            }
                        }
                    }
                }
            case BF_SPAWN:
                stageData.boyfriend.position[0] += dx;
                stageData.boyfriend.position[1] += dy;
                dummyBF.setPosition(stageData.boyfriend.position[0], stageData.boyfriend.position[1]);
            case DAD_SPAWN:
                stageData.dad.position[0] += dx;
                stageData.dad.position[1] += dy;
                dummyDad.setPosition(stageData.dad.position[0], stageData.dad.position[1]);
            case GF_SPAWN:
                stageData.girlfriend.position[0] += dx;
                stageData.girlfriend.position[1] += dy;
                dummyGF.setPosition(stageData.girlfriend.position[0], stageData.girlfriend.position[1]);
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
                curPos = stageData.boyfriend.position;
                targetMarker.setPosition(dummyBF.x, dummyBF.y);
            case DAD_SPAWN:
                curPos = stageData.dad.position;
                targetMarker.setPosition(dummyDad.x, dummyDad.y);
            case GF_SPAWN:
                curPos = stageData.girlfriend.position;
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
        var targetDir = 'assets/stages';
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