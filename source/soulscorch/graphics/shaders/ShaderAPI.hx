package soulscorch.graphics.shaders;

import soulscorch.backend.system.engine.DevConsole;
import soulscorch.graphics.shaders.SoulShader;

class ShaderAPI {
    public static function loadShader(shaderName:String):SoulShader {
        try {
            return new SoulShader(shaderName);
        } catch (e:Dynamic) {
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[SHADER ERROR] Failed compiling $shaderName: ' + e);
            }
        }
        return null;
    }
}