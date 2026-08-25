package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.gameplay.notes.NoteSkinManager;

using StringTools;

class NoteSplash extends FlxSprite {
    public var splashSkin:String = "default";
    public var splashScale:Float = 1.0;
    public var splashAlpha:Float = 0.6;
    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

    public function new(x:Float = 0, y:Float = 0, ?skin:String = "default") {
        super(x, y);
        this.splashSkin = (skin != null && skin.length > 0) ? skin : "default";
        loadSplashSkin(this.splashSkin);
        scrollFactor.set();
    }

    public function loadSplashSkin(skin:String = "default"):Void {
        animOffsets.clear();
        this.splashSkin = skin;

        var xmsoulLoaded = loadSplashXMSoul(skin);
        if (!xmsoulLoaded) {
            loadDefaultSplashAtlas(skin);
        }
    }

    private function loadSplashXMSoul(skin:String):Bool {
        var paths = [
            'noteskins/splashes/$skin.xmsoul',
            'data/noteskins/splashes/$skin.xmsoul',
            'images/ui/game/splashes/$skin.xmsoul',
            'ui/game/splashes/$skin.xmsoul',
            'data/splashes/$skin.xmsoul',
            'splashes/$skin.xmsoul',
            'assets/preload/data/splashes/$skin.xmsoul'
        ];

        for (path in paths) {
            var access = XMSoul.parse(path);
            if (access != null) {
                var imagePath = XMSoul.getAttr(access, "sprite", XMSoul.getAttr(access, "image", 'ui/game/splashes/$skin'));
                if (!AssetHelper.loadSparrowSafely(this, imagePath)) {
                    AssetHelper.loadSparrowSafely(this, 'ui/game/splashes/default');
                }

                splashScale = XMSoul.getFloatAttr(access, "scale", 1.0);
                splashAlpha = XMSoul.getFloatAttr(access, "alpha", 0.6);
                antialiasing = XMSoul.getBoolAttr(access, "antialiasing", true);

                if (access.hasNode.resolve("lanes")) {
                    var lanesNode = access.node.resolve("lanes");
                    for (laneNode in lanesNode.nodes.resolve("lane")) {
                        var laneId = XMSoul.getIntAttr(laneNode, "id", 0);
                        var animIdx = 1;
                        for (anim in laneNode.nodes.resolve("anim")) {
                            var animName = 'splash $animIdx $laneId';
                            var prefix = XMSoul.getAttr(anim, "prefix", "");
                            var offX = XMSoul.getFloatAttr(anim, "x", 0);
                            var offY = XMSoul.getFloatAttr(anim, "y", 0);

                            animation.addByPrefix(animName, prefix, 24, false);
                            animOffsets.set(animName, [offX, offY]);
                            animIdx++;
                        }
                    }
                } else if (access.hasNode.anim) {
                    for (animNode in access.nodes.anim) {
                        var animName = animNode.att.name;
                        var prefix = animNode.att.prefix;
                        var fps = XMSoul.getIntAttr(animNode, "fps", 24);
                        var loop = XMSoul.getBoolAttr(animNode, "loop", false);

                        if (animNode.has.indices) {
                            var indices:Array<Int> = [];
                            for (i in animNode.att.indices.split(",")) indices.push(Std.parseInt(i.trim()));
                            animation.addByIndices(animName, prefix, indices, "", fps, loop);
                        } else {
                            animation.addByPrefix(animName, prefix, fps, loop);
                        }

                        var offStr = animNode.has.offsets ? animNode.att.offsets.split(",") : ["0", "0"];
                        animOffsets.set(animName, [Std.parseFloat(offStr[0].trim()), Std.parseFloat(offStr[1].trim())]);
                    }
                }
                return true;
            }
        }
        return false;
    }

    private function loadDefaultSplashAtlas(skin:String):Void {
        var loaded = AssetHelper.loadSparrowSafely(this, 'ui/game/splashes/$skin');
        if (!loaded && skin == "default") loaded = AssetHelper.loadSparrowSafely(this, 'ui/game/splashes/default');
        if (!loaded) loaded = AssetHelper.loadSparrowSafely(this, 'ui/game/splashes/noteSplashes');
        if (!loaded) loaded = AssetHelper.loadSparrowSafely(this, 'noteSplashes');

        if (loaded && frames != null) {
            setupDefaultSplashAnimations();
        } else {
            makeGraphic(120, 120, 0x00FFFFFF);
        }

        splashScale = 1.0;
        splashAlpha = 0.6;
        antialiasing = true;
    }

    private function setupDefaultSplashAnimations():Void {
        var directions = ["purple", "blue", "green", "red"];
        for (i in 0...directions.length) {
            var dir = directions[i];
            animation.addByPrefix('splash 1 $i', 'note impact 1 $dir', 24, false);
            if (animation.getByName('splash 1 $i') == null) {
                animation.addByPrefix('splash 1 $i', 'note splash $dir 1', 24, false);
            }

            animation.addByPrefix('splash 2 $i', 'note impact 2 $dir', 24, false);
            if (animation.getByName('splash 2 $i') == null) {
                animation.addByPrefix('splash 2 $i', 'note splash $dir 2', 24, false);
            }

            animOffsets.set('splash 1 $i', [0, 0]);
            animOffsets.set('splash 2 $i', [0, 0]);
        }
    }

    public function spawnSplash(x:Float, y:Float, lane:Int = 0):Void {
        setPosition(x, y);
        alpha = splashAlpha;

        var variant = FlxG.random.int(1, 2);
        var animName = 'splash $variant ${lane % 4}';

        if (animation.getByName(animName) == null) {
            animName = 'splash 1 ${lane % 4}';
        }

        if (animation.getByName(animName) != null) {
            animation.play(animName, true);
        }

        scale.set(splashScale, splashScale);
        updateHitbox();

        offset.set(width * 0.25, height * 0.25);

        if (animOffsets.exists(animName)) {
            var off = animOffsets.get(animName);
            offset.x += off[0];
            offset.y += off[1];
        }

        color = FlxColor.WHITE;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (animation.curAnim != null && animation.curAnim.finished) {
            kill();
        }
    }
}