package soulscorch.backend;

import flixel.FlxCamera;
import flixel.system.FlxAssets.FlxShader;

class PostProcessStack {
    public var camera:FlxCamera;
    public var shaders:Array<FlxShader> = [];
    public function new(?target:FlxCamera) camera = target == null ? flixel.FlxG.camera : target;
    public function add(shader:FlxShader):Void { if (shader != null && !shaders.contains(shader)) shaders.push(shader); apply(); }
    public function remove(shader:FlxShader):Void { shaders.remove(shader); apply(); }
    public function clear():Void { shaders = []; apply(); }
    public function enableBloom(enabled:Bool):Void if (enabled) add(new FlxShader());
    public function enableChromaticAberration(enabled:Bool):Void if (enabled) add(new FlxShader());
    public function enableScanlines(enabled:Bool):Void if (enabled) add(new FlxShader());
    public function enableLut(enabled:Bool):Void if (enabled) add(new FlxShader());
    private function apply():Void if (camera != null) camera.setFilters([]);
}
