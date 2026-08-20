package soulscorch.gameplay.actors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;

using StringTools;

class Character extends FlxSprite {
    public var curCharacter:String = "bf";
    public var isPlayer:Bool = false;
    public var isDie:Bool = false;

    public var holdTimer:Float = 0.0;
    public var singDuration:Float = 4.0;
    public var idleSuffix:String = "";
    public var altAnim:Bool = false;

    public var healthColor:FlxColor = 0xFF66FF33;
    public var healthIcon:String = "face";
    public var cameraOffset:Array<Float> = [0.0, 0.0];
    public var positionOffset:Array<Float> = [0.0, 0.0];

    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

    public function new(x:Float = 0, y:Float = 0, character:String = "bf", isPlayer:Bool = false) {
        super(x, y);
        this.curCharacter = (character != null && character.length > 0) ? character : (isPlayer ? "bf" : "dad");
        this.isPlayer = isPlayer;

        loadCharacter();
    }

    public function loadCharacter():Void {
        animOffsets.clear();
        antialiasing = true;

        var charDataLoaded = loadCharacterJSON(curCharacter);
        if (!charDataLoaded) {
            loadCharacterFallback(curCharacter);
        }

        dance();
    }

    private function loadCharacterJSON(char:String):Bool {
        var jsonPaths = [
            'characters/$char.json',
            'data/characters/$char.json',
            'assets/preload/characters/$char.json',
            'assets/preload/data/characters/$char.json'
        ];

        for (path in jsonPaths) {
            var resolved = AssetResolver.resolveFile(path, [".json", ""]);
            if (resolved != null) {
                var content = AssetResolver.getText(resolved);
                if (content != null && content.length > 0) {
                    try {
                        var json:Dynamic = Json.parse(content);
                        var imagePath = json.image != null ? Std.string(json.image) : 'characters/$char';

                        if (!AssetHelper.loadSparrowSafely(this, imagePath)) {
                            AssetHelper.loadSparrowSafely(this, 'characters/$char');
                        }

                        if (json.healthicon != null) healthIcon = Std.string(json.healthicon);
                        else if (json.icon != null) healthIcon = Std.string(json.icon);
                        else healthIcon = char;

                        if (json.healthbar_colors != null && json.healthbar_colors.length >= 3) {
                            healthColor = FlxColor.fromRGB(json.healthbar_colors[0], json.healthbar_colors[1], json.healthbar_colors[2]);
                        } else if (json.color != null) {
                            healthColor = FlxColor.fromString(Std.string(json.color));
                        }

                        if (json.camera_position != null) cameraOffset = [json.camera_position[0], json.camera_position[1]];
                        if (json.position != null) positionOffset = [json.position[0], json.position[1]];
                        if (json.sing_duration != null) singDuration = json.sing_duration;
                        if (json.scale != null) scale.set(json.scale, json.scale);
                        if (json.flip_x != null) flipX = json.flip_x;
                        if (isPlayer) flipX = !flipX;

                        var animList:Array<Dynamic> = json.animations != null ? cast json.animations : [];
                        for (a in animList) {
                            var animName:String = a.anim;
                            var animPrefix:String = a.name;
                            var fps:Int = a.fps != null ? a.fps : 24;
                            var loop:Bool = a.loop != null ? a.loop : false;
                            var indices:Array<Int> = a.indices != null ? cast a.indices : null;

                            if (indices != null && indices.length > 0) {
                                animation.addByIndices(animName, animPrefix, indices, "", fps, loop);
                            } else {
                                animation.addByPrefix(animName, animPrefix, fps, loop);
                            }

                            var offX:Float = (a.offsets != null && a.offsets.length > 0) ? a.offsets[0] : 0.0;
                            var offY:Float = (a.offsets != null && a.offsets.length > 1) ? a.offsets[1] : 0.0;
                            addOffset(animName, offX, offY);
                        }
                        updateHitbox();
                        return true;
                    } catch (e:Dynamic) {
                        Logger.warn('Failed parsing character JSON for $char: $e', "character");
                    }
                }
            }
        }
        return false;
    }

    private function loadCharacterFallback(char:String):Void {
        healthIcon = char;
        healthColor = isPlayer ? 0xFF66FF33 : 0xFFAF66CE;

        if (!AssetHelper.loadSparrowSafely(this, 'characters/$char')) {
            if (!AssetHelper.loadSparrowSafely(this, char)) {
                makeGraphic(150, 250, healthColor);
                return;
            }
        }

        animation.addByPrefix("idle", "idle", 24, false);
        animation.addByPrefix("singLEFT", "singLEFT", 24, false);
        animation.addByPrefix("singDOWN", "singDOWN", 24, false);
        animation.addByPrefix("singUP", "singUP", 24, false);
        animation.addByPrefix("singRIGHT", "singRIGHT", 24, false);
        addOffset("idle", 0, 0);
    }

    public function addOffset(name:String, x:Float = 0, y:Float = 0):Void {
        animOffsets.set(name, [x, y]);
    }

    public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
        if (animation.getByName(animName) == null) return;

        animation.play(animName, force, reversed, frame);

        var daOffset = animOffsets.get(animName);
        if (daOffset != null) {
            offset.set(daOffset[0], daOffset[1]);
        } else {
            offset.set(0, 0);
        }
    }

    public function playSingAnim(dir:Int, miss:Bool = false):Void {
        var dirStr = switch (dir) {
            case 0: "singLEFT";
            case 1: "singDOWN";
            case 2: "singUP";
            case 3: "singRIGHT";
            default: "singUP";
        };

        if (miss) dirStr += "miss";
        else if (altAnim && animation.getByName(dirStr + "-alt") != null) dirStr += "-alt";
        else if (altAnim && animation.getByName(dirStr + "alt") != null) dirStr += "alt";

        playAnim(dirStr, true);
        holdTimer = 0;
    }

    public function dance(force:Bool = false):Void {
        if (animation.getByName("danceLeft") != null && animation.getByName("danceRight") != null) {
            playAnim("danceLeft", force);
        } else if (animation.getByName("idle" + idleSuffix) != null) {
            playAnim("idle" + idleSuffix, force);
        } else if (animation.getByName("idle") != null) {
            playAnim("idle", force);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (animation.curAnim != null && animation.curAnim.name.startsWith("sing")) {
            holdTimer += elapsed;
            if (holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration) {
                dance();
                holdTimer = 0;
            }
        }
    }
}