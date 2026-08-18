package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.events.Event;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.StorageUtil;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.actors.CharacterData;
import soulscorch.gameplay.stage.Stage;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class CharacterEditorState extends MusicBeatState {
    public var curCharacter:String = "dad";
    public var isPlayer:Bool = false;

    // --- Viewports & Cameras ---
    private var camEditor:FlxCamera;
    private var camHUD:FlxCamera;

    // --- Visual Elements ---
    private var stageBackdrop:Stage;
    private var charLayer:Character;
    private var ghostChar:Character;
    private var crosshair:FlxSprite;
    private var camFollow:FlxPoint;

    // --- UI Info ---
    private var animListTxt:FlxText;
    private var curAnimTxt:FlxText;
    private var offsetTxt:FlxText;
    private var helpTxt:FlxText;

    // --- Animation State ---
    private var animList:Array<String> = [];
    private var curAnimIndex:Int = 0;
    private var showGhost:Bool = true;

    public function new(?char:String = "dad", ?isPlayer:Bool = false) {
        super();
        this.curCharacter = char;
        this.isPlayer = isPlayer;
    }

    override public function create():Void {
        super.create();

        // 1. Setup Camera Layers
        camEditor = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camEditor);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camEditor, true);

        camFollow = FlxPoint.get(FlxG.width * 0.5, FlxG.height * 0.5);
        camEditor.target = null;
        camEditor.zoom = 0.9;

        // 2. Add Background Grid / Stage
        var bg = new FlxSprite().makeGraphic(FlxG.width * 3, FlxG.height * 3, 0xFF2A2634);
        bg.screenCenter();
        bg.scrollFactor.set(0, 0);
        add(bg);

        // Ground Guide Line
        var groundLine = new FlxSprite(0, FlxG.height * 0.75).makeGraphic(FlxG.width * 4, 4, 0xFF555066);
        groundLine.screenCenter(X);
        groundLine.scrollFactor.set(1, 1);
        add(groundLine);

        // 3. Load Characters
        reloadCharacters();

        // 4. Center Crosshair
        crosshair = new FlxSprite().makeGraphic(20, 20, FlxColor.TRANSPARENT);
        // Draw crosshair shape
        for (i in 0...20) {
            crosshair.pixels.setPixel32(i, 10, 0xFFFF0044);
            crosshair.pixels.setPixel32(10, i, 0xFFFF0044);
        }
        crosshair.scrollFactor.set(1, 1);
        add(crosshair);

        // 5. Setup Editor HUD
        setupHUD();

        updateCrosshair();
        updateHUDText();

        FlxG.mouse.visible = true;
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

        // Ghost character for reference overlay
        ghostChar = new Character(FlxG.width * 0.5 - 150, FlxG.height * 0.2, curCharacter, isPlayer);
        ghostChar.alpha = showGhost ? 0.35 : 0.0;
        ghostChar.color = 0xFF8888FF;
        add(ghostChar);

        // Active Character
        charLayer = new Character(FlxG.width * 0.5 - 150, FlxG.height * 0.2, curCharacter, isPlayer);
        add(charLayer);

        // Extract Animations
        animList = [];
        if (charLayer.animation != null) {
            @:privateAccess
            for (key in charLayer.animation._animations.keys()) {
                animList.push(key);
            }
        }

        if (animList.length == 0) {
            animList = ["idle", "singUP", "singRIGHT", "singDOWN", "singLEFT"];
        }

        curAnimIndex = 0;
        playCurrentAnim();
    }

    private function setupHUD():Void {
        var hudBox = new FlxSprite(10, 10).makeGraphic(320, 380, 0xBB000000);
        hudBox.scrollFactor.set(0, 0);
        hudBox.cameras = [camHUD];
        add(hudBox);

        curAnimTxt = new FlxText(20, 15, 300, "Anim: idle", 20);
        curAnimTxt.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        curAnimTxt.scrollFactor.set(0, 0);
        curAnimTxt.cameras = [camHUD];
        add(curAnimTxt);

        offsetTxt = new FlxText(20, 45, 300, "Offset: [0, 0]", 18);
        offsetTxt.setFormat(Paths.font("vcr"), 18, 0xFF00FFCC, LEFT, OUTLINE, FlxColor.BLACK);
        offsetTxt.scrollFactor.set(0, 0);
        offsetTxt.cameras = [camHUD];
        add(offsetTxt);

        animListTxt = new FlxText(20, 75, 300, "", 14);
        animListTxt.setFormat(Paths.font("vcr"), 14, 0xFFDDDDDD, LEFT);
        animListTxt.scrollFactor.set(0, 0);
        animListTxt.cameras = [camHUD];
        add(animListTxt);

        var helpBox = new FlxSprite(FlxG.width - 340, 10).makeGraphic(330, 260, 0xBB000000);
        helpBox.scrollFactor.set(0, 0);
        helpBox.cameras = [camHUD];
        add(helpBox);

        helpTxt = new FlxText(FlxG.width - 330, 15, 310,
            "CONTROLS:\n" +
            "[W / S] - Next / Prev Animation\n" +
            "[ARROWS] - Move Offsets (1px)\n" +
            "[SHIFT + ARROWS] - Move Offsets (10px)\n" +
            "[SPACE] - Replay Animation\n" +
            "[Q / E] - Zoom Cam In/Out\n" +
            "[I / J / K / L] - Pan Camera\n" +
            "[G] - Toggle Ghost Overlay\n" +
            "[F] - Flip Character (FlipX)\n" +
            "[CTRL + S] - Save Offsets JSON\n" +
            "[ESCAPE] - Exit Editor",
            14
        );
        helpTxt.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        helpTxt.scrollFactor.set(0, 0);
        helpTxt.cameras = [camHUD];
        add(helpTxt);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        handleCameraControls(elapsed);
        handleAnimationControls();
        handleOffsetControls();

        // Ghost Toggle
        if (FlxG.keys.justPressed.G) {
            showGhost = !showGhost;
            if (ghostChar != null) ghostChar.alpha = showGhost ? 0.35 : 0.0;
        }

        // Flip Character
        if (FlxG.keys.justPressed.F && charLayer != null) {
            charLayer.flipX = !charLayer.flipX;
            if (ghostChar != null) ghostChar.flipX = charLayer.flipX;
        }

        // Save JSON
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) {
            saveOffsetsJson();
        }

        // Exit
        if (FlxG.keys.justPressed.ESCAPE) {
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    private function handleCameraControls(elapsed:Float):Void {
        // Zooming
        if (FlxG.keys.pressed.Q) camEditor.zoom += 0.8 * elapsed;
        if (FlxG.keys.pressed.E) camEditor.zoom = Math.max(0.2, camEditor.zoom - 0.8 * elapsed);

        // Panning
        var moveSpeed:Float = FlxG.keys.pressed.SHIFT ? 1000.0 : 400.0;
        if (FlxG.keys.pressed.I) camFollow.y -= moveSpeed * elapsed;
        if (FlxG.keys.pressed.K) camFollow.y += moveSpeed * elapsed;
        if (FlxG.keys.pressed.J) camFollow.x -= moveSpeed * elapsed;
        if (FlxG.keys.pressed.L) camFollow.x += moveSpeed * elapsed;

        camEditor.focusOn(camFollow);
    }

    private function handleAnimationControls():Void {
        if (animList.length == 0) return;

        if (FlxG.keys.justPressed.W) {
            curAnimIndex = FlxMath.wrap(curAnimIndex - 1, 0, animList.length - 1);
            playCurrentAnim();
        }
        if (FlxG.keys.justPressed.S) {
            curAnimIndex = FlxMath.wrap(curAnimIndex + 1, 0, animList.length - 1);
            playCurrentAnim();
        }

        if (FlxG.keys.justPressed.SPACE) {
            playCurrentAnim();
        }
    }

    private function handleOffsetControls():Void {
        if (charLayer == null || animList.length == 0) return;

        var anim = animList[curAnimIndex];
        var multiplier:Float = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
        var changed:Bool = false;

        var curOffset = charLayer.animOffsets.get(anim);
        if (curOffset == null) {
            curOffset = [0.0, 0.0];
            charLayer.animOffsets.set(anim, curOffset);
        }

        if (FlxG.keys.justPressed.LEFT) {
            curOffset[0] += multiplier;
            changed = true;
        }
        if (FlxG.keys.justPressed.RIGHT) {
            curOffset[0] -= multiplier;
            changed = true;
        }
        if (FlxG.keys.justPressed.UP) {
            curOffset[1] += multiplier;
            changed = true;
        }
        if (FlxG.keys.justPressed.DOWN) {
            curOffset[1] -= multiplier;
            changed = true;
        }

        if (changed) {
            charLayer.offset.set(curOffset[0], curOffset[1]);
            updateCrosshair();
            updateHUDText();
        }
    }

    private function playCurrentAnim():Void {
        if (charLayer == null || animList.length == 0) return;

        var anim = animList[curAnimIndex];
        charLayer.playAnim(anim, true);

        var curOffset = charLayer.animOffsets.get(anim);
        if (curOffset != null) {
            charLayer.offset.set(curOffset[0], curOffset[1]);
        } else {
            charLayer.offset.set(0, 0);
        }

        // Keep ghost locked to first frame of idle
        if (ghostChar != null && showGhost) {
            ghostChar.playAnim("idle", true);
            var idleOffset = ghostChar.animOffsets.get("idle");
            if (idleOffset != null) {
                ghostChar.offset.set(idleOffset[0], idleOffset[1]);
            }
        }

        updateCrosshair();
        updateHUDText();
    }

    private function updateCrosshair():Void {
        if (charLayer != null) {
            crosshair.setPosition(charLayer.x, charLayer.y);
        }
    }

    private function updateHUDText():Void {
        if (animList.length == 0) return;

        var curAnim = animList[curAnimIndex];
        curAnimTxt.text = 'Anim: $curAnim (${curAnimIndex + 1}/${animList.length})';

        var curOffset = charLayer.animOffsets.get(curAnim);
        if (curOffset != null) {
            offsetTxt.text = 'Offset: [${curOffset[0]}, ${curOffset[1]}]';
        } else {
            offsetTxt.text = 'Offset: [0, 0]';
        }

        var listStr:String = "ANIMATIONS:\n";
        for (i in 0...animList.length) {
            var name = animList[i];
            var off = charLayer.animOffsets.get(name);
            var offStr = off != null ? '[${off[0]}, ${off[1]}]' : '[0, 0]';
            if (i == curAnimIndex) {
                listStr += '> $name: $offStr <\n';
            } else {
                listStr += '  $name: $offStr\n';
            }
        }
        animListTxt.text = listStr;
    }

    private function saveOffsetsJson():Void {
        var charJson:Dynamic = {
            animations: [],
            healthIcon: charLayer.healthIcon,
            flipX: charLayer.flipX,
            scale: charLayer.scale.x
        };

        for (anim in animList) {
            var off = charLayer.animOffsets.get(anim);
            var offArray = off != null ? [off[0], off[1]] : [0.0, 0.0];
            charJson.animations.push({
                anim: anim,
                name: anim,
                fps: 24,
                loop: false,
                offsets: offArray
            });
        }

        var formattedJson = Json.stringify(charJson, "\t");
        var savePath = 'characters/$curCharacter.json';

        #if sys
        var targetFile = 'assets/$savePath';
        try {
            File.saveContent(targetFile, formattedJson);
            Logger.info('Saved character JSON to $targetFile', "editor");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[EDITOR] Successfully saved $curCharacter offsets to $targetFile');
            }
            FlxG.sound.play(Paths.sound("confirmMenu"));
        } catch (e:Dynamic) {
            Logger.error('Failed to save character file: $e', "editor");
        }
        #else
        var fileRef = new FileReference();
        fileRef.save(formattedJson, '$curCharacter.json');
        #end
    }
}