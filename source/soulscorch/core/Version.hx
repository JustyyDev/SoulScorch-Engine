package soulscorch.core;

/**
 * Static engine version metadata.
 */
class Version {
    public static inline var ENGINE_NAME:String = "SoulScorch Engine";
    public static inline var MAJOR:Int = 0;
    public static inline var MINOR:Int = 6;
    public static inline var PATCH:Int = 0;
    public static inline var CODENAME:String = "Ember";
    public static inline var BUILD_DATE:String = "2026-08-16";

    public static function versionString():String {
        return '$ENGINE_NAME v$MAJOR.$MINOR.$PATCH "$CODENAME"';
    }

    public static function fullVersion():String {
        return '${versionString()} (build $BUILD_DATE)';
    }

    public static function isAtLeast(major:Int, minor:Int, patch:Int):Bool {
        if (MAJOR != major) return MAJOR > major;
        if (MINOR != minor) return MINOR > minor;
        return PATCH >= patch;
    }
}
