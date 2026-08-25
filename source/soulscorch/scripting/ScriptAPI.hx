package soulscorch.scripting;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import soulscorch.gameplay.PlayState;
import soulscorch.graphics.shaders.ShaderManager;
import soulscorch.graphics.shaders.SoulShader;

using StringTools;

class ScriptAPI {
    public static function createShader(name:String):Null<SoulShader> {
        if (name == null || name.trim().length == 0) return null;
        return ShaderManager.instance.getShader(name.trim());
    }

    public static function addShaderToCamera(shaderName:String, cameraName:String = "game"):Bool {
        var shader = createShader(shaderName);
        var camera = resolveCamera(cameraName);
        if (shader == null || camera == null) return false;
        ShaderManager.instance.addShader(shader, camera);
        return true;
    }

    public static function removeShaderFromCamera(shaderName:String, cameraName:String = "game"):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        var camera = resolveCamera(cameraName);
        if (shader == null || camera == null) return false;
        ShaderManager.instance.removeShader(shader, camera);
        return true;
    }

    public static function setShaderFloat(shaderName:String, uniform:String, value:Float):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        if (shader == null) return false;
        shader.setFloat(uniform, value);
        return true;
    }

    public static function setShaderFloatArray(shaderName:String, uniform:String, value:Array<Float>):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        if (shader == null) return false;
        shader.setFloatArray(uniform, value);
        return true;
    }

    public static function setShaderInt(shaderName:String, uniform:String, value:Int):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        if (shader == null) return false;
        shader.setInt(uniform, value);
        return true;
    }

    public static function setShaderBool(shaderName:String, uniform:String, value:Bool):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        if (shader == null) return false;
        shader.setBool(uniform, value);
        return true;
    }

    public static function setSpriteShader(sprite:FlxSprite, shaderName:String):Bool {
        if (sprite == null) return false;
        var shader = createShader(shaderName);
        if (shader == null) return false;
        sprite.shader = shader;
        return true;
    }

    public static function clearCameraShaders(cameraName:String = "game"):Void {
        var camera = resolveCamera(cameraName);
        if (camera != null) camera.setFilters([]);
    }

    public static function resolveCamera(cameraName:String = "game"):FlxCamera {
        var game = PlayState.instance;
        var clean = cameraName == null ? "game" : cameraName.toLowerCase().trim();
        if (game == null) return FlxG.camera;
        return switch (clean) {
            case "hud", "camhud": game.camHUD;
            case "other", "camother": game.camOther;
            case "controls", "camcontrols": game.camControls;
            case "game", "camgame": game.camGame;
            default: FlxG.camera;
        };
    }
}
