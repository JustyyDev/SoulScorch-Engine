package soulscorch.backend.system.engine;

import soulscorch.backend.utils.Logger;

class ObjectPoolingManager {
    private static var pools:Map<String, Array<Dynamic>> = new Map<String, Array<Dynamic>>();

    public static function preallocate<T>(key:String, factory:Void->T, count:Int):Void {
        if (!pools.exists(key)) {
            pools.set(key, []);
        }
        var pool = pools.get(key);
        for (i in 0...count) {
            pool.push(factory());
        }
        Logger.info('Pre-allocated $count instances for pool: "$key"', "profiler");
    }

    public static function obtain<T>(key:String, factory:Void->T):T {
        if (!pools.exists(key)) {
            pools.set(key, []);
        }
        var pool = pools.get(key);
        if (pool.length > 0) {
            return pool.pop();
        }
        return factory();
    }

    public static function recycle(key:String, instance:Dynamic):Void {
        if (instance == null) return;
        if (!pools.exists(key)) {
            pools.set(key, []);
        }
        pools.get(key).push(instance);
    }

    public static function clearPool(key:String):Void {
        if (pools.exists(key)) {
            var pool = pools.get(key);
            pool.resize(0);
            pools.remove(key);
            Logger.info('Cleared and disposed pool: "$key"', "profiler");
        }
    }

    public static function clearAll():Void {
        for (key in pools.keys()) {
            clearPool(key);
        }
        pools.clear();
        Logger.info("Flushed all object pools.", "profiler");
    }
}