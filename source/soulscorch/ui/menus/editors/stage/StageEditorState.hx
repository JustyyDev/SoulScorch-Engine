package soulscorch.ui.menus.editors.stage;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import lime.system.Clipboard;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.stage.Stage;
import soulscorch.ui.menus.editors.EditorPickerMenu;

class StageEditorState extends MusicBeatState {
    public var stageId:String = "stage";
    public var stage:Stage;

    public var bfMarker:FlxSprite;
    public var dadMarker:FlxSprite;
    public var gfMarker:FlxSprite;

    public var camGame:FlxCamera;
    public var camHUD:FlxCamera;

    private var curSelectedTarget:String = "bf";
    private var infoText:FlxText;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Stage Editor", 'Editing: $stageId');

        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        stage = new Stage(stageId);
        add(stage);
        stage.load();

        // Actor Placement Target Markers
        bfMarker = new FlxSprite(stage.bfPosition[0], stage.bfPosition[1]).makeGraphic(60, 60, 0xFF33FF33);
        dadMarker = new FlxSprite(stage.dadPosition[0], stage.dadPosition[1]).makeGraphic(60, 60, 0xFFFF3333);
        gfMarker = new FlxSprite(stage.gfPosition[0], stage.gfPosition[1]).makeGraphic(60, 60, 0xFFA033FF);

        add(gfMarker);
        add(dadMarker);
        add(bfMarker);

        setupUI();
    }

    private function setupUI():Void {
        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 40, 0xDD0D111A);
        topBar.cameras = [camHUD];
        add(topBar);

        infoText = new FlxText(15, 8, FlxG.width - 30, "", 18);
        infoText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, LEFT);
        infoText.cameras = [camHUD];
        add(infoText);

        var help = new FlxText(15, FlxG.height - 70, FlxG.width - 30,
            "[TAB] Cycle Target (BF/DAD/GF) | [ARROWS] Move Position (Hold Shift: x10)\n[Q/E] Adjust Camera Zoom | [CTRL + S] Export JSON | [ESC] Exit", 16);
        help.setFormat(Paths.font("vcr"), 16, 0xFFFFCC00, LEFT, OUTLINE, FlxColor.BLACK);
        help.cameras = [camHUD];
        add(help);

        updateText();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var shiftMult:Float = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;

        // Viewport Dragging
        if (FlxG.mouse.pressedRight) {
            camGame.scroll.x -= FlxG.mouse.deltaX / camGame.zoom;
            camGame.scroll.y -= FlxG.mouse.deltaY / camGame.zoom;
        }

        if (FlxG.keys.justPressed.E) camGame.zoom += 0.05;
        if (FlxG.keys.justPressed.Q) camGame.zoom = Math.max(0.1, camGame.zoom - 0.05);

        // Cycle selected character position marker
        if (FlxG.keys.justPressed.TAB) {
            curSelectedTarget = (curSelectedTarget == "bf") ? "dad" : ((curSelectedTarget == "dad") ? "gf" : "bf");
            updateText();
        }

        var targetMarker = (curSelectedTarget == "bf") ? bfMarker : ((curSelectedTarget == "dad") ? dadMarker : gfMarker);
        var targetPos = (curSelectedTarget == "bf") ? stage.bfPosition : ((curSelectedTarget == "dad") ? stage.dadPosition : stage.gfPosition);

        if (FlxG.keys.pressed.LEFT) { targetPos[0] -= 1 * shiftMult; targetMarker.x = targetPos[0]; }
        if (FlxG.keys.pressed.RIGHT) { targetPos[0] += 1 * shiftMult; targetMarker.x = targetPos[0]; }
        if (FlxG.keys.pressed.UP) { targetPos[1] -= 1 * shiftMult; targetMarker.y = targetPos[1]; }
        if (FlxG.keys.pressed.DOWN) { targetPos[1] += 1 * shiftMult; targetMarker.y = targetPos[1]; }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) {
            exportStageJson();
        }

        if (Controls.instance.BACK) {
            MusicBeatState.switchState(new EditorPickerMenu());
        }

        updateText();
    }

    private function updateText():Void {
        var targetPos = (curSelectedTarget == "bf") ? stage.bfPosition : ((curSelectedTarget == "dad") ? stage.dadPosition : stage.gfPosition);
        infoText.text = 'Stage: $stageId | Target: ${curSelectedTarget.toUpperCase()} | Pos: [${targetPos[0]}, ${targetPos[1]}] | Zoom: ${Math.round(camGame.zoom * 100) / 100}';
    }

    private function exportStageJson():Void {
        var schema:Dynamic = {
            name: stageId,
            defaultZoom: stage.defaultZoom,
            boyfriend: stage.bfPosition,
            opponent: stage.dadPosition,
            girlfriend: stage.gfPosition,
            sprites: []
        };

        var output = Json.stringify(schema, "\t");
        Clipboard.text = output;
        FlxG.camera.flash(FlxColor.GREEN, 0.4);
    }
}