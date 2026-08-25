package soulscorch.graphics.shaders;

import flixel.FlxCamera;
import flixel.FlxG;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.shaders.SoulShader;

using StringTools;

class ShaderManager {
    public static var instance:ShaderManager = new ShaderManager();

    public var filters:Array<ShaderFilter> = [];
    public var shaders:Array<SoulShader> = [];
    public var shaderMap:Map<String, SoulShader> = new Map<String, SoulShader>();

    public function new() {
        instance = this;
    }

    public function getShader(name:String):Null<SoulShader> {
        if (name == null || name.trim().length == 0) return null;
        var clean = name.trim();

        if (shaderMap.exists(clean)) {
            return shaderMap.get(clean);
        }

        for (s in shaders) {
            if (s != null && s.shaderName != null && s.shaderName.toLowerCase() == clean.toLowerCase()) {
                shaderMap.set(clean, s);
                return s;
            }
        }

        var createdShader = new SoulShader(clean);
        if (createdShader != null) {
            addShader(createdShader);
            shaderMap.set(clean, createdShader);
            return createdShader;
        }

        return null;
    }

    public function addShader(shader:SoulShader, ?camera:FlxCamera):Void {
        if (shader == null) return;

        if (!shaders.contains(shader)) {
            shaders.push(shader);
            if (shader.shaderName != null) {
                shaderMap.set(shader.shaderName, shader);
            }
        }

        var filter = shader.filter;
        if (!filters.contains(filter)) filters.push(filter);

        var cam = (camera != null) ? camera : FlxG.camera;
        if (cam != null) {
            var currentFilters:Array<BitmapFilter> = (cam.filters != null) ? cam.filters : [];
            if (!currentFilters.contains(filter)) {
                currentFilters.push(filter);
                cam.setFilters(currentFilters);
            }
        }

        EventBus.publish("shader/added", {name: shader.shaderName});
        Logger.info('Added shader filter (${shader.shaderName})', "shader");
    }

    public function removeShader(shader:SoulShader, ?camera:FlxCamera):Void {
        if (shader == null) return;

        var cam = (camera != null) ? camera : FlxG.camera;
        if (cam != null) {
            var currentFilters:Array<BitmapFilter> = (cam.filters != null) ? cam.filters : [];
            currentFilters.remove(shader.filter);
            cam.setFilters(currentFilters);
        }

        if (camera == null) {
            shaders.remove(shader);
            if (shader.shaderName != null) {
                shaderMap.remove(shader.shaderName);
            }
            filters.remove(shader.filter);
        }

        EventBus.publish("shader/removed", {name: shader.shaderName});
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
        shaderMap.clear();
        EventBus.publish("shader/cleared", {});
    }

    public function destroy():Void {
        clearShaders();
    }
}