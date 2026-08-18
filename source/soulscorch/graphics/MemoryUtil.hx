package soulscorch.graphics;

import flixel.FlxG;
import openfl.system.System;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;

#if cpp
import cpp.vm.Gc;
#end

class MemoryUtil {
    /**
     * Executes an aggressive garbage collection cycle and purges unused cache pools.
     */
    public static function collect():Void {
        // 1. Flush unused GPU textures & asset registry caches
        GPUTextureManager.clearUnused();
        AssetHelper.clearAtlasCache();
        AssetResolver.clearCache();

        // 2. Clear OpenFL unused bitmap cache
        FlxG.bitmap.dumpCache();

        // 3. Force garbage collection sweep
        #if cpp
        Gc.run(true);
        Gc.compact();
        #elseif hl
        hl.Gc.major();
        #else
        System.gc();
        #end
    }

    /**
     * Returns the current application RAM usage in megabytes.
     */
    public static function getUsedRAM():Float {
        #if cpp
        return Gc.memInfo64(Gc.MEM_INFO_USAGE) / (1024 * 1024);
        #else
        return System.totalMemory / (1024 * 1024);
        #end
    }
}