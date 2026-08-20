package soulscorch.graphics;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;

using StringTools;

class FunkinSprite extends FlxSprite {
    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
    public var globalOffset:FlxPoint = FlxPoint.get(0, 0);

    public function new(x:Float = 0, y:Float = 0, ?graphicKey:Dynamic) {
        super(x, y);
        if (graphicKey != null) {
            loadSprite(graphicKey);
        }
    }

    public function loadSprite(asset:Dynamic):FunkinSprite {
        if (Std.isOfType(asset, FlxGraphic)) {
            loadGraphic(cast asset);
            return this;
        }

        var key:String = Std.string(asset);
        
        // Try loading as Sparrow XML / Adobe Animate JSON atlas first
        var loaded = AssetHelper.loadSparrowSafely(this, key);
        if (!loaded) loaded = AssetHelper.loadSparrowSafely(this, 'ui/game/cutscenes/$key');
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(this, key);
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(this, 'ui/game/cutscenes/$key');
        if (!loaded) makeGraphic(100, 100, 0xFFFF0055);

        antialiasing = true;
        return this;
    }

    public function makeSolid(width:Float, height:Float, color:FlxColor = FlxColor.WHITE):FunkinSprite {
        makeGraphic(Std.int(width), Std.int(height), color);
        return this;
    }

    public function addAnim(name:String, prefix:String, fps:Int = 24, loop:Bool = false, ?indices:Array<Int>):Void {
        if (frames == null || frames.frames == null) return;

        if (indices != null && indices.length > 0) {
            animation.addByIndices(name, prefix, indices, "", fps, loop);
        } else {
            animation.addByPrefix(name, prefix, fps, loop);
        }
    }

    public function addAnimByIndices(name:String, prefix:String, indices:Array<Int>, fps:Int = 24, loop:Bool = false):Void {
        addAnim(name, prefix, fps, loop, indices);
    }

    public function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
        if (animation.getByName(name) == null) return;

        animation.play(name, force, reversed, frame);

        var daOffset = animOffsets.get(name);
        if (daOffset != null) {
            offset.set(daOffset[0], daOffset[1]);
        } else {
            offset.set(0, 0);
        }
    }

    public function addOffset(name:String, x:Float = 0, y:Float = 0):Void {
        animOffsets.set(name, [x, y]);
    }

    public function getCameraPosition():FlxPoint {
        return FlxPoint.get(getMidpoint().x + globalOffset.x, getMidpoint().y + globalOffset.y);
    }

    override public function destroy():Void {
        if (globalOffset != null) {
            globalOffset.put();
            globalOffset = null;
        }
        animOffsets.clear();
        super.destroy();
    }
}