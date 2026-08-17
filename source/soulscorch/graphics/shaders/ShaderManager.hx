package soulscorch.system;

import flixel.FlxG;
import flixel.FlxCamera;
import openfl.filters.ShaderFilter;
import soulscorch.core.EventBus;
import soulscorch.core.Logger;

class ShaderManager {
    public var filters:Array<ShaderFilter> = [];
    public var shaders:Array<SoulShader> = [];

    public function new() {}

    public function addShader(shader:SoulShader, ?camera:FlxCamera):Void {
        shaders.push(shader);
        var filter = new ShaderFilter(shader);
        filters.push(filter);

        var cam = camera != null ? camera : FlxG.camera;

        if (cam.filters == null) {
            cam.setFilters([filter]);
        } else {
            cam.filters.push(filter);
        }

        EventBus.publish("shader/added", {name: shader.shaderName});
        Logger.info("shader", 'Added shader filter (total: ${shaders.length})');
    }

    public function update(elapsed:Float):Void {
        for (shader in shaders) {
            if (Reflect.hasField(shader.data, "iTime")) {
                var curTime:Array<Float> = Reflect.field(shader.data, "iTime").value;
                if (curTime == null) curTime = [0.0];
                curTime[0] += elapsed;
                shader.setFloat("iTime", curTime[0]);
            }
        }
    }

    public function clearShaders(?camera:FlxCamera):Void {
        var cam = camera != null ? camera : FlxG.camera;
        cam.setFilters([]);
        filters = [];
        shaders = [];
        EventBus.publish("shader/cleared", {});
    }

    public function destroy():Void {
        clearShaders();
    }
}