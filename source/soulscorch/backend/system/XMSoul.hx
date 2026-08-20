package soulscorch.backend.system;

import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;

using StringTools;

class XMSoul {
    private static var cache:Map<String, Access> = new Map<String, Access>();

    public static function parse(path:String, useCache:Bool = true):Null<Access> {
        if (path == null || path.trim().length == 0) return null;
        var clean = path.trim().replace("\\", "/");

        if (useCache && cache.exists(clean)) {
            return cache.get(clean);
        }

        var resolved = AssetResolver.resolveFile(clean, [".xmsoul", ".xml", ""]);
        if (resolved == null) {
            resolved = AssetResolver.resolveFile(clean + ".xmsoul", [""]);
        }

        if (resolved != null) {
            var rawText = AssetResolver.getText(resolved);
            if (rawText != null && rawText.trim().length > 0) {
                try {
                    var xml = Xml.parse(rawText.trim());
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

    public static function getAttr(node:Access, name:String, defaultVal:String = ""):String {
        if (node == null) return defaultVal;
        return (node.has.resolve(name)) ? node.att.resolve(name) : defaultVal;
    }

    public static function getFloatAttr(node:Access, name:String, defaultVal:Float = 0.0):Float {
        if (node == null) return defaultVal;
        return (node.has.resolve(name)) ? Std.parseFloat(node.att.resolve(name)) : defaultVal;
    }

    public static function getIntAttr(node:Access, name:String, defaultVal:Int = 0):Int {
        if (node == null) return defaultVal;
        return (node.has.resolve(name)) ? Std.parseInt(node.att.resolve(name)) : defaultVal;
    }

    public static function getBoolAttr(node:Access, name:String, defaultVal:Bool = false):Bool {
        if (node == null) return defaultVal;
        return (node.has.resolve(name)) ? (node.att.resolve(name).toLowerCase() == "true") : defaultVal;
    }

    public static function getArrayAttr(node:Access, name:String, delimiter:String = ","):Array<String> {
        if (node == null || !node.has.resolve(name)) return [];
        var raw = node.att.resolve(name);
        var result:Array<String> = [];
        for (item in raw.split(delimiter)) {
            var trimmed = item.trim();
            if (trimmed.length > 0) result.push(trimmed);
        }
        return result;
    }

    public static function clearCache():Void {
        cache.clear();
    }
}