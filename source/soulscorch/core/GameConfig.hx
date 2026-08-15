package soulscorch.core;

import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;

class GameConfig {
    public var width:Int;
    public var height:Int;
    public var title:String;
    public var framerate:Int;

    public var antialiasing:Bool = true;
    public var flashingLights:Bool = true;
    public var downscroll:Bool = false;
    public var middlescroll:Bool = false;
    public var ghostTapping:Bool = true;
    public var botplay:Bool = false;
    public var noteOffset:Float = 0;
    public var safeWindow:Float = 10;
    public var scrollSpeed:Float = 1.0;
    
    public var binds:Map<String, Array<FlxKey>> = [
        "left" => [A, LEFT],
        "down" => [S, DOWN],
        "up" => [W, UP],
        "right" => [D, RIGHT],
        "accept" => [SPACE, ENTER],
        "back" => [BACKSPACE, ESCAPE],
        "pause" => [ENTER, ESCAPE]
    ];

    public function new(width:Int = 1280, height:Int = 720, title:String = "SoulScorch Engine", framerate:Int = 120) {
        this.width = width;
        this.height = height;
        this.title = title;
        this.framerate = framerate;
    }

    public function load():Void {
        var save = new FlxSave();
        save.bind("soulscorch_config");

        if (save.data.antialiasing != null) antialiasing = save.data.antialiasing;
        if (save.data.flashingLights != null) flashingLights = save.data.flashingLights;
        if (save.data.downscroll != null) downscroll = save.data.downscroll;
        if (save.data.middlescroll != null) middlescroll = save.data.middlescroll;
        if (save.data.ghostTapping != null) ghostTapping = save.data.ghostTapping;
        if (save.data.noteOffset != null) noteOffset = save.data.noteOffset;
        if (save.data.framerate != null) framerate = save.data.framerate;
        if (save.data.scrollSpeed != null) scrollSpeed = save.data.scrollSpeed;
        if (save.data.binds != null) binds = save.data.binds;

        save.close();
    }
    
    public function save():Void {
        var save = new FlxSave();
        save.bind("soulscorch_config");

        save.data.antialiasing = antialiasing;
        save.data.flashingLights = flashingLights;
        save.data.downscroll = downscroll;
        save.data.middlescroll = middlescroll;
        save.data.ghostTapping = ghostTapping;
        save.data.noteOffset = noteOffset;
        save.data.framerate = framerate;
        save.data.scrollSpeed = scrollSpeed;
        save.data.binds = binds;

        save.flush();
        save.close();
    }
}