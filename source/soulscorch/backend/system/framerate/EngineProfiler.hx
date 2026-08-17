package soulscorch.backend.system.framerate;

import soulscorch.backend.system.framerate.SystemInfo;
import soulscorch.backend.utils.Logger;

class EngineProfiler {
    public static var instance:EngineProfiler;

    private var frameAccum:Float = 0;
    private var frameCount:Int = 0;
    public var fps(default, null):Int = 0;
    public var memPeak(default, null):Float = 0;

    public var maxFrameTime:Float = 0.0;
    public var logToConsole:Bool = false;

    public function new(logToConsole:Bool = false) {
        instance = this;
        this.logToConsole = logToConsole;
    }

    public function update(elapsed:Float):Void {
        frameAccum += elapsed;
        frameCount++;

        if (elapsed > maxFrameTime) {
            maxFrameTime = elapsed;
        }

        if (frameAccum >= 1.0) {
            fps = Math.round(frameCount / frameAccum);
            frameAccum = 0;
            frameCount = 0;

            var memMB = SystemInfo.memoryMegabytes;
            if (memMB > memPeak) memPeak = memMB;

            if (logToConsole) {
                Logger.info('FPS: $fps | MEM: ${Math.round(memMB)}MB | PEAK: ${Math.round(memPeak)}MB | MAX DELTA: ${Math.round(maxFrameTime * 1000)}ms');
            }

            maxFrameTime = 0.0;
        }
    }
}