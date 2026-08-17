package soulscorch.backend.system.framerate;

import haxe.Timer;
import openfl.Lib;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import soulscorch.backend.utils.EngineUtils;

class Framerate extends TextField {
    public var currentFPS(default, null):Int = 0;
    public var memoryMegabytes(default, null):Float = 0.0;

    private var times:Array<Float> = [];
    private var lastTime:Float = 0.0;

    public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF) {
        super();

        this.x = x;
        this.y = y;

        this.selectable = false;
        this.mouseEnabled = false;
        this.autoSize = LEFT;
        this.multiline = true;

        defaultTextFormat = new TextFormat("_sans", 14, color, true);
        text = "FPS: 0\nRAM: 0 MB";

        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function onEnterFrame(_:Event):Void {
        var now:Float = Timer.stamp();
        times.push(now);

        while (times[0] < now - 1.0) {
            times.shift();
        }

        currentFPS = times.length;

        // Throttle text rendering slightly to avoid performance hits
        if (now - lastTime >= 0.15) {
            lastTime = now;
            memoryMegabytes = EngineUtils.getSystemMemoryMB();

            text = 'FPS: $currentFPS\nRAM: ${EngineUtils.formatMemoryMB(memoryMegabytes * 1024 * 1024)}';
        }
    }
}