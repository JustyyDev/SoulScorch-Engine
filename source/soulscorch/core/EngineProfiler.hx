package soulscorch.core;

import soulscorch.utils.EngineUtils;

/**
 * Engine performance profiler. Implemented as a Module so it is ticked by the
 * Engine update loop. Logs FPS and memory usage once per second.
 */
class EngineProfiler extends ModuleBase {
    var frameAccum:Float = 0;
    var frameCount:Int = 0;
    var fps:Int = 0;
    var memPeak:Float = 0;

    public function new() {
        super("profiler");
    }

    override public function update(elapsed:Float):Void {
        frameAccum += elapsed;
        frameCount++;

        if (frameAccum >= 1.0) {
            fps = Math.round(frameCount / frameAccum);
            frameAccum = 0;
            frameCount = 0;

            var memMB = EngineUtils.getSystemMemoryMB();
            if (memMB > memPeak) memPeak = memMB;

            Logger.info("profiler", 'FPS: $fps | MEM: ${Math.round(memMB)}MB | PEAK: ${Math.round(memPeak)}MB');
        }
    }
}
