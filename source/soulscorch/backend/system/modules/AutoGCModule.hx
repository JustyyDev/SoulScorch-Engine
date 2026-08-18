package soulscorch.backend.system.modules;

import flixel.FlxG;
import openfl.system.System;
import soulscorch.backend.system.framerate.SystemInfo;
import soulscorch.backend.system.modules.Module.ModuleBase;
import soulscorch.backend.utils.Logger;

#if cpp
import cpp.vm.Gc;
#end

class AutoGCModule extends ModuleBase {
    public var memoryThresholdMB:Float = 1200.0;
    public var checkInterval:Float = 15.0;
    public var cooldownTime:Float = 30.0;

    private var timer:Float = 0.0;
    private var timeSinceLastGC:Float = 0.0;

    public function new(thresholdMB:Float = 1200.0) {
        super("auto_gc");
        this.memoryThresholdMB = thresholdMB;
    }

    override public function update(elapsed:Float):Void {
        timer += elapsed;
        timeSinceLastGC += elapsed;

        if (timer >= checkInterval) {
            timer = 0.0;
            checkMemory();
        }
    }

    override public function onStateSwitch():Void {
        if (timeSinceLastGC >= 5.0) {
            collectGarbage("State Switch");
        }
    }

    private function checkMemory():Void {
        var currentMemory = SystemInfo.memoryMegabytes;
        if (currentMemory >= memoryThresholdMB && timeSinceLastGC >= cooldownTime) {
            collectGarbage('Threshold Exceeded (${Math.round(currentMemory)}MB / ${Math.round(memoryThresholdMB)}MB)');
        }
    }

    public function collectGarbage(reason:String = "Manual"):Void {
        var memBefore = SystemInfo.memoryMegabytes;

        try {
            #if cpp
            Gc.enable(true);
            Gc.run(true);
            Gc.compact();
            #elseif sys
            System.gc();
            #end

            if (FlxG.bitmap != null) {
                FlxG.bitmap.clearUnused();
            }

            timeSinceLastGC = 0.0;
            var memAfter = SystemInfo.memoryMegabytes;
            var freed = Math.max(0.0, memBefore - memAfter);
            
            Logger.info('Garbage collection completed ($reason). Freed: ${Math.round(freed)}MB | Current RAM: ${Math.round(memAfter)}MB', "auto_gc");
        } catch (e:Dynamic) {
            Logger.error('Failed to execute garbage collection ($reason): $e', "auto_gc");
        }
    }
}