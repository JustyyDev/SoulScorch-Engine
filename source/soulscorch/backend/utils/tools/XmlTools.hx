package soulscorch.backend.utils.tools;

import haxe.xml.Access;

/**
 * Static extension methods for Haxe's standard `Xml` and `haxe.xml.Access` nodes.
 * Use via `using soulscorch.backend.utils.tools.XmlTools;`
 */
class XmlTools {
    /**
     * Safely reads an attribute as a Float from an Xml node.
     */
    public static function getFloat(xml:Xml, att:String, defaultValue:Float = 0.0):Float {
        if (xml == null || !xml.exists(att)) return defaultValue;
        var parsed = Std.parseFloat(xml.get(att));
        return Math.isNaN(parsed) ? defaultValue : parsed;
    }

    /**
     * Safely reads an attribute as an Int from an Xml node.
     */
    public static function getInt(xml:Xml, att:String, defaultValue:Int = 0):Int {
        if (xml == null || !xml.exists(att)) return defaultValue;
        var parsed = Std.parseInt(xml.get(att));
        return parsed == null ? defaultValue : parsed;
    }

    /**
     * Safely reads an attribute as a Bool from an Xml node (handles "true", "false", "1", "0").
     */
    public static function getBool(xml:Xml, att:String, defaultValue:Bool = false):Bool {
        if (xml == null || !xml.exists(att)) return defaultValue;
        var val = xml.get(att).toLowerCase().trim();
        return val == "true" || val == "1";
    }

    /**
     * Safely reads an attribute as a String with a default fallback.
     */
    public static function getString(xml:Xml, att:String, defaultValue:String = ""):String {
        if (xml == null || !xml.exists(att)) return defaultValue;
        var val = xml.get(att);
        return val != null ? val : defaultValue;
    }

    /**
     * Reads an attribute safely from a fast `haxe.xml.Access` wrapper.
     */
    public static function getAtt(node:Access, att:String, defaultValue:String = ""):String {
        if (node == null || !node.has.resolve(att)) return defaultValue;
        return node.att.resolve(att);
    }
}