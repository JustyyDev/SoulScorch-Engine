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

    private var topBar:EditorTopBar;
    private var infoTxt:FlxText;
    private var listTxt:FlxText;
    private var targetMarker:FlxSprite;

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
        camStage.zoom = 0.9;

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

        targetMarker = new FlxSprite().makeGraphic(20, 20, FlxColor.TRANSPARENT);
        for (i in 0...20) {
            targetMarker.pixels.setPixel32(i, 10, EditorTheme.ACCENT_MAGENTA);
            targetMarker.pixels.setPixel32(10, i, EditorTheme.ACCENT_MAGENTA);
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
        var candidates = ['stages/$curStage.json', 'data/stages/$curStage.json', 'assets/data/stages/$curStage.json'];
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
                pieces: []
            };
        }
        camStage.zoom = stageData.defaultZoom > 0 ? stageData.defaultZoom : 0.9;
    }

    private function buildStagePieces():Void {
        stagePiecesGroup.clear();
        pieceSprites.clear();
        pieceNames = [];

        var list = stageData.pieces != null ? stageData.pieces : stageData.sprites;
        if (list != null) {
            for (p in list) {
                var pName = p.name != null ? p.name : "piece_" + pieceNames.length;
                var posX = p.position != null && p.position.length > 0 ? p.position[0] : 0.0;
                var posY = p.position != null && p.position.length > 1 ? p.position[1] : 0.0;

                var spr = new FlxSprite(posX, posY);
                if (!AssetHelper.loadGraphicSafely(spr, p.image)) spr.makeGraphic(300, 200, EditorTheme.PANEL_BORDER);

                spr.scrollFactor.set(p.scroll != null ? p.scroll[0] : 1.0, p.scroll != null ? p.scroll[1] : 1.0);
                spr.scale.set(p.scale != null ? p.scale[0] : 1.0, p.scale != null ? p.scale[1] : 1.0);
                spr.updateHitbox();

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

        var gfPos = getSpawnPos(stageData.girlfriend, [400.0, 130.0]);
        var dadPos = getSpawnPos(stageData.dad, [100.0, 100.0]);
        var bfPos = getSpawnPos(stageData.boyfriend, [770.0, 450.0]);

        dummyGF = new Character(gfPos[0], gfPos[1], "gf", false);
        dummyDad = new Character(dadPos[0], dadPos[1], "dad", false);
        dummyBF = new Character(bfPos[0], bfPos[1], "bf", true);

        dummyGF.alpha = 0.8; dummyDad.alpha = 0.8; dummyBF.alpha = 0.8;
        add(dummyGF); add(dummyDad); add(dummyBF);
    }

    private function getSpawnPos(raw:Dynamic, fallback:Array<Float>):Array<Float> {
        if (raw == null) return fallback;
        if (Std.isOfType(raw, Array)) return [Std.parseFloat(Std.string(raw[0])), Std.parseFloat(Std.string(raw[1]))];
        return fallback;
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar('STAGE ARCHITECT [${curStage.toUpperCase()}]');
        topBar.cameras = [camHUD];
        topBar.addAction("Save (Ctrl+S)", saveStageJson);
        topBar.addAction("Exit", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        var infoWindow = new EditorWindow(15, 45, 300, 360, "Hierarchy Tree");
        infoWindow.cameras = [camHUD];
        add(infoWindow);

        infoTxt = new FlxText(10, 4, 280, "", 14);
        infoTxt.setFormat(Paths.font("vcr"), 14, EditorTheme.ACCENT_CYAN, LEFT);
        infoWindow.addElement(infoTxt);

        listTxt = new FlxText(10, 55, 280, "", 12);
        listTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        infoWindow.addElement(listTxt);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var spd = FlxG.keys.pressed.SHIFT ? 1200.0 : 500.0;
        if (FlxG.keys.pressed.I) camFollow.y -= spd * elapsed;
        if (FlxG.keys.pressed.K) camFollow.y += spd * elapsed;
        if (FlxG.keys.pressed.J) camFollow.x -= spd * elapsed;
        if (FlxG.keys.pressed.L) camFollow.x += spd * elapsed;
        camStage.focusOn(camFollow);

        if (FlxG.keys.justPressed.TAB) {
            currentMode = switch (currentMode) {
                case PIECE: BF_SPAWN;
                case BF_SPAWN: DAD_SPAWN;
                case DAD_SPAWN: GF_SPAWN;
                case GF_SPAWN: PIECE;
            };
            updateHUD();
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveStageJson();
        if (FlxG.keys.justPressed.ESCAPE) MusicBeatState.switchState(new MainMenuState());
    }

    private function updateHUD():Void {
        var targetName = switch (currentMode) {
            case PIECE: (pieceNames.length > 0 ? 'Piece: ${pieceNames[curPieceIndex]}' : "None");
            case BF_SPAWN: "BF Spawn";
            case DAD_SPAWN: "Dad Spawn";
            case GF_SPAWN: "GF Spawn";
        };

        infoTxt.text = 'Target: $targetName\nDefault Zoom: ${Math.round(stageData.defaultZoom * 100) / 100}x';

        var list = "";
        for (i in 0...pieceNames.length) list += (currentMode == PIECE && i == curPieceIndex ? '> ' : '  ') + pieceNames[i] + '\n';
        list += (currentMode == BF_SPAWN ? '> ' : '  ') + 'BF Spawn\n';
        list += (currentMode == DAD_SPAWN ? '> ' : '  ') + 'Dad Spawn\n';
        list += (currentMode == GF_SPAWN ? '> ' : '  ') + 'GF Spawn\n';
        listTxt.text = list;
    }

    private function saveStageJson():Void {
        var json = Json.stringify(stageData, "\t");

        #if sys
        var targetDir = 'assets/data/stages';
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) targetDir = 'mods/${ModManager.activeMods[0]}/data/stages';
        try {
            if (!FileSystem.exists(targetDir)) FileSystem.createDirectory(targetDir);
            File.saveContent('$targetDir/$curStage.json', json);
            EditorToast.show("Stage Layout Exported!");
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            EditorToast.show("Save Failed!", true);
        }
        #else
        var ref = new FileReference();
        ref.save(json, '$curStage.json');
        EditorToast.show("Stage File Exported!");
        #end
    }
}