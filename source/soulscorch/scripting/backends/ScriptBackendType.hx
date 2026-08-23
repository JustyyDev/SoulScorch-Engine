package soulscorch.scripting.backends;

import soulscorch.scripting.ScriptInstance;

using StringTools;

enum abstract ScriptBackendType(String) from String to String {
    var HSCRIPT = "hscript";
    var LUA = "lua";
    var SOULSCRIPT = "soulscript";
    var PYTHON = "python";
    var UNKNOWN = "unknown";

    public static function fromPath(path:String):ScriptBackendType {
        if (path == null) return UNKNOWN;
        var clean = path.toLowerCase().trim();

        if (clean.endsWith(".soul")) {
            return SOULSCRIPT;
        } else if (clean.endsWith(".lua")) {
            return LUA;
        } else if (clean.endsWith(".py")) {
            return PYTHON;
        } else if (clean.endsWith(".hx") || clean.endsWith(".hscript") || clean.endsWith(".iris")) {
            return HSCRIPT;
        }
        return UNKNOWN;
    }

    public static function createInstance(path:String):ScriptInstance {
        return switch (fromPath(path)) {
            case SOULSCRIPT: new SoulScript(path);
            case LUA: new LuaScript(path);
            case PYTHON: new PythonScript(path);
            case HSCRIPT: new HScriptIris(path);
            default: new HScriptIris(path);
        };
    }
}