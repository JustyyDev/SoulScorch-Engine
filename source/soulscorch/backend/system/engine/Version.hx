package soulscorch.backend.system.engine;

class Version {
    public static inline var MAJOR:Int = 1;
    public static inline var MINOR:Int = 0;
    public static inline var PATCH:Int = 0;
    public static inline var BUILD:String = "dev";
    public static inline var CODENAME:String = "Alpha";

    public static inline var ENGINE_VERSION:String = "1.0.0";

    public static inline function versionString():String {
        return 'v$MAJOR.$MINOR.$PATCH ($CODENAME)';
    }

    public static inline function fullVersion():String {
        return 'SoulScorch Engine v$MAJOR.$MINOR.$PATCH ($CODENAME)';
    }

    public static inline function shortVersion():String {
        return 'v$MAJOR.$MINOR.$PATCH';
    }

    public static inline function getBuildInfo():String {
        return 'SoulScorch Engine $ENGINE_VERSION - $CODENAME Build ($BUILD)';
    }
}