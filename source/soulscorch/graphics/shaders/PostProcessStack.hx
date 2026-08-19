package soulscorch.graphics.shaders;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import soulscorch.graphics.shaders.SoulShader;

class PostProcessStack {
    public var camera:FlxCamera;
    public var shaders:Array<FlxShader> = [];
    public var enabled:Bool = true;

    public function new(?targetCamera:FlxCamera) {
        this.camera = (targetCamera != null) ? targetCamera : FlxG.camera;
    }

    public function add(shader:FlxShader):Void {
        if (shader == null || shaders.contains(shader)) return;
        shaders.push(shader);
        apply();
    }

    public function remove(shader:FlxShader):Void {
        if (shaders.remove(shader)) {
            apply();
        }
    }

    public function insert(index:Int, shader:FlxShader):Void {
        if (shader == null || shaders.contains(shader)) return;
        shaders.insert(index, shader);
        apply();
    }

    public function update(elapsed:Float):Void {
        if (!enabled) return;
        for (shader in shaders) {
            if (Std.isOfType(shader, SoulShader)) {
                cast(shader, SoulShader).update(elapsed);
            } else if (Std.isOfType(shader, RuntimeShader)) {
                cast(shader, RuntimeShader).update(elapsed);
            }
        }
    }

    public function clear():Void {
        shaders = [];
        apply();
    }

    public function apply():Void {
        if (camera == null) return;

        if (!enabled || shaders.length == 0) {
            camera.setFilters([]);
            return;
        }

        var filters:Array<BitmapFilter> = [];
        for (shader in shaders) {
            if (shader != null) {
                filters.push(new ShaderFilter(shader));
            }
        }
        camera.setFilters(filters);
    }

    public function setCamera(newCamera:FlxCamera):Void {
        if (camera != null) {
            camera.setFilters([]);
        }
        camera = newCamera;
        apply();
    }
}