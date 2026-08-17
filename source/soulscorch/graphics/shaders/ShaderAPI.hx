package soulscorch.backend;

import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ShaderAPI {
    public static function loadShader(shaderName:String):RuntimeShader {
        #if sys
        var fragPath = ModManager.getPath('shaders/$shaderName.frag');
        var vertPath = ModManager.getPath('shaders/$shaderName.vert');
        
        var fragCode:String = null;
        var vertCode:String = null;

        if (FileSystem.exists(fragPath)) fragCode = File.getContent(fragPath);
        if (FileSystem.exists(vertPath)) vertCode = File.getContent(vertPath);

        if (fragCode != null || vertCode != null) {
            try {
                return new RuntimeShader(fragCode, vertCode);
            } catch (e:Dynamic) {
                if (soulscorch.ui.DevConsole.instance != null) {
                    soulscorch.ui.DevConsole.instance.log('[SHADER ERROR] Failed to compile $shaderName: ' + e);
                }
            }
        } else {
            if (soulscorch.ui.DevConsole.instance != null) {
                soulscorch.ui.DevConsole.instance.log('[SHADER WARN] Shader files not found for: ' + shaderName);
            }
        }
        #end
        
        return null;
    }
}