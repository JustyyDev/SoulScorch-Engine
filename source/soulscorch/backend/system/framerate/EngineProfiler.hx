package soulscorch.backend.system.framerate;

import soulscorch.backend.system.framerate.SystemInfo;
import soulscorch.backend.utils.Logger;

class EngineProfiler {
    public static var instance(get, null):EngineProfiler;
    private static var _instance:EngineProfiler;

    private var frameAccum:Float = 0.0;
    private var frameCount:Int = 0;
    public var fps(default, null):Int = 0;
    public var memPeak(default, null):Float = 0.0;
    public var memAverage(default, null):Float = 0.0;

    public var maxFrameTime:Float = 0.0;
    public var minFrameTime:Float = 999.0;
    public var averageFrameTime(default, null):Float = 0.0;
    public var logToConsole:Bool = false;
    public var stutterThresholdMs:Float = 33.33;

    private var totalFrameTimeAccum:Float = 0.0;
    private var totalFramesSampled:Int = 0;

    public function new(logToConsole:Bool = false) {
        _instance = this;
        this.logToConsole = logToConsole;
        memPeak = SystemInfo.memoryMegabytes;
    }

    public static inline function get_instance():EngineProfiler {
        if (_instance == null) {
            _instance = new EngineProfiler(false);
        }
        return _instance;
    }

    public function update(elapsed:Float):Void {
        frameAccum += elapsed;
        frameCount++;

        totalFrameTimeAccum += elapsed;
        totalFramesSampled++;

        if (elapsed > maxFrameTime) {
            maxFrameTime = elapsed;
        }

        if (elapsed < minFrameTime) {
            minFrameTime = elapsed;
        }

        if (elapsed * 1000.0 >= stutterThresholdMs && logToConsole) {
            Logger.warn('Stutter spike detected! Delta: ${Math.round(elapsed * 1000.0)}ms', "profiler");
        }

        if (frameAccum >= 1.0) {
            fps = Math.round(frameCount / (frameAccum > 0 ? frameAccum : 1.0));
            averageFrameTime = totalFramesSampled > 0 ? (totalFrameTimeAccum / totalFramesSampled) : 0.0;

            frameAccum = 0.0;
            frameCount = 0;

            var memMB = SystemInfo.memoryMegabytes;
            if (memMB > memPeak) {
                memPeak = memMB;
            }
            memAverage = memMB;

            if (logToConsole) {
                Logger.info('FPS: $fps | MEM: ${Math.round(memMB)}MB | PEAK: ${Math.round(memPeak)}MB | AVG: ${Math.round(averageFrameTime * 1000.0)}ms | MAX: ${Math.round(maxFrameTime * 1000.0)}ms', "profiler");
            }

            maxFrameTime = 0.0;
            minFrameTime = 999.0;
            totalFrameTimeAccum = 0.0;
            totalFramesSampled = 0;
        }
    }

    public function resetMetrics():Void {
        maxFrameTime = 0.0;
        minFrameTime = 999.0;
        memPeak = SystemInfo.memoryMegabytes;
        totalFrameTimeAccum = 0.0;
        totalFramesSampled = 0;
        frameAccum = 0.0;
        frameCount = 0;
    }
}