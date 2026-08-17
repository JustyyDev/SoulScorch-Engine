package soulscorch.backend.system.engine;

import flixel.FlxG;
import soulscorch.backend.utils.EngineUtils;

class GameConfig {
    public var downscroll:Bool = false;
    public var ghostTapping:Bool = true;
    public var framerate:Int = 120;
    public var flashingLights:Bool = true;
    public var antialiasing:Bool = true;
    public var autoGC:Bool = true;
    public var offset:Float = 0.0;

    public function new() {
        load();
    }

    public function load():Void {
        if (FlxG.save.data.downscroll != null) downscroll = FlxG.save.data.downscroll;
        if (FlxG.save.data.ghostTapping != null) ghostTapping = FlxG.save.data.ghostTapping;
        if (FlxG.save.data.framerate != null) framerate = FlxG.save.data.framerate;
        if (FlxG.save.data.flashingLights != null) flashingLights = FlxG.save.data.flashingLights;
        if (FlxG.save.data.antialiasing != null) antialiasing = FlxG.save.data.antialiasing;
        if (FlxG.save.data.autoGC != null) autoGC = FlxG.save.data.autoGC;
        if (FlxG.save.data.offset != null) offset = FlxG.save.data.offset;

        EngineUtils.setFramerate(framerate);
    }

    public function save():Void {
        FlxG.save.data.downscroll = downscroll;
        FlxG.save.data.ghostTapping = ghostTapping;
        FlxG.save.data.framerate = framerate;
        FlxG.save.data.flashingLights = flashingLights;
        FlxG.save.data.antialiasing = antialiasing;
        FlxG.save.data.autoGC = autoGC;
        FlxG.save.data.offset = offset;
        FlxG.save.flush();
    }
}