package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import soulscorch.core.Scene;
import soulscorch.gameplay.Character;
import soulscorch.assets.Paths;
import soulscorch.assets.AssetHelper;
#if sys
import sys.io.File;
#end
import haxe.Json;

class CharacterEditorState extends Scene {
    var charSprite:Character;
    var ghostSprite:Character;
    var camFollow:FlxSprite;
    var uiText:FlxText;
    
    var curAnimIndex:Int = 0;
    var animList:Array<String> = [];
    var charId:String;
    var isPlayer:Bool;

    public function new(charId:String = "bf", isPlayer:Bool = true) {
        super();
        this.charId = charId;
        this.isPlayer = isPlayer;
    }

    override public function create():Void {
        super.create();
        FlxG.mouse.visible = true;

        var bg = new FlxSprite(-600, -200);
        AssetHelper.loadGraphicSafely(bg, 'images/stages/default/stageback.png');
        bg.scrollFactor.set(0.9, 0.9);
        add(bg);

        ghostSprite = new Character(0, 0, charId, isPlayer);
        ghostSprite.alpha = 0.4;
        ghostSprite.playAnim('idle');
        add(ghostSprite);

        charSprite = new Character(0, 0, charId, isPlayer);
        add(charSprite);

        for (anim in charSprite.animOffsets.keys()) {
            animList.push(anim);
        }

        camFollow = new FlxSprite(charSprite.getMidpoint().x, charSprite.getMidpoint().y).makeGraphic(1, 1, 0x00000000);
        add(camFollow);
        FlxG.camera.follow(camFollow, null, 1);

        uiText = new FlxText(10, 10, FlxG.width, "", 20);
        uiText.scrollFactor.set(0, 0);
        add(uiText);

        updateAnimDisplay();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var speed = FlxG.keys.pressed.SHIFT ? 10 : 2;
        if (FlxG.keys.pressed.I) camFollow.y -= speed;
        if (FlxG.keys.pressed.K) camFollow.y += speed;
        if (FlxG.keys.pressed.J) camFollow.x -= speed;
        if (FlxG.keys.pressed.L) camFollow.x += speed;

        if (FlxG.keys.justPressed.W) changeAnim(-1);
        if (FlxG.keys.justPressed.S) changeAnim(1);

        if (FlxG.keys.justPressed.SPACE) {
            charSprite.playAnim(animList[curAnimIndex], true);
        }

        var shiftMult = FlxG.keys.pressed.SHIFT ? 10 : 1;
        var currentAnim = animList[curAnimIndex];
        var offsets = charSprite.animOffsets.get(currentAnim);

        if (offsets != null) {
            if (FlxG.keys.justPressed.LEFT) offsets[0] += shiftMult;
            if (FlxG.keys.justPressed.RIGHT) offsets[0] -= shiftMult;
            if (FlxG.keys.justPressed.UP) offsets[1] += shiftMult;
            if (FlxG.keys.justPressed.DOWN) offsets[1] -= shiftMult;
            
            charSprite.playAnim(currentAnim);
        }

        uiText.text = 'CHARACTER EDITOR: $charId\n\n' +
                      'Current Anim: $currentAnim\n' +
                      'Offset X: ${offsets != null ? offsets[0] : 0}\n' +
                      'Offset Y: ${offsets != null ? offsets[1] : 0}\n\n' +
                      '[W/S] Change Animation | [ARROWS] Move Offset | [CTRL+S] Save';

        if (FlxG.keys.justPressed.S && FlxG.keys.pressed.CONTROL) {
            saveCharacter();
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.mouse.visible = false;
            FlxG.switchState(new MainMenuState());
        }
    }

    function changeAnim(change:Int):Void {
        curAnimIndex += change;
        if (curAnimIndex >= animList.length) curAnimIndex = 0;
        if (curAnimIndex < 0) curAnimIndex = animList.length - 1;

        charSprite.playAnim(animList[curAnimIndex]);
        updateAnimDisplay();
    }

    function updateAnimDisplay():Void {
        charSprite.playAnim(animList[curAnimIndex]);
    }

    function saveCharacter():Void {
        #if sys
        var charData:Dynamic = {
            image: charId,
            scale: charSprite.scale.x,
            singDuration: charSprite.singDuration,
            healthIcon: charSprite.healthIcon,
            position: charSprite.positionOffset,
            cameraPosition: charSprite.cameraOffset,
            flipX: charSprite.flipX,
            antialiasing: charSprite.antialiasing,
            animations: []
        };

        for (anim in animList) {
            var offset = charSprite.animOffsets.get(anim);
            var loopStatus = false;
            var animFrame = charSprite.animation.getByName(anim);
            if (animFrame != null) {
                loopStatus = animFrame.looped;
            }

            var animData:Dynamic = {};
            Reflect.setField(animData, "anim", anim);
            Reflect.setField(animData, "name", anim);
            Reflect.setField(animData, "fps", 24);
            Reflect.setField(animData, "loop", loopStatus);
            Reflect.setField(animData, "indices", []);
            Reflect.setField(animData, "offsets", [offset != null ? offset[0] : 0, offset != null ? offset[1] : 0]);

            charData.animations.push(animData);
        }

        File.saveContent('assets/data/characters/$charId.json', Json.stringify(charData, "\t"));
        Sys.println("Character offsets saved!");
        #end
    }
}