package soulscorch.gameplay.actors;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.CharacterJson;

using StringTools;

class Character extends FlxSprite {
    public var curCharacter:String = "bf";
    public var isPlayer:Bool = false;
    public var debugMode:Bool = false;

    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
    public var positionOffset:Array<Float> = [0.0, 0.0];
    public var cameraOffset:Array<Float> = [0.0, 0.0];

    public var holdTimer:Float = 0.0;
    public var singDuration:Float = 4.0;
    public var healthIcon:String = "face";
    public var healthColor:FlxColor = 0xFFA1A1A1;
    public var originalFlipX:Bool = false;

    public var danced:Bool = false;
    public var specialAnim:Bool = false;
    public var stunned:Bool = false;

    public function new(x:Float, y:Float, curCharacter:String = "bf", isPlayer:Bool = false) {
        super(x, y);

        this.curCharacter = (curCharacter != null && curCharacter.length > 0) ? curCharacter : "bf";
        this.isPlayer = isPlayer;
        loadCharacter();
    }

    public function loadCharacter():Void {
        animOffsets.clear();

        var charJsonCandidates = [
            'characters/$curCharacter.json',
            'data/characters/$curCharacter.json',
            'assets/characters/$curCharacter.json',
            'assets/data/characters/$curCharacter.json',
            'assets/preload/data/characters/$curCharacter.json',
            'assets/preload/characters/$curCharacter.json'
        ];

        var resolvedJson:String = null;
        for (c in charJsonCandidates) {
            resolvedJson = AssetResolver.resolveFile(c, [".json", ""]);
            if (resolvedJson != null) break;
        }

        var imageToLoad:String = 'characters/$curCharacter';
        var charScale:Float = 1.0;

        if (resolvedJson != null) {
            try {
                var rawJson:String = AssetResolver.getText(resolvedJson);
                var data:CharacterJson = Json.parse(rawJson);

                if (data.image != null && data.image.length > 0) {
                    imageToLoad = data.image;
                }

                healthIcon = (data.healthIcon != null) ? data.healthIcon : ((data.healthicon != null) ? data.healthicon : curCharacter);
                singDuration = (data.singDuration != null) ? data.singDuration : ((data.sing_duration != null) ? data.sing_duration : 4.0);
                originalFlipX = (data.flipX != null) ? data.flipX : ((data.flip_x != null) ? data.flip_x : false);
                
                var noAnti:Bool = (data.noAntialiasing != null) ? data.noAntialiasing : ((data.no_antialiasing != null) ? data.no_antialiasing : false);
                antialiasing = !noAnti;

                if (data.scale != null && data.scale > 0) {
                    charScale = data.scale;
                }

                if (data.position != null && data.position.length >= 2) {
                    positionOffset = [data.position[0], data.position[1]];
                }

                var camPos = (data.cameraPosition != null) ? data.cameraPosition : data.camera_position;
                if (camPos != null && camPos.length >= 2) {
                    cameraOffset = [camPos[0], camPos[1]];
                }

                var colors = (data.healthBarColor != null) ? data.healthBarColor : data.healthbar_colors;
                if (colors != null && colors.length >= 3) {
                    healthColor = FlxColor.fromRGB(colors[0], colors[1], colors[2]);
                } else {
                    healthColor = isPlayer ? 0xFF66FF33 : 0xFFFF0000;
                }

                AssetHelper.loadSparrowSafely(this, imageToLoad);

                if (data.animations != null) {
                    for (anim in data.animations) {
                        var fps:Int = (anim.fps != null) ? Std.int(anim.fps) : 24;
                        var loop:Bool = (anim.loop != null) ? anim.loop : false;

                        if (anim.indices != null && anim.indices.length > 0) {
                            animation.addByIndices(anim.anim, anim.name, anim.indices, "", fps, loop);
                        } else {
                            animation.addByPrefix(anim.anim, anim.name, fps, loop);
                        }

                        if (anim.offsets != null && anim.offsets.length >= 2) {
                            addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
                        } else {
                            addOffset(anim.anim, 0, 0);
                        }
                    }
                }
            } catch (e:Dynamic) {
                Logger.error('Failed parsing character data for $curCharacter: $e', "actor");
            }
        } else {
            AssetHelper.loadSparrowSafely(this, imageToLoad);
            animation.addByPrefix("idle", "BF idle dance", 24, false);
            animation.addByPrefix("singLEFT", "BF NOTE LEFT0", 24, false);
            animation.addByPrefix("singDOWN", "BF NOTE DOWN0", 24, false);
            animation.addByPrefix("singUP", "BF NOTE UP0", 24, false);
            animation.addByPrefix("singRIGHT", "BF NOTE RIGHT0", 24, false);
            addOffset("idle", 0, 0);
            addOffset("singLEFT", 12, -6);
            addOffset("singDOWN", -10, -50);
            addOffset("singUP", -29, 27);
            addOffset("singRIGHT", -41, -7);
        }

        scale.set(charScale, charScale);
        updateHitbox();

        flipX = (isPlayer != originalFlipX);
        dance();
    }

    public function addOffset(name:String, x:Float = 0, y:Float = 0):Void {
        animOffsets.set(name, [x, y]);
    }

    public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
        if (!animation.exists(animName)) return;

        animation.play(animName, force, reversed, frame);

        var off = animOffsets.get(animName);
        if (off != null) {
            offset.set(off[0], off[1]);
        } else {
            offset.set(0, 0);
        }

        if (curCharacter == "gf" || curCharacter.startsWith("gf-")) {
            if (animName == "singLEFT") danced = true;
            else if (animName == "singRIGHT") danced = false;
            if (animName == "singUP" || animName == "singDOWN") danced = !danced;
        }
    }

    public function dance(force:Bool = false):Void {
        if (!debugMode && !specialAnim) {
            if (animation.exists("danceLeft") && animation.exists("danceRight")) {
                danced = !danced;
                playAnim(danced ? "danceRight" : "danceLeft", force);
            } else if (animation.exists("idle")) {
                playAnim("idle", force);
            }
        }
    }

    public function playSingAnim(direction:Int, miss:Bool = false):Void {
        var anims = ["singLEFT", "singDOWN", "singUP", "singRIGHT"];
        var anim = anims[direction % 4] + (miss ? "miss" : "");
        
        if (animation.exists(anim)) {
            playAnim(anim, true);
            holdTimer = 0;
        }
    }

    override public function update(elapsed:Float):Void {
        if (!debugMode && animation.curAnim != null) {
            if (animation.curAnim.name.startsWith("sing")) {
                holdTimer += elapsed;
                if (holdTimer >= (singDuration * (1 / 24.0))) {
                    dance();
                    holdTimer = 0;
                }
            }

            if (animation.curAnim.finished && animation.exists(animation.curAnim.name + "-loop")) {
                playAnim(animation.curAnim.name + "-loop");
            }
        }

        super.update(elapsed);
    }
}