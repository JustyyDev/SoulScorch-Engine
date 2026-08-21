package soulscorch.backend.system;

import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class XMSoul {
    private static var cache:Map<String, Access> = new Map<String, Access>();

    public static function parse(path:String, useCache:Bool = true):Null<Access> {
        if (path == null || path.trim().length == 0) return null;
        var clean = path.trim().replace("\\", "/");
        while (clean.startsWith("/")) clean = clean.substr(1);

        if (useCache && cache.exists(clean)) {
            return cache.get(clean);
        }

        var rawText:String = null;

        #if sys
        if (FileSystem.exists(clean)) {
            try { rawText = File.getContent(clean); } catch (e:Dynamic) {}
        }
        #end

        if (rawText == null) {
            var resolved = AssetResolver.resolveFile(clean, [".xmsoul", ".xml", ""]);
            if (resolved != null) {
                rawText = AssetResolver.getText(resolved);
            }
        }

        if (rawText != null && rawText.trim().length > 0) {
            try {
                var rawXml = Xml.parse(rawText.trim());
                var firstElem:Xml = null;
                for (elem in rawXml.elements()) {
                    firstElem = elem;
                    break;
                }

                if (firstElem == null) {
                    Logger.warn('XMSoul parser found empty XML structure in: $clean', "xmsoul");
                    return null;
                }

                var access = new Access(firstElem);
                if (useCache) cache.set(clean, access);
                return access;
            } catch (e:Dynamic) {
                Logger.error('XMSoul Parse Failure [$clean]: $e', "xmsoul");
            }
        }

        return null;
    }

    public static function getAttr(node:Access, name:String, defaultVal:String = ""):String {
        if (node == null) return defaultVal;
        return (node.has.resolve(name)) ? node.att.resolve(name) : defaultVal;
    }

    public static function getFloatAttr(node:Access, name:String, defaultVal:Float = 0.0):Float {
        if (node == null || !node.has.resolve(name)) return defaultVal;
        var val = Std.parseFloat(node.att.resolve(name));
        return Math.isNaN(val) ? defaultVal : val;
    }

    public static function getIntAttr(node:Access, name:String, defaultVal:Int = 0):Int {
        if (node == null || !node.has.resolve(name)) return defaultVal;
        var val = Std.parseInt(node.att.resolve(name));
        return val == null ? defaultVal : val;
    }

    public static function getBoolAttr(node:Access, name:String, defaultVal:Bool = false):Bool {
        if (node == null || !node.has.resolve(name)) return defaultVal;
        var v = node.att.resolve(name).toLowerCase().trim();
        return (v == "true" || v == "1" || v == "yes");
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