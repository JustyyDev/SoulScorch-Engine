package soulscorch.ui.menus.editors.character;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.apis.NativeAPI;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.stage.Stage;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.ui.menus.editors.EditorPickerMenu;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class CharacterEditorState extends MusicBeatState {
    public var char:Character;
    public var ghostChar:Character;
    public var charName:String = "bf";
    public var isPlayer:Bool = true;

    private var camGame:FlxCamera;
    private var camHUD:FlxCamera;
    private var camFollow:FlxObject;

    private var stage:Stage;
    private var animList:Array<String> = [];
    private var curAnimIndex:Int = 0;

    private var infoText:FlxText;
    private var helpText:FlxText;
    private var animListText:FlxText;
    private var ghostText:FlxText;

    private var crosshair:FlxSprite;
    private var ghostAnimName:String = "";

    public function new(charName:String = "bf", isPlayer:Bool = true) {
        super();
        this.charName = charName;
        this.isPlayer = isPlayer;
    }

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Character Editor", 'Editing: $charName');

        setupCameras();

        stage = new Stage("stage");
        stage.load();
        add(stage);

        spawnGhostCharacter();
        spawnMainCharacter();

        setupCrosshair();
        setupHUD();

        changeAnim(0);
    }

    private function setupCameras():Void {
        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        camFollow = new FlxObject(0, 0, 1, 1);
        add(camFollow);
        camGame.follow(camFollow, LOCKON, 0.04);
        camGame.zoom = 0.9;
    }

    private function spawnGhostCharacter():Void {
        if (ghostChar != null) {
            remove(ghostChar, true);
            ghostChar.destroy();
        }

        ghostChar = new Character(0, 0, charName, isPlayer);
        ghostChar.alpha = 0.35;
        ghostChar.color = 0xFF8888FF;
        ghostChar.visible = false;
        add(ghostChar);
    }

    private function spawnMainCharacter():Void {
        if (char != null) {
            remove(char, true);
            char.destroy();
        }

        char = new Character(0, 0, charName, isPlayer);
        char.debugMode = true;
        add(char);

        animList = [];
        for (anim in char.animation.getNameList()) {
            animList.push(anim);
        }

        if (stage != null) {
            if (isPlayer) {
                stage.positionCharacters(char, null, null);
                stage.positionCharacters(ghostChar, null, null);
            } else {
                stage.positionCharacters(null, char, null);
                stage.positionCharacters(null, ghostChar, null);
            }
        }

        camFollow.setPosition(char.getMidpoint().x, char.getMidpoint().y - 50);
    }

    private function setupCrosshair():Void {
        crosshair = new FlxSprite(char.x, char.y).makeGraphic(16, 16, 0xFFFF3333);
        crosshair.screenCenter();
        add(crosshair);
    }

    private function setupHUD():Void {
        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 45, 0xAA0E141F);
        topBar.cameras = [camHUD];
        add(topBar);

        infoText = new FlxText(20, 12, FlxG.width - 40, "", 20);
        infoText.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        infoText.cameras = [camHUD];
        add(infoText);

        animListText = new FlxText(FlxG.width - 260, 60, 240, "", 16);
        animListText.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
        animListText.cameras = [camHUD];
        add(animListText);

        ghostText = new FlxText(20, 60, 300, "Ghost: None", 16);
        ghostText.setFormat(Paths.font("vcr"), 16, 0xFF8888FF, LEFT, OUTLINE, FlxColor.BLACK);
        ghostText.cameras = [camHUD];
        add(ghostText);

        var helpBg = new FlxSprite(0, FlxG.height - 40).makeGraphic(FlxG.width, 40, 0xDD0E141F);
        helpBg.cameras = [camHUD];
        add(helpBg);

        helpText = new FlxText(20, FlxG.height - 30, FlxG.width - 40, "[W/S] Anim | [ARROWS] Nudge Offset | [SPACE] Play | [G] Ghost | [CTRL+S] Save | [ESC] Exit", 15);
        helpText.setFormat(Paths.font("vcr"), 15, 0xFFAAAAAA, CENTER);
        helpText.cameras = [camHUD];
        add(helpText);

        updateText();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        // Zoom Controls
        if (FlxG.keys.pressed.E) camGame.zoom += elapsed * 0.5;
        if (FlxG.keys.pressed.Q) camGame.zoom = Math.max(0.2, camGame.zoom - (elapsed * 0.5));

        // Camera Pan
        if (FlxG.keys.pressed.I) camFollow.y -= elapsed * 400.0;
        if (FlxG.keys.pressed.K) camFollow.y += elapsed * 400.0;
        if (FlxG.keys.pressed.J) camFollow.x -= elapsed * 400.0;
        if (FlxG.keys.pressed.L) camFollow.x += elapsed * 400.0;

        // Animation Switching
        if (FlxG.keys.justPressed.W) changeAnim(-1);
        if (FlxG.keys.justPressed.S) changeAnim(1);

        if (FlxG.keys.justPressed.SPACE) {
            playCurrentAnim();
        }

        // Ghost Frame Capture
        if (FlxG.keys.justPressed.G && animList.length > 0) {
            toggleGhost();
        }

        // Offset Nudging
        var shiftMult:Float = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
        if (FlxG.keys.justPressed.LEFT) shiftOffset(shiftMult, 0);
        if (FlxG.keys.justPressed.RIGHT) shiftOffset(-shiftMult, 0);
        if (FlxG.keys.justPressed.UP) shiftOffset(0, shiftMult);
        if (FlxG.keys.justPressed.DOWN) shiftOffset(0, -shiftMult);

        // Save Offsets
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) {
            saveCharacterData();
        }

        if (Controls.instance.BACK) {
            MusicBeatState.switchState(new EditorPickerMenu());
        }

        if (char != null) {
            crosshair.setPosition(char.x - 8, char.y - 8);
        }
    }

    private function changeAnim(change:Int):Void {
        if (animList.length == 0) return;
        curAnimIndex = FlxMath.wrap(curAnimIndex + change, 0, animList.length - 1);
        playCurrentAnim();
        updateText();
    }

    private function playCurrentAnim():Void {
        if (animList.length == 0) return;
        var anim = animList[curAnimIndex];
        char.playAnim(anim, true);
    }

    private function toggleGhost():Void {
        var currentAnim = animList[curAnimIndex];
        if (ghostChar.visible && ghostAnimName == currentAnim) {
            ghostChar.visible = false;
            ghostAnimName = "";
            ghostText.text = "Ghost: None";
        } else {
            ghostChar.visible = true;
            ghostAnimName = currentAnim;
            ghostChar.playAnim(currentAnim, true);
            ghostText.text = 'Ghost: $currentAnim';
        }
    }

    private function shiftOffset(x:Float, y:Float):Void {
        if (animList.length == 0) return;
        var anim = animList[curAnimIndex];
        var off = char.animOffsets.get(anim);
        var curOff:Array<Float> = (off != null) ? off : [0.0, 0.0];

        curOff[0] += x;
        curOff[1] += y;
        char.animOffsets.set(anim, curOff);
        char.playAnim(anim, true);

        updateText();
    }

    private function updateText():Void {
        if (animList.length == 0) return;
        var anim = animList[curAnimIndex];
        var off = char.animOffsets.get(anim);
        var curOff:Array<Float> = (off != null) ? off : [0.0, 0.0];

        infoText.text = 'Character: $charName | Anim: $anim | Offset: [${curOff[0]}, ${curOff[1]}]';

        var listStr = "ANIMATIONS\n";
        for (i in 0...animList.length) {
            var prefix = (i == curAnimIndex) ? "> " : "  ";
            listStr += prefix + animList[i] + "\n";
        }
        animListText.text = listStr;
    }

    private function saveCharacterData():Void {
        #if sys
        var charJsonPath = ModLoader.getPath('assets/data/characters/$charName.json');
        if (!AssetResolver.exists(charJsonPath)) {
            charJsonPath = 'assets/data/characters/$charName.json';
        }

        var animArray:Array<Dynamic> = [];
        for (animName in animList) {
            var off = char.animOffsets.get(animName);
            var offsetVal:Array<Float> = (off != null) ? off : [0.0, 0.0];

            animArray.push({
                anim: animName,
                name: animName,
                fps: 24,
                loop: false,
                offsets: offsetVal
            });
        }

        var cameraOff = (char.positionOffset != null) ? [char.positionOffset[0], char.positionOffset[1]] : [0.0, 0.0];

        var dataToSave = {
            animations: animArray,
            image: 'characters/$charName',
            scale: char.scale.x,
            sing_duration: char.singDuration,
            healthicon: char.healthIcon,
            flip_x: char.flipX,
            no_antialiasing: !char.antialiasing,
            camera_position: cameraOff
        };

        try {
            var rawJson = Json.stringify(dataToSave, "\t");
            File.saveContent(charJsonPath, rawJson);
            NativeAPI.showMessageInfo("SoulScorch Character Editor", 'Saved offsets for "$charName" successfully to:\n$charJsonPath');
        } catch (e:Dynamic) {
            NativeAPI.showMessageError("Character Editor Error", 'Failed saving character JSON:\n$e');
        }
        #end
    }
}