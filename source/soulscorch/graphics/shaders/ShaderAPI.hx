package soulscorch.graphics.shaders;

import openfl.filters.ShaderFilter;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.graphics.shaders.SoulShader;

class ShaderAPI {
    private static var _cachedShaders:Map<String, SoulShader> = new Map<String, SoulShader>();

    public static function loadShader(shaderName:String, forceNewInstance:Bool = false):Null<SoulShader> {
        if (shaderName == null || shaderName.length == 0) return null;

        if (!forceNewInstance && _cachedShaders.exists(shaderName)) {
            return _cachedShaders.get(shaderName);
        }

        try {
            var shader = new SoulShader(shaderName);
            if (!forceNewInstance) {
                _cachedShaders.set(shaderName, shader);
            }
            return shader;
        } catch (e:Dynamic) {
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[SHADER ERROR] Failed compiling $shaderName: ' + e);
            }
        }
        return null;
    }

    public static function createFilter(shaderName:String):Null<ShaderFilter> {
        var shader = loadShader(shaderName);
        return (shader != null) ? shader.filter : null;
    }

    public static function clearCache():Void {
        _cachedShaders.clear();
    }
}