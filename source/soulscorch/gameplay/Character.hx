package soulscorch.gameplay;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;
import haxe.Json;

class Character extends FlxSprite {
    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
    public var debugMode:Bool = false;
    public var isPlayer:Bool = false;
    public var curCharacter:String = "bf";
    public var holdTimer:Float = 0;
    public var singDuration:Float = 4;
    public var stunned:Bool = false;
    public var healthIcon:String = "face";
    public var positionOffset:Array<Float> = [0, 0];
    public var cameraOffset:Array<Float> = [0, 0];

    public function new(x:Float, y:Float, character:String = "bf", isPlayer:Bool = false) {
        super(x, y);
        this.curCharacter = character;
        this.isPlayer = isPlayer;
        reloadCharacter(character);
    }

    public function reloadCharacter(char:String):Void {
        this.curCharacter = char;
        var jsonPath = 'assets/data/characters/$char.json';
        var resolvedJsonPath = ModLoader.getPath(jsonPath);

        if (AssetResolver.exists(resolvedJsonPath)) {
            var rawJson = AssetResolver.getText(resolvedJsonPath);
            var data:Dynamic = Json.parse(rawJson);

            var imagePath = 'assets/images/characters/${data.image}';
            var resolvedImage = ModLoader.getPath('$imagePath.png');
            var resolvedXml = ModLoader.getPath('$imagePath.xml');

            if (AssetResolver.exists(resolvedXml)) {
                frames = FlxAtlasFrames.fromSparrow(resolvedImage, resolvedXml);
            }

            if (Reflect.hasField(data, "scale")) {
                var sc:Float = data.scale;
                scale.set(sc, sc);
                updateHitbox();
            }

            if (Reflect.hasField(data, "singDuration")) singDuration = data.singDuration;
            if (Reflect.hasField(data, "healthIcon")) healthIcon = data.healthIcon;
            if (Reflect.hasField(data, "flipX")) flipX = data.flipX != isPlayer;
            if (Reflect.hasField(data, "antialiasing")) antialiasing = data.antialiasing;

            if (Reflect.hasField(data, "animations")) {
                var anims:Array<Dynamic> = data.animations;
                for (anim in anims) {
                    var animName:String = anim.anim;
                    var animPrefix:String = anim.name;
                    var animFps:Int = anim.fps;
                    var animLoop:Bool = anim.loop;
                    var animIndices:Array<Int> = anim.indices;
                    var animOffsetsData:Array<Float> = anim.offsets;

                    if (animIndices != null && animIndices.length > 0) {
                        animation.addByIndices(animName, animPrefix, animIndices, "", animFps, animLoop);
                    } else {
                        animation.addByPrefix(animName, animPrefix, animFps, animLoop);
                    }

                    if (animOffsetsData != null) {
                        addOffset(animName, animOffsetsData[0], animOffsetsData[1]);
                    }
                }
            }
        } else {
            loadGraphic('assets/images/characters/BOYFRIEND.png', true, 150, 150);
            animation.add("idle", [0, 1, 2], 24, true);
            animation.play("idle");
        }

        playAnim("idle");
    }

    public function addOffset(anim:String, x:Float = 0, y:Float = 0):Void {
        animOffsets.set(anim, [x, y]);
    }

    public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
        if (animation.getByName(animName) != null) {
            animation.play(animName, force, reversed, frame);
        }

        var daOffset = animOffsets.get(animName);
        if (daOffset != null) {
            offset.set(daOffset[0], daOffset[1]);
        } else {
            offset.set(0, 0);
        }

        if (StringTools.startsWith(curCharacter, 'gf')) {
            if (animName == 'singLEFT') danceLeft();
            else if (animName == 'singRIGHT') danceRight();
        }
    }

    public function playSingAnim(direction:Int, miss:Bool = false):Void {
        var dirs = ["LEFT", "DOWN", "UP", "RIGHT"];
        var animName = "sing" + dirs[direction];
        if (miss) animName += "miss";
        
        playAnim(animName, true);
        holdTimer = 0;
    }

    public function dance():Void {
        if (StringTools.startsWith(curCharacter, 'gf')) {
            if (!StringTools.startsWith(animation.name, 'sing')) {
                danceLeft();
            }
        } else {
            playAnim('idle');
        }
    }

    private function danceLeft():Void {
        playAnim('danceRight');
    }

    private function danceRight():Void {
        playAnim('danceLeft');
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (animation.curAnim != null) {
            if (StringTools.startsWith(animation.curAnim.name, 'sing')) {
                holdTimer += elapsed;
                var holdThreshold:Float = 4 * 0.001 * singDuration; 
                if (holdTimer >= holdThreshold) {
                    dance();
                    holdTimer = 0;
                }
            }
        }
    }
}