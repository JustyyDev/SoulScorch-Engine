package soulscorch.graphics.shaders;

import flixel.FlxCamera;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import soulscorch.graphics.shaders.SoulShader;

/**
 * FlxCamera subclass that exposes a script-friendly `addShader` / `removeShader`
 * API. Song/cutscene scripts call `camGame.addShader(shader)` directly.
 */
class SoulCamera extends FlxCamera {
    public function new(?x:Float = 0, ?y:Float = 0, ?width:Int = 0, ?height:Int = 0, ?zoom:Float = 0) {
        super(x, y, width, height, zoom);
    }

    public function addShader(shader:SoulShader):Void {
        if (shader == null) return;
        ShaderManager.instance.addShader(shader, this);
    }

    public function removeShader(shader:SoulShader):Void {
        if (shader == null) return;
        ShaderManager.instance.removeShader(shader, this);
    }

    public function clearShaderFilters():Void {
        var currentFilters:Array<BitmapFilter> = (this.filters != null) ? this.filters : [];
        for (f in currentFilters) {
            if (Std.isOfType(f, ShaderFilter)) {
                var sf:ShaderFilter = cast f;
                if (Std.isOfType(sf.shader, SoulShader)) {
                    ShaderManager.instance.removeShader(cast sf.shader, this);
                }
            }
        }
    }
}
