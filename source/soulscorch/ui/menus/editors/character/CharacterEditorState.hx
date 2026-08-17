package soulscorch.ui.menus.editors.character;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import lime.system.Clipboard;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.actors.Character;
import soulscorch.scripting.ModLoader;

class CharacterEditorState extends MusicBeatState {
    public var curCharName:String = "bf";
    public var character:Character;
    public var ghostChar:Character;

    public var camGame:FlxCamera;
    public var camHUD:FlxCamera;

    public var animList:Array<String> = [];
    public var curAnimIndex:Int = 0;

    private var crosshair:FlxSprite;
    private var camFollowPointer:FlxSprite;
    private var infoText:FlxText;
    private var helpText:FlxText;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Character Editor", 'Editing: $curCharName');

        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        var grid = FlxGridOverlay.create(40, 40, 3200, 2400, true, 0xFF2A2A38, 0xFF1D1D28);
        grid.screenCenter();
        add(grid);

        // Origin Crosshair
        crosshair = new FlxSprite().makeGraphic(12, 12, 0xFFFF0000);
        crosshair.screenCenter();
        add(crosshair);

        // Camera Offset Target Marker
        camFollowPointer = new FlxSprite().makeGraphic(16, 16, 0xFF00FFFF);
        add(camFollowPointer);

        reloadCharacter(curCharName);

        setupUI();
    }

    private function reloadCharacter(charName:String):Void {
        if (character != null) remove(character, true);
        if (ghostChar != null) remove(ghostChar, true);

        this.curCharName = charName;

        // Ghost character for alignment comparison
        ghostChar = new Character(FlxG.width * 0.5, FlxG.height * 0.5, charName, false);
        ghostChar.alpha = 0.35;
        ghostChar.color = 0xFF4444FF;
        add(ghostChar);

        character = new Character(FlxG.width * 0.5, FlxG.height * 0.5, charName, false);
        character.debugMode = true;
        add(character);

        animList = [];
        for (animKey in character.animOffsets.keys()) {
            animList.push(animKey);
        }

        if (animList.length == 0) {
            animList.push("idle");
        }

        curAnimIndex = 0;
        playCurrentAnim();
        updateCamFollowPointer();
    }

    private function setupUI():Void {
        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 40, 0xCC0E141E);
        topBar.cameras = [camHUD];
        add(topBar);

        infoText = new FlxText(15, 8, FlxG.width - 30, "", 18);
        infoText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, LEFT);
        infoText.cameras = [camHUD];
        add(infoText);

        helpText = new FlxText(15, FlxG.height - 110, FlxG.width - 30,
            "[W/S] Cycle Animation | [Arrows] Shift Offset (Hold Shift: x10)\n[SPACE] Replay Animation | [C] Update Camera Target | [R] Reset Camera\n[E/Q] Zoom Camera | [CTRL + S] Export JSON to Clipboard | [ESC] Exit",
            16);
        helpText.setFormat(Paths.font("vcr"), 16, 0xFFFFCC00, LEFT, OUTLINE, FlxColor.BLACK);
        helpText.cameras = [camHUD];
        add(helpText);

        updateText();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var shiftMult:Float = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;

        // Camera dragging and zooming
        if (FlxG.mouse.pressedRight) {
            camGame.scroll.x -= FlxG.mouse.deltaX / camGame.zoom;
            camGame.scroll.y -= FlxG.mouse.deltaY / camGame.zoom;
        }

        if (FlxG.keys.justPressed.E) camGame.zoom += 0.1;
        if (FlxG.keys.justPressed.Q) camGame.zoom = Math.max(0.2, camGame.zoom - 0.1);
        if (FlxG.keys.justPressed.R) {
            camGame.zoom = 1.0;
            camGame.focusOn(character.getMidpoint());
        }

        // Animation Cycling
        if (FlxG.keys.justPressed.W) changeAnim(-1);
        if (FlxG.keys.justPressed.S) changeAnim(1);
        if (FlxG.keys.justPressed.SPACE) playCurrentAnim();

        // Offset Nudging
        var curAnim = animList[curAnimIndex];
        var offsets = character.animOffsets.get(curAnim);
        if (offsets == null) {
            offsets = [0.0, 0.0];
            character.animOffsets.set(curAnim, offsets);
        }

        if (FlxG.keys.justPressed.LEFT) { offsets[0] += 1 * shiftMult; character.playAnim(curAnim, true); }
        if (FlxG.keys.justPressed.RIGHT) { offsets[0] -= 1 * shiftMult; character.playAnim(curAnim, true); }
        if (FlxG.keys.justPressed.UP) { offsets[1] += 1 * shiftMult; character.playAnim(curAnim, true); }
        if (FlxG.keys.justPressed.DOWN) { offsets[1] -= 1 * shiftMult; character.playAnim(curAnim, true); }

        // Camera Point Adjustment
        if (FlxG.keys.justPressed.C) {
            character.cameraOffset[0] = Math.round(FlxG.mouse.x - character.x);
            character.cameraOffset[1] = Math.round(FlxG.mouse.y - character.y);
            updateCamFollowPointer();
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) {
            exportCharacterJson();
        }

        if (Controls.instance.BACK) {
            MusicBeatState.switchState(new EditorPickerMenu());
        }

        updateText();
    }

    private function changeAnim(change:Int):Void {
        curAnimIndex = FlxMath.wrap(curAnimIndex + change, 0, animList.length - 1);
        playCurrentAnim();
    }

    private function playCurrentAnim():Void {
        if (animList.length > 0) {
            var anim = animList[curAnimIndex];
            character.playAnim(anim, true);
            ghostChar.playAnim(anim, true);
        }
    }

    private function updateCamFollowPointer():Void {
        var mid = character.getMidpoint();
        camFollowPointer.setPosition(mid.x + character.cameraOffset[0], mid.y + character.cameraOffset[1]);
    }

    private function updateText():Void {
        var anim = animList.length > 0 ? animList[curAnimIndex] : "None";
        var curOffset = character.animOffsets.get(anim);
        var xOff:Float = curOffset != null ? curOffset[0] : 0.0;
        var yOff:Float = curOffset != null ? curOffset[1] : 0.0;

        infoText.text = 'Character: $curCharName | Anim: $anim ($curAnimIndex/${animList.length}) | Offset: [$xOff, $yOff] | Cam: [${character.cameraOffset[0]}, ${character.cameraOffset[1]}]';
    }

    private function exportCharacterJson():Void {
        var animArray:Array<Dynamic> = [];
        for (animName in animList) {
            var off = character.animOffsets.get(animName);
            animArray.push({
                anim: animName,
                name: animName,
                fps: 24,
                loop: false,
                offsets: off != null ? off : [0, 0]
            });
        }

        var schema:Dynamic = {
            image: curCharName,
            scale: character.scale.x,
            singDuration: character.singDuration,
            healthIcon: character.healthIcon,
            flipX: character.flipX,
            antialiasing: character.antialiasing,
            cameraOffset: character.cameraOffset,
            positionOffset: character.positionOffset,
            animations: animArray
        };

        var output = Json.stringify(schema, "\t");
        Clipboard.text = output;
        FlxG.camera.flash(FlxColor.GREEN, 0.4);
    }
}