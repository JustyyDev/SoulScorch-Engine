package soulscorch.graphics.shaders;

import flixel.FlxCamera;
import flixel.FlxG;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.shaders.SoulShader;

class ShaderManager {
    public static var instance:ShaderManager = new ShaderManager();

    public var filters:Array<ShaderFilter> = [];
    public var shaders:Array<SoulShader> = [];

    public function new() {
        instance = this;
    }

    public function addShader(shader:SoulShader, ?camera:FlxCamera):Void {
        if (shader == null || shaders.contains(shader)) return;

        shaders.push(shader);
        var filter = shader.filter;
        filters.push(filter);

        var cam = (camera != null) ? camera : FlxG.camera;
        if (cam != null) {
            var currentFilters:Array<BitmapFilter> = (cam.filters != null) ? cam.filters : [];
            currentFilters.push(filter);
            cam.setFilters(currentFilters);
        }

        EventBus.emit("shader/added", {name: shader.shaderName});
        Logger.info('Added shader filter (${shader.shaderName})', "shader");
    }

    public function removeShader(shader:SoulShader, ?camera:FlxCamera):Void {
        if (shader == null) return;
        shaders.remove(shader);
        filters.remove(shader.filter);

        var cam = (camera != null) ? camera : FlxG.camera;
        if (cam != null) {
            var currentFilters:Array<BitmapFilter> = (cam.filters != null) ? cam.filters : [];
            currentFilters.remove(shader.filter);
            cam.setFilters(currentFilters);
        }

        EventBus.emit("shader/removed", {name: shader.shaderName});
    }

    public function update(elapsed:Float):Void {
        for (shader in shaders) {
            if (shader != null) shader.update(elapsed);
        }
    }

    public function clearShaders(?camera:FlxCamera):Void {
        var cam = (camera != null) ? camera : FlxG.camera;
        if (cam != null) {
            cam.setFilters([]);
        }
        filters = [];
        shaders = [];
        EventBus.emit("shader/cleared", {});
    }

    public function destroy():Void {
        clearShaders();
    }
}