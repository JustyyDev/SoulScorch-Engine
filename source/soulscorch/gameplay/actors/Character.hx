package soulscorch.gameplay.actors;

import flixel.FlxSprite;
import haxe.Json;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.scripting.mod.ModLoader;

using StringTools;

class Character extends FlxSprite {
    public var curCharacter:String = "bf";
    public var isPlayer:Bool = false;
    public var debugMode:Bool = false;

    public var animOffsets:Map<String, Array<Float>> = new Map();
    public var positionOffset:Array<Float> = [0.0, 0.0];
    public var holdTimer:Float = 0.0;
    public var singDuration:Float = 4.0;
    public var healthIcon:String = "face";
    public var originalFlipX:Bool = false;

    public function new(x:Float, y:Float, curCharacter:String = "bf", isPlayer:Bool = false) {
        super(x, y);

        this.curCharacter = (curCharacter != null && curCharacter.length > 0) ? curCharacter : "bf";
        this.isPlayer = isPlayer;
        loadCharacter();
    }

    public function loadCharacter():Void {
        var charJsonCandidates = [
            'assets/data/characters/$curCharacter.json',
            'assets/characters/$curCharacter.json',
            'data/characters/$curCharacter.json',
            'characters/$curCharacter.json'
        ];

        var resolvedJson:String = null;
        for (c in charJsonCandidates) {
            var test = ModLoader.getPath(c);
            if (AssetResolver.exists(test)) {
                resolvedJson = test;
                break;
            }
        }

        var imageToLoad = 'characters/$curCharacter';

        if (resolvedJson != null) {
            try {
                var rawJson = AssetResolver.getText(resolvedJson);
                var data:Dynamic = Json.parse(rawJson);

                if (data.image != null) imageToLoad = data.image;
                if (data.healthicon != null) healthIcon = data.healthicon;
                if (data.sing_duration != null) singDuration = data.sing_duration;
                if (data.flip_x != null) originalFlipX = data.flip_x;
                if (data.no_antialiasing != null) antialiasing = !data.no_antialiasing;
                if (data.position != null) positionOffset = [data.position[0], data.position[1]];

                AssetHelper.loadSparrowSafely(this, imageToLoad);

                if (data.animations != null) {
                    for (anim in cast(data.animations, Array<Dynamic>)) {
                        var fps:Int = (anim.fps != null) ? anim.fps : 24;
                        var loop:Bool = (anim.loop != null) ? anim.loop : false;

                        if (anim.indices != null && cast(anim.indices, Array<Dynamic>).length > 0) {
                            animation.addByIndices(anim.anim, anim.name, anim.indices, "", fps, loop);
                        } else {
                            animation.addByPrefix(anim.anim, anim.name, fps, loop);
                        }

                        if (anim.offsets != null) {
                            animOffsets.set(anim.anim, [anim.offsets[0], anim.offsets[1]]);
                        }
                    }
                }
            } catch (e:Dynamic) {}
        } else {
            // Default fallback
            AssetHelper.loadSparrowSafely(this, 'characters/$curCharacter');
            animation.addByPrefix("idle", "BF idle dance", 24, false);
            animation.addByPrefix("singLEFT", "BF NOTE LEFT0", 24, false);
            animation.addByPrefix("singDOWN", "BF NOTE DOWN0", 24, false);
            animation.addByPrefix("singUP", "BF NOTE UP0", 24, false);
            animation.addByPrefix("singRIGHT", "BF NOTE RIGHT0", 24, false);
            animOffsets.set("idle", [0.0, 0.0]);
        }

        flipX = (isPlayer != originalFlipX);
        playAnim("idle");
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        if (!animation.exists(animName)) return;

        animation.play(animName, force);

        var off = animOffsets.get(animName);
        if (off != null) {
            offset.set(off[0], off[1]);
        } else {
            offset.set(0, 0);
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
                    playAnim("idle");
                    holdTimer = 0;
                }
            }
        }

        super.update(elapsed);
    }
}