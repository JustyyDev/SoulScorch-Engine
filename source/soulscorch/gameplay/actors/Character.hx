package soulscorch.gameplay.actors;

import flixel.FlxG;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.FunkinSprite;

using StringTools;

class Character extends FunkinSprite {
    public var curCharacter:String = "bf";
    public var isPlayer:Bool = false;
    public var isDie:Bool = false;

    public var holdTimer:Float = 0.0;
    public var singDuration:Float = 4.0;
    public var idleSuffix:String = "";
    public var altAnim:Bool = false;
    public var stunned:Bool = false;
    public var danced:Bool = false;

    public var healthColor:FlxColor = 0xFF66FF33;
    public var healthIcon:String = "face";
    public var cameraOffset:Array<Float> = [0.0, 0.0];
    public var positionOffset:Array<Float> = [0.0, 0.0];

    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

    private var _hasDancePair:Bool = false;
    private var _idleAnimName:String = "idle";
    private var _altSingSuffix:Array<String> = ["", "", "", ""];
    private var _isSingingAnim:Bool = false;

    private static var _xmsoulPathCache:Map<String, String> = new Map<String, String>();
    private static var _jsonPathCache:Map<String, String> = new Map<String, String>();

    public function new(x:Float = 0, y:Float = 0, character:String = "bf", isPlayer:Bool = false) {
        super(x, y);
        this.curCharacter = (character != null && character.length > 0) ? character : (isPlayer ? "bf" : "dad");
        this.isPlayer = isPlayer;

        loadCharacter();
    }

    public function loadCharacter():Void {
        animOffsets.clear();
        antialiasing = true;

        var xmsoulLoaded = loadCharacterXMSoul(curCharacter);
        if (!xmsoulLoaded) {
            var charDataLoaded = loadCharacterJSON(curCharacter);
            if (!charDataLoaded) {
                loadCharacterFallback(curCharacter);
            }
        }

        refreshAnimationCaches();
        dance();
    }

    private function refreshAnimationCaches():Void {
        _hasDancePair = animation.getByName("danceLeft") != null && animation.getByName("danceRight") != null;
        _idleAnimName = (animation.getByName("idle" + idleSuffix) != null) ? ("idle" + idleSuffix) : "idle";

        var dirs = ["singLEFT", "singDOWN", "singUP", "singRIGHT"];
        for (i in 0...4) {
            var base = dirs[i];
            if (animation.getByName(base + "-alt") != null) {
                _altSingSuffix[i] = "-alt";
            } else if (animation.getByName(base + "alt") != null) {
                _altSingSuffix[i] = "alt";
            } else {
                _altSingSuffix[i] = "";
            }
        }
    }

    private function loadCharacterXMSoul(char:String):Bool {
        var cacheKey = char.toLowerCase().trim();
        var cachedPath = _xmsoulPathCache.exists(cacheKey) ? _xmsoulPathCache.get(cacheKey) : null;

        var paths:Array<String>;
        if (cachedPath != null) {
            if (cachedPath.length == 0) return false;
            paths = [cachedPath];
        } else {
            paths = [
                'characters/$char.xmsoul',
                'data/characters/$char.xmsoul',
                'characters/$char/$char.xmsoul',
                'assets/preload/characters/$char.xmsoul',
                'assets/preload/data/characters/$char.xmsoul'
            ];
        }

        var foundPath:String = null;

        for (path in paths) {
            var access = XMSoul.parse(path);
            if (access != null) {
                try {
                    foundPath = path;
                    var imagePath = XMSoul.getAttr(access, "sprite", XMSoul.getAttr(access, "image", 'characters/$char'));
                    
                    loadSprite(imagePath);

                    healthIcon = XMSoul.getAttr(access, "icon", char);
                    healthColor = access.has.color ? FlxColor.fromString(access.att.color) : (isPlayer ? 0xFF66FF33 : 0xFFAF66CE);
                    singDuration = XMSoul.getFloatAttr(access, "singDuration", 4.0);
                    flipX = XMSoul.getBoolAttr(access, "flipX", false);
                    if (isPlayer) flipX = !flipX;

                    if (access.has.scale) {
                        var sc = Std.parseFloat(access.att.scale);
                        scale.set(sc, sc);
                    } else {
                        scale.set(1.0, 1.0);
                    }

                    if (access.has.cameraOffsetX && access.has.cameraOffsetY) {
                        cameraOffset = [Std.parseFloat(access.att.cameraOffsetX), Std.parseFloat(access.att.cameraOffsetY)];
                    }
                    if (access.has.positionX && access.has.positionY) {
                        positionOffset = [Std.parseFloat(access.att.positionX), Std.parseFloat(access.att.positionY)];
                    }

                    if (access.hasNode.anim) {
                        for (animNode in access.nodes.anim) {
                            var animName = animNode.att.name;
                            var animPrefix = animNode.att.prefix;
                            var fps = XMSoul.getIntAttr(animNode, "fps", 24);
                            var loop = XMSoul.getBoolAttr(animNode, "loop", false);

                            if (animNode.has.indices) {
                                var indicesStr = animNode.att.indices.split(",");
                                var indices:Array<Int> = [];
                                for (idx in indicesStr) {
                                    indices.push(Std.parseInt(idx.trim()));
                                }
                                animation.addByIndices(animName, animPrefix, indices, "", fps, loop);
                            } else {
                                animation.addByPrefix(animName, animPrefix, fps, loop);
                            }

                            var offX = animNode.has.offsetX ? Std.parseFloat(animNode.att.offsetX) : 0.0;
                            var offY = animNode.has.offsetY ? Std.parseFloat(animNode.att.offsetY) : 0.0;
                            if (animNode.has.offsets) {
                                var parts = animNode.att.offsets.split(",");
                                if (parts.length >= 2) {
                                    offX = Std.parseFloat(parts[0].trim());
                                    offY = Std.parseFloat(parts[1].trim());
                                }
                            }
                            addOffset(animName, offX, offY);
                        }
                    }

                    updateHitbox();
                    _xmsoulPathCache.set(cacheKey, foundPath);
                    return true;
                } catch (e:Dynamic) {
                    Logger.warn('Failed parsing character .xmsoul for $char: $e', "character");
                }
            }
        }

        if (cachedPath == null) {
            _xmsoulPathCache.set(cacheKey, "");
        }
        return false;
    }

    private function loadCharacterJSON(char:String):Bool {
        var cacheKey = char.toLowerCase().trim();
        var cachedPath = _jsonPathCache.exists(cacheKey) ? _jsonPathCache.get(cacheKey) : null;

        var jsonPaths:Array<String>;
        if (cachedPath != null) {
            if (cachedPath.length == 0) return false;
            jsonPaths = [cachedPath];
        } else {
            jsonPaths = [
                'characters/$char.json',
                'data/characters/$char.json',
                'assets/preload/characters/$char.json',
                'assets/preload/data/characters/$char.json'
            ];
        }

        var foundPath:String = null;

        for (path in jsonPaths) {
            var resolved = AssetResolver.resolveFile(path, [".json", ""]);
            if (resolved != null) {
                foundPath = path;
                var content = AssetResolver.getText(resolved);
                if (content != null && content.length > 0) {
                    try {
                        var json:Dynamic = Json.parse(content);
                        var imagePath = json.image != null ? Std.string(json.image) : 'characters/$char';

                        loadSprite(imagePath);

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
                        _jsonPathCache.set(cacheKey, foundPath);
                        return true;
                    } catch (e:Dynamic) {
                        Logger.warn('Failed parsing character JSON for $char: $e', "character");
                    }
                }
            }
        }

        if (cachedPath == null) {
            _jsonPathCache.set(cacheKey, "");
        }
        return false;
    }

    private function loadCharacterFallback(char:String):Void {
        healthIcon = char;
        healthColor = isPlayer ? 0xFF66FF33 : 0xFFAF66CE;

        if (!loadSprite('characters/$char')) {
            if (!loadSprite(char)) {
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

    override public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
        if (animation.getByName(animName) == null) return;

        animation.play(animName, force, reversed, frame);
        _isSingingAnim = animName.startsWith("sing");

        var daOffset = animOffsets.get(animName);
        if (daOffset != null) {
            offset.set(daOffset[0], daOffset[1]);
        } else {
            offset.set(0, 0);
        }
    }

    public function playSingAnim(dir:Int, miss:Bool = false):Void {
        var lane = (dir >= 0 && dir < 4) ? dir : 2;
        var dirStr = switch (lane) {
            case 0: "singLEFT";
            case 1: "singDOWN";
            case 2: "singUP";
            case 3: "singRIGHT";
            default: "singUP";
        };

        if (miss) dirStr += "miss";
        else if (altAnim) dirStr += _altSingSuffix[lane];

        playAnim(dirStr, true);
        holdTimer = 0;
    }

    public function dance(force:Bool = false):Void {
        if (stunned) return;
        if (_hasDancePair) {
            danced = !danced;
            playAnim(danced ? "danceRight" : "danceLeft", force);
        } else if (animation.getByName(_idleAnimName) != null) {
            playAnim(_idleAnimName, force);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (!_isSingingAnim && animation.curAnim != null) {
            _isSingingAnim = animation.curAnim.name.startsWith("sing");
        }

        if (_isSingingAnim) {
            holdTimer += elapsed;
            if (holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration) {
                dance();
                holdTimer = 0;
            }
        }
    }
}