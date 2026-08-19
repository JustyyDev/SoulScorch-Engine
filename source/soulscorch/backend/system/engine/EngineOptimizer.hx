package soulscorch.backend.system.engine;

import flixel.FlxG;
import soulscorch.graphics.GPUTextureManager;
import soulscorch.graphics.MemoryUtil;
import soulscorch.backend.utils.Logger;

class EngineOptimizer {
    public static var enabled(default, set):Bool = true;
    public static var targetFPS:Int = 120;
    
    // Performance tuning thresholds
    public static var autoOptimizeOnLag:Bool = true;
    public static var lagThresholdFPS:Int = 45;
    private static var lagTimer:Float = 0.0;

    public static function init(target:Int = 120):Void {
        targetFPS = target;
        FlxG.updateFramerate = targetFPS;
        FlxG.drawFramerate = targetFPS;
        
        // Optimize Flixel rendering settings for high performance
        FlxG.fixedTimestep = false;
        FlxG.maxElapsed = 0.1; // Prevents spiral-of-death lag spikes when window loses focus
        
        Logger.info("[OPTIMIZER] Global Engine Optimizer initialized.", "optimizer");
    }

    public static function update(elapsed:Float):Void {
        if (!enabled) return;

        // Dynamic Lag Detection & Auto-Purge
        if (autoOptimizeOnLag && FlxG.save.data != null && FlxG.save.data.autoGC != false) {
            var currentFPS = Math.round(1.0 / (elapsed > 0 ? elapsed : 0.016));
            if (currentFPS < lagThresholdFPS) {
                lagTimer += elapsed;
                if (lagTimer >= 3.0) { // If lagging consistently for 3 seconds
                    lagTimer = 0.0;
                    Logger.warn('[OPTIMIZER] Low FPS detected ($currentFPS FPS). Executing emergency memory purge...', "optimizer");
                    MemoryUtil.collect();
                }
            } else {
                lagTimer = Math.max(0.0, lagTimer - (elapsed * 0.5));
            }
        }
    }

    private static function set_enabled(value:Bool):Bool {
        enabled = value;
        Logger.info('Global Engine Optimizer state: ${enabled ? "ENABLED" : "DISABLED"}', "optimizer");
        return enabled;
    }
}