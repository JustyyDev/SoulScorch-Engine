package soulscorch.scripting.backends;

import soulscorch.scripting.ScriptInstance;

using StringTools;

enum abstract ScriptBackendType(String) from String to String {
    var HSCRIPT = "hscript";
    var LUA = "lua";
    var SOULSCRIPT = "soulscript";
    var UNKNOWN = "unknown";

    public static function fromPath(path:String):ScriptBackendType {
        if (path == null) return UNKNOWN;
        var clean = path.toLowerCase().trim();

        if (clean.endsWith(".hx") || clean.endsWith(".hscript")) {
            return HSCRIPT;
        } else if (clean.endsWith(".lua")) {
            return LUA;
        } else if (clean.endsWith(".soul")) {
            return SOULSCRIPT;
        }
        return UNKNOWN;
    }

    public static function createInstance(path:String):ScriptInstance {
        return switch (fromPath(path)) {
            case HSCRIPT: new HScriptIris(path);
            case LUA: new LuaScript(path);
            case SOULSCRIPT: new SoulScript(path);
            default: new HScriptIris(path);
        };
    }
}