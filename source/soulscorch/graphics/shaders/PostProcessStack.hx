package soulscorch.graphics.shaders;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

class PostProcessStack {
    public var camera:FlxCamera;
    public var shaders:Array<FlxShader> = [];
    public var enabled:Bool = true;

    public function new(?targetCamera:FlxCamera) {
        this.camera = targetCamera != null ? targetCamera : FlxG.camera;
    }

    /**
     * Appends a shader to the post-processing chain.
     */
    public function add(shader:FlxShader):Void {
        if (shader == null || shaders.contains(shader)) return;
        shaders.push(shader);
        apply();
    }

    /**
     * Removes a specific shader from the chain.
     */
    public function remove(shader:FlxShader):Void {
        if (shaders.remove(shader)) {
            apply();
        }
    }

    /**
     * Inserts a shader at a specific index in the render pipeline.
     */
    public function insert(index:Int, shader:FlxShader):Void {
        if (shader == null || shaders.contains(shader)) return;
        shaders.insert(index, shader);
        apply();
    }

    /**
     * Clears all active post-processing shaders from the camera.
     */
    public function clear():Void {
        shaders = [];
        apply();
    }

    /**
     * Reconstructs the OpenFL filter list and uploads it to the FlxCamera.
     */
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