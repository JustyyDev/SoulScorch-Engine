package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
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
import soulscorch.gameplay.actors.CharacterJson;
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

class CharacterEditorState extends MusicBeatState {
    public var curCharacter:String = "dad";
    public var isPlayer:Bool = false;

    private var camEditor:FlxCamera;
    private var camHUD:FlxCamera;

    private var charLayer:Character;
    private var ghostChar:Character;
    private var crosshair:FlxSprite;
    private var camFollowMarker:FlxSprite;
    private var camFollow:FlxPoint;

    private var topBar:EditorTopBar;
    private var propertiesWindow:EditorWindow;
    private var offsetsWindow:EditorWindow;

    private var curAnimTxt:FlxText;
    private var offsetTxt:FlxText;
    private var animListTxt:FlxText;

    private var animList:Array<String> = [];
    private var curAnimIndex:Int = 0;
    private var showGhost:Bool = true;

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
        camEditor.zoom = 0.9;

        var bg = new FlxSprite().makeGraphic(FlxG.width * 3, FlxG.height * 3, EditorTheme.BG_DARK);
        bg.screenCenter();
        bg.scrollFactor.set(0, 0);
        add(bg);

        var ground = new FlxSprite(0, FlxG.height * 0.75).makeGraphic(FlxG.width * 4, 2, EditorTheme.ACCENT_PURPLE);
        ground.screenCenter(X);
        ground.scrollFactor.set(1, 1);
        add(ground);

        crosshair = new FlxSprite().makeGraphic(18, 18, FlxColor.TRANSPARENT);
        for (i in 0...18) {
            crosshair.pixels.setPixel32(i, 9, EditorTheme.ACCENT_MAGENTA);
            crosshair.pixels.setPixel32(9, i, EditorTheme.ACCENT_MAGENTA);
        }
        crosshair.dirty = true;
        crosshair.scrollFactor.set(1, 1);
        add(crosshair);

        camFollowMarker = new FlxSprite().makeGraphic(14, 14, EditorTheme.ACCENT_CYAN);
        camFollowMarker.scrollFactor.set(1, 1);
        add(camFollowMarker);

        reloadCharacters();
        setupWindows();

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
        playCurrentAnim();
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar('ACTOR STUDIO [${curCharacter.toUpperCase()}]');
        topBar.cameras = [camHUD];
        topBar.addAction("Save (Ctrl+S)", saveOffsetsJson);
        topBar.addAction("Exit", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        var infoWindow = new EditorWindow(15, 45, 300, 360, "Animation Matrix");
        infoWindow.cameras = [camHUD];
        add(infoWindow);

        curAnimTxt = new FlxText(10, 4, 280, "Anim: idle", 16);
        curAnimTxt.setFormat(Paths.font("vcr"), 16, EditorTheme.ACCENT_CYAN, LEFT);
        infoWindow.addElement(curAnimTxt);

        offsetTxt = new FlxText(10, 26, 280, "Offset: [0, 0]", 14);
        offsetTxt.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_MUTED, LEFT);
        infoWindow.addElement(offsetTxt);

        animListTxt = new FlxText(10, 50, 280, "", 12);
        animListTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        infoWindow.addElement(animListTxt);

        propertiesWindow = new EditorWindow(FlxG.width - 325, 45, 310, 250, "Actor Settings");
        propertiesWindow.cameras = [camHUD];
        add(propertiesWindow);

        var stepperScale = new EditorNumericStepper(10, 8, 290, "Scale", charLayer.scale.x, 0.1, 5.0, 0.05, 2, function(v) {
            charLayer.scale.set(v, v);
            charLayer.updateHitbox();
            if (ghostChar != null) { ghostChar.scale.set(v, v); ghostChar.updateHitbox(); }
        });
        propertiesWindow.addElement(stepperScale);

        var checkGhost = new EditorCheckbox(10, 44, "Ghost Overlay", showGhost, function(c) {
            showGhost = c;
            if (ghostChar != null) ghostChar.alpha = showGhost ? 0.35 : 0.0;
        });
        propertiesWindow.addElement(checkGhost);

        var checkFlip = new EditorCheckbox(160, 44, "Flip X Axis", charLayer.flipX, function(c) {
            charLayer.flipX = c;
            if (ghostChar != null) ghostChar.flipX = c;
        });
        propertiesWindow.addElement(checkFlip);

        offsetsWindow = new EditorWindow(FlxG.width - 325, 305, 310, 180, "Camera Focus Anchor");
        offsetsWindow.cameras = [camHUD];
        add(offsetsWindow);

        var stepperCamX = new EditorNumericStepper(10, 8, 290, "Cam Offset X", charLayer.cameraOffset[0], -600, 600, 5.0, 1, function(v) {
            charLayer.cameraOffset[0] = v;
            updateCrosshair();
        });
        offsetsWindow.addElement(stepperCamX);

        var stepperCamY = new EditorNumericStepper(10, 44, 290, "Cam Offset Y", charLayer.cameraOffset[1], -600, 600, 5.0, 1, function(v) {
            charLayer.cameraOffset[1] = v;
            updateCrosshair();
        });
        offsetsWindow.addElement(stepperCamY);

        updateHUDText();
        updateCrosshair();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        handleCameraControls(elapsed);
        handleAnimationControls();
        handleOffsetControls();

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveOffsetsJson();
        if (FlxG.keys.justPressed.ESCAPE) MusicBeatState.switchState(new MainMenuState());
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
        if (animList.length == 0) return;

        if (FlxG.keys.justPressed.W) {
            curAnimIndex = FlxMath.wrap(curAnimIndex - 1, 0, animList.length - 1);
            playCurrentAnim();
        }
        if (FlxG.keys.justPressed.S) {
            curAnimIndex = FlxMath.wrap(curAnimIndex + 1, 0, animList.length - 1);
            playCurrentAnim();
        }
        if (FlxG.keys.justPressed.SPACE) playCurrentAnim();
    }

    private function handleOffsetControls():Void {
        if (charLayer == null || animList.length == 0) return;

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

    private function playCurrentAnim():Void {
        if (charLayer == null || animList.length == 0) return;
        var anim = animList[curAnimIndex];
        charLayer.playAnim(anim, true);

        var curOffset = charLayer.animOffsets.get(anim);
        charLayer.offset.set(curOffset != null ? curOffset[0] : 0, curOffset != null ? curOffset[1] : 0);

        if (ghostChar != null && showGhost) {
            ghostChar.playAnim(anim, true);
            var gOffset = ghostChar.animOffsets.get(anim);
            ghostChar.offset.set(gOffset != null ? gOffset[0] : 0, gOffset != null ? gOffset[1] : 0);
        }

        updateCrosshair();
        updateHUDText();
    }

    private function updateCrosshair():Void {
        if (charLayer != null) {
            crosshair.setPosition(charLayer.x, charLayer.y);
            camFollowMarker.setPosition(
                charLayer.getMidpoint().x + charLayer.cameraOffset[0] - 7,
                charLayer.getMidpoint().y + charLayer.cameraOffset[1] - 7
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
        for (i in 0...animList.length) {
            var name = animList[i];
            var aOff = charLayer.animOffsets.get(name);
            var str = aOff != null ? '[${aOff[0]}, ${aOff[1]}]' : '[0, 0]';
            list += (i == curAnimIndex ? '> $name: $str <\n' : '  $name: $str\n');
        }
        animListTxt.text = list;
    }

    private function saveOffsetsJson():Void {
        var charJson:CharacterJson = {
            animations: [],
            image: 'characters/$curCharacter',
            scale: charLayer.scale.x,
            sing_duration: charLayer.singDuration,
            healthicon: charLayer.healthIcon,
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
}