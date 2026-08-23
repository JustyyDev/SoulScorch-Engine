package soulscorch.backend.system.engine;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.Lib;
import openfl.system.System;
import openfl.utils.Assets;
import soulscorch.backend.assets.Paths;
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

#if (cpp && windows)
@:cppFileCode('
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>

#undef ERROR
#undef DELETE
#undef TRANSPARENT
#undef OPAQUE
#undef IN
#undef OUT
#undef NO_ERROR
#undef min
#undef max
')
#end
class EngineOptimizer {
    public static var enabled(default, set):Bool = true;
    public static var targetFPS:Int = 120;
    
    // Performance Tuning & Thresholds
    public static var autoOptimizeOnLag:Bool = true;
    public static var lowSpecMode:Bool = false;
    public static var lagThresholdFPS:Int = 50;
    public static var maxGCMemoryMB:Float = 380.0;
    
    private static var lagTimer:Float = 0.0;
    private static var gcSweepTimer:Float = 0.0;

    // Adaptive VRAM & Frame Settings
    public static var vramPurgeInterval:Float = 10.0; // Seconds between sweeping unused graphic assets
    public static var maxDeltaTime:Float = 0.085;     // Prevents physics explosion after window dragging / stalling

    public static function init(target:Int = 120):Void {
        targetFPS = target;
        
        #if mobile
        lowSpecMode = true;
        maxGCMemoryMB = 220.0;
        vramPurgeInterval = 6.0;
        #else
        lowSpecMode = false;
        #end

        FlxG.updateFramerate = targetFPS;
        FlxG.drawFramerate = targetFPS;
        
        // High-performance Flixel timing configurations
        FlxG.fixedTimestep = false;
        FlxG.maxElapsed = maxDeltaTime;
        FlxG.autoPause = false;
        FlxG.mouse.useSystemCursor = false;

        #if (cpp && windows)
        trimProcessWorkingSet();
        #end

        FlxG.signals.gameResized.add(function(w:Int, h:Int) {
            performIncrementalVRAMPurge();
        });

        Logger.info("[OPTIMIZER] SoulScorch Anti-Lag Engine Optimizer initialized.", "optimizer");
    }

    #if (cpp && windows)
    @:functionCode('
        SetProcessWorkingSetSize(GetCurrentProcess(), (SIZE_T)-1, (SIZE_T)-1);
    ')
    private static function trimProcessWorkingSet():Void {}
    #end

    public static function update(elapsed:Float):Void {
        if (!enabled) return;

        var safeElapsed = Math.min(elapsed, maxDeltaTime);
        gcSweepTimer += safeElapsed;

        if (gcSweepTimer >= vramPurgeInterval) {
            gcSweepTimer = 0.0;
            var currentMemMB:Float = (System.totalMemory / 1048576.0);
            if (currentMemMB > maxGCMemoryMB || lowSpecMode) {
                performIncrementalVRAMPurge();
            }
        }

        if (autoOptimizeOnLag) {
            var currentFPS = Math.round(1.0 / (safeElapsed > 0 ? safeElapsed : 0.016));
            if (currentFPS < lagThresholdFPS) {
                lagTimer += safeElapsed;
                if (lagTimer >= 2.0) {
                    lagTimer = 0.0;
                    if (!lowSpecMode) {
                        lowSpecMode = true;
                        Logger.warn('[OPTIMIZER] Low frame rate ($currentFPS FPS). Enabled Low-Spec rendering mode.', "optimizer");
                    }
                    performEmergencyCompaction();
                }
            } else {
                lagTimer = Math.max(0.0, lagTimer - (safeElapsed * 0.5));
            }
        }
    }

    @:access(flixel.system.frontEnds.BitmapFrontEnd)
    public static function performIncrementalVRAMPurge():Void {
        for (key in FlxG.bitmap._cache.keys()) {
            var graph:FlxGraphic = FlxG.bitmap._cache.get(key);
            if (graph != null && !graph.persist && graph.useCount <= 0 && !Paths.currentTrackedAssets.exists(key)) {
                FlxG.bitmap.remove(graph);
            }
        }

        // Only sweep the GC when there is real memory pressure. Running a GC
        // unconditionally every interval causes periodic micro-hitches.
        var currentMemMB:Float = (System.totalMemory / 1048576.0);
        if (currentMemMB > maxGCMemoryMB || lowSpecMode) {
            #if cpp
            Gc.run(false); // Non-blocking generational GC sweep
            #elseif hl
            Gc.major();
            #end
        }
    }
    
    public static function runMemorySweep():Void {
        performIncrementalVRAMPurge();
    }

    public static function performEmergencyCompaction():Void {
        // IMPORTANT: Never wipe the active asset caches. Clearing IMAGE/SOUND
        // forces every still-needed graphic/sound to be re-decoded from disk on
        // next use, which produces massive, repeated lag spikes. Instead we only
        // release genuinely unused GPU/CPU assets and run an incremental GC.
        performIncrementalVRAMPurge();
        MemoryUtil.collect();

        #if cpp
        Gc.run(false); // Incremental, non-blocking sweep (no full compact)
        #elseif hl
        Gc.major();
        #elseif java
        System.gc();
        #end

        #if (cpp && windows)
        trimProcessWorkingSet();
        #end

        Logger.info("[OPTIMIZER] Gentle memory compaction complete (no cache wipe).", "optimizer");
    }

    private static function set_enabled(value:Bool):Bool {
        enabled = value;
        Logger.info('Global Engine Optimizer state: ${enabled ? "ENABLED" : "DISABLED"}', "optimizer");
        return enabled;
    }
}