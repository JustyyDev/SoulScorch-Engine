package soulscorch.backend.system.framerate;

import haxe.Timer;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.utils.EngineUtils;

class Framerate extends TextField {
    public var currentFPS(default, null):Int = 0;
    public var memoryMegabytes(default, null):Float = 0.0;
    public var peakMemoryMegabytes(default, null):Float = 0.0;
    public var minFPS(default, null):Int = 999;
    public var maxFPS(default, null):Int = 0;

    public var showRam(default, set):Bool = true;
    public var showPeak(default, set):Bool = true;
    public var showEngineVersion(default, set):Bool = true;
    public var customTextColor(default, set):Int = 0xFFFFFF;

    private var timeBuckets:Array<Int> = [];
    private var bucketTime:Float = 0.0;
    private var currentBucket:Int = 0;
    private var fpsWindowTotal:Int = 0;
    private var lastTime:Float = 0.0;
    private var updateInterval:Float = 0.12;

    public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF) {
        super();

        this.x = x;
        this.y = y;
        this.selectable = false;
        this.mouseEnabled = false;
        this.autoSize = LEFT;
        this.multiline = true;

        defaultTextFormat = new TextFormat("_sans", 13, color, true);
        text = "FPS: 0\nRAM: 0 MB";

        for (_ in 0...10) timeBuckets.push(0);
        bucketTime = Timer.stamp();

        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function set_showRam(value:Bool):Bool {
        showRam = value;
        updateTextDisplay();
        return value;
    }

    private function set_showPeak(value:Bool):Bool {
        showPeak = value;
        updateTextDisplay();
        return value;
    }

    private function set_showEngineVersion(value:Bool):Bool {
        showEngineVersion = value;
        updateTextDisplay();
        return value;
    }

    private function set_customTextColor(value:Int):Int {
        customTextColor = value;
        defaultTextFormat = new TextFormat("_sans", 13, customTextColor, true);
        setTextFormat(defaultTextFormat);
        return value;
    }

    private function onEnterFrame(_:Event):Void {
        if (!visible) return;

        var now:Float = Timer.stamp();
        var delta = now - bucketTime;

        if (delta >= 0.1) {
            var shifts = Std.int(delta / 0.1);
            if (shifts > 10) shifts = 10;

            for (_ in 0...shifts) {
                currentBucket = (currentBucket + 1) % 10;
                fpsWindowTotal -= timeBuckets[currentBucket];
                timeBuckets[currentBucket] = 0;
            }

            bucketTime += shifts * 0.1;
            if (bucketTime < now - 1.0) bucketTime = now - 1.0;
        }

        timeBuckets[currentBucket]++;
        fpsWindowTotal++;
        currentFPS = fpsWindowTotal;

        if (currentFPS > 0) {
            if (currentFPS < minFPS) minFPS = currentFPS;
            if (currentFPS > maxFPS) maxFPS = currentFPS;
        }

        if (now - lastTime >= updateInterval) {
            lastTime = now;
            memoryMegabytes = EngineUtils.getSystemMemoryMB();

            if (memoryMegabytes > peakMemoryMegabytes) {
                peakMemoryMegabytes = memoryMegabytes;
            }

            updateTextDisplay();
        }
    }

    private function updateTextDisplay():Void {
        var displayText:String = 'FPS: $currentFPS';

        if (showRam) {
            var ramStr = EngineUtils.formatMemoryMB(memoryMegabytes * 1024 * 1024);
            displayText += '\nRAM: $ramStr';
            
            if (showPeak) {
                var peakStr = EngineUtils.formatMemoryMB(peakMemoryMegabytes * 1024 * 1024);
                displayText += ' (Peak: $peakStr)';
            }
        }

        if (showEngineVersion) {
            displayText += '\nSoulScorch ' + Version.shortVersion();
        }

        text = displayText;

        if (customTextColor == 0xFFFFFF) {
            var targetColor:Int = (currentFPS >= 60) ? 0xFFFFFF : ((currentFPS >= 30) ? 0xFFFFCC00 : 0xFFFF4444);
            textColor = targetColor;
        }
    }

    public function resetStats():Void {
        minFPS = 999;
        maxFPS = 0;
        peakMemoryMegabytes = memoryMegabytes;
        for (i in 0...timeBuckets.length) timeBuckets[i] = 0;
        fpsWindowTotal = 0;
        currentBucket = 0;
        bucketTime = Timer.stamp();
    }
}