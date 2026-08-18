package soulscorch.graphics;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;

class GPUSprite extends FlxSprite {
    public var autoCull:Bool = true;
    public var cullPadding:Float = 64.0;

    public function new(x:Float = 0, y:Float = 0, ?imagePath:String) {
        super(x, y);
        if (imagePath != null) {
            loadGPUGraphic(imagePath);
        }
        antialiasing = true;
    }

    public function loadGPUGraphic(path:String, animated:Bool = false, width:Int = 0, height:Int = 0):GPUSprite {
        var graphic = GPUTextureManager.loadGPUGraphic(path);
        if (graphic != null) {
            loadGraphic(graphic, animated, width, height);
        }
        return this;
    }

    public function loadGPUSparrow(path:String):GPUSprite {
        var atlas = GPUAtlasFrames.fromSparrow(path);
        if (atlas != null) {
            this.frames = atlas;
        }
        return this;
    }

    override public function isOnScreen(?camera:FlxCamera):Bool {
        if (!autoCull) return true;
        if (camera == null) camera = FlxG.camera;
        if (camera == null) return true;

        var minX = x - offset.x - cullPadding;
        var maxX = x - offset.x + width + cullPadding;
        var minY = y - offset.y - cullPadding;
        var maxY = y - offset.y + height + cullPadding;

        return (maxX >= camera.viewMarginLeft && minX <= camera.viewMarginRight &&
                maxY >= camera.viewMarginTop && minY <= camera.viewMarginBottom);
    }
}