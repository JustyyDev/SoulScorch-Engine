package soulscorch.backend.system;

import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;

class XMSoul {
    private static var cache:Map<String, Access> = new Map<String, Access>();

    /**
     * Parses and caches any .xmsoul or XML configuration file across the engine.
     */
    public static function parse(path:String, useCache:Bool = true):Null<Access> {
        if (path == null || path.trim().length == 0) return null;
        var clean = path.trim().replace("\\", "/");
        while (clean.startsWith("/")) clean = clean.substr(1);

        if (useCache && cache.exists(clean)) {
            return cache.get(clean);
        }

        var resolved = AssetResolver.resolveFile(clean, [".xmsoul", ".xml", ""]);
        if (resolved == null) {
            resolved = AssetResolver.resolveFile(clean + ".xmsoul", [""]);
        }

        if (resolved != null) {
            var text = AssetResolver.getText(resolved);
            if (text != null && text.length > 0) {
                try {
                    var xml = Xml.parse(text);
                    var access = new Access(xml.firstElement());
                    if (useCache) {
                        cache.set(clean, access);
                    }
                    return access;
                } catch (e:Dynamic) {
                    Logger.error('XMSoul Parser Error [$clean]: $e', "xmsoul");
                }
            }
        }
        return null;
    }

    /**
     * Helper to read typed attributes safely with default fallbacks.
     */
    public static inline function getAttr(node:Access, name:String, defaultVal:String):String {
        return (node.has.att(name)) ? node.att.resolve(name) : defaultVal;
    }

    public static inline function getFloatAttr(node:Access, name:String, defaultVal:Float):Float {
        return (node.has.att(name)) ? Std.parseFloat(node.att.resolve(name)) : defaultVal;
    }

    public static inline function getIntAttr(node:Access, name:String, defaultVal:Int):Int {
        return (node.has.att(name)) ? Std.parseInt(node.att.resolve(name)) : defaultVal;
    }

    public static inline function getBoolAttr(node:Access, name:String, defaultVal:Bool):Bool {
        return (node.has.att(name)) ? (node.att.resolve(name).toLowerCase() == "true") : defaultVal;
    }

    public static function clearCache():Void {
        cache.clear();
    }
}