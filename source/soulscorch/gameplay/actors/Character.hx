package soulscorch.gameplay.actors;

import flixel.FlxSprite;
import haxe.Json;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;

typedef CharacterAnimation = {
    var anim:String;
    var name:String;
    var fps:Int;
    var loop:Bool;
    var ?indices:Array<Int>;
    var ?offsets:Array<Float>;
}

typedef CharacterData = {
    var image:String;
    var ?scale:Float;
    var ?singDuration:Float;
    var ?healthIcon:String;
    var ?flipX:Bool;
    var ?antialiasing:Bool;
    var ?positionOffset:Array<Float>;
    var ?cameraOffset:Array<Float>;
    var ?danceIdle:Bool;
    var ?animations:Array<CharacterAnimation>;
}

class Character extends FlxSprite implements IBeatReceiver {
    public var animOffsets:Map<String, Array<Float>> = new Map();
    public var isPlayer:Bool = false;
    public var curCharacter:String = "bf";
    public var holdTimer:Float = 0.0;
    public var singDuration:Float = 4.0;
    public var stunned:Bool = false;

    public var healthIcon:String = "face";
    public var positionOffset:Array<Float> = [0.0, 0.0];
    public var cameraOffset:Array<Float> = [0.0, 0.0];
    public var isDanceIdle:Bool = false;

    public var danced:Bool = false;
    public var debugMode:Bool = false;

    public function new(x:Float = 0, y:Float = 0, character:String = "bf", isPlayer:Bool = false) {
        super(x, y);
        this.isPlayer = isPlayer;
        reloadCharacter(character);
    }

    /**
     * Parses the JSON character schema and initializes animations, offsets, and textures.
     */
    public function reloadCharacter(char:String):Void {
        this.curCharacter = char;
        animOffsets.clear();

        var jsonPath = 'assets/data/characters/$char.json';
        var resolvedJsonPath = ModLoader.getPath(jsonPath);

        if (AssetResolver.exists(resolvedJsonPath)) {
            var rawJson = AssetResolver.getText(resolvedJsonPath);
            var data:CharacterData = Json.parse(rawJson);

            var imagePath = 'characters/${data.image}';
            frames = Paths.getFrames(imagePath);

            if (data.scale != null) {
                scale.set(data.scale, data.scale);
                updateHitbox();
            }

            if (data.singDuration != null) singDuration = data.singDuration;
            if (data.healthIcon != null) healthIcon = data.healthIcon;
            if (data.flipX != null) flipX = (data.flipX != isPlayer);
            if (data.antialiasing != null) antialiasing = data.antialiasing;
            if (data.positionOffset != null) positionOffset = data.positionOffset;
            if (data.cameraOffset != null) cameraOffset = data.cameraOffset;
            if (data.danceIdle != null) isDanceIdle = data.danceIdle;

            if (data.animations != null) {
                for (anim in data.animations) {
                    if (anim.indices != null && anim.indices.length > 0) {
                        animation.addByIndices(anim.anim, anim.name, anim.indices, "", anim.fps, anim.loop);
                    } else {
                        animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop);
                    }

                    if (anim.offsets != null && anim.offsets.length >= 2) {
                        addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
                    }
                }
            }

            Logger.info('Loaded character: $char (${data.image})', "character");
        } else {
            Logger.warn('Character JSON missing: $jsonPath. Using default placeholder.', "character");
            loadGraphic(Paths.image("characters/BOYFRIEND"), true, 150, 150);
            animation.add("idle", [0, 1, 2], 24, true);
        }

        dance();
    }

    public function addOffset(anim:String, x:Float = 0, y:Float = 0):Void {
        animOffsets.set(anim, [x, y]);
    }

    public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
        if (animation.getByName(animName) == null) return;

        animation.play(animName, force, reversed, frame);

        var offsetVal = animOffsets.get(animName);
        if (offsetVal != null) {
            offset.set(offsetVal[0], offsetVal[1]);
        } else {
            offset.set(0, 0);
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
        if (debugMode) return;

        if (isDanceIdle || StringTools.startsWith(curCharacter, "gf")) {
            danced = !danced;
            playAnim(danced ? 'danceRight' : 'danceLeft');
        } else if (animation.getByName("idle") != null) {
            playAnim("idle");
        }
    }

    public function stepHit(step:Int):Void {}

    public function beatHit(beat:Int):Void {
        if (animation.curAnim == null || !StringTools.startsWith(animation.curAnim.name, "sing")) {
            dance();
        }
    }

    public function measureHit(measure:Int):Void {}

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (animation.curAnim != null && StringTools.startsWith(animation.curAnim.name, "sing")) {
            holdTimer += elapsed;
            var threshold:Float = (Conductor.stepCrochet * singDuration) / 1000.0;
            if (holdTimer >= threshold) {
                dance();
                holdTimer = 0;
            }
        }
    }
}