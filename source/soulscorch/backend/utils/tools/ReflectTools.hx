package soulscorch.backend.utils.tools;

/**
 * Safe reflection utilities for SoulScorch Engine, scripts, and dynamic entities.
 */
class ReflectTools {
    /**
     * Safely retrieves a field or property from an object without throwing null exceptions.
     */
    public static function safeField(o:Dynamic, field:String, defaultValue:Dynamic = null):Dynamic {
        if (o == null || field == null) return defaultValue;
        try {
            if (Reflect.hasField(o, field)) {
                var val = Reflect.field(o, field);
                return val != null ? val : defaultValue;
            }
            var prop = Reflect.getProperty(o, field);
            return prop != null ? prop : defaultValue;
        } catch (e:Dynamic) {}
        return defaultValue;
    }

    /**
     * Safely assigns a field or property value on an object.
     */
    public static function safeSetField(o:Dynamic, field:String, value:Dynamic):Bool {
        if (o == null || field == null) return false;
        try {
            Reflect.setProperty(o, field, value);
            return true;
        } catch (e:Dynamic) {
            try {
                Reflect.setField(o, field, value);
                return true;
            } catch (e2:Dynamic) {
                return false;
            }
        }
    }

    /**
     * Safely invokes a method on an object with variable argument lists.
     */
    public static function safeCall(o:Dynamic, funcName:String, ?args:Array<Dynamic>):Dynamic {
        if (o == null || funcName == null) return null;
        if (args == null) args = [];
        try {
            var fn = Reflect.getProperty(o, funcName);
            if (fn == null) fn = Reflect.field(o, funcName);

            if (fn != null && Reflect.isFunction(fn)) {
                return Reflect.callMethod(o, fn, args);
            }
        } catch (e:Dynamic) {}
        return null;
    }

    /**
     * Copies all primitive fields and properties from a source object onto a target object.
     */
    public static function copyFields(source:Dynamic, target:Dynamic):Void {
        if (source == null || target == null) return;
        for (field in Reflect.fields(source)) {
            try {
                var value = Reflect.field(source, field);
                Reflect.setProperty(target, field, value);
            } catch (e:Dynamic) {}
        }
    }
}