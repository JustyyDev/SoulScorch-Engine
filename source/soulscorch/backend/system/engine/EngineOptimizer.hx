package soulscorch.backend.system.engine;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.Lib;
import openfl.utils.Assets;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.GPUTextureManager;
import soulscorch.graphics.MemoryUtil;

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif java
import java.lang.System;
#end

@:headerInclude("windows.h")
class EngineOptimizer {
    public static var enabled(default, set):Bool = true;
    public static var targetFPS:Int = 120;
    
    // Performance Tuning & Thresholds
    public static var autoOptimizeOnLag:Bool = true;
    public static var lagThresholdFPS:Int = 50;
    private static var lagTimer:Float = 0.0;
    private static var gcSweepTimer:Float = 0.0;

    // Adaptive VRAM & Frame Settings
    public static var vramPurgeInterval:Float = 15.0; // Seconds between sweeping unused graphic assets
    public static var maxDeltaTime:Float = 0.1;       // Prevents physics explosion after window dragging / stalling

    public static function init(target:Int = 120):Void {
        targetFPS = target;
        FlxG.updateFramerate = targetFPS;
        FlxG.drawFramerate = targetFPS;
        
        // High-performance Flixel timing configurations
        FlxG.fixedTimestep = false;
        FlxG.maxElapsed = maxDeltaTime;
        FlxG.autoPause = false;
        FlxG.mouse.useSystemCursor = false;

        #if (cpp && windows)
        // Optimize working memory block allocation size for C++ target
        untyped __cpp__("SetProcessWorkingSetSize(GetCurrentProcess(), (SIZE_T)-1, (SIZE_T)-1)");
        #end

        Logger.info("[OPTIMIZER] SoulScorch High-Performance Engine Optimizer initialized.", "optimizer");
    }

    public static function update(elapsed:Float):Void {
        if (!enabled) return;

        // Clamp elapsed to prevent physics/math spiral-of-death spikes
        var safeElapsed = Math.min(elapsed, maxDeltaTime);
        gcSweepTimer += safeElapsed;

        // Periodic VRAM and Bitmap Cache Sweep
        if (gcSweepTimer >= vramPurgeInterval) {
            gcSweepTimer = 0.0;
            performIncrementalVRAMPurge();
        }

        // Dynamic Lag Detection & Emergency Auto-Purge
        if (autoOptimizeOnLag) {
            var currentFPS = Math.round(1.0 / (safeElapsed > 0 ? safeElapsed : 0.016));
            if (currentFPS < lagThresholdFPS) {
                lagTimer += safeElapsed;
                if (lagTimer >= 2.5) { // Consistent low FPS for 2.5 seconds
                    lagTimer = 0.0;
                    Logger.warn('[OPTIMIZER] Low frame rate detected ($currentFPS FPS). Executing emergency memory sweep...', "optimizer");
                    performEmergencyCompaction();
                }
            } else {
                lagTimer = Math.max(0.0, lagTimer - (safeElapsed * 0.5));
            }
        }
    }

    public static function performIncrementalVRAMPurge():Void {
        @:privateAccess {
            for (key in FlxG.bitmap._cache.keys()) {
                var graph:FlxGraphic = FlxG.bitmap._cache.get(key);
                if (graph != null && !graph.persist && graph.useCount <= 0) {
                    FlxG.bitmap.remove(graph);
                }
            }
        }

        #if cpp
        Gc.run(false); // Non-blocking generational GC sweep
        #elseif hl
        Gc.major();
        #end
    }

    public static function performEmergencyCompaction():Void {
        @:privateAccess {
            if (Assets.cache != null) {
                Assets.cache.clear("IMAGE");
                Assets.cache.clear("SOUND");
            }
        }

        FlxG.bitmap.dumpCache();
        FlxG.bitmap.clearUnused();
        MemoryUtil.collect();

        #if cpp
        Gc.run(true);
        Gc.compact();
        #elseif hl
        Gc.major();
        #elseif java
        System.gc();
        #end

        Logger.info("[OPTIMIZER] Emergency VRAM and Garbage Collection compaction complete.", "optimizer");
    }

    private static function set_enabled(value:Bool):Bool {
        enabled = value;
        Logger.info('Global Engine Optimizer state: ${enabled ? "ENABLED" : "DISABLED"}', "optimizer");
        return enabled;
    }
}