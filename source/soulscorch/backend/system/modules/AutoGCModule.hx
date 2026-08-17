package soulscorch.backend.system.modules;

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
    private var timer:Float = 0.0;

    public function new(thresholdMB:Float = 1200.0) {
        super("auto_gc");
        this.memoryThresholdMB = thresholdMB;
    }

    override public function update(elapsed:Float):Void {
        timer += elapsed;
        if (timer >= checkInterval) {
            timer = 0.0;
            checkMemory();
        }
    }

    override public function onStateSwitch():Void {
        collectGarbage("State Switch");
    }

    private function checkMemory():Void {
        var currentMemory = SystemInfo.memoryMegabytes;
        if (currentMemory >= memoryThresholdMB) {
            collectGarbage('Threshold Exceeded (${Math.round(currentMemory)}MB / ${Math.round(memoryThresholdMB)}MB)');
        }
    }

    public function collectGarbage(reason:String = "Manual"):Void {
        var memBefore = SystemInfo.memoryMegabytes;

        #if cpp
        Gc.run(true);
        Gc.compact();
        #elseif sys
        System.gc();
        #end

        var memAfter = SystemInfo.memoryMegabytes;
        var freed = Math.max(0, memBefore - memAfter);
        Logger.info('Garbage collection ran ($reason). Freed: ${Math.round(freed)}MB | Current RAM: ${Math.round(memAfter)}MB');
    }
}