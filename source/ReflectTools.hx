package;

/**
 * Utility helpers for safe, crash-proof reflection in SoulScorch Engine and HScript.
 */
class ReflectTools {
    /**
     * Safely retrieves a field from an object without throwing null-reference exceptions.
     */
    public static function safeField(o:Dynamic, field:String, defaultValue:Dynamic = null):Dynamic {
        if (o == null || field == null) return defaultValue;
        try {
            if (Reflect.hasField(o, field)) {
                var val = Reflect.getProperty(o, field);
                return val != null ? val : defaultValue;
            }
        } catch (e:Dynamic) {}
        return defaultValue;
    }

    /**
     * Safely sets a field or property on an object without crashing if the field does not exist.
     */
    public static function safeSetField(o:Dynamic, field:String, value:Dynamic):Bool {
        if (o == null || field == null) return false;
        try {
            Reflect.setProperty(o, field, value);
            return true;
        } catch (e:Dynamic) {
            return false;
        }
    }

    /**
     * Safely executes a function on an object with variable arguments.
     */
    public static function safeCall(o:Dynamic, funcName:String, ?args:Array<Dynamic>):Dynamic {
        if (o == null || funcName == null) return null;
        if (args == null) args = [];
        try {
            var fn = Reflect.getProperty(o, funcName);
            if (fn != null && Reflect.isFunction(fn)) {
                return Reflect.callMethod(o, fn, args);
            }
        } catch (e:Dynamic) {}
        return null;
    }
}